#!/bin/bash
# Set bgmplayer volume using PipeWire's native volume control via pw-dump + jq
# Usage: set_bgmplayer_volume.sh <volume> [pid]
# If PID is provided, will target that specific bgmplayer process

TARGET_VOLUME=${1:-70}  # Target volume (0-100)
TARGET_PID=${2:-}       # Optional: specific bgmplayer PID to target
LOG_FILE="/home/fpp/media/logs/fpp-plugin-BackgroundMusic.log"
FPP_UID=$(id -u fpp)

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Validate target volume
if ! [[ "$TARGET_VOLUME" =~ ^[0-9]+$ ]] || [ "$TARGET_VOLUME" -lt 0 ] || [ "$TARGET_VOLUME" -gt 100 ]; then
    log_message "ERROR: Invalid target volume: $TARGET_VOLUME"
    exit 1
fi

# Find bgmplayer stream in PipeWire using pw-cli
if [ -n "$TARGET_PID" ]; then
    # Find stream by matching PID (not reliable for SDL streams, kept for compatibility)
    log_message "Looking for bgmplayer stream with PID $TARGET_PID"
    STREAM_ID=$(sudo -u fpp XDG_RUNTIME_DIR="/run/user/${FPP_UID}" \
        pw-cli list-objects 2>/dev/null | grep -B20 "application.process.id = $TARGET_PID" | \
        grep "^  id " | grep -oP 'id \K[0-9]+' | head -1)
else
    # No PID specified - find BackgroundMusic stream by metadata role
    # First try to find stream with bgmplayer.role=main metadata
    STREAM_ID=$(sudo -u fpp XDG_RUNTIME_DIR="/run/user/${FPP_UID}" \
        pw-dump 2>/dev/null | jq -r '.[] | select(.type == "PipeWire:Interface:Node") | select(.info.state? == "running") | select(.info.props["media.name"]? // "" | startswith("BackgroundMusic")) | .id' | while read id; do
            role=$(sudo -u fpp XDG_RUNTIME_DIR="/run/user/${FPP_UID}" pw-metadata ls "$id" 2>/dev/null | grep "bgmplayer.role" | grep -oP "'value':'\\K[^']+")
            if [ "$role" = "main" ]; then
                echo "$id"
                break
            fi
        done | head -1)
    
    # Fallback to BackgroundMusic_Main name (for backwards compatibility)
    if [ -z "$STREAM_ID" ]; then
        STREAM_ID=$(sudo -u fpp XDG_RUNTIME_DIR="/run/user/${FPP_UID}" \
            pw-dump 2>/dev/null | jq -r '.[] | select(.info.props["media.name"]? == "BackgroundMusic_Main") | select(.type == "PipeWire:Interface:Node") | select(.info.state? == "running") | .id' | tail -1)
    fi
    
    # Last fallback to any running BackgroundMusic stream
    if [ -z "$STREAM_ID" ]; then
        STREAM_ID=$(sudo -u fpp XDG_RUNTIME_DIR="/run/user/${FPP_UID}" \
            pw-dump 2>/dev/null | jq -r '.[] | select(.info.props["media.name"]? // "" | startswith("BackgroundMusic")) | select(.type == "PipeWire:Interface:Node") | select(.info.state? == "running") | .id' | tail -1)
    fi
fi

if [ -z "$STREAM_ID" ]; then
    log_message "No bgmplayer stream found in PipeWire"
    exit 0
fi

# Convert percentage to PipeWire volume (0.0 to 1.0)
PIPEWIRE_VOL=$(awk "BEGIN {printf \"%.2f\", $TARGET_VOLUME / 100.0}")

# Set volume using pw-cli
sudo -u fpp XDG_RUNTIME_DIR="/run/user/${FPP_UID}" \
    pw-cli set-param "$STREAM_ID" Props '{ volume: '"$PIPEWIRE_VOL"' }' 2>/dev/null

if [ $? -eq 0 ]; then
    if [ -n "$TARGET_PID" ]; then
        log_message "Set bgmplayer stream $STREAM_ID (PID $TARGET_PID) volume to ${TARGET_VOLUME}% (PipeWire: ${PIPEWIRE_VOL})"
    else
        log_message "Set bgmplayer stream $STREAM_ID volume to ${TARGET_VOLUME}% (PipeWire: ${PIPEWIRE_VOL})"
    fi
else
    log_message "ERROR: Failed to set volume for stream $STREAM_ID"
    exit 1
fi

exit 0
