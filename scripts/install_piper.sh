#!/bin/bash
# Install Piper TTS for Background Music Plugin
# This script downloads and installs Piper TTS engine

PLUGIN_DIR="/home/fpp/media/plugins/fpp-plugin-BackgroundMusic"
PIPER_DIR="${PLUGIN_DIR}/piper"
PIPER_BIN="${PIPER_DIR}/piper"

echo "Installing Piper TTS for Background Music Plugin..."

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
    aarch64|arm64)
        PIPER_ARCH="aarch64"
        echo "Detected ARM64 architecture"
        ;;
    armv7l|armv6l)
        PIPER_ARCH="armv7l"
        echo "Detected ARM32 architecture"
        ;;
    x86_64)
        PIPER_ARCH="x86_64"
        echo "Detected x86_64 architecture"
        ;;
    *)
        echo "Error: Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# Create piper directory
mkdir -p "${PIPER_DIR}"
cd "${PIPER_DIR}" || exit 1

# Download Piper - get latest version
echo "Fetching latest Piper version..."
PIPER_VERSION=$(curl -s https://api.github.com/repos/rhasspy/piper/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')

if [ -z "$PIPER_VERSION" ]; then
    echo "Warning: Could not fetch latest version, using known version"
    PIPER_VERSION="2023.11.14-2"
fi

echo "Using Piper version: ${PIPER_VERSION}"
PIPER_URL="https://github.com/rhasspy/piper/releases/download/${PIPER_VERSION}/piper_linux_${PIPER_ARCH}.tar.gz"

echo "Downloading Piper from ${PIPER_URL}..."
wget -q --show-progress "${PIPER_URL}" -O piper.tar.gz

if [ $? -ne 0 ]; then
    echo "Error: Failed to download Piper"
    exit 1
fi

echo "Extracting Piper..."
tar -xzf piper.tar.gz --strip-components=1
rm piper.tar.gz

# Ensure piper binary is executable
if [ -f "piper" ]; then
    chmod +x piper
    echo "Piper binary found and made executable"
else
    echo "Error: piper binary not found after extraction"
    exit 1
fi

# Download a default voice model (en_US-lessac-medium - good quality, reasonable size)
echo "Downloading default voice model (en_US-lessac-medium)..."
mkdir -p voices

VOICE_URL="https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/lessac/medium/en_US-lessac-medium.onnx"
VOICE_CONFIG_URL="https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/lessac/medium/en_US-lessac-medium.onnx.json"

wget -q --show-progress "${VOICE_URL}" -O voices/en_US-lessac-medium.onnx
wget -q --show-progress "${VOICE_CONFIG_URL}" -O voices/en_US-lessac-medium.onnx.json

if [ $? -ne 0 ]; then
    echo "Warning: Failed to download voice model. TTS may not work until a voice is downloaded."
else
    echo "Voice model downloaded successfully"
fi

# Create symlink for easy access
ln -sf "${PIPER_DIR}/voices/en_US-lessac-medium.onnx" "${PIPER_DIR}/default_voice.onnx"
ln -sf "${PIPER_DIR}/voices/en_US-lessac-medium.onnx.json" "${PIPER_DIR}/default_voice.onnx.json"

# Set proper ownership for FPP user
chown -R fpp:fpp "${PIPER_DIR}"

# Test Piper installation
echo "Testing Piper installation..."
echo "Hello, this is a test." | "${PIPER_BIN}" --model "${PIPER_DIR}/default_voice.onnx" --output_file /tmp/piper_test.wav

if [ $? -eq 0 ] && [ -f /tmp/piper_test.wav ]; then
    echo "✓ Piper TTS installed successfully!"
    rm /tmp/piper_test.wav
    
    # Create status file
    echo "installed" > "${PIPER_DIR}/status.txt"
    echo "$(date)" >> "${PIPER_DIR}/status.txt"
    echo "version: ${PIPER_VERSION}" >> "${PIPER_DIR}/status.txt"
    echo "architecture: ${PIPER_ARCH}" >> "${PIPER_DIR}/status.txt"
    
    exit 0
else
    echo "✗ Piper installation test failed"
    exit 1
fi
