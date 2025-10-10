#!/bin/bash

# fpp-plugin-backgroundmusic install script

BASEDIR=$(dirname $0)
cd $BASEDIR
cd ..

make "SRCDIR=${SRCDIR}"

# Source FPP common functions if available
if [ -f "${FPPDIR}/scripts/common" ]; then
    . ${FPPDIR}/scripts/common
elif [ -f "/opt/fpp/scripts/common" ]; then
    . /opt/fpp/scripts/common
fi

# install jq utility for PSU Control script to work
sudo apt-get -y install jq

#install mpg123 for playing mp3 audio tracks
sudo apt-get -y install mpg123

# Configure ALSA for software mixing (dmix) to allow concurrent audio streams
# This enables background music and PSA announcements to play simultaneously
echo "Configuring ALSA for software mixing support..."

# Detect the audio card to use (prefer FPP's configured device)
AUDIO_CARD="0"
AUDIO_DEVICE="0"

# Try to read FPP's audio configuration
if [ -f "/home/fpp/media/settings" ]; then
    FPP_AUDIO_OUTPUT=$(grep "^AudioOutput = " /home/fpp/media/settings | sed 's/AudioOutput = "\(.*\)"/\1/')
    if [ -n "$FPP_AUDIO_OUTPUT" ]; then
        AUDIO_CARD="$FPP_AUDIO_OUTPUT"
        echo "Using FPP's configured audio card: $AUDIO_CARD"
    fi
fi

# Backup existing asound.conf if it exists and doesn't have our marker
if [ -f "/etc/asound.conf" ]; then
    if ! grep -q "Background Music Plugin" /etc/asound.conf; then
        cp /etc/asound.conf /etc/asound.conf.backup-$(date +%Y%m%d-%H%M%S)
        echo "Backed up existing /etc/asound.conf"
    fi
fi

# Create ALSA configuration with dmix support
cat > /etc/asound.conf << EOF
# ALSA configuration for Background Music Plugin with software mixing support
# This enables multiple audio streams to play concurrently (background music + PSA announcements)

pcm.!default {
    type plug
    slave.pcm "dmixer"
}

pcm.dmixer {
    type dmix
    ipc_key 1024
    slave {
        pcm "hw:${AUDIO_CARD},${AUDIO_DEVICE}"
        period_time 0
        period_size 1024
        buffer_size 4096
        rate 48000
    }
    bindings {
        0 0
        1 1
    }
}

ctl.!default {
    type hw
    card ${AUDIO_CARD}
}
EOF

echo "ALSA software mixing configured successfully for card ${AUDIO_CARD}"
echo "Note: If FPP's audio device is changed, re-run this install script or manually update /etc/asound.conf"

# Check if fpp-brightness plugin is installed (required for transitions with MultiSync support)
if [ ! -d "/home/fpp/media/plugins/fpp-brightness" ]; then
    echo "============================================"
    echo "WARNING: fpp-brightness plugin not found!"
    echo "============================================"
    echo "The Background Music plugin requires the fpp-brightness plugin"
    echo "for brightness transitions with MultiSync support."
    echo ""
    echo "Please install it on ALL controllers:"
    echo "  Plugin Manager -> Install Plugins -> fpp-brightness"
    echo "  Or: https://github.com/FalconChristmas/fpp-brightness"
    echo "============================================"
    sleep 3
fi

# Set restart flag if setSetting function is available
if command -v setSetting &> /dev/null; then
    setSetting restartFlag 1
fi

