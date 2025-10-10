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

