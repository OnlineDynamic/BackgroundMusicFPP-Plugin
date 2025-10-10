#!/bin/bash
###########################################################
# Start Main Show - Trigger show transition via GPIO
###########################################################

# Call the plugin API to start the main show
# This will:
# 1. Stop background music
# 2. Fade out brightness
# 3. Wait for blackout period
# 4. Start main show playlist
# 5. Restore brightness

curl -X POST -H "Content-Type: application/json" \
  http://localhost/api/plugin/fpp-plugin-BackgroundMusic/start-show

exit 0
