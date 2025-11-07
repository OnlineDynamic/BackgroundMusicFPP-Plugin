<style>
    .controlPanelGrid {
        display: grid;
        grid-template-columns: repeat(3, 1fr);
        gap: 20px;
        margin: 20px auto;
        max-width: 1200px;
    }
    
    @media (max-width: 1024px) {
        .controlPanelGrid {
            grid-template-columns: 1fr;
        }
    }
    
    .controlColumn {
        background-color: #f5f5f5;
        border-radius: 8px;
        padding: 20px;
        text-align: center;
        border: 2px solid #e0e0e0;
    }
    
    .controlColumn h2 {
        margin-top: 0;
        padding-bottom: 10px;
        border-bottom: 2px solid;
    }
    
    .controlColumn.background h2 {
        border-color: #4CAF50;
        color: #4CAF50;
    }
    
    .controlColumn.psa h2 {
        border-color: #e91e63;
        color: #e91e63;
    }
    
    .controlColumn.show h2 {
        border-color: #2196F3;
        color: #2196F3;
    }
    
    .controlButton {
        margin: 10px 0;
        padding: 15px 30px;
        font-size: 16px;
        width: 100%;
        max-width: 300px;
    }
    
    .psaButton {
        margin: 8px 0;
        padding: 12px 20px;
        font-size: 14px;
        width: 100%;
        max-width: 300px;
        background-color: #e91e63;
        color: white;
        border: none;
        border-radius: 4px;
        cursor: pointer;
        transition: background-color 0.3s;
    }
    
    .psaButton:hover:not(:disabled) {
        background-color: #c2185b;
    }
    
    .psaButton:disabled {
        background-color: #ccc;
        cursor: not-allowed;
        opacity: 0.6;
    }
    
    .psaButton.playing {
        background-color: #ff9800;
        animation: pulse 1.5s infinite;
    }
    
    @keyframes pulse {
        0%, 100% { opacity: 1; }
        50% { opacity: 0.7; }
    }
    
    .psa-status-active {
        animation: psa-flash 2s infinite;
    }
    
    @keyframes psa-flash {
        0%, 100% { 
            color: #e91e63;
        }
        50% { 
            color: #ff4081;
        }
    }
    
    .statusPanel {
        margin: 20px auto;
        max-width: 1200px;
        padding: 20px;
        background-color: #f5f5f5;
        border-radius: 5px;
    }
    .statusItem {
        margin: 10px 0;
        font-size: 16px;
        display: flex;
        align-items: flex-start;
        gap: 10px;
    }
    .statusLabel {
        font-weight: bold;
        display: inline-block;
        width: 200px;
        flex-shrink: 0;
    }
    
    .hidden {
        display: none !important;
    }
    
    /* PSA Progress Bar Styling */
    #psaStatusContainer .progress {
        border-radius: 4px;
        overflow: hidden;
    }
    #psaProgressBar {
        background: linear-gradient(90deg, #17a2b8 0%, #138496 100%);
        display: flex;
        align-items: center;
        justify-content: center;
        min-width: 60px;
    }
    #psaProgressText {
        color: white;
        text-shadow: 0 0 3px rgba(0,0,0,0.8);
        white-space: nowrap;
    }
    
    .btn-start {
        background-color: #4CAF50;
        color: white;
    }
    .btn-stop {
        background-color: #f44336;
        color: white;
    }
    .btn-show {
        background-color: #2196F3;
        color: white;
    }
    .loading {
        opacity: 0.6;
        pointer-events: none;
    }
    
    /* Player control button tooltips - position below */
    .player-control-btn {
        position: relative;
    }
    
    .custom-tooltip {
        position: absolute;
        bottom: -40px;
        left: 50%;
        transform: translateX(-50%);
        background-color: rgba(0, 0, 0, 0.9);
        color: white;
        padding: 8px 12px;
        border-radius: 4px;
        font-size: 12px;
        white-space: nowrap;
        z-index: 10000;
        pointer-events: none;
        opacity: 0;
        transition: opacity 0.2s;
    }
    
    .custom-tooltip.show {
        opacity: 1;
    }
    
    .custom-tooltip::before {
        content: '';
        position: absolute;
        top: -6px;
        left: 50%;
        transform: translateX(-50%);
        border-width: 0 6px 6px 6px;
        border-style: solid;
        border-color: transparent transparent rgba(0, 0, 0, 0.9) transparent;
    }
    
    /* Collapsible sections */
    .collapsible-section {
        display: block;
        overflow: hidden;
        transition: max-height 0.3s ease-out;
    }
    
    .statusPanel h2 {
        transition: background-color 0.2s;
    }
    
    .statusPanel h2:hover {
        background-color: rgba(0, 0, 0, 0.05);
        border-radius: 4px;
        padding: 5px;
        margin: -5px;
    }
</style>

<div id="global" class="settings">
    <!-- Update Notification Banner -->
    <div id="updateNotification" style="display: none; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; border-radius: 8px; padding: 15px 20px; margin: 20px auto; max-width: 1200px; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
        <div style="display: flex; justify-content: space-between; align-items: center;">
            <div style="flex: 1;">
                <h3 style="margin: 0 0 5px 0; color: white;"><i class="fas fa-cloud-download-alt"></i> Update Available!</h3>
                <p style="margin: 0; font-size: 14px; opacity: 0.9;" id="updateDetails">A new version is available</p>
            </div>
            <div>
                <button onclick="dismissUpdateNotification()" class="btn btn-sm" style="background-color: rgba(255,255,255,0.2); color: white; border: 1px solid rgba(255,255,255,0.3); margin-right: 10px;">
                    Dismiss
                </button>
                <a href="/plugins.php" class="btn btn-sm" style="background-color: white; color: #667eea; border: none; font-weight: bold;">
                    <i class="fas fa-download"></i> Update Plugin
                </a>
            </div>
        </div>
    </div>
    
    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px;">
        <h1 style="margin: 0;">Background Music Controller</h1>
        <div>
            <a href="plugin.php?_menu=content&plugin=fpp-plugin-BackgroundMusic&page=content.php" class="btn btn-outline-secondary" style="margin-right: 5px;">
                <i class="fas fa-cog"></i> Settings
            </a>
            <a href="plugin.php?plugin=fpp-plugin-BackgroundMusic&page=help%2Fbackgroundmusic-help.php" class="btn btn-outline-info">
                <i class="fas fa-question-circle"></i> Help
            </a>
        </div>
    </div>
    
    <!-- Brightness Plugin Warning -->
    <div id="brightnessPluginWarning" style="display: none; background-color: #fff3cd; border: 2px solid #ffc107; border-radius: 5px; padding: 15px; margin: 20px auto; max-width: 1200px;">
        <h3 style="margin-top: 0; color: #856404;"><i class="fas fa-exclamation-triangle"></i> Required Plugin Missing</h3>
        <p style="margin-bottom: 10px;">
            The <strong>fpp-brightness</strong> plugin is not installed. This plugin is required for brightness transitions with MultiSync support.
        </p>
        <p style="margin-bottom: 0;">
            <strong>Install on ALL controllers:</strong> Go to <em>Plugin Manager → Install Plugins</em> and search for "brightness"
        </p>
    </div>
    
    <!-- 3-Column Control Panel -->
    <div class="controlPanelGrid">
        <!-- Background Music Column -->
        <div class="controlColumn background">
            <h2><i class="fas fa-music"></i> Background Music</h2>
            <div>
                <button id="btnStartBackground" class="controlButton btn-start" onclick="startBackground()">
                    <i class="fas fa-play"></i> Start Background Music
                </button>
            </div>
            <div>
                <button id="btnStopBackground" class="controlButton btn-stop" onclick="stopBackground()">
                    <i class="fas fa-stop"></i> Stop Background Music
                </button>
            </div>
        </div>
        
        <!-- PSA Column -->
        <div class="controlColumn psa">
            <h2><i class="fas fa-bullhorn"></i> Public Service Announcements</h2>
            <div id="psaButtonsContainer">
                <!-- PSA buttons will be dynamically generated -->
                <p style="color: #999; font-size: 14px; margin: 20px 0;">
                    <i class="fas fa-info-circle"></i> Configure PSA buttons in settings
                </p>
            </div>
        </div>
        
        <!-- Main Show Column -->
        <div class="controlColumn show">
            <h2><i class="fas fa-star"></i> Main Show</h2>
            <div>
                <button id="btnStartShow" class="controlButton btn-show" onclick="startShow()">
                    <i class="fas fa-rocket"></i> Start Main Show
                </button>
            </div>
        </div>
    </div>

        <!-- Current Status Panel -->
        <div class="statusPanel">
            <h2><i class="fas fa-info-circle"></i> Current Status</h2>
            <div class="statusItem">
                <span class="statusLabel">Background Music:</span>
                <span id="statusBackgroundMusic">Not Running</span>
            </div>
            <div class="statusItem" id="currentTrackContainer" style="display: none;">
                <span class="statusLabel">Current Track:</span>
                <span id="statusCurrentTrack" style="font-weight: bold; color: #007bff;">-</span>
            </div>
            <div class="statusItem" id="trackProgressContainer" style="display: none;">
                <span class="statusLabel">Progress:</span>
                <div style="display: inline-block; width: 60%; vertical-align: middle;">
                    <div style="background-color: #e9ecef; border-radius: 4px; height: 20px; position: relative; overflow: hidden;">
                        <div id="statusTrackProgressBar" style="background-color: #007bff; height: 100%; width: 0%; transition: width 0.3s;"></div>
                        <span id="trackProgressText" style="position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); font-size: 12px; font-weight: bold; color: #000;">0%</span>
                    </div>
                </div>
                <span id="trackTimeDisplay" style="margin-left: 10px; font-size: 12px; color: #6c757d;">0:00 / 0:00</span>
            </div>
            <div class="statusItem">
                <span class="statusLabel">Main Show:</span>
                <span id="statusShow">Not Running</span>
            </div>
            <div class="statusItem" id="psaStatusContainer" style="display: none;">
                <span class="statusLabel">PSA Announcement:</span>
                <div style="display: flex; flex-direction: column; gap: 5px; flex: 1;">
                    <span id="statusPSA" class="psa-status-active" style="font-weight: bold; color: #e91e63;">
                        <i class="fas fa-bullhorn"></i> Playing...
                    </span>
                    <div class="progress" style="height: 20px; margin: 0; background-color: #2a2a2a; border: 1px solid #444;">
                        <div id="psaProgressBar" class="progress-bar bg-info" role="progressbar" 
                             style="width: 0%; transition: width 0.5s ease;" 
                             aria-valuenow="0" aria-valuemin="0" aria-valuemax="100">
                            <span id="psaProgressText" style="font-size: 11px; font-weight: bold;">0:00 / 0:00</span>
                        </div>
                    </div>
                </div>
            </div>
            <div class="statusItem">
                <span class="statusLabel">Current FPP Playlist:</span>
                <span id="statusCurrentPlaylist" style="font-weight: bold;">-</span>
            </div>
            <div class="statusItem">
                <span class="statusLabel">Current Brightness:</span>
                <span id="statusBrightness">-</span>
            </div>
            <div class="statusItem">
                <span class="statusLabel" style="font-style: italic;">Note:</span>
                <span style="font-size: 14px;">Pre-show sequence controlled by FPP scheduler</span>
            </div>
        </div>

        <!-- Volume Control Panel -->
        <div class="statusPanel">
            <h2 style="cursor: pointer; user-select: none;" onclick="toggleSection('volumeControl')" data-tooltip="Click to expand/collapse">
                <i class="fas fa-volume-up"></i> Volume Control 
                <i id="volumeControlIcon" class="fas fa-chevron-down" style="float: right; font-size: 14px; transition: transform 0.3s;"></i>
            </h2>
            <div id="volumeControl" class="collapsible-section">
            <div class="statusItem">
                <span class="statusLabel">Current Volume:</span>
                <span id="statusVolume" style="font-weight: bold; font-size: 18px; color: #007bff;">70%</span>
            </div>
            <div class="statusItem">
                <div style="display: flex; align-items: center; gap: 15px; margin-top: 10px;">
                    <span style="font-size: 24px; cursor: pointer;" onclick="decreaseVolume()" title="Decrease volume">🔈</span>
                    <input type="range" id="volumeSlider" min="0" max="100" value="70" 
                           style="flex: 1; height: 8px; cursor: pointer;" 
                           oninput="updateVolumeDisplay(this.value)" 
                           onchange="setVolume(this.value)">
                    <span style="font-size: 24px; cursor: pointer;" onclick="increaseVolume()" title="Increase volume">🔊</span>
                </div>
                <div style="text-align: center; margin-top: 8px; font-size: 12px; color: #6c757d;">
                    <span>Adjust FPP system volume (affects all audio output)</span>
                </div>
            </div>
            </div>
        </div>

        <!-- Background Music Playlist Details Panel -->
        <div class="statusPanel" id="playlistDetailsPanel">
            <h2 style="cursor: pointer; user-select: none;" onclick="toggleSection('playlistDetails')" data-tooltip="Click to expand/collapse">
                <i class="fas fa-music"></i> Background Music Playlist
                <i id="playlistDetailsIcon" class="fas fa-chevron-down" style="float: right; font-size: 14px; transition: transform 0.3s;"></i>
            </h2>
            <div id="playlistDetails" class="collapsible-section">
            <div class="statusItem">
                <span class="statusLabel">Playlist:</span>
                <span id="playlistName" style="font-weight: bold; color: #007bff;">-</span>
            </div>
            <div class="statusItem">
                <span class="statusLabel">Total Tracks:</span>
                <span id="playlistTrackCount" style="font-weight: bold;">-</span>
            </div>
            <div class="statusItem">
                <span class="statusLabel">Total Duration:</span>
                <span id="playlistTotalDuration" style="font-weight: bold;">-</span>
            </div>
            
            <!-- Player Controls -->
            <div id="playerControls" style="display: none; margin: 15px 0; text-align: center; background-color: #f8f9fa; padding: 15px; border-radius: 8px; border: 1px solid #dee2e6;">
                <div style="margin-bottom: 10px;">
                    <strong>Now Playing:</strong> <span id="nowPlayingTrack" style="color: #007bff;">-</span>
                </div>
                <div style="margin-bottom: 10px;">
                    <span id="trackTime" style="font-family: monospace; font-size: 14px;">0:00 / 0:00</span>
                </div>
                <div style="margin-bottom: 15px;">
                    <div style="width: 100%; height: 6px; background-color: #e0e0e0; border-radius: 3px; overflow: hidden;">
                        <div id="trackProgressBar" style="width: 0%; height: 100%; background-color: #4CAF50; transition: width 0.3s;"></div>
                    </div>
                </div>
                <div style="display: flex; justify-content: center; gap: 10px; flex-wrap: wrap;">
                    <button class="btn btn-secondary player-control-btn" onclick="previousTrack()" data-tooltip="Previous Track" style="padding: 8px 15px;">
                        <i class="fas fa-step-backward"></i> Previous
                    </button>
                    <button id="btnPauseResume" class="btn btn-warning player-control-btn" onclick="togglePauseResume()" data-tooltip="Pause/Resume" style="padding: 8px 20px;">
                        <i class="fas fa-pause"></i> <span id="pauseResumeText">Pause</span>
                    </button>
                    <button class="btn btn-secondary player-control-btn" onclick="nextTrack()" data-tooltip="Next Track" style="padding: 8px 15px;">
                        <i class="fas fa-step-forward"></i> Next
                    </button>
                </div>
            </div>
            <div style="margin-top: 15px; padding: 8px; background-color: #e3f2fd; border-radius: 4px; font-size: 13px;">
                <i class="fas fa-info-circle"></i> <strong>Tip:</strong> Drag and drop tracks to reorder, or click a track to jump to it
            </div>
            <div style="margin-top: 10px; max-height: 400px; overflow-y: auto; border: 1px solid #e0e0e0; border-radius: 4px; padding-right: 5px;">
                <table id="playlistTable" style="width: 100%; border-collapse: collapse; font-size: 14px;">
                    <thead style="position: sticky; top: 0; background-color: #f8f9fa; border-bottom: 2px solid #dee2e6;">
                        <tr>
                            <th style="padding: 8px; text-align: center; width: 30px;"><i class="fas fa-grip-vertical"></i></th>
                            <th style="padding: 8px; text-align: left; width: 40px;">#</th>
                            <th style="padding: 8px; text-align: left;">Track Name</th>
                            <th style="padding: 8px 15px 8px 8px; text-align: right; width: 80px;">Duration</th>
                        </tr>
                    </thead>
                    <tbody id="playlistTracksTable">
                        <tr>
                            <td colspan="3" style="padding: 20px; text-align: center; color: #6c757d;">
                                <i class="fas fa-spinner fa-spin"></i> Loading playlist...
                            </td>
                        </tr>
                    </tbody>
                </table>
            </div>
            </div>
        </div>

        <!-- Configuration Summary Panel -->
        <div class="statusPanel">
            <h2 style="cursor: pointer; user-select: none;" onclick="toggleSection('configSummary')" data-tooltip="Click to expand/collapse">
                <i class="fas fa-cog"></i> Configuration Summary
                <i id="configSummaryIcon" class="fas fa-chevron-down" style="float: right; font-size: 14px; transition: transform 0.3s;"></i>
            </h2>
            <div id="configSummary" class="collapsible-section">
            
            <!-- Playlists -->
            <h4 style="color: #2196F3; margin-top: 15px; margin-bottom: 10px; border-bottom: 1px solid #e0e0e0; padding-bottom: 5px;">
                <i class="fas fa-list"></i> Background Music Source
            </h4>
            <div class="statusItem">
                <span class="statusLabel">Source Type:</span>
                <span id="configBackgroundMusicSource">-</span>
            </div>
            <div class="statusItem" id="configBackgroundMusicPlaylistRow">
                <span class="statusLabel">Background Music Playlist:</span>
                <span id="configBackgroundMusic">-</span>
            </div>
            <div class="statusItem hidden" id="configBackgroundMusicStreamRow">
                <span class="statusLabel">Stream URL:</span>
                <span id="configBackgroundMusicStream">-</span>
            </div>
            <div class="statusItem">
                <span class="statusLabel">Show Playlist:</span>
                <span id="configShowPlaylist">-</span>
            </div>
            <div class="statusItem" id="configShuffleMusicRow">
                <span class="statusLabel">Shuffle Music:</span>
                <span id="configShuffleMusic">-</span>
            </div>

            <!-- Volume Settings -->
            <h4 style="color: #4CAF50; margin-top: 20px; margin-bottom: 10px; border-bottom: 1px solid #e0e0e0; padding-bottom: 5px;">
                <i class="fas fa-volume-up"></i> Volume Settings
            </h4>
            <div class="statusItem">
                <span class="statusLabel">Background Music Volume:</span>
                <span id="configBackgroundMusicVolume">-</span>%
            </div>
            <div class="statusItem">
                <span class="statusLabel">Show Playlist Volume:</span>
                <span id="configShowPlaylistVolume">-</span>%
            </div>
            <div class="statusItem">
                <span class="statusLabel">Post-Show Background Volume:</span>
                <span id="configPostShowBackgroundVolume">-</span>%
            </div>

            <!-- Transition Settings -->
            <h4 style="color: #FF9800; margin-top: 20px; margin-bottom: 10px; border-bottom: 1px solid #e0e0e0; padding-bottom: 5px;">
                <i class="fas fa-adjust"></i> Show Transition
            </h4>
            <div class="statusItem">
                <span class="statusLabel">Fade Time:</span>
                <span id="configFadeTime">-</span> seconds
            </div>
            <div class="statusItem">
                <span class="statusLabel">Blackout Time:</span>
                <span id="configBlackoutTime">-</span> seconds
            </div>

            <!-- Post-Show Settings -->
            <h4 style="color: #9C27B0; margin-top: 20px; margin-bottom: 10px; border-bottom: 1px solid #e0e0e0; padding-bottom: 5px;">
                <i class="fas fa-redo"></i> Post-Show Settings
            </h4>
            <div class="statusItem">
                <span class="statusLabel">Return to Pre-Show:</span>
                <span id="configReturnToPreShow">-</span>
            </div>
            <div class="statusItem">
                <span class="statusLabel">Resume Playlist:</span>
                <span id="configResumeMode">-</span>
            </div>
            <div class="statusItem">
                <span class="statusLabel">Post-Show Delay:</span>
                <span id="configPostShowDelay">-</span> seconds
            </div>

            <div style="margin-top: 15px;">
                <a href="plugin.php?_menu=content&plugin=fpp-plugin-BackgroundMusic&page=content.php" class="btn btn-outline-primary">
                    <i class="fas fa-cog"></i> Configure Settings
                </a>
            </div>
            </div>
        </div>
    </div>

    <script>
        // Collapsible section toggle function
        function toggleSection(sectionId) {
            var section = document.getElementById(sectionId);
            var icon = document.getElementById(sectionId + 'Icon');
            
            if (section.style.display === 'none') {
                section.style.display = 'block';
                icon.style.transform = 'rotate(0deg)';
                localStorage.setItem('section_' + sectionId, 'expanded');
            } else {
                section.style.display = 'none';
                icon.style.transform = 'rotate(-90deg)';
                localStorage.setItem('section_' + sectionId, 'collapsed');
            }
        }
        
        // Initialize section states from localStorage on page load
        document.addEventListener('DOMContentLoaded', function() {
            ['volumeControl', 'playlistDetails', 'configSummary'].forEach(function(sectionId) {
                var state = localStorage.getItem('section_' + sectionId);
                if (state === 'collapsed') {
                    var section = document.getElementById(sectionId);
                    var icon = document.getElementById(sectionId + 'Icon');
                    if (section && icon) {
                        section.style.display = 'none';
                        icon.style.transform = 'rotate(-90deg)';
                    }
                }
            });
        });
        
        // Helper function to format seconds as MM:SS
        function formatTime(seconds) {
            var mins = Math.floor(seconds / 60);
            var secs = seconds % 60;
            return mins + ':' + (secs < 10 ? '0' : '') + secs;
        }
        
        function updateVolumeDisplay(volume) {
            $('#statusVolume').text(volume + '%');
        }
        
        function decreaseVolume() {
            var currentVolume = parseInt($('#volumeSlider').val());
            var newVolume = Math.max(0, currentVolume - 5);
            $('#volumeSlider').val(newVolume);
            updateVolumeDisplay(newVolume);
            setVolume(newVolume);
        }
        
        function increaseVolume() {
            var currentVolume = parseInt($('#volumeSlider').val());
            var newVolume = Math.min(100, currentVolume + 5);
            $('#volumeSlider').val(newVolume);
            updateVolumeDisplay(newVolume);
            setVolume(newVolume);
        }
        
        function setVolume(volume) {
            // Use FPP's native volume API to keep UI in sync
            // Using the same approach as FPP's SetVolume function
            var obj = { volume: parseInt(volume) };
            $.post({
                url: '/api/system/volume',
                data: JSON.stringify(obj),
                contentType: 'application/json'
            })
            .done(function(data) {
                $.jGrowl('Volume set to ' + volume + '%', {themeState: 'success', life: 1000});
                // Update the display immediately
                $('#statusVolume').text(volume + '%');
            })
            .fail(function() {
                $.jGrowl('Failed to set volume', {themeState: 'error'});
            });
        }
        
        function updateStatus() {
            $.ajax({
                url: '/api/plugin/fpp-plugin-BackgroundMusic/status',
                type: 'GET',
                dataType: 'json',
                success: function(data) {
                    $('#statusBackgroundMusic').text(data.backgroundMusicRunning ? 'Running' : 'Not Running');
                    $('#statusShow').text(data.showRunning ? 'Running' : 'Not Running');
                    $('#statusBrightness').text(data.brightness + '%');
                    
                    // Show current track information (only for playlist mode)
                    var bgSource = data.config.backgroundMusicSource || 'playlist';
                    if (bgSource === 'playlist' && data.backgroundMusicRunning && data.currentTrack) {
                        $('#currentTrackContainer').show();
                        $('#trackProgressContainer').show();
                        $('#statusCurrentTrack').text(data.currentTrack);
                        
                        // Update progress bar in Current Status section
                        var progress = data.trackProgress || 0;
                        $('#statusTrackProgressBar').css('width', progress + '%');
                        $('#trackProgressText').text(progress + '%');
                        
                        // Update time display
                        var elapsed = data.trackElapsed || 0;
                        var duration = data.trackDuration || 0;
                        $('#trackTimeDisplay').text(formatTime(elapsed) + ' / ' + formatTime(duration));
                    } else {
                        $('#currentTrackContainer').hide();
                        $('#trackProgressContainer').hide();
                    }
                    
                    // Show current FPP playlist (sequence running via scheduler)
                    var currentPlaylist = data.currentPlaylist || '';
                    var fppStatus = data.fppStatus || 'unknown';
                    
                    if (currentPlaylist) {
                        var statusText = currentPlaylist;
                        var statusColor = '#28a745'; // green
                        
                        // Add status indicator
                        if (fppStatus === 'playing') {
                            statusText += ' ▶';
                        } else if (fppStatus === 'paused') {
                            statusText += ' ⏸';
                            statusColor = '#ffc107'; // yellow
                        }
                        
                        $('#statusCurrentPlaylist').text(statusText).css('color', statusColor);
                    } else {
                        var idleText = 'None';
                        if (fppStatus === 'idle') {
                            idleText += ' (Idle)';
                        }
                        $('#statusCurrentPlaylist').text(idleText).css('color', '#6c757d');
                    }
                    
                    // Display background music source information
                    var bgSource = data.config.backgroundMusicSource || 'playlist';
                    $('#configBackgroundMusicSource').text(bgSource === 'stream' ? 'Internet Stream' : 'FPP Playlist');
                    
                    if (bgSource === 'stream') {
                        $('#configBackgroundMusicPlaylistRow').addClass('hidden');
                        $('#configBackgroundMusicStreamRow').removeClass('hidden');
                        $('#configShuffleMusicRow').addClass('hidden');
                        $('#playlistDetailsPanel').addClass('hidden');
                        $('#configBackgroundMusicStream').text(data.config.backgroundMusicStreamURL || 'Not Set');
                    } else {
                        $('#configBackgroundMusicPlaylistRow').removeClass('hidden');
                        $('#configBackgroundMusicStreamRow').addClass('hidden');
                        $('#configShuffleMusicRow').removeClass('hidden');
                        $('#playlistDetailsPanel').removeClass('hidden');
                        $('#configBackgroundMusic').text(data.config.backgroundMusicPlaylist || 'Not Set');
                        $('#configShuffleMusic').text(data.config.shuffleMusic == '1' ? 'Yes' : 'No');
                    }
                    
                    $('#configShowPlaylist').text(data.config.showPlaylist || 'Not Set');
                    
                    $('#configBackgroundMusicVolume').text(data.config.backgroundMusicVolume || data.config.volumeLevel || '70');
                    $('#configShowPlaylistVolume').text(data.config.showPlaylistVolume || '100');
                    $('#configPostShowBackgroundVolume').text(data.config.postShowBackgroundVolume || data.config.backgroundMusicVolume || data.config.volumeLevel || '70');
                    
                    $('#configFadeTime').text(data.config.fadeTime || '5');
                    $('#configBlackoutTime').text(data.config.blackoutTime || '2');
                    
                    $('#configReturnToPreShow').text(data.config.returnToPreShow == '1' ? 'Yes' : 'No');
                    var resumeMode = data.config.resumeMode || 'continue';
                    $('#configResumeMode').text(resumeMode == 'continue' ? 'Continue from Next Track' : 'Restart from Beginning');
                    $('#configPostShowDelay').text(data.config.postShowDelay || '0');
                    
                    updateButtonStates(data);
                    
                    // Generate PSA buttons from config
                    generatePSAButtons(data.config);
                    
                    // Show warning if brightness plugin is not installed
                    if (data.brightnessPluginInstalled === false) {
                        $('#brightnessPluginWarning').show();
                    } else {
                        $('#brightnessPluginWarning').hide();
                    }
                    
                    // Update playlist details with current track info
                    var currentTrack = data.currentTrack || '';
                    updatePlaylistDetails(currentTrack);
                    
                    // Update player controls
                    if (data.backgroundMusicRunning) {
                        $('#playerControls').show();
                        $('#nowPlayingTrack').text(currentTrack || '-');
                        
                        // Update progress bar
                        var progress = data.trackProgress || 0;
                        $('#trackProgressBar').css('width', progress + '%');
                        
                        // Update time display
                        var elapsed = data.trackElapsed || 0;
                        var duration = data.trackDuration || 0;
                        $('#trackTime').text(formatTime(elapsed) + ' / ' + formatTime(duration));
                        
                        // Update pause/resume button
                        if (data.playbackState === 'paused') {
                            $('#btnPauseResume').removeClass('btn-warning').addClass('btn-success');
                            $('#btnPauseResume i').removeClass('fa-pause').addClass('fa-play');
                            $('#pauseResumeText').text('Resume');
                        } else {
                            $('#btnPauseResume').removeClass('btn-success').addClass('btn-warning');
                            $('#btnPauseResume i').removeClass('fa-play').addClass('fa-pause');
                            $('#pauseResumeText').text('Pause');
                        }
                    } else {
                        $('#playerControls').hide();
                    }
                    
                    // Check PSA status
                    updatePSAStatus();
                },
                error: function() {
                    $('#statusBackgroundMusic').text('Error getting status');
                }
            });
            
            // Get FPP's system volume separately
            $.ajax({
                url: '/api/fppd/volume',
                type: 'GET',
                dataType: 'json',
                success: function(data) {
                    if (data.volume !== undefined) {
                        $('#volumeSlider').val(data.volume);
                        $('#statusVolume').text(data.volume + '%');
                    }
                }
            });
        }
        
        function updatePlaylistDetails(currentTrack, forceRefresh) {
            // Don't update if user is dragging
            if (isDragging) {
                return;
            }
            
            // Store current track globally
            lastCurrentTrack = currentTrack;
            
            // Throttle playlist updates to once every 10 seconds unless forced
            var now = Date.now();
            if (!forceRefresh && lastPlaylistData && (now - lastPlaylistUpdate) < 10000) {
                // Just update the playing indicator without fetching new data
                // Only update if track changed or hasn't been updated yet
                updatePlayingIndicator(currentTrack);
                return;
            }
            
            $.ajax({
                url: '/api/plugin/fpp-plugin-BackgroundMusic/playlist-details',
                type: 'GET',
                dataType: 'json',
                success: function(data) {
                    if (data.status === 'OK' && data.tracks && data.tracks.length > 0) {
                        $('#playlistName').text(data.playlistName);
                        $('#playlistTrackCount').text(data.totalTracks + ' tracks');
                        $('#playlistTotalDuration').text('Total: ' + data.totalDurationFormatted);
                        
                        // Store tracks globally for reordering
                        window.playlistTracks = data.tracks;
                        lastPlaylistData = data;
                        lastPlaylistUpdate = now;
                        
                        // Build table rows
                        var rows = '';
                        for (var i = 0; i < data.tracks.length; i++) {
                            var track = data.tracks[i];
                            var isPlaying = currentTrack && track.name === currentTrack;
                            var rowStyle = '';
                            var iconHtml = '';
                            
                            if (isPlaying) {
                                rowStyle = ' style="cursor: pointer; background-color: #e3f2fd; font-weight: bold; border-left: 3px solid #2196F3;"';
                                iconHtml = ' <i class="fas fa-play" style="color: #2196F3; margin-left: 5px;"></i>';
                            } else {
                                rowStyle = ' style="cursor: pointer;"';
                            }
                            
                            rows += '<tr data-track-index="' + i + '" data-track-number="' + track.number + '" data-track-name="' + track.name + '"' + rowStyle + '>';
                            rows += '<td style="text-align: center; padding: 8px; cursor: grab;"><i class="fas fa-grip-vertical" style="color: #999;"></i></td>';
                            rows += '<td style="text-align: center; padding: 8px;">' + track.number + '</td>';
                            rows += '<td style="padding: 8px;">' + escapeHtml(track.name) + iconHtml + '</td>';
                            rows += '<td style="text-align: right; padding: 8px 15px 8px 8px;">' + track.durationFormatted + '</td>';
                            rows += '</tr>';
                        }
                        $('#playlistTracksTable').html(rows);
                        
                        // Initialize sortable if not already done
                        if (!$('#playlistTracksTable').hasClass('ui-sortable')) {
                            initPlaylistSortable();
                        }
                        
                        // Add click handlers for jumping to track
                        $('#playlistTracksTable tr').click(function(e) {
                            // Don't trigger if clicking on the drag handle
                            if ($(e.target).hasClass('fa-grip-vertical') || $(e.target).closest('td').find('.fa-grip-vertical').length > 0) {
                                return;
                            }
                            var trackNumber = $(this).data('track-number');
                            if (trackNumber) {
                                jumpToTrack(trackNumber);
                            }
                        });
                    } else {
                        // No playlist or error
                        var message = data.message || 'No playlist configured';
                        $('#playlistName').text('-');
                        $('#playlistTrackCount').text('-');
                        $('#playlistTotalDuration').text('-');
                        $('#playlistTracksTable').html('<tr><td colspan="4" style="text-align: center; color: #999;">' + message + '</td></tr>');
                        lastPlaylistData = null;
                    }
                },
                error: function() {
                    $('#playlistTracksTable').html('<tr><td colspan="4" style="text-align: center; color: #999;">Error loading playlist</td></tr>');
                }
            });
        }
        
        function updatePlayingIndicator(currentTrack) {
            // Lightweight update - just change the playing indicator without rebuilding the table
            var $rows = $('#playlistTracksTable tr');
            
            // If no rows, nothing to update
            if ($rows.length === 0) {
                return;
            }
            
            $rows.each(function() {
                var $row = $(this);
                var trackName = $row.data('track-name');
                var $nameCell = $row.find('td:eq(2)'); // Column 0=grip, 1=number, 2=name, 3=duration
                var isPlaying = currentTrack && trackName === currentTrack;
                var rowStyle = $row.attr('style') || '';
                var hasHighlight = rowStyle.indexOf('background-color: #e3f2fd') >= 0 || rowStyle.indexOf('background-color:#e3f2fd') >= 0;
                
                if (isPlaying && !hasHighlight) {
                    // Add highlight
                    $row.css({
                        'background-color': '#e3f2fd',
                        'font-weight': 'bold',
                        'border-left': '3px solid #2196F3'
                    });
                    // Add play icon if not present
                    if ($nameCell.find('.fa-play').length === 0) {
                        var currentText = $nameCell.clone().children().remove().end().text().trim();
                        $nameCell.html(escapeHtml(currentText) + ' <i class="fas fa-play" style="color: #2196F3; margin-left: 5px;"></i>');
                    }
                } else if (!isPlaying && hasHighlight) {
                    // Remove highlight
                    $row.css({
                        'background-color': '',
                        'font-weight': '',
                        'border-left': ''
                    });
                    // Remove play icon
                    if ($nameCell.find('.fa-play').length > 0) {
                        var currentText = $nameCell.clone().children().remove().end().text().trim();
                        $nameCell.html(escapeHtml(currentText));
                    }
                }
                // If already correct state, do nothing (prevents flashing)
            });
        }
        
        function updatePSAStatus() {
            $.ajax({
                url: '/api/plugin/fpp-plugin-BackgroundMusic/psa-status',
                type: 'GET',
                dataType: 'json',
                success: function(data) {
                    if (data.status === 'OK' && data.playing) {
                        var statusText = '<i class="fas fa-bullhorn"></i> Playing';
                        if (data.buttonLabel) {
                            statusText += ': ' + escapeHtml(data.buttonLabel);
                        }
                        $('#statusPSA').html(statusText);
                        
                        // Update progress bar
                        var progress = data.progress || 0;
                        var elapsed = data.elapsed || 0;
                        var duration = data.duration || 0;
                        
                        $('#psaProgressBar').css('width', progress + '%');
                        $('#psaProgressBar').attr('aria-valuenow', progress);
                        
                        // Format time as mm:ss
                        var elapsedStr = formatTime(elapsed);
                        var durationStr = formatTime(duration);
                        $('#psaProgressText').text(elapsedStr + ' / ' + durationStr);
                        
                        $('#psaStatusContainer').show();
                    } else {
                        $('#psaStatusContainer').hide();
                    }
                },
                error: function() {
                    $('#psaStatusContainer').hide();
                }
            });
        }
        
        function escapeHtml(text) {
            var map = {
                '&': '&amp;',
                '<': '&lt;',
                '>': '&gt;',
                '"': '&quot;',
                "'": '&#039;'
            };
            return text.replace(/[&<>"']/g, function(m) { return map[m]; });
        }
        
        function updateButtonStates(status) {
            // Check if show playlist is configured
            var hasShowPlaylist = status.config && status.config.showPlaylist && status.config.showPlaylist.trim() !== '';
            
            if (status.backgroundMusicRunning) {
                $('#btnStartBackground').prop('disabled', true).css('opacity', '0.5')
                    .attr('title', 'Background music is already running');
                $('#btnStopBackground').prop('disabled', false);
                
                // Enable start show only if playlist is configured
                if (hasShowPlaylist) {
                    $('#btnStartShow').prop('disabled', false).css('opacity', '1')
                        .html('<i class="fas fa-rocket"></i> Start Main Show')
                        .attr('title', 'Start the main show');
                } else {
                    $('#btnStartShow').prop('disabled', true).css('opacity', '0.5')
                        .html('<i class="fas fa-cog"></i> Configure Show Playlist')
                        .attr('title', 'No show playlist configured - click Settings tab to configure');
                }
            } else if (status.showRunning) {
                // Disable background music button when show is running
                $('#btnStartBackground').prop('disabled', true).css('opacity', '0.5')
                    .attr('title', 'Cannot start background music while show is playing');
                $('#btnStopBackground').prop('disabled', true);
                $('#btnStartShow').prop('disabled', true).css('opacity', '0.5')
                    .html('<i class="fas fa-rocket"></i> Start Main Show')
                    .attr('title', 'Show is already running');
            } else {
                $('#btnStartBackground').prop('disabled', false).css('opacity', '1')
                    .attr('title', 'Start background music playback');
                $('#btnStopBackground').prop('disabled', true);
                
                // Disable start show button when nothing is running
                if (hasShowPlaylist) {
                    $('#btnStartShow').prop('disabled', true).css('opacity', '0.5')
                        .html('<i class="fas fa-rocket"></i> Start Main Show')
                        .attr('title', 'Start background music first');
                } else {
                    $('#btnStartShow').prop('disabled', true).css('opacity', '0.5')
                        .html('<i class="fas fa-cog"></i> Configure Show Playlist')
                        .attr('title', 'No show playlist configured - click Settings tab to configure');
                }
            }
        }
        
        function startBackground() {
            $('#btnStartBackground').addClass('loading');
            $.ajax({
                url: '/api/plugin/fpp-plugin-BackgroundMusic/start-background',
                type: 'POST',
                dataType: 'json',
                success: function(data) {
                    if (data.status === 'OK') {
                        $.jGrowl('Background music started successfully', {themeState: 'success'});
                    } else {
                        $.jGrowl('Error: ' + (data.message || 'Unknown error'), {themeState: 'error'});
                    }
                    $('#btnStartBackground').removeClass('loading');
                    updateStatus();
                },
                error: function() {
                    $.jGrowl('Failed to start background music', {themeState: 'error'});
                    $('#btnStartBackground').removeClass('loading');
                }
            });
        }
        
        function stopBackground() {
            $('#btnStopBackground').addClass('loading');
            $.ajax({
                url: '/api/plugin/fpp-plugin-BackgroundMusic/stop-background',
                type: 'POST',
                dataType: 'json',
                success: function(data) {
                    if (data.status === 'OK') {
                        $.jGrowl('Background music stopped successfully', {themeState: 'success'});
                    } else {
                        $.jGrowl('Error: ' + (data.message || 'Unknown error'), {themeState: 'error'});
                    }
                    $('#btnStopBackground').removeClass('loading');
                    updateStatus();
                },
                error: function() {
                    $.jGrowl('Failed to stop background music', {themeState: 'error'});
                    $('#btnStopBackground').removeClass('loading');
                }
            });
        }
        
        function togglePauseResume() {
            var $btn = $('#btnPauseResume');
            var isPaused = $btn.hasClass('btn-success');
            var endpoint = isPaused ? 'resume-background' : 'pause-background';
            var action = isPaused ? 'resumed' : 'paused';
            
            $btn.prop('disabled', true);
            $.ajax({
                url: '/api/plugin/fpp-plugin-BackgroundMusic/' + endpoint,
                type: 'POST',
                dataType: 'json',
                success: function(data) {
                    if (data.status === 'OK') {
                        $.jGrowl('Background music ' + action, {themeState: 'success', life: 1000});
                    } else {
                        $.jGrowl('Error: ' + (data.message || 'Unknown error'), {themeState: 'error'});
                    }
                    $btn.prop('disabled', false);
                    updateStatus();
                },
                error: function() {
                    $.jGrowl('Failed to ' + (isPaused ? 'resume' : 'pause') + ' background music', {themeState: 'error'});
                    $btn.prop('disabled', false);
                }
            });
        }
        
        function nextTrack() {
            $.ajax({
                url: '/api/plugin/fpp-plugin-BackgroundMusic/next-track',
                type: 'POST',
                dataType: 'json',
                success: function(data) {
                    if (data.status === 'OK') {
                        $.jGrowl('Skipping to next track', {themeState: 'success', life: 1000});
                    } else {
                        $.jGrowl('Error: ' + (data.message || 'Unknown error'), {themeState: 'error'});
                    }
                    updateStatus();
                },
                error: function() {
                    $.jGrowl('Failed to skip track', {themeState: 'error'});
                }
            });
        }
        
        function previousTrack() {
            $.ajax({
                url: '/api/plugin/fpp-plugin-BackgroundMusic/previous-track',
                type: 'POST',
                dataType: 'json',
                success: function(data) {
                    if (data.status === 'OK') {
                        $.jGrowl('Going to previous track', {themeState: 'success', life: 1000});
                    } else {
                        $.jGrowl('Error: ' + (data.message || 'Unknown error'), {themeState: 'error'});
                    }
                    updateStatus();
                },
                error: function() {
                    $.jGrowl('Failed to go to previous track', {themeState: 'error'});
                }
            });
        }
        
        function jumpToTrack(trackNumber) {
            $.ajax({
                url: '/api/plugin/fpp-plugin-BackgroundMusic/jump-to-track',
                type: 'POST',
                contentType: 'application/json',
                data: JSON.stringify({trackNumber: trackNumber}),
                dataType: 'json',
                success: function(data) {
                    if (data.status === 'OK') {
                        $.jGrowl('Jumping to track ' + trackNumber, {themeState: 'success', life: 1000});
                    } else {
                        $.jGrowl('Error: ' + (data.message || 'Unknown error'), {themeState: 'error'});
                    }
                    updateStatus();
                },
                error: function() {
                    $.jGrowl('Failed to jump to track', {themeState: 'error'});
                }
            });
        }
        
        function initPlaylistSortable() {
            // Check if jQuery UI sortable is available
            if (typeof $.fn.sortable === 'undefined') {
                console.warn('jQuery UI sortable not available, drag-and-drop disabled');
                return;
            }
            
            $('#playlistTracksTable').sortable({
                handle: '.fa-grip-vertical',
                axis: 'y',
                cursor: 'move',
                tolerance: 'pointer',
                delay: 100, // Small delay helps prevent accidental drags
                start: function(event, ui) {
                    isDragging = true;
                    ui.item.css('opacity', '0.7');
                    ui.placeholder.css({
                        'background-color': '#e3f2fd',
                        'border': '2px dashed #2196F3',
                        'visibility': 'visible',
                        'height': ui.item.outerHeight() + 'px'
                    });
                },
                stop: function(event, ui) {
                    isDragging = false;
                    ui.item.css('opacity', '1');
                },
                helper: function(e, tr) {
                    var $originals = tr.children();
                    var $helper = tr.clone();
                    $helper.children().each(function(index) {
                        $(this).width($originals.eq(index).width());
                    });
                    $helper.css({
                        'background-color': '#f8f9fa',
                        'box-shadow': '0 4px 8px rgba(0,0,0,0.2)',
                        'border': '1px solid #dee2e6'
                    });
                    return $helper;
                },
                update: function(event, ui) {
                    // Get new order
                    var newOrder = [];
                    $('#playlistTracksTable tr').each(function() {
                        var trackIndex = $(this).data('track-index');
                        if (trackIndex !== undefined) {
                            newOrder.push(trackIndex);
                        }
                    });
                    
                    // Update track numbers in the display
                    $('#playlistTracksTable tr').each(function(index) {
                        $(this).find('td:eq(1)').text(index + 1);
                        $(this).data('track-number', index + 1);
                    });
                    
                    // Save new order
                    savePlaylistOrder(newOrder);
                }
            }).disableSelection();
        }
        
        function savePlaylistOrder(trackOrder) {
            $.ajax({
                url: '/api/plugin/fpp-plugin-BackgroundMusic/reorder-playlist',
                type: 'POST',
                contentType: 'application/json',
                data: JSON.stringify({trackOrder: trackOrder}),
                dataType: 'json',
                success: function(data) {
                    if (data.status === 'OK') {
                        var message = 'Playlist order saved';
                        if (data.message.indexOf('after current track') >= 0) {
                            message = 'Order saved - will apply after current track';
                        }
                        $.jGrowl(message, {themeState: 'success', life: 3000});
                        // Force a fresh playlist load after reordering
                        lastPlaylistUpdate = 0;
                        // Update status to refresh the playlist display
                        setTimeout(function() {
                            updateStatus();
                        }, 500);
                    } else {
                        $.jGrowl('Error saving playlist order: ' + (data.message || 'Unknown error'), {themeState: 'error'});
                    }
                },
                error: function() {
                    $.jGrowl('Failed to save playlist order', {themeState: 'error'});
                }
            });
        }
        
        function startShow() {
            if (!confirm('This will fade out the background music and animation, then start the main show. Continue?')) {
                return;
            }
            
            $('#btnStartShow').addClass('loading');
            $.ajax({
                url: '/api/plugin/fpp-plugin-BackgroundMusic/start-show',
                type: 'POST',
                dataType: 'json',
                success: function(data) {
                    if (data.status === 'OK') {
                        $.jGrowl('Starting show transition...', {themeState: 'success'});
                    } else {
                        $.jGrowl('Error: ' + (data.message || 'Unknown error'), {themeState: 'error'});
                    }
                    $('#btnStartShow').removeClass('loading');
                    updateStatus();
                },
                error: function() {
                    $.jGrowl('Failed to start show', {themeState: 'error'});
                    $('#btnStartShow').removeClass('loading');
                }
            });
        }
        
        // PSA Functions
        var currentlyPlayingPSA = 0; // 0 = none, 1-5 = button number
        
        // Drag and drop state
        var isDragging = false;
        var lastPlaylistUpdate = 0;
        var lastPlaylistData = null;
        var lastCurrentTrack = '';
        
        function generatePSAButtons(config) {
            var container = $('#psaButtonsContainer');
            var buttonsHtml = '';
            var hasButtons = false;
            
            for (var i = 1; i <= 5; i++) {
                var label = config['PSAButton' + i + 'Label'] || '';
                var file = config['PSAButton' + i + 'File'] || '';
                
                if (label && file) {
                    hasButtons = true;
                    buttonsHtml += '<div><button id="psaBtn' + i + '" class="psaButton" onclick="playAnnouncement(' + i + ')">';
                    buttonsHtml += '<i class="fas fa-bullhorn"></i> ' + escapeHtml(label);
                    buttonsHtml += '</button></div>';
                }
            }
            
            if (hasButtons) {
                container.html(buttonsHtml);
            } else {
                container.html('<p style="color: #999; font-size: 14px; margin: 20px 0;"><i class="fas fa-info-circle"></i> Configure PSA buttons in settings</p>');
            }
        }
        
        function playAnnouncement(buttonNumber) {
            if (currentlyPlayingPSA !== 0) {
                $.jGrowl('An announcement is already playing', {themeState: 'warning'});
                return;
            }
            
            $('#psaBtn' + buttonNumber).prop('disabled', true).addClass('playing');
            currentlyPlayingPSA = buttonNumber;
            
            $.ajax({
                url: '/api/plugin/fpp-plugin-BackgroundMusic/play-announcement',
                type: 'POST',
                contentType: 'application/json',
                data: JSON.stringify({buttonNumber: buttonNumber}),
                dataType: 'json',
                success: function(data) {
                    if (data.status === 'OK') {
                        $.jGrowl('Playing announcement...', {themeState: 'success'});
                        // Monitor announcement status
                        monitorAnnouncement(buttonNumber);
                    } else {
                        $.jGrowl('Error: ' + (data.message || 'Failed to play announcement'), {themeState: 'error'});
                        resetPSAButton(buttonNumber);
                    }
                },
                error: function() {
                    $.jGrowl('Failed to play announcement', {themeState: 'error'});
                    resetPSAButton(buttonNumber);
                }
            });
        }
        
        function stopAnnouncement() {
            if (currentlyPlayingPSA === 0) return;
            
            var buttonNumber = currentlyPlayingPSA;
            $.ajax({
                url: '/api/plugin/fpp-plugin-BackgroundMusic/stop-announcement',
                type: 'POST',
                dataType: 'json',
                success: function(data) {
                    $.jGrowl('Announcement stopped', {themeState: 'success'});
                    resetPSAButton(buttonNumber);
                },
                error: function() {
                    $.jGrowl('Failed to stop announcement', {themeState: 'error'});
                }
            });
        }
        
        function monitorAnnouncement(buttonNumber) {
            // Check if announcement is still playing
            var checkInterval = setInterval(function() {
                $.ajax({
                    url: '/api/plugin/fpp-plugin-BackgroundMusic/psa-status',
                    type: 'GET',
                    dataType: 'json',
                    success: function(data) {
                        if (!data.playing) {
                            // Announcement finished
                            clearInterval(checkInterval);
                            resetPSAButton(buttonNumber);
                        }
                    },
                    error: function() {
                        // Error checking status, assume finished
                        clearInterval(checkInterval);
                        resetPSAButton(buttonNumber);
                    }
                });
            }, 1000); // Check every second
        }
        
        function resetPSAButton(buttonNumber) {
            $('#psaBtn' + buttonNumber).prop('disabled', false).removeClass('playing');
            currentlyPlayingPSA = 0;
        }
        
        // Update check functionality
        var updateCheckDismissed = false;
        var lastUpdateCheck = 0;
        var UPDATE_CHECK_INTERVAL = 3600000; // Check every hour (in milliseconds)
        
        function checkForUpdates() {
            // Don't check if dismissed or checked recently (within the hour)
            var now = Date.now();
            if (updateCheckDismissed || (now - lastUpdateCheck) < UPDATE_CHECK_INTERVAL) {
                return;
            }
            
            lastUpdateCheck = now;
            
            $.ajax({
                url: '/api/plugin/fpp-plugin-BackgroundMusic/check-update',
                type: 'GET',
                dataType: 'json',
                timeout: 10000, // 10 second timeout
                success: function(data) {
                    if (data.status === 'OK' && data.hasUpdate && data.canConnect) {
                        var details = 'Version ' + data.latestCommitShort + ' is available';
                        if (data.branch && data.branch !== 'master') {
                            details += ' (branch: ' + data.branch + ')';
                        }
                        if (data.behindBy > 0) {
                            details += ' — ' + data.behindBy + ' commit' + (data.behindBy > 1 ? 's' : '') + ' behind';
                        }
                        if (data.latestCommitMessage) {
                            details += ' — ' + data.latestCommitMessage;
                        }
                        $('#updateDetails').text(details);
                        $('#updateNotification').slideDown(400);
                    }
                },
                error: function() {
                    // Silently fail - don't bother the user if update check fails
                }
            });
        }
        
        function dismissUpdateNotification() {
            $('#updateNotification').slideUp(400);
            updateCheckDismissed = true;
        }
        
        setInterval(updateStatus, 2000);
        
        // Initialize custom tooltips for player control buttons
        function initCustomTooltips() {
            $('.player-control-btn').each(function() {
                var $btn = $(this);
                var tooltipText = $btn.attr('data-tooltip');
                
                if (tooltipText) {
                    var $tooltip = $('<div class="custom-tooltip">' + tooltipText + '</div>');
                    $btn.append($tooltip);
                    
                    $btn.on('mouseenter', function() {
                        $(this).find('.custom-tooltip').addClass('show');
                    });
                    
                    $btn.on('mouseleave', function() {
                        $(this).find('.custom-tooltip').removeClass('show');
                    });
                }
            });
        }
        
        $(document).ready(function() {
            updateStatus();
            
            // Initialize custom tooltips
            initCustomTooltips();
            
            // Check for updates on page load (after a short delay)
            setTimeout(checkForUpdates, 5000); // Wait 5 seconds after page load
            
            // Check for updates periodically
            setInterval(checkForUpdates, UPDATE_CHECK_INTERVAL);
        });
    </script>
    
    <!-- Header Indicator - Shows music status in FPP header -->
    <script src="/plugin.php?plugin=fpp-plugin-BackgroundMusic&file=header-indicator.js&nopage=1"></script>
</div>
