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

# Clean up temporary files
rm -f /tmp/background_music_playlist.m3u
rm -f /tmp/bg_music_loop.sh
rm -f /tmp/bg_music_status.txt
rm -f /tmp/announcement_player.pid

# Note: We leave /etc/asound.conf in place as removing it might break other audio.
# If you want to restore the original ALSA configuration, you can manually:
#   1. Check for backups in /etc/asound.conf.backup-*
#   2. Restore with: sudo cp /etc/asound.conf.backup-YYYYMMDD-HHMMSS /etc/asound.conf
#   3. Restart FPP or reboot

echo "Background Music Plugin uninstalled successfully"
echo "Note: ALSA configuration (/etc/asound.conf) was left in place for safety"
echo "Check /etc/asound.conf.backup-* for original configuration if needed"

