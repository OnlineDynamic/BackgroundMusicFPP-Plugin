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
    
    // Load plugin config
    if (file_exists($pluginConfigFile)){
        $pluginSettings = parse_ini_file($pluginConfigFile);
    } else {
        $pluginSettings = array();
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
    
    if ($backgroundMusicRunning) {
        $statusFile = '/tmp/bg_music_status.txt';
        if (file_exists($statusFile)) {
            $statusData = parse_ini_file($statusFile);
            if ($statusData) {
                $currentTrack = isset($statusData['filename']) ? $statusData['filename'] : '';
                $trackDuration = isset($statusData['duration']) ? intval($statusData['duration']) : 0;
                $trackElapsed = isset($statusData['elapsed']) ? intval($statusData['elapsed']) : 0;
                $trackProgress = isset($statusData['progress']) ? intval($statusData['progress']) : 0;
            }
        }
    }
    
    $showRunning = ($currentPlaylist === $showPlaylist && $currentPlaylist !== '');
    
    // Check if fpp-brightness plugin is installed (required for transitions)
    $brightnessPluginInstalled = file_exists('/home/fpp/media/plugins/fpp-brightness/libfpp-brightness.so');
    
    $result = array(
        'backgroundMusicRunning' => $backgroundMusicRunning,
        'showRunning' => $showRunning,
        'brightness' => intval($brightness),
        'brightnessPluginInstalled' => $brightnessPluginInstalled,
        'currentPlaylist' => $currentPlaylist,
        'fppStatus' => $fppStatus,
        'currentSequence' => $currentSequence,
        'currentTrack' => $currentTrack,
        'trackDuration' => $trackDuration,
        'trackElapsed' => $trackElapsed,
        'trackProgress' => $trackProgress,
        'config' => array(
            'backgroundMusicPlaylist' => $backgroundMusicPlaylist,
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
    
    $backgroundMusicPlaylist = isset($pluginSettings['BackgroundMusicPlaylist']) ? $pluginSettings['BackgroundMusicPlaylist'] : '';
    
    if (empty($backgroundMusicPlaylist)) {
        return json(array('status' => 'ERROR', 'message' => 'Background music playlist not configured'));
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
    // This does NOT stop any FPP playlists (sequences continue running)
    $scriptPath = dirname(__FILE__) . '/scripts/background_music_player.sh';
    $output = array();
    $returnCode = 0;
    exec("/bin/bash " . escapeshellarg($scriptPath) . " stop 2>&1", $output, $returnCode);
    
    return json(array('status' => 'OK', 'message' => 'Background music stopped'));
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
    $cmd = sprintf('/bin/bash %s %d %d %s > /dev/null 2>&1 &', 
        escapeshellarg($scriptPath), 
        $fadeTime, 
        $blackoutTime, 
        escapeshellarg($showPlaylist));
    
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
           escapeshellarg($announcementVolume) . " 2>&1";
    
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
    $playing = false;
    $currentFile = '';
    
    if (file_exists($pidFile)) {
        $pid = trim(file_get_contents($pidFile));
        // Check if process is actually running
        exec("ps -p $pid > /dev/null 2>&1", $output, $returnCode);
        $playing = ($returnCode === 0);
        
        // If not playing but PID file exists, clean it up
        if (!$playing) {
            @unlink($pidFile);
        }
    }
    
    $result = array(
        'status' => 'OK',
        'playing' => $playing,
        'currentFile' => $currentFile
    );
    
    return json($result);
}

?>
