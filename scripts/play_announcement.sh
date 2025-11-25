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

# Ducking strategy using bgmplayer's runtime volume control:
# 1. Send volume control command to background music player to reduce its volume
# 2. Play PSA at normal volume (both use same system volume via dmix)
# 3. After PSA, restore background music volume

if [ "$BG_MUSIC_PLAYING" = true ]; then
    # DUCK_VOLUME is the target volume level (e.g., 20 means bgmplayer should be at 20%)
    # bgmplayer starts at 100%, so we need to decrease to DUCK_VOLUME
    
    log_message "Ducking background music from 100% to ${DUCK_VOLUME}% via SIGUSR1 signals"
    
    # Calculate how many 10% decreases needed to reach target
    DECREASES=$(( (100 - DUCK_VOLUME) / 10 ))
    
    # Send SIGUSR1 signals to decrease volume by 10% each time
    for ((i=0; i<DECREASES; i++)); do
        kill -SIGUSR1 "$BG_PLAYER_PID" 2>/dev/null
        sleep 0.1
    done
    
    log_message "Background music ducked to ~${DUCK_VOLUME}% (continues playing at reduced volume)"
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
    # Temporarily raise system volume to ANNOUNCEMENT_VOLUME for the PSA
    # Background music is already ducked to low internal volume
    
    PLUGIN_DIR="/home/fpp/media/plugins/fpp-plugin-BackgroundMusic"
    
    log_message "Setting system volume to ${ANNOUNCEMENT_VOLUME}% for announcement (was ${ORIGINAL_VOLUME}%)"
    
    # Set system volume to announcement level via FPP API
    curl -s -X PUT "http://localhost/api/system/volume" \
        -H "Content-Type: application/json" \
        -d "{\"volume\":${ANNOUNCEMENT_VOLUME}}" > /dev/null 2>&1

    # Ensure PipeWire is running and audio output is properly set
    # This is important when background music is not playing
    if [ "$BG_MUSIC_PLAYING" = false ]; then
        log_message "Background music not playing - ensuring PipeWire and audio output are configured"
        FPP_UID=$(id -u fpp)
        
        # Start PipeWire if not running (run as root, script handles internal sudo)
        if ! pgrep -u fpp pipewire > /dev/null 2>&1; then
            log_message "Starting PipeWire for fpp user"
            XDG_RUNTIME_DIR="/run/user/${FPP_UID}" bash "$PLUGIN_DIR/scripts/start_pipewire.sh" >> "$LOG_FILE" 2>&1
            sleep 1
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
    
    # Play announcement using PipeWire via ALSA with larger buffer to avoid underruns
    # Run as fpp user to access PipeWire session
    FPP_UID=$(id -u fpp)
    sudo -u fpp XDG_RUNTIME_DIR="/run/user/${FPP_UID}" PIPEWIRE_RUNTIME_DIR="/run/user/${FPP_UID}" \
        SDL_AUDIODRIVER=alsa SDL_AUDIO_ALSA_DEVICE="pipewire" \
        SDL_AUDIO_SAMPLES=8192 \
        "$PLUGIN_DIR/bgmplayer" -nodisp -autoexit \
        -loglevel error "$TEMP_FILE" >> "$LOG_FILE" 2>&1 &
    BGMPLAYER_PID=$!
    
    log_message "PSA player started with PID $BGMPLAYER_PID"
    
    # Wait for bgmplayer to finish
    wait $BGMPLAYER_PID 2>/dev/null
    PLAY_RESULT=$?
    
    log_message "DEBUG: announcement playback exit code: $PLAY_RESULT"
    
    if [ $PLAY_RESULT -eq 0 ]; then
        log_message "Announcement completed successfully"
    else
        log_message "ERROR: Announcement playback failed with code: $PLAY_RESULT"
    fi
    
    # Restore system volume to original level
    log_message "Restoring system volume to ${ORIGINAL_VOLUME}%"
    curl -s -X PUT "http://localhost/api/system/volume" \
        -H "Content-Type: application/json" \
        -d "{\"volume\":${ORIGINAL_VOLUME}}" > /dev/null 2>&1
    
    # Restore background music to normal volume if it was playing
    if [ "$BG_MUSIC_PLAYING" = true ] && [ -f "/tmp/bg_music_bgmplayer.pid" ]; then
        CURRENT_BG_PID=$(cat /tmp/bg_music_bgmplayer.pid)
        if ps -p "$CURRENT_BG_PID" > /dev/null 2>&1; then
            log_message "Restoring background music from ${DUCK_VOLUME}% to 100% volume"
            
            # Calculate how many increases needed to restore to 100%
            INCREASES=$(( (100 - DUCK_VOLUME) / 10 ))
            
            for ((i=0; i<INCREASES; i++)); do
                kill -SIGUSR2 "$CURRENT_BG_PID" 2>/dev/null
                sleep 0.1
            done
            log_message "Background music volume restored to 100%"
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
