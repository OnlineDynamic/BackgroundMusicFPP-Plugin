#!/bin/bash

# fpp-plugin-BackgroundMusic uninstall script

echo "Uninstalling Background Music Plugin..."

# Stop any running background music
if [ -f "/tmp/background_music_player.pid" ]; then
    PID=$(cat /tmp/background_music_player.pid)
    if ps -p "$PID" > /dev/null 2>&1; then
        echo "Stopping background music player..."
        kill "$PID" 2>/dev/null
        sleep 1
        kill -9 "$PID" 2>/dev/null
    fi
    rm -f /tmp/background_music_player.pid
fi

# Stop any running PSA announcements
if [ -f "/tmp/announcement_player.pid" ]; then
    PID=$(cat /tmp/announcement_player.pid)
    if ps -p "$PID" > /dev/null 2>&1; then
        echo "Stopping PSA announcement..."
        kill "$PID" 2>/dev/null
        sleep 1
        kill -9 "$PID" 2>/dev/null
    fi
    rm -f /tmp/announcement_player.pid
fi

# Clean up temporary files
echo "Cleaning up temporary files..."
rm -f /tmp/background_music_playlist.m3u
rm -f /tmp/bg_music_loop.sh
rm -f /tmp/bg_music_status.txt
rm -f /tmp/announcement_player.pid
rm -f /tmp/announcement_status.txt

# Remove header indicator symlink
echo "Removing header indicator..."
WEB_JS_LINK="/opt/fpp/www/js/fpp-plugin-backgroundmusic-indicator.js"
if [ -L "$WEB_JS_LINK" ]; then
    rm -f "$WEB_JS_LINK"
    echo "Header indicator removed"
fi

# Clean up PipeWire configuration
echo ""
echo "============================================"
echo "PipeWire Configuration Cleanup"
echo "============================================"

PIPEWIRE_CONF="/home/fpp/.config/pipewire/pipewire.conf.d/99-backgroundmusic.conf"
if [ -f "$PIPEWIRE_CONF" ]; then
    echo "Removing custom PipeWire configuration..."
    rm -f "$PIPEWIRE_CONF"
fi

# Restore previous /root/.asoundrc if we backed it up
if [ -f "/root/.asoundrc.backgroundmusic-backup" ]; then
    echo "Restoring /root/.asoundrc backup..."
    mv /root/.asoundrc.backgroundmusic-backup /root/.asoundrc
fi

echo ""
echo "============================================"
echo "Uninstall Summary"
echo "============================================"
echo "✓ Background music player stopped"
echo "✓ PSA announcement system stopped"
echo "✓ Temporary files cleaned up"
echo "✓ PipeWire overrides removed"

echo ""
echo "If audio problems persist, restart FPPD or reboot so ALSA/PipeWire reload"

echo ""
echo "Note: System packages (jq, mpg123, ffmpeg) were left installed"
echo "      as other plugins or FPP features may use them"
echo ""
echo "Background Music Plugin uninstalled successfully"

