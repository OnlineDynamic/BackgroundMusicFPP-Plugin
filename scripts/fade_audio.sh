#!/bin/bash
##########################################################################
# fade_audio.sh - Gradually fade audio volume down to 0
# 
# This script fades the audio volume of the running ffplay process by
# manipulating the process volume using pactl or amixer
##########################################################################

FADE_TIME=${1:-5}  # Fade time in seconds (default 5)
LOG_FILE="/home/fpp/media/logs/fpp-plugin-BackgroundMusic.log"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Get the PID of the running ffplay process
if [ ! -f "/tmp/background_music_player.pid" ]; then
    log_message "No background music player running"
    exit 0
fi

PLAYER_PID=$(cat /tmp/background_music_player.pid)

# Check if the process is actually running
if ! ps -p "$PLAYER_PID" > /dev/null 2>&1; then
    log_message "Background music player PID $PLAYER_PID not found"
    exit 0
fi

# Find the ffplay process (child of the player script)
FFPLAY_PID=$(pgrep -P "$PLAYER_PID" ffplay)

if [ -z "$FFPLAY_PID" ]; then
    log_message "No ffplay process found for player PID $PLAYER_PID"
    exit 0
fi

log_message "Fading audio for ffplay PID $FFPLAY_PID over $FADE_TIME seconds"

# Check if we have PulseAudio (pactl) or just ALSA (amixer)
if command -v pactl > /dev/null 2>&1; then
    # Use PulseAudio for per-application volume control
    log_message "Using PulseAudio (pactl) for fade"
    
    # Find the sink input for this ffplay process
    SINK_INPUT=$(pactl list sink-inputs | grep -B 20 "application.process.id = \"$FFPLAY_PID\"" | grep "Sink Input" | head -1 | awk '{print $3}' | tr -d '#')
    
    if [ -z "$SINK_INPUT" ]; then
        log_message "Could not find PulseAudio sink input for ffplay PID $FFPLAY_PID"
        exit 1
    fi
    
    # Get current volume
    CURRENT_VOLUME=$(pactl list sink-inputs | grep -A 15 "Sink Input #$SINK_INPUT" | grep "Volume:" | head -1 | awk '{print $5}' | tr -d '%')
    
    if [ -z "$CURRENT_VOLUME" ]; then
        CURRENT_VOLUME=100
    fi
    
    log_message "Current volume: ${CURRENT_VOLUME}%, fading to 0%"
    
    # Calculate fade steps (10 steps per second)
    FADE_STEPS=$((FADE_TIME * 10))
    VOLUME_STEP=$(echo "scale=2; $CURRENT_VOLUME / $FADE_STEPS" | bc)
    SLEEP_TIME=$(echo "scale=3; $FADE_TIME / $FADE_STEPS" | bc)
    
    # Fade volume down
    for ((i=1; i<=FADE_STEPS; i++)); do
        CURRENT_VOLUME=$(echo "$CURRENT_VOLUME - $VOLUME_STEP" | bc)
        CURRENT_VOLUME_INT=$(echo "$CURRENT_VOLUME / 1" | bc)
        
        if [ "$CURRENT_VOLUME_INT" -lt 0 ]; then
            CURRENT_VOLUME_INT=0
        fi
        
        pactl set-sink-input-volume "$SINK_INPUT" "${CURRENT_VOLUME_INT}%" 2>/dev/null
        
        # Check if process still exists
        if ! ps -p "$FFPLAY_PID" > /dev/null 2>&1; then
            log_message "ffplay process ended during fade"
            exit 0
        fi
        
        sleep "$SLEEP_TIME"
    done
    
    # Ensure volume is at 0
    pactl set-sink-input-volume "$SINK_INPUT" 0% 2>/dev/null
    log_message "Audio fade complete (PulseAudio)"
    
elif command -v amixer > /dev/null 2>&1; then
    # Use ALSA mixer for system-wide volume control
    log_message "Using ALSA (amixer) for fade"
    
    # Get the audio device from FPP settings
    AUDIO_DEVICE=$(grep "^AlsaAudioDevice = " /home/fpp/media/settings | sed 's/AlsaAudioDevice = "\(.*\)"/\1/')
    AUDIO_DEVICE=${AUDIO_DEVICE:-default}
    
    # Get current volume
    CURRENT_VOLUME=$(amixer -D "$AUDIO_DEVICE" sget Master 2>/dev/null | grep -o '[0-9]*%' | head -1 | tr -d '%')
    
    if [ -z "$CURRENT_VOLUME" ]; then
        # Try PCM if Master doesn't exist
        CURRENT_VOLUME=$(amixer -D "$AUDIO_DEVICE" sget PCM 2>/dev/null | grep -o '[0-9]*%' | head -1 | tr -d '%')
    fi
    
    if [ -z "$CURRENT_VOLUME" ]; then
        # Try Speaker if PCM doesn't exist
        CURRENT_VOLUME=$(amixer -D "$AUDIO_DEVICE" sget Speaker 2>/dev/null | grep -o '[0-9]*%' | head -1 | tr -d '%')
    fi
    
    if [ -z "$CURRENT_VOLUME" ]; then
        CURRENT_VOLUME=100
    fi
    
    log_message "Current volume: ${CURRENT_VOLUME}%, fading to 0%"
    
    # Calculate fade steps (10 steps per second)
    FADE_STEPS=$((FADE_TIME * 10))
    VOLUME_STEP=$(echo "scale=2; $CURRENT_VOLUME / $FADE_STEPS" | bc)
    SLEEP_TIME=$(echo "scale=3; $FADE_TIME / $FADE_STEPS" | bc)
    
    # Fade volume down
    for ((i=1; i<=FADE_STEPS; i++)); do
        CURRENT_VOLUME=$(echo "$CURRENT_VOLUME - $VOLUME_STEP" | bc)
        CURRENT_VOLUME_INT=$(echo "$CURRENT_VOLUME / 1" | bc)
        
        if [ "$CURRENT_VOLUME_INT" -lt 0 ]; then
            CURRENT_VOLUME_INT=0
        fi
        
        # Try Master first, then PCM, then Speaker
        amixer -D "$AUDIO_DEVICE" sset Master "${CURRENT_VOLUME_INT}%" 2>/dev/null >/dev/null || \
        amixer -D "$AUDIO_DEVICE" sset PCM "${CURRENT_VOLUME_INT}%" 2>/dev/null >/dev/null || \
        amixer -D "$AUDIO_DEVICE" sset Speaker "${CURRENT_VOLUME_INT}%" 2>/dev/null >/dev/null
        
        # Check if process still exists
        if ! ps -p "$FFPLAY_PID" > /dev/null 2>&1; then
            log_message "ffplay process ended during fade"
            exit 0
        fi
        
        sleep "$SLEEP_TIME"
    done
    
    # Ensure volume is at 0
    amixer -D "$AUDIO_DEVICE" sset Master 0% 2>/dev/null >/dev/null || \
    amixer -D "$AUDIO_DEVICE" sset PCM 0% 2>/dev/null >/dev/null || \
    amixer -D "$AUDIO_DEVICE" sset Speaker 0% 2>/dev/null >/dev/null
    
    log_message "Audio fade complete (ALSA)"
else
    log_message "ERROR: Neither pactl nor amixer found - cannot fade audio"
    exit 1
fi

exit 0
