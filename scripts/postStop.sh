#!/bin/bash
##########################################################################
# postStop.sh - FPP Plugin Hook (runs when FPPD stops)
# FPP 10 version: clean up GStreamer pipelines, do NOT touch PipeWire
##########################################################################

SCRIPT_DIR="$(dirname "$0")"
. "$SCRIPT_DIR/pw_env.sh"

log_message "[postStop] FPPD stopped - cleaning up background music processes"

# Stop background music player gracefully
if [ -f "$SCRIPT_DIR/background_music_player.sh" ]; then
    log_message "[postStop] Stopping background music player"
    "$SCRIPT_DIR/background_music_player.sh" stop >> "$LOG_FILE" 2>&1
    sleep 0.5
fi

# Kill any remaining GStreamer pipelines from this plugin
kill_bgmusic_gst

# Kill orphaned scripts
for script in background_music_player.sh bg_music_loop.sh monitor_show_completion.sh return_to_preshow.sh; do
    if pgrep -f "$script" > /dev/null 2>&1; then
        log_message "[postStop] Cleaning up orphaned $script"
        pkill -f "$script" 2>/dev/null
        pkill -9 -f "$script" 2>/dev/null
    fi
done

# Clean up state files
log_message "[postStop] Cleaning up state files"
rm -f "$PID_FILE" /tmp/background_music_start.pid 2>/dev/null
rm -f /tmp/bg_music_loop.sh 2>/dev/null
rm -f "$STATUS_FILE" "$STATE_FILE" 2>/dev/null
rm -f "$GST_PID_FILE" "$GST_NEXT_PID_FILE" 2>/dev/null
rm -f /tmp/bg_music_jump.txt /tmp/bg_music_next.txt /tmp/bg_music_previous.txt 2>/dev/null
rm -f /tmp/bg_music_reorder.txt /tmp/bg_music_metadata.pid 2>/dev/null
rm -f "$VOLUME_FILE" /tmp/background_music_playlist.m3u 2>/dev/null
rm -f /tmp/show_monitor.pid 2>/dev/null

log_message "[postStop] Cleanup complete"
exit 0
