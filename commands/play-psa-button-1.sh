#!/bin/bash
# Play PSA Button 1
# Triggers the first configured PSA button

PLUGIN_DIR="/home/fpp/media/plugins/fpp-plugin-BackgroundMusic"
PLUGIN_CONFIG="/home/fpp/media/config/plugin.fpp-plugin-BackgroundMusic"

# Check if plugin is configured
if [ ! -f "$PLUGIN_CONFIG" ]; then
    echo "ERROR: Plugin not configured"
    exit 1
fi

# Load configuration
source "$PLUGIN_CONFIG"

# Check if button is configured
if [ -z "$PSAButton1File" ] || [ ! -f "$PSAButton1File" ]; then
    echo "ERROR: PSA Button 1 not configured or file not found"
    exit 1
fi

# Get settings
ANNOUNCEMENT_FILE="$PSAButton1File"
ANNOUNCEMENT_LABEL="${PSAButton1Label:-PSA Button 1}"
DUCK_VOLUME="${PSADuckVolume:-30}"
ANNOUNCEMENT_VOLUME="${PSAAnnouncementVolume:-90}"

# Call the play_announcement script
"${PLUGIN_DIR}/scripts/play_announcement.sh" \
    "$ANNOUNCEMENT_FILE" \
    "$DUCK_VOLUME" \
    "$ANNOUNCEMENT_VOLUME" \
    "1" \
    "$ANNOUNCEMENT_LABEL"

exit $?
