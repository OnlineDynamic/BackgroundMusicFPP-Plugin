#!/bin/bash
###########################################################
# Start Background Music - Trigger background music via GPIO
###########################################################

# Call the plugin API to start background music
curl -X POST -H "Content-Type: application/json" \
  http://localhost/api/plugin/fpp-plugin-BackgroundMusic/start-background

exit 0
