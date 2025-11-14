#!/bin/bash

# fpp-plugin-backgroundmusic install script

BASEDIR=$(dirname "$0")
cd "$BASEDIR"
cd ..
PLUGIN_DIR=$(pwd)

# Check if this is an upgrade (ALSA config with our marker already exists)
IS_UPGRADE=0
if [ -f "/etc/asound.conf" ] && grep -q "Background Music Plugin" /etc/asound.conf; then
    IS_UPGRADE=1
    echo "=========================================="
    echo "Upgrading Background Music Plugin"
    echo "=========================================="
    
    # Clean up old ffplay processes and PID files from previous version
    echo "Cleaning up old processes..."
    pkill -f "ffplay" 2>/dev/null || true
    rm -f /tmp/bg_music_ffplay.pid 2>/dev/null || true
    rm -f /tmp/bg_music_ffplay_next.pid 2>/dev/null || true
    echo "Old processes cleaned up"
else
    echo "=========================================="
    echo "Installing Background Music Plugin"
    echo "=========================================="
fi

# Source FPP common functions if available
if [ -f "${FPPDIR}/scripts/common" ]; then
    . ${FPPDIR}/scripts/common
elif [ -f "/opt/fpp/scripts/common" ]; then
    . /opt/fpp/scripts/common
fi

# Install dependencies
echo "=========================================="
echo "Installing Dependencies"
echo "=========================================="

# Install jq utility for PSU Control script to work
sudo apt-get -y install jq

# Install build tools and libraries for custom audio player
echo "Installing build dependencies for bgmplayer..."
sudo apt-get -y install g++ make
sudo apt-get -y install libsdl2-dev
sudo apt-get -y install libavformat-dev libavcodec-dev libavutil-dev libswresample-dev

# Compile custom audio player
echo ""
echo "=========================================="
echo "Compiling Background Music Player"
echo "=========================================="
cd "$PLUGIN_DIR"
if make; then
    echo "✓ bgmplayer compiled successfully"
    # Make it executable
    chmod +x bgmplayer
else
    echo "⚠ WARNING: Failed to compile bgmplayer"
    echo "   Plugin requires bgmplayer for proper operation"
    echo "   Volume control will not work without it"
fi
echo "=========================================="

# Configure ALSA for software mixing (dmix) to allow concurrent audio streams
# This enables background music and PSA announcements to play simultaneously
echo ""
echo "=========================================="
echo "Configuring ALSA for software mixing support..."
echo "=========================================="

# Detect the audio card to use (prefer FPP's configured device)
AUDIO_CARD="0"
AUDIO_DEVICE="0"

# Try to read FPP's audio configuration
if [ -f "/home/fpp/media/settings" ]; then
    FPP_AUDIO_OUTPUT=$(grep "^AudioOutput = " /home/fpp/media/settings | sed 's/AudioOutput = "\(.*\)"/\1/')
    if [ -n "$FPP_AUDIO_OUTPUT" ]; then
        AUDIO_CARD="$FPP_AUDIO_OUTPUT"
        echo "Using FPP's configured audio card: $AUDIO_CARD"
    else
        echo "No audio output configured in FPP, using default card 0"
    fi
else
    echo "FPP settings file not found, using default card 0"
fi

# Check if this is an upgrade (existing config with our marker)
NEEDS_UPDATE=0
if [ -f "/etc/asound.conf" ]; then
    if grep -q "Background Music Plugin" /etc/asound.conf; then
        # Always update to ensure correct configuration
        echo "Updating ALSA configuration to latest version..."
        sudo cp /etc/asound.conf /etc/asound.conf.old-$(date +%Y%m%d-%H%M%S)
        NEEDS_UPDATE=1
    else
        # Backup non-plugin config
        sudo cp /etc/asound.conf /etc/asound.conf.backup-$(date +%Y%m%d-%H%M%S)
        echo "Backed up existing /etc/asound.conf"
        NEEDS_UPDATE=1
    fi
else
    # No config exists
    echo "Creating new ALSA configuration..."
    NEEDS_UPDATE=1
fi

# Create or update ALSA configuration with dmix support
if [ $NEEDS_UPDATE -eq 1 ]; then
    echo "Writing new ALSA configuration..."
    sudo tee /etc/asound.conf > /dev/null << EOF
# ALSA configuration for Background Music Plugin with software mixing support
# This enables multiple audio streams to play concurrently (background music + PSA announcements)
# Auto-generated during plugin installation/update
# Last updated: $(date)

pcm.dmixer {
    type dmix
    ipc_key 1024
    ipc_perm 0666
    slave {
        pcm "hw:${AUDIO_CARD},${AUDIO_DEVICE}"
        rate 48000
        channels 2
        format S16_LE
        period_time 0
        period_size 1024
        buffer_size 4096
    }
    bindings {
        0 0
        1 1
    }
}

pcm.!default {
    type plug
    slave.pcm "dmixer"
}

ctl.!default {
    type hw
    card ${AUDIO_CARD}
}
EOF

    echo "ALSA software mixing configured successfully for card ${AUDIO_CARD}"
    echo ""
    echo "IMPORTANT: If background music is currently playing, stop and restart it"
    echo "           for the new ALSA configuration to take effect."
else
    echo "ALSA configuration is current, no changes needed"
fi

echo "Note: If FPP's audio device is changed, re-run this install script or"
echo "      reinstall the plugin to update /etc/asound.conf"
echo "=========================================="

# Check if fpp-brightness plugin is installed (required for transitions with MultiSync support)
if [ ! -d "/home/fpp/media/plugins/fpp-brightness" ]; then
    echo "============================================"
    echo "fpp-brightness plugin not found!"
    echo "============================================"
    echo "The Background Music plugin requires the fpp-brightness plugin"
    echo "for brightness transitions with MultiSync support."
    echo ""
    echo "Attempting to install fpp-brightness plugin automatically..."
    echo ""
    
    # Try to install via git clone
    cd /home/fpp/media/plugins
    if git clone https://github.com/FalconChristmas/fpp-brightness.git; then
        echo "✓ fpp-brightness plugin cloned successfully"
        
        # Run its install script if it exists
        if [ -f "/home/fpp/media/plugins/fpp-brightness/install.sh" ]; then
            echo "Running fpp-brightness install script..."
            cd /home/fpp/media/plugins/fpp-brightness
            bash install.sh
            echo "✓ fpp-brightness plugin installed successfully"
        elif [ -f "/home/fpp/media/plugins/fpp-brightness/scripts/fpp_install.sh" ]; then
            echo "Running fpp-brightness install script..."
            cd /home/fpp/media/plugins/fpp-brightness
            bash scripts/fpp_install.sh
            echo "✓ fpp-brightness plugin installed successfully"
        else
            echo "✓ fpp-brightness plugin downloaded (no install script found)"
        fi
        
        echo ""
        echo "IMPORTANT: Install fpp-brightness on ALL other controllers"
        echo "           in your MultiSync setup via Plugin Manager"
        echo "============================================"
    else
        echo "✗ Failed to automatically install fpp-brightness plugin"
        echo ""
        echo "Please install manually on ALL controllers:"
        echo "  Plugin Manager -> Install Plugins -> fpp-brightness"
        echo "  Or: https://github.com/FalconChristmas/fpp-brightness"
        echo "============================================"
    fi
    
    # Return to plugin directory
    cd "$PLUGIN_DIR"
    sleep 3
fi

# Show upgrade-specific messages
if [ $IS_UPGRADE -eq 1 ]; then
    echo ""
    echo "=========================================="
    echo "Plugin Upgraded Successfully"
    echo "=========================================="
    echo ""
    echo "IMPORTANT UPGRADE NOTES:"
    echo "------------------------"
    echo "✓ ALSA audio configuration updated for software mixing"
    echo "✓ PSA announcement system now available"
    echo ""
    echo "ACTION REQUIRED:"
    echo "If background music is currently running:"
    echo "  1. Stop background music"
    echo "  2. Wait 2-3 seconds"
    echo "  3. Start background music"
    echo ""
    echo "This applies the new ALSA configuration for PSA support."
    echo "=========================================="
else
    echo ""
    echo "=========================================="
    echo "Plugin Installed Successfully"
    echo "=========================================="
fi

# Create log files with proper permissions
LOG_FILE="/home/fpp/media/logs/fpp-plugin-BackgroundMusic.log"
PLAYER_LOG="/tmp/background_music_player.log"

if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
    chown fpp:fpp "$LOG_FILE"
    chmod 664 "$LOG_FILE"
    echo "Created log file: $LOG_FILE"
fi

if [ ! -f "$PLAYER_LOG" ]; then
    touch "$PLAYER_LOG"
    chown fpp:fpp "$PLAYER_LOG"
    chmod 664 "$PLAYER_LOG"
    echo "Created player log file: $PLAYER_LOG"
else
    # Fix ownership if file exists but has wrong owner
    chown fpp:fpp "$PLAYER_LOG" 2>/dev/null
    chmod 664 "$PLAYER_LOG" 2>/dev/null
fi

# Clean up any temp files with wrong permissions (from older versions or manual testing)
echo "Cleaning up temporary files..."
rm -f /tmp/bg_music_jump.txt /tmp/bg_music_next.txt /tmp/bg_music_previous.txt 2>/dev/null

# Copy stream presets example file if it doesn't exist
STREAM_PRESETS="${PLUGIN_DIR}/stream_presets.json"
STREAM_PRESETS_EXAMPLE="${PLUGIN_DIR}/stream_presets.json.example"

if [ ! -f "$STREAM_PRESETS" ] && [ -f "$STREAM_PRESETS_EXAMPLE" ]; then
    echo "Creating stream presets configuration..."
    cp "$STREAM_PRESETS_EXAMPLE" "$STREAM_PRESETS"
    chown fpp:fpp "$STREAM_PRESETS"
    chmod 664 "$STREAM_PRESETS"
    echo "Stream presets file created: $STREAM_PRESETS"
fi

# Set restart flag if setSetting function is available
if command -v setSetting &> /dev/null; then
    setSetting restartFlag 1
fi

# Create symlink for header indicator JavaScript
echo "Setting up header indicator..."
HEADER_JS="${PLUGIN_DIR}/header-indicator.js"
WEB_JS_DIR="/opt/fpp/www/js"
WEB_JS_LINK="${WEB_JS_DIR}/fpp-plugin-backgroundmusic-indicator.js"

# Create the js directory if it doesn't exist
if [ ! -d "$WEB_JS_DIR" ]; then
    mkdir -p "$WEB_JS_DIR"
fi

# Create symlink if it doesn't exist or update it
if [ -L "$WEB_JS_LINK" ]; then
    rm -f "$WEB_JS_LINK"
fi

if [ -f "$HEADER_JS" ]; then
    ln -s "$HEADER_JS" "$WEB_JS_LINK"
    echo "Header indicator installed: $WEB_JS_LINK"
else
    echo "Warning: header-indicator.js not found at $HEADER_JS"
fi
