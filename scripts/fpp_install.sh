#!/bin/bash

# fpp-plugin-backgroundmusic install script

BASEDIR=$(dirname $0)
cd $BASEDIR
cd ..

make "SRCDIR=${SRCDIR}"


. ${FPPDIR}/scripts/common

# install jq utility for PSU Control script to work
sudo apt-get -y install jq

#install mpg123 for playing mp3 audion tracks
sudo apt-get install mpg123

# Execute script to fix mac address to be static

setSetting restartFlag 1

