#!/bin/bash
# Set PipeWire default sink based on FPP audio output setting

export XDG_RUNTIME_DIR=/run/user/500

# Get FPP's configured audio device (card number)
get_fpp_audio_card() {
    local audio_device=""
    
    if [ -f "/home/fpp/media/settings" ]; then
        audio_device=$(grep "^AudioOutput = " /home/fpp/media/settings | sed 's/AudioOutput = "\(.*\)"/\1/')
    fi
    
    if [ -z "$audio_device" ]; then
        audio_device="0"
    fi
    
    echo "$audio_device"
}

CARD_NUM=$(get_fpp_audio_card)

# Set runtime directory for PipeWire commands (use 500 as that's where PipeWire is running)
export XDG_RUNTIME_DIR=/run/user/500

SINK_NAME=""

# Get list of all node IDs, then check each for alsa.card match
ALL_NODES=$(XDG_RUNTIME_DIR=/run/user/500 pw-cli ls Node 2>/dev/null | grep "^\s*id [0-9]" | awk '{gsub(/,/,"",$2); print $2}')

for NODE_ID in $ALL_NODES; do
    NODE_INFO=$(XDG_RUNTIME_DIR=/run/user/500 pw-cli info "$NODE_ID" 2>/dev/null)
    
    # Only check nodes that have alsa.card (audio devices)
    if echo "$NODE_INFO" | grep -q 'alsa.card = '; then
        CARD_ID=$(echo "$NODE_INFO" | grep 'alsa.card = ' | head -1 | grep -oP '"\K[0-9]+')
        
        if [ "$CARD_ID" = "$CARD_NUM" ]; then
            SINK_NAME=$(echo "$NODE_INFO" | grep 'node.name = ' | head -1 | grep -oP '= "\K[^"]+')
            break
        fi
    fi
done

if [ -z "$SINK_NAME" ]; then
    echo "Warning: Could not find sink for card $CARD_NUM"
    exit 1
fi

# Set as default sink using pw-metadata (more reliable than wpctl set-default)
pw-metadata -n default 0 default.audio.sink "{\"name\":\"$SINK_NAME\"}" 2>/dev/null

echo "Set default sink to: $SINK_NAME (card $CARD_NUM)"
exit 0

        
        # For vc4-hdmi devices
        if echo "$CARD_NAME" | grep -qi "vc4.*hdmi"; then
            # Detected vc4-hdmi device, searching for HDMI output node
            DEFAULT_SINK_NAME=$($PW_CLI_CMD ls Node 2>/dev/null | \
                grep 'node.name = "alsa_output.*hdmi' | \
                head -1 | sed 's/.*node.name = "\([^"]*\)".*/\1/' || true)
            
            # Alternative: search by description containing HDMI
            if [ -z "$DEFAULT_SINK_NAME" ]; then
                DEFAULT_SINK_NAME=$($PW_CLI_CMD ls Node 2>/dev/null | \
                    grep -B5 'node.description.*HDMI' | \
                    grep 'node.name = "alsa_output' | \
                    head -1 | sed 's/.*node.name = "\([^"]*\)".*/\1/' || true)
            fi
        else
            # For non-HDMI devices, match by card name in description
            DEFAULT_SINK_NAME=$($PW_CLI_CMD ls Node 2>/dev/null | \
                grep -B5 "node.description.*$CARD_NAME" | \
                grep 'node.name = "alsa_output' | \
                head -1 | sed 's/.*node.name = "\([^"]*\)".*/\1/' || true)
        fi
    fi
    
    # Fallback for USB devices
    if [ -z "$DEFAULT_SINK_NAME" ]; then
        DEFAULT_SINK_NAME=$($PW_CLI_CMD ls Node 2>/dev/null | \
            grep 'node.name = "alsa_output.*usb' | \
            head -1 | sed 's/.*node.name = "\([^"]*\)".*/\1/' || true)
    fi
fi

if [ -n "$DEFAULT_SINK_NAME" ]; then
    # Setting default sink: $DEFAULT_SINK_NAME (FPP card $CARD_NUM)
    $PW_META_CMD -n default 0 default.audio.sink "{\"name\":\"$DEFAULT_SINK_NAME\"}" 2>&1
    
    # Also move any existing streams to the new default sink
    # Get the sink ID
    SINK_ID=$($PW_CLI_CMD ls Node 2>/dev/null | grep -B5 "node.name = \"$DEFAULT_SINK_NAME\"" | grep "id [0-9]" | head -1 | sed 's/.*id \([0-9]*\).*/\1/')
    
    if [ -n "$SINK_ID" ]; then
        # Moving existing streams to sink ID
        # Get all stream-output links (actively playing streams)
        $PW_CLI_CMD ls Node 2>/dev/null | grep -E "media.class.*Stream/Output/Audio" | grep "id [0-9]" | sed 's/.*id \([0-9]*\).*/\1/' | while read STREAM_ID; do
            # Moving stream to sink
            $PW_CLI_CMD set-param $STREAM_ID Route "{ index: 0, device: $SINK_ID, props: {}, save: false }" 2>&1 || true
        done
    fi
    
    # Audio output configured successfully
    exit 0
else
    echo "ERROR: Could not find ALSA sink for card $CARD_NUM"
    exit 1
fi
