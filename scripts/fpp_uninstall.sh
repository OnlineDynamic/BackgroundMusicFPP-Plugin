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
rm -f /tmp/bg_music_status.txt /tmp/bg_music_state.txt
rm -f /tmp/bgmusic_gst.pid /tmp/bgmusic_gst_next.pid /tmp/bgmusic_volume.txt
rm -f /tmp/announcement_player.pid
rm -f /tmp/announcement_status.txt
rm -f /tmp/bg_music_jump.txt /tmp/bg_music_next.txt /tmp/bg_music_previous.txt
rm -f /tmp/bg_music_reorder.txt /tmp/bg_music_metadata.pid

# Kill any remaining GStreamer pipelines from this plugin
pkill -f "node.name=bgmusic_" 2>/dev/null || true

# Remove header indicator symlink
echo "Removing header indicator..."
WEB_JS_LINK="/opt/fpp/www/js/fpp-plugin-backgroundmusic-indicator.js"
if [ -L "$WEB_JS_LINK" ]; then
    rm -f "$WEB_JS_LINK"
    echo "Header indicator removed"
fi

echo ""
echo "============================================"
echo "Uninstall Summary"
echo "============================================"
echo "✓ Background music player stopped"
echo "✓ PSA announcement system stopped"
echo "✓ GStreamer pipelines terminated"
echo "✓ Temporary files cleaned up"

echo ""
echo "Note: PipeWire is managed by FPP and was not modified."
echo "Note: System packages (jq, gstreamer) were left installed"
echo "      as other plugins or FPP features may use them"
echo ""
echo "Background Music Plugin uninstalled successfully"

