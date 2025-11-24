#!/bin/bash
# Generate TTS audio using ElevenLabs API
# Usage: generate_tts_elevenlabs.sh "text to speak" "output_filename.mp3" [voice_id] [api_key]

PLUGIN_CONFIG="/home/fpp/media/config/plugin.fpp-plugin-BackgroundMusic"
MUSIC_DIR="/home/fpp/media/music"

# Get parameters
TEXT="$1"
OUTPUT_FILE="$2"
VOICE_ID="$3"
API_KEY="$4"

# Validate inputs
if [ -z "$TEXT" ]; then
    echo "Error: No text provided"
    exit 1
fi

if [ -z "$OUTPUT_FILE" ]; then
    echo "Error: No output filename provided"
    exit 1
fi

# Get API key from config if not provided
if [ -z "$API_KEY" ] && [ -f "$PLUGIN_CONFIG" ]; then
    API_KEY=$(grep "^ElevenLabsAPIKey=" "$PLUGIN_CONFIG" | cut -d'=' -f2- | tr -d '\r' | tr -d '"')
fi

if [ -z "$API_KEY" ]; then
    echo "Error: ElevenLabs API key not configured"
    exit 1
fi

# Get voice ID from config if not provided
if [ -z "$VOICE_ID" ] && [ -f "$PLUGIN_CONFIG" ]; then
    VOICE_ID=$(grep "^ElevenLabsVoiceID=" "$PLUGIN_CONFIG" | cut -d'=' -f2- | tr -d '\r' | tr -d '"')
fi

# Default to Rachel voice if not specified
if [ -z "$VOICE_ID" ]; then
    VOICE_ID="21m00Tcm4TlvDq8ikWAM"
fi

# If output file doesn't have full path, assume it goes in music directory
if [[ "$OUTPUT_FILE" != /* ]]; then
    OUTPUT_FILE="${MUSIC_DIR}/${OUTPUT_FILE}"
fi

# Ensure output filename ends with .mp3
if [[ "$OUTPUT_FILE" != *.mp3 ]]; then
    OUTPUT_FILE="${OUTPUT_FILE}.mp3"
fi

echo "Generating TTS audio using ElevenLabs..."
echo "Text: $TEXT"
echo "Voice ID: $VOICE_ID"
echo "Output: $OUTPUT_FILE"

# Call ElevenLabs API
# Using the text-to-speech endpoint with default settings
# Note: Using eleven_turbo_v2_5 which is available on free tier
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    "https://api.elevenlabs.io/v1/text-to-speech/${VOICE_ID}" \
    -H "xi-api-key: ${API_KEY}" \
    -H "Content-Type: application/json" \
    -d "{
        \"text\": $(echo "$TEXT" | jq -Rs .),
        \"model_id\": \"eleven_turbo_v2_5\",
        \"voice_settings\": {
            \"stability\": 0.5,
            \"similarity_boost\": 0.75
        }
    }" \
    --output "$OUTPUT_FILE")

# Extract HTTP status code (last line)
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

if [ "$HTTP_CODE" = "200" ] && [ -f "$OUTPUT_FILE" ] && [ -s "$OUTPUT_FILE" ]; then
    echo "✓ TTS audio generated successfully: $OUTPUT_FILE"
    
    # Set proper permissions
    chmod 644 "$OUTPUT_FILE"
    
    # Get file size
    FILE_SIZE=$(stat -f%z "$OUTPUT_FILE" 2>/dev/null || stat -c%s "$OUTPUT_FILE" 2>/dev/null)
    echo "File size: ${FILE_SIZE} bytes"
    
    exit 0
else
    echo "Error: ElevenLabs API request failed (HTTP $HTTP_CODE)"
    if [ -f "$OUTPUT_FILE" ]; then
        # Check if output contains error message
        if grep -q "error" "$OUTPUT_FILE" 2>/dev/null; then
            echo "API Error: $(cat "$OUTPUT_FILE")"
        fi
        rm -f "$OUTPUT_FILE"
    fi
    exit 1
fi
