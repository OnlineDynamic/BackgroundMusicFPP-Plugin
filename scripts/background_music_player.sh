#!/bin/bash
# Background Music Player - plays audio files independently from FPP playlists
# Uses custom bgmplayer for proper volume control support

# Use PipeWire for audio routing - allows dynamic device switching
FPP_UID=$(id -u fpp)
export XDG_RUNTIME_DIR="/run/user/${FPP_UID}"
export SDL_AUDIODRIVER=pipewire
export SDL_AUDIO_SAMPLES=4096

# Clean up stale PipeWire sockets FIRST before anything else
# This prevents issues when audio output changes between reboots
if [ -d "$XDG_RUNTIME_DIR" ]; then
    # If pipewire sockets exist but no pipewire processes are running, clean them up
    if ls "$XDG_RUNTIME_DIR"/pipewire-* >/dev/null 2>&1; then
        if ! pgrep -u fpp pipewire >/dev/null 2>&1; then
            rm -f "$XDG_RUNTIME_DIR"/pipewire-* 2>/dev/null
            rm -f "$XDG_RUNTIME_DIR/bus" 2>/dev/null
        fi
    fi
fi

PLUGIN_DIR="/home/fpp/media/plugins/fpp-plugin-BackgroundMusic"
PLUGIN_CONFIG="/home/fpp/media/config/plugin.fpp-plugin-BackgroundMusic"
PID_FILE="/tmp/background_music_player.pid"
PLAYLIST_FILE="/tmp/background_music_playlist.m3u"
STATE_FILE="/tmp/bg_music_state.txt"
BGMPLAYER_PID_FILE="/tmp/bg_music_bgmplayer.pid"

# Use bgmplayer for local files (proper volume control)
# bgmplayer uses SDL which connects directly to ALSA with dmix for software mixing
PLAYER_CMD="${PLUGIN_DIR}/bgmplayer"

# Function to check if running on PocketBeagle (needs softvol)
is_pocketbeagle() {
    if [ -f /proc/device-tree/model ]; then
        grep -qi "pocketbeagle" /proc/device-tree/model 2>/dev/null && return 0
    fi
    return 1
}

# Function to get FPP audio device
get_audio_device() {
    # Read FPP's configured audio device
    local audio_device=""
    
    # Try to read AlsaAudioDevice from FPP settings
    if [ -f "/home/fpp/media/settings" ]; then
        audio_device=$(grep "^AlsaAudioDevice = " /home/fpp/media/settings | sed 's/AlsaAudioDevice = "\(.*\)"/\1/')
    fi
    
    # If not set or empty, try AudioOutput
    if [ -z "$audio_device" ]; then
        if [ -f "/home/fpp/media/settings" ]; then
            audio_device=$(grep "^AudioOutput = " /home/fpp/media/settings | sed 's/AudioOutput = "\(.*\)"/\1/')
        fi
    fi
    
    # If audio_device is just a number (card number), convert to ALSA device format
    if [[ "$audio_device" =~ ^[0-9]+$ ]]; then
        # It's a card number - get the actual card name from ALSA
        local card_num="$audio_device"
        local card_name=$(aplay -l 2>/dev/null | grep "^card ${card_num}:" | sed 's/^card [0-9]*: \([^ ]*\).*/\1/')
        
        if [ -n "$card_name" ]; then
            # Use the card name format that ALSA recognizes
            audio_device="plughw:CARD=${card_name},DEV=0"
            echo "Converted card number $card_num to ALSA device: $audio_device (card name: $card_name)" >&2
        else
            # Fallback to numeric format
            audio_device="plughw:${card_num},0"
            echo "Converted card number $card_num to ALSA device: $audio_device" >&2
        fi
    fi
    
    # If still empty, use default detection
    if [ -z "$audio_device" ]; then
        # Try to detect available ALSA devices
        if aplay -L | grep -q "^sysdefault:CARD="; then
            audio_device="sysdefault"
        elif aplay -L | grep -q "^default:CARD="; then
            audio_device="default"
        elif aplay -L | grep -q "^plughw:"; then
            audio_device=$(aplay -L | grep "^plughw:" | head -1)
        else
            # Last resort - use hw:0,0
            audio_device="hw:0,0"
        fi
    fi
    
    echo "$audio_device"
}

# Function to create playlist from FPP playlist
create_audio_playlist() {
    local playlist_name="$1"
    local playlist_file="/home/fpp/media/playlists/${playlist_name}.json"
    
    # Check if playlist file exists
    if [ ! -f "$playlist_file" ]; then
        echo "ERROR: Playlist file not found: $playlist_file" >&2
        return 1
    fi
    
    # Clear the m3u file
    echo "#EXTM3U" > "$PLAYLIST_FILE"
    
    # Extract media files from the playlist using jq
    jq -r '.mainPlaylist[] | select(.type == "media") | .mediaName' "$playlist_file" | while read -r media_file; do
        # Add full path to media file
        if [ -n "$media_file" ]; then
            echo "/home/fpp/media/music/${media_file}" >> "$PLAYLIST_FILE"
        fi
    done
    
    # Check if we have any files
    local file_count=$(grep -v "^#" "$PLAYLIST_FILE" | wc -l)
    if [ "$file_count" -eq 0 ]; then
        echo "ERROR: No media files found in playlist: $playlist_name" >&2
        return 1
    fi
    
    echo "Created playlist with $file_count files" >&2
    return 0
}

# Function to strip quotes from INI values
strip_quotes() {
    local value="$1"
    # Remove leading and trailing quotes
    value="${value%\"}"
    value="${value#\"}"
    echo "$value"
}

# Function to start background music
start_music() {
    # Read configuration first to determine source type
    if [ ! -f "$PLUGIN_CONFIG" ]; then
        echo "ERROR: Plugin configuration not found"
        return 1
    fi
    
    # Read source type (playlist or stream)
    local bg_source=$(grep "^BackgroundMusicSource=" "$PLUGIN_CONFIG" | cut -d'=' -f2- | tr -d '\r')
    bg_source=$(strip_quotes "$bg_source")
    bg_source=${bg_source:-playlist}  # Default to playlist for backward compatibility
    
    # Check if already running and if source type has changed
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            # Check if the source type has changed by looking at the running loop script
            local current_source="unknown"
            if [ -f "/tmp/bg_music_loop.sh" ]; then
                if grep -q "STREAM_URL=" /tmp/bg_music_loop.sh; then
                    current_source="stream"
                else
                    current_source="playlist"
                fi
            fi
            
            # If source type changed, stop the old player and restart with new config
            if [ "$current_source" != "$bg_source" ] && [ "$current_source" != "unknown" ]; then
                echo "Source type changed from $current_source to $bg_source, restarting..."
                stop_music
                sleep 0.5
            else
                echo "Background music already running (PID: $pid) with same source type ($bg_source)"
                return 0
            fi
        fi
    fi
    
    # Clean up any stale control files and log files from previous session
    rm -f /tmp/bg_music_jump.txt /tmp/bg_music_next.txt /tmp/bg_music_previous.txt 2>/dev/null
    rm -f /tmp/background_music_player.log /tmp/background_music_start.log 2>/dev/null
    rm -f /tmp/pipewire_start.log /tmp/pipewire_restart.log 2>/dev/null
    # Clean up stale PID files
    rm -f "$PID_FILE" /tmp/background_music_start.pid 2>/dev/null
    
    # Write a temporary startup PID so the API knows we're starting
    # This will be updated with the actual player PID later
    echo "$$" > /tmp/background_music_start.pid
    
    local bg_playlist=$(grep "^BackgroundMusicPlaylist=" "$PLUGIN_CONFIG" | cut -d'=' -f2- | tr -d '\r')
    bg_playlist=$(strip_quotes "$bg_playlist")
    local bg_stream_url=$(grep "^BackgroundMusicStreamURL=" "$PLUGIN_CONFIG" | cut -d'=' -f2- | tr -d '\r')
    bg_stream_url=$(strip_quotes "$bg_stream_url")
    local shuffle_mode=$(grep "^ShuffleMusic=" "$PLUGIN_CONFIG" | cut -d'=' -f2- | tr -d '\r')
    shuffle_mode=$(strip_quotes "$shuffle_mode")
    local enable_crossfade=$(grep "^EnableCrossfade=" "$PLUGIN_CONFIG" | cut -d'=' -f2- | tr -d '\r')
    enable_crossfade=$(strip_quotes "$enable_crossfade")
    local crossfade_duration=$(grep "^CrossfadeDuration=" "$PLUGIN_CONFIG" | cut -d'=' -f2- | tr -d '\r')
    crossfade_duration=$(strip_quotes "$crossfade_duration")
    local volume_level=$(grep "^BackgroundMusicVolume=" "$PLUGIN_CONFIG" | cut -d'=' -f2- | tr -d '\r')
    volume_level=$(strip_quotes "$volume_level")
    
    # Fallback to VolumeLevel for backward compatibility
    if [ -z "$volume_level" ]; then
        volume_level=$(grep "^VolumeLevel=" "$PLUGIN_CONFIG" | cut -d'=' -f2- | tr -d '\r')
        volume_level=$(strip_quotes "$volume_level")
    fi
    
    # Default volume to 70 if not set
    volume_level=${volume_level:-70}
    
    # Always initialize volume file with config value on start
    # This ensures config changes are applied
    echo "$volume_level" > /tmp/bgmplayer_volume.txt
    echo "Set volume to ${volume_level}% from config"
    
    # Validate configuration based on source type
    if [ "$bg_source" = "stream" ]; then
        if [ -z "$bg_stream_url" ]; then
            echo "ERROR: BackgroundMusicStreamURL not configured"
            return 1
        fi
        echo "Using internet stream: $bg_stream_url"
    else
        # Playlist mode
        if [ -z "$bg_playlist" ]; then
            echo "ERROR: BackgroundMusicPlaylist not configured"
            return 1
        fi
        
        # Create playlist file
        if ! create_audio_playlist "$bg_playlist"; then
            return 1
        fi
    fi
    
    # Get audio device
    local audio_device=$(get_audio_device)
    
    echo "Detected audio device: $audio_device"
    
    # Test if the audio device is valid
    if ! aplay -L | grep -q "$audio_device" && ! echo "$audio_device" | grep -q "^hw:"; then
        echo "WARNING: Audio device '$audio_device' not found in ALSA device list"
        echo "Available devices:"
        aplay -L | head -20
        echo "Attempting to use anyway with plug wrapper..."
    fi
    
    # Ensure PipeWire is running and configured for the current audio device
    echo "Checking PipeWire status..."
    if ! pgrep -u fpp pipewire > /dev/null || ! pgrep -u fpp wireplumber > /dev/null; then
        echo "PipeWire not running, starting it now..."
        # Call start_pipewire.sh synchronously (it's fast now - ~4 seconds)
        if "${PLUGIN_DIR}/scripts/start_pipewire.sh" > /tmp/pipewire_start.log 2>&1; then
            echo "PipeWire started successfully"
            sleep 0.5  # Give WirePlumber time to detect devices and create sinks
            
            # Ensure audio output is set to match FPP configuration
            echo "Configuring audio output to match FPP settings..."
            "${PLUGIN_DIR}/scripts/set_audio_output.sh" >> /tmp/background_music_start.log 2>&1
        else
            echo "ERROR: Failed to start PipeWire"
            echo "Check /tmp/pipewire_start.log for details"
            return 1
        fi
    else
        echo "PipeWire is running"
        
        # Restart PipeWire if the audio device has changed
        # Check if WirePlumber config matches current device
        # Extract card number from various formats: plughw:2,0 or plughw:CARD=vc4hdmi0,DEV=0 or hw:2
        if echo "$audio_device" | grep -q "CARD="; then
            # Format: plughw:CARD=vc4hdmi0,DEV=0 - need to map card name to number
            local card_name=$(echo "$audio_device" | sed 's/.*CARD=\([^,]*\).*/\1/')
            CURRENT_CARD=$(aplay -l 2>/dev/null | grep -i "card [0-9]*:.*$card_name" | sed 's/^card \([0-9]*\):.*/\1/' | head -1)
        else
            # Format: plughw:2,0 or hw:2
            CURRENT_CARD=$(echo "$audio_device" | grep -oP '(?<=:)\d+' | head -1)
        fi
        
        if [ -z "$CURRENT_CARD" ]; then
            CURRENT_CARD="0"
        fi
        
        WIREPLUMBER_CONFIG="/home/fpp/.config/wireplumber/main.lua.d/51-fpp-audio.lua"
        if [ -f "$WIREPLUMBER_CONFIG" ]; then
            CONFIGURED_CARD=$(grep "api.alsa.card.id" "$WIREPLUMBER_CONFIG" | grep -oP '(?<=equals", ")\d+' | head -1)
            if [ "$CURRENT_CARD" != "$CONFIGURED_CARD" ]; then
                echo "Audio device changed (card $CONFIGURED_CARD -> card $CURRENT_CARD), restarting PipeWire..."
                
                # Kill existing PipeWire processes first
                pkill -u fpp pipewire 2>/dev/null
                pkill -u fpp wireplumber 2>/dev/null
                sleep 0.2
                
                # Start PipeWire synchronously (this is fast - ~4 seconds)
                if "${PLUGIN_DIR}/scripts/start_pipewire.sh" > /tmp/pipewire_restart.log 2>&1; then
                    echo "PipeWire restarted successfully"
                    sleep 1  # Give WirePlumber time to detect all devices and create sinks
                    
                    # Set audio output to match FPP configuration after restart
                    echo "Configuring audio output to match FPP settings..."
                    "${PLUGIN_DIR}/scripts/set_audio_output.sh" >> /tmp/background_music_start.log 2>&1
                else
                    echo "ERROR: Failed to restart PipeWire"
                    echo "Check /tmp/pipewire_restart.log for details"
                    return 1
                fi
            else
                # No restart needed, but ensure default sink is set correctly
                echo "Configuring audio output to match FPP settings..."
                "${PLUGIN_DIR}/scripts/set_audio_output.sh" >> /tmp/background_music_start.log 2>&1
            fi
        fi
    fi
    
    echo "Starting background music player..."
    echo "Audio routing: SDL -> PipeWire -> $audio_device"
    echo "Source Type: $bg_source"
    if [ "$bg_source" = "stream" ]; then
        echo "Stream URL: $bg_stream_url"
    else
        echo "Playlist: $bg_playlist"
        echo "Shuffle Mode: ${shuffle_mode:-0}"
    fi
    echo "System Volume (ALSA): ${volume_level}%"
    echo "Player: bgmplayer (integrated volume control)"
    
    # Set ALSA volume to BackgroundMusicVolume via FPP API
    echo "Setting system volume to ${volume_level}% via FPP API"
    curl -s -X POST -H "Content-Type: application/json" \
         -d "{\"volume\": ${volume_level}}" \
         "http://localhost/api/system/volume" > /dev/null 2>&1
    
    # Handle stream vs playlist
    if [ "$bg_source" = "stream" ]; then
        # Stream mode - use bgmplayer with reconnect logic and ICY metadata extraction
        cat > /tmp/bg_music_loop.sh << 'STREAMSCRIPT'
#!/bin/bash
STREAM_URL="$STREAM_URL_PLACEHOLDER"
PLAYER_CMD="$PLAYER_CMD_PLACEHOLDER"
STATUS_FILE="/tmp/bg_music_status.txt"
STATE_FILE="/tmp/bg_music_state.txt"
BGMPLAYER_PID_FILE="/tmp/bg_music_bgmplayer.pid"
METADATA_PID_FILE="/tmp/bg_music_metadata.pid"

# Initialize state
echo "playing" > "$STATE_FILE"

# Initial status
cat > "$STATUS_FILE" << EOF
state=playing
source=stream
stream_url=$STREAM_URL
stream_title=
stream_artist=
EOF

# Make status file world-readable so web UI can access it
chmod 644 "$STATUS_FILE"

# Function to extract ICY metadata
extract_metadata() {
    local script_path="/home/fpp/media/plugins/fpp-plugin-BackgroundMusic/scripts/icy_metadata_reader.py"
    
    while [ -f "$STATUS_FILE" ]; do
        # Use Python script to extract ICY metadata from stream
        stream_title=$("$script_path" "$STREAM_URL" 2>/dev/null)
        
        # If we found a title, parse it for artist/title
        if [ -n "$stream_title" ]; then
            # Try to split on common separators: " - ", " – ", " | "
            if echo "$stream_title" | grep -q " - "; then
                stream_artist=$(echo "$stream_title" | cut -d'-' -f1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                stream_song=$(echo "$stream_title" | cut -d'-' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            elif echo "$stream_title" | grep -q " – "; then
                stream_artist=$(echo "$stream_title" | cut -d'–' -f1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                stream_song=$(echo "$stream_title" | cut -d'–' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            elif echo "$stream_title" | grep -q " | "; then
                stream_artist=$(echo "$stream_title" | cut -d'|' -f1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                stream_song=$(echo "$stream_title" | cut -d'|' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            else
                # No separator found, use entire title as song name
                stream_artist=""
                stream_song="$stream_title"
            fi
            
            # Update status file with metadata
            # Read current status and update stream fields
            # Also check STATE_FILE for pause/play state
            current_state="playing"
            if [ -f "$STATE_FILE" ]; then
                current_state=$(cat "$STATE_FILE")
            fi
            
            temp_status=$(mktemp)
            while IFS='=' read -r key value; do
                case "$key" in
                    stream_title)
                        echo "stream_title=$stream_song"
                        ;;
                    stream_artist)
                        echo "stream_artist=$stream_artist"
                        ;;
                    state)
                        # Use state from STATE_FILE, not from old STATUS_FILE
                        echo "state=$current_state"
                        ;;
                    *)
                        echo "$key=$value"
                        ;;
                esac
            done < "$STATUS_FILE" > "$temp_status"
            mv "$temp_status" "$STATUS_FILE"
            chmod 644 "$STATUS_FILE"
        fi
        
        # Check every 10 seconds for metadata updates
        sleep 10
    done
}

# Start metadata extraction in background
extract_metadata &
metadata_pid=$!
echo $metadata_pid > "$METADATA_PID_FILE"

# Loop to handle reconnection if stream drops
while true; do
    # Check if we should stop
    if [ ! -f "$STATUS_FILE" ]; then
        break
    fi
    
    # Play the stream with bgmplayer
    SDL_AUDIODRIVER=pipewire "$PLAYER_CMD" -nodisp -autoexit \
        -loglevel error "$STREAM_URL" &
    
    bgplayer_pid=$!
    echo $bgplayer_pid > "$BGMPLAYER_PID_FILE"
    
    # Wait for PipeWire stream to be created and set initial volume
    sleep 0.3
    VOLUME_FILE="/tmp/bgmplayer_volume.txt"
    if [ -f "$VOLUME_FILE" ]; then
        DESIRED_VOL=$(cat "$VOLUME_FILE")
        /home/fpp/media/plugins/fpp-plugin-BackgroundMusic/scripts/set_bgmplayer_volume.sh "$DESIRED_VOL" 2>&1
    fi
    
    # Wait for bgmplayer to exit
    wait $bgplayer_pid
    exit_code=$?
    
    rm -f "$BGMPLAYER_PID_FILE"
    
    # If exit code is 0, it was a clean exit (user stopped it)
    if [ $exit_code -eq 0 ] || [ ! -f "$STATUS_FILE" ]; then
        break
    fi
    
    # Otherwise, stream dropped - wait a bit and reconnect
    echo "Stream disconnected (exit code: $exit_code), reconnecting in 3 seconds..." >&2
    sleep 3
done

# Cleanup - kill metadata extraction process
if [ -f "$METADATA_PID_FILE" ]; then
    kill $(cat "$METADATA_PID_FILE") 2>/dev/null
    rm -f "$METADATA_PID_FILE"
fi
rm -f "$STATUS_FILE" "$STATE_FILE" "$BGMPLAYER_PID_FILE"
STREAMSCRIPT
        
        # Replace placeholders
        sed -i "s|\$STREAM_URL_PLACEHOLDER|$bg_stream_url|g" /tmp/bg_music_loop.sh
        sed -i "s|\$PLAYER_CMD_PLACEHOLDER|$PLAYER_CMD|g" /tmp/bg_music_loop.sh
        
    else
        # Playlist mode - use bgmplayer for proper volume control
        cat > /tmp/bg_music_loop.sh << LOOPSCRIPT
#!/bin/bash
PLAYLIST_FILE="/tmp/background_music_playlist.m3u"
SHUFFLE_MODE="${shuffle_mode:-0}"
ENABLE_CROSSFADE="${enable_crossfade:-0}"
CROSSFADE_DURATION="${crossfade_duration:-3}"
VOLUME_LEVEL="100"
PLAYER_CMD="${PLAYER_CMD}"
STATUS_FILE="/tmp/bg_music_status.txt"
STATE_FILE="/tmp/bg_music_state.txt"
BGMPLAYER_PID_FILE="/tmp/bg_music_bgmplayer.pid"
BGMPLAYER_NEXT_PID_FILE="/tmp/bg_music_bgmplayer_next.pid"
JUMP_FILE="/tmp/bg_music_jump.txt"
PREVIOUS_FILE="/tmp/bg_music_previous.txt"
NEXT_FILE="/tmp/bg_music_next.txt"
REORDER_FILE="/tmp/bg_music_reorder.txt"

# Initialize state
echo "playing" > "\$STATE_FILE"

# Function to shuffle array
shuffle_array() {
    local i tmp size max rand
    size=\${#playlist_files[@]}
    for ((i=size-1; i>0; i--)); do
        rand=\$((RANDOM % (i+1)))
        tmp=\${playlist_files[i]}
        playlist_files[i]=\${playlist_files[rand]}
        playlist_files[rand]=\$tmp
    done
}

# Function to play track with crossfade support
# Returns: 0 = normal completion with crossfade, 1 = normal completion without crossfade, 2 = skipped/interrupted
play_track_with_crossfade() {
    local media_file="\$1"
    local track_name="\$2"
    local duration="\$3"
    local track_number="\$4"
    local total_tracks="\$5"
    local next_media_file="\$6"
    
    # Calculate when to start crossfade (duration - crossfade_duration seconds)
    local crossfade_start_time=0
    if [ "\$ENABLE_CROSSFADE" = "1" ] && [ -n "\$next_media_file" ] && [ "\$duration" -gt "\$CROSSFADE_DURATION" ]; then
        crossfade_start_time=\$((duration - CROSSFADE_DURATION))
    fi
    
    # Update status before starting
    update_status "\$track_name" "\$duration" 0 "\$track_number" "\$total_tracks"
    
    # Start bgmplayer in background
    "\$PLAYER_CMD" -nodisp -autoexit -loglevel error "\$media_file" &
    local player_pid=\$!
    echo "\$player_pid" > "\$BGMPLAYER_PID_FILE"
    
    # Wait for PipeWire stream to be created and set initial volume
    sleep 0.5
    VOLUME_FILE="/tmp/bgmplayer_volume.txt"
    if [ -f "\$VOLUME_FILE" ]; then
        DESIRED_VOL=\$(cat "\$VOLUME_FILE")
        /home/fpp/media/plugins/fpp-plugin-BackgroundMusic/scripts/set_bgmplayer_volume.sh "\$DESIRED_VOL" >/dev/null 2>&1 &
    fi
    
    # Track progress while playing
    local elapsed=0
    local crossfade_started=0
    local next_player_pid=0
    
    while kill -0 \$player_pid 2>/dev/null; do
        sleep 1
        
        # Volume is already set at bgmplayer startup - no need to re-apply
        
        # Only increment elapsed time if not paused
        local current_state="playing"
        if [ -f "\$STATE_FILE" ]; then
            current_state=\$(cat "\$STATE_FILE")
        fi
        
        if [ "\$current_state" != "paused" ]; then
            elapsed=\$((elapsed + 1))
        fi
        
        update_status "\$track_name" "\$duration" "\$elapsed" "\$track_number" "\$total_tracks"
        
        # Start crossfade if enabled and time reached
        if [ \$crossfade_started -eq 0 ] && [ \$crossfade_start_time -gt 0 ] && [ \$elapsed -ge \$crossfade_start_time ]; then
            crossfade_started=1
            # Start next track with bgmplayer
            "\$PLAYER_CMD" -nodisp -autoexit -loglevel error "\$next_media_file" &
            next_player_pid=\$!
            echo "\$next_player_pid" > "\$BGMPLAYER_NEXT_PID_FILE"
            echo "\$(date +%s.%N) [CROSSFADE] Started next PID=\$next_player_pid file='\$(basename "\$next_media_file")'" >&2
            
            # Wait for PipeWire stream and set volume for crossfade track
            (
                sleep 0.5
                VOLUME_FILE="/tmp/bgmplayer_volume.txt"
                if [ -f "\$VOLUME_FILE" ]; then
                    DESIRED_VOL=\$(cat "\$VOLUME_FILE")
                    /home/fpp/media/plugins/fpp-plugin-BackgroundMusic/scripts/set_bgmplayer_volume.sh "\$DESIRED_VOL" >/dev/null 2>&1
                fi
            ) &
        fi
        
        # Check for jump/skip/previous commands
        if [ -f "\$JUMP_FILE" ] || [ -f "\$NEXT_FILE" ] || [ -f "\$PREVIOUS_FILE" ]; then
            kill \$player_pid 2>/dev/null
            [ \$next_player_pid -gt 0 ] && kill \$next_player_pid 2>/dev/null
            return 2  # Interrupted
        fi
    done
    
    # Wait for player to fully exit
    wait \$player_pid 2>/dev/null
    rm -f "\$BGMPLAYER_PID_FILE"
    
    # If crossfade was started, the next track is now the current player
    if [ \$crossfade_started -eq 1 ] && [ \$next_player_pid -gt 0 ]; then
        echo "\$next_player_pid" > "\$BGMPLAYER_PID_FILE"
        return 0  # Crossfade completed - next track already playing
    fi
    
    return 1  # Normal completion without crossfade
}

# Function to get track duration in seconds using ffprobe
get_duration() {
    local file="\$1"
    ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "\$file" 2>/dev/null | cut -d'.' -f1
}

# Function to update status file
update_status() {
    local filename="\$1"
    local duration="\$2"
    local elapsed="\$3"
    local track_num="\$4"
    local total_tracks="\$5"
    local progress=0
    local state="playing"
    
    # Read current state if file exists
    if [ -f "\$STATE_FILE" ]; then
        state=\$(cat "\$STATE_FILE")
    fi
    
    # Calculate progress percentage
    if [ "\$duration" -gt 0 ]; then
        progress=\$((elapsed * 100 / duration))
    fi
    
    # Ensure progress doesn't exceed 100
    [ \$progress -gt 100 ] && progress=100
    
    # Write status file (use printf to safely handle special characters)
    {
        echo "filename=\$filename"
        echo "duration=\$duration"
        echo "elapsed=\$elapsed"
        echo "progress=\$progress"
        echo "state=\$state"
        echo "track_number=\$track_num"
        echo "total_tracks=\$total_tracks"
    } > "\$STATUS_FILE"
    
    # Make status file world-readable so web UI can access it
    chmod 644 "\$STATUS_FILE" 2>/dev/null
}

# Main loop - continuously play music
current_track_index=0
previous_track_index=-1
last_playlist_track=""

# Check if we should resume from previous position
if [ -f "\$STATUS_FILE" ]; then
    saved_track=\$(grep "^track_number=" "\$STATUS_FILE" | cut -d'=' -f2)
    if [ -n "\$saved_track" ] && [ "\$saved_track" -gt 0 ]; then
        # Resume from the next track after the saved position
        current_track_index=\$saved_track
        echo "Resuming from track \$current_track_index (continuing from previous session)" >&2
    fi
fi

while true; do
    # Read playlist into array
    playlist_files=()
    while IFS= read -r media_file || [ -n "\$media_file" ]; do
        # Skip comments and empty lines
        if [[ "\$media_file" =~ ^#.*\$ ]] || [ -z "\$media_file" ]; then
            continue
        fi
        playlist_files+=("\$media_file")
    done < "\$PLAYLIST_FILE"
    
    total_tracks=\${#playlist_files[@]}
    
    # If playlist is empty, wait a bit before retrying
    if [ \$total_tracks -eq 0 ]; then
        echo "Warning: No files in playlist, waiting..." >&2
        sleep 5
        continue
    fi
    
    # Check if playlist was reordered externally
    if [ -f "\$REORDER_FILE" ]; then
        rm -f "\$REORDER_FILE"
        # Try to maintain position based on the currently playing file
        if [ -n "\$last_playlist_track" ]; then
            found_at_index=-1
            for i in "\${!playlist_files[@]}"; do
                if [ "\${playlist_files[i]}" = "\$last_playlist_track" ]; then
                    found_at_index=\$i
                    break
                fi
            done
            
            # Update to new position if found
            if [ \$found_at_index -ge 0 ]; then
                # Current track found - move to next track in new order
                current_track_index=\$((found_at_index + 1))
                if [ \$current_track_index -ge \$total_tracks ]; then
                    current_track_index=0
                fi
                echo "Playlist reordered - advancing from index \$found_at_index to \$current_track_index" >&2
            elif [ \$current_track_index -ge \$total_tracks ]; then
                # Track not found and index out of bounds - wrap to start
                current_track_index=0
                echo "Playlist reordered - track not found, wrapping to start" >&2
            fi
        elif [ \$current_track_index -ge \$total_tracks ]; then
            # No last track info but index out of bounds - wrap to start
            current_track_index=0
            echo "Playlist reordered - no position info, wrapping to start" >&2
        fi
    fi
    
    # Shuffle if enabled (only on first run or after full loop)
    if [ "\$SHUFFLE_MODE" = "1" ] && [ \$current_track_index -eq 0 ]; then
        shuffle_array
    fi
    
    # Check for jump command BEFORE starting track
    if [ -f "\$JUMP_FILE" ]; then
        jump_to=\$(cat "\$JUMP_FILE")
        rm -f "\$JUMP_FILE"
        if [ "\$jump_to" -ge 1 ] && [ "\$jump_to" -le \$total_tracks ]; then
            current_track_index=\$((jump_to - 1))
        fi
    fi
    
    # Get current track
    media_file="\${playlist_files[\$current_track_index]}"
    track_name=\$(basename "\$media_file")
    track_number=\$((current_track_index + 1))
    
    # Save current track for reordering detection
    last_playlist_track="\$media_file"
    
    # Get duration in seconds
    duration=\$(get_duration "\$media_file")
    [ -z "\$duration" ] && duration=0
    
    # Determine next track for crossfade
    next_track_index=\$((current_track_index + 1))
    if [ \$next_track_index -ge \$total_tracks ]; then
        next_track_index=0
    fi
    next_media_file="\${playlist_files[\$next_track_index]}"
    
    # Use crossfade playback if enabled, otherwise standard playback
    crossfade_happened=0
    if [ "\$ENABLE_CROSSFADE" = "1" ]; then
        # Crossfade playback
        play_track_with_crossfade "\$media_file" "\$track_name" "\$duration" "\$track_number" "\$total_tracks" "\$next_media_file"
        result=\$?
        if [ \$result -eq 0 ]; then
            # Crossfade completed - next track is already playing and we need to wait for it
            crossfade_happened=1
            track_was_skipped=0
            
            # The next track is now playing - we need to monitor it
            # Advance index to reflect the track that's actually playing
            current_track_index=\$next_track_index
            
            # Now monitor the NEXT track (which is actually playing) until completion
            # Get info about the track that's actually playing
            media_file="\${playlist_files[\$current_track_index]}"
            track_name=\$(basename "\$media_file")
            track_number=\$((current_track_index + 1))
            duration=\$(get_duration "\$media_file")
            [ -z "\$duration" ] && duration=0
            
            # Read the PID of the currently playing track (set by crossfade function)
            if [ -f "\$BGMPLAYER_PID_FILE" ]; then
                player_pid=\$(cat "\$BGMPLAYER_PID_FILE")
                
                # Monitor this track as it plays
                elapsed=0
                while kill -0 \$player_pid 2>/dev/null; do
                    sleep 1
                    
                    current_state="playing"
                    if [ -f "\$STATE_FILE" ]; then
                        current_state=\$(cat "\$STATE_FILE")
                    fi
                    
                    if [ "\$current_state" != "paused" ]; then
                        elapsed=\$((elapsed + 1))
                    fi
                    
                    update_status "\$track_name" "\$duration" "\$elapsed" "\$track_number" "\$total_tracks"
                    
                    # Check for skip commands
                    if [ -f "\$JUMP_FILE" ] || [ -f "\$NEXT_FILE" ] || [ -f "\$PREVIOUS_FILE" ]; then
                        kill \$player_pid 2>/dev/null
                        track_was_skipped=1
                        break
                    fi
                done
                
                wait \$player_pid 2>/dev/null
                rm -f "\$BGMPLAYER_PID_FILE"
            fi
            
            # After crossfade, we've already played this track in full.
            # Skip the rest of the loop iteration (don't execute normal playback code)
            # and go directly to the next loop iteration which will advance index normally.
            continue
        elif [ \$result -eq 1 ]; then
            # Normal completion without crossfade
            track_was_skipped=0
        else
            # Interrupted/skipped
            track_was_skipped=1
        fi
    else
        # Standard playback (original code)
        update_status "\$track_name" "\$duration" 0 "\$track_number" "\$total_tracks"
        
        echo "\$(date +%s.%N) [START] Starting track: \$track_name file='\$media_file'" >&2
        "\$PLAYER_CMD" -nodisp -autoexit -loglevel error "\$media_file" &
    player_pid=\$!
    echo "\$player_pid" > "\$BGMPLAYER_PID_FILE"
        
        # Wait for PipeWire stream to be created and set initial volume
        sleep 0.5
        VOLUME_FILE="/tmp/bgmplayer_volume.txt"
        if [ -f "\$VOLUME_FILE" ]; then
            DESIRED_VOL=\$(cat "\$VOLUME_FILE")
            /home/fpp/media/plugins/fpp-plugin-BackgroundMusic/scripts/set_bgmplayer_volume.sh "\$DESIRED_VOL" >/dev/null 2>&1 &
        fi
        
        elapsed=0
        track_was_skipped=0
        while kill -0 \$player_pid 2>/dev/null; do
            sleep 1
            
            current_state="playing"
            if [ -f "\$STATE_FILE" ]; then
                current_state=\$(cat "\$STATE_FILE")
            fi
            
            if [ "\$current_state" != "paused" ]; then
                elapsed=\$((elapsed + 1))
            fi
            
            update_status "\$track_name" "\$duration" "\$elapsed" "\$track_number" "\$total_tracks"
            
            if [ -f "\$JUMP_FILE" ]; then
                kill \$player_pid 2>/dev/null
                track_was_skipped=1
                break
            fi
            
            if [ -f "\$PREVIOUS_FILE" ]; then
                kill \$player_pid 2>/dev/null
                track_was_skipped=1
                break
            fi
            
            if [ -f "\$NEXT_FILE" ]; then
                kill \$player_pid 2>/dev/null
                track_was_skipped=1
                break
            fi
        done
        
        wait \$player_pid 2>/dev/null
        rm -f "\$BGMPLAYER_PID_FILE"
    fi
    
    # Check what caused the track to end and handle navigation
    previous_pressed=0
    next_pressed=0
    
    # Check for previous track command
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
    
    # Check for next track command
    if [ -f "\$NEXT_FILE" ]; then
        rm -f "\$NEXT_FILE"
        next_pressed=1
        # Increment will happen below if previous wasn't pressed
    fi
    
    # Save the current track file path for playlist change detection
    # This is ONLY used when playlist is externally reordered
    # We do NOT save it on normal completion - let index increment handle progression
    # Only save if we need to maintain position through external changes
    
    # Save current index as previous for next iteration
    previous_track_index=\$current_track_index
    
    # Move to next track (unless previous was pressed, which already set the correct index)
    # Note: If crossfade happened, we already advanced the index during monitoring, so just increment by 1
    if [ \$previous_pressed -eq 0 ]; then
        current_track_index=\$((current_track_index + 1))
        
        # Check if we would wrap around - if so, check for pending reorder first
        if [ \$current_track_index -ge \$total_tracks ]; then
            # If playlist was reordered, don't wrap - let reorder detection handle it
            if [ -f "\$REORDER_FILE" ]; then
                # Keep the incremented index, reorder detection will fix it in next loop
                echo "At playlist end with pending reorder - will reposition after reload" >&2
            else
                # No reorder pending, normal wrap to start
                current_track_index=0
                last_playlist_track=""  # Reset on loop restart
            fi
        fi
    fi
    
    # Small sleep to prevent CPU spinning if file fails immediately
    sleep 0.1
done
LOOPSCRIPT
    fi  # End of if stream vs playlist
    
    chmod +x /tmp/bg_music_loop.sh
    
    # Start the looping script in background
    nohup /bin/bash /tmp/bg_music_loop.sh > /tmp/background_music_player.log 2>&1 &
    
    local pid=$!
    echo $pid > "$PID_FILE"
    # Also write to the file the API expects
    echo $pid > "/tmp/background_music_start.pid"
    
    # Verify it started
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

# Function to pause background music
pause_music() {
    if [ ! -f "$BGMPLAYER_PID_FILE" ]; then
        echo "No active playback to pause"
        return 1
    fi
    
    local bgmplayer_pid=$(cat "$BGMPLAYER_PID_FILE")
    
    if ps -p "$bgmplayer_pid" > /dev/null 2>&1; then
        kill -STOP "$bgmplayer_pid" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "paused" > "$STATE_FILE"
            # Update status file so UI shows paused state
            if [ -f "/tmp/bg_music_status.txt" ]; then
                sed -i 's/^state=.*/state=paused/' /tmp/bg_music_status.txt
            fi
            echo "Background music paused"
            return 0
        else
            echo "Failed to pause playback"
            return 1
        fi
    else
        echo "Playback process not found"
        return 1
    fi
}

# Function to resume background music
resume_music() {
    if [ ! -f "$BGMPLAYER_PID_FILE" ]; then
        echo "No paused playback to resume"
        return 1
    fi
    
    local bgmplayer_pid=$(cat "$BGMPLAYER_PID_FILE")
    
    if ps -p "$bgmplayer_pid" > /dev/null 2>&1; then
        kill -CONT "$bgmplayer_pid" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "playing" > "$STATE_FILE"
            # Update status file so UI shows playing state
            if [ -f "/tmp/bg_music_status.txt" ]; then
                sed -i 's/^state=.*/state=playing/' /tmp/bg_music_status.txt
            fi
            echo "Background music resumed"
            return 0
        else
            echo "Failed to resume playback"
            return 1
        fi
    else
        echo "Playback process not found"
        return 1
    fi
}

# Function to jump to a specific track
jump_to_track() {
    local track_number="$1"
    
    if [ -z "$track_number" ] || [ "$track_number" -lt 1 ]; then
        echo "ERROR: Invalid track number"
        return 1
    fi
    
    # Write the target track number to a control file
    echo "$track_number" > /tmp/bg_music_jump.txt
    chown fpp:fpp /tmp/bg_music_jump.txt 2>/dev/null
    
    # Stop current bgmplayer if running
    if [ -f "$BGMPLAYER_PID_FILE" ]; then
        local bgmplayer_pid=$(cat "$BGMPLAYER_PID_FILE")
        if ps -p "$bgmplayer_pid" > /dev/null 2>&1; then
            kill "$bgmplayer_pid" 2>/dev/null
            wait "$bgmplayer_pid" 2>/dev/null
        fi
    fi
    
    echo "Jumping to track $track_number"
    return 0
}

# Function to skip to next track
next_track() {
    # Write a signal file to indicate we want to move forward
    echo "1" > /tmp/bg_music_next.txt
    chown fpp:fpp /tmp/bg_music_next.txt 2>/dev/null
    
    # Kill current bgmplayer
    if [ -f "$BGMPLAYER_PID_FILE" ]; then
        local bgmplayer_pid=$(cat "$BGMPLAYER_PID_FILE")
        if ps -p "$bgmplayer_pid" > /dev/null 2>&1; then
            kill "$bgmplayer_pid" 2>/dev/null
            echo "Skipping to next track"
            return 0
        fi
    fi
    echo "No track currently playing"
    return 1
}

# Function to go to previous track
previous_track() {
    # Write a signal file to indicate we want to go back
    echo "1" > /tmp/bg_music_previous.txt
    chown fpp:fpp /tmp/bg_music_previous.txt 2>/dev/null
    
    # Kill current bgmplayer
    if [ -f "$BGMPLAYER_PID_FILE" ]; then
        local bgmplayer_pid=$(cat "$BGMPLAYER_PID_FILE")
        if ps -p "$bgmplayer_pid" > /dev/null 2>&1; then
            kill "$bgmplayer_pid" 2>/dev/null
            echo "Going to previous track"
            return 0
        fi
    fi
    echo "No track currently playing"
    return 1
}

# Function to stop background music
stop_music() {
    # First, kill ALL bgmplayer processes unconditionally
    echo "Stopping all bgmplayer processes..."
    killall bgmplayer 2>/dev/null
    killall -9 bgmplayer 2>/dev/null
    
    # Kill any metadata extraction processes (specific to streaming)
    if [ -f "/tmp/bg_music_metadata.pid" ]; then
        local metadata_pid=$(cat /tmp/bg_music_metadata.pid)
        kill "$metadata_pid" 2>/dev/null
        kill -9 "$metadata_pid" 2>/dev/null
        rm -f /tmp/bg_music_metadata.pid
    fi
    
    if [ ! -f "$PID_FILE" ]; then
        echo "Background music PID file not found, cleaning up any orphaned processes..."
        # Kill any loop script processes
        pkill -f "bg_music_loop.sh" 2>/dev/null
        pkill -9 -f "bg_music_loop.sh" 2>/dev/null
        
        # Kill any bash processes running the loop script
        pkill -f "/bin/bash /tmp/bg_music_loop.sh" 2>/dev/null
        pkill -9 -f "/bin/bash /tmp/bg_music_loop.sh" 2>/dev/null
        
        # Clean up temp files
        rm -f "$BGMPLAYER_PID_FILE"
        rm -f "/tmp/background_music_start.pid"
        rm -f /tmp/bg_music_loop.sh
        rm -f "$STATE_FILE"
        rm -f /tmp/bg_music_status.txt
        
        echo "Cleanup complete"
        return 0
    fi
    
    local pid=$(cat "$PID_FILE")
    
    if ps -p "$pid" > /dev/null 2>&1; then
        echo "Stopping background music player (PID: $pid)..."
        
        # Remove status file first to signal loops to stop
        rm -f /tmp/bg_music_status.txt
        
        # Kill all child processes of the main script
        pkill -P "$pid" 2>/dev/null
        sleep 0.5
        pkill -9 -P "$pid" 2>/dev/null
        
        # Kill the main script
        kill "$pid" 2>/dev/null
        
        # Wait for processes to stop (max 5 seconds)
        local count=0
        while ps -p "$pid" > /dev/null 2>&1 && [ $count -lt 10 ]; do
            sleep 0.5
            count=$((count + 1))
        done
        
        # Force kill if still running
        if ps -p "$pid" > /dev/null 2>&1; then
            echo "Force stopping..."
            pkill -9 -P "$pid" 2>/dev/null
            kill -9 "$pid" 2>/dev/null
        fi
        
        echo "Background music stopped"
    else
        echo "Background music process not found (stale PID file)"
    fi
    
    # Always kill any remaining loop scripts and bash processes
    pkill -f "bg_music_loop.sh" 2>/dev/null
    pkill -9 -f "bg_music_loop.sh" 2>/dev/null
    pkill -f "/bin/bash /tmp/bg_music_loop.sh" 2>/dev/null
    pkill -9 -f "/bin/bash /tmp/bg_music_loop.sh" 2>/dev/null
    
    rm -f "$PID_FILE"
    rm -f "/tmp/background_music_start.pid"
    rm -f "$PLAYLIST_FILE"
    rm -f /tmp/bg_music_loop.sh
    # Remove status file to signal all loops to stop
    rm -f /tmp/bg_music_status.txt
    rm -f "$STATE_FILE"
    rm -f "$BGMPLAYER_PID_FILE"
    rm -f /tmp/bg_music_jump.txt
    rm -f /tmp/bg_music_previous.txt
    rm -f /tmp/bg_music_next.txt
    rm -f /tmp/bg_music_reorder.txt
    rm -f /tmp/bg_music_metadata.pid
    
    # Final safety check - kill any remaining bgmplayer processes
    # This catches orphaned processes that might have lost their PID tracking
    sleep 0.5
    if pgrep -x bgmplayer > /dev/null; then
        echo "Found orphaned bgmplayer processes, cleaning up..."
        killall -9 bgmplayer 2>/dev/null
    fi
    
    # Note: We do NOT manipulate ALSA volume. FPP controls ALSA via its volume slider.
    # Background music uses bgmplayer with system volume control via ALSA.
    
    echo "All background music processes stopped"
    return 0
}

# Function to check status
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

# Main script logic
case "$1" in
    start)
        start_music
        ;;
    stop)
        stop_music
        ;;
    restart)
        stop_music
        sleep 1
        start_music
        ;;
    pause)
        pause_music
        ;;
    resume)
        resume_music
        ;;
    next)
        next_track
        ;;
    previous)
        previous_track
        ;;
    jump)
        if [ -z "$2" ]; then
            echo "Usage: $0 jump <track_number>"
            exit 1
        fi
        jump_to_track "$2"
        ;;
    status)
        status_check
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|pause|resume|next|previous|jump <track_number>|status}"
        exit 1
        ;;
esac

exit $?
