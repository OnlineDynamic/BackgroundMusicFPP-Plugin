#!/bin/bash
# FPP postStart hook for Background Music Plugin
# This script is called after FPP starts up
# Handles autostart of background music if enabled

PLUGIN_CONFIG="/home/fpp/media/config/plugin.fpp-plugin-BackgroundMusic"
LOG_FILE="/home/fpp/media/logs/fpp-plugin-BackgroundMusic.log"

# Log function
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [postStart] $1" >> "$LOG_FILE"
}

log_message "FPP postStart hook triggered"

# Check if plugin is configured
if [ ! -f "$PLUGIN_CONFIG" ]; then
    log_message "Plugin not configured, skipping autostart"
    exit 0
fi

# Read autostart setting
AUTOSTART_ENABLED=$(grep "^AutostartEnabled=" "$PLUGIN_CONFIG" | cut -d'=' -f2- | tr -d '\r' | tr -d '"')

if [ "$AUTOSTART_ENABLED" != "1" ]; then
    log_message "Autostart not enabled, skipping"
    exit 0
fi

# Give FPP a moment to fully initialize
log_message "Autostart enabled, waiting 5 seconds for FPP to fully initialize..."
sleep 5

# Start background music as fpp user
SCRIPT_DIR="$(dirname "$0")"
log_message "Starting background music via autostart..."

# Run as fpp user to avoid permission issues
if su - fpp -c "/bin/bash '$SCRIPT_DIR/background_music_player.sh' start" >> "$LOG_FILE" 2>&1; then
    log_message "Background music autostart successful"
else
    log_message "Background music autostart failed"
fi

exit 0
