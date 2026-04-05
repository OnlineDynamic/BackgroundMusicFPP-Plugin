#!/bin/bash
###############################################################################
# set_pipewire_volume.sh - Set volume on all background music PipeWire streams
# FPP 10 version: uses wpctl with system PipeWire socket
# Usage: set_pipewire_volume.sh <volume_percent>
###############################################################################

SCRIPT_DIR="$(dirname "$0")"
. "$SCRIPT_DIR/pw_env.sh"

TARGET_VOLUME=${1:-70}

# Set volume on all bgmusic streams
FOUND=0
for node_name in bgmusic_main bgmusic_crossfade; do
    NODE_ID=$(find_bgmusic_node "$node_name")
    if [ -n "$NODE_ID" ]; then
        set_node_volume "$NODE_ID" "$TARGET_VOLUME"
        echo "Set $node_name (node $NODE_ID) volume to ${TARGET_VOLUME}%"
        FOUND=1
    fi
done

if [ $FOUND -eq 0 ]; then
    echo "No background music streams found"
    exit 1
fi

echo "$TARGET_VOLUME" > "$VOLUME_FILE"
echo "Volume set successfully"
exit 0
