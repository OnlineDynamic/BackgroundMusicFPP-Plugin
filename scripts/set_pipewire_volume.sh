#!/bin/bash
# Set PipeWire stream volume for background music player

TARGET_VOLUME=${1:-70}  # Target volume (0-100)
FPP_UID=$(id -u fpp)
RUNTIME_DIR="/run/user/${FPP_UID}"

# Convert percentage to PipeWire volume (0.0 to 1.0 for wpctl)
PW_VOLUME=$(echo "scale=2; $TARGET_VOLUME / 100" | bc)

# Use wpctl (WirePlumber control) to set stream volume
if [ "$(whoami)" = "fpp" ]; then
    export XDG_RUNTIME_DIR="$RUNTIME_DIR"
    WPCTL_CMD="wpctl"
else
    WPCTL_CMD="sudo -u fpp XDG_RUNTIME_DIR=$RUNTIME_DIR wpctl"
fi

# Find all sink-inputs (playback streams) and set volume for bgmplayer/SDL streams
FOUND=0
$WPCTL_CMD status 2>/dev/null | grep -A100 "Sink inputs:" | grep -B1 -E "bgmplayer|SDL" | grep "^\s*[0-9]" | while read LINE; do
    STREAM_ID=$(echo "$LINE" | grep -oP '^\s*\K[0-9]+')
    if [ -n "$STREAM_ID" ]; then
        echo "Found bgmplayer stream ID: $STREAM_ID, setting volume to ${TARGET_VOLUME}%"
        $WPCTL_CMD set-volume $STREAM_ID $PW_VOLUME 2>&1
        FOUND=1
    fi
done

if [ $FOUND -eq 0 ]; then
    echo "No bgmplayer stream found - it may not be playing yet"
    exit 1
fi

echo "Volume set successfully"
exit 0
