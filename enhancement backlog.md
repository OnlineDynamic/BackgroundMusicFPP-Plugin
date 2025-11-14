# A Backlog of Enhancement Ideas for the plugin

* ~~Add configurable ability to autostart background music player on fpp start/restart, and let it continue from where it left off~~ - COMPLETED: Added AutostartEnabled setting and postStart.sh hook
* ~~Add a FPP command to allow triggering of Start fpp Playlist/sequence - but be able to pass sequence/playlist name as an arg - default to configured MainShow config is no arg passed... this will allow user to schedule different playlist or sequences via the main fpp scheduler but have them interact with e background music plugin correctly~~ - COMPLETED: Added "BackgroundMusic - Start Show" command with optional playlistName argument
* ~~If internet stream fails try to auto reconnect so user doesn't have to stop and start the background music process~~ - COMPLETED: Stream mode automatically reconnects after 3 seconds if connection drops, with continuous retry loop until manually stopped
* Integration with the VASTFMT plugin
* RDS Output of playing info (using RDS plugin?)
* Add a music Icon into the FPP header when background music plugin is active - need to add new hooks in core fpp for fully functionality
* make volume slider wider again
* add link to https://www.internet-radio.com/stations/christmas/ for streaming url's
* work out how to handle immediate start of fpp sequence with media whilst background music playing
* make css not inline - need change to core fpp to allow exposing css/js.images folders to apache
* need to figure out volume control for K16 type capes with PCM on pcm5102
* fix fpp core to allow reload of fppd to trigger plugin actions that you normal get on fpp start
