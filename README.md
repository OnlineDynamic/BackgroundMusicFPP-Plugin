# BackgroundMusic Controller Plugin for FPP

This is the home of the BackgroundMusic FPP Plugin Repo

The purpose of this FPP plugin is to allow the end user to control a background music playlist directly from the FPP UI and have music playing over the top of sequence-only playlists to create background atmosphere, great for pre-show ambiance.

The plugin allows the user to start an audio-only background playlist whilst a normal FSEQ sequence is already running (normally an animation sequence on repeat).

A 'Start Show' button allows the user to trigger a configured show playlist. When triggered, FPP gradually reduces the brightness of the currently running playlist to fade it out at the same time as fading out the background music (time configurable). Once the fade completes, the background music and FSEQ playlists stop, have a blackout period (time configurable), and then return FPP to its previous brightness setting before starting the configured show playlist.

## Features

- 🎵 **Background Music Player** - Independent audio player that runs alongside FPP sequences
- 🔀 **Shuffle Mode** - Randomize playlist order for variety, reshuffles on each loop
- 🔊 **Volume Control** - Separate volume settings for background music, show, and post-show
- 📈 **Track Progress Display** - Real-time track name, progress bar, and time remaining
- 🎭 **Smooth Show Transitions** - Configurable fade-out and blackout before main show
- 🔄 **Auto-Return to Pre-Show** - Optionally restart background music after show ends with configurable delay
- 📊 **Real-Time Status** - View current FPP playlist, plugin state, and playing track
- 🎼 **Playlist Details View** - See all tracks with durations, highlights currently playing track
- 🔌 **GPIO Integration** - Trigger show start via physical buttons or sensors using FPP commands
- ⚙️ **REST API** - Full programmatic control via HTTP endpoints

## Quick Start

### 1. Installation

Plugin automatically installs via FPP plugin manager.

### 2. Configuration

1. Navigate to **Content Setup** → **Background Music Settings**
2. Select **Background Music Playlist** (audio-only playlist)
3. Select **Main Show Playlist** (your main show)
4. Configure **Volume Settings** (background, show, and post-show volumes)
5. Set fade/blackout times and post-show delay
6. Enable **Shuffle** if desired
7. Enable **Return to Pre-Show** if you want automatic restart after show
8. Click **Save Settings**

### 3. Basic Usage

**Start Background Music:**
- Go to **Status/Control** → **Background Music Controller**
- Click "Start Background Music" button
- Background music plays over scheduler-controlled sequences
- See real-time track progress and playlist details

**Start Main Show:**
- Click "Start Main Show" button on controller page
- OR configure GPIO input to trigger show (see below)
- Background music fades out → blackout → show starts

### 4. GPIO Setup (Optional)

The plugin exposes FPP commands that can be triggered via GPIO inputs, allowing physical buttons or sensors to start your show.

**Setup Steps:**

1. Go to **Input/Output Setup** → **GPIO Inputs**
2. Configure a GPIO pin with:
   - **Mode**: GPIO Input
   - **Edge**: Rising (for button press) or Falling
3. Under **Run Command When Triggered**, select:
   - **Command**: "Plugin Command"
   - **Plugin**: "fpp-plugin-BackgroundMusic"  
   - **Command**: "Start Main Show"
4. Save configuration and test

**Available FPP Commands:**
- `Start Main Show` - Initiates fade transition and starts main show playlist
- `Start Background Music` - Starts background music playback
- `Stop Background Music` - Stops background music playback

**Use Cases:**
- Push button at entrance to start show
- PIR motion sensor to trigger when audience arrives
- Toggle switch for manual show control
- Integration with other automation systems

## Controller Features

### Real-Time Status Display
- Background music running state
- Currently playing track with progress bar
- Time elapsed/remaining display
- FPP playlist status
- System brightness and volume levels
- Configuration summary

### Playlist Details Panel
- View all tracks in background music playlist
- Track numbers, names, and durations
- Total track count and playlist duration
- Highlights currently playing track with play icon
- Auto-updates every 2 seconds

### Volume Control
- Real-time volume adjustment slider
- Syncs with FPP's system volume
- Separate volume settings for:
  - Background Music (pre-show)
  - Show Playlist (main show)
  - Post-Show Background (after show returns)

## API Endpoints

All endpoints available at: `/api/plugin/fpp-plugin-BackgroundMusic/`

### Status

```bash
GET /api/plugin/fpp-plugin-BackgroundMusic/status
```

Returns current plugin state, FPP playlist, brightness, track progress, and configuration.

### Control Background Music

```bash
POST /api/plugin/fpp-plugin-BackgroundMusic/start-background
POST /api/plugin/fpp-plugin-BackgroundMusic/stop-background
```

### Trigger Show

```bash
POST /api/plugin/fpp-plugin-BackgroundMusic/start-show
```

### Set Volume

```bash
POST /api/plugin/fpp-plugin-BackgroundMusic/set-volume
Content-Type: application/json
{"volume": 70}
```

### Playlist Details

```bash
GET /api/plugin/fpp-plugin-BackgroundMusic/playlist-details
```

Returns track list with durations and metadata for the configured background music playlist.

### Save Settings

```bash
POST /api/plugin/fpp-plugin-BackgroundMusic/save-settings
Content-Type: application/json
{
  "BackgroundMusicPlaylist": "Background music only",
  "ShowPlaylist": "Main Show",
  "BackgroundMusicVolume": 70,
  "ShowPlaylistVolume": 100,
  "PostShowBackgroundVolume": 70,
  "FadeTime": 5,
  "BlackoutTime": 2,
  "ShuffleMusic": 1,
  "ReturnToPreShow": 1,
  "PostShowDelay": 5
}
```

## How It Works

The plugin uses an **independent audio player** (ffplay) that runs completely separate from FPP's playlist system. This allows:

- ✅ Background music + FPP sequences running simultaneously
- ✅ No playlist conflicts
- ✅ Scheduler controls sequences
- ✅ Plugin adds music layer
- ✅ Clean transitions between pre-show and show
- ✅ FPP commands for GPIO integration

### Architecture Highlights

- **Independent Player**: Uses ffplay process, not FPP playlists
- **Volume Management**: Integrates with FPP's native volume API
- **Process Control**: PID-based tracking for reliable start/stop
- **Smooth Transitions**: Coordinated brightness fading and audio crossfade
- **Auto-Recovery**: Optional return to pre-show after main show completes

## Support & Development

**Plugin Developer:** Stuart Ledingham of Dynamic Pixels

**Resources:**
- [GitHub Repository](https://github.com/OnlineDynamic/BackgroundMusicFPP-Plugin)
- [Bug Reports & Feature Requests](https://github.com/OnlineDynamic/BackgroundMusicFPP-Plugin/issues)

## License

This project is licensed under the terms specified in the LICENSE file.
