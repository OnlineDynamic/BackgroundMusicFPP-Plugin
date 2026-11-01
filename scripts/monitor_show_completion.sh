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

# When enabled, ignore playlist-name changes (e.g. "Insert Random Item From Playlist"
# or nested playlists) and only treat the show as finished when FPP reports idle
RESUME_ONLY_WHEN_IDLE=$(grep "^ResumeOnlyWhenIdle=" "$PLUGIN_CONFIG" 2>/dev/null | cut -d'=' -f2 | tr -d '\r')
# Optional pre-show playlist or .fseq sequence; seeing it running also means the show has ended
PRESHOW_SEQUENCE=$(grep "^PreShowSequence=" "$PLUGIN_CONFIG" 2>/dev/null | cut -d'=' -f2- | tr -d '\r' | sed 's/^"//; s/"$//')

# Returns 0 if the configured pre-show playlist/sequence is currently running
is_preshow_running() {
    [ -n "$PRESHOW_SEQUENCE" ] || return 1
    [ "$1" = "$PRESHOW_SEQUENCE" ] && return 0
    [ "${2%.fseq}" = "${PRESHOW_SEQUENCE%.fseq}" ] && [ -n "$2" ] && return 0
    return 1
}

log_message "Starting show completion monitor for playlist: $SHOW_PLAYLIST"
if [ "$RESUME_ONLY_WHEN_IDLE" = "1" ]; then
    log_message "Resume only when FPP is idle - ignoring playlist name changes"
    if [ -n "$PRESHOW_SEQUENCE" ]; then
        log_message "Pre-show playlist/sequence '$PRESHOW_SEQUENCE' also marks the show as ended"
    fi
fi

# Wait a bit for the show to actually start
sleep 5

# Monitor the FPP status
SHOW_RUNNING=true
while [ "$SHOW_RUNNING" = "true" ]; do
    # Get current FPP status
    STATUS=$(curl -s --connect-timeout 3 --max-time 5 "http://localhost/api/fppd/status")
    CURRENT_PLAYLIST=$(echo "$STATUS" | jq -r '.current_playlist.playlist // ""')
    FPP_STATUS=$(echo "$STATUS" | jq -r '.status_name // ""')
    CURRENT_SEQUENCE=$(echo "$STATUS" | jq -r '.current_sequence // ""')
    
    # Check if show playlist is still running
    if [ "$RESUME_ONLY_WHEN_IDLE" = "1" ]; then
        if [ "$FPP_STATUS" = "idle" ]; then
            log_message "FPP is idle - show completed or stopped"
            SHOW_RUNNING=false
        elif is_preshow_running "$CURRENT_PLAYLIST" "$CURRENT_SEQUENCE"; then
            log_message "Pre-show '$PRESHOW_SEQUENCE' is running - show completed"
            SHOW_RUNNING=false
        else
            sleep 2
        fi
    elif [ "$CURRENT_PLAYLIST" != "$SHOW_PLAYLIST" ] || [ "$FPP_STATUS" = "idle" ]; then
        log_message "Show playlist completed or stopped"
        SHOW_RUNNING=false
    else
        # Still running, wait before checking again
        sleep 2
    fi
done

# Show has ended, trigger return to pre-show if enabled
SCRIPT_DIR="$(dirname "$0")"
/bin/bash "$SCRIPT_DIR/return_to_preshow.sh" "$SHOW_PLAYLIST" &

# Clean up our PID file
rm -f "$MONITOR_PID_FILE"

log_message "Show monitor exiting"

exit 0
