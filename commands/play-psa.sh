#!/bin/bash
##########################################################################
# FPP Command: Play PSA Button
#
# Usage: play-psa.sh <button_number>
#
# Arguments:
#   button_number - PSA button number (1-20)
#
# This command triggers a configured PSA button via the plugin API
##########################################################################

BUTTON_NUMBER="$1"

# Validate button number
if [ -z "$BUTTON_NUMBER" ]; then
    echo "ERROR: Button number required (1-20)"
    exit 1
fi

if ! [[ "$BUTTON_NUMBER" =~ ^[0-9]+$ ]]; then
    echo "ERROR: Button number must be numeric"
    exit 1
fi

if [ "$BUTTON_NUMBER" -lt 1 ] || [ "$BUTTON_NUMBER" -gt 20 ]; then
    echo "ERROR: Button number must be between 1 and 20"
    exit 1
fi

# Call the plugin API to play announcement
RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d "{\"buttonNumber\": $BUTTON_NUMBER}" \
    "http://localhost/api/plugin/fpp-plugin-BackgroundMusic/play-announcement")

# Check response
STATUS=$(echo "$RESPONSE" | jq -r '.status' 2>/dev/null)

if [ "$STATUS" = "OK" ]; then
    MESSAGE=$(echo "$RESPONSE" | jq -r '.message' 2>/dev/null)
    echo "SUCCESS: $MESSAGE"
    exit 0
else
    MESSAGE=$(echo "$RESPONSE" | jq -r '.message' 2>/dev/null)
    echo "ERROR: $MESSAGE"
    exit 1
fi
