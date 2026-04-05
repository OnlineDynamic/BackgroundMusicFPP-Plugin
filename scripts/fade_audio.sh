#!/bin/bash
##########################################################################
# fade_audio.sh - Gradually fade system audio volume down to 0
# FPP 10 version: uses FPP API for system volume control
##########################################################################

FADE_TIME=${1:-5}

SCRIPT_DIR="$(dirname "$0")"
. "$SCRIPT_DIR/pw_env.sh"

# Check if background music is running
if [ ! -f "$PID_FILE" ]; then
    log_message "No background music player running"
    exit 0
fi

PLAYER_PID=$(cat "$PID_FILE")
if ! ps -p "$PLAYER_PID" > /dev/null 2>&1; then
    log_message "Background music player PID $PLAYER_PID not found"
    exit 0
fi

# Get current volume from FPP API
CURRENT_VOLUME=$(curl -s "http://localhost/api/system/volume" | jq -r '.volume' 2>/dev/null)
if [ -z "$CURRENT_VOLUME" ] || [ "$CURRENT_VOLUME" = "null" ]; then
    CURRENT_VOLUME=70
fi

log_message "Fading system volume from ${CURRENT_VOLUME}% to 0% over ${FADE_TIME}s"

# 10 steps per second
FADE_STEPS=$((FADE_TIME * 10))
[ $FADE_STEPS -lt 1 ] && FADE_STEPS=1
VOLUME_STEP=$(awk "BEGIN {printf \"%.2f\", $CURRENT_VOLUME / $FADE_STEPS}")
SLEEP_TIME=$(awk "BEGIN {printf \"%.3f\", $FADE_TIME / $FADE_STEPS}")

for ((i=1; i<=FADE_STEPS; i++)); do
    TARGET_VOLUME=$(awk "BEGIN {v=int($CURRENT_VOLUME - ($VOLUME_STEP * $i)); if(v<0) v=0; print v}")

    curl -s -X POST -H "Content-Type: application/json" \
        -d "{\"volume\": ${TARGET_VOLUME}}" \
        "http://localhost/api/system/volume" > /dev/null 2>&1

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
