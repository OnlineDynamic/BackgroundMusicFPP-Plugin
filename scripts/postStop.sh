#!/bin/bash
##########################################################################
# postStop.sh - FPP Plugin Hook (runs when FPPD stops)
# 
# This script ensures background music processes are properly cleaned up
# when FPPD stops, preventing orphaned processes from holding the audio
# device and causing FPPD to hang on restart.
#
# Addresses Issue #11: FPPD stops and won't restart after background music
##########################################################################

SCRIPT_DIR="$(dirname "$0")"
LOG_FILE="/home/fpp/media/logs/fpp-plugin-BackgroundMusic.log"
PID_FILE="/tmp/background_music_player.pid"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [postStop] $1" >> "$LOG_FILE"
}

log_message "FPPD stopped - cleaning up background music processes to prevent audio device conflicts"

# Stop background music player gracefully first
if [ -f "$SCRIPT_DIR/background_music_player.sh" ]; then
    log_message "Stopping background music player gracefully"
    "$SCRIPT_DIR/background_music_player.sh" stop >> "$LOG_FILE" 2>&1
    sleep 0.5
fi

# Ensure all bgmplayer processes are terminated
if pgrep -x bgmplayer > /dev/null 2>&1; then
    log_message "Found remaining bgmplayer processes - force stopping"
    killall -TERM bgmplayer 2>/dev/null
    sleep 0.5
    killall -9 bgmplayer 2>/dev/null
fi

# Kill any background music player scripts that might be orphaned
if pgrep -f "background_music_player.sh" > /dev/null 2>&1; then
    log_message "Found orphaned background_music_player.sh processes - cleaning up"
    pkill -f "background_music_player.sh" 2>/dev/null
    sleep 0.3
    pkill -9 -f "background_music_player.sh" 2>/dev/null
fi

# Kill any loop scripts
if pgrep -f "bg_music_loop.sh" > /dev/null 2>&1; then
    log_message "Found loop script processes - cleaning up"
    pkill -f "bg_music_loop.sh" 2>/dev/null
    pkill -9 -f "bg_music_loop.sh" 2>/dev/null
fi

# Kill any monitor scripts that may be running
if pgrep -f "monitor_show_completion.sh" > /dev/null 2>&1; then
    log_message "Found monitor scripts - cleaning up"
    pkill -f "monitor_show_completion.sh" 2>/dev/null
fi

# Kill any return_to_preshow scripts that may be running
if pgrep -f "return_to_preshow.sh" > /dev/null 2>&1; then
    log_message "Found return_to_preshow scripts - cleaning up"
    pkill -f "return_to_preshow.sh" 2>/dev/null
fi

# Stop PipeWire to release audio device completely
if pgrep -u fpp pipewire > /dev/null 2>&1; then
    log_message "Stopping PipeWire to release audio device"
    pkill -u fpp pipewire 2>/dev/null
    pkill -u fpp wireplumber 2>/dev/null
    sleep 0.3
    pkill -9 -u fpp pipewire 2>/dev/null
    pkill -9 -u fpp wireplumber 2>/dev/null
fi

# Clean up all PID and state files
log_message "Cleaning up PID and state files"
rm -f "$PID_FILE" 2>/dev/null
rm -f /tmp/background_music_start.pid 2>/dev/null
rm -f /tmp/bg_music_bgmplayer.pid 2>/dev/null
rm -f /tmp/bg_music_loop.sh 2>/dev/null
rm -f /tmp/bg_music_status.txt 2>/dev/null
rm -f /tmp/bg_music_state.txt 2>/dev/null
rm -f /tmp/bg_music_jump.txt 2>/dev/null
rm -f /tmp/bg_music_next.txt 2>/dev/null
rm -f /tmp/bg_music_previous.txt 2>/dev/null
rm -f /tmp/bg_music_reorder.txt 2>/dev/null
rm -f /tmp/bg_music_metadata.pid 2>/dev/null
rm -f /tmp/bgmplayer_volume.txt 2>/dev/null
rm -f /tmp/background_music_playlist.m3u 2>/dev/null
rm -f /tmp/show_monitor.pid 2>/dev/null

# Clean up any PipeWire sockets if no PipeWire processes remain
FPP_UID=$(id -u fpp 2>/dev/null)
if [ -n "$FPP_UID" ]; then
    XDG_RUNTIME_DIR="/run/user/${FPP_UID}"
    if [ -d "$XDG_RUNTIME_DIR" ]; then
        if ! pgrep -u fpp pipewire > /dev/null 2>&1; then
            log_message "Cleaning up stale PipeWire sockets"
            rm -f "$XDG_RUNTIME_DIR"/pipewire-* 2>/dev/null
        fi
    fi
fi

log_message "Background music cleanup complete - audio device released for FPPD restart"

exit 0
