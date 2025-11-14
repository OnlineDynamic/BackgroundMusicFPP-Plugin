#!/bin/bash
# FPP Command: Start Show with Background Music Integration
# Triggers the show transition (fade out background music, brightness transition, start show)
# Usage: start-show.sh [playlist_name]
# If no playlist_name provided, uses the configured ShowPlaylist setting

PLUGIN_CONFIG="/home/fpp/media/config/plugin.fpp-plugin-BackgroundMusic"
LOG_FILE="/home/fpp/media/logs/fpp-plugin-BackgroundMusic.log"

# Log function
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [Start Show Command] $1" >> "$LOG_FILE"
}

# Get the playlist/sequence name from argument or config
PLAYLIST_NAME="$1"

if [ -z "$PLAYLIST_NAME" ]; then
    # No argument provided, use configured ShowPlaylist
    if [ -f "$PLUGIN_CONFIG" ]; then
        PLAYLIST_NAME=$(grep "^ShowPlaylist=" "$PLUGIN_CONFIG" | cut -d'=' -f2- | tr -d '\r' | tr -d '"')
    fi
    
    if [ -z "$PLAYLIST_NAME" ]; then
        log_message "ERROR: No playlist specified and ShowPlaylist not configured"
        echo '{"status":"ERROR","message":"No playlist specified and ShowPlaylist not configured"}'
        exit 1
    fi
    log_message "Using configured ShowPlaylist: $PLAYLIST_NAME"
else
    log_message "Using command argument playlist: $PLAYLIST_NAME"
fi

# Validate that the playlist exists in playable playlists
PLAYLIST_EXISTS=$(curl -s "http://localhost/api/playlists/playable" | jq -r ".[] | select(. == \"$PLAYLIST_NAME\")")

if [ -z "$PLAYLIST_EXISTS" ]; then
    log_message "ERROR: Playlist '$PLAYLIST_NAME' not found"
    echo '{"status":"ERROR","message":"Playlist not found: '"$PLAYLIST_NAME"'"}'
    exit 1
fi

log_message "Starting show transition for playlist: $PLAYLIST_NAME"

# Trigger the show start via the plugin's API
RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d "{\"playlist\":\"$PLAYLIST_NAME\"}" \
    "http://localhost/api/plugin/fpp-plugin-BackgroundMusic/start-show")

# Check if the request was successful
STATUS=$(echo "$RESPONSE" | jq -r '.status')

if [ "$STATUS" = "OK" ]; then
    log_message "Show start successful: $PLAYLIST_NAME"
    echo "$RESPONSE"
    exit 0
else
    MESSAGE=$(echo "$RESPONSE" | jq -r '.message')
    log_message "Show start failed: $MESSAGE"
    echo "$RESPONSE"
    exit 1
fi
