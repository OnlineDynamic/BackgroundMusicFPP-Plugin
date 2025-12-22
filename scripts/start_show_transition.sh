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

# Check if a show is already running - prevent double-triggering
CURRENT_STATUS=$(curl -s "http://localhost/api/fppd/status")
CURRENT_PLAYLIST=$(echo "$CURRENT_STATUS" | jq -r '.current_playlist.playlist // ""')
FPP_STATUS=$(echo "$CURRENT_STATUS" | jq -r '.status_name // ""')

if [ "$CURRENT_PLAYLIST" = "$SHOW_PLAYLIST" ] && [ "$FPP_STATUS" != "idle" ]; then
    log_message "WARNING: Show playlist '$SHOW_PLAYLIST' is already running - ignoring duplicate request"
    exit 0
fi

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

# Start fading brightness and bgmplayer volume in parallel
SCRIPT_DIR="$(dirname "$0")"
if [ -f "/tmp/background_music_player.pid" ]; then
    log_message "Starting bgmplayer volume fade (internal volume, not system)"
    /bin/bash "$SCRIPT_DIR/fade_bgmplayer.sh" >> "$LOG_FILE" 2>&1 &
    FADE_BGMPLAYER_PID=$!
fi

# Fade out brightness using Brightness plugin's native fade (supports MultiSync)
# Convert seconds to milliseconds for the API
FADE_TIME_MS=$((FADE_TIME * 1000))
log_message "Fading brightness to 0% over ${FADE_TIME}s using Brightness plugin FadeDown"
curl -s -X GET "http://localhost/api/plugin-apis/Brightness/FadeDown/$FADE_TIME_MS" > /dev/null 2>&1

# Wait for fade to complete
sleep "$FADE_TIME"

# Wait for bgmplayer volume fade to complete if it's still running
if [ -n "$FADE_BGMPLAYER_PID" ]; then
    wait "$FADE_BGMPLAYER_PID" 2>/dev/null
fi

log_message "Brightness and bgmplayer volume faded to 0%"

# Stop all FPP playlists (sequences) before stopping bgmplayer
log_message "Stopping all playlists"
curl -s -X GET "http://localhost/api/playlists/stop" > /dev/null 2>&1

# Now stop the background music player (it's at 0% volume so no audible artifacts)
if [ -f "/tmp/background_music_player.pid" ]; then
    PLAYER_PID=$(cat /tmp/background_music_player.pid 2>/dev/null)
    if [ -n "$PLAYER_PID" ] && kill -0 "$PLAYER_PID" 2>/dev/null; then
        log_message "Stopping bgmplayer (PID: $PLAYER_PID)"
        kill -TERM "$PLAYER_PID" 2>/dev/null
        sleep 0.3
        # Force kill if still running
        if kill -0 "$PLAYER_PID" 2>/dev/null; then
            kill -9 "$PLAYER_PID" 2>/dev/null
        fi
    fi
    # Clean up state files
    rm -f /tmp/background_music_player.pid /tmp/bg_music_state.txt /tmp/bg_music_status.txt /tmp/bgmplayer_${PLAYER_PID}_volume.txt
else
    log_message "No background music PID file found, checking for orphaned processes"
fi

# Kill any remaining bgmplayer processes (orphaned or not properly stopped)
if pgrep -f "bgmplayer" > /dev/null 2>&1; then
    log_message "Found running bgmplayer processes - killing them"
    pkill -f "bgmplayer" 2>/dev/null
    sleep 0.5
fi

# Also check for any lingering audio processes that might be holding the device
if pgrep -f "background_music_player.sh" > /dev/null 2>&1; then
    log_message "Found background_music_player.sh processes - killing them"
    pkill -f "background_music_player.sh" 2>/dev/null
    sleep 0.3
fi

# CRITICAL: Stop PipeWire to release the ALSA device for FPP's direct ALSA access
# The plugin uses PipeWire, but FPP uses ALSA directly (until FPP migrates to PipeWire)
# We must stop PipeWire completely so FPP can have exclusive ALSA access
log_message "Stopping PipeWire to release ALSA device for FPP's main show"
pkill -u fpp pipewire 2>/dev/null
pkill -u fpp pipewire-pulse 2>/dev/null
pkill -u fpp wireplumber 2>/dev/null
sleep 0.5

# Clean up PipeWire sockets to ensure complete release
FPP_UID=$(id -u fpp)
RUNTIME_DIR="/run/user/${FPP_UID}"
if [ -d "$RUNTIME_DIR" ]; then
    rm -f "$RUNTIME_DIR"/pipewire-* 2>/dev/null
    rm -rf "$RUNTIME_DIR/pulse" 2>/dev/null
fi

# Blackout period - wait for complete audio device release
# This ensures PipeWire has fully released the ALSA device before FPP tries to use it
if [ "$BLACKOUT_TIME" -gt 0 ]; then
    log_message "Blackout for $BLACKOUT_TIME seconds (allowing ALSA device to be fully released)"
    sleep "$BLACKOUT_TIME"
else
    # Even with 0 blackout, we need minimum time for PipeWire/ALSA cleanup
    # 0.5s is typically sufficient for process termination and kernel cleanup
    log_message "Minimum wait for PipeWire/ALSA cleanup (0.5s)"
    sleep 0.5
fi

# Verify ALSA device is available
log_message "Verifying ALSA device is ready for FPP"
for i in {1..5}; do
    if aplay -l > /dev/null 2>&1; then
        log_message "ALSA device ready after $i attempt(s)"
        break
    else
        log_message "ALSA device not ready, waiting... (attempt $i/5)"
        sleep 0.5
    fi
done

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
