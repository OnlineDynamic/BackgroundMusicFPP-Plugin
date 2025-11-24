#!/bin/bash
# Wrapper script to start background music from API
# This runs as root and detaches properly from Apache

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/background_music_start.log"

# Run the start command in background, fully detached
nohup bash "$SCRIPT_DIR/background_music_player.sh" start > "$LOG_FILE" 2>&1 </dev/null &

exit 0
