#!/bin/bash
# Install Piper TTS for Background Music Plugin
# This script downloads and installs Piper TTS engine

PLUGIN_DIR="/home/fpp/media/plugins/fpp-plugin-BackgroundMusic"
PIPER_DIR="${PLUGIN_DIR}/piper"
PIPER_BIN="${PIPER_DIR}/piper"

echo "Installing Piper TTS for Background Music Plugin..."

# Install required dependencies
echo "Installing required dependencies..."
apt-get update -qq
apt-get install -y -qq libstdc++6 libgomp1 libatomic1 > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo "Warning: Some dependencies may not have installed correctly"
fi

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
# Note: Using rhasspy/piper repo (2023.11.14-2) which provides pre-compiled binaries.
# The new OHF-Voice/piper1-gpl v1.3.0+ is Python-based and would require different installation.
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
    
    # Check if the binary can be executed (check for missing libraries)
    if ! ldd piper > /dev/null 2>&1; then
        echo "Warning: Unable to check binary dependencies with ldd"
    else
        echo "Checking binary dependencies..."
        MISSING_LIBS=$(ldd piper 2>&1 | grep "not found")
        if [ -n "$MISSING_LIBS" ]; then
            echo "Error: Missing required libraries:"
            echo "$MISSING_LIBS"
            echo ""
            echo "Attempting to install additional dependencies..."
            apt-get install -y -qq libc6 libgcc-s1 > /dev/null 2>&1
        fi
    fi
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

# First test if the binary can execute at all
if ! "${PIPER_BIN}" --version > /dev/null 2>&1; then
    echo "Error: Piper binary cannot execute"
    echo "Checking for missing dependencies..."
    ldd "${PIPER_BIN}" 2>&1 | grep -E "not found|cannot"
    echo ""
    echo "Troubleshooting suggestions:"
    echo "1. Ensure all system packages are up to date: sudo apt-get update && sudo apt-get upgrade"
    echo "2. Try manually installing: sudo apt-get install -y libstdc++6 libgomp1 libatomic1"
    echo "3. Check system architecture matches downloaded binary"
    exit 1
fi

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
    echo "The binary executed but failed to generate audio"
    echo "Check if voice model was downloaded correctly"
    exit 1
fi
