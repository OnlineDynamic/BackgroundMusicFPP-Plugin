<!DOCTYPE html>
<html>
<head>
    <title>Background Music Plugin - Help & About</title>
    <link rel="stylesheet" href="/css/fpp.css" />
    <?php include_once(__DIR__ . '/../logo_base64.php'); ?>
    <style>
        /* Tab Navigation */
        .tab-navigation {
            display: flex;
            border-bottom: 2px solid #dee2e6;
            margin-bottom: 20px;
            flex-wrap: wrap;
        }
        
        .tab-button {
            padding: 12px 24px;
            background-color: #f8f9fa;
            border: none;
            border-bottom: 3px solid transparent;
            cursor: pointer;
            font-size: 16px;
            font-weight: 500;
            transition: all 0.3s;
            color: #495057;
        }
        
        .tab-button:hover {
            background-color: #e9ecef;
        }
        
        .tab-button.active {
            background-color: #fff;
            border-bottom-color: #007bff;
            color: #007bff;
        }
        
        .tab-content {
            display: none;
            animation: fadeIn 0.3s;
        }
        
        .tab-content.active {
            display: block;
        }
        
        @keyframes fadeIn {
            from { opacity: 0; }
            to { opacity: 1; }
        }
        
        .section-divider {
            margin: 30px 0;
            border-top: 2px solid #e0e0e0;
        }
        
        .about-section {
            background-color: #f8f9fa;
            padding: 20px;
            border-radius: 8px;
            border: 2px solid #dee2e6;
            margin: 20px 0;
        }
        
        .about-section h2 {
            margin-top: 0;
            color: #007bff;
        }
        
        .credits {
            font-size: 16px;
            line-height: 1.8;
        }
        
        .credits a {
            color: #007bff;
            text-decoration: none;
        }
        
        .credits a:hover {
            text-decoration: underline;
        }
        
        .api-endpoint {
            background-color: #f8f9fa;
            border-left: 4px solid #007bff;
            padding: 15px;
            margin: 15px 0;
            border-radius: 4px;
        }
        
        .api-method {
            display: inline-block;
            padding: 4px 8px;
            border-radius: 4px;
            font-weight: bold;
            font-size: 12px;
            margin-right: 10px;
        }
        
        .api-method.get {
            background-color: #28a745;
            color: white;
        }
        
        .api-method.post {
            background-color: #007bff;
            color: white;
        }
        
        .api-path {
            font-family: monospace;
            background-color: #e9ecef;
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 14px;
        }
        
        .code-block {
            background-color: #2d2d2d;
            color: #f8f8f2;
            padding: 15px;
            border-radius: 4px;
            overflow-x: auto;
            font-family: 'Courier New', monospace;
            font-size: 13px;
            margin: 10px 0;
        }
        
        /* Suppress Font Awesome brand icons loading errors (not used in this page) */
        @font-face {
            font-family: "Font Awesome 6 Brands";
            src: none;
        }
    </style>
</head>
<body>
    <div id="global" class="settings">
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px;">
            <h1 style="margin: 0;">Background Music Plugin - Help & About</h1>
            <div>
                <a href="/plugin.php?_menu=status&plugin=fpp-plugin-BackgroundMusic&page=backgroundmusic.php" class="btn btn-outline-secondary" style="margin-right: 5px;">
                    <i class="fas fa-music"></i> Controller
                </a>
                <a href="/plugin.php?_menu=content&plugin=fpp-plugin-BackgroundMusic&page=content.php" class="btn btn-outline-secondary">
                    <i class="fas fa-cog"></i> Settings
                </a>
            </div>
        </div>
        
        <!-- Tab Navigation -->
        <div class="tab-navigation">
            <button class="tab-button active" onclick="switchTab('overview', this)">
                <i class="fas fa-home"></i> Overview
            </button>
            <button class="tab-button" onclick="switchTab('setup', this)">
                <i class="fas fa-cog"></i> Setup Guide
            </button>
            <button class="tab-button" onclick="switchTab('psa', this)">
                <i class="fas fa-bullhorn"></i> PSA System
            </button>
            <button class="tab-button" onclick="switchTab('api', this)">
                <i class="fas fa-code"></i> API Endpoints
            </button>
            <button class="tab-button" onclick="switchTab('troubleshooting', this)">
                <i class="fas fa-wrench"></i> Troubleshooting
            </button>
            <button class="tab-button" onclick="switchTab('changelog', this)">
                <i class="fas fa-history"></i> Changelog
            </button>
            <button class="tab-button" onclick="switchTab('about', this)">
                <i class="fas fa-info-circle"></i> Plugin Info
            </button>
        </div>
        
        <!-- Overview Tab -->
        <div id="overview" class="tab-content active">
            <div style="background-color: #fff3cd; border: 2px solid #ffc107; border-radius: 5px; padding: 15px; margin-bottom: 20px;">
                <h3 style="margin-top: 0; color: #856404;"><i class="fas fa-exclamation-triangle"></i> Required Plugin - Install on ALL Controllers</h3>
                <p style="margin-bottom: 10px; font-weight: bold;">
                    This plugin requires the <strong>fpp-brightness</strong> plugin to be installed on <strong>EVERY controller</strong> 
                    in your setup - both master and all remotes.
                </p>
                <p style="margin-bottom: 10px;">
                    <strong>Why on all controllers?</strong> The brightness plugin enables MultiSync, which synchronizes brightness changes 
                    across all controllers during the fade transition. If any controller is missing the plugin, it won't fade in sync with the others.
                </p>
                <p style="margin-bottom: 0;">
                    <strong>Installation Steps:</strong>
                </p>
                <ol style="margin-top: 5px; margin-bottom: 0;">
                    <li>On each controller, go to <em>Plugin Manager → Install Plugins</em></li>
                    <li>Search for "brightness"</li>
                    <li>Click "Install" on <strong>fpp-brightness</strong></li>
                    <li>Restart FPPd when prompted</li>
                    <li>Repeat on EVERY controller in your show</li>
                </ol>
                <p style="margin-top: 10px; margin-bottom: 0;">
                    <strong>Alternative:</strong> Visit <a href="https://github.com/FalconChristmas/fpp-brightness" target="_blank">fpp-brightness on GitHub</a> 
                    for manual installation instructions.
                </p>
            </div>
            
            <h2>Purpose</h2>
            <p>
                This plugin adds background music audio playback to your existing FPP scheduler-controlled
                pre-show sequences. The music plays independently without interfering with FPP's playlist
                system. When ready, trigger a smooth transition to your main show with automatic fade-out
                and brightness control. Optionally, the system can automatically return to pre-show state
                when your main show ends.
            </p>
            
            <h2>How It Works</h2>
            <p>
                <strong>Important:</strong> This plugin is designed to work <em>with</em> FPP's scheduler,
                not replace it. Your pre-show sequence should already be running via FPP's scheduler in
                looping mode. This plugin simply adds background music audio on top of that sequence.
            </p>
            <ul>
                <li><strong>Pre-Show:</strong> FPP scheduler runs your looping sequence playlist. 
                    Plugin plays background music independently using ffplay.</li>
                <li><strong>Main Show:</strong> Plugin fades out, stops music, and triggers your main show.</li>
                <li><strong>After Show:</strong> If "Return to Pre-Show" is enabled, background music 
                    automatically restarts (scheduler will resume pre-show sequence per its schedule).</li>
            </ul>
            
            <h2>Features</h2>
            <h3>Background Music Playback</h3>
            <p>
                Independent audio player that runs alongside your sequences. Music automatically loops 
                continuously - no gaps, no configuration needed. Works perfectly even with short playlists.
            </p>
            
            <h3>Media Player Controls</h3>
            <p>
                Full media player functionality with pause/resume, next/previous track navigation, and jump to specific track. 
                The controller interface includes a progress bar showing current track position and time, clickable playlist 
                for instant track selection, and drag-and-drop reordering. All controls are available via both the web UI 
                and REST API.
            </p>
            
            <h3>Smooth Show Transitions</h3>
            <p>
                Professional fade-out with synchronized brightness dimming across all controllers (via MultiSync). 
                Configurable fade and blackout times create dramatic transitions to your main show.
            </p>
            
            <h3>Public Service Announcements (PSA)</h3>
            <p>
                Play pre-recorded announcements over background music with automatic volume ducking. 
                Configure up to 5 announcement buttons with custom labels and smooth audio mixing.
            </p>
            
            <h3>Shuffle Mode</h3>
            <p>
                Enable "Shuffle Music Playlist" to randomize track order. The playlist is reshuffled
                each time it loops, providing variety and preventing listener fatigue.
            </p>
            
            <h2>How the Transition Works</h2>
            <p>When you click "Start Main Show", the following happens automatically:</p>
            <ol>
                <li>System captures current brightness level</li>
                <li>Brightness fades from current to 0 using the <strong>fpp-brightness plugin</strong></li>
                <li>Background music fades out simultaneously</li>
                <li>Background music player stops (independent process)</li>
                <li>All FPP playlists stop (including any running sequences)</li>
                <li>System waits during blackout period (creates dramatic pause)</li>
                <li>Brightness restores to original level via brightness plugin</li>
                <li>Main show playlist starts</li>
            </ol>
            
            <div style="background-color: #d1ecf1; border-left: 4px solid #0c5460; padding: 10px; margin: 15px 0;">
                <p style="margin: 0;"><strong><i class="fas fa-info-circle"></i> MultiSync Requirement:</strong> 
                For brightness to fade in sync across all controllers, the <strong>fpp-brightness plugin must be installed 
                on the master AND every remote controller</strong>. When MultiSync is enabled in FPP and the plugin is installed 
                everywhere, brightness changes will automatically synchronize during the transition.</p>
            </div>
        </div>
        
        <!-- Setup Guide Tab -->
        <div id="setup" class="tab-content">
            <h2>Setup Steps</h2>
            <ol>
                <li><strong>Install Required Plugins:</strong>
                    <ul>
                        <li>Install <strong>fpp-brightness</strong> plugin on ALL controllers (master and remotes)</li>
                        <li>Go to Plugin Manager → Install Plugins → Search "brightness" → Install → Restart FPPd</li>
                        <li>Verify installation on each controller before proceeding</li>
                    </ul>
                </li>
                <li><strong>Set Up FPP Scheduler:</strong>
                    <ul>
                        <li>Configure your pre-show sequence playlist to loop via FPP's scheduler</li>
                        <li>This should already be running before using this plugin</li>
                    </ul>
                </li>
                <li><strong>Create Background Music Playlist:</strong>
                    <ul>
                        <li>Create a playlist containing ONLY audio files (media type)</li>
                        <li>No sequences or FSEQ files - audio only (MP3, WAV, etc.)</li>
                        <li>Go to Content Setup → Playlists → Add Playlist</li>
                        <li>Add your music files to the playlist</li>
                    </ul>
                </li>
                <li><strong>Create Main Show Playlist:</strong>
                    <ul>
                        <li>Your full synchronized show playlist (can include sequences and audio)</li>
                        <li>This is the playlist that will start after the fade transition</li>
                    </ul>
                </li>
                <li><strong>Configure Plugin:</strong>
                    <ul>
                        <li>Go to Content Setup → Background Music Settings</li>
                        <li>Select your background music playlist (media-only)</li>
                        <li>Select your main show playlist</li>
                        <li>Set fade time (how long to fade out, 1-60 seconds, recommended: 5s)</li>
                        <li>Set blackout time (pause before show starts, 0-30 seconds, recommended: 2-3s)</li>
                        <li>Configure volume levels for different states</li>
                        <li>Enable "Return to Pre-Show" if you want music to auto-restart after show</li>
                        <li>Enable "Shuffle Music" if you want randomized track order (optional)</li>
                        <li>Save Settings</li>
                    </ul>
                </li>
                <li><strong>Use the Controller:</strong>
                    <ul>
                        <li>Go to Status/Control → Background Music Controller</li>
                        <li>Ensure your pre-show sequence is running via FPP scheduler</li>
                        <li>Click "Start Background Music" to add music to the scene</li>
                        <li>When ready, click "Start Main Show" to trigger transition</li>
                    </ul>
                </li>
            </ol>
            
            <h2>Tips for Best Results</h2>
            <ul>
                <li><strong>Fade Time:</strong> 5 seconds provides a smooth, professional transition</li>
                <li><strong>Blackout Time:</strong> 2-3 seconds creates anticipation before the show</li>
                <li><strong>Background Animation:</strong> Use simple, looping sequences that aren't distracting</li>
                <li><strong>Background Music:</strong> Choose instrumental or ambient music that sets the mood</li>
                <li><strong>Volume Levels:</strong> Set background music slightly lower than show volume</li>
                <li><strong>Test First:</strong> Always test your transition before the actual event</li>
                <li><strong>MultiSync:</strong> Verify brightness plugin installed on all controllers for synchronized fades</li>
            </ul>
        </div>
        
        <!-- PSA System Tab -->
        <div id="psa" class="tab-content">
            <h2>Public Service Announcements (PSA)</h2>
            <p>
                The PSA system allows you to play pre-recorded announcements over your background music.
                The background music volume automatically "ducks" (lowers) during the announcement, then
                smoothly fades back up when the announcement completes.
            </p>
            
            <h3>How It Works</h3>
            <ul>
                <li>Announcements play through a separate audio stream using ALSA dmix</li>
                <li>Background music volume smoothly fades down over 1 second (ducking)</li>
                <li>Announcement plays at configured volume</li>
                <li>After announcement completes, music volume smoothly fades back up over 1 second</li>
                <li>Only one announcement can play at a time</li>
            </ul>
            
            <h3>Configuration</h3>
            <ol>
                <li><strong>Prepare Announcement Files:</strong>
                    <ul>
                        <li>Create or obtain your announcement audio files (MP3 format recommended)</li>
                        <li>Upload them to <code>/home/fpp/media/music/</code> via FPP's File Manager</li>
                        <li>Keep filenames simple and descriptive</li>
                    </ul>
                </li>
                <li><strong>Configure PSA Settings:</strong>
                    <ul>
                        <li>Go to Content Setup → Background Music Settings</li>
                        <li>Scroll to "Public Service Announcements" section</li>
                        <li>Set <strong>Announcement Volume</strong> (0-100%, default: 90%)</li>
                        <li>Set <strong>Ducked Music Volume</strong> (0-100%, default: 30%)</li>
                    </ul>
                </li>
                <li><strong>Configure Buttons (up to 5):</strong>
                    <ul>
                        <li>For each button, set a <strong>Label</strong> (e.g., "Welcome Message")</li>
                        <li><strong>Select an MP3 File</strong> from the dropdown (files from /home/fpp/media/music/)</li>
                        <li>Leave unused buttons empty - they won't appear on the controller</li>
                    </ul>
                </li>
                <li><strong>Save Settings</strong></li>
            </ol>
            
            <h3>Using PSA Buttons</h3>
            <ul>
                <li>Go to Status/Control → Background Music Controller</li>
                <li>Configured PSA buttons appear in the center column</li>
                <li>Click a button to play that announcement</li>
                <li>Button will pulse/animate while announcement is playing</li>
                <li>Buttons are disabled while any announcement is playing</li>
                <li>Music volume automatically ducks and restores</li>
            </ul>
            
            <h3>Example Use Cases</h3>
            <ul>
                <li><strong>Welcome Message:</strong> "Welcome to our holiday light display!"</li>
                <li><strong>Show Starting:</strong> "Our main show will begin in 2 minutes"</li>
                <li><strong>Safety Reminder:</strong> "Please stay on the sidewalk"</li>
                <li><strong>Thank You:</strong> "Thank you for visiting! Happy holidays!"</li>
                <li><strong>Tune In:</strong> "Tune your radio to 87.9 FM to hear the music"</li>
            </ul>
            
            <h3>Tips</h3>
            <ul>
                <li>Keep announcements short (15-30 seconds maximum)</li>
                <li>Record in a quiet environment with clear audio</li>
                <li>Normalize audio levels for consistency</li>
                <li>Test volume levels before your event</li>
                <li>Consider having announcements in multiple languages for diverse audiences</li>
            </ul>
            
            <h3>Technical Requirements</h3>
            <p>PSA announcements use ALSA software mixing to play concurrently with background music. The plugin automatically configures this during installation:</p>
            <ul>
                <li><strong>ALSA dmix:</strong> Configured in <code>/etc/asound.conf</code></li>
                <li><strong>Software Mixing:</strong> Allows multiple audio streams simultaneously</li>
                <li><strong>Backup:</strong> Original config backed up to <code>/etc/asound.conf.backup-*</code></li>
                <li><strong>Audio Device:</strong> Uses <code>plug:default</code> for automatic format conversion and mixing</li>
                <li><strong>FPP Compatibility:</strong> Configuration uses FPP's audio card setting (AudioOutput)</li>
                <li><strong>Transparent Operation:</strong> FPP's playlists and media playback continue to work normally</li>
            </ul>
            <div class="alert alert-info">
                <strong>Note:</strong> If PSA announcements don't play, stop and restart background music after plugin installation to apply ALSA configuration changes. If you change FPP's audio device, reinstall the plugin to update ALSA configuration.
            </div>
            </ul>
        </div>
        
        <!-- API Endpoints Tab -->
        <div id="api" class="tab-content">
            <h2>API Endpoints</h2>
            <p>
                This plugin exposes REST API endpoints that can be used for automation, integration with 
                other systems, or custom control interfaces. All endpoints use the base path:
            </p>
            <p class="api-path">/api/plugin/fpp-plugin-BackgroundMusic/</p>
            
            <h3>Status & Information</h3>
            
            <div class="api-endpoint">
                <div>
                    <span class="api-method get">GET</span>
                    <code class="api-path">version</code>
                </div>
                <p><strong>Description:</strong> Get plugin version information</p>
                <p><strong>Response:</strong></p>
                <div class="code-block">{"version": "fpp-BackgroundMusic v1.0"}</div>
            </div>
            
            <div class="api-endpoint">
                <div>
                    <span class="api-method get">GET</span>
                    <code class="api-path">status</code>
                </div>
                <p><strong>Description:</strong> Get current status of background music, show, brightness, and all configuration</p>
                <p><strong>Response includes:</strong></p>
                <ul>
                    <li><code>backgroundMusicRunning</code> - Boolean, true if music playing</li>
                    <li><code>showRunning</code> - Boolean, true if main show active</li>
                    <li><code>playbackState</code> - String ("playing", "paused", or "stopped"), current playback state</li>
                    <li><code>brightness</code> - Integer (0-100), current brightness level</li>
                    <li><code>brightnessPluginInstalled</code> - Boolean, fpp-brightness plugin status</li>
                    <li><code>currentPlaylist</code> - String, currently playing FPP playlist</li>
                    <li><code>currentTrack</code> - String, currently playing music track name</li>
                    <li><code>currentTrackNumber</code> - Integer, track position in playlist (1-based)</li>
                    <li><code>totalTracks</code> - Integer, total number of tracks in playlist</li>
                    <li><code>trackDuration</code> - Integer, track duration in seconds</li>
                    <li><code>trackElapsed</code> - Integer, elapsed time in seconds</li>
                    <li><code>trackProgress</code> - Integer (0-100), playback progress percentage</li>
                    <li><code>config</code> - Object containing all plugin settings including PSA configuration</li>
                </ul>
                <p><strong>Example Response:</strong></p>
                <div class="code-block">{
  "backgroundMusicRunning": true,
  "showRunning": false,
  "playbackState": "playing",
  "brightness": 100,
  "currentTrack": "Holiday Music 01.mp3",
  "currentTrackNumber": 3,
  "totalTracks": 12,
  "trackProgress": 45,
  "config": {
    "backgroundMusicPlaylist": "PreShowMusic",
    "fadeTime": "5",
    ...
  }
}</div>
            </div>
            
            <div class="api-endpoint">
                <div>
                    <span class="api-method get">GET</span>
                    <code class="api-path">playlist-details</code>
                </div>
                <p><strong>Description:</strong> Get detailed information about the background music playlist</p>
                <p><strong>Response includes:</strong></p>
                <ul>
                    <li><code>playlistName</code> - String, name of playlist</li>
                    <li><code>totalTracks</code> - Integer, number of tracks</li>
                    <li><code>totalDuration</code> - Integer, total duration in seconds</li>
                    <li><code>tracks</code> - Array of track objects with name, duration, etc.</li>
                </ul>
            </div>
            
            <h3>Background Music Control</h3>
            
            <div class="api-endpoint">
                <div>
                    <span class="api-method post">POST</span>
                    <code class="api-path">start-background</code>
                </div>
                <p><strong>Description:</strong> Start playing background music</p>
                <p><strong>Requirements:</strong> Background music playlist must be configured</p>
                <p><strong>Response:</strong></p>
                <div class="code-block">{"status": "OK", "message": "Background music started"}</div>
            </div>
            
            <div class="api-endpoint">
                <div>
                    <span class="api-method post">POST</span>
                    <code class="api-path">stop-background</code>
                </div>
                <p><strong>Description:</strong> Stop playing background music</p>
                <p><strong>Response:</strong></p>
                <div class="code-block">{"status": "OK", "message": "Background music stopped"}</div>
            </div>
            
            <h3>Media Player Controls</h3>
            
            <div class="api-endpoint">
                <div>
                    <span class="api-method post">POST</span>
                    <code class="api-path">pause-background</code>
                </div>
                <p><strong>Description:</strong> Pause currently playing background music</p>
                <p><strong>Behavior:</strong> Pauses audio playback without stopping the player. Progress bar freezes at current position.</p>
                <p><strong>Response:</strong></p>
                <div class="code-block">{"status": "OK", "message": "Background music paused"}</div>
            </div>
            
            <div class="api-endpoint">
                <div>
                    <span class="api-method post">POST</span>
                    <code class="api-path">resume-background</code>
                </div>
                <p><strong>Description:</strong> Resume paused background music</p>
                <p><strong>Behavior:</strong> Continues playback from current position. Progress bar resumes advancing.</p>
                <p><strong>Response:</strong></p>
                <div class="code-block">{"status": "OK", "message": "Background music resumed"}</div>
            </div>
            
            <div class="api-endpoint">
                <div>
                    <span class="api-method post">POST</span>
                    <code class="api-path">next-track</code>
                </div>
                <p><strong>Description:</strong> Skip to next track in background music playlist</p>
                <p><strong>Behavior:</strong> Immediately advances to next track. If at end of playlist, wraps to first track.</p>
                <p><strong>Response:</strong></p>
                <div class="code-block">{"status": "OK", "message": "Skipped to next track"}</div>
            </div>
            
            <div class="api-endpoint">
                <div>
                    <span class="api-method post">POST</span>
                    <code class="api-path">previous-track</code>
                </div>
                <p><strong>Description:</strong> Go back to previous track in background music playlist</p>
                <p><strong>Behavior:</strong> Returns to previous track. If at first track, wraps to last track.</p>
                <p><strong>Response:</strong></p>
                <div class="code-block">{"status": "OK", "message": "Returned to previous track"}</div>
            </div>
            
            <div class="api-endpoint">
                <div>
                    <span class="api-method post">POST</span>
                    <code class="api-path">jump-to-track</code>
                </div>
                <p><strong>Description:</strong> Jump directly to a specific track number</p>
                <p><strong>Request Body:</strong></p>
                <div class="code-block">{"trackNumber": 5}</div>
                <p><strong>Parameters:</strong></p>
                <ul>
                    <li><code>trackNumber</code> - Integer (1-based), track position in playlist</li>
                </ul>
                <p><strong>Behavior:</strong> Immediately starts playing the specified track.</p>
                <p><strong>Response:</strong></p>
                <div class="code-block">{"status": "OK", "message": "Jumped to track 5"}</div>
            </div>
            
            <div class="api-endpoint">
                <div>
                    <span class="api-method post">POST</span>
                    <code class="api-path">reorder-playlist</code>
                </div>
                <p><strong>Description:</strong> Reorder background music playlist tracks</p>
                <p><strong>Request Body:</strong></p>
                <div class="code-block">{"trackOrder": ["song3.mp3", "song1.mp3", "song2.mp3"]}</div>
                <p><strong>Parameters:</strong></p>
                <ul>
                    <li><code>trackOrder</code> - Array of strings, track filenames in new order</li>
                </ul>
                <p><strong>Behavior:</strong> Updates playlist order without interrupting current playback. Changes persist across restarts.</p>
                <p><strong>Response:</strong></p>
                <div class="code-block">{"status": "OK", "message": "Playlist reordered successfully"}</div>
            </div>
            
            <h3>Show Control</h3>
            
            <div class="api-endpoint">
                <div>
                    <span class="api-method post">POST</span>
                    <code class="api-path">start-show</code>
                </div>
                <p><strong>Description:</strong> Start show transition (fade out, blackout, start main show)</p>
                <p><strong>Requirements:</strong> Show playlist must be configured</p>
                <p><strong>Process:</strong> Triggers fade out, stops background music, stops playlists, waits blackout time, starts show</p>
                <p><strong>Response:</strong></p>
                <div class="code-block">{"status": "OK", "message": "Show transition started"}</div>
            </div>
            
            <h3>PSA (Public Service Announcements)</h3>
            
            <div class="api-endpoint">
                <div>
                    <span class="api-method post">POST</span>
                    <code class="api-path">play-announcement</code>
                </div>
                <p><strong>Description:</strong> Play a configured announcement with volume ducking</p>
                <p><strong>Request Body:</strong></p>
                <div class="code-block">{"buttonNumber": 1}</div>
                <p><strong>Parameters:</strong></p>
                <ul>
                    <li><code>buttonNumber</code> - Integer (1-5), which PSA button to trigger</li>
                </ul>
                <p><strong>Behavior:</strong> Ducks music volume, plays announcement, restores volume</p>
                <p><strong>Response:</strong></p>
                <div class="code-block">{"status": "OK", "message": "Announcement started"}</div>
            </div>
            
            <div class="api-endpoint">
                <div>
                    <span class="api-method post">POST</span>
                    <code class="api-path">stop-announcement</code>
                </div>
                <p><strong>Description:</strong> Stop currently playing announcement and restore music volume</p>
                <p><strong>Response:</strong></p>
                <div class="code-block">{"status": "OK", "message": "Announcement stopped"}</div>
            </div>
            
            <div class="api-endpoint">
                <div>
                    <span class="api-method get">GET</span>
                    <code class="api-path">psa-status</code>
                </div>
                <p><strong>Description:</strong> Get current PSA playback status</p>
                <p><strong>Response:</strong></p>
                <div class="code-block">{
  "status": "OK",
  "playing": false,
  "currentFile": ""
}</div>
            </div>
            
            <h3>Configuration</h3>
            
            <div class="api-endpoint">
                <div>
                    <span class="api-method post">POST</span>
                    <code class="api-path">set-volume</code>
                </div>
                <p><strong>Description:</strong> Set FPP system volume</p>
                <p><strong>Request Body:</strong></p>
                <div class="code-block">{"volume": 75}</div>
                <p><strong>Parameters:</strong></p>
                <ul>
                    <li><code>volume</code> - Integer (0-100), volume level</li>
                </ul>
            </div>
            
            <div class="api-endpoint">
                <div>
                    <span class="api-method post">POST</span>
                    <code class="api-path">save-settings</code>
                </div>
                <p><strong>Description:</strong> Save plugin configuration settings</p>
                <p><strong>Request Body:</strong> JSON object with configuration keys and values</p>
                <p><strong>Common Keys:</strong></p>
                <ul>
                    <li><code>BackgroundMusicPlaylist</code></li>
                    <li><code>ShowPlaylist</code></li>
                    <li><code>FadeTime</code></li>
                    <li><code>BlackoutTime</code></li>
                    <li><code>BackgroundMusicVolume</code></li>
                    <li><code>ShowPlaylistVolume</code></li>
                    <li><code>PSAButton1Label</code>, <code>PSAButton1File</code> (etc. for buttons 1-5)</li>
                    <li><code>PSAAnnouncementVolume</code>, <code>PSADuckVolume</code></li>
                </ul>
            </div>
            
            <h3>Example Usage</h3>
            <p><strong>cURL Examples:</strong></p>
            
            <p>Get current status:</p>
            <div class="code-block">curl http://localhost/api/plugin/fpp-plugin-BackgroundMusic/status</div>
            
            <p>Start background music:</p>
            <div class="code-block">curl -X POST http://localhost/api/plugin/fpp-plugin-BackgroundMusic/start-background</div>
            
            <p>Pause playback:</p>
            <div class="code-block">curl -X POST http://localhost/api/plugin/fpp-plugin-BackgroundMusic/pause-background</div>
            
            <p>Resume playback:</p>
            <div class="code-block">curl -X POST http://localhost/api/plugin/fpp-plugin-BackgroundMusic/resume-background</div>
            
            <p>Skip to next track:</p>
            <div class="code-block">curl -X POST http://localhost/api/plugin/fpp-plugin-BackgroundMusic/next-track</div>
            
            <p>Go to previous track:</p>
            <div class="code-block">curl -X POST http://localhost/api/plugin/fpp-plugin-BackgroundMusic/previous-track</div>
            
            <p>Jump to track #5:</p>
            <div class="code-block">curl -X POST -H "Content-Type: application/json" \
  -d '{"trackNumber": 5}' \
  http://localhost/api/plugin/fpp-plugin-BackgroundMusic/jump-to-track</div>
            
            <p>Reorder playlist tracks:</p>
            <div class="code-block">curl -X POST -H "Content-Type: application/json" \
  -d '{"trackOrder": ["song3.mp3", "song1.mp3", "song2.mp3"]}' \
  http://localhost/api/plugin/fpp-plugin-BackgroundMusic/reorder-playlist</div>
            
            <p>Play announcement #1:</p>
            <div class="code-block">curl -X POST -H "Content-Type: application/json" \
  -d '{"buttonNumber": 1}' \
  http://localhost/api/plugin/fpp-plugin-BackgroundMusic/play-announcement</div>
            
            <p>Trigger show transition:</p>
            <div class="code-block">curl -X POST http://localhost/api/plugin/fpp-plugin-BackgroundMusic/start-show</div>
        </div>
        
        <!-- Troubleshooting Tab -->
        <div id="troubleshooting" class="tab-content">
            <h2>Troubleshooting</h2>
            
            <h3>fpp-brightness Plugin Issues</h3>
            <p><strong>Problem:</strong> Warning shows "fpp-brightness plugin not installed"</p>
            <p><strong>Solution:</strong></p>
            <ul>
                <li>Go to Plugin Manager → Install Plugins</li>
                <li>Search for "brightness"</li>
                <li>Install fpp-brightness plugin</li>
                <li>Restart FPPd</li>
                <li><strong>Important:</strong> Must be installed on ALL controllers (master + remotes)</li>
            </ul>
            
            <h3>Brightness Not Fading on Remote Controllers</h3>
            <p><strong>Problem:</strong> Master fades but remotes don't</p>
            <p><strong>Solution:</strong></p>
            <ul>
                <li>Install fpp-brightness plugin on EVERY remote controller</li>
                <li>Verify MultiSync is enabled in FPP settings</li>
                <li>Restart FPPd on all controllers after installing plugin</li>
            </ul>
            
            <h3>Playlists Not Showing in Dropdown</h3>
            <p><strong>Problem:</strong> Background music playlist dropdown is empty</p>
            <p><strong>Solution:</strong></p>
            <ul>
                <li>Create playlists in FPP first (Content Setup → Playlists)</li>
                <li>For background music, playlist must contain ONLY media files (no sequences)</li>
                <li>Ensure playlist has at least one enabled track</li>
                <li>Refresh the settings page</li>
            </ul>
            
            <h3>Background Music Won't Start</h3>
            <p><strong>Possible Causes & Solutions:</strong></p>
            <ul>
                <li><strong>No playlist configured:</strong> Select a background music playlist in settings</li>
                <li><strong>Empty playlist:</strong> Add audio files to the playlist</li>
                <li><strong>File not found:</strong> Check that media files exist in /home/fpp/media/music/</li>
                <li><strong>Permission issues:</strong> Ensure FPP has read access to media files</li>
                <li><strong>Audio device busy:</strong> Check if another process is using the audio device</li>
            </ul>
            
            <h3>Transition Not Smooth</h3>
            <p><strong>Problem:</strong> Fade is jerky or stuttery</p>
            <p><strong>Solution:</strong></p>
            <ul>
                <li>Increase the fade time setting (try 5-10 seconds)</li>
                <li>Ensure fpp-brightness plugin is installed (required for smooth fades)</li>
                <li>Check system load - high CPU usage can affect fade smoothness</li>
                <li>Verify network latency if using MultiSync with remote controllers</li>
            </ul>
            
            <h3>PSA Button Not Appearing</h3>
            <p><strong>Problem:</strong> Configured PSA button doesn't show on controller</p>
            <p><strong>Solution:</strong></p>
            <ul>
                <li>Verify both Label AND File are selected</li>
                <li>Check that audio file exists in /home/fpp/media/music/</li>
                <li>Save settings and refresh the controller page</li>
                <li>Check browser console for JavaScript errors</li>
            </ul>
            
            <h3>PSA Volume Ducking Not Working</h3>
            <p><strong>Problem:</strong> Background music volume doesn't duck during announcements</p>
            <p><strong>Solution:</strong></p>
            <ul>
                <li>Ensure background music is actually playing</li>
                <li>Check that PSADuckVolume is set lower than current music volume</li>
                <li>Verify FPP's volume API is working (test volume slider on controller page)</li>
                <li>Check logs: <code>/home/fpp/media/logs/fpp-plugin-BackgroundMusic.log</code></li>
            </ul>
            
            <h3>PSA Announcement No Audio</h3>
            <p><strong>Problem:</strong> PSA button shows alert but no audio plays</p>
            <p><strong>Solution:</strong></p>
            <ul>
                <li><strong>Check ALSA configuration:</strong> Verify <code>/etc/asound.conf</code> has dmix configured</li>
                <li><strong>Restart background music:</strong> Stop and start background music after plugin installation</li>
                <li><strong>Test device:</strong> Run <code>aplay -L</code> to verify "plug:default" device exists</li>
                <li><strong>Check logs:</strong> Look for "Device or resource busy" errors in plugin log</li>
                <li><strong>Verify audio files:</strong> Ensure announcement files are valid and readable</li>
            </ul>
            <div class="alert alert-warning">
                <strong>Important:</strong> PSA announcements require ALSA software mixing (dmix). The plugin configures this automatically during installation, but you must stop/restart background music for changes to take effect.
            </div>
            
            <h3>Settings Not Saving</h3>
            <p><strong>Problem:</strong> Changes don't persist after clicking Save</p>
            <p><strong>Solution:</strong></p>
            <ul>
                <li>Check file permissions on /home/fpp/media/config/</li>
                <li>Ensure disk is not full (check with <code>df -h</code>)</li>
                <li>Check browser console for AJAX errors</li>
                <li>Try saving with fewer changes at once</li>
            </ul>
            
            <h3>Check Logs</h3>
            <p>For detailed troubleshooting, check the plugin log file:</p>
            <div class="code-block">/home/fpp/media/logs/fpp-plugin-BackgroundMusic.log</div>
            <p>View recent log entries:</p>
            <div class="code-block">tail -f /home/fpp/media/logs/fpp-plugin-BackgroundMusic.log</div>
            
            <h3>Support</h3>
            <p>
                If issues persist, please visit: 
                <a href="https://github.com/OnlineDynamic/BackgroundMusicFPP-Plugin/issues" target="_blank">
                    <i class="fab fa-github"></i> GitHub Issues
                </a>
            </p>
            <p>When reporting issues, please include:</p>
            <ul>
                <li>FPP version</li>
                <li>Plugin version</li>
                <li>Relevant log entries</li>
                <li>Steps to reproduce the problem</li>
                <li>Your configuration settings (sanitized if needed)</li>
            </ul>
        </div>
        
        <!-- Changelog Tab -->
        <div id="changelog" class="tab-content">
            <h2>Plugin Version History</h2>
            <p>Recent commits and changes to the Background Music Plugin:</p>
            
            <div id="changelogContent" style="margin-top: 20px;">
                <div style="text-align: center; padding: 40px;">
                    <i class="fas fa-spinner fa-spin" style="font-size: 32px; color: #007bff;"></i>
                    <p style="margin-top: 15px; color: #6c757d;">Loading commit history...</p>
                </div>
            </div>
            
            <script>
                // Helper function to escape HTML
                function escapeHtml(text) {
                    const div = document.createElement('div');
                    div.textContent = text;
                    return div.innerHTML;
                }
                
                // Load Git commit history when changelog tab is opened
                function loadChangelog() {
                    fetch('/api/plugin/fpp-plugin-BackgroundMusic/get-commit-history')
                        .then(response => {
                            if (!response.ok) {
                                throw new Error('Network response was not ok');
                            }
                            return response.json();
                        })
                        .then(data => {
                            const container = document.getElementById('changelogContent');
                            
                            if (data.status === 'OK' && data.commits && data.commits.length > 0) {
                                let html = '';
                                data.commits.forEach((commit, index) => {
                                    const date = new Date(commit.date);
                                    const formattedDate = date.toLocaleDateString('en-US', {
                                        year: 'numeric',
                                        month: 'long',
                                        day: 'numeric',
                                        hour: '2-digit',
                                        minute: '2-digit'
                                    });
                                    
                                    const escapedMessage = escapeHtml(commit.message);
                                    const escapedAuthor = escapeHtml(commit.author);
                                    const shortHash = commit.hash.substring(0, 7);
                                    const bgColor = index % 2 === 0 ? '#f8f9fa' : '#ffffff';
                                    
                                    html += `
                                        <div style="background-color: ${bgColor}; 
                                                    border-left: 4px solid #007bff; 
                                                    padding: 15px 20px; 
                                                    margin-bottom: 10px; 
                                                    border-radius: 4px;
                                                    box-shadow: 0 1px 3px rgba(0,0,0,0.1);">
                                            <div style="display: flex; justify-content: space-between; align-items: start; margin-bottom: 8px;">
                                                <div style="flex: 1;">
                                                    <strong style="color: #212529; font-size: 15px;">${escapedMessage}</strong>
                                                </div>
                                                <div style="text-align: right; margin-left: 15px;">
                                                    <code style="background-color: #e9ecef; padding: 2px 6px; border-radius: 3px; font-size: 11px; color: #495057;">${shortHash}</code>
                                                </div>
                                            </div>
                                            <div style="font-size: 13px; color: #6c757d;">
                                                <i class="fas fa-user" style="margin-right: 5px;"></i>${escapedAuthor}
                                                <span style="margin: 0 10px;">•</span>
                                                <i class="fas fa-calendar" style="margin-right: 5px;"></i>${formattedDate}
                                            </div>
                                        </div>
                                    `;
                                });
                                container.innerHTML = html;
                            } else {
                                const errorMsg = data.message || 'Unable to load commit history. This may be a manual installation or Git is not available.';
                                container.innerHTML = `
                                    <div style="background-color: #fff3cd; border: 2px solid #ffc107; border-radius: 5px; padding: 20px; text-align: center;">
                                        <i class="fas fa-exclamation-triangle" style="font-size: 32px; color: #856404; margin-bottom: 10px;"></i>
                                        <p style="margin: 0; color: #856404;">${escapeHtml(errorMsg)}</p>
                                    </div>
                                `;
                            }
                        })
                        .catch(error => {
                            document.getElementById('changelogContent').innerHTML = `
                                <div style="background-color: #f8d7da; border: 2px solid #f5c6cb; border-radius: 5px; padding: 20px; text-align: center;">
                                    <i class="fas fa-exclamation-circle" style="font-size: 32px; color: #721c24; margin-bottom: 10px;"></i>
                                    <p style="margin: 0; color: #721c24;">Error loading commit history: ${escapeHtml(error.message)}</p>
                                </div>
                            `;
                        });
                }
                
                // Load changelog when tab is first opened
                document.addEventListener('DOMContentLoaded', function() {
                    let changelogLoaded = false;
                    const originalSwitchTab = window.switchTab;
                    
                    if (typeof originalSwitchTab === 'function') {
                        window.switchTab = function(tabName, button) {
                            originalSwitchTab(tabName, button);
                            if (tabName === 'changelog' && !changelogLoaded) {
                                loadChangelog();
                                changelogLoaded = true;
                            }
                        };
                    }
                });
            </script>
        </div>
        
        <!-- About Tab -->
        <div id="about" class="tab-content">
            <h2>Purpose</h2>
            <p>
                This plugin adds background music audio playback to your existing FPP scheduler-controlled
                pre-show sequences. The music plays independently without interfering with FPP's playlist
                system. When ready, trigger a smooth transition to your main show with automatic fade-out
                and brightness control.
            </p>
            
            <h2>Features</h2>
            <ul>
                <li><strong>Independent Audio Playback:</strong> Background music runs separately from FPP playlists</li>
                <li><strong>Smooth Transitions:</strong> Professional fade-out with synchronized brightness dimming</li>
                <li><strong>MultiSync Support:</strong> Brightness fades synchronized across all controllers</li>
                <li><strong>Continuous Looping:</strong> Music never stops during pre-show</li>
                <li><strong>Shuffle Mode:</strong> Randomize track order for variety</li>
                <li><strong>PSA System:</strong> Play announcements with automatic volume ducking</li>
                <li><strong>Auto Return:</strong> Optionally return to pre-show after main show completes</li>
                <li><strong>Real-time Status:</strong> Track-level playback information and progress</li>
                <li><strong>REST API:</strong> Full API for automation and integration</li>
            </ul>
            
            <!-- About Section -->
            <div class="about-section">
                <h2><i class="fas fa-info-circle"></i> Plugin Information</h2>
                
                <!-- Dynamic Pixels Logo -->
                <div style="text-align: center; margin: 20px 0;">
                    <img src="<?php echo $logoBase64; ?>" 
                         alt="Dynamic Pixels Logo" 
                         style="max-width: 100%; height: auto; max-height: 120px;">
                </div>
                
                <div class="credits">
                    <p><strong>Plugin Developed By:</strong></p>
                    <p style="margin-left: 20px;">
                        Stuart Ledingham of <strong>Dynamic Pixels</strong>
                    </p>
                    
                    <p style="margin-top: 20px;"><strong>Resources:</strong></p>
                    <ul style="margin-left: 20px;">
                        <li><a href='https://github.com/OnlineDynamic/BackgroundMusicFPP-Plugin' target='_blank'>
                            <i class="fab fa-github"></i> Git Repository
                        </a></li>
                        <li><a href='https://github.com/OnlineDynamic/BackgroundMusicFPP-Plugin/issues' target='_blank'>
                            <i class="fas fa-bug"></i> Bug Reporter / Feature Requests
                        </a></li>
                    </ul>
                    
                    <p style="margin-top: 20px; font-size: 14px; color: #6c757d;">
                        This plugin enhances Falcon Player (FPP) by adding independent background music playback 
                        during pre-show sequences with smooth transitions to your main synchronized show.
                    </p>
                </div>
            </div>
        </div>
    </div>
    
    <script>
        function switchTab(tabName, element) {
            // Hide all tab contents
            var tabContents = document.getElementsByClassName('tab-content');
            for (var i = 0; i < tabContents.length; i++) {
                tabContents[i].classList.remove('active');
            }
            
            // Remove active class from all buttons
            var tabButtons = document.getElementsByClassName('tab-button');
            for (var i = 0; i < tabButtons.length; i++) {
                tabButtons[i].classList.remove('active');
            }
            
            // Show the selected tab
            document.getElementById(tabName).classList.add('active');
            
            // Mark the button as active
            if (element) {
                element.classList.add('active');
            }
        }
    </script>
</body>
</html>
