#!/bin/bash
##########################################################################
# restore_audio_volume.sh - Restore audio volume to specified level
# FPP 10 version: uses FPP API + wpctl
##########################################################################

TARGET_VOLUME=${1:-70}

SCRIPT_DIR="$(dirname "$0")"
. "$SCRIPT_DIR/pw_env.sh"

log_message "Restoring audio volume to ${TARGET_VOLUME}%"

# Restore system volume via FPP API
curl -s -X POST -H "Content-Type: application/json" \
    -d "{\"volume\": ${TARGET_VOLUME}}" \
    "http://localhost/api/system/volume" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    log_message "System volume restored to ${TARGET_VOLUME}% via FPP API"
else
    log_message "WARNING: Failed to set system volume via FPP API"
fi

# Also restore bgmusic stream volume if playing
NODE_ID=$(find_bgmusic_node "bgmusic_main")
if [ -n "$NODE_ID" ]; then
    set_node_volume "$NODE_ID" "$TARGET_VOLUME"
    echo "$TARGET_VOLUME" > "$VOLUME_FILE"
    log_message "Restored bgmusic_main (node $NODE_ID) volume to ${TARGET_VOLUME}%"
fi

exit 0
