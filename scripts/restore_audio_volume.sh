#!/bin/bash
##########################################################################
# restore_audio_volume.sh - Restore audio volume to specified level
# 
# This script restores the system audio volume after a fade
##########################################################################

TARGET_VOLUME=${1:-70}  # Target volume (default 70%)
LOG_FILE="/home/fpp/media/logs/fpp-plugin-BackgroundMusic.log"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

log_message "Restoring audio volume to ${TARGET_VOLUME}%"

# Get FPP's configured audio card number
AUDIO_CARD=$(grep "^AudioOutput = " /home/fpp/media/settings | sed 's/AudioOutput = "\(.*\)"/\1/')
if [ -z "$AUDIO_CARD" ]; then
    AUDIO_CARD=$(grep "^AlsaAudioDevice = " /home/fpp/media/settings | sed 's/AlsaAudioDevice = "\(.*\)"/\1/')
fi
AUDIO_CARD=${AUDIO_CARD:-0}

log_message "Using audio card: $AUDIO_CARD"

# For PipeWire systems, use wpctl to control sink volume
# PipeWire manages volume in software, so we set ALSA to 100% and control via wpctl
FPP_UID=$(id -u fpp)
RUNTIME_DIR="/run/user/${FPP_UID}"

if command -v wpctl > /dev/null 2>&1; then
    log_message "Using wpctl (PipeWire/WirePlumber) to restore volume"
    
    # Convert percentage to decimal (0.0-1.0)
    PW_VOLUME=$(echo "scale=2; $TARGET_VOLUME / 100" | bc)
    
    if [ "$(whoami)" = "fpp" ]; then
        export XDG_RUNTIME_DIR="$RUNTIME_DIR"
        WPCTL_CMD="wpctl"
    else
        WPCTL_CMD="sudo -u fpp XDG_RUNTIME_DIR=$RUNTIME_DIR wpctl"
    fi
    
    # First, ensure ALSA hardware volume is at 100% (PipeWire will control from there)
    if command -v amixer > /dev/null 2>&1; then
        if amixer -c "$AUDIO_CARD" sget PCM > /dev/null 2>&1; then
            amixer -c "$AUDIO_CARD" sset PCM 100% > /dev/null 2>&1
            log_message "Set ALSA PCM to 100% (base level for PipeWire)"
        elif amixer -c "$AUDIO_CARD" sget Master > /dev/null 2>&1; then
            amixer -c "$AUDIO_CARD" sset Master 100% > /dev/null 2>&1
            log_message "Set ALSA Master to 100% (base level for PipeWire)"
        fi
    fi
    
    # Find the sink for the configured audio card
    # wpctl output includes UTF-8 box characters, so use simple pattern matching
    if [ "$AUDIO_CARD" = "2" ] || [ "$AUDIO_CARD" = "3" ]; then
        # HDMI cards - look for HDMI in sink name
        SINK_ID=$($WPCTL_CMD status 2>/dev/null | grep -E "[0-9]+\. .*HDMI" | head -1 | sed 's/^[^0-9]*\([0-9]*\)\..*$/\1/')
    elif [ "$AUDIO_CARD" = "1" ]; then
        # USB card - look for USB, Blaster, or similar
        SINK_ID=$($WPCTL_CMD status 2>/dev/null | grep -E "[0-9]+\. .*(USB|Blaster|Sound)" | grep -v "HDMI" | head -1 | sed 's/^[^0-9]*\([0-9]*\)\..*$/\1/')
    elif [ "$AUDIO_CARD" = "0" ]; then
        # Built-in headphones - look for "Built-in" but NOT HDMI
        SINK_ID=$($WPCTL_CMD status 2>/dev/null | grep -E "[0-9]+\. .*Built-in" | grep -v "HDMI" | head -1 | sed 's/^[^0-9]*\([0-9]*\)\..*$/\1/')
    fi
    
    if [ -n "$SINK_ID" ]; then
        log_message "Setting PipeWire sink $SINK_ID to ${TARGET_VOLUME}% ($PW_VOLUME)"
        $WPCTL_CMD set-volume $SINK_ID $PW_VOLUME 2>&1 | tee -a "$LOG_FILE"
        log_message "Volume restored via wpctl"
    else
        log_message "WARNING: Could not find PipeWire sink for card $AUDIO_CARD, falling back to ALSA"
        # Fallback to direct ALSA control
        if command -v amixer > /dev/null 2>&1; then
            if amixer -c "$AUDIO_CARD" sget PCM > /dev/null 2>&1; then
                amixer -c "$AUDIO_CARD" sset PCM "${TARGET_VOLUME}%" > /dev/null 2>&1
                log_message "Volume restored via ALSA PCM control"
            fi
        fi
    fi
elif command -v amixer > /dev/null 2>&1; then
    # Fallback to ALSA if wpctl not available
    log_message "Using ALSA (amixer) to restore volume on card $AUDIO_CARD"
    
    if amixer -c "$AUDIO_CARD" sget Master > /dev/null 2>&1; then
        amixer -c "$AUDIO_CARD" sset Master "${TARGET_VOLUME}%" > /dev/null 2>&1
        log_message "Volume restored via ALSA Master control"
    elif amixer -c "$AUDIO_CARD" sget PCM > /dev/null 2>&1; then
        amixer -c "$AUDIO_CARD" sset PCM "${TARGET_VOLUME}%" > /dev/null 2>&1
        log_message "Volume restored via ALSA PCM control"
    elif amixer -c "$AUDIO_CARD" sget Speaker > /dev/null 2>&1; then
        amixer -c "$AUDIO_CARD" sset Speaker "${TARGET_VOLUME}%" > /dev/null 2>&1
        log_message "Volume restored via ALSA Speaker control"
    else
        log_message "WARNING: Could not find ALSA volume control on card $AUDIO_CARD"
    fi
else
    log_message "ERROR: Neither wpctl nor amixer found - cannot restore volume"
    exit 1
fi

# Also set PipeWire stream volume if bgmplayer is playing
PLUGIN_DIR="/home/fpp/media/plugins/fpp-plugin-BackgroundMusic"
if [ -x "${PLUGIN_DIR}/scripts/set_pipewire_volume.sh" ]; then
    log_message "Attempting to set PipeWire stream volume to ${TARGET_VOLUME}%"
    "${PLUGIN_DIR}/scripts/set_pipewire_volume.sh" "${TARGET_VOLUME}" >> "$LOG_FILE" 2>&1 || true
fi

exit 0
