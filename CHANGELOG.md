# Changelog

All notable changes to the Background Music Plugin will be documented in this file.

## [2.0.0] - 2025-10-11

### Added - PSA (Public Service Announcement) System
- **5 Configurable PSA Buttons**: Play announcements over background music
- **Automatic Volume Ducking**: Background music smoothly fades down during announcements
- **Volume Control**: Separate volume settings for announcements and ducked music
- **Concurrent Playback**: PSA announcements play simultaneously with background music
- **Button States**: Visual feedback with pulse animation during playback
- **API Endpoints**: RESTful API for programmatic PSA control
  - `POST /api/plugin/.../play-announcement` - Play announcement by button number
  - `POST /api/plugin/.../stop-announcement` - Stop current announcement
  - `GET /api/plugin/.../psa-status` - Get playback status

### Added - ALSA Software Mixing Configuration
- **Automatic dmix Setup**: Configures ALSA for concurrent audio streams on installation
- **Audio Card Detection**: Uses FPP's configured audio device (AudioOutput setting)
- **Backup System**: Automatically backs up existing /etc/asound.conf
- **Upgrade Detection**: Checks and updates ALSA config during plugin updates
- **FPP Compatibility**: Works seamlessly with FPP's native media playback

### Added - Documentation
- **Tab-Driven Help Page**: Organized help documentation with 6 sections
  - Overview, Setup Guide, PSA System, API Endpoints, Troubleshooting, About
- **API Documentation**: Complete REST API reference with examples
- **Troubleshooting Guide**: Common issues and solutions
- **PSA Configuration Guide**: Step-by-step setup instructions

### Changed
- **UI Layout**: 3-column grid (Background Music | PSA | Main Show)
- **Header Navigation**: Consistent navigation buttons across all pages
- **Audio Configuration**: Background music player now uses `plug:default` device
- **File Selection**: PSA configuration uses dropdown instead of text input

### Technical
- **ALSA dmix**: Software mixing for multiple concurrent audio streams
- **Audio Filters**: ffplay volume control via audio filters for dmix compatibility
- **Smart Upgrades**: Install script detects upgrades and updates ALSA configuration
- **Version Tracking**: `.installed_version` file tracks plugin version

### Fixed
- Audio device locking issues (multiple streams can now play concurrently)
- Volume ducking timing and smoothness
- PSA button state management during playback

### Requirements
- FPP 9.0 or higher
- fpp-brightness plugin (for brightness transitions)
- ALSA with dmix support (configured automatically)

### Upgrade Notes
**For existing installations upgrading to 2.0.0:**
1. Plugin automatically updates ALSA configuration during upgrade
2. After upgrade, stop and restart background music to apply changes
3. Configure PSA buttons in Settings page
4. PSA announcements will now work with concurrent audio playback

---

## [1.x.x] - Previous Versions

### Features
- Independent background music player
- Playlist shuffling with re-shuffle on loop
- Volume control for background, show, and post-show
- Track progress display with real-time updates
- Smooth show transitions with brightness fading
- MultiSync compatibility for multi-controller setups
- Auto-return to pre-show after main show
- Real-time status monitoring
- Playlist details view
- GPIO integration for physical triggers
- REST API for programmatic control
