#!/bin/bash
# Start PipeWire for audio mixing

# Ensure runtime directory exists
FPP_UID=$(id -u fpp)
RUNTIME_DIR="/run/user/${FPP_UID}"

if [ ! -d "$RUNTIME_DIR" ]; then
    mkdir -p "$RUNTIME_DIR"
    chown fpp:fpp "$RUNTIME_DIR"
    chmod 700 "$RUNTIME_DIR"
fi

# Kill any existing PipeWire processes and stale sockets
pkill -u fpp pipewire 2>/dev/null
pkill -u fpp pipewire-pulse 2>/dev/null
pkill -u fpp wireplumber 2>/dev/null
sleep 1

# Remove stale PulseAudio socket so pipewire-pulse can bind cleanly
mkdir -p "$RUNTIME_DIR/pulse" 2>/dev/null
rm -f "$RUNTIME_DIR/pulse/native" 2>/dev/null

# Start PipeWire as fpp user
export XDG_RUNTIME_DIR="$RUNTIME_DIR"
export PIPEWIRE_RUNTIME_DIR="$RUNTIME_DIR"
export DBUS_SESSION_BUS_ADDRESS="unix:path=$RUNTIME_DIR/bus"

# Start dbus session if needed
if [ ! -S "$RUNTIME_DIR/bus" ]; then
    sudo -u fpp dbus-daemon --session --address="unix:path=$RUNTIME_DIR/bus" --nofork --nopidfile &
    sleep 1
fi

# Start PipeWire services
sudo -u fpp XDG_RUNTIME_DIR="$RUNTIME_DIR" PIPEWIRE_RUNTIME_DIR="$RUNTIME_DIR" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=$RUNTIME_DIR/bus" \
    /usr/bin/pipewire &

sleep 1

sudo -u fpp XDG_RUNTIME_DIR="$RUNTIME_DIR" PIPEWIRE_RUNTIME_DIR="$RUNTIME_DIR" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=$RUNTIME_DIR/bus" \
    /usr/bin/pipewire-pulse &

sleep 1

sudo -u fpp XDG_RUNTIME_DIR="$RUNTIME_DIR" PIPEWIRE_RUNTIME_DIR="$RUNTIME_DIR" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=$RUNTIME_DIR/bus" \
    /usr/bin/wireplumber &

sleep 2

echo "PipeWire started for fpp user"
ps aux | grep -E "pipewire|wireplumber" | grep fpp | grep -v grep
