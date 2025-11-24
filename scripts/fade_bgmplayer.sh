#!/bin/bash
###############################################################################
# fade_bgmplayer.sh - Fade bgmplayer's PipeWire stream volume
###############################################################################

SCRIPT_DIR="$(dirname "$0")"
. /opt/fpp/scripts/common

LOG_FILE="/home/fpp/media/logs/backgroundmusic_transition.log"
export XDG_RUNTIME_DIR=/run/user/500

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Get bgmplayer PID (the actual player, not the wrapper script)
BGMPLAYER_PID_FILE="/tmp/bg_music_bgmplayer.pid"

if [ ! -f "$BGMPLAYER_PID_FILE" ]; then
    log_message "No bgmplayer PID file found at $BGMPLAYER_PID_FILE"
    exit 1
fi

PLAYER_PID=$(cat "$BGMPLAYER_PID_FILE" 2>/dev/null)
if [ -z "$PLAYER_PID" ] || ! kill -0 "$PLAYER_PID" 2>/dev/null; then
    log_message "bgmplayer process not running (PID: $PLAYER_PID)"
    exit 1
fi

# Find bgmplayer stream in PipeWire
STREAM_ID=$(wpctl status 2>/dev/null | awk '/Streams:/,/^$/ {print}' | grep -E "(bgmplayer|SDL Application)" | grep -oP '^\s+\K[0-9]+' | head -1)

if [ -z "$STREAM_ID" ]; then
    log_message "Could not find bgmplayer stream in PipeWire"
    exit 1
fi

log_message "Found bgmplayer stream ID: $STREAM_ID"

# Get fade time from plugin settings (default 10 seconds)
FADE_TIME=$(getSetting BackgroundMusicFadeTime)
if [ -z "$FADE_TIME" ] || [ "$FADE_TIME" -eq 0 ]; then
    FADE_TIME=10
fi

# Get current volume from volume file
CURRENT_VOL=$(cat /tmp/bgmplayer_volume.txt 2>/dev/null || echo "70")
log_message "Starting PipeWire stream volume fade from ${CURRENT_VOL}% to 0% over ${FADE_TIME}s - PID: $PLAYER_PID"

# Calculate step size and interval
STEPS=20
INTERVAL=$(echo "scale=3; $FADE_TIME / $STEPS" | bc)

for ((i=1; i<=STEPS; i++)); do
    # Check if player still exists
    if ! kill -0 "$PLAYER_PID" 2>/dev/null; then
        log_message "bgmplayer stopped during fade"
        exit 0
    fi
    
    # Calculate target volume for this step (linear fade from CURRENT_VOL to 0)
    TARGET_VOL=$(( CURRENT_VOL - (CURRENT_VOL * i / STEPS) ))
    if [ "$TARGET_VOL" -lt 0 ]; then
        TARGET_VOL=0
    fi
    
    # Convert to PipeWire volume (with 1.5x boost like set_bgmplayer_volume.sh)
    PIPEWIRE_VOL=$(echo "scale=2; ($TARGET_VOL / 100.0) * 1.5" | bc)
    
    # Set volume using wpctl
    wpctl set-volume "$STREAM_ID" "$PIPEWIRE_VOL" 2>/dev/null
    
    log_message "Fade step $i/$STEPS - volume: ${TARGET_VOL}% (PipeWire: ${PIPEWIRE_VOL})"
    
    sleep "$INTERVAL"
done

# Final step - ensure it's at 0
wpctl set-volume "$STREAM_ID" 0 2>/dev/null
log_message "PipeWire stream volume fade complete - now at 0%"
