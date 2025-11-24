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
sudo apt-get -y install ffmpeg

# Install PipeWire stack for reliable mixed audio playback
echo "Installing PipeWire audio stack..."
sudo apt-get -y install pipewire pipewire-pulse pipewire-alsa wireplumber

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

# Ensure helper scripts are executable
# Scripts will be executed by root via sudo, but can be owned by fpp for easy editing
echo "Setting permissions on helper scripts..."
chmod +x "$PLUGIN_DIR/scripts"/*.sh 2>/dev/null
chown fpp:fpp "$PLUGIN_DIR/scripts"/*.sh 2>/dev/null

# Create per-user PipeWire config for the fpp user
PIPEWIRE_CONF_DIR="/home/fpp/.config/pipewire/pipewire.conf.d"
sudo -u fpp mkdir -p "$PIPEWIRE_CONF_DIR"
cat <<'EOF' | sudo tee "$PIPEWIRE_CONF_DIR/99-backgroundmusic.conf" > /dev/null
context.properties = {
    default.clock.rate = 48000
    default.clock.quantum = 2048
    default.clock.min-quantum = 1024
    default.clock.max-quantum = 8192
}
EOF
sudo chown fpp:fpp "$PIPEWIRE_CONF_DIR/99-backgroundmusic.conf"
sudo chmod 644 "$PIPEWIRE_CONF_DIR/99-backgroundmusic.conf"

echo "PipeWire configuration written to $PIPEWIRE_CONF_DIR/99-backgroundmusic.conf"

# Ensure WirePlumber config directory exists with proper permissions
WIREPLUMBER_CONF_DIR="/home/fpp/.config/wireplumber/main.lua.d"
sudo -u fpp mkdir -p "$WIREPLUMBER_CONF_DIR"
sudo chown -R fpp:fpp /home/fpp/.config/wireplumber
sudo chmod -R 755 /home/fpp/.config/wireplumber

# Ensure /run/user/500 exists with proper permissions for PipeWire runtime
if [ ! -d "/run/user/500" ]; then
    echo "Creating /run/user/500 for PipeWire runtime..."
    sudo mkdir -p /run/user/500
    sudo chown fpp:fpp /run/user/500
    sudo chmod 700 /run/user/500
fi

# Start/refresh PipeWire stack so new settings take effect
echo "Starting PipeWire services..."
if /home/fpp/media/plugins/fpp-plugin-BackgroundMusic/scripts/start_pipewire.sh; then
    echo "✓ PipeWire stack started for fpp user"
else
    echo "⚠ WARNING: PipeWire start script encountered an error"
    echo "  Check /tmp/pipewire*.log for details"
fi

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

# Plugin log file in /home/fpp/media/logs should be owned by fpp for web UI access
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
    chown fpp:fpp "$LOG_FILE"
    chmod 664 "$LOG_FILE"
    echo "Created log file: $LOG_FILE"
fi

# Temporary log files in /tmp will be created by root at runtime - no need to pre-create
# Clean up any old temp files
rm -f /tmp/background_music*.log /tmp/background_music*.pid /tmp/bg_music*.pid 2>/dev/null
echo "Cleaned up temporary files"

# Clean up any temp files from previous versions or manual testing
echo "Cleaning up control files..."
rm -f /tmp/bg_music_jump.txt /tmp/bg_music_next.txt /tmp/bg_music_previous.txt 2>/dev/null
rm -f /tmp/bg_music_status.txt /tmp/bg_music_state.txt 2>/dev/null

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

echo ""
echo "Installation/Upgrade complete!"
echo ""
