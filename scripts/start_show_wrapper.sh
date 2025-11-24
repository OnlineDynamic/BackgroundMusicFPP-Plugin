#!/bin/bash
# Wrapper script to start show transition from API
# This allows proper detachment from Apache process

FADE_TIME=$1
BLACKOUT_TIME=$2
SHOW_PLAYLIST=$3

SCRIPT_DIR="$(dirname "$0")"
LOG_FILE="/home/fpp/media/logs/fpp-plugin-BackgroundMusic-api.log"

nohup /bin/bash "$SCRIPT_DIR/start_show_transition.sh" "$FADE_TIME" "$BLACKOUT_TIME" "$SHOW_PLAYLIST" >> "$LOG_FILE" 2>&1 &

exit 0
