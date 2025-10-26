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
ORIGINAL_VOLUME=${ORIGINAL_VOLUME:-70}

log_message "Original volume: ${ORIGINAL_VOLUME}%, ducking to: ${DUCK_VOLUME}%, announcement volume: ${ANNOUNCEMENT_VOLUME}%"

# Check if background music is playing
BG_MUSIC_PLAYING=false
if [ -f "/tmp/background_music_player.pid" ]; then
    BG_PID=$(cat /tmp/background_music_player.pid)
    if ps -p "$BG_PID" > /dev/null 2>&1; then
        BG_MUSIC_PLAYING=true
        log_message "Background music detected, applying ducking"
        
        # Smoothly fade down the background music volume over 1 second
        FADE_STEPS=10
        VOLUME_DIFF=$((ORIGINAL_VOLUME - DUCK_VOLUME))
        STEP_SIZE=$((VOLUME_DIFF / FADE_STEPS))
        
        for i in $(seq 1 $FADE_STEPS); do
            NEW_VOLUME=$((ORIGINAL_VOLUME - (STEP_SIZE * i)))
            if [ $i -eq $FADE_STEPS ]; then
                NEW_VOLUME=$DUCK_VOLUME  # Ensure we hit exact target
            fi
            
            curl -s -X POST -H "Content-Type: application/json" \
                -d "{\"volume\": ${NEW_VOLUME}}" \
                "http://localhost/api/system/volume" > /dev/null 2>&1
            
            sleep 0.1
        done
        
        log_message "Volume ducked from ${ORIGINAL_VOLUME}% to ${DUCK_VOLUME}%"
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
    
    if [ -z "$audio_device" ]; then
        audio_device="sysdefault"
    fi
    
    echo "$audio_device"
}

AUDIO_DEVICE=$(get_audio_device)

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
EOF

# Play announcement in background
(
    # Set announcement volume (ALSA will mix with background music)
    # Calculate ffplay volume (0-100 scale)
    FFPLAY_VOLUME=$((ANNOUNCEMENT_VOLUME))
    
    log_message "Playing announcement on device: $AUDIO_DEVICE at volume: ${FFPLAY_VOLUME}%"
    
    # Play the announcement file using ffplay with ALSA plug device for software mixing
    # The plug: device allows concurrent audio streams through ALSA
    VOLUME_FILTER="volume=$(echo "scale=2; $FFPLAY_VOLUME / 100" | bc)"
    
    # Use plug:default to enable software mixing
    SDL_AUDIODRIVER=alsa AUDIODEV="plug:default" ffplay -nodisp -autoexit \
        -af "$VOLUME_FILTER" \
        "$ANNOUNCEMENT_FILE" >> "$LOG_FILE" 2>&1
    
    PLAY_RESULT=$?
    log_message "DEBUG: ffplay exit code: $PLAY_RESULT"
    
    if [ $PLAY_RESULT -eq 0 ]; then
        log_message "Announcement completed successfully"
    else
        log_message "ERROR: Announcement playback failed with code: $PLAY_RESULT"
    fi
    
    # Restore background music volume if it was playing
    if [ "$BG_MUSIC_PLAYING" = true ]; then
        log_message "Restoring background music volume to ${ORIGINAL_VOLUME}%"
        
        # Smoothly fade up the background music volume over 1 second
        FADE_STEPS=10
        VOLUME_DIFF=$((ORIGINAL_VOLUME - DUCK_VOLUME))
        STEP_SIZE=$((VOLUME_DIFF / FADE_STEPS))
        
        for i in $(seq 1 $FADE_STEPS); do
            NEW_VOLUME=$((DUCK_VOLUME + (STEP_SIZE * i)))
            if [ $i -eq $FADE_STEPS ]; then
                NEW_VOLUME=$ORIGINAL_VOLUME  # Ensure we hit exact target
            fi
            
            curl -s -X POST -H "Content-Type: application/json" \
                -d "{\"volume\": ${NEW_VOLUME}}" \
                "http://localhost/api/system/volume" > /dev/null 2>&1
            
            sleep 0.1
        done
        
        log_message "Volume restored to ${ORIGINAL_VOLUME}%"
    fi
    
    # Clean up PID and status files
    rm -f "$ANNOUNCEMENT_PID_FILE"
    rm -f "$ANNOUNCEMENT_STATUS_FILE"
    
) &

# Save the background process PID
ANNOUNCEMENT_PID=$!
echo "$ANNOUNCEMENT_PID" > "$ANNOUNCEMENT_PID_FILE"

log_message "Announcement started (PID: $ANNOUNCEMENT_PID)"

exit 0
