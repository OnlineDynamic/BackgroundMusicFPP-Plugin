#!/bin/bash
###############################################################################
# set_bgmusic_volume.sh - Set background music PipeWire stream volume
# FPP 10 version: uses wpctl with system PipeWire socket
# Usage: set_bgmusic_volume.sh <volume_percent>
###############################################################################

SCRIPT_DIR="$(dirname "$0")"
. "$SCRIPT_DIR/pw_env.sh"

TARGET_VOLUME=${1:-70}

# Validate
if ! [[ "$TARGET_VOLUME" =~ ^[0-9]+$ ]] || [ "$TARGET_VOLUME" -lt 0 ] || [ "$TARGET_VOLUME" -gt 100 ]; then
    log_message "ERROR: Invalid target volume: $TARGET_VOLUME"
    exit 1
fi

# Find bgmusic_main node
NODE_ID=$(find_bgmusic_node "bgmusic_main")
if [ -z "$NODE_ID" ]; then
    log_message "No bgmusic_main node found in PipeWire - player may not be active"
    exit 0
fi

set_node_volume "$NODE_ID" "$TARGET_VOLUME"
echo "$TARGET_VOLUME" > "$VOLUME_FILE"
log_message "Set bgmusic_main (node $NODE_ID) volume to ${TARGET_VOLUME}%"

# Also set crossfade stream if active
XFADE_NODE=$(find_bgmusic_node "bgmusic_crossfade")
if [ -n "$XFADE_NODE" ]; then
    set_node_volume "$XFADE_NODE" "$TARGET_VOLUME"
    log_message "Set bgmusic_crossfade (node $XFADE_NODE) volume to ${TARGET_VOLUME}%"
fi

exit 0
