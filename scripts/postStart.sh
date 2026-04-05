#!/bin/bash
# FPP postStart hook for Background Music Plugin
# FPP 10 version: PipeWire is managed by fpp-pipewire.service

SCRIPT_DIR="$(dirname "$0")"
. "$SCRIPT_DIR/pw_env.sh"

log_message "[postStart] FPP postStart hook triggered"

# Check if plugin is configured
if [ ! -f "$PLUGIN_CONFIG" ]; then
    log_message "[postStart] Plugin not configured, skipping autostart"
    exit 0
fi

# Read autostart setting
AUTOSTART_ENABLED=$(get_plugin_setting "AutostartEnabled" "0")

if [ "$AUTOSTART_ENABLED" != "1" ]; then
    log_message "[postStart] Autostart not enabled, skipping"
    exit 0
fi

# Verify PipeWire socket is available
if [ ! -S "/run/pipewire-fpp/pipewire-0" ]; then
    log_message "[postStart] WARNING: PipeWire socket not found, waiting..."
    for i in {1..10}; do
        sleep 1
        [ -S "/run/pipewire-fpp/pipewire-0" ] && break
    done
    if [ ! -S "/run/pipewire-fpp/pipewire-0" ]; then
        log_message "[postStart] ERROR: PipeWire socket still not available"
        exit 1
    fi
fi

# Give FPP a moment to fully initialize
log_message "[postStart] Autostart enabled, waiting 5 seconds for FPP to initialize..."
sleep 5

log_message "[postStart] Starting background music via autostart..."
if /bin/bash "$SCRIPT_DIR/background_music_player.sh" start >> "$LOG_FILE" 2>&1; then
    log_message "[postStart] Background music autostart successful"
else
    log_message "[postStart] Background music autostart failed"
fi

exit 0
