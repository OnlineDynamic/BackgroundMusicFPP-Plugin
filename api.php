<?php
include_once("/opt/fpp/www/common.php");
$pluginName = "fpp-plugin-BackgroundMusic";
$pluginConfigFile = $settings['configDirectory'] . "/plugin." . $pluginName;

function getEndpointsfpppluginBackgroundMusic() {
    $result = array();

    $ep = array(
        'method' => 'GET',
        'endpoint' => 'version',
        'callback' => 'fppBackgroundMusicVersion');
    array_push($result, $ep);
    
    $ep = array(
        'method' => 'GET',
        'endpoint' => 'status',
        'callback' => 'fppBackgroundMusicStatus');
    array_push($result, $ep);
    
    $ep = array(
        'method' => 'POST',
        'endpoint' => 'start-background',
        'callback' => 'fppBackgroundMusicStartBackground');
    array_push($result, $ep);
    
    $ep = array(
        'method' => 'POST',
        'endpoint' => 'stop-background',
        'callback' => 'fppBackgroundMusicStopBackground');
    array_push($result, $ep);
    
    $ep = array(
        'method' => 'POST',
        'endpoint' => 'pause-background',
        'callback' => 'fppBackgroundMusicPauseBackground');
    array_push($result, $ep);
    
    $ep = array(
        'method' => 'POST',
        'endpoint' => 'resume-background',
        'callback' => 'fppBackgroundMusicResumeBackground');
    array_push($result, $ep);
    
    $ep = array(
        'method' => 'POST',
        'endpoint' => 'next-track',
        'callback' => 'fppBackgroundMusicNextTrack');
    array_push($result, $ep);
    
    $ep = array(
        'method' => 'POST',
        'endpoint' => 'previous-track',
        'callback' => 'fppBackgroundMusicPreviousTrack');
    array_push($result, $ep);
    
    $ep = array(
        'method' => 'POST',
        'endpoint' => 'jump-to-track',
        'callback' => 'fppBackgroundMusicJumpToTrack');
    array_push($result, $ep);
    
    $ep = array(
        'method' => 'POST',
        'endpoint' => 'start-show',
        'callback' => 'fppBackgroundMusicStartShow');
    array_push($result, $ep);
    
    $ep = array(
        'method' => 'POST',
        'endpoint' => 'set-volume',
        'callback' => 'fppBackgroundMusicSetVolume');
    array_push($result, $ep);
    
    $ep = array(
        'method' => 'POST',
        'endpoint' => 'save-settings',
        'callback' => 'fppBackgroundMusicSaveSettings');
    array_push($result, $ep);
    
    $ep = array(
        'method' => 'GET',
        'endpoint' => 'playlist-details',
        'callback' => 'fppBackgroundMusicPlaylistDetails');
    array_push($result, $ep);
    
    $ep = array(
        'method' => 'POST',
        'endpoint' => 'play-announcement',
        'callback' => 'fppBackgroundMusicPlayAnnouncement');
    array_push($result, $ep);
    
    $ep = array(
        'method' => 'POST',
        'endpoint' => 'stop-announcement',
        'callback' => 'fppBackgroundMusicStopAnnouncement');
    array_push($result, $ep);
    
    $ep = array(
        'method' => 'GET',
        'endpoint' => 'psa-status',
        'callback' => 'fppBackgroundMusicPSAStatus');
    array_push($result, $ep);
    
    $ep = array(
        'method' => 'GET',
        'endpoint' => 'check-update',
        'callback' => 'fppBackgroundMusicCheckUpdate');
    array_push($result, $ep);
    
    $ep = array(
        'method' => 'GET',
        'endpoint' => 'get-commit-history',
        'callback' => 'fppBackgroundMusicGetCommitHistory');
    array_push($result, $ep);
    
    $ep = array(
        'method' => 'POST',
        'endpoint' => 'reorder-playlist',
        'callback' => 'fppBackgroundMusicReorderPlaylist');
    array_push($result, $ep);

    return $result;
}

// GET /api/plugin/fpp-plugin-BackgroundMusic/version
function fppBackgroundMusicVersion() {
    $result = array();
    $result['version'] = 'fpp-BackgroundMusic v1.0';
    return json($result);
}

// GET /api/plugin/fpp-plugin-BackgroundMusic/status
function fppBackgroundMusicStatus() {
    global $settings;
    $pluginConfigFile = $settings['configDirectory'] . "/plugin.fpp-plugin-BackgroundMusic";
    
    // Load plugin config with error checking
    $pluginSettings = array();
    if (file_exists($pluginConfigFile)){
        // Check if file is readable
        if (!is_readable($pluginConfigFile)) {
            error_log("BackgroundMusic Plugin: Config file exists but is not readable: $pluginConfigFile");
            // Try to fix permissions
            @chmod($pluginConfigFile, 0644);
        }
        
        // Try to parse the file
        $pluginSettings = @parse_ini_file($pluginConfigFile);
        if ($pluginSettings === false) {
            error_log("BackgroundMusic Plugin: Failed to parse config file: $pluginConfigFile");
            $pluginSettings = array();
        }
    } else {
        error_log("BackgroundMusic Plugin: Config file does not exist: $pluginConfigFile");
    }
    
    // Get current brightness
    $brightness = getSetting('brightness');
    if ($brightness === false || $brightness === '') {
        $brightness = 100;
    }
    
    // Check running playlists
    $status = GetCurrentStatus();
    $currentPlaylist = isset($status['current_playlist']['playlist']) ? $status['current_playlist']['playlist'] : '';
    $fppStatus = isset($status['status_name']) ? $status['status_name'] : 'unknown';
    $currentSequence = isset($status['current_sequence']) ? $status['current_sequence'] : '';
    
    $backgroundMusicPlaylist = isset($pluginSettings['BackgroundMusicPlaylist']) ? $pluginSettings['BackgroundMusicPlaylist'] : '';
    $showPlaylist = isset($pluginSettings['ShowPlaylist']) ? $pluginSettings['ShowPlaylist'] : '';
    $returnToPreShow = isset($pluginSettings['ReturnToPreShow']) ? $pluginSettings['ReturnToPreShow'] : '1';
    $shuffleMusic = isset($pluginSettings['ShuffleMusic']) ? $pluginSettings['ShuffleMusic'] : '0';
    $volumeLevel = isset($pluginSettings['VolumeLevel']) ? intval($pluginSettings['VolumeLevel']) : 70;
    $backgroundMusicVolume = isset($pluginSettings['BackgroundMusicVolume']) ? intval($pluginSettings['BackgroundMusicVolume']) : $volumeLevel;
    $showPlaylistVolume = isset($pluginSettings['ShowPlaylistVolume']) ? intval($pluginSettings['ShowPlaylistVolume']) : 100;
    $postShowBackgroundVolume = isset($pluginSettings['PostShowBackgroundVolume']) ? intval($pluginSettings['PostShowBackgroundVolume']) : $backgroundMusicVolume;
    
    // Check if background music player is running (independent of FPP playlists)
    $pidFile = '/tmp/background_music_player.pid';
    $backgroundMusicRunning = false;
    if (file_exists($pidFile)) {
        $pid = trim(file_get_contents($pidFile));
        // Check if process is actually running
        exec("ps -p $pid > /dev/null 2>&1", $output, $returnCode);
        $backgroundMusicRunning = ($returnCode === 0);
    }
    
    // Get current track information if player is running
    $currentTrack = '';
    $trackDuration = 0;
    $trackElapsed = 0;
    $trackProgress = 0;
    $playbackState = 'stopped';
    $currentTrackNumber = 0;
    $totalTracks = 0;
    $streamSource = false;
    
    if ($backgroundMusicRunning) {
        $statusFile = '/tmp/bg_music_status.txt';
        if (file_exists($statusFile)) {
            // Read status file line by line to handle special characters properly
            $statusLines = file($statusFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
            $statusData = array();
            foreach ($statusLines as $line) {
                // Split on first = only
                $pos = strpos($line, '=');
                if ($pos !== false) {
                    $key = substr($line, 0, $pos);
                    $value = substr($line, $pos + 1);
                    $statusData[$key] = $value;
                }
            }
            
            if ($statusData) {
                // Check if this is a stream source
                $streamSource = isset($statusData['source']) && $statusData['source'] === 'stream';
                
                // Only populate track info for playlist mode, not for streams
                if (!$streamSource) {
                    $currentTrack = isset($statusData['filename']) ? $statusData['filename'] : '';
                    $trackDuration = isset($statusData['duration']) ? intval($statusData['duration']) : 0;
                    $trackElapsed = isset($statusData['elapsed']) ? intval($statusData['elapsed']) : 0;
                    $trackProgress = isset($statusData['progress']) ? intval($statusData['progress']) : 0;
                    $currentTrackNumber = isset($statusData['track_number']) ? intval($statusData['track_number']) : 0;
                    $totalTracks = isset($statusData['total_tracks']) ? intval($statusData['total_tracks']) : 0;
                }
                $playbackState = isset($statusData['state']) ? $statusData['state'] : 'playing';
            }
        }
    }
    
    $showRunning = ($currentPlaylist === $showPlaylist && $currentPlaylist !== '');
    
    // Check if fpp-brightness plugin is installed (required for transitions)
    $brightnessPluginInstalled = file_exists('/home/fpp/media/plugins/fpp-brightness/libfpp-brightness.so');
    
    $result = array(
        'backgroundMusicRunning' => $backgroundMusicRunning,
        'showRunning' => $showRunning,
        'streamSource' => $streamSource,
        'brightness' => intval($brightness),
        'brightnessPluginInstalled' => $brightnessPluginInstalled,
        'currentPlaylist' => $currentPlaylist,
        'fppStatus' => $fppStatus,
        'currentSequence' => $currentSequence,
        'currentTrack' => $currentTrack,
        'trackDuration' => $trackDuration,
        'trackElapsed' => $trackElapsed,
        'trackProgress' => $trackProgress,
        'playbackState' => $playbackState,
        'currentTrackNumber' => $currentTrackNumber,
        'totalTracks' => $totalTracks,
        'config' => array(
            'backgroundMusicSource' => isset($pluginSettings['BackgroundMusicSource']) ? $pluginSettings['BackgroundMusicSource'] : 'playlist',
            'backgroundMusicPlaylist' => $backgroundMusicPlaylist,
            'backgroundMusicStreamURL' => isset($pluginSettings['BackgroundMusicStreamURL']) ? $pluginSettings['BackgroundMusicStreamURL'] : '',
            'showPlaylist' => $showPlaylist,
            'fadeTime' => isset($pluginSettings['FadeTime']) ? $pluginSettings['FadeTime'] : 5,
            'blackoutTime' => isset($pluginSettings['BlackoutTime']) ? $pluginSettings['BlackoutTime'] : 2,
            'returnToPreShow' => $returnToPreShow,
            'postShowDelay' => isset($pluginSettings['PostShowDelay']) ? $pluginSettings['PostShowDelay'] : 0,
            'shuffleMusic' => $shuffleMusic,
            'volumeLevel' => $volumeLevel,
            'backgroundMusicVolume' => $backgroundMusicVolume,
            'showPlaylistVolume' => $showPlaylistVolume,
            'postShowBackgroundVolume' => $postShowBackgroundVolume,
            'PSAAnnouncementVolume' => isset($pluginSettings['PSAAnnouncementVolume']) ? $pluginSettings['PSAAnnouncementVolume'] : '90',
            'PSADuckVolume' => isset($pluginSettings['PSADuckVolume']) ? $pluginSettings['PSADuckVolume'] : '30',
            'PSAButton1Label' => isset($pluginSettings['PSAButton1Label']) ? $pluginSettings['PSAButton1Label'] : '',
            'PSAButton1File' => isset($pluginSettings['PSAButton1File']) ? $pluginSettings['PSAButton1File'] : '',
            'PSAButton2Label' => isset($pluginSettings['PSAButton2Label']) ? $pluginSettings['PSAButton2Label'] : '',
            'PSAButton2File' => isset($pluginSettings['PSAButton2File']) ? $pluginSettings['PSAButton2File'] : '',
            'PSAButton3Label' => isset($pluginSettings['PSAButton3Label']) ? $pluginSettings['PSAButton3Label'] : '',
            'PSAButton3File' => isset($pluginSettings['PSAButton3File']) ? $pluginSettings['PSAButton3File'] : '',
            'PSAButton4Label' => isset($pluginSettings['PSAButton4Label']) ? $pluginSettings['PSAButton4Label'] : '',
            'PSAButton4File' => isset($pluginSettings['PSAButton4File']) ? $pluginSettings['PSAButton4File'] : '',
            'PSAButton5Label' => isset($pluginSettings['PSAButton5Label']) ? $pluginSettings['PSAButton5Label'] : '',
            'PSAButton5File' => isset($pluginSettings['PSAButton5File']) ? $pluginSettings['PSAButton5File'] : ''
        )
    );
    
    return json($result);
}

// POST /api/plugin/fpp-plugin-BackgroundMusic/start-background
function fppBackgroundMusicStartBackground() {
    global $settings;
    $pluginConfigFile = $settings['configDirectory'] . "/plugin.fpp-plugin-BackgroundMusic";
    
    if (file_exists($pluginConfigFile)){
        $pluginSettings = parse_ini_file($pluginConfigFile);
    } else {
        return json(array('status' => 'ERROR', 'message' => 'Plugin not configured'));
    }
    
    // Check source type
    $source = isset($pluginSettings['BackgroundMusicSource']) ? $pluginSettings['BackgroundMusicSource'] : 'playlist';
    
    if ($source === 'stream') {
        $streamURL = isset($pluginSettings['BackgroundMusicStreamURL']) ? $pluginSettings['BackgroundMusicStreamURL'] : '';
        if (empty($streamURL)) {
            return json(array('status' => 'ERROR', 'message' => 'Stream URL not configured'));
        }
    } else {
        $backgroundMusicPlaylist = isset($pluginSettings['BackgroundMusicPlaylist']) ? $pluginSettings['BackgroundMusicPlaylist'] : '';
        if (empty($backgroundMusicPlaylist)) {
            return json(array('status' => 'ERROR', 'message' => 'Background music playlist not configured'));
        }
    }
    
    // Start background music using independent player (not FPP playlist system)
    // This allows music to play while FPP scheduler controls the sequence playlist
    $scriptPath = dirname(__FILE__) . '/scripts/background_music_player.sh';
    $output = array();
    $returnCode = 0;
    exec("/bin/bash " . escapeshellarg($scriptPath) . " start 2>&1", $output, $returnCode);
    
    if ($returnCode === 0) {
        return json(array('status' => 'OK', 'message' => 'Background music started'));
    } else {
        return json(array('status' => 'ERROR', 'message' => 'Failed to start background music', 'details' => implode("\n", $output)));
    }
}

// POST /api/plugin/fpp-plugin-BackgroundMusic/stop-background
function fppBackgroundMusicStopBackground() {
    // Stop the independent background music player
    $scriptPath = dirname(__FILE__) . '/scripts/background_music_player.sh';
    $output = array();
    $returnCode = 0;
    exec("/bin/bash " . escapeshellarg($scriptPath) . " stop 2>&1", $output, $returnCode);
    
    // Also stop any FPP playlist that might be playing background music
    // Check if a background music playlist is currently playing
    global $settings;
    $pluginConfigFile = $settings['configDirectory'] . "/plugin.fpp-plugin-BackgroundMusic";
    
    if (file_exists($pluginConfigFile)) {
        $pluginSettings = parse_ini_file($pluginConfigFile);
        $bgMusicPlaylist = isset($pluginSettings['BackgroundMusicPlaylist']) ? $pluginSettings['BackgroundMusicPlaylist'] : '';
        
        // Get current FPP status
        $fppStatus = @file_get_contents('http://localhost/api/fppd/status');
        if ($fppStatus) {
            $statusData = json_decode($fppStatus, true);
            $currentPlaylist = isset($statusData['current_playlist']['playlist']) ? $statusData['current_playlist']['playlist'] : '';
            
            // If the current FPP playlist matches our background music playlist, stop it
            if (!empty($bgMusicPlaylist) && $currentPlaylist === $bgMusicPlaylist) {
                // Stop the FPP playlist
                @file_get_contents('http://localhost/api/playlists/stop');
            }
        }
    }
    
    return json(array('status' => 'OK', 'message' => 'Background music stopped'));
}

// POST /api/plugin/fpp-plugin-BackgroundMusic/pause-background
function fppBackgroundMusicPauseBackground() {
    $scriptPath = dirname(__FILE__) . '/scripts/background_music_player.sh';
    $output = array();
    $returnCode = 0;
    exec("/bin/bash " . escapeshellarg($scriptPath) . " pause 2>&1", $output, $returnCode);
    
    if ($returnCode === 0) {
        return json(array('status' => 'OK', 'message' => 'Background music paused'));
    } else {
        return json(array('status' => 'ERROR', 'message' => 'Failed to pause background music', 'details' => implode("\n", $output)));
    }
}

// POST /api/plugin/fpp-plugin-BackgroundMusic/resume-background
function fppBackgroundMusicResumeBackground() {
    $scriptPath = dirname(__FILE__) . '/scripts/background_music_player.sh';
    $output = array();
    $returnCode = 0;
    exec("/bin/bash " . escapeshellarg($scriptPath) . " resume 2>&1", $output, $returnCode);
    
    if ($returnCode === 0) {
        return json(array('status' => 'OK', 'message' => 'Background music resumed'));
    } else {
        return json(array('status' => 'ERROR', 'message' => 'Failed to resume background music', 'details' => implode("\n", $output)));
    }
}

// POST /api/plugin/fpp-plugin-BackgroundMusic/next-track
function fppBackgroundMusicNextTrack() {
    $scriptPath = dirname(__FILE__) . '/scripts/background_music_player.sh';
    $output = array();
    $returnCode = 0;
    exec("/bin/bash " . escapeshellarg($scriptPath) . " next 2>&1", $output, $returnCode);
    
    if ($returnCode === 0) {
        return json(array('status' => 'OK', 'message' => 'Skipped to next track'));
    } else {
        return json(array('status' => 'ERROR', 'message' => 'Failed to skip track', 'details' => implode("\n", $output)));
    }
}

// POST /api/plugin/fpp-plugin-BackgroundMusic/previous-track
function fppBackgroundMusicPreviousTrack() {
    $scriptPath = dirname(__FILE__) . '/scripts/background_music_player.sh';
    $output = array();
    $returnCode = 0;
    exec("/bin/bash " . escapeshellarg($scriptPath) . " previous 2>&1", $output, $returnCode);
    
    if ($returnCode === 0) {
        return json(array('status' => 'OK', 'message' => 'Went to previous track'));
    } else {
        return json(array('status' => 'ERROR', 'message' => 'Failed to go to previous track', 'details' => implode("\n", $output)));
    }
}

// POST /api/plugin/fpp-plugin-BackgroundMusic/jump-to-track
function fppBackgroundMusicJumpToTrack() {
    $input = json_decode(file_get_contents('php://input'), true);
    $trackNumber = isset($input['trackNumber']) ? intval($input['trackNumber']) : 0;
    
    if ($trackNumber < 1) {
        return json(array('status' => 'ERROR', 'message' => 'Invalid track number'));
    }
    
    $scriptPath = dirname(__FILE__) . '/scripts/background_music_player.sh';
    $output = array();
    $returnCode = 0;
    exec("/bin/bash " . escapeshellarg($scriptPath) . " jump " . escapeshellarg($trackNumber) . " 2>&1", $output, $returnCode);
    
    if ($returnCode === 0) {
        return json(array('status' => 'OK', 'message' => 'Jumped to track ' . $trackNumber));
    } else {
        return json(array('status' => 'ERROR', 'message' => 'Failed to jump to track', 'details' => implode("\n", $output)));
    }
}

// POST /api/plugin/fpp-plugin-BackgroundMusic/start-show
function fppBackgroundMusicStartShow() {
    global $settings;
    $pluginConfigFile = $settings['configDirectory'] . "/plugin.fpp-plugin-BackgroundMusic";
    
    if (file_exists($pluginConfigFile)){
        $pluginSettings = parse_ini_file($pluginConfigFile);
    } else {
        return json(array('status' => 'ERROR', 'message' => 'Plugin not configured'));
    }
    
    $showPlaylist = isset($pluginSettings['ShowPlaylist']) ? $pluginSettings['ShowPlaylist'] : '';
    $fadeTime = isset($pluginSettings['FadeTime']) ? intval($pluginSettings['FadeTime']) : 5;
    $blackoutTime = isset($pluginSettings['BlackoutTime']) ? intval($pluginSettings['BlackoutTime']) : 2;
    
    if (empty($showPlaylist)) {
        return json(array('status' => 'ERROR', 'message' => 'Show playlist not configured'));
    }
    
    // Execute the fade and show transition script in background
    $scriptPath = dirname(__FILE__) . '/scripts/start_show_transition.sh';
    $logFile = '/home/fpp/media/logs/fpp-plugin-BackgroundMusic-api.log';
    $cmd = sprintf('/bin/bash %s %d %d %s >> %s 2>&1 &', 
        escapeshellarg($scriptPath), 
        $fadeTime, 
        $blackoutTime, 
        escapeshellarg($showPlaylist),
        escapeshellarg($logFile));
    
    exec($cmd);
    
    return json(array('status' => 'OK', 'message' => 'Show transition started'));
}

// POST /api/plugin/fpp-plugin-BackgroundMusic/set-volume
function fppBackgroundMusicSetVolume() {
    global $settings;
    $pluginConfigFile = $settings['configDirectory'] . "/plugin.fpp-plugin-BackgroundMusic";
    
    // Get POST data
    $input = json_decode(file_get_contents('php://input'), true);
    $volume = isset($input['volume']) ? intval($input['volume']) : null;
    
    if ($volume === null || $volume < 0 || $volume > 100) {
        return json(array('status' => 'ERROR', 'message' => 'Invalid volume level. Must be between 0 and 100.'));
    }
    
    // Update the config file
    if (file_exists($pluginConfigFile)){
        $pluginSettings = parse_ini_file($pluginConfigFile);
    } else {
        $pluginSettings = array();
    }
    
    $pluginSettings['VolumeLevel'] = $volume;
    $pluginSettings['BackgroundMusicVolume'] = $volume;  // Update both for consistency
    
    // Write back to config file
    $configContent = "";
    foreach ($pluginSettings as $key => $value) {
        $configContent .= "$key=$value\n";
    }
    file_put_contents($pluginConfigFile, $configContent);
    
    // Apply volume change immediately using system audio controls
    $scriptPath = dirname(__FILE__) . '/scripts/restore_audio_volume.sh';
    exec("/bin/bash " . escapeshellarg($scriptPath) . " " . escapeshellarg($volume) . " 2>&1", $output, $returnCode);
    
    if ($returnCode === 0) {
        return json(array('status' => 'OK', 'message' => 'Volume updated immediately', 'volume' => $volume));
    } else {
        return json(array('status' => 'WARNING', 'message' => 'Volume saved but failed to apply immediately', 'volume' => $volume));
    }
}

function GetCurrentStatus() {
    $ch = curl_init('http://localhost/api/fppd/status');
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_HEADER, 0);
    $data = curl_exec($ch);
    curl_close($ch);
    return json_decode($data, true);
}

// POST /api/plugin/fpp-plugin-BackgroundMusic/save-settings
function fppBackgroundMusicSaveSettings() {
    global $settings;
    $pluginConfigFile = $settings['configDirectory'] . "/plugin.fpp-plugin-BackgroundMusic";
    
    // Get POST data
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input) {
        return json(array('status' => 'ERROR', 'message' => 'Invalid input data'));
    }
    
    // Write settings in INI format
    $configContent = "";
    foreach ($input as $key => $value) {
        // Quote values that contain spaces or special characters
        if (strpos($value, ' ') !== false || strpos($value, '"') !== false || strpos($value, '=') !== false) {
            // Escape any existing quotes and wrap in quotes
            $value = '"' . str_replace('"', '\\"', $value) . '"';
        }
        $configContent .= "$key=$value\n";
    }
    
    if (file_put_contents($pluginConfigFile, $configContent) !== false) {
        return json(array('status' => 'OK', 'message' => 'Settings saved successfully'));
    } else {
        return json(array('status' => 'ERROR', 'message' => 'Failed to write settings file'));
    }
}

// GET /api/plugin/fpp-plugin-BackgroundMusic/playlist-details
function fppBackgroundMusicPlaylistDetails() {
    global $settings;
    $pluginConfigFile = $settings['configDirectory'] . "/plugin.fpp-plugin-BackgroundMusic";
    
    $result = array();
    $result['status'] = 'OK';
    $result['tracks'] = array();
    $result['playlistName'] = '';
    $result['totalDuration'] = 0;
    
    // Read plugin configuration
    if (file_exists($pluginConfigFile)) {
        $pluginSettings = parse_ini_file($pluginConfigFile);
        $playlistName = isset($pluginSettings['BackgroundMusicPlaylist']) ? $pluginSettings['BackgroundMusicPlaylist'] : '';
        
        if (!empty($playlistName)) {
            $result['playlistName'] = $playlistName;
            
            // Get playlist file path - FPP playlists are JSON files
            $playlistFile = $settings['playlistDirectory'] . '/' . $playlistName . '.json';
            
            if (file_exists($playlistFile)) {
                $playlistContent = file_get_contents($playlistFile);
                $playlistData = json_decode($playlistContent, true);
                
                if ($playlistData && isset($playlistData['mainPlaylist'])) {
                    $trackNum = 1;
                    foreach ($playlistData['mainPlaylist'] as $item) {
                        // Only include media items that are enabled
                        if ($item['type'] === 'media' && isset($item['enabled']) && $item['enabled'] == 1) {
                            $trackInfo = array();
                            $trackInfo['number'] = $trackNum;
                            $trackInfo['name'] = isset($item['mediaName']) ? $item['mediaName'] : 'Unknown';
                            
                            // Duration is already in the playlist JSON
                            $duration = isset($item['duration']) ? (int)$item['duration'] : 0;
                            $trackInfo['duration'] = $duration;
                            $trackInfo['durationFormatted'] = formatDuration($duration);
                            
                            $result['tracks'][] = $trackInfo;
                            $result['totalDuration'] += $duration;
                            $trackNum++;
                        }
                    }
                    
                    $result['totalDurationFormatted'] = formatDuration($result['totalDuration']);
                    $result['totalTracks'] = count($result['tracks']);
                } else {
                    $result['status'] = 'WARNING';
                    $result['message'] = 'Invalid playlist format';
                }
            } else {
                $result['status'] = 'WARNING';
                $result['message'] = 'Playlist file not found: ' . $playlistFile;
            }
        } else {
            $result['status'] = 'WARNING';
            $result['message'] = 'No background music playlist configured';
        }
    } else {
        $result['status'] = 'ERROR';
        $result['message'] = 'Plugin not configured';
    }
    
    return json($result);
}

function formatDuration($seconds) {
    if ($seconds < 60) {
        return $seconds . 's';
    } else if ($seconds < 3600) {
        $minutes = floor($seconds / 60);
        $secs = $seconds % 60;
        return sprintf('%d:%02d', $minutes, $secs);
    } else {
        $hours = floor($seconds / 3600);
        $minutes = floor(($seconds % 3600) / 60);
        $secs = $seconds % 60;
        return sprintf('%d:%02d:%02d', $hours, $minutes, $secs);
    }
}

// POST /api/plugin/fpp-plugin-BackgroundMusic/play-announcement
function fppBackgroundMusicPlayAnnouncement() {
    global $settings;
    $pluginConfigFile = $settings['configDirectory'] . "/plugin.fpp-plugin-BackgroundMusic";
    
    // Load plugin config
    if (!file_exists($pluginConfigFile)) {
        return json(array('status' => 'ERROR', 'message' => 'Plugin not configured'));
    }
    
    $pluginSettings = parse_ini_file($pluginConfigFile);
    
    // Get input data
    $input = json_decode(file_get_contents('php://input'), true);
    $buttonNumber = isset($input['buttonNumber']) ? intval($input['buttonNumber']) : 0;
    
    if ($buttonNumber < 1 || $buttonNumber > 5) {
        return json(array('status' => 'ERROR', 'message' => 'Invalid button number'));
    }
    
    // Get announcement configuration
    $announcementFile = isset($pluginSettings['PSAButton' . $buttonNumber . 'File']) ? $pluginSettings['PSAButton' . $buttonNumber . 'File'] : '';
    $announcementLabel = isset($pluginSettings['PSAButton' . $buttonNumber . 'Label']) ? $pluginSettings['PSAButton' . $buttonNumber . 'Label'] : 'PSA #' . $buttonNumber;
    $announcementVolume = isset($pluginSettings['PSAAnnouncementVolume']) ? intval($pluginSettings['PSAAnnouncementVolume']) : 90;
    $duckVolume = isset($pluginSettings['PSADuckVolume']) ? intval($pluginSettings['PSADuckVolume']) : 30;
    
    if (empty($announcementFile)) {
        return json(array('status' => 'ERROR', 'message' => 'Announcement button not configured'));
    }
    
    if (!file_exists($announcementFile)) {
        return json(array('status' => 'ERROR', 'message' => 'Announcement file not found: ' . $announcementFile));
    }
    
    // Call the play_announcement script
    $scriptPath = dirname(__FILE__) . '/scripts/play_announcement.sh';
    $output = array();
    $returnCode = 0;
    
    $cmd = "/bin/bash " . escapeshellarg($scriptPath) . " " . 
           escapeshellarg($announcementFile) . " " . 
           escapeshellarg($duckVolume) . " " . 
           escapeshellarg($announcementVolume) . " " . 
           escapeshellarg($buttonNumber) . " " . 
           escapeshellarg($announcementLabel) . " 2>&1";
    
    exec($cmd, $output, $returnCode);
    
    if ($returnCode === 0) {
        return json(array('status' => 'OK', 'message' => 'Announcement started'));
    } else {
        return json(array('status' => 'ERROR', 'message' => 'Failed to play announcement', 'details' => implode("\n", $output)));
    }
}

// POST /api/plugin/fpp-plugin-BackgroundMusic/stop-announcement
function fppBackgroundMusicStopAnnouncement() {
    $pidFile = '/tmp/announcement_player.pid';
    
    if (!file_exists($pidFile)) {
        return json(array('status' => 'OK', 'message' => 'No announcement playing'));
    }
    
    $pid = trim(file_get_contents($pidFile));
    
    // Kill the announcement process
    exec("kill $pid 2>&1", $output, $returnCode);
    
    // Clean up PID file
    @unlink($pidFile);
    
    return json(array('status' => 'OK', 'message' => 'Announcement stopped'));
}

// GET /api/plugin/fpp-plugin-BackgroundMusic/psa-status
function fppBackgroundMusicPSAStatus() {
    $pidFile = '/tmp/announcement_player.pid';
    $statusFile = '/tmp/announcement_status.txt';
    $playing = false;
    $buttonNumber = 0;
    $buttonLabel = '';
    $announcementFile = '';
    $duration = 0;
    $elapsed = 0;
    $progress = 0;
    $maxDuration = 300; // 5 minutes max for any announcement
    
    if (file_exists($pidFile)) {
        $pid = trim(file_get_contents($pidFile));
        // Check if process is actually running
        exec("ps -p $pid > /dev/null 2>&1", $output, $returnCode);
        $playing = ($returnCode === 0);
        
        // If playing, read status information
        if ($playing && file_exists($statusFile)) {
            $statusData = parse_ini_file($statusFile);
            if ($statusData) {
                $buttonNumber = isset($statusData['buttonNumber']) ? intval($statusData['buttonNumber']) : 0;
                $buttonLabel = isset($statusData['buttonLabel']) ? $statusData['buttonLabel'] : '';
                $announcementFile = isset($statusData['announcementFile']) ? $statusData['announcementFile'] : '';
                $duration = isset($statusData['duration']) ? intval($statusData['duration']) : 0;
                
                // Calculate elapsed time and progress
                if (isset($statusData['startTime'])) {
                    $startTime = intval($statusData['startTime']);
                    $elapsed = time() - $startTime;
                    
                    // Calculate progress percentage
                    if ($duration > 0) {
                        $progress = min(100, round(($elapsed / $duration) * 100));
                    }
                    
                    // Check if announcement has been running too long (stuck)
                    if ($elapsed > $maxDuration) {
                        error_log("BackgroundMusic: PSA stuck for $elapsed seconds, killing process $pid");
                        // Kill stuck process
                        exec("kill $pid 2>&1");
                        $playing = false;
                    }
                }
            }
        }
        
        // If not playing but PID file exists, clean it up
        if (!$playing) {
            @unlink($pidFile);
            @unlink($statusFile);
        }
    } else {
        // No PID file - ensure status file is also cleaned up
        if (file_exists($statusFile)) {
            @unlink($statusFile);
        }
    }
    
    $result = array(
        'status' => 'OK',
        'playing' => $playing,
        'buttonNumber' => $buttonNumber,
        'buttonLabel' => $buttonLabel,
        'announcementFile' => $announcementFile,
        'duration' => $duration,
        'elapsed' => $elapsed,
        'progress' => $progress
    );
    
    return json($result);
}

// GET /api/plugin/fpp-plugin-BackgroundMusic/check-update
function fppBackgroundMusicCheckUpdate() {
    $pluginDir = dirname(__FILE__);
    $result = array(
        'status' => 'OK',
        'hasUpdate' => false,
        'currentCommit' => '',
        'latestCommit' => '',
        'currentCommitShort' => '',
        'latestCommitShort' => '',
        'behindBy' => 0,
        'lastChecked' => time(),
        'canConnect' => false,
        'branch' => 'master',
        'repoURL' => 'https://github.com/OnlineDynamic/BackgroundMusicFPP-Plugin'
    );
    
    // Determine which branch to check based on FPP version
    $pluginInfoFile = $pluginDir . '/pluginInfo.json';
    $branch = 'master'; // Default fallback
    
    if (file_exists($pluginInfoFile)) {
        $pluginInfo = json_decode(file_get_contents($pluginInfoFile), true);
        if ($pluginInfo && isset($pluginInfo['versions']) && is_array($pluginInfo['versions'])) {
            // Get FPP version
            $fppVersion = getFPPVersion();
            $fppVersionParts = explode('.', $fppVersion);
            $fppMajor = isset($fppVersionParts[0]) ? intval($fppVersionParts[0]) : 0;
            $fppMinor = isset($fppVersionParts[1]) ? intval($fppVersionParts[1]) : 0;
            
            // Find matching version config
            foreach ($pluginInfo['versions'] as $versionConfig) {
                $minFPP = isset($versionConfig['minFPPVersion']) ? $versionConfig['minFPPVersion'] : '0.0';
                $maxFPP = isset($versionConfig['maxFPPVersion']) ? $versionConfig['maxFPPVersion'] : '0';
                $configBranch = isset($versionConfig['branch']) ? $versionConfig['branch'] : 'master';
                
                $minParts = explode('.', $minFPP);
                $minMajor = isset($minParts[0]) ? intval($minParts[0]) : 0;
                $minMinor = isset($minParts[1]) ? intval($minParts[1]) : 0;
                
                // Check if FPP version >= minFPPVersion
                $meetsMin = ($fppMajor > $minMajor) || ($fppMajor == $minMajor && $fppMinor >= $minMinor);
                
                // Check maxFPPVersion (0 means no maximum)
                $meetsMax = false;
                if ($maxFPP === '0' || $maxFPP === 0) {
                    $meetsMax = true;
                } else {
                    $maxParts = explode('.', $maxFPP);
                    $maxMajor = isset($maxParts[0]) ? intval($maxParts[0]) : 0;
                    $maxMinor = isset($maxParts[1]) ? intval($maxParts[1]) : 0;
                    $meetsMax = ($fppMajor < $maxMajor) || ($fppMajor == $maxMajor && $fppMinor <= $maxMinor);
                }
                
                if ($meetsMin && $meetsMax) {
                    $branch = $configBranch;
                    break;
                }
            }
        }
    }
    
    $result['branch'] = $branch;
    
    // Check if we can connect to the internet (check GitHub)
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, "https://github.com");
    curl_setopt($ch, CURLOPT_NOBODY, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, 3);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    $result['canConnect'] = ($httpCode >= 200 && $httpCode < 400);
    
    if (!$result['canConnect']) {
        $result['message'] = 'Cannot connect to GitHub - check internet connection';
        return json($result);
    }
    
    // Get current commit hash
    $currentCommit = trim(shell_exec("cd " . escapeshellarg($pluginDir) . " && git rev-parse HEAD 2>/dev/null"));
    if (empty($currentCommit)) {
        $result['status'] = 'ERROR';
        $result['message'] = 'Failed to get current git commit';
        return json($result);
    }
    
    $result['currentCommit'] = $currentCommit;
    $result['currentCommitShort'] = substr($currentCommit, 0, 7);
    
    // Fetch latest from remote for the appropriate branch
    exec("cd " . escapeshellarg($pluginDir) . " && git fetch origin " . escapeshellarg($branch) . " 2>&1", $fetchOutput, $fetchReturn);
    
    if ($fetchReturn !== 0) {
        $result['status'] = 'ERROR';
        $result['message'] = 'Failed to fetch updates from remote repository';
        return json($result);
    }
    
    // Get latest commit hash from remote branch
    $latestCommit = trim(shell_exec("cd " . escapeshellarg($pluginDir) . " && git rev-parse origin/" . escapeshellarg($branch) . " 2>/dev/null"));
    if (empty($latestCommit)) {
        $result['status'] = 'ERROR';
        $result['message'] = 'Failed to get latest commit from remote';
        return json($result);
    }
    
    $result['latestCommit'] = $latestCommit;
    $result['latestCommitShort'] = substr($latestCommit, 0, 7);
    
    // Check if we're behind
    if ($currentCommit !== $latestCommit) {
        $result['hasUpdate'] = true;
        
        // Get number of commits behind
        $behindCount = trim(shell_exec("cd " . escapeshellarg($pluginDir) . " && git rev-list --count HEAD..origin/" . escapeshellarg($branch) . " 2>/dev/null"));
        $result['behindBy'] = intval($behindCount);
        
        // Get latest commit details
        $commitInfo = shell_exec("cd " . escapeshellarg($pluginDir) . " && git log origin/" . escapeshellarg($branch) . " -1 --pretty=format:'%s|%an|%ar' 2>/dev/null");
        if (!empty($commitInfo)) {
            $parts = explode('|', $commitInfo);
            $result['latestCommitMessage'] = isset($parts[0]) ? $parts[0] : '';
            $result['latestCommitAuthor'] = isset($parts[1]) ? $parts[1] : '';
            $result['latestCommitDate'] = isset($parts[2]) ? $parts[2] : '';
        }
    }
    
    return json($result);
}

// POST /api/plugin/fpp-plugin-BackgroundMusic/reorder-playlist
function fppBackgroundMusicReorderPlaylist() {
    global $settings;
    $pluginConfigFile = $settings['configDirectory'] . "/plugin.fpp-plugin-BackgroundMusic";
    
    // Get POST data
    $input = json_decode(file_get_contents('php://input'), true);
    $trackOrder = isset($input['trackOrder']) ? $input['trackOrder'] : null;
    
    if (!is_array($trackOrder) || count($trackOrder) === 0) {
        return json(array('status' => 'ERROR', 'message' => 'Invalid track order data'));
    }
    
    // Read plugin configuration to get playlist name
    if (file_exists($pluginConfigFile)) {
        $pluginSettings = parse_ini_file($pluginConfigFile);
        $playlistName = isset($pluginSettings['BackgroundMusicPlaylist']) ? $pluginSettings['BackgroundMusicPlaylist'] : '';
        
        if (empty($playlistName)) {
            return json(array('status' => 'ERROR', 'message' => 'No background music playlist configured'));
        }
        
        // Get playlist file path
        $playlistFile = $settings['playlistDirectory'] . '/' . $playlistName . '.json';
        
        if (!file_exists($playlistFile)) {
            return json(array('status' => 'ERROR', 'message' => 'Playlist file not found'));
        }
        
        // Read and parse playlist
        $playlistContent = file_get_contents($playlistFile);
        $playlistData = json_decode($playlistContent, true);
        
        if (!$playlistData || !isset($playlistData['mainPlaylist'])) {
            return json(array('status' => 'ERROR', 'message' => 'Invalid playlist format'));
        }
        
        // Extract only the media items that are enabled
        $mediaItems = array();
        $otherItems = array();
        foreach ($playlistData['mainPlaylist'] as $item) {
            if ($item['type'] === 'media' && isset($item['enabled']) && $item['enabled'] == 1) {
                $mediaItems[] = $item;
            } else {
                $otherItems[] = $item;
            }
        }
        
        // Verify track order matches the number of media items
        if (count($trackOrder) !== count($mediaItems)) {
            return json(array('status' => 'ERROR', 'message' => 'Track order count does not match playlist'));
        }
        
        // Reorder the media items based on trackOrder array (0-indexed)
        $reorderedMedia = array();
        foreach ($trackOrder as $oldIndex) {
            if (isset($mediaItems[$oldIndex])) {
                $reorderedMedia[] = $mediaItems[$oldIndex];
            }
        }
        
        // Merge back with other items (keep non-media items in their original positions)
        // For simplicity, we'll put all media items first, then other items
        $playlistData['mainPlaylist'] = array_merge($reorderedMedia, $otherItems);
        
        // Write back to file with pretty printing
        $jsonOutput = json_encode($playlistData, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
        if (file_put_contents($playlistFile, $jsonOutput) !== false) {
            // Check if background music is running
            $scriptPath = dirname(__FILE__) . '/scripts/background_music_player.sh';
            exec("/bin/bash " . escapeshellarg($scriptPath) . " status 2>&1", $statusOutput, $statusReturn);
            
            if ($statusReturn === 0) {
                // It's running - regenerate the m3u playlist file so it picks up the new order
                // The player will continue the current track and use the new order afterwards
                $m3uFile = '/tmp/background_music_playlist.m3u';
                $m3uContent = "#EXTM3U\n";
                foreach ($reorderedMedia as $item) {
                    $mediaName = isset($item['mediaName']) ? $item['mediaName'] : '';
                    if (!empty($mediaName)) {
                        $m3uContent .= "/home/fpp/media/music/" . $mediaName . "\n";
                    }
                }
                file_put_contents($m3uFile, $m3uContent);
                
                // Create signal file to tell player that playlist was reordered
                file_put_contents('/tmp/bg_music_reorder.txt', '1');
                
                return json(array('status' => 'OK', 'message' => 'Playlist reordered - will apply after current track'));
            } else {
                return json(array('status' => 'OK', 'message' => 'Playlist reordered successfully'));
            }
        } else {
            return json(array('status' => 'ERROR', 'message' => 'Failed to save playlist file'));
        }
    } else {
        return json(array('status' => 'ERROR', 'message' => 'Plugin not configured'));
    }
}

// GET /api/plugin/fpp-plugin-BackgroundMusic/get-commit-history
function fppBackgroundMusicGetCommitHistory() {
    $pluginDir = dirname(__FILE__);
    
    // Check if this is a Git repository
    if (!is_dir($pluginDir . '/.git')) {
        return json(array(
            'status' => 'ERROR',
            'message' => 'Not a Git repository. This may be a manual installation.',
            'commits' => array()
        ));
    }
    
    // Get the last 50 commits
    $gitCommand = "cd " . escapeshellarg($pluginDir) . " && git log -50 --pretty=format:'%H|%an|%ae|%ad|%s' --date=iso 2>&1";
    $output = array();
    $returnVar = 0;
    
    exec($gitCommand, $output, $returnVar);
    
    if ($returnVar !== 0) {
        return json(array(
            'status' => 'ERROR',
            'message' => 'Failed to execute git log command',
            'commits' => array()
        ));
    }
    
    $commits = array();
    foreach ($output as $line) {
        $parts = explode('|', $line, 5);
        if (count($parts) === 5) {
            $commits[] = array(
                'hash' => $parts[0],
                'author' => $parts[1],
                'email' => $parts[2],
                'date' => $parts[3],
                'message' => $parts[4]
            );
        }
    }
    
    return json(array(
        'status' => 'OK',
        'commits' => $commits,
        'count' => count($commits)
    ));
}

?>
