#!/bin/bash
# Background Music Player - plays audio files independently from FPP playlists
# Uses ffplay to ensure no conflict with FPP's playlist system

PLUGIN_DIR="/home/fpp/media/plugins/fpp-plugin-BackgroundMusic"
PLUGIN_CONFIG="/home/fpp/media/config/plugin.fpp-plugin-BackgroundMusic"
PID_FILE="/tmp/background_music_player.pid"
PLAYLIST_FILE="/tmp/background_music_playlist.m3u"
STATE_FILE="/tmp/bg_music_state.txt"
FFPLAY_PID_FILE="/tmp/bg_music_ffplay.pid"

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
    
    # Default to sysdefault if nothing found
    if [ -z "$audio_device" ]; then
        audio_device="sysdefault"
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

# Function to start background music
start_music() {
    # Check if already running
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            echo "Background music already running (PID: $pid)"
            return 0
        fi
    fi
    
    # Read configuration
    if [ ! -f "$PLUGIN_CONFIG" ]; then
        echo "ERROR: Plugin configuration not found"
        return 1
    fi
    
    local bg_playlist=$(grep "^BackgroundMusicPlaylist=" "$PLUGIN_CONFIG" | cut -d'=' -f2 | tr -d '\r')
    local shuffle_mode=$(grep "^ShuffleMusic=" "$PLUGIN_CONFIG" | cut -d'=' -f2 | tr -d '\r')
    local volume_level=$(grep "^BackgroundMusicVolume=" "$PLUGIN_CONFIG" | cut -d'=' -f2 | tr -d '\r')
    
    # Fallback to VolumeLevel for backward compatibility
    if [ -z "$volume_level" ]; then
        volume_level=$(grep "^VolumeLevel=" "$PLUGIN_CONFIG" | cut -d'=' -f2 | tr -d '\r')
    fi
    
    # Default volume to 70 if not set
    volume_level=${volume_level:-70}
    
    if [ -z "$bg_playlist" ]; then
        echo "ERROR: BackgroundMusicPlaylist not configured"
        return 1
    fi
    
    # Create playlist file
    if ! create_audio_playlist "$bg_playlist"; then
        return 1
    fi
    
    # Get audio device
    local audio_device=$(get_audio_device)
    
    # Wrap device in plug: for software mixing support (allows PSA announcements to play concurrently)
    # The plug plugin provides automatic sample rate/format conversion and software mixing
    if [[ ! "$audio_device" =~ ^plug: ]] && [[ ! "$audio_device" =~ ^dmix: ]]; then
        audio_device="plug:$audio_device"
    fi
    
    echo "Starting background music player..."
    echo "Playlist: $bg_playlist"
    echo "Audio Device: $audio_device"
    echo "System Volume (ALSA): ${volume_level}%"
    echo "ffplay Volume: 100% (controlled by ALSA)"
    echo "Shuffle Mode: ${shuffle_mode:-0}"
    
    # Start ffplay in background with loop
    # -nodisp: no video display
    # -autoexit: exit when playback finished
    # -volume: volume level (0-100)
    # -loglevel error: only show errors
    # Note: ffplay doesn't support -playlist with -loop, so we use a wrapper approach
    
    # Create a simple looping script with shuffle support
    cat > /tmp/bg_music_loop.sh << LOOPSCRIPT
#!/bin/bash
PLAYLIST_FILE="/tmp/background_music_playlist.m3u"
SHUFFLE_MODE="${shuffle_mode:-0}"
VOLUME_LEVEL="100"
AUDIO_DEVICE="${audio_device}"
STATUS_FILE="/tmp/bg_music_status.txt"
STATE_FILE="/tmp/bg_music_state.txt"
FFPLAY_PID_FILE="/tmp/bg_music_ffplay.pid"
JUMP_FILE="/tmp/bg_music_jump.txt"
PREVIOUS_FILE="/tmp/bg_music_previous.txt"
NEXT_FILE="/tmp/bg_music_next.txt"

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
    
    # Write status file
    echo "filename=\$filename" > "\$STATUS_FILE"
    echo "duration=\$duration" >> "\$STATUS_FILE"
    echo "elapsed=\$elapsed" >> "\$STATUS_FILE"
    echo "progress=\$progress" >> "\$STATUS_FILE"
    echo "state=\$state" >> "\$STATUS_FILE"
    echo "track_number=\$track_num" >> "\$STATUS_FILE"
    echo "total_tracks=\$total_tracks" >> "\$STATUS_FILE"
}

# Main loop - continuously play music
current_track_index=0
previous_track_index=-1
last_playlist_track=""

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
    
    # If playlist order changed (detected by comparing with last track), 
    # try to maintain position based on the currently playing file
    if [ -n "\$last_playlist_track" ]; then
        # Find the current track in the new playlist order
        for i in "\${!playlist_files[@]}"; do
            if [ "\${playlist_files[i]}" = "\$last_playlist_track" ]; then
                current_track_index=\$i
                break
            fi
        done
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
    
    # Get duration in seconds
    duration=\$(get_duration "\$media_file")
    [ -z "\$duration" ] && duration=0
    
    # Update status before starting
    update_status "\$track_name" "\$duration" 0 "\$track_number" "\$total_tracks"
    
    # Start ffplay in background so we can track progress
    # Use SDL audio driver with ALSA and specify the device
    SDL_AUDIODRIVER=alsa AUDIODEV="\$AUDIO_DEVICE" ffplay -nodisp -autoexit -volume "\$VOLUME_LEVEL" -loglevel error "\$media_file" &
    player_pid=\$!
    echo "\$player_pid" > "\$FFPLAY_PID_FILE"
    
    # Track progress while playing
    elapsed=0
    track_was_skipped=0
    while kill -0 \$player_pid 2>/dev/null; do
        sleep 1
        
        # Only increment elapsed time if not paused
        current_state="playing"
        if [ -f "\$STATE_FILE" ]; then
            current_state=\$(cat "\$STATE_FILE")
        fi
        
        if [ "\$current_state" != "paused" ]; then
            elapsed=\$((elapsed + 1))
        fi
        
        update_status "\$track_name" "\$duration" "\$elapsed" "\$track_number" "\$total_tracks"
        
        # Check for jump command while playing
        if [ -f "\$JUMP_FILE" ]; then
            kill \$player_pid 2>/dev/null
            track_was_skipped=1
            break
        fi
        
        # Check for previous command while playing
        if [ -f "\$PREVIOUS_FILE" ]; then
            kill \$player_pid 2>/dev/null
            track_was_skipped=1
            break
        fi
        
        # Check for next command while playing
        if [ -f "\$NEXT_FILE" ]; then
            kill \$player_pid 2>/dev/null
            track_was_skipped=1
            break
        fi
    done
    
    # Wait for ffplay to fully exit
    wait \$player_pid 2>/dev/null
    rm -f "\$FFPLAY_PID_FILE"
    
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
    # BUT only if track completed naturally (not skipped via next/previous/jump)
    if [ \$track_was_skipped -eq 0 ] && [ \$next_pressed -eq 0 ] && [ \$previous_pressed -eq 0 ]; then
        last_playlist_track="\$media_file"
    fi
    
    # Save current index as previous for next iteration
    previous_track_index=\$current_track_index
    
    # Move to next track (unless previous was pressed, which already set the correct index)
    if [ \$previous_pressed -eq 0 ]; then
        current_track_index=\$((current_track_index + 1))
        if [ \$current_track_index -ge \$total_tracks ]; then
            current_track_index=0
            last_playlist_track=""  # Reset on loop restart
        fi
    fi
    
    # Small sleep to prevent CPU spinning if file fails immediately
    sleep 0.1
done
LOOPSCRIPT
    
    chmod +x /tmp/bg_music_loop.sh
    
    # Set ALSA volume to BackgroundMusicVolume via FPP API
    # This ensures the system volume matches what the user configured
    echo "Setting system volume to ${volume_level}% via FPP API"
    curl -s -X POST -H "Content-Type: application/json" \
         -d "{\"volume\": ${volume_level}}" \
         "http://localhost/api/system/volume" > /dev/null 2>&1
    
    # Start the looping script in background
    nohup /bin/bash /tmp/bg_music_loop.sh > /tmp/background_music_player.log 2>&1 &
    
    local pid=$!
    echo $pid > "$PID_FILE"
    
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
    if [ ! -f "$FFPLAY_PID_FILE" ]; then
        echo "No active playback to pause"
        return 1
    fi
    
    local ffplay_pid=$(cat "$FFPLAY_PID_FILE")
    
    if ps -p "$ffplay_pid" > /dev/null 2>&1; then
        kill -STOP "$ffplay_pid" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "paused" > "$STATE_FILE"
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
    if [ ! -f "$FFPLAY_PID_FILE" ]; then
        echo "No paused playback to resume"
        return 1
    fi
    
    local ffplay_pid=$(cat "$FFPLAY_PID_FILE")
    
    if ps -p "$ffplay_pid" > /dev/null 2>&1; then
        kill -CONT "$ffplay_pid" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "playing" > "$STATE_FILE"
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
    
    # Stop current ffplay if running
    if [ -f "$FFPLAY_PID_FILE" ]; then
        local ffplay_pid=$(cat "$FFPLAY_PID_FILE")
        if ps -p "$ffplay_pid" > /dev/null 2>&1; then
            kill "$ffplay_pid" 2>/dev/null
            wait "$ffplay_pid" 2>/dev/null
        fi
    fi
    
    echo "Jumping to track $track_number"
    return 0
}

# Function to skip to next track
next_track() {
    # Write a signal file to indicate we want to move forward
    echo "1" > /tmp/bg_music_next.txt
    
    # Kill current ffplay
    if [ -f "$FFPLAY_PID_FILE" ]; then
        local ffplay_pid=$(cat "$FFPLAY_PID_FILE")
        if ps -p "$ffplay_pid" > /dev/null 2>&1; then
            kill "$ffplay_pid" 2>/dev/null
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
    
    # Kill current ffplay
    if [ -f "$FFPLAY_PID_FILE" ]; then
        local ffplay_pid=$(cat "$FFPLAY_PID_FILE")
        if ps -p "$ffplay_pid" > /dev/null 2>&1; then
            kill "$ffplay_pid" 2>/dev/null
            echo "Going to previous track"
            return 0
        fi
    fi
    echo "No track currently playing"
    return 1
}

# Function to stop background music
stop_music() {
    if [ ! -f "$PID_FILE" ]; then
        echo "Background music is not running"
        return 0
    fi
    
    local pid=$(cat "$PID_FILE")
    
    if ps -p "$pid" > /dev/null 2>&1; then
        echo "Stopping background music player (PID: $pid)..."
        
        # Kill the main script and all its children (including ffplay processes)
        pkill -P "$pid" 2>/dev/null
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
        
        # Also kill any remaining ffplay processes that might be orphaned
        pkill -f "ffplay.*background_music" 2>/dev/null
        pkill -f "bg_music_loop.sh" 2>/dev/null
        
        echo "Background music stopped"
    else
        echo "Background music process not found (stale PID file)"
    fi
    
    rm -f "$PID_FILE"
    rm -f "$PLAYLIST_FILE"
    rm -f /tmp/bg_music_loop.sh
    rm -f /tmp/bg_music_status.txt
    rm -f "$STATE_FILE"
    rm -f "$FFPLAY_PID_FILE"
    rm -f /tmp/bg_music_jump.txt
    rm -f /tmp/bg_music_previous.txt
    rm -f /tmp/bg_music_next.txt
    
    # Note: We do NOT manipulate ALSA volume. FPP controls ALSA via its volume slider.
    # Background music uses ffplay's -volume parameter which multiplies with ALSA.
    
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
