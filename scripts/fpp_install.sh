#!/bin/bash

# fpp-plugin-backgroundmusic install script (FPP 10+ / PipeWire+GStreamer)

BASEDIR=$(dirname "$0")
cd "$BASEDIR"
cd ..
PLUGIN_DIR=$(pwd)

# Check if this is an upgrade
IS_UPGRADE=0
if [ -f "/home/fpp/media/config/plugin.fpp-plugin-BackgroundMusic" ]; then
    IS_UPGRADE=1
    echo "=========================================="
    echo "Upgrading Background Music Plugin"
    echo "=========================================="

    # Clean up old bgmplayer/ffplay processes from previous versions
    echo "Cleaning up old processes..."
    pkill -f "bgmplayer" 2>/dev/null || true
    pkill -f "ffplay" 2>/dev/null || true
    pkill -f "node.name=bgmusic_" 2>/dev/null || true
    rm -f /tmp/bg_music_ffplay.pid /tmp/bg_music_ffplay_next.pid 2>/dev/null
    rm -f /tmp/bg_music_bgmplayer.pid /tmp/bg_music_bgmplayer_next.pid 2>/dev/null
    echo "Old processes cleaned up"

    # Clean up old per-user PipeWire config (no longer needed — system service)
    rm -f /home/fpp/.config/pipewire/pipewire.conf.d/99-backgroundmusic.conf 2>/dev/null
    rm -f /home/fpp/.config/wireplumber/main.lua.d/51-fpp-audio.lua 2>/dev/null
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

# jq is required for PipeWire node queries and config parsing
sudo apt-get -y install jq

# GStreamer plugins for stream playback (souphttpsrc for HTTP streams)
echo "Installing GStreamer plugins..."
sudo apt-get -y install gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly
sudo apt-get -y install gstreamer1.0-pipewire

echo "=========================================="

# Verify FPP 10 audio stack is available
echo "Verifying FPP 10 audio stack..."
ERRORS=0

if ! command -v gst-launch-1.0 &>/dev/null; then
    echo "✗ ERROR: gst-launch-1.0 not found"
    ERRORS=$((ERRORS + 1))
else
    echo "✓ GStreamer available: $(gst-launch-1.0 --version | head -1)"
fi

if ! command -v wpctl &>/dev/null; then
    echo "✗ ERROR: wpctl not found (WirePlumber)"
    ERRORS=$((ERRORS + 1))
else
    echo "✓ WirePlumber available"
fi

if systemctl is-active --quiet fpp-pipewire.service 2>/dev/null; then
    echo "✓ fpp-pipewire.service is running"
else
    echo "⚠ WARNING: fpp-pipewire.service is not running"
    echo "  Background music requires PipeWire to be enabled in FPP settings"
fi

if [ -S "/run/pipewire-fpp/pipewire-0" ]; then
    echo "✓ PipeWire socket available at /run/pipewire-fpp/pipewire-0"
else
    echo "⚠ WARNING: PipeWire socket not found at /run/pipewire-fpp/pipewire-0"
    echo "  Enable PipeWire in FPP settings and restart"
fi

if [ $ERRORS -gt 0 ]; then
    echo ""
    echo "✗ $ERRORS critical dependency missing — plugin may not work correctly"
fi

# Ensure helper scripts are executable
echo "Setting permissions on helper scripts..."
chmod +x "$PLUGIN_DIR/scripts"/*.sh 2>/dev/null
chown fpp:fpp "$PLUGIN_DIR/scripts"/*.sh 2>/dev/null

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
    echo "✓ Plugin now uses FPP 10's GStreamer + PipeWire audio stack"
    echo "✓ No more custom bgmplayer — uses gst-launch-1.0"
    echo "✓ Audio routes through system PipeWire (no more start/stop)"
    echo ""
    echo "ACTION REQUIRED:"
    echo "  1. Enable PipeWire in FPP Audio settings if not already"
    echo "  2. Stop and restart background music to use new engine"
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
# Clean up any old temp files from previous versions
rm -f /tmp/background_music*.log /tmp/background_music*.pid /tmp/bg_music*.pid 2>/dev/null
rm -f /tmp/bgmusic_gst*.pid /tmp/bgmplayer_*.txt 2>/dev/null
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
