#!/bin/bash
# FPP playlistStart hook - runs when FPP playlist playback starts
# FPP 10 version: stop background music GStreamer pipelines
# PipeWire stays running (shared with fppd)

SCRIPT_DIR="$(dirname "$0")"
. "$SCRIPT_DIR/pw_env.sh"

log_message "[playlistStart] FPP playlist starting - checking background music"

if [ -f "$PID_FILE" ] || pgrep -f "bg_music_loop.sh" >/dev/null 2>&1; then
    log_message "[playlistStart] Background music running - stopping"
    "$SCRIPT_DIR/background_music_player.sh" stop >> "$LOG_FILE" 2>&1
    log_message "[playlistStart] Background music stopped"
else
    log_message "[playlistStart] Background music not running"
fi

exit 0
