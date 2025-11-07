#!/bin/bash
# Generate TTS audio using Piper
# Usage: generate_tts.sh "text to speak" "output_filename.mp3" [voice_model]

PLUGIN_DIR="/home/fpp/media/plugins/fpp-plugin-BackgroundMusic"
PIPER_DIR="${PLUGIN_DIR}/piper"
PIPER_BIN="${PIPER_DIR}/piper"
MUSIC_DIR="/home/fpp/media/music"

# Check if Piper is installed
if [ ! -f "${PIPER_BIN}" ]; then
    echo "Error: Piper TTS not installed. Run install_piper.sh first."
    exit 1
fi

# Get parameters
TEXT="$1"
OUTPUT_FILE="$2"
VOICE_PARAM="$3"

# Validate inputs
if [ -z "$TEXT" ]; then
    echo "Error: No text provided"
    exit 1
fi

if [ -z "$OUTPUT_FILE" ]; then
    echo "Error: No output filename provided"
    exit 1
fi

# Determine voice model to use
if [ -n "$VOICE_PARAM" ]; then
    # Check if it's a full path
    if [ -f "$VOICE_PARAM" ]; then
        VOICE_MODEL="$VOICE_PARAM"
    # Check if it's a voice ID
    elif [ -f "${PIPER_DIR}/voices/${VOICE_PARAM}.onnx" ]; then
        VOICE_MODEL="${PIPER_DIR}/voices/${VOICE_PARAM}.onnx"
    else
        echo "Error: Voice not found: $VOICE_PARAM"
        exit 1
    fi
else
    # Use default voice
    VOICE_MODEL="${PIPER_DIR}/default_voice.onnx"
fi

# Check if voice model exists
if [ ! -f "$VOICE_MODEL" ]; then
    echo "Error: Voice model not found: $VOICE_MODEL"
    exit 1
fi

# If output file doesn't have full path, assume it goes in music directory
if [[ "$OUTPUT_FILE" != /* ]]; then
    OUTPUT_FILE="${MUSIC_DIR}/${OUTPUT_FILE}"
fi

# Ensure output filename ends with .mp3
if [[ "$OUTPUT_FILE" != *.mp3 ]]; then
    OUTPUT_FILE="${OUTPUT_FILE}.mp3"
fi

# Create temporary WAV file
TEMP_WAV="/tmp/piper_tts_$(date +%s).wav"

echo "Generating TTS audio..."
echo "Text: $TEXT"
echo "Voice: $VOICE_MODEL"
echo "Output: $OUTPUT_FILE"

# Generate WAV using Piper
echo "$TEXT" | "${PIPER_BIN}" --model "$VOICE_MODEL" --output_file "$TEMP_WAV"

if [ $? -ne 0 ] || [ ! -f "$TEMP_WAV" ]; then
    echo "Error: Piper TTS generation failed"
    rm -f "$TEMP_WAV"
    exit 1
fi

echo "Converting to MP3..."

# Convert WAV to MP3 using ffmpeg
ffmpeg -i "$TEMP_WAV" -codec:a libmp3lame -qscale:a 2 "$OUTPUT_FILE" -y 2>&1 | grep -v "^frame="

if [ $? -eq 0 ] && [ -f "$OUTPUT_FILE" ]; then
    echo "✓ TTS audio generated successfully: $OUTPUT_FILE"
    
    # Set proper permissions
    chmod 644 "$OUTPUT_FILE"
    
    # Get file size
    FILE_SIZE=$(stat -f%z "$OUTPUT_FILE" 2>/dev/null || stat -c%s "$OUTPUT_FILE" 2>/dev/null)
    echo "File size: ${FILE_SIZE} bytes"
    
    # Cleanup
    rm -f "$TEMP_WAV"
    
    exit 0
else
    echo "✗ Error: Failed to convert to MP3"
    rm -f "$TEMP_WAV"
    exit 1
fi
