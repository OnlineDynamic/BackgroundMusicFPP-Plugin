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

. /opt/fpp/scripts/common
. /opt/fpp/scripts/functions

FADE_TIME=${1:-5}        # Fade time in seconds (default 5)
BLACKOUT_TIME=${2:-2}    # Blackout time in seconds (default 2)
SHOW_PLAYLIST=${3:-""}   # Show playlist to start

PLUGIN_CONFIG="/home/fpp/media/config/plugin.fpp-plugin-BackgroundMusic"
LOG_FILE="/home/fpp/media/logs/fpp-plugin-BackgroundMusic.log"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

log_message "Starting show transition: fade=$FADE_TIME sec, blackout=$BLACKOUT_TIME sec, show=$SHOW_PLAYLIST"

# Get current brightness setting
ORIGINAL_BRIGHTNESS=$(getSetting brightness)
if [ -z "$ORIGINAL_BRIGHTNESS" ] || [ "$ORIGINAL_BRIGHTNESS" = "false" ]; then
    ORIGINAL_BRIGHTNESS=100
fi

log_message "Original brightness: $ORIGINAL_BRIGHTNESS%"

# Calculate fade steps (10 steps per second for smooth fade)
FADE_STEPS=$((FADE_TIME * 10))
BRIGHTNESS_STEP=$(echo "scale=2; $ORIGINAL_BRIGHTNESS / $FADE_STEPS" | bc)
SLEEP_TIME=$(echo "scale=3; $FADE_TIME / $FADE_STEPS" | bc)

log_message "Fade steps: $FADE_STEPS, brightness step: $BRIGHTNESS_STEP, sleep time: $SLEEP_TIME"

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

# Fade out brightness
CURRENT_BRIGHTNESS=$ORIGINAL_BRIGHTNESS

for ((i=1; i<=FADE_STEPS; i++)); do
    CURRENT_BRIGHTNESS=$(echo "$CURRENT_BRIGHTNESS - $BRIGHTNESS_STEP" | bc)
    
    # Ensure we don't go negative
    CURRENT_BRIGHTNESS_INT=$(echo "$CURRENT_BRIGHTNESS / 1" | bc)
    if [ "$CURRENT_BRIGHTNESS_INT" -lt 0 ]; then
        CURRENT_BRIGHTNESS_INT=0
    fi
    
    # Set brightness via API
    curl -s -X PUT "http://localhost/api/system/brightness/$CURRENT_BRIGHTNESS_INT" > /dev/null 2>&1
    
    sleep "$SLEEP_TIME"
done

# Wait for audio fade to complete if it's still running
if [ -n "$FADE_AUDIO_PID" ]; then
    wait "$FADE_AUDIO_PID" 2>/dev/null
fi

# Ensure brightness is at 0
curl -s -X PUT "http://localhost/api/system/brightness/0" > /dev/null 2>&1
log_message "Brightness faded to 0%"

# Ensure background music is stopped
if [ -f "/tmp/background_music_player.pid" ]; then
    log_message "Stopping background music player"
    SCRIPT_DIR="$(dirname "$0")"
    /bin/bash "$SCRIPT_DIR/background_music_player.sh" stop >> "$LOG_FILE" 2>&1
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

# Restore original brightness
log_message "Restoring brightness to $ORIGINAL_BRIGHTNESS%"
curl -s -X PUT "http://localhost/api/system/brightness/$ORIGINAL_BRIGHTNESS" > /dev/null 2>&1

# Start the show playlist
if [ -n "$SHOW_PLAYLIST" ]; then
    log_message "Starting show playlist: $SHOW_PLAYLIST"
    # Use FPP's playlist API to start the playlist
    curl -s -X GET "http://localhost/api/playlist/${SHOW_PLAYLIST}/start" > /dev/null 2>&1
    
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
