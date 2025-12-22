#!/bin/bash
##########################################################################
# monitor_show_completion.sh - Monitor for show playlist completion
# 
# This script runs in the background to monitor the show playlist.
# When it detects the show playlist has ended, it triggers the
# return-to-preshow callback if enabled.
##########################################################################

SHOW_PLAYLIST="$1"
PLUGIN_CONFIG="/home/fpp/media/config/plugin.fpp-plugin-BackgroundMusic"
LOG_FILE="/home/fpp/media/logs/fpp-plugin-BackgroundMusic.log"
MONITOR_PID_FILE="/tmp/show_monitor.pid"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Check if another monitor is already running
if [ -f "$MONITOR_PID_FILE" ]; then
    OLD_PID=$(cat "$MONITOR_PID_FILE" 2>/dev/null)
    if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
        log_message "Monitor already running with PID $OLD_PID - stopping old monitor first"
        kill -TERM "$OLD_PID" 2>/dev/null
        sleep 0.5
        # Force kill if still running
        if kill -0 "$OLD_PID" 2>/dev/null; then
            kill -9 "$OLD_PID" 2>/dev/null
        fi
    fi
fi

# Store our PID
echo $$ > "$MONITOR_PID_FILE"

log_message "Starting show completion monitor for playlist: $SHOW_PLAYLIST"

# Wait a bit for the show to actually start
sleep 5

# Monitor the FPP status
SHOW_RUNNING=true
while [ "$SHOW_RUNNING" = "true" ]; do
    # Get current FPP status
    STATUS=$(curl -s "http://localhost/api/fppd/status")
    CURRENT_PLAYLIST=$(echo "$STATUS" | jq -r '.current_playlist.playlist // ""')
    FPP_STATUS=$(echo "$STATUS" | jq -r '.status_name // ""')
    
    # Check if show playlist is still running
    if [ "$CURRENT_PLAYLIST" != "$SHOW_PLAYLIST" ] || [ "$FPP_STATUS" = "idle" ]; then
        log_message "Show playlist completed or stopped"
        SHOW_RUNNING=false
    else
        # Still running, wait before checking again
        sleep 2
    fi
done

# Show has ended, trigger return to pre-show if enabled
SCRIPT_DIR="$(dirname "$0")"
/bin/bash "$SCRIPT_DIR/return_to_preshow.sh" &

# Clean up our PID file
rm -f "$MONITOR_PID_FILE"

log_message "Show monitor exiting"

exit 0
