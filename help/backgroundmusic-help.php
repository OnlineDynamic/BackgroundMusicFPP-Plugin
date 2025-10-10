<!DOCTYPE html>
<html>
<head>
    <title>Background Music Plugin - Help & About</title>
    <link rel="stylesheet" href="/css/fpp.css" />
    <?php include_once(__DIR__ . '/../logo_base64.php'); ?>
    <style>
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
    </style>
</head>
<body>
    <div id="global" class="settings">
        <h1>Background Music Plugin - Help & About</h1>
        
        <div style="background-color: #fff3cd; border: 2px solid #ffc107; border-radius: 5px; padding: 15px; margin-bottom: 20px;">
            <h3 style="margin-top: 0; color: #856404;"><i class="fas fa-exclamation-triangle"></i> Required Plugin</h3>
            <p style="margin-bottom: 0;">
                This plugin requires the <strong>fpp-brightness</strong> plugin to be installed for brightness transitions to work properly.
                The brightness plugin provides smooth fading with automatic MultiSync support across all controllers.
            </p>
            <p style="margin-bottom: 0; margin-top: 10px;">
                <strong>Installation:</strong> Go to <em>Plugin Manager → Install Plugins</em> and search for "brightness", or visit 
                <a href="https://github.com/FalconChristmas/fpp-brightness" target="_blank">fpp-brightness on GitHub</a>
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
        
        <h2>Setup Steps</h2>
        <ol>
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
                </ul>
            </li>
            <li><strong>Create Main Show Playlist:</strong>
                <ul>
                    <li>Your full synchronized show playlist (can include sequences and audio)</li>
                </ul>
            </li>
            <li><strong>Configure Plugin:</strong>
                <ul>
                    <li>Go to Content Setup → Background Music Settings</li>
                    <li>Select your background music playlist (media-only)</li>
                    <li>Select your main show playlist</li>
                    <li>Set fade time (how long to fade out, 1-60 seconds)</li>
                    <li>Set blackout time (pause before show starts, 0-30 seconds)</li>
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
        
        <h2>How the Transition Works</h2>
        <p>When you click "Start Main Show", the following happens automatically:</p>
        <ol>
            <li>System captures current brightness level</li>
            <li>Brightness fades from current to 0 using the <strong>fpp-brightness plugin</strong> (supports MultiSync)</li>
            <li>Background music fades out simultaneously over configured fade time</li>
            <li>Background music player stops (independent process)</li>
            <li>All FPP playlists stop (including any running sequences)</li>
            <li>System waits during blackout period (creates dramatic pause)</li>
            <li>Brightness restores to original level via brightness plugin</li>
            <li>Main show playlist starts</li>
        </ol>
        
        <p><strong>MultiSync Note:</strong> If you have MultiSync enabled in FPP and the fpp-brightness plugin installed 
        on all controllers, brightness changes will automatically synchronize across all controllers during the transition.</p>
        
        <h2>Tips for Best Results</h2>
        <ul>
            <li><strong>Fade Time:</strong> 5 seconds provides a smooth, professional transition</li>
            <li><strong>Blackout Time:</strong> 2-3 seconds creates anticipation before the show</li>
            <li><strong>Background Animation:</strong> Use simple, looping sequences that aren't distracting</li>
            <li><strong>Background Music:</strong> Choose instrumental or ambient music that sets the mood</li>
            <li><strong>Test First:</strong> Always test your transition before the actual event</li>
        </ul>
        
        <h2>Features</h2>
        <h3>Continuous Looping</h3>
        <p>
            Background music automatically loops continuously - music never stops during pre-show.
            This works perfectly even with short playlists (1-2 tracks). No configuration needed,
            looping is always enabled.
        </p>
        
        <h3>Shuffle Mode</h3>
        <p>
            Enable "Shuffle Music Playlist" to randomize track order. The playlist is reshuffled
            each time it loops, providing variety and preventing listener fatigue. Perfect for
            long pre-show periods with limited music tracks.
        </p>
        
        <h2>Troubleshooting</h2>
        <h3>Playlists Not Showing</h3>
        <p>Make sure you've created the playlists in FPP first (Content Setup → Playlists).</p>
        
        <h3>Transition Not Smooth</h3>
        <p>Increase the fade time setting for a smoother transition.</p>
        
        <h3>Settings Not Saving</h3>
        <p>Check that FPP has write permissions to the config directory.</p>
        
        <h3>Check Logs</h3>
        <p>View logs at: <code>/home/fpp/media/logs/fpp-plugin-BackgroundMusic.log</code></p>
        
        <h2>Support</h2>
        <p>
            For issues or questions, please visit: 
            <a href="https://github.com/OnlineDynamic/BackgroundMusicFPP-Plugin/issues" target="_blank">
                GitHub Issues
            </a>
        </p>
        
        <div class="section-divider"></div>
        
        <!-- About Section -->
        <div class="about-section">
            <h2><i class="fas fa-info-circle"></i> About This Plugin</h2>
            
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
        
        <div style="margin-top: 30px;">
            <a href="/plugin.php?_menu=status&plugin=fpp-plugin-BackgroundMusic&page=backgroundmusic.php" class="btn btn-primary">
                <i class="fas fa-arrow-left"></i> Back to Controller
            </a>
            <a href="/plugin.php?_menu=content&plugin=fpp-plugin-BackgroundMusic&page=content.php" class="btn btn-outline-secondary">
                <i class="fas fa-cog"></i> Settings
            </a>
        </div>
    </div>
</body>
</html>
