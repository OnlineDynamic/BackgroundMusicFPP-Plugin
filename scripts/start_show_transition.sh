#!/bin/bash
##########################################################################
# start_show_transition.sh - Fade out background music and start main show
# FPP 10 version: PipeWire stays running (shared with fppd)
#
# Steps:
# 1. Fade brightness to 0
# 2. Fade bgmusic stream volume to 0
# 3. Stop background music GStreamer pipelines
# 4. Blackout period
# 5. Set show volume, restore brightness
# 6. Start show playlist
##########################################################################

FADE_TIME=${1:-5}
BLACKOUT_TIME=${2:-2}
SHOW_PLAYLIST=${3:-""}

SCRIPT_DIR="$(dirname "$0")"
. "$SCRIPT_DIR/pw_env.sh"

log_message "Starting show transition: fade=$FADE_TIME sec, blackout=$BLACKOUT_TIME sec, show=$SHOW_PLAYLIST"

# Prevent double-triggering
CURRENT_STATUS=$(curl -s "http://localhost/api/fppd/status")
CURRENT_PLAYLIST=$(echo "$CURRENT_STATUS" | jq -r '.current_playlist.playlist // ""')
FPP_STATUS=$(echo "$CURRENT_STATUS" | jq -r '.status_name // ""')

if [ "$CURRENT_PLAYLIST" = "$SHOW_PLAYLIST" ] && [ "$FPP_STATUS" != "idle" ]; then
    log_message "WARNING: Show playlist '$SHOW_PLAYLIST' already running - ignoring"
    exit 0
fi

# Save current brightness
ORIGINAL_BRIGHTNESS=$(curl -s "http://localhost/api/system/brightness" | jq -r '.brightness' 2>/dev/null)
[ -z "$ORIGINAL_BRIGHTNESS" ] || [ "$ORIGINAL_BRIGHTNESS" = "false" ] && ORIGINAL_BRIGHTNESS=100
log_message "Original brightness: $ORIGINAL_BRIGHTNESS%"

# Start bgmusic volume fade in background
if [ -f "$PID_FILE" ]; then
    log_message "Starting bgmusic stream volume fade"
    /bin/bash "$SCRIPT_DIR/fade_bgmusic.sh" >> "$LOG_FILE" 2>&1 &
    FADE_BGMUSIC_PID=$!
fi

# Fade brightness via Brightness plugin
FADE_TIME_MS=$((FADE_TIME * 1000))
log_message "Fading brightness to 0% over ${FADE_TIME}s"
curl -s -X GET "http://localhost/api/plugin-apis/Brightness/FadeDown/$FADE_TIME_MS" > /dev/null 2>&1

sleep "$FADE_TIME"

# Wait for bgmusic volume fade
if [ -n "$FADE_BGMUSIC_PID" ]; then
    wait "$FADE_BGMUSIC_PID" 2>/dev/null
fi
log_message "Brightness and bgmusic volume faded to 0%"

# Stop all FPP playlists
log_message "Stopping all playlists"
curl -s -X GET "http://localhost/api/playlists/stop" > /dev/null 2>&1

# Stop background music (GStreamer pipelines already at 0 volume)
if [ -f "$PID_FILE" ]; then
    log_message "Stopping background music player"
    /bin/bash "$SCRIPT_DIR/background_music_player.sh" stop >> "$LOG_FILE" 2>&1
fi

# Kill any orphaned loop scripts
pkill -f "bg_music_loop.sh" 2>/dev/null

# Blackout period
if [ "$BLACKOUT_TIME" -gt 0 ]; then
    log_message "Blackout for $BLACKOUT_TIME seconds"
    sleep "$BLACKOUT_TIME"
else
    sleep 0.3
fi

# Set show volume
SHOW_PLAYLIST_VOLUME=$(get_plugin_setting "ShowPlaylistVolume" "")
if [ -z "$SHOW_PLAYLIST_VOLUME" ]; then
    SHOW_PLAYLIST_VOLUME=$(grep "^volume = " /home/fpp/media/settings | sed 's/volume = "\(.*\)"/\1/')
    SHOW_PLAYLIST_VOLUME=${SHOW_PLAYLIST_VOLUME:-75}
fi

log_message "Setting show volume to ${SHOW_PLAYLIST_VOLUME}%"
curl -s -X POST -H "Content-Type: application/json" \
    -d "{\"volume\": ${SHOW_PLAYLIST_VOLUME}}" \
    "http://localhost/api/system/volume" > /dev/null 2>&1

# Restore brightness
log_message "Restoring brightness to $ORIGINAL_BRIGHTNESS%"
curl -s -X GET "http://localhost/api/plugin-apis/Brightness/$ORIGINAL_BRIGHTNESS" > /dev/null 2>&1

# Start show playlist
if [ -n "$SHOW_PLAYLIST" ]; then
    log_message "Starting show playlist: $SHOW_PLAYLIST"
    curl -s -X POST "http://localhost/api/command" \
        -H "Content-Type: application/json" \
        -d "{\"command\":\"Start Playlist\",\"args\":[\"${SHOW_PLAYLIST}\",false,false]}" > /dev/null 2>&1

    sleep 2
    PLAYLIST_STATUS=$(curl -s "http://localhost/api/fppd/status" | jq -r '.current_playlist.playlist' 2>/dev/null)
    if [ "$PLAYLIST_STATUS" = "$SHOW_PLAYLIST" ]; then
        log_message "Show playlist started: $SHOW_PLAYLIST"
    else
        log_message "WARNING: Show may not have started. Current: $PLAYLIST_STATUS"
    fi

    nohup /bin/bash "$SCRIPT_DIR/monitor_show_completion.sh" "$SHOW_PLAYLIST" >> "$LOG_FILE" 2>&1 &
    log_message "Show completion monitor started"
else
    log_message "ERROR: No show playlist specified"
fi

log_message "Show transition complete"
