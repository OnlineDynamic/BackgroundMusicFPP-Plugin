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

# Check if we have PulseAudio (pactl) or just ALSA (amixer)
if command -v pactl > /dev/null 2>&1; then
    # Use PulseAudio to restore all sink inputs
    log_message "Using PulseAudio (pactl) to restore volume"
    
    # Set all sinks to target volume
    pactl list short sinks | while read -r line; do
        SINK=$(echo "$line" | awk '{print $1}')
        pactl set-sink-volume "$SINK" "${TARGET_VOLUME}%" 2>/dev/null
    done
    
    log_message "Volume restored via PulseAudio"
    
elif command -v amixer > /dev/null 2>&1; then
    # Use ALSA mixer for system-wide volume control
    log_message "Using ALSA (amixer) to restore volume"
    
    # Get the audio device from FPP settings
    AUDIO_DEVICE=$(grep "^AlsaAudioDevice = " /home/fpp/media/settings | sed 's/AlsaAudioDevice = "\(.*\)"/\1/')
    AUDIO_DEVICE=${AUDIO_DEVICE:-default}
    
    # Try Master first, then PCM, then Speaker
    if amixer -D "$AUDIO_DEVICE" sget Master > /dev/null 2>&1; then
        amixer -D "$AUDIO_DEVICE" sset Master "${TARGET_VOLUME}%" > /dev/null 2>&1
        log_message "Volume restored via ALSA Master control"
    elif amixer -D "$AUDIO_DEVICE" sget PCM > /dev/null 2>&1; then
        amixer -D "$AUDIO_DEVICE" sset PCM "${TARGET_VOLUME}%" > /dev/null 2>&1
        log_message "Volume restored via ALSA PCM control"
    elif amixer -D "$AUDIO_DEVICE" sget Speaker > /dev/null 2>&1; then
        amixer -D "$AUDIO_DEVICE" sset Speaker "${TARGET_VOLUME}%" > /dev/null 2>&1
        log_message "Volume restored via ALSA Speaker control"
    else
        log_message "WARNING: Could not find ALSA volume control"
    fi
else
    log_message "ERROR: Neither pactl nor amixer found - cannot restore volume"
    exit 1
fi

exit 0
