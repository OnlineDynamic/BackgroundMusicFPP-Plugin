#!/bin/bash
# FPP playlistStart hook - runs when FPP playlist playback starts
# Stop background music to release ALSA device for FPP

SCRIPT_DIR="$(dirname "$0")"
LOG_FILE="/home/fpp/media/logs/fpp-plugin-BackgroundMusic.log"

# Log function
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [playlistStart] $1" >> "$LOG_FILE"
}

log_message "FPP playlist starting - checking if background music needs to be stopped"

# Check if background music is running
if pgrep -f "background_music_player.sh" >/dev/null 2>&1 || pgrep -u fpp bgmplayer >/dev/null 2>&1; then
    log_message "Background music is running - stopping to release audio device for FPP"
    
    # Stop background music
    "$SCRIPT_DIR/background_music_player.sh" stop >/dev/null 2>&1
    
    # Also stop PipeWire to fully release the device
    pkill -u fpp pipewire 2>/dev/null
    pkill -u fpp wireplumber 2>/dev/null
    
    sleep 1
    log_message "Background music and PipeWire stopped - ALSA device released for FPP"
else
    log_message "Background music not running - no action needed"
fi

exit 0
