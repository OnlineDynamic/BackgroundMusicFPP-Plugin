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

# Handle ALSA configuration restoration
echo ""
echo "============================================"
echo "ALSA Configuration Restoration"
echo "============================================"

if [ -f "/etc/asound.conf" ] && grep -q "Background Music Plugin" /etc/asound.conf; then
    echo "Found ALSA configuration created by this plugin."
    
    # Find the most recent backup that was created BEFORE the plugin's config
    LATEST_BACKUP=$(ls -t /etc/asound.conf.backup-* 2>/dev/null | head -n1)
    
    if [ -n "$LATEST_BACKUP" ]; then
        echo "Restoring original ALSA configuration from backup..."
        echo "Backup file: $LATEST_BACKUP"
        
        # Restore the backup
        cp "$LATEST_BACKUP" /etc/asound.conf
        
        echo "✓ ALSA configuration restored successfully"
        echo "✓ Software mixing (dmix) configuration removed"
        echo ""
        echo "IMPORTANT: Restart FPP for audio changes to take effect"
        echo "           (Status/Control → Restart FPPD or reboot system)"
    else
        echo "WARNING: No backup files found (/etc/asound.conf.backup-*)"
        echo "Unable to restore original ALSA configuration"
        echo "The current configuration will be left in place"
        echo ""
        echo "Manual restoration (if needed):"
        echo "  1. Check FPP's default audio settings"
        echo "  2. Remove /etc/asound.conf to use system defaults"
        echo "  3. Or manually configure ALSA for your audio device"
    fi
else
    echo "No plugin-specific ALSA configuration found"
    echo "ALSA configuration was not modified by this plugin or already restored"
fi

echo ""
echo "============================================"
echo "Uninstall Summary"
echo "============================================"
echo "✓ Background music player stopped"
echo "✓ PSA announcement system stopped"
echo "✓ Temporary files cleaned up"

if [ -f "/etc/asound.conf" ] && ! grep -q "Background Music Plugin" /etc/asound.conf; then
    echo "✓ ALSA configuration restored from backup"
    echo ""
    echo "IMPORTANT: Restart FPP for audio changes to take effect"
elif [ -f "/etc/asound.conf" ] && grep -q "Background Music Plugin" /etc/asound.conf; then
    echo "⚠ ALSA configuration could not be automatically restored"
    echo "  Manual restoration may be required if audio issues occur"
    echo "  Backup files: /etc/asound.conf.backup-*"
fi

echo ""
echo "Note: System packages (jq, mpg123, ffmpeg) were left installed"
echo "      as other plugins or FPP features may use them"
echo ""
echo "Background Music Plugin uninstalled successfully"

