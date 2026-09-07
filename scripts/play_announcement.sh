#!/bin/bash
##########################################################################
# play_announcement.sh - Play public service announcement with ducking
# FPP 10 version: uses GStreamer + system PipeWire
#
# Usage: play_announcement.sh <announcement_file> <duck_volume> <announcement_volume> [button_number] [button_label]
##########################################################################

ANNOUNCEMENT_FILE="$1"
DUCK_VOLUME="${2:-30}"
ANNOUNCEMENT_VOLUME="${3:-90}"
BUTTON_NUMBER="${4:-0}"
BUTTON_LABEL="${5:-PSA}"

SCRIPT_DIR="$(dirname "$0")"
. "$SCRIPT_DIR/pw_env.sh"

ANNOUNCEMENT_PID_FILE="/tmp/announcement_player.pid"
ANNOUNCEMENT_STATUS_FILE="/tmp/announcement_status.txt"

# Check if announcement file exists
if [ ! -f "$ANNOUNCEMENT_FILE" ]; then
    log_message "[PSA] ERROR: File not found: $ANNOUNCEMENT_FILE"
    exit 1
fi

# Check if an announcement is already playing
if [ -f "$ANNOUNCEMENT_PID_FILE" ]; then
    EXISTING_PID=$(cat "$ANNOUNCEMENT_PID_FILE")
    if ps -p "$EXISTING_PID" > /dev/null 2>&1; then
        log_message "[PSA] Already playing (PID: $EXISTING_PID), skipping"
        exit 0
    fi
    rm -f "$ANNOUNCEMENT_PID_FILE"
fi

log_message "[PSA] Playing: $(basename "$ANNOUNCEMENT_FILE")"

# Get current background music volume
ORIGINAL_VOLUME=$(cat "$VOLUME_FILE" 2>/dev/null)
if [ -z "$ORIGINAL_VOLUME" ]; then
    ORIGINAL_VOLUME=$(get_plugin_setting "BackgroundMusicVolume" "")
    [ -z "$ORIGINAL_VOLUME" ] && ORIGINAL_VOLUME=$(get_plugin_setting "VolumeLevel" "70")
fi

log_message "[PSA] Original vol: ${ORIGINAL_VOLUME}%, duck: ${DUCK_VOLUME}%, PSA vol: ${ANNOUNCEMENT_VOLUME}%"

# Duck background music if playing — duck both main and crossfade nodes (fix #13 + #17)
BG_MUSIC_PLAYING=false
# Check if any bgmusic pipeline is active via pid files or pgrep
HAS_BGMUSIC=false
for _pidfile in "$GST_PID_FILE" "$GST_NEXT_PID_FILE"; do
    if [ -f "$_pidfile" ]; then
        _pid=$(cat "$_pidfile" 2>/dev/null)
        if [ -n "$_pid" ] && ps -p "$_pid" > /dev/null 2>&1; then HAS_BGMUSIC=true; break; fi
    fi
done
if [ "$HAS_BGMUSIC" = false ] && { pgrep -f "node.name=bgmusic_main" > /dev/null 2>&1 || pgrep -f "node.name=bgmusic_crossfade" > /dev/null 2>&1; }; then HAS_BGMUSIC=true; fi

if [ "$HAS_BGMUSIC" = true ]; then
    BG_MUSIC_PLAYING=true
    for _node_name in bgmusic_main bgmusic_crossfade; do
        BG_NODE=$(find_bgmusic_node "$_node_name")
        if [ -n "$BG_NODE" ]; then
            log_message "[PSA] Ducking $_node_name (node $BG_NODE) to ${DUCK_VOLUME}%"
            set_node_volume "$BG_NODE" "$DUCK_VOLUME"
        fi
    done
fi

# Get announcement duration
DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$ANNOUNCEMENT_FILE" 2>/dev/null | cut -d'.' -f1)
[ -z "$DURATION" ] && DURATION=0

# Quote button label if it contains spaces
if [[ "$BUTTON_LABEL" =~ [[:space:]] ]]; then
    QUOTED_LABEL="\"$BUTTON_LABEL\""
else
    QUOTED_LABEL="$BUTTON_LABEL"
fi

cat > "$ANNOUNCEMENT_STATUS_FILE" << EOF
buttonNumber=$BUTTON_NUMBER
buttonLabel=$QUOTED_LABEL
announcementFile=$(basename "$ANNOUNCEMENT_FILE")
startTime=$(date +%s)
duration=$DURATION
EOF

# Play announcement in background subshell — trap ensures gst killed if subshell killed (fix #13)
(
    trap 'kill $PSA_PID 2>/dev/null' TERM INT
    # Play PSA through its own GStreamer pipeline with a distinct node name
    gst-launch-1.0 -q \
        filesrc location="$ANNOUNCEMENT_FILE" \
        ! decodebin ! audioconvert ! audioresample \
        ! "audio/x-raw,rate=48000" \
        ! pipewiresink target-object="$BGMUSIC_SINK" \
            stream-properties="props,node.name=bgmusic_psa,media.class=Stream/Output/Audio,application.name=BGMusic-Plugin" &
    PSA_PID=$!
    echo "$PSA_PID" > "/tmp/announcement_gst.pid"

    log_message "[PSA] GStreamer started (PID: $PSA_PID)"

    # Set PSA stream volume after it appears
    sleep 0.8
    PSA_NODE=$(find_bgmusic_node "bgmusic_psa")
    if [ -n "$PSA_NODE" ]; then
        set_node_volume "$PSA_NODE" "$ANNOUNCEMENT_VOLUME"
        log_message "[PSA] Set PSA node $PSA_NODE volume to ${ANNOUNCEMENT_VOLUME}%"
    fi

    wait $PSA_PID 2>/dev/null
    PLAY_RESULT=$?
    rm -f "/tmp/announcement_gst.pid"

    if [ $PLAY_RESULT -eq 0 ]; then
        log_message "[PSA] Completed successfully"
    else
        log_message "[PSA] Playback failed (exit $PLAY_RESULT)"
    fi

    # Restore background music volume — restore both main and crossfade (fix #13 + #17)
    if [ "$BG_MUSIC_PLAYING" = true ]; then
        RESTORE_VOLUME=$ORIGINAL_VOLUME
        [ -f "$VOLUME_FILE" ] && RESTORE_VOLUME=$(cat "$VOLUME_FILE")

        for _node_name in bgmusic_main bgmusic_crossfade; do
            BG_NODE=$(find_bgmusic_node "$_node_name")
            if [ -n "$BG_NODE" ]; then
                set_node_volume "$BG_NODE" "$RESTORE_VOLUME"
                log_message "[PSA] Restored $_node_name (node $BG_NODE) volume to ${RESTORE_VOLUME}%"
            fi
        done
        # Fallback: if no node found but bgmusic still active, try again after short delay (PipeWire node recreation)
        if [ -z "$(find_bgmusic_node "bgmusic_main")" ] && [ -z "$(find_bgmusic_node "bgmusic_crossfade")" ]; then
            sleep 0.5
            for _node_name in bgmusic_main bgmusic_crossfade; do
                BG_NODE=$(find_bgmusic_node "$_node_name")
                if [ -n "$BG_NODE" ]; then
                    set_node_volume "$BG_NODE" "$RESTORE_VOLUME"
                    log_message "[PSA] Restored (retry) $_node_name (node $BG_NODE) volume to ${RESTORE_VOLUME}%"
                fi
            done
        fi
    fi

    rm -f "$ANNOUNCEMENT_PID_FILE" "$ANNOUNCEMENT_STATUS_FILE" "/tmp/announcement_gst.pid"
) &

ANNOUNCEMENT_PID=$!
echo "$ANNOUNCEMENT_PID" > "$ANNOUNCEMENT_PID_FILE"

log_message "[PSA] Started (PID: $ANNOUNCEMENT_PID)"
exit 0
