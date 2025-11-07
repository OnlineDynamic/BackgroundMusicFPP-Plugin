#!/bin/bash
# Install additional Piper TTS voice
# Usage: install_voice.sh <voice_id>
# Example: install_voice.sh en_US-amy-medium

PLUGIN_DIR="/home/fpp/media/plugins/fpp-plugin-BackgroundMusic"
PIPER_DIR="${PLUGIN_DIR}/piper"
VOICES_DIR="${PIPER_DIR}/voices"

# Check if Piper is installed
if [ ! -d "${PIPER_DIR}" ]; then
    echo "Error: Piper TTS not installed. Run install_piper.sh first."
    exit 1
fi

# Get voice ID parameter
VOICE_ID="$1"

if [ -z "$VOICE_ID" ]; then
    echo "Error: No voice ID provided"
    echo "Usage: install_voice.sh <voice_id>"
    echo "Example: install_voice.sh en_US-amy-medium"
    exit 1
fi

# Create voices directory if it doesn't exist
mkdir -p "${VOICES_DIR}"

# Parse voice ID to get language and name
# Format: language_region-name-quality
# Example: en_US-amy-medium
LANG_REGION=$(echo "$VOICE_ID" | cut -d'-' -f1)
VOICE_NAME=$(echo "$VOICE_ID" | cut -d'-' -f2)
QUALITY=$(echo "$VOICE_ID" | cut -d'-' -f3-)

# Convert underscores to forward slashes for URL path
LANG=$(echo "$LANG_REGION" | cut -d'_' -f1)
REGION=$(echo "$LANG_REGION" | cut -d'_' -f2)

# Construct download URLs
BASE_URL="https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0"
VOICE_URL="${BASE_URL}/${LANG}/${LANG_REGION}/${VOICE_NAME}/${QUALITY}/${VOICE_ID}.onnx"
CONFIG_URL="${BASE_URL}/${LANG}/${LANG_REGION}/${VOICE_NAME}/${QUALITY}/${VOICE_ID}.onnx.json"

echo "Installing voice: ${VOICE_ID}"
echo "Downloading from: ${VOICE_URL}"

# Download voice model
wget -q --show-progress "${VOICE_URL}" -O "${VOICES_DIR}/${VOICE_ID}.onnx"

if [ $? -ne 0 ]; then
    echo "✗ Error: Failed to download voice model"
    rm -f "${VOICES_DIR}/${VOICE_ID}.onnx"
    exit 1
fi

# Download config file
wget -q --show-progress "${CONFIG_URL}" -O "${VOICES_DIR}/${VOICE_ID}.onnx.json"

if [ $? -ne 0 ]; then
    echo "✗ Error: Failed to download voice config"
    rm -f "${VOICES_DIR}/${VOICE_ID}.onnx" "${VOICES_DIR}/${VOICE_ID}.onnx.json"
    exit 1
fi

echo "✓ Voice installed successfully: ${VOICE_ID}"
echo "Location: ${VOICES_DIR}/${VOICE_ID}.onnx"

# Set proper ownership for FPP user
chown fpp:fpp "${VOICES_DIR}/${VOICE_ID}.onnx" 2>/dev/null || true
chown fpp:fpp "${VOICES_DIR}/${VOICE_ID}.onnx.json" 2>/dev/null || true

# Get file size
FILE_SIZE=$(stat -f%z "${VOICES_DIR}/${VOICE_ID}.onnx" 2>/dev/null || stat -c%s "${VOICES_DIR}/${VOICE_ID}.onnx" 2>/dev/null)
echo "File size: ${FILE_SIZE} bytes"

exit 0
