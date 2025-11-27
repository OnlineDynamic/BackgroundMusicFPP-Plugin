#!/bin/bash
# Set PipeWire stream volume for background music player using pw-dump + jq

TARGET_VOLUME=${1:-70}  # Target volume (0-100)
FPP_UID=$(id -u fpp)
RUNTIME_DIR="/run/user/${FPP_UID}"

# Convert percentage to PipeWire volume (0.0 to 1.0)
PW_VOLUME=$(echo "scale=2; $TARGET_VOLUME / 100" | bc)

# Find all BackgroundMusic streams using pw-dump + jq
if [ "$(whoami)" = "fpp" ]; then
    export XDG_RUNTIME_DIR="$RUNTIME_DIR"
    STREAM_IDS=$(pw-dump 2>/dev/null | jq -r '.[] | select(.info.props["media.name"]? // "" | startswith("BackgroundMusic")) | select(.type == "PipeWire:Interface:Node") | .id')
else
    STREAM_IDS=$(sudo -u fpp XDG_RUNTIME_DIR="$RUNTIME_DIR" pw-dump 2>/dev/null | jq -r '.[] | select(.info.props["media.name"]? // "" | startswith("BackgroundMusic")) | select(.type == "PipeWire:Interface:Node") | .id')
fi

FOUND=0
for STREAM_ID in $STREAM_IDS; do
    if [ -n "$STREAM_ID" ]; then
        echo "Found bgmplayer stream ID: $STREAM_ID, setting volume to ${TARGET_VOLUME}%"
        if [ "$(whoami)" = "fpp" ]; then
            pw-cli set-param "$STREAM_ID" Props '{ volume: '"$PW_VOLUME"' }' 2>/dev/null
        else
            sudo -u fpp XDG_RUNTIME_DIR="$RUNTIME_DIR" pw-cli set-param "$STREAM_ID" Props '{ volume: '"$PW_VOLUME"' }' 2>/dev/null
        fi
        FOUND=1
    fi
done

if [ $FOUND -eq 0 ]; then
    echo "No bgmplayer stream found - it may not be playing yet"
    exit 1
fi

echo "Volume set successfully"
exit 0
