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

# Clean up stale PipeWire sockets that might prevent startup after reboot
RUNTIME_DIR="/run/user/500"
if [ -d "$RUNTIME_DIR" ]; then
    # If pipewire sockets exist but no pipewire processes are running, clean them up
    if ls "$RUNTIME_DIR"/pipewire-* >/dev/null 2>&1; then
        if ! pgrep -u fpp pipewire >/dev/null 2>&1; then
            log_message "Cleaning up stale PipeWire sockets (no running processes)"
            rm -f "$RUNTIME_DIR"/pipewire-* 2>/dev/null
            rm -f "$RUNTIME_DIR/bus" 2>/dev/null
        fi
    fi
fi

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

# Run background_music_player.sh directly (it will use sudo internally where needed)
# Don't use su - fpp because start_pipewire.sh needs to run as root
if /bin/bash "$SCRIPT_DIR/background_music_player.sh" start >> "$LOG_FILE" 2>&1; then
    log_message "Background music autostart successful"
else
    log_message "Background music autostart failed"
fi

exit 0
