#!/bin/bash
# Start PipeWire for audio mixing

# Ensure runtime directory exists
FPP_UID=$(id -u fpp)
RUNTIME_DIR="/run/user/${FPP_UID}"

if [ ! -d "$RUNTIME_DIR" ]; then
    sudo mkdir -p "$RUNTIME_DIR"
    sudo chown fpp:fpp "$RUNTIME_DIR"
    sudo chmod 700 "$RUNTIME_DIR"
fi

# Kill any existing PipeWire processes and stale sockets
pkill -u fpp pipewire 2>/dev/null
pkill -u fpp pipewire-pulse 2>/dev/null
pkill -u fpp wireplumber 2>/dev/null
pkill -f "dbus-daemon.*$RUNTIME_DIR" 2>/dev/null
sleep 1

# Always remove sockets when starting - they're stale if we got here
sudo rm -rf "$RUNTIME_DIR/pulse" 2>/dev/null
sudo rm -f "$RUNTIME_DIR"/pipewire-* 2>/dev/null
sudo rm -f "$RUNTIME_DIR/bus" 2>/dev/null
sudo -u fpp mkdir -p "$RUNTIME_DIR/pulse"

# Remove stale sockets and recreate pulse directory with correct permissions
sudo rm -rf "$RUNTIME_DIR/pulse" 2>/dev/null
sudo -u fpp mkdir -p "$RUNTIME_DIR/pulse"
sudo rm -f "$RUNTIME_DIR/bus" 2>/dev/null

# Get FPP's configured audio device and configure PipeWire to use it
get_fpp_audio_device() {
    local audio_device=""
    
    if [ -f "/home/fpp/media/settings" ]; then
        audio_device=$(grep "^AudioOutput = " /home/fpp/media/settings | sed 's/AudioOutput = "\(.*\)"/\1/')
    fi
    
    if [ -z "$audio_device" ] && [ -f "/home/fpp/media/settings" ]; then
        audio_device=$(grep "^AlsaAudioDevice = " /home/fpp/media/settings | sed 's/AlsaAudioDevice = "\(.*\)"/\1/')
    fi
    
    # Convert card number to ALSA device format if needed
    if [[ "$audio_device" =~ ^[0-9]+$ ]]; then
        audio_device="hw:$audio_device,0"
    fi
    
    # Default to hw:0,0 if nothing configured
    if [ -z "$audio_device" ]; then
        audio_device="hw:0,0"
    fi
    
    echo "$audio_device"
}

# Create PipeWire configuration with FPP's audio device
# PipeWire will auto-detect ALSA devices, we just configure the buffer settings
ALSA_DEVICE=$(get_fpp_audio_device)
PIPEWIRE_CONF_DIR="/home/fpp/.config/pipewire/pipewire.conf.d"
sudo -u fpp mkdir -p "$PIPEWIRE_CONF_DIR"

cat <<EOF | sudo tee "$PIPEWIRE_CONF_DIR/99-backgroundmusic.conf" > /dev/null
context.properties = {
    default.clock.rate = 48000
    default.clock.quantum = 2048
    default.clock.min-quantum = 1024
    default.clock.max-quantum = 8192
}
EOF
sudo chown fpp:fpp "$PIPEWIRE_CONF_DIR/99-backgroundmusic.conf"

# Create WirePlumber configuration to set the default ALSA device
WIREPLUMBER_CONF_DIR="/home/fpp/.config/wireplumber/main.lua.d"
sudo -u fpp mkdir -p "$WIREPLUMBER_CONF_DIR"

# Extract card number from device string (e.g., hw:1,0 -> 1)
CARD_NUM=$(echo "$ALSA_DEVICE" | grep -oP '(?<=:)\d+' | head -1)
if [ -z "$CARD_NUM" ]; then
    CARD_NUM="0"
fi

# Use filename 51- to load after 50-alsa-config.lua but before 90-enable-all.lua
cat <<EOF | sudo tee "$WIREPLUMBER_CONF_DIR/51-fpp-audio.lua" > /dev/null
-- Set default ALSA sink based on FPP configuration
-- Priority boosts FPP's configured audio device
-- Enable suspend-on-idle to release device when not in use (allows FPP direct access)
alsa_monitor.rules = alsa_monitor.rules or {}

table.insert(alsa_monitor.rules, {
  matches = {
    {
      { "node.name", "matches", "alsa_output.*" },
      { "api.alsa.card.id", "equals", "${CARD_NUM}" },
    },
  },
  apply_properties = {
    ["node.description"] = "FPP Audio Output",
    ["priority.session"] = 1000,
    ["priority.driver"] = 1000,
    ["session.suspend-timeout-seconds"] = 0,
  },
})

-- Enable suspend on idle for all ALSA nodes
table.insert(alsa_monitor.rules, {
  matches = {
    { { "node.name", "matches", "alsa_*" } },
  },
  apply_properties = {
    ["node.pause-on-idle"] = true,
  },
})
EOF
sudo chown fpp:fpp "$WIREPLUMBER_CONF_DIR/51-fpp-audio.lua"

# Remove old config file if it exists
sudo rm -f "$WIREPLUMBER_CONF_DIR/99-backgroundmusic.lua" 2>/dev/null

echo "PipeWire configured to use ALSA device: $ALSA_DEVICE (card $CARD_NUM)"

# Start PipeWire as fpp user
export XDG_RUNTIME_DIR="$RUNTIME_DIR"
export PIPEWIRE_RUNTIME_DIR="$RUNTIME_DIR"
export DBUS_SESSION_BUS_ADDRESS="unix:path=$RUNTIME_DIR/bus"

# Ensure dbus session is running
if [ ! -S "$RUNTIME_DIR/bus" ]; then
    sudo -u fpp bash -c "dbus-daemon --session --address='unix:path=$RUNTIME_DIR/bus' --nofork --nopidfile" >/dev/null 2>&1 &
    sleep 1
fi

# Start PipeWire services directly
sudo -u fpp XDG_RUNTIME_DIR="$RUNTIME_DIR" PIPEWIRE_RUNTIME_DIR="$RUNTIME_DIR" DBUS_SESSION_BUS_ADDRESS="unix:path=$RUNTIME_DIR/bus" /usr/bin/pipewire >/dev/null 2>&1 &
sleep 1
sudo -u fpp XDG_RUNTIME_DIR="$RUNTIME_DIR" PIPEWIRE_RUNTIME_DIR="$RUNTIME_DIR" DBUS_SESSION_BUS_ADDRESS="unix:path=$RUNTIME_DIR/bus" /usr/bin/pipewire-pulse >/dev/null 2>&1 &
sleep 1
sudo -u fpp XDG_RUNTIME_DIR="$RUNTIME_DIR" PIPEWIRE_RUNTIME_DIR="$RUNTIME_DIR" DBUS_SESSION_BUS_ADDRESS="unix:path=$RUNTIME_DIR/bus" /usr/bin/wireplumber >/dev/null 2>&1 &
sleep 1

# Verify PipeWire is running
if ! pgrep -u fpp pipewire >/dev/null 2>&1; then
    echo "Error: PipeWire failed to start"
    exit 1
fi

echo "PipeWire started for fpp user"
ps aux | grep -E "pipewire|wireplumber" | grep fpp | grep -v grep || echo "Warning: PipeWire processes not detected"

# Determine if we need sudo or not
if [ "$(whoami)" = "fpp" ]; then
    PW_CMD="XDG_RUNTIME_DIR=\"$RUNTIME_DIR\" pw-cli"
    PW_META="XDG_RUNTIME_DIR=\"$RUNTIME_DIR\" pw-metadata"
else
    PW_CMD="sudo -u fpp XDG_RUNTIME_DIR=\"$RUNTIME_DIR\" pw-cli"
    PW_META="sudo -u fpp XDG_RUNTIME_DIR=\"$RUNTIME_DIR\" pw-metadata"
fi

# Set the default sink to match FPP's configured audio device
# Find the node name for the configured ALSA card
if [ "$CARD_NUM" = "0" ]; then
    # Card 0 is usually the built-in bcm2835 audio - look for platform mailbox or Built-in Audio
    DEFAULT_SINK_NAME=$(timeout 5 eval $PW_CMD ls Node 2>/dev/null | \
        grep -E 'node.name.*alsa_output.*(platform.*mailbox|bcm2835)' | \
        head -1 | sed 's/.*node.name = "\([^"]*\)".*/\1/' || true)
    
    # Fallback: try any alsa_output for Built-in Audio
    if [ -z "$DEFAULT_SINK_NAME" ]; then
        DEFAULT_SINK_NAME=$(timeout 5 eval $PW_CMD ls Node 2>/dev/null | \
            grep -B20 'node.description.*Built-in Audio Stereo' | \
            grep 'node.name.*alsa_output' | tail -1 | sed 's/.*node.name = "\([^"]*\)".*/\1/' || true)
    fi
else
    # For USB/HDMI/other cards, get the card name from ALSA and match by description
    CARD_NAME=$(aplay -l 2>/dev/null | grep "^card $CARD_NUM:" | sed 's/^card [0-9]*: \([^[]*\).*/\1/' | sed 's/ *$//')
    
    if [ -n "$CARD_NAME" ]; then
        # Looking for audio sink matching card name
        
        # For vc4-hdmi devices, search for platform-*.hdmi nodes
        if echo "$CARD_NAME" | grep -qi "vc4.*hdmi"; then
            # Detected HDMI device, searching for platform hdmi output
            DEFAULT_SINK_NAME=$(timeout 5 eval $PW_CMD ls Node 2>/dev/null | \
                grep 'node.name.*alsa_output.platform.*hdmi' | \
                head -1 | sed 's/.*node.name = "\([^"]*\)".*/\1/' || true)
        else
            # For non-HDMI devices, match by card name in description
            DEFAULT_SINK_NAME=$(timeout 5 eval $PW_CMD ls Node 2>/dev/null | \
                grep -A10 "node.description.*$CARD_NAME" | \
                grep 'node.name.*alsa_output' | \
                head -1 | sed 's/.*node.name = "\([^"]*\)".*/\1/' || true)
        fi
    fi
    
    # Fallback: get any alsa_output node for USB devices
    if [ -z "$DEFAULT_SINK_NAME" ]; then
        DEFAULT_SINK_NAME=$(timeout 5 eval $PW_CMD ls Node 2>/dev/null | \
            grep 'node.name.*alsa_output.*usb' | \
            head -1 | sed 's/.*node.name = "\([^"]*\)".*/\1/' || true)
    fi
fi

if [ -n "$DEFAULT_SINK_NAME" ]; then
    # Setting default sink to: $DEFAULT_SINK_NAME (card $CARD_NUM)
    timeout 3 eval $PW_META -n default 0 default.audio.sink "{\"name\":\"$DEFAULT_SINK_NAME\"}" >/dev/null 2>&1 || true
    echo "Default sink configured"
else
    echo "Warning: Could not find ALSA sink for card $CARD_NUM"
fi

echo "PipeWire initialization complete"
