#!/bin/bash
##########################################################################
# return_to_preshow.sh - Callback when show playlist ends
# 
# This script is triggered when the main show playlist completes.
# If the "Return to Pre-Show" setting is enabled, it will:
# 1. Restart the background music player
# 2. Let FPP scheduler resume control of the pre-show sequence
##########################################################################

PLUGIN_CONFIG="/home/fpp/media/config/plugin.fpp-plugin-BackgroundMusic"
LOG_FILE="/home/fpp/media/logs/fpp-plugin-BackgroundMusic.log"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

log_message "Show playlist ended - checking return to pre-show setting"

# Check if plugin is configured
if [ ! -f "$PLUGIN_CONFIG" ]; then
    log_message "Plugin not configured, exiting"
    exit 0
fi

# Read the ReturnToPreShow setting
RETURN_TO_PRESHOW=$(grep "^ReturnToPreShow=" "$PLUGIN_CONFIG" | cut -d'=' -f2 | tr -d '\r')

if [ "$RETURN_TO_PRESHOW" != "1" ]; then
    log_message "Return to pre-show disabled, exiting"
    exit 0
fi

log_message "Return to pre-show enabled - restarting background music"

# Read the PostShowDelay setting
POST_SHOW_DELAY=$(grep "^PostShowDelay=" "$PLUGIN_CONFIG" | cut -d'=' -f2 | tr -d '\r')

# Default to 0 if not set
if [ -z "$POST_SHOW_DELAY" ]; then
    POST_SHOW_DELAY=0
fi

# Wait for the configured delay
if [ "$POST_SHOW_DELAY" -gt 0 ]; then
    log_message "Waiting ${POST_SHOW_DELAY} seconds before restarting background music"
    sleep "$POST_SHOW_DELAY"
fi

# Read the PostShowBackgroundVolume setting
POST_SHOW_VOLUME=$(grep "^PostShowBackgroundVolume=" "$PLUGIN_CONFIG" | cut -d'=' -f2 | tr -d '\r')

# Default to BackgroundMusicVolume or VolumeLevel if not set
if [ -z "$POST_SHOW_VOLUME" ]; then
    POST_SHOW_VOLUME=$(grep "^BackgroundMusicVolume=" "$PLUGIN_CONFIG" | cut -d'=' -f2 | tr -d '\r')
fi

if [ -z "$POST_SHOW_VOLUME" ]; then
    POST_SHOW_VOLUME=$(grep "^VolumeLevel=" "$PLUGIN_CONFIG" | cut -d'=' -f2 | tr -d '\r')
fi

# Default to 70 if still not found
POST_SHOW_VOLUME=${POST_SHOW_VOLUME:-70}

# Note: We do NOT set ALSA volume here. The background_music_player.sh script
# will set ALSA volume when it starts mpg123, which needs direct ALSA control.
# This allows FPP's volume slider to work properly when sequences are running.
log_message "Post-show background music volume will be set to ${POST_SHOW_VOLUME}% when player starts"

# Update the volume in config for the background music player to use
sed -i "s/^VolumeLevel=.*/VolumeLevel=$POST_SHOW_VOLUME/" "$PLUGIN_CONFIG"
sed -i "s/^BackgroundMusicVolume=.*/BackgroundMusicVolume=$POST_SHOW_VOLUME/" "$PLUGIN_CONFIG"

# Restart background music player
SCRIPT_DIR="$(dirname "$0")"
/bin/bash "$SCRIPT_DIR/background_music_player.sh" start >> "$LOG_FILE" 2>&1

if [ $? -eq 0 ]; then
    log_message "Background music restarted successfully"
else
    log_message "ERROR: Failed to restart background music"
fi

# FPP scheduler will automatically resume the pre-show sequence playlist
# based on its schedule configuration - no need to start it here

log_message "Return to pre-show complete"

exit 0
