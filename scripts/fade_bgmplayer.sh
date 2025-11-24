#!/bin/bash
###############################################################################
# fade_bgmplayer.sh - Fade bgmplayer's internal volume (not system volume)
###############################################################################

SCRIPT_DIR="$(dirname "$0")"
. /opt/fpp/scripts/common

LOG_FILE="/home/fpp/media/logs/backgroundmusic_transition.log"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Get bgmplayer PID (the actual player, not the wrapper script)
BGMPLAYER_PID_FILE="/tmp/bg_music_bgmplayer.pid"

if [ ! -f "$BGMPLAYER_PID_FILE" ]; then
    log_message "No bgmplayer PID file found at $BGMPLAYER_PID_FILE"
    exit 1
fi

PLAYER_PID=$(cat "$BGMPLAYER_PID_FILE" 2>/dev/null)
if [ -z "$PLAYER_PID" ] || ! kill -0 "$PLAYER_PID" 2>/dev/null; then
    log_message "bgmplayer process not running (PID: $PLAYER_PID)"
    exit 1
fi

# Get fade time from plugin settings (default 10 seconds)
FADE_TIME=$(getSetting BackgroundMusicFadeTime)
if [ -z "$FADE_TIME" ] || [ "$FADE_TIME" -eq 0 ]; then
    FADE_TIME=10
fi

log_message "Starting bgmplayer volume fade (${FADE_TIME}s) - PID: $PLAYER_PID"

# Calculate how many times to decrease volume
# Each SIGUSR1 decreases by 10%, so we need 10 signals to go from 100% to 0%
DECREASES=10
INTERVAL=$(echo "scale=2; $FADE_TIME / $DECREASES" | bc)

log_message "Sending $DECREASES volume decrease signals over ${FADE_TIME}s (interval: ${INTERVAL}s)"

for ((i=0; i<DECREASES; i++)); do
    # Check if player still exists
    if ! kill -0 "$PLAYER_PID" 2>/dev/null; then
        log_message "bgmplayer stopped during fade"
        exit 0
    fi
    
    # Send SIGUSR1 to decrease volume by 10%
    kill -SIGUSR1 "$PLAYER_PID" 2>/dev/null
    log_message "Sent volume decrease signal ($((i+1))/$DECREASES) - now at $((100 - (i+1)*10))%"
    
    sleep "$INTERVAL"
done

log_message "bgmplayer volume fade complete (should be at 0%)"
