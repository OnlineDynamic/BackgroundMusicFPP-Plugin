#!/bin/bash
###############################################################################
# pw_env.sh — Common PipeWire/GStreamer environment for FPP 10
#
# Source this file from any plugin script that needs to interact with
# PipeWire or launch GStreamer pipelines:
#   . "$(dirname "$0")/pw_env.sh"
###############################################################################

# FPP 10 PipeWire runs system-wide — use its socket
export PIPEWIRE_REMOTE=/run/pipewire-fpp/pipewire-0
export PIPEWIRE_RUNTIME_DIR=/run/pipewire-fpp
export XDG_RUNTIME_DIR=/run/pipewire-fpp

# Plugin's combine-stream sink that background music routes through
BGMUSIC_SINK="fpp_bgmusic_group"

# Common paths
PLUGIN_DIR="/home/fpp/media/plugins/fpp-plugin-BackgroundMusic"
PLUGIN_CONFIG="/home/fpp/media/config/plugin.fpp-plugin-BackgroundMusic"
LOG_FILE="/home/fpp/media/logs/fpp-plugin-BackgroundMusic.log"

# PID / state files
PID_FILE="/tmp/background_music_player.pid"
GST_PID_FILE="/tmp/bgmusic_gst.pid"
GST_NEXT_PID_FILE="/tmp/bgmusic_gst_next.pid"
STATE_FILE="/tmp/bg_music_state.txt"
STATUS_FILE="/tmp/bg_music_status.txt"
VOLUME_FILE="/tmp/bgmusic_volume.txt"

###############################################################################
# Logging
###############################################################################
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

###############################################################################
# GStreamer pipeline launchers
###############################################################################

# Play a local file through the plugin's PipeWire sink
# Usage: gst_play_file <file> [node_name]
gst_play_file() {
    local file="$1"
    local node_name="${2:-bgmusic_main}"
    gst-launch-1.0 -q \
        filesrc location="$file" \
        ! decodebin \
        ! audioconvert \
        ! audioresample \
        ! "audio/x-raw,rate=48000" \
        ! pipewiresink target-object="$BGMUSIC_SINK" \
            stream-properties="props,node.name=$node_name,media.class=Stream/Output/Audio"
}

# Play an internet stream through the plugin's PipeWire sink
# Usage: gst_play_stream <url> [node_name]
gst_play_stream() {
    local url="$1"
    local node_name="${2:-bgmusic_main}"
    gst-launch-1.0 -q \
        souphttpsrc location="$url" is-live=true \
        ! decodebin \
        ! audioconvert \
        ! audioresample \
        ! "audio/x-raw,rate=48000" \
        ! pipewiresink target-object="$BGMUSIC_SINK" \
            stream-properties="props,node.name=$node_name,media.class=Stream/Output/Audio"
}

###############################################################################
# PipeWire node helpers
###############################################################################

# Find a PipeWire node ID by node.name
# Usage: find_bgmusic_node [node_name]
find_bgmusic_node() {
    local name="${1:-bgmusic_main}"
    pw-dump 2>/dev/null | jq -r \
        --arg name "$name" \
        '.[] | select(.type == "PipeWire:Interface:Node")
             | select(.info.props["node.name"]? == $name)
             | .id' | tail -1
}

# Find the combine-stream sink node ID
find_bgmusic_sink() {
    pw-dump 2>/dev/null | jq -r \
        --arg name "$BGMUSIC_SINK" \
        '.[] | select(.type == "PipeWire:Interface:Node")
             | select(.info.props["node.name"]? == $name)
             | .id' | tail -1
}

# Set volume on a PipeWire node (percentage 0-100)
# Usage: set_node_volume <node_id> <volume_pct>
set_node_volume() {
    local node_id="$1"
    local volume_pct="$2"
    local vol_float
    vol_float=$(awk "BEGIN {printf \"%.4f\", $volume_pct / 100.0}")
    wpctl set-volume "$node_id" "$vol_float"
}

# Get volume of a PipeWire node (returns percentage 0-100)
# Usage: get_node_volume <node_id>
get_node_volume() {
    local node_id="$1"
    local vol_str
    vol_str=$(wpctl get-volume "$node_id" 2>/dev/null | awk '{print $2}')
    if [ -n "$vol_str" ]; then
        awk "BEGIN {printf \"%.0f\", $vol_str * 100}"
    else
        echo "0"
    fi
}

###############################################################################
# Config helpers
###############################################################################

# Read a value from the plugin config file, stripping quotes
# Usage: get_plugin_setting <key> [default]
get_plugin_setting() {
    local key="$1"
    local default="$2"
    local value=""
    if [ -f "$PLUGIN_CONFIG" ]; then
        value=$(grep "^${key}=" "$PLUGIN_CONFIG" | cut -d'=' -f2- | tr -d '\r')
        # Strip surrounding quotes
        value="${value%\"}"
        value="${value#\"}"
    fi
    echo "${value:-$default}"
}

###############################################################################
# Process helpers
###############################################################################

# Kill all GStreamer pipelines launched by this plugin
kill_bgmusic_gst() {
    local pids=""
    for pidfile in "$GST_PID_FILE" "$GST_NEXT_PID_FILE"; do
        if [ -f "$pidfile" ]; then
            local pid
            pid=$(cat "$pidfile" 2>/dev/null)
            if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                kill "$pid" 2>/dev/null
                pids="$pids $pid"
            fi
            rm -f "$pidfile"
        fi
    done
    # Also kill any orphaned gst-launch processes with our node names
    pkill -f "node.name=bgmusic_" 2>/dev/null || true
    if [ -n "$pids" ]; then
        sleep 0.3
        for pid in $pids; do
            kill -9 "$pid" 2>/dev/null || true
        done
    fi
}
