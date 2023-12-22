#!/bin/sh
###########################################################
# GPIO-On.sh - Turn on one of the Pi's GPIO Outputs       #
###########################################################

if [ $# -lt 1 ];
then
echo "# GPIO on Script"
echo "# Usage:"
echo "# GPIO-On.sh GPIO#"
echo "# example:"
echo "# GPIO-On.sh 76"
exit 0
fi

# Set the GPIO number (NOT the pin number)
#GPIO="64" (pi zero)
#GPIO="76" (Pi4)
GPIO=$1

# Make sure the pin is setup for output.
/opt/fpp/src/fpp -G ${GPIO},Output

# Turn on the pin
/opt/fpp/src/fpp -g ${GPIO},Output,1
