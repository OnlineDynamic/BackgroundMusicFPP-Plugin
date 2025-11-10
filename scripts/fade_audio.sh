#!/bin/bash
##########################################################################
# fade_audio.sh - Gradually fade audio volume down to 0
# 
# This script fades the system audio volume using ALSA mixer
##########################################################################

FADE_TIME=${1:-5}  # Fade time in seconds (default 5)
LOG_FILE="/home/fpp/media/logs/fpp-plugin-BackgroundMusic.log"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Get the PID of the running background music player
if [ ! -f "/tmp/background_music_player.pid" ]; then
    log_message "No background music player running"
    exit 0
fi

PLAYER_PID=$(cat /tmp/background_music_player.pid)

# Check if the process is actually running
if ! ps -p "$PLAYER_PID" > /dev/null 2>&1; then
    log_message "Background music player PID $PLAYER_PID not found"
    exit 0
fi

log_message "Fading system volume over $FADE_TIME seconds"

# Get current volume
CURRENT_VOLUME=$(amixer get PCM | grep -o '[0-9]*%' | head -1 | tr -d '%')
if [ -z "$CURRENT_VOLUME" ]; then
    log_message "Could not detect current volume"
    exit 1
fi

log_message "Current volume: ${CURRENT_VOLUME}%, fading to 0%"

# Calculate fade steps (10 steps per second)
FADE_STEPS=$((FADE_TIME * 10))
if [ $FADE_STEPS -lt 1 ]; then
    FADE_STEPS=1
fi
VOLUME_STEP=$(echo "scale=2; $CURRENT_VOLUME / $FADE_STEPS" | bc)
SLEEP_TIME=$(echo "scale=3; $FADE_TIME / $FADE_STEPS" | bc)

# Fade volume down using FPP API
for ((i=1; i<=FADE_STEPS; i++)); do
    TARGET_VOLUME=$(echo "scale=0; $CURRENT_VOLUME - ($VOLUME_STEP * $i)" | bc)
    
    if [ "$TARGET_VOLUME" -lt 0 ]; then
        TARGET_VOLUME=0
    fi
    
    # Set volume via FPP API
    curl -s -X POST -H "Content-Type: application/json" \
        -d "{\"volume\": ${TARGET_VOLUME}}" \
        "http://localhost/api/system/volume" > /dev/null 2>&1
    
    # Check if player still running
    if ! ps -p "$PLAYER_PID" > /dev/null 2>&1; then
        log_message "Player process ended during fade"
        exit 0
    fi
    
    sleep "$SLEEP_TIME"
done

# Ensure volume is at 0
curl -s -X POST -H "Content-Type: application/json" \
    -d '{"volume": 0}' \
    "http://localhost/api/system/volume" > /dev/null 2>&1

log_message "Audio fade complete - volume at 0%"

exit 0
