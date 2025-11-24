#!/bin/bash
# Set bgmplayer volume using PipeWire's native volume control
# Much simpler and more reliable than custom PCM scaling

TARGET_VOLUME=${1:-70}  # Target volume (0-100)
VOLUME_FILE="/tmp/bgmplayer_volume.txt"
LOG_FILE="/home/fpp/media/logs/fpp-plugin-BackgroundMusic.log"
export XDG_RUNTIME_DIR=/run/user/500

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Validate target volume
if ! [[ "$TARGET_VOLUME" =~ ^[0-9]+$ ]] || [ "$TARGET_VOLUME" -lt 0 ] || [ "$TARGET_VOLUME" -gt 100 ]; then
    log_message "ERROR: Invalid target volume: $TARGET_VOLUME"
    exit 1
fi

# Find bgmplayer stream in PipeWire (look for SDL Application which is bgmplayer)
STREAM_ID=$(wpctl status 2>/dev/null | awk '/Streams:/,/^$/ {print}' | grep -E "(bgmplayer|SDL Application)" | grep -oP '^\s+\K[0-9]+' | head -1)

if [ -z "$STREAM_ID" ]; then
    log_message "No bgmplayer stream found in PipeWire, saving volume ${TARGET_VOLUME}% for next start"
    echo "$TARGET_VOLUME" > "$VOLUME_FILE"
    exit 0
fi

# Convert percentage to PipeWire volume (0.0 to 1.5 for 150% boost)
# Apply 1.5x boost to match FPP's volume level
PIPEWIRE_VOL=$(awk "BEGIN {printf \"%.2f\", ($TARGET_VOLUME / 100.0) * 1.5}")

# Set volume using wpctl
wpctl set-volume "$STREAM_ID" "$PIPEWIRE_VOL" 2>/dev/null

if [ $? -eq 0 ]; then
    log_message "Set bgmplayer stream $STREAM_ID volume to ${TARGET_VOLUME}% (PipeWire: ${PIPEWIRE_VOL})"
    echo "$TARGET_VOLUME" > "$VOLUME_FILE"
else
    log_message "ERROR: Failed to set volume for stream $STREAM_ID"
    exit 1
fi

exit 0
