#!/bin/bash
###########################################################
# Stop Background Music - Stop background music via GPIO
###########################################################

# Call the plugin API to stop background music
curl -X POST -H "Content-Type: application/json" \
  http://localhost/api/plugin/fpp-plugin-BackgroundMusic/stop-background

exit 0
