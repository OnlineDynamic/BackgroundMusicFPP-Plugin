#!/bin/bash
##########################################################################
# start_show_transition.sh - Fade out background and start main show
# 
# This script:
# 1. Gradually reduces brightness from current to 0
# 2. Fades out audio volume from current to 0
# 3. Stops all running playlists
# 4. Waits for blackout period
# 5. Restores brightness to previous level
# 6. Starts the configured show playlist
##########################################################################

FADE_TIME=${1:-5}        # Fade time in seconds (default 5)
BLACKOUT_TIME=${2:-2}    # Blackout time in seconds (default 2)
SHOW_PLAYLIST=${3:-""}   # Show playlist to start

PLUGIN_CONFIG="/home/fpp/media/config/plugin.fpp-plugin-BackgroundMusic"
LOG_FILE="/home/fpp/media/logs/fpp-plugin-BackgroundMusic.log"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

log_message "Starting show transition: fade=$FADE_TIME sec, blackout=$BLACKOUT_TIME sec, show=$SHOW_PLAYLIST"

# Get current brightness setting (will restore this later)
ORIGINAL_BRIGHTNESS=$(curl -s "http://localhost/api/system/brightness" | jq -r '.brightness' 2>/dev/null)
if [ -z "$ORIGINAL_BRIGHTNESS" ] || [ "$ORIGINAL_BRIGHTNESS" = "false" ]; then
    ORIGINAL_BRIGHTNESS=100
fi

log_message "Original brightness: $ORIGINAL_BRIGHTNESS%"

# Get current volume level from background music player
ORIGINAL_VOLUME=$(grep "^VolumeLevel=" "$PLUGIN_CONFIG" 2>/dev/null | cut -d'=' -f2 | tr -d '\r')
if [ -z "$ORIGINAL_VOLUME" ]; then
    ORIGINAL_VOLUME=70
fi

log_message "Original volume: ${ORIGINAL_VOLUME}%"

# Start audio fade in background (will fade over FADE_TIME seconds)
SCRIPT_DIR="$(dirname "$0")"
if [ -f "/tmp/background_music_player.pid" ]; then
    log_message "Starting audio fade"
    /bin/bash "$SCRIPT_DIR/fade_audio.sh" "$FADE_TIME" &
    FADE_AUDIO_PID=$!
fi

# Fade out brightness using Brightness plugin's native fade (supports MultiSync)
# Convert seconds to milliseconds for the API
FADE_TIME_MS=$((FADE_TIME * 1000))
log_message "Fading brightness to 0% over ${FADE_TIME}s using Brightness plugin FadeDown"
curl -s -X GET "http://localhost/api/plugin-apis/Brightness/FadeDown/$FADE_TIME_MS" > /dev/null 2>&1

# Wait for fade to complete
sleep "$FADE_TIME"

# Wait for audio fade to complete if it's still running
if [ -n "$FADE_AUDIO_PID" ]; then
    wait "$FADE_AUDIO_PID" 2>/dev/null
fi

log_message "Brightness faded to 0%"

# Ensure background music is stopped
if [ -f "/tmp/background_music_player.pid" ]; then
    log_message "Stopping background music player"
    SCRIPT_DIR="$(dirname "$0")"
    /bin/bash "$SCRIPT_DIR/background_music_player.sh" stop >> "$LOG_FILE" 2>&1
else
    log_message "No background music PID file found, checking for orphaned processes"
fi

# Kill any remaining ffplay processes (orphaned or not properly stopped)
if pgrep -f "ffplay.*\.mp3" > /dev/null 2>&1; then
    log_message "Found running ffplay processes - killing them"
    pkill -f "ffplay.*\.mp3" 2>/dev/null
    sleep 1
fi

# Get the Show Playlist Volume setting
SHOW_PLAYLIST_VOLUME=$(grep "^ShowPlaylistVolume=" "$PLUGIN_CONFIG" 2>/dev/null | cut -d'=' -f2 | tr -d '\r')
if [ -z "$SHOW_PLAYLIST_VOLUME" ]; then
    # Default to FPP's configured volume if not set
    SHOW_PLAYLIST_VOLUME=$(grep "^volume = " /home/fpp/media/settings | sed 's/volume = "\(.*\)"/\1/')
    SHOW_PLAYLIST_VOLUME=${SHOW_PLAYLIST_VOLUME:-75}
fi

log_message "Setting volume to ${SHOW_PLAYLIST_VOLUME}% for show playlist via FPP API"

# Use FPP's API to set volume so the UI updates correctly
curl -s -X POST -H "Content-Type: application/json" -d "{\"volume\": ${SHOW_PLAYLIST_VOLUME}}" "http://localhost/api/system/volume" > /dev/null 2>&1

log_message "Volume set to ${SHOW_PLAYLIST_VOLUME}% for show playback"

# Wait for audio device to be fully released
sleep 1

# Stop all FPP playlists (sequences)
log_message "Stopping all playlists"
curl -s -X GET "http://localhost/api/playlists/stop" > /dev/null 2>&1

# Blackout period
if [ "$BLACKOUT_TIME" -gt 0 ]; then
    log_message "Blackout for $BLACKOUT_TIME seconds"
    sleep "$BLACKOUT_TIME"
fi

# Restore original brightness using Brightness plugin
log_message "Restoring brightness to $ORIGINAL_BRIGHTNESS% using Brightness plugin"
curl -s -X GET "http://localhost/api/plugin-apis/Brightness/$ORIGINAL_BRIGHTNESS" > /dev/null 2>&1

# Start the show playlist
if [ -n "$SHOW_PLAYLIST" ]; then
    log_message "Starting show playlist: $SHOW_PLAYLIST"
    # Use FPP's command API to start the playlist
    curl -s -X POST "http://localhost/api/command" \
        -H "Content-Type: application/json" \
        -d "{\"command\":\"Start Playlist\",\"args\":[\"${SHOW_PLAYLIST}\",false,false]}" > /dev/null 2>&1
    
    # Verify it started
    sleep 2
    PLAYLIST_STATUS=$(curl -s "http://localhost/api/fppd/status" | jq -r '.current_playlist.playlist' 2>/dev/null)
    if [ "$PLAYLIST_STATUS" = "$SHOW_PLAYLIST" ]; then
        log_message "Show playlist started successfully - now playing: $SHOW_PLAYLIST"
    else
        log_message "WARNING: Show playlist may not have started correctly. Current: $PLAYLIST_STATUS"
    fi
    
    # Start monitor for show completion (for return-to-preshow feature)
    SCRIPT_DIR="$(dirname "$0")"
    nohup /bin/bash "$SCRIPT_DIR/monitor_show_completion.sh" "$SHOW_PLAYLIST" >> "$LOG_FILE" 2>&1 &
    log_message "Show completion monitor started"
else
    log_message "ERROR: No show playlist specified"
fi

log_message "Show transition complete"
