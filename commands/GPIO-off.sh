#!/bin/sh
###########################################################
# GPIO-Off.sh - Turn on one of the Pi's GPIO Outputs       #
###########################################################

if [ $# -lt 1 ];
then
echo "# GPIO off Script"
echo "# Usage:"
echo "# GPIO-Off.sh GPIO#"
echo "# example:"
echo "# GPIO-Off.sh 76"
exit 0
fi

# Set the GPIO number (NOT the pin number)
#GPIO="64" (pi zero)
#GPIO="76" (Pi4)
GPIO=$1

# Make sure the pin is setup for output.
/opt/fpp/src/fpp -G ${GPIO},Output

# Turn off the pin
/opt/fpp/src/fpp -g ${GPIO},Output,0
echo "PSU On Script"
