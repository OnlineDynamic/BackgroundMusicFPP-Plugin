#!/bin/bash
# Play immediate TTS announcement over background music
# Usage: play_tts_announcement.sh "text to speak" [voice_model]

PLUGIN_DIR="/home/fpp/media/plugins/fpp-plugin-BackgroundMusic"
PIPER_DIR="${PLUGIN_DIR}/piper"
PIPER_BIN="${PIPER_DIR}/piper"

# Check if Piper is installed
if [ ! -f "${PIPER_BIN}" ]; then
    echo "Error: Piper TTS not installed. Run install_piper.sh first."
    exit 1
fi

# Get parameters
TEXT="$1"
VOICE_MODEL="${2:-${PIPER_DIR}/default_voice.onnx}"

# Validate inputs
if [ -z "$TEXT" ]; then
    echo "Error: No text provided"
    exit 1
fi

# Create temporary files
TEMP_WAV="/tmp/piper_realtime_$(date +%s).wav"
TEMP_MP3="/tmp/piper_realtime_$(date +%s).mp3"

echo "Generating real-time TTS announcement..."

# Generate WAV using Piper
echo "$TEXT" | "${PIPER_BIN}" --model "$VOICE_MODEL" --output_file "$TEMP_WAV"

if [ $? -ne 0 ] || [ ! -f "$TEMP_WAV" ]; then
    echo "Error: Piper TTS generation failed"
    rm -f "$TEMP_WAV"
    exit 1
fi

# Convert to MP3 for better compatibility
ffmpeg -i "$TEMP_WAV" -codec:a libmp3lame -qscale:a 2 "$TEMP_MP3" -y 2>&1 > /dev/null

if [ $? -ne 0 ] || [ ! -f "$TEMP_MP3" ]; then
    echo "Error: MP3 conversion failed, trying WAV directly"
    TEMP_MP3="$TEMP_WAV"
fi

# Now use the existing play_announcement.sh script to play it
# This will handle volume ducking and proper audio device selection
"${PLUGIN_DIR}/scripts/play_announcement.sh" "$TEMP_MP3"

RESULT=$?

# Wait for the announcement subshell to finish playing before cleaning up.
# play_announcement.sh backgrounds a subshell that runs GStreamer — if we delete
# the temp file too early, GStreamer loses its source and exits with error 255.
ANNOUNCEMENT_PID_FILE="/tmp/announcement_player.pid"
if [ -f "$ANNOUNCEMENT_PID_FILE" ]; then
    ANN_PID=$(cat "$ANNOUNCEMENT_PID_FILE")
    if [ -n "$ANN_PID" ] && kill -0 "$ANN_PID" 2>/dev/null; then
        echo "Waiting for announcement playback to finish (PID: $ANN_PID)..."
        while kill -0 "$ANN_PID" 2>/dev/null; do
            sleep 0.5
        done
    fi
fi

# Cleanup
sleep 0.5
rm -f "$TEMP_WAV" "$TEMP_MP3"

if [ $RESULT -eq 0 ]; then
    echo "✓ Real-time TTS announcement played successfully"
    exit 0
else
    echo "✗ Error: Failed to play TTS announcement"
    exit 1
fi
