<style>
    .controlPanel {
        margin: 20px auto;
        max-width: 800px;
        text-align: center;
    }
    .controlButton {
        margin: 10px;
        padding: 20px 40px;
        font-size: 18px;
        min-width: 250px;
    }
    .statusPanel {
        margin: 20px auto;
        max-width: 800px;
        padding: 20px;
        background-color: #f5f5f5;
        border-radius: 5px;
    }
    .statusItem {
        margin: 10px 0;
        font-size: 16px;
    }
    .statusLabel {
        font-weight: bold;
        display: inline-block;
        width: 200px;
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
</style>

<div id="global" class="settings">
    <h1>Background Music Controller</h1>
    
    <div class="controlPanel">
            <h2>Control Panel</h2>
            <div>
                <button id="btnStartBackground" class="controlButton btn-start" onclick="startBackground()">
                    Start Background Music
                </button>
            </div>
            <div>
                <button id="btnStopBackground" class="controlButton btn-stop" onclick="stopBackground()">
                    Stop Background Music
                </button>
            </div>
            <div>
                <button id="btnStartShow" class="controlButton btn-show" onclick="startShow()">
                    Start Main Show
                </button>
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
                        <div id="trackProgressBar" style="background-color: #007bff; height: 100%; width: 0%; transition: width 0.3s;"></div>
                        <span id="trackProgressText" style="position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); font-size: 12px; font-weight: bold; color: #000;">0%</span>
                    </div>
                </div>
                <span id="trackTimeDisplay" style="margin-left: 10px; font-size: 12px; color: #6c757d;">0:00 / 0:00</span>
            </div>
            <div class="statusItem">
                <span class="statusLabel">Main Show:</span>
                <span id="statusShow">Not Running</span>
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
            <h2><i class="fas fa-volume-up"></i> Volume Control</h2>
            <div class="statusItem">
                <span class="statusLabel">Current Volume:</span>
                <span id="statusVolume" style="font-weight: bold; font-size: 18px; color: #007bff;">70%</span>
            </div>
            <div class="statusItem">
                <div style="display: flex; align-items: center; gap: 15px; margin-top: 10px;">
                    <span style="font-size: 24px;">🔈</span>
                    <input type="range" id="volumeSlider" min="0" max="100" value="70" 
                           style="flex: 1; height: 8px; cursor: pointer;" 
                           oninput="updateVolumeDisplay(this.value)" 
                           onchange="setVolume(this.value)">
                    <span style="font-size: 24px;">🔊</span>
                </div>
                <div style="text-align: center; margin-top: 8px; font-size: 12px; color: #6c757d;">
                    <span>Adjust FPP system volume (affects all audio output)</span>
                </div>
            </div>
        </div>

        <!-- Background Music Playlist Details Panel -->
        <div class="statusPanel">
            <h2><i class="fas fa-music"></i> Background Music Playlist</h2>
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
            <div style="margin-top: 15px; max-height: 400px; overflow-y: auto; border: 1px solid #e0e0e0; border-radius: 4px;">
                <table style="width: 100%; border-collapse: collapse; font-size: 14px;">
                    <thead style="position: sticky; top: 0; background-color: #f8f9fa; border-bottom: 2px solid #dee2e6;">
                        <tr>
                            <th style="padding: 8px; text-align: left; width: 40px;">#</th>
                            <th style="padding: 8px; text-align: left;">Track Name</th>
                            <th style="padding: 8px; text-align: right; width: 80px;">Duration</th>
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

        <!-- Configuration Summary Panel -->
        <div class="statusPanel">
            <h2><i class="fas fa-cog"></i> Configuration Summary</h2>
            
            <!-- Playlists -->
            <h4 style="color: #2196F3; margin-top: 15px; margin-bottom: 10px; border-bottom: 1px solid #e0e0e0; padding-bottom: 5px;">
                <i class="fas fa-list"></i> Playlists
            </h4>
            <div class="statusItem">
                <span class="statusLabel">Background Music Playlist:</span>
                <span id="configBackgroundMusic">-</span>
            </div>
            <div class="statusItem">
                <span class="statusLabel">Show Playlist:</span>
                <span id="configShowPlaylist">-</span>
            </div>
            <div class="statusItem">
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

    <script>
        // Helper function to format seconds as MM:SS
        function formatTime(seconds) {
            var mins = Math.floor(seconds / 60);
            var secs = seconds % 60;
            return mins + ':' + (secs < 10 ? '0' : '') + secs;
        }
        
        function updateVolumeDisplay(volume) {
            $('#statusVolume').text(volume + '%');
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
                    
                    // Show current track information
                    if (data.backgroundMusicRunning && data.currentTrack) {
                        $('#currentTrackContainer').show();
                        $('#trackProgressContainer').show();
                        $('#statusCurrentTrack').text(data.currentTrack);
                        
                        // Update progress bar
                        var progress = data.trackProgress || 0;
                        $('#trackProgressBar').css('width', progress + '%');
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
                    
                    $('#configBackgroundMusic').text(data.config.backgroundMusicPlaylist || 'Not Set');
                    $('#configShowPlaylist').text(data.config.showPlaylist || 'Not Set');
                    $('#configShuffleMusic').text(data.config.shuffleMusic == '1' ? 'Yes' : 'No');
                    
                    $('#configBackgroundMusicVolume').text(data.config.backgroundMusicVolume || data.config.volumeLevel || '70');
                    $('#configShowPlaylistVolume').text(data.config.showPlaylistVolume || '100');
                    $('#configPostShowBackgroundVolume').text(data.config.postShowBackgroundVolume || data.config.backgroundMusicVolume || data.config.volumeLevel || '70');
                    
                    $('#configFadeTime').text(data.config.fadeTime || '5');
                    $('#configBlackoutTime').text(data.config.blackoutTime || '2');
                    
                    $('#configReturnToPreShow').text(data.config.returnToPreShow == '1' ? 'Yes' : 'No');
                    $('#configPostShowDelay').text(data.config.postShowDelay || '0');
                    
                    updateButtonStates(data);
                    
                    // Update playlist details with current track info
                    var currentTrack = data.currentTrack || '';
                    updatePlaylistDetails(currentTrack);
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
        
        function updatePlaylistDetails(currentTrack) {
            $.ajax({
                url: '/api/plugin/fpp-plugin-BackgroundMusic/playlist-details',
                type: 'GET',
                dataType: 'json',
                success: function(data) {
                    if (data.status === 'OK' && data.tracks && data.tracks.length > 0) {
                        $('#playlistName').text(data.playlistName);
                        $('#playlistTrackCount').text(data.totalTracks + ' tracks');
                        $('#playlistTotalDuration').text('Total: ' + data.totalDurationFormatted);
                        
                        // Build table rows
                        var rows = '';
                        for (var i = 0; i < data.tracks.length; i++) {
                            var track = data.tracks[i];
                            var isPlaying = currentTrack && track.name === currentTrack;
                            var rowStyle = '';
                            var iconHtml = '';
                            
                            if (isPlaying) {
                                rowStyle = ' style="background-color: #e3f2fd; font-weight: bold; border-left: 3px solid #2196F3;"';
                                iconHtml = ' <i class="fas fa-play" style="color: #2196F3; margin-left: 5px;"></i>';
                            }
                            
                            rows += '<tr' + rowStyle + '>';
                            rows += '<td style="text-align: center; padding: 8px;">' + track.number + '</td>';
                            rows += '<td style="padding: 8px;">' + escapeHtml(track.name) + iconHtml + '</td>';
                            rows += '<td style="text-align: right; padding: 8px;">' + track.durationFormatted + '</td>';
                            rows += '</tr>';
                        }
                        $('#playlistTracksTable').html(rows);
                    } else {
                        // No playlist or error
                        var message = data.message || 'No playlist configured';
                        $('#playlistName').text('-');
                        $('#playlistTrackCount').text('-');
                        $('#playlistTotalDuration').text('-');
                        $('#playlistTracksTable').html('<tr><td colspan="3" style="text-align: center; color: #999;">' + message + '</td></tr>');
                    }
                },
                error: function() {
                    $('#playlistTracksTable').html('<tr><td colspan="3" style="text-align: center; color: #999;">Error loading playlist</td></tr>');
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
            if (status.backgroundMusicRunning) {
                $('#btnStartBackground').prop('disabled', true).css('opacity', '0.5')
                    .attr('title', 'Background music is already running');
                $('#btnStopBackground').prop('disabled', false);
                $('#btnStartShow').prop('disabled', false);
            } else if (status.showRunning) {
                // Disable background music button when show is running
                $('#btnStartBackground').prop('disabled', true).css('opacity', '0.5')
                    .attr('title', 'Cannot start background music while show is playing');
                $('#btnStopBackground').prop('disabled', true);
                $('#btnStartShow').prop('disabled', true).css('opacity', '0.5')
                    .attr('title', 'Show is already running');
            } else {
                $('#btnStartBackground').prop('disabled', false).css('opacity', '1')
                    .attr('title', 'Start background music playback');
                $('#btnStopBackground').prop('disabled', true);
                $('#btnStartShow').prop('disabled', true);
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
        
        setInterval(updateStatus, 2000);
        
        $(document).ready(function() {
            updateStatus();
        });
    </script>
</div>
