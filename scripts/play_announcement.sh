#!/bin/bash
##########################################################################
# play_announcement.sh - Play public service announcement with ducking
# 
# Usage: play_announcement.sh <announcement_file> <duck_volume> <announcement_volume> [button_number] [button_label]
#
# This script:
# 1. Reduces background music volume (ducking)
# 2. Plays announcement at specified volume
# 3. Restores background music volume when done
##########################################################################

ANNOUNCEMENT_FILE="$1"
DUCK_VOLUME="${2:-30}"          # Volume to duck background music to (default 30%)
ANNOUNCEMENT_VOLUME="${3:-90}"  # Volume for announcement playback (default 90%)
BUTTON_NUMBER="${4:-0}"         # Button number (optional)
BUTTON_LABEL="${5:-PSA}"        # Button label (optional)

PLUGIN_DIR="/home/fpp/media/plugins/fpp-plugin-BackgroundMusic"
PLUGIN_CONFIG="/home/fpp/media/config/plugin.fpp-plugin-BackgroundMusic"
LOG_FILE="/home/fpp/media/logs/fpp-plugin-BackgroundMusic.log"
ANNOUNCEMENT_PID_FILE="/tmp/announcement_player.pid"
ANNOUNCEMENT_STATUS_FILE="/tmp/announcement_status.txt"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [PSA] $1" >> "$LOG_FILE"
}

# Check if announcement file exists
if [ ! -f "$ANNOUNCEMENT_FILE" ]; then
    log_message "ERROR: Announcement file not found: $ANNOUNCEMENT_FILE"
    exit 1
fi

# Check if an announcement is already playing
if [ -f "$ANNOUNCEMENT_PID_FILE" ]; then
    EXISTING_PID=$(cat "$ANNOUNCEMENT_PID_FILE")
    if ps -p "$EXISTING_PID" > /dev/null 2>&1; then
        log_message "Announcement already playing (PID: $EXISTING_PID), skipping"
        exit 0
    fi
    rm -f "$ANNOUNCEMENT_PID_FILE"
fi

log_message "Playing announcement: $(basename "$ANNOUNCEMENT_FILE")"

# Get current background music volume
ORIGINAL_VOLUME=""
if [ -f "$PLUGIN_CONFIG" ]; then
    ORIGINAL_VOLUME=$(grep "^BackgroundMusicVolume=" "$PLUGIN_CONFIG" | cut -d'=' -f2 | tr -d '\r')
    if [ -z "$ORIGINAL_VOLUME" ]; then
        ORIGINAL_VOLUME=$(grep "^VolumeLevel=" "$PLUGIN_CONFIG" | cut -d'=' -f2 | tr -d '\r')
    fi
fi

# If no config volume found, get current FPP system volume
if [ -z "$ORIGINAL_VOLUME" ]; then
    ORIGINAL_VOLUME=$(curl -s "http://localhost/api/system/volume" | jq -r '.volume' 2>/dev/null)
fi
ORIGINAL_VOLUME=${ORIGINAL_VOLUME:-70}

log_message "Original volume: ${ORIGINAL_VOLUME}%, ducking to: ${DUCK_VOLUME}%, announcement volume: ${ANNOUNCEMENT_VOLUME}%"

# Check if background music is playing
BG_MUSIC_PLAYING=false
BG_PLAYER_PID=""
if [ -f "/tmp/bg_music_bgmplayer.pid" ]; then
    BG_PLAYER_PID=$(cat /tmp/bg_music_bgmplayer.pid)
    if ps -p "$BG_PLAYER_PID" > /dev/null 2>&1; then
        BG_MUSIC_PLAYING=true
        log_message "Background music detected (PID: $BG_PLAYER_PID)"
    fi
fi

# Ducking strategy using PipeWire stream volume control:
# 1. Duck background music stream to DUCK_VOLUME via PipeWire
# 2. Play PSA at ANNOUNCEMENT_VOLUME via its own bgmplayer instance
# 3. After PSA, restore background music stream volume
# This allows independent volume control for each audio stream

if [ "$BG_MUSIC_PLAYING" = true ]; then
    # Query actual current volume from PipeWire stream
    FPP_UID=$(id -u fpp)
    
    # Find background music stream by name using pw-dump + jq
    # Target BackgroundMusic_Main first, fallback to any BackgroundMusic
    BG_STREAM_ID=$(sudo -u fpp XDG_RUNTIME_DIR="/run/user/${FPP_UID}" \
        pw-dump 2>/dev/null | jq -r '.[] | select(.info.props["media.name"] == "BackgroundMusic_Main") | select(.type == "PipeWire:Interface:Node") | .id' | tail -1)
    
    # Fallback to any BackgroundMusic stream
    if [ -z "$BG_STREAM_ID" ]; then
        BG_STREAM_ID=$(sudo -u fpp XDG_RUNTIME_DIR="/run/user/${FPP_UID}" \
            pw-dump 2>/dev/null | jq -r '.[] | select(.info.props["media.name"] | startswith("BackgroundMusic")) | select(.type == "PipeWire:Interface:Node") | .id' | tail -1)
    fi
    
    if [ -n "$BG_STREAM_ID" ]; then
        # Get current volume from PipeWire stream
        CURRENT_BG_VOLUME=$(sudo -u fpp XDG_RUNTIME_DIR="/run/user/${FPP_UID}" \
            pw-dump 2>/dev/null | jq -r --arg id "$BG_STREAM_ID" '.[] | select(.id == ($id | tonumber)) | .info.params.Props[0].volume' 2>/dev/null)
        
        # Convert from 0.0-1.0 to 0-100, default to config value if query fails
        if [ -n "$CURRENT_BG_VOLUME" ] && [ "$CURRENT_BG_VOLUME" != "null" ]; then
            CURRENT_BG_VOLUME=$(awk "BEGIN {printf \"%.0f\", $CURRENT_BG_VOLUME * 100}")
        else
            CURRENT_BG_VOLUME=$ORIGINAL_VOLUME
        fi
        
        log_message "Ducking background music (PID $BG_PLAYER_PID) from ${CURRENT_BG_VOLUME}% to ${DUCK_VOLUME}% via PipeWire"
        
        # Save the stream ID and current volume for restoration
        echo "$BG_STREAM_ID" > /tmp/bg_music_stream_id.txt
        echo "$CURRENT_BG_VOLUME" > /tmp/bg_music_preduck_volume.txt
        # Set volume using pw-cli (volume is 0.0 to 1.0 for 0-100%)
        DUCK_PW_VOL=$(awk "BEGIN {printf \"%.2f\", $DUCK_VOLUME / 100.0}")
        sudo -u fpp XDG_RUNTIME_DIR="/run/user/${FPP_UID}" \
            pw-cli set-param "$BG_STREAM_ID" Props '{ volume: '"$DUCK_PW_VOL"' }' 2>/dev/null
        log_message "Background music ducked to ${DUCK_VOLUME}% (stream $BG_STREAM_ID, volume $DUCK_PW_VOL)"
    else
        log_message "WARNING: Could not find background music stream to duck"
    fi
fi

# Get FPP audio device
get_audio_device() {
    local audio_device=""
    
    if [ -f "/home/fpp/media/settings" ]; then
        audio_device=$(grep "^AlsaAudioDevice = " /home/fpp/media/settings | sed 's/AlsaAudioDevice = "\(.*\)"/\1/')
    fi
    
    if [ -z "$audio_device" ]; then
        if [ -f "/home/fpp/media/settings" ]; then
            audio_device=$(grep "^AudioOutput = " /home/fpp/media/settings | sed 's/AudioOutput = "\(.*\)"/\1/')
        fi
    fi
    
    # If audio_device is just a number (card number), convert to ALSA device format
    if [[ "$audio_device" =~ ^[0-9]+$ ]]; then
        # It's a card number - convert to plughw format
        local card_num="$audio_device"
        audio_device="plughw:${card_num},0"
    fi
    
    if [ -z "$audio_device" ]; then
        audio_device="sysdefault"
    fi
    
    echo "$audio_device"
}

AUDIO_DEVICE=$(get_audio_device)

# Wrap device in plug: for software mixing support
# The plug plugin provides automatic sample rate/format conversion and software mixing
# Don't wrap if already using plughw, plug, or dmix (they already have plugin/mixing support)
if [[ ! "$AUDIO_DEVICE" =~ ^plug: ]] && [[ ! "$AUDIO_DEVICE" =~ ^dmix: ]] && [[ ! "$AUDIO_DEVICE" =~ ^plughw: ]]; then
    AUDIO_DEVICE="plug:$AUDIO_DEVICE"
fi

log_message "Using audio device: $AUDIO_DEVICE"

# Get announcement duration
DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$ANNOUNCEMENT_FILE" 2>/dev/null | cut -d'.' -f1)
[ -z "$DURATION" ] && DURATION=0

# Save announcement status
# Quote the button label if it contains spaces
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

# Play announcement in background
(
    # PSA will play at ANNOUNCEMENT_VOLUME via its own PipeWire stream
    # Background music continues at ducked volume (independent streams)
    
    PLUGIN_DIR="/home/fpp/media/plugins/fpp-plugin-BackgroundMusic"

    # Ensure PipeWire is running and audio output is properly set
    # This is important when background music is not playing
    if [ "$BG_MUSIC_PLAYING" = false ]; then
        log_message "Background music not playing - ensuring PipeWire and audio output are configured"
        FPP_UID=$(id -u fpp)
        
        # Start PipeWire if not running (run as root, script handles internal sudo)
        if ! pgrep -u fpp pipewire > /dev/null 2>&1; then
            log_message "Starting PipeWire for fpp user"
            XDG_RUNTIME_DIR="/run/user/${FPP_UID}" bash "$PLUGIN_DIR/scripts/start_pipewire.sh" >> "$LOG_FILE" 2>&1
            sleep 0.3
        fi
        
        # Set the correct audio output (run as root, script handles internal sudo)
        XDG_RUNTIME_DIR="/run/user/${FPP_UID}" bash "$PLUGIN_DIR/scripts/set_audio_output.sh" >> "$LOG_FILE" 2>&1
    fi

    # Convert announcement to 48kHz stereo WAV for smoother playback through PipeWire
    TEMP_FILE="/tmp/psa_resampled_${$}.wav"
    if ! ffmpeg -y -loglevel error -i "$ANNOUNCEMENT_FILE" -ar 48000 -ac 2 "$TEMP_FILE"; then
        log_message "ERROR: Failed to transcode announcement for playback"
        rm -f "$TEMP_FILE"
        exit 1
    fi
    
    # Play announcement using PipeWire with same SDL config as background music
    # Run as fpp user to access PipeWire session
    FPP_UID=$(id -u fpp)
    sudo -u fpp XDG_RUNTIME_DIR="/run/user/${FPP_UID}" PIPEWIRE_RUNTIME_DIR="/run/user/${FPP_UID}" \
        PIPEWIRE_PROPS="{media.name=PSA_Announcement}" \
        SDL_AUDIODRIVER=pipewire \
        SDL_AUDIO_SAMPLES=4096 \
        "$PLUGIN_DIR/bgmplayer" -nodisp -autoexit \
        -loglevel error "$TEMP_FILE" >> "$LOG_FILE" 2>&1 &
    BGMPLAYER_PID=$!
    
    log_message "PSA player started with PID $BGMPLAYER_PID"
    
    # Set PSA stream volume using pw-cli - wait for stream to appear
    sleep 0.5
    
    FPP_UID=$(id -u fpp)
    
    # Find the PSA stream by name to set volume
    PSA_STREAM_ID=$(sudo -u fpp XDG_RUNTIME_DIR="/run/user/${FPP_UID}" \
        pw-dump 2>/dev/null | jq -r '.[] | select(.info.props["media.name"]? == "PSA_Announcement") | select(.type == "PipeWire:Interface:Node") | .id' | tail -1)
    
    log_message "Found PSA stream: ${PSA_STREAM_ID}"
    
    if [ -n "$PSA_STREAM_ID" ]; then
        # Set volume using pw-cli (volume is 0.0 to 1.0 for 0-100%)
        PSA_PW_VOL=$(awk "BEGIN {printf \"%.2f\", $ANNOUNCEMENT_VOLUME / 100.0}")
        sudo -u fpp XDG_RUNTIME_DIR="/run/user/${FPP_UID}" \
            pw-cli set-param "$PSA_STREAM_ID" Props '{ volume: '"$PSA_PW_VOL"' }' 2>/dev/null
        log_message "PSA stream volume set to ${ANNOUNCEMENT_VOLUME}% (stream $PSA_STREAM_ID, volume $PSA_PW_VOL)"
    elif [ -n "$PSA_STREAM_ID" ]; then
        log_message "WARNING: Only found 1 stream - not setting PSA volume to avoid affecting background music"
    else
        log_message "WARNING: Could not find PSA stream to set volume"
    fi
    
    # Wait for bgmplayer to finish
    wait $BGMPLAYER_PID 2>/dev/null
    PLAY_RESULT=$?
    
    log_message "DEBUG: announcement playback exit code: $PLAY_RESULT"
    
    if [ $PLAY_RESULT -eq 0 ]; then
        log_message "Announcement completed successfully"
    else
        log_message "ERROR: Announcement playback failed with code: $PLAY_RESULT"
    fi
    
    # Restore background music volume if it was playing
    if [ "$BG_MUSIC_PLAYING" = true ] && [ -f "/tmp/bg_music_bgmplayer.pid" ]; then
        CURRENT_BG_PID=$(cat /tmp/bg_music_bgmplayer.pid)
        if ps -p "$CURRENT_BG_PID" > /dev/null 2>&1; then
            # Get the volume to restore from our saved pre-duck value
            RESTORE_VOLUME=$ORIGINAL_VOLUME
            if [ -f /tmp/bg_music_preduck_volume.txt ]; then
                RESTORE_VOLUME=$(cat /tmp/bg_music_preduck_volume.txt)
            fi
            
            log_message "Restoring background music from ${DUCK_VOLUME}% to ${RESTORE_VOLUME}% via PipeWire"
            
            # Get the saved stream ID or find it again
            FPP_UID=$(id -u fpp)
            if [ -f "/tmp/bg_music_stream_id.txt" ]; then
                RESTORE_STREAM_ID=$(cat /tmp/bg_music_stream_id.txt)
            else
                # Fallback: find BackgroundMusic stream (Main first, then any)
                RESTORE_STREAM_ID=$(sudo -u fpp XDG_RUNTIME_DIR="/run/user/${FPP_UID}" \
                    pw-dump 2>/dev/null | jq -r '.[] | select(.info.props["media.name"]? == "BackgroundMusic_Main") | select(.type == "PipeWire:Interface:Node") | .id' | tail -1)
                if [ -z "$RESTORE_STREAM_ID" ]; then
                    RESTORE_STREAM_ID=$(sudo -u fpp XDG_RUNTIME_DIR="/run/user/${FPP_UID}" \
                        pw-dump 2>/dev/null | jq -r '.[] | select(.info.props["media.name"]? // "" | startswith("BackgroundMusic")) | select(.type == "PipeWire:Interface:Node") | .id' | tail -1)
                fi
            fi
            
            if [ -n "$RESTORE_STREAM_ID" ]; then
                # Set volume using pw-cli (volume is 0.0 to 1.0 for 0-100%)
                RESTORE_PW_VOL=$(awk "BEGIN {printf \"%.2f\", $RESTORE_VOLUME / 100.0}")
                sudo -u fpp XDG_RUNTIME_DIR="/run/user/${FPP_UID}" \
                    pw-cli set-param "$RESTORE_STREAM_ID" Props '{ volume: '"$RESTORE_PW_VOL"' }' 2>/dev/null
                log_message "Background music volume restored to ${RESTORE_VOLUME}% (stream $RESTORE_STREAM_ID, volume $RESTORE_PW_VOL)"
                
                # Clean up temporary files
                rm -f /tmp/bg_music_preduck_volume.txt
            else
                log_message "WARNING: Could not find background music stream to restore"
            fi
            
            rm -f /tmp/bg_music_stream_id.txt
        fi
    else
        log_message "No background music to restore (was not playing)"
    fi
    
    # Clean up temp audio, PID and status files
    rm -f "$TEMP_FILE"
    rm -f "$ANNOUNCEMENT_PID_FILE"
    rm -f "$ANNOUNCEMENT_STATUS_FILE"
    
) &

# Save the background process PID
ANNOUNCEMENT_PID=$!
echo "$ANNOUNCEMENT_PID" > "$ANNOUNCEMENT_PID_FILE"

log_message "Announcement started (PID: $ANNOUNCEMENT_PID)"

exit 0
