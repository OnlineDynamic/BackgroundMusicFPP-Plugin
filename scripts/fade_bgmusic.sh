#!/bin/bash
###############################################################################
# fade_bgmusic.sh - Fade background music PipeWire stream volume to 0
# FPP 10 version: uses wpctl with system PipeWire socket
###############################################################################

SCRIPT_DIR="$(dirname "$0")"
. "$SCRIPT_DIR/pw_env.sh"

# Get fade time from plugin settings (default 10 seconds)
FADE_TIME=$(get_plugin_setting "BackgroundMusicFadeTime" "10")
[ "$FADE_TIME" -eq 0 ] 2>/dev/null && FADE_TIME=10

# Find the bgmusic_main node
NODE_ID=$(find_bgmusic_node "bgmusic_main")
if [ -z "$NODE_ID" ]; then
    log_message "[FADE] No bgmusic_main node found in PipeWire"
    exit 1
fi

# Get current volume
CURRENT_VOL=$(cat "$VOLUME_FILE" 2>/dev/null || echo "70")
log_message "[FADE] Starting fade from ${CURRENT_VOL}% to 0% over ${FADE_TIME}s (node $NODE_ID)"

STEPS=20
INTERVAL=$(awk "BEGIN {printf \"%.3f\", $FADE_TIME / $STEPS}")

for ((i=1; i<=STEPS; i++)); do
    # Check if GStreamer pipeline still running
    if [ -f "$GST_PID_FILE" ]; then
        gst_pid=$(cat "$GST_PID_FILE")
        if ! kill -0 "$gst_pid" 2>/dev/null; then
            log_message "[FADE] GStreamer pipeline stopped during fade"
            exit 0
        fi
    fi

    TARGET_VOL=$(( CURRENT_VOL - (CURRENT_VOL * i / STEPS) ))
    [ "$TARGET_VOL" -lt 0 ] && TARGET_VOL=0

    set_node_volume "$NODE_ID" "$TARGET_VOL"
    sleep "$INTERVAL"
done

# Ensure final volume is 0
set_node_volume "$NODE_ID" 0
log_message "[FADE] Fade complete - volume at 0%"

exit 0
