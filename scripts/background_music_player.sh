#!/bin/bash
# Background Music Player - plays audio files independently from FPP playlists
# FPP 10 version: uses GStreamer + system PipeWire (fpp-pipewire.service)

# Source shared PipeWire environment
SCRIPT_DIR="$(dirname "$0")"
. "$SCRIPT_DIR/pw_env.sh"

PLAYLIST_FILE="/tmp/background_music_playlist.m3u"

# Function to create playlist from FPP playlist
create_audio_playlist() {
    local playlist_name="$1"
    local playlist_file="/home/fpp/media/playlists/${playlist_name}.json"

    if [ ! -f "$playlist_file" ]; then
        echo "ERROR: Playlist file not found: $playlist_file" >&2
        return 1
    fi

    echo "#EXTM3U" > "$PLAYLIST_FILE"

    jq -r '.mainPlaylist[] | select(.type == "media") | .mediaName' "$playlist_file" | while read -r media_file; do
        if [ -n "$media_file" ]; then
            echo "/home/fpp/media/music/${media_file}" >> "$PLAYLIST_FILE"
        fi
    done

    local file_count=$(grep -v "^#" "$PLAYLIST_FILE" | wc -l)
    if [ "$file_count" -eq 0 ]; then
        echo "ERROR: No media files found in playlist: $playlist_name" >&2
        return 1
    fi

    echo "Created playlist with $file_count files" >&2
    return 0
}

# Function to start background music
start_music() {
    # SAFETY CHECK: Verify FPPD is responsive before starting
    FPPD_STATUS=$(curl -s --max-time 3 "http://localhost/api/fppd/status" 2>/dev/null)
    if [ $? -ne 0 ] || [ -z "$FPPD_STATUS" ]; then
        echo "ERROR: Cannot connect to FPPD API - FPPD may be stopped or unresponsive"
        return 1
    fi

    if [ ! -f "$PLUGIN_CONFIG" ]; then
        echo "ERROR: Plugin configuration not found"
        return 1
    fi

    # Verify PipeWire is running
    if [ ! -S "/run/pipewire-fpp/pipewire-0" ]; then
        echo "ERROR: PipeWire socket not found at /run/pipewire-fpp/pipewire-0"
        echo "Enable PipeWire in FPP Audio settings"
        return 1
    fi

    # Read configuration
    local bg_source=$(get_plugin_setting "BackgroundMusicSource" "playlist")
    local bg_playlist=$(get_plugin_setting "BackgroundMusicPlaylist" "")
    local bg_stream_url=$(get_plugin_setting "BackgroundMusicStreamURL" "")
    local shuffle_mode=$(get_plugin_setting "ShuffleMusic" "0")
    local enable_crossfade=$(get_plugin_setting "EnableCrossfade" "0")
    local crossfade_duration=$(get_plugin_setting "CrossfadeDuration" "3")
    local volume_level=$(get_plugin_setting "BackgroundMusicVolume" "")

    # Fallback to VolumeLevel for backward compatibility
    if [ -z "$volume_level" ]; then
        volume_level=$(get_plugin_setting "VolumeLevel" "70")
    fi

    # Check if already running
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            local current_source="unknown"
            if [ -f "/tmp/bg_music_loop.sh" ]; then
                if grep -q "STREAM_URL=" /tmp/bg_music_loop.sh; then
                    current_source="stream"
                else
                    current_source="playlist"
                fi
            fi
            if [ "$current_source" != "$bg_source" ] && [ "$current_source" != "unknown" ]; then
                echo "Source type changed from $current_source to $bg_source, restarting..."
                stop_music
                sleep 0.5
            else
                echo "Background music already running (PID: $pid)"
                return 0
            fi
        fi
    fi

    # Clean up stale files
    rm -f /tmp/bg_music_jump.txt /tmp/bg_music_next.txt /tmp/bg_music_previous.txt 2>/dev/null
    rm -f "$PID_FILE" /tmp/background_music_start.pid 2>/dev/null

    echo "$$" > /tmp/background_music_start.pid

    # Initialize volume file
    if [ ! -f "$VOLUME_FILE" ]; then
        echo "$volume_level" > "$VOLUME_FILE"
        echo "Set initial volume to ${volume_level}% from config"
    else
        current_volume=$(cat "$VOLUME_FILE")
        echo "Preserving user volume setting: ${current_volume}%"
    fi

    # Validate configuration
    if [ "$bg_source" = "stream" ]; then
        if [ -z "$bg_stream_url" ]; then
            echo "ERROR: BackgroundMusicStreamURL not configured"
            return 1
        fi
        echo "Using internet stream: $bg_stream_url"
    else
        if [ -z "$bg_playlist" ]; then
            echo "ERROR: BackgroundMusicPlaylist not configured"
            return 1
        fi
        if ! create_audio_playlist "$bg_playlist"; then
            return 1
        fi
    fi

    echo "Starting background music player..."
    echo "Audio routing: GStreamer -> pipewiresink -> $BGMUSIC_SINK"
    echo "Source Type: $bg_source"
    if [ "$bg_source" = "stream" ]; then
        echo "Stream URL: $bg_stream_url"
    else
        echo "Playlist: $bg_playlist"
        echo "Shuffle Mode: ${shuffle_mode}"
    fi
    echo "Volume: ${volume_level}%"

    # Set volume via FPP API
    echo "Setting system volume to ${volume_level}% via FPP API"
    curl -s -X POST -H "Content-Type: application/json" \
         -d "{\"volume\": ${volume_level}}" \
         "http://localhost/api/system/volume" > /dev/null 2>&1

    if [ "$bg_source" = "stream" ]; then
        # Stream mode
        cat > /tmp/bg_music_loop.sh << 'STREAMSCRIPT'
#!/bin/bash
. /home/fpp/media/plugins/fpp-plugin-BackgroundMusic/scripts/pw_env.sh

STREAM_URL="$STREAM_URL_PLACEHOLDER"
METADATA_PID_FILE="/tmp/bg_music_metadata.pid"

echo "playing" > "$STATE_FILE"

cat > "$STATUS_FILE" << EOF
state=playing
source=stream
stream_url=$STREAM_URL
stream_title=
stream_artist=
EOF
chmod 644 "$STATUS_FILE"

# ICY metadata extraction
extract_metadata() {
    local script_path="$PLUGIN_DIR/scripts/icy_metadata_reader.py"
    while [ -f "$STATUS_FILE" ]; do
        stream_title=$("$script_path" "$STREAM_URL" 2>/dev/null)
        if [ -n "$stream_title" ]; then
            if echo "$stream_title" | grep -q " - "; then
                stream_artist=$(echo "$stream_title" | cut -d'-' -f1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                stream_song=$(echo "$stream_title" | cut -d'-' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            elif echo "$stream_title" | grep -q " – "; then
                stream_artist=$(echo "$stream_title" | cut -d'–' -f1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                stream_song=$(echo "$stream_title" | cut -d'–' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            else
                stream_artist=""
                stream_song="$stream_title"
            fi

            current_state="playing"
            [ -f "$STATE_FILE" ] && current_state=$(cat "$STATE_FILE")

            temp_status=$(mktemp)
            while IFS='=' read -r key value; do
                case "$key" in
                    stream_title) echo "stream_title=$stream_song" ;;
                    stream_artist) echo "stream_artist=$stream_artist" ;;
                    state) echo "state=$current_state" ;;
                    *) echo "$key=$value" ;;
                esac
            done < "$STATUS_FILE" > "$temp_status"
            mv "$temp_status" "$STATUS_FILE"
            chmod 644 "$STATUS_FILE"
        fi
        sleep 10
    done
}

extract_metadata &
metadata_pid=$!
echo $metadata_pid > "$METADATA_PID_FILE"

# Reconnection loop
while true; do
    [ ! -f "$STATUS_FILE" ] && break

    gst-launch-1.0 -q \
        souphttpsrc location="$STREAM_URL" is-live=true \
        ! decodebin ! audioconvert ! audioresample \
        ! "audio/x-raw,rate=48000" \
        ! pipewiresink target-object="$BGMUSIC_SINK" \
            stream-properties="props,node.name=bgmusic_main,media.class=Stream/Output/Audio" &
    gst_pid=$!
    echo $gst_pid > "$GST_PID_FILE"

    # Set initial volume after stream appears
    sleep 1
    NODE_ID=$(find_bgmusic_node "bgmusic_main")
    if [ -n "$NODE_ID" ] && [ -f "$VOLUME_FILE" ]; then
        set_node_volume "$NODE_ID" "$(cat "$VOLUME_FILE")"
    fi

    wait $gst_pid
    exit_code=$?
    rm -f "$GST_PID_FILE"

    [ $exit_code -eq 0 ] || [ ! -f "$STATUS_FILE" ] && break

    echo "Stream disconnected (exit $exit_code), reconnecting in 3s..." >&2
    sleep 3
done

# Cleanup
[ -f "$METADATA_PID_FILE" ] && kill $(cat "$METADATA_PID_FILE") 2>/dev/null && rm -f "$METADATA_PID_FILE"
rm -f "$STATUS_FILE" "$STATE_FILE" "$GST_PID_FILE"
STREAMSCRIPT

        sed -i "s|\$STREAM_URL_PLACEHOLDER|$bg_stream_url|g" /tmp/bg_music_loop.sh

    else
        # Playlist mode
        cat > /tmp/bg_music_loop.sh << LOOPSCRIPT
#!/bin/bash
. /home/fpp/media/plugins/fpp-plugin-BackgroundMusic/scripts/pw_env.sh

PLAYLIST_FILE="/tmp/background_music_playlist.m3u"
SHUFFLE_MODE="${shuffle_mode:-0}"
ENABLE_CROSSFADE="${enable_crossfade:-0}"
CROSSFADE_DURATION="${crossfade_duration:-3}"
JUMP_FILE="/tmp/bg_music_jump.txt"
PREVIOUS_FILE="/tmp/bg_music_previous.txt"
NEXT_FILE="/tmp/bg_music_next.txt"
REORDER_FILE="/tmp/bg_music_reorder.txt"

echo "playing" > "\$STATE_FILE"

shuffle_array() {
    local i tmp size rand
    size=\${#playlist_files[@]}
    for ((i=size-1; i>0; i--)); do
        rand=\$((RANDOM % (i+1)))
        tmp=\${playlist_files[i]}
        playlist_files[i]=\${playlist_files[rand]}
        playlist_files[rand]=\$tmp
    done
}

get_duration() {
    local file="\$1"
    ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "\$file" 2>/dev/null | cut -d'.' -f1
}

update_status() {
    local filename="\$1" duration="\$2" elapsed="\$3" track_num="\$4" total_tracks="\$5"
    local progress=0 state="playing"
    [ -f "\$STATE_FILE" ] && state=\$(cat "\$STATE_FILE")
    [ "\$duration" -gt 0 ] 2>/dev/null && progress=\$((elapsed * 100 / duration))
    [ \$progress -gt 100 ] && progress=100
    {
        echo "filename=\$filename"
        echo "duration=\$duration"
        echo "elapsed=\$elapsed"
        echo "progress=\$progress"
        echo "state=\$state"
        echo "track_number=\$track_num"
        echo "total_tracks=\$total_tracks"
    } > "\$STATUS_FILE"
    chmod 644 "\$STATUS_FILE" 2>/dev/null
}

# Play a track, optionally starting next track for crossfade
# Returns: 0 = crossfade completed, 1 = normal completion, 2 = skipped
play_track_with_crossfade() {
    local media_file="\$1" track_name="\$2" duration="\$3"
    local track_number="\$4" total_tracks="\$5" next_media_file="\$6"

    local crossfade_start_time=0
    if [ "\$ENABLE_CROSSFADE" = "1" ] && [ -n "\$next_media_file" ] && [ "\$duration" -gt "\$CROSSFADE_DURATION" ]; then
        crossfade_start_time=\$((duration - CROSSFADE_DURATION))
    fi

    update_status "\$track_name" "\$duration" 0 "\$track_number" "\$total_tracks"

    # Launch GStreamer pipeline for main track
    gst-launch-1.0 -q \\
        filesrc location="\$media_file" ! decodebin ! audioconvert ! audioresample \\
        ! "audio/x-raw,rate=48000" \\
        ! pipewiresink target-object="\$BGMUSIC_SINK" \\
            stream-properties="props,node.name=bgmusic_main,media.class=Stream/Output/Audio" &
    local player_pid=\$!
    echo "\$player_pid" > "\$GST_PID_FILE"

    # Set initial volume after stream appears
    sleep 0.8
    local main_node=\$(find_bgmusic_node "bgmusic_main")
    if [ -n "\$main_node" ] && [ -f "\$VOLUME_FILE" ]; then
        set_node_volume "\$main_node" "\$(cat "\$VOLUME_FILE")"
    fi

    local elapsed=0 crossfade_started=0 next_player_pid=0

    while kill -0 \$player_pid 2>/dev/null; do
        sleep 1

        local current_state="playing"
        [ -f "\$STATE_FILE" ] && current_state=\$(cat "\$STATE_FILE")
        [ "\$current_state" != "paused" ] && elapsed=\$((elapsed + 1))

        update_status "\$track_name" "\$duration" "\$elapsed" "\$track_number" "\$total_tracks"

        # Start crossfade when time reached
        if [ \$crossfade_started -eq 0 ] && [ \$crossfade_start_time -gt 0 ] && [ \$elapsed -ge \$crossfade_start_time ]; then
            crossfade_started=1
            gst-launch-1.0 -q \\
                filesrc location="\$next_media_file" ! decodebin ! audioconvert ! audioresample \\
                ! "audio/x-raw,rate=48000" \\
                ! pipewiresink target-object="\$BGMUSIC_SINK" \\
                    stream-properties="props,node.name=bgmusic_crossfade,media.class=Stream/Output/Audio" &
            next_player_pid=\$!
            echo "\$next_player_pid" > "\$GST_NEXT_PID_FILE"
            log_message "[CROSSFADE] Started next PID=\$next_player_pid file='\$(basename "\$next_media_file")'"

            # Set crossfade track volume
            (
                sleep 0.8
                xfade_node=\$(find_bgmusic_node "bgmusic_crossfade")
                if [ -n "\$xfade_node" ] && [ -f "\$VOLUME_FILE" ]; then
                    set_node_volume "\$xfade_node" "\$(cat "\$VOLUME_FILE")"
                fi
            ) &
        fi

        # Check for navigation commands
        if [ -f "\$JUMP_FILE" ] || [ -f "\$NEXT_FILE" ] || [ -f "\$PREVIOUS_FILE" ]; then
            kill \$player_pid 2>/dev/null
            if [ \$next_player_pid -gt 0 ]; then
                kill \$next_player_pid 2>/dev/null
                rm -f "\$GST_NEXT_PID_FILE"
            fi
            return 2
        fi
    done

    wait \$player_pid 2>/dev/null
    rm -f "\$GST_PID_FILE"

    # If crossfade started and next track is still playing, it becomes the current track
    if [ \$crossfade_started -eq 1 ] && [ \$next_player_pid -gt 0 ] && kill -0 \$next_player_pid 2>/dev/null; then
        echo "\$next_player_pid" > "\$GST_PID_FILE"
        return 0
    fi

    return 1
}

# Main loop
current_track_index=0
previous_track_index=-1
last_playlist_track=""

# Resume from previous position if available
if [ -f "\$STATUS_FILE" ]; then
    saved_track=\$(grep "^track_number=" "\$STATUS_FILE" | cut -d'=' -f2)
    if [ -n "\$saved_track" ] && [ "\$saved_track" -gt 0 ]; then
        current_track_index=\$saved_track
        echo "Resuming from track \$current_track_index" >&2
    fi
fi

while true; do
    # Read playlist into array
    playlist_files=()
    while IFS= read -r media_file || [ -n "\$media_file" ]; do
        [[ "\$media_file" =~ ^#.*\$ ]] || [ -z "\$media_file" ] && continue
        playlist_files+=("\$media_file")
    done < "\$PLAYLIST_FILE"

    total_tracks=\${#playlist_files[@]}
    if [ \$total_tracks -eq 0 ]; then
        echo "Warning: No files in playlist, waiting..." >&2
        sleep 5
        continue
    fi

    # Handle external playlist reorder
    if [ -f "\$REORDER_FILE" ]; then
        rm -f "\$REORDER_FILE"
        if [ -n "\$last_playlist_track" ]; then
            found_at_index=-1
            for i in "\${!playlist_files[@]}"; do
                [ "\${playlist_files[i]}" = "\$last_playlist_track" ] && found_at_index=\$i && break
            done
            if [ \$found_at_index -ge 0 ]; then
                current_track_index=\$((found_at_index + 1))
                [ \$current_track_index -ge \$total_tracks ] && current_track_index=0
            elif [ \$current_track_index -ge \$total_tracks ]; then
                current_track_index=0
            fi
        elif [ \$current_track_index -ge \$total_tracks ]; then
            current_track_index=0
        fi
    fi

    # Shuffle on first run or after full loop
    [ "\$SHUFFLE_MODE" = "1" ] && [ \$current_track_index -eq 0 ] && shuffle_array

    # Handle jump command
    if [ -f "\$JUMP_FILE" ]; then
        jump_to=\$(cat "\$JUMP_FILE")
        rm -f "\$JUMP_FILE"
        if [ "\$jump_to" -ge 1 ] && [ "\$jump_to" -le \$total_tracks ]; then
            current_track_index=\$((jump_to - 1))
        fi
    fi

    media_file="\${playlist_files[\$current_track_index]}"
    track_name=\$(basename "\$media_file")
    track_number=\$((current_track_index + 1))
    last_playlist_track="\$media_file"

    duration=\$(get_duration "\$media_file")
    [ -z "\$duration" ] && duration=0

    # Determine next track for crossfade
    next_track_index=\$((current_track_index + 1))
    [ \$next_track_index -ge \$total_tracks ] && next_track_index=0
    next_media_file="\${playlist_files[\$next_track_index]}"

    crossfade_happened=0

    if [ "\$ENABLE_CROSSFADE" = "1" ]; then
        play_track_with_crossfade "\$media_file" "\$track_name" "\$duration" "\$track_number" "\$total_tracks" "\$next_media_file"
        result=\$?
        if [ \$result -eq 0 ]; then
            # Crossfade completed — next track is already playing
            crossfade_happened=1
            current_track_index=\$next_track_index

            # Monitor the crossfaded track
            media_file="\${playlist_files[\$current_track_index]}"
            track_name=\$(basename "\$media_file")
            track_number=\$((current_track_index + 1))
            duration=\$(get_duration "\$media_file")
            [ -z "\$duration" ] && duration=0

            next_track_index=\$((current_track_index + 1))
            [ \$next_track_index -ge \$total_tracks ] && next_track_index=0
            next_media_file="\${playlist_files[\$next_track_index]}"

            crossfade_start_time=0
            if [ "\$duration" -gt "\$CROSSFADE_DURATION" ]; then
                crossfade_start_time=\$((duration - CROSSFADE_DURATION))
            fi

            if [ -f "\$GST_PID_FILE" ]; then
                player_pid=\$(cat "\$GST_PID_FILE")
                elapsed=\$CROSSFADE_DURATION
                next_crossfade_started=0 next_player_pid=0 track_was_skipped=0

                while kill -0 \$player_pid 2>/dev/null; do
                    sleep 1
                    current_state="playing"
                    [ -f "\$STATE_FILE" ] && current_state=\$(cat "\$STATE_FILE")
                    [ "\$current_state" != "paused" ] && elapsed=\$((elapsed + 1))
                    update_status "\$track_name" "\$duration" "\$elapsed" "\$track_number" "\$total_tracks"

                    if [ \$next_crossfade_started -eq 0 ] && [ \$crossfade_start_time -gt 0 ] && [ \$elapsed -ge \$crossfade_start_time ]; then
                        next_crossfade_started=1
                        gst-launch-1.0 -q \\
                            filesrc location="\$next_media_file" ! decodebin ! audioconvert ! audioresample \\
                            ! "audio/x-raw,rate=48000" \\
                            ! pipewiresink target-object="\$BGMUSIC_SINK" \\
                                stream-properties="props,node.name=bgmusic_crossfade,media.class=Stream/Output/Audio" &
                        next_player_pid=\$!
                        echo "\$next_player_pid" > "\$GST_NEXT_PID_FILE"
                        (
                            sleep 0.8
                            xf_node=\$(find_bgmusic_node "bgmusic_crossfade")
                            if [ -n "\$xf_node" ] && [ -f "\$VOLUME_FILE" ]; then
                                set_node_volume "\$xf_node" "\$(cat "\$VOLUME_FILE")"
                            fi
                        ) &
                    fi

                    if [ -f "\$JUMP_FILE" ] || [ -f "\$NEXT_FILE" ] || [ -f "\$PREVIOUS_FILE" ]; then
                        kill \$player_pid 2>/dev/null
                        [ \$next_player_pid -gt 0 ] && kill \$next_player_pid 2>/dev/null && rm -f "\$GST_NEXT_PID_FILE"
                        track_was_skipped=1
                        break
                    fi
                done

                wait \$player_pid 2>/dev/null
                rm -f "\$GST_PID_FILE"

                if [ \$next_crossfade_started -eq 1 ] && [ \$next_player_pid -gt 0 ] && [ \$track_was_skipped -eq 0 ]; then
                    echo "\$next_player_pid" > "\$GST_PID_FILE"
                    crossfade_happened=1
                fi
            fi

            current_track_index=\$((current_track_index + 1))
            continue
        elif [ \$result -eq 2 ]; then
            track_was_skipped=1
        fi
    else
        # Standard playback (no crossfade)
        update_status "\$track_name" "\$duration" 0 "\$track_number" "\$total_tracks"

        gst-launch-1.0 -q \\
            filesrc location="\$media_file" ! decodebin ! audioconvert ! audioresample \\
            ! "audio/x-raw,rate=48000" \\
            ! pipewiresink target-object="\$BGMUSIC_SINK" \\
                stream-properties="props,node.name=bgmusic_main,media.class=Stream/Output/Audio" &
        player_pid=\$!
        echo "\$player_pid" > "\$GST_PID_FILE"

        sleep 0.8
        main_node=\$(find_bgmusic_node "bgmusic_main")
        if [ -n "\$main_node" ] && [ -f "\$VOLUME_FILE" ]; then
            set_node_volume "\$main_node" "\$(cat "\$VOLUME_FILE")"
        fi

        elapsed=0
        track_was_skipped=0
        while kill -0 \$player_pid 2>/dev/null; do
            sleep 1
            current_state="playing"
            [ -f "\$STATE_FILE" ] && current_state=\$(cat "\$STATE_FILE")
            [ "\$current_state" != "paused" ] && elapsed=\$((elapsed + 1))
            update_status "\$track_name" "\$duration" "\$elapsed" "\$track_number" "\$total_tracks"

            if [ -f "\$JUMP_FILE" ] || [ -f "\$PREVIOUS_FILE" ] || [ -f "\$NEXT_FILE" ]; then
                kill \$player_pid 2>/dev/null
                track_was_skipped=1
                break
            fi
        done

        wait \$player_pid 2>/dev/null
        rm -f "\$GST_PID_FILE"
    fi

    # Handle navigation
    previous_pressed=0
    next_pressed=0

    if [ -f "\$PREVIOUS_FILE" ]; then
        rm -f "\$PREVIOUS_FILE"
        previous_pressed=1
        if [ \$current_track_index -gt 0 ]; then
            current_track_index=\$((current_track_index - 1))
        elif [ \$previous_track_index -ge 0 ]; then
            current_track_index=\$previous_track_index
        else
            current_track_index=\$((total_tracks - 1))
        fi
    fi

    [ -f "\$NEXT_FILE" ] && rm -f "\$NEXT_FILE" && next_pressed=1

    previous_track_index=\$current_track_index

    if [ \$previous_pressed -eq 0 ] && [ \$crossfade_happened -eq 0 ]; then
        current_track_index=\$((current_track_index + 1))
        if [ \$current_track_index -ge \$total_tracks ]; then
            if [ -f "\$REORDER_FILE" ]; then
                echo "At playlist end with pending reorder" >&2
            else
                current_track_index=0
                last_playlist_track=""
            fi
        fi
    fi

    sleep 0.1
done
LOOPSCRIPT
    fi

    chmod +x /tmp/bg_music_loop.sh

    # Start the loop in background
    nohup /bin/bash /tmp/bg_music_loop.sh >> "$LOG_FILE" 2>&1 &

    local pid=$!
    echo $pid > "$PID_FILE"
    echo $pid > "/tmp/background_music_start.pid"

    sleep 1
    if ps -p "$pid" > /dev/null 2>&1; then
        echo "Background music started successfully (PID: $pid)"
        return 0
    else
        echo "ERROR: Failed to start background music player"
        rm -f "$PID_FILE"
        return 1
    fi
}

# Pause background music
pause_music() {
    if [ ! -f "$GST_PID_FILE" ]; then
        echo "No active playback to pause"
        return 1
    fi

    local gst_pid=$(cat "$GST_PID_FILE")
    if ps -p "$gst_pid" > /dev/null 2>&1; then
        kill -STOP "$gst_pid" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "paused" > "$STATE_FILE"
            [ -f "$STATUS_FILE" ] && sed -i 's/^state=.*/state=paused/' "$STATUS_FILE"
            echo "Background music paused"
            return 0
        fi
    fi
    echo "Playback process not found"
    return 1
}

# Resume background music
resume_music() {
    if [ ! -f "$GST_PID_FILE" ]; then
        echo "No paused playback to resume"
        return 1
    fi

    local gst_pid=$(cat "$GST_PID_FILE")
    if ps -p "$gst_pid" > /dev/null 2>&1; then
        kill -CONT "$gst_pid" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "playing" > "$STATE_FILE"
            [ -f "$STATUS_FILE" ] && sed -i 's/^state=.*/state=playing/' "$STATUS_FILE"
            echo "Background music resumed"
            return 0
        fi
    fi
    echo "Playback process not found"
    return 1
}

# Jump to specific track
jump_to_track() {
    local track_number="$1"
    if [ -z "$track_number" ] || [ "$track_number" -lt 1 ]; then
        echo "ERROR: Invalid track number"
        return 1
    fi
    echo "$track_number" > /tmp/bg_music_jump.txt
    chown fpp:fpp /tmp/bg_music_jump.txt 2>/dev/null

    if [ -f "$GST_PID_FILE" ]; then
        local gst_pid=$(cat "$GST_PID_FILE")
        kill "$gst_pid" 2>/dev/null
    fi
    echo "Jumping to track $track_number"
    return 0
}

# Skip to next track
next_track() {
    echo "1" > /tmp/bg_music_next.txt
    chown fpp:fpp /tmp/bg_music_next.txt 2>/dev/null
    if [ -f "$GST_PID_FILE" ]; then
        local gst_pid=$(cat "$GST_PID_FILE")
        if ps -p "$gst_pid" > /dev/null 2>&1; then
            kill "$gst_pid" 2>/dev/null
            echo "Skipping to next track"
            return 0
        fi
    fi
    echo "No track currently playing"
    return 1
}

# Go to previous track
previous_track() {
    echo "1" > /tmp/bg_music_previous.txt
    chown fpp:fpp /tmp/bg_music_previous.txt 2>/dev/null
    if [ -f "$GST_PID_FILE" ]; then
        local gst_pid=$(cat "$GST_PID_FILE")
        if ps -p "$gst_pid" > /dev/null 2>&1; then
            kill "$gst_pid" 2>/dev/null
            echo "Going to previous track"
            return 0
        fi
    fi
    echo "No track currently playing"
    return 1
}

# Stop background music
stop_music() {
    echo "Stopping all background music GStreamer processes..."
    kill_bgmusic_gst

    # Kill metadata extraction
    if [ -f "/tmp/bg_music_metadata.pid" ]; then
        local metadata_pid=$(cat /tmp/bg_music_metadata.pid)
        kill "$metadata_pid" 2>/dev/null
        kill -9 "$metadata_pid" 2>/dev/null
        rm -f /tmp/bg_music_metadata.pid
    fi

    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            echo "Stopping background music loop (PID: $pid)..."
            rm -f "$STATUS_FILE"
            pkill -P "$pid" 2>/dev/null
            sleep 0.5
            pkill -9 -P "$pid" 2>/dev/null
            kill "$pid" 2>/dev/null

            local count=0
            while ps -p "$pid" > /dev/null 2>&1 && [ $count -lt 10 ]; do
                sleep 0.5
                count=$((count + 1))
            done
            ps -p "$pid" > /dev/null 2>&1 && kill -9 "$pid" 2>/dev/null
            echo "Background music stopped"
        fi
    fi

    # Kill any remaining loop scripts
    pkill -f "bg_music_loop.sh" 2>/dev/null
    pkill -9 -f "bg_music_loop.sh" 2>/dev/null

    # Clean up all state files
    rm -f "$PID_FILE" "/tmp/background_music_start.pid" "$PLAYLIST_FILE"
    rm -f /tmp/bg_music_loop.sh "$STATUS_FILE" "$STATE_FILE"
    rm -f "$GST_PID_FILE" "$GST_NEXT_PID_FILE"
    rm -f /tmp/bg_music_jump.txt /tmp/bg_music_previous.txt /tmp/bg_music_next.txt
    rm -f /tmp/bg_music_reorder.txt /tmp/bg_music_metadata.pid
    rm -f "$VOLUME_FILE"

    echo "All background music processes stopped"
    return 0
}

# Check status
status_check() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            echo "Running (PID: $pid)"
            return 0
        else
            echo "Not running (stale PID file)"
            rm -f "$PID_FILE"
            return 1
        fi
    else
        echo "Not running"
        return 1
    fi
}

# Main
case "$1" in
    start)      start_music ;;
    stop)       stop_music ;;
    restart)    stop_music; sleep 1; start_music ;;
    pause)      pause_music ;;
    resume)     resume_music ;;
    next)       next_track ;;
    previous)   previous_track ;;
    jump)
        [ -z "$2" ] && echo "Usage: $0 jump <track_number>" && exit 1
        jump_to_track "$2"
        ;;
    status)     status_check ;;
    *)
        echo "Usage: $0 {start|stop|restart|pause|resume|next|previous|jump <track_number>|status}"
        exit 1
        ;;
esac

exit $?
