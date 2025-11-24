<?php
include_once("/opt/fpp/www/common.php");
$pluginName = "fpp-plugin-BackgroundMusic";
$pluginConfigFile = $settings['configDirectory'] . "/plugin." . $pluginName;

// Load current settings
if (file_exists($pluginConfigFile)){
    if (is_readable($pluginConfigFile)) {
        $pluginSettings = parse_ini_file($pluginConfigFile);
        if ($pluginSettings === false) {
            error_log("BackgroundMusic: parse_ini_file failed for $pluginConfigFile");
            $pluginSettings = array();
        } else {
            error_log("BackgroundMusic: Successfully loaded config with " . count($pluginSettings) . " settings");
            // Trim whitespace from all values
            $pluginSettings = array_map('trim', $pluginSettings);
        }
    } else {
        error_log("BackgroundMusic: Config file exists but is not readable: $pluginConfigFile");
        $pluginSettings = array();
    }
} else {
    error_log("BackgroundMusic: Config file does not exist: $pluginConfigFile");
    $pluginSettings = array();
}

// Get audio files from music directory
function getAudioFiles() {
    $musicDir = '/home/fpp/media/music';
    $audioFiles = array();
    
    if (is_dir($musicDir)) {
        $files = scandir($musicDir);
        foreach ($files as $file) {
            if ($file != '.' && $file != '..') {
                $ext = strtolower(pathinfo($file, PATHINFO_EXTENSION));
                if (in_array($ext, array('mp3', 'wav', 'ogg', 'm4a', 'flac'))) {
                    $audioFiles[] = $file;
                }
            }
        }
        sort($audioFiles);
    }
    
    return $audioFiles;
}

// Get playlists
function getPlaylists() {
    $ch = curl_init('http://localhost/api/playlists');
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_HEADER, 0);
    $data = curl_exec($ch);
    curl_close($ch);
    $result = json_decode($data, true);
    // FPP API returns a simple array of playlist names
    if (is_array($result)) {
        return $result;
    }
    return array();
}

// Check if a playlist contains only media items (no sequences) and is not empty
function isMediaOnlyPlaylist($playlistName) {
    $ch = curl_init('http://localhost/api/playlist/' . rawurlencode($playlistName));
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_HEADER, 0);
    $data = curl_exec($ch);
    curl_close($ch);
    $playlist = json_decode($data, true);
    
    if (!isset($playlist['mainPlaylist']) || !is_array($playlist['mainPlaylist'])) {
        return false;
    }
    
    // Check if playlist has items (don't rely on 'empty' flag - it can be incorrect for m4a files)
    if (count($playlist['mainPlaylist']) == 0) {
        return false;
    }
    
    // Check if all items are media type
    foreach ($playlist['mainPlaylist'] as $item) {
        if (!isset($item['type']) || $item['type'] !== 'media') {
            return false;
        }
    }
    
    return true;
}

// Check if a playlist has any items
function hasPlaylistItems($playlistName) {
    $ch = curl_init('http://localhost/api/playlist/' . rawurlencode($playlistName));
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_HEADER, 0);
    $data = curl_exec($ch);
    curl_close($ch);
    $playlist = json_decode($data, true);
    
    // Check mainPlaylist array directly (don't rely on 'empty' flag - it can be incorrect for m4a files)
    if (!isset($playlist['mainPlaylist']) || !is_array($playlist['mainPlaylist'])) {
        return false;
    }
    
    return count($playlist['mainPlaylist']) > 0;
}

// Filter playlists - get media-only for background music, all for others
function getMediaOnlyPlaylists($allPlaylists) {
    $mediaPlaylists = array();
    foreach ($allPlaylists as $playlistName) {
        if (isMediaOnlyPlaylist($playlistName)) {
            $mediaPlaylists[] = $playlistName;
        }
    }
    return $mediaPlaylists;
}

// Filter out empty playlists
function filterNonEmptyPlaylists($playlists) {
    $nonEmptyPlaylists = array();
    foreach ($playlists as $playlistName) {
        if (hasPlaylistItems($playlistName)) {
            $nonEmptyPlaylists[] = $playlistName;
        }
    }
    return $nonEmptyPlaylists;
}

$allPlaylists = getPlaylists();
// Filter out empty playlists from all playlists first
$allPlaylists = filterNonEmptyPlaylists($allPlaylists);
// Then get media-only playlists (which already excludes empty ones)
$mediaOnlyPlaylists = getMediaOnlyPlaylists($allPlaylists);

// Get audio files for PSA configuration
$audioFiles = getAudioFiles();
?>

<style>
    .settingsTable {
        width: 100%;
        max-width: 800px;
        margin: 20px auto;
    }
    .settingsTable td {
        padding: 10px;
    }
    .settingsTable .label {
        width: 40%;
        font-weight: bold;
        text-align: right;
    }
    .settingsTable .value {
        width: 60%;
    }
    .settingsTable select, .settingsTable input[type="number"], .settingsTable input[type="text"] {
        width: 100%;
        padding: 5px;
    }
    .settingsTable input[type="checkbox"] {
        width: 18px;
        height: 18px;
        margin: 0;
        vertical-align: middle;
        cursor: pointer;
        transform: scale(1.3);
        margin-right: 8px;
    }
    .settingsTable label {
        margin-left: 8px;
        vertical-align: middle;
        cursor: pointer;
    }
    .buttonRow {
        text-align: center;
        margin-top: 20px;
    }
    .description {
        max-width: 800px;
        margin: 20px auto;
        padding: 15px;
        background-color: #f0f8ff;
        border: 1px solid #b0d4f1;
        border-radius: 5px;
    }
    .config-header {
        position: sticky;
        top: 60px;
        z-index: 100;
        background-color: #fff;
        padding: 15px 0;
        margin-bottom: 20px;
        border-bottom: 2px solid #e0e0e0;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }
</style>

<div id="global" class="settings">
    <div class="config-header">
        <div style="display: flex; justify-content: space-between; align-items: center;">
            <h1 style="margin: 0;">Background Music Configuration</h1>
            <div>
                <button type="submit" form="settingsForm" class="btn btn-success" style="margin-right: 5px;">
                    <i class="fas fa-save"></i> Save Settings
                </button>
                <a href="plugin.php?_menu=status&plugin=fpp-plugin-BackgroundMusic&page=backgroundmusic.php" class="btn btn-outline-secondary" style="margin-right: 5px;">
                    <i class="fas fa-arrow-left"></i> Controller
                </a>
                <a href="plugin.php?plugin=fpp-plugin-BackgroundMusic&page=help%2Fbackgroundmusic-help.php" class="btn btn-outline-info">
                    <i class="fas fa-question-circle"></i> Help
                </a>
            </div>
        </div>
    </div>
    
    <!-- Brightness Plugin Warning -->
    <div style="background-color: #fff3cd; border: 2px solid #ffc107; border-radius: 5px; padding: 15px; margin: 20px auto; max-width: 800px;">
        <h3 style="margin-top: 0; color: #856404;"><i class="fas fa-exclamation-triangle"></i> Required: fpp-brightness Plugin</h3>
        <p style="margin-bottom: 10px;">
            This plugin requires the <strong>fpp-brightness</strong> plugin to be installed on <strong>ALL controllers</strong> 
            in your setup for brightness transitions and MultiSync to work properly.
        </p>
        <p style="margin-bottom: 0;">
            <strong>Installation:</strong> On each controller (master and remotes), go to <em>Plugin Manager → Install Plugins</em> 
            and search for "brightness". Install on <strong>every controller</strong> in your show, then restart FPPd.
        </p>
    </div>
        
<div class="description">
    <p><strong>How it works:</strong></p>
    <ul>
        <li><strong>Background Music Source:</strong> Choose between a local FPP Playlist (audio files you upload) or an Internet Radio Stream (continuous online audio). The selected source plays over your existing pre-show sequence (already running via FPP scheduler).</li>
        <li><strong>Show Playlist:</strong> Main show playlist to start after the fade transition.</li>
        <li><strong>Fade Time:</strong> Duration to gradually fade out both brightness and background music before the show.</li>
        <li><strong>Blackout Time:</strong> Silent period after fade before starting the show (for dramatic effect).</li>
        <li><strong>Return to Pre-Show:</strong> After the show completes, background music (playlist or stream) automatically restarts. Your scheduler will handle restarting the pre-show sequence.</li>
        <li><strong>Playlist Mode:</strong> Supports shuffle, track control, and playlist management.</li>
        <li><strong>Stream Mode:</strong> Plays a continuous audio stream (no shuffle or track control). Auto-reconnects if the stream drops.</li>
        <li><strong>Seamless Track Transitions:</strong> Enable crossfading to eliminate silence between tracks. The next track starts playing before the current one ends, creating smooth, continuous playback perfect for maintaining atmosphere.</li>
    </ul>
    <p><strong>Expected Setup:</strong> Your pre-show sequence (or non media playlist) should already be running (looping) via FPP's scheduler. This plugin adds background music on top.</p>
</div>        <form id="settingsForm" onsubmit="return saveSettings();">
            <!-- Background Music Source Selection -->
            <h3 style="margin: 30px auto 10px; max-width: 800px; color: #2196F3; border-bottom: 2px solid #2196F3; padding-bottom: 5px;">
                <i class="fas fa-list"></i> Background Music Source Selection
            </h3>
            <table class="settingsTable">
                <tr>
                    <td class="label">Background Music Source:</td>
                    <td class="value">
                        <select name="BackgroundMusicSource" id="BackgroundMusicSource" onchange="toggleBackgroundSource()">
                            <?php
                            $bgSource = isset($pluginSettings['BackgroundMusicSource']) ? $pluginSettings['BackgroundMusicSource'] : 'playlist';
                            ?>
                            <option value="playlist" <?php echo ($bgSource == 'playlist') ? 'selected' : ''; ?>>FPP Playlist</option>
                            <option value="stream" <?php echo ($bgSource == 'stream') ? 'selected' : ''; ?>>Internet Stream</option>
                        </select>
                        <small>Choose between local playlist or internet audio stream</small>
                    </td>
                </tr>
                <tr id="playlistRow" style="<?php echo ($bgSource == 'stream') ? 'display: none;' : ''; ?>">
                    <td class="label">Background Music Playlist:</td>
                    <td class="value">
                        <select name="BackgroundMusicPlaylist" id="BackgroundMusicPlaylist">
                            <option value="">-- Select Playlist --</option>
                            <?php
                            $savedBgPlaylist = isset($pluginSettings['BackgroundMusicPlaylist']) ? $pluginSettings['BackgroundMusicPlaylist'] : '';
                            error_log("BackgroundMusic: Saved BG Playlist: '" . $savedBgPlaylist . "'");
                            foreach ($mediaOnlyPlaylists as $playlist) {
                                $selected = '';
                                if ($savedBgPlaylist != '' && $savedBgPlaylist == $playlist) {
                                    $selected = 'selected';
                                    error_log("BackgroundMusic: Matched BG playlist: '" . $playlist . "'");
                                }
                                echo '<option value="' . htmlspecialchars($playlist) . '" ' . $selected . '>' . 
                                     htmlspecialchars($playlist) . '</option>';
                            }
                            ?>
                        </select>
                        <small>Audio playlist to play as background music (media-only playlists)</small>
                    </td>
                </tr>
                <tr id="streamRow" style="<?php echo ($bgSource == 'playlist') ? 'display: none;' : ''; ?>">
                    <td class="label">Stream URL:</td>
                    <td class="value">
                        <select name="BackgroundMusicStreamPreset" id="BackgroundMusicStreamPreset" 
                                onchange="handleStreamPresetChange()" style="width: 100%; max-width: 600px; margin-bottom: 5px;">
                            <?php
                            $currentStreamURL = isset($pluginSettings['BackgroundMusicStreamURL']) ? $pluginSettings['BackgroundMusicStreamURL'] : '';
                            $isCustom = true;
                            
                            // Load preset streams from JSON file
                            $presetsFile = __DIR__ . '/stream_presets.json';
                            $presets = array();
                            
                            if (file_exists($presetsFile)) {
                                $jsonContent = file_get_contents($presetsFile);
                                $presetsData = json_decode($jsonContent, true);
                                
                                if ($presetsData && isset($presetsData['presets'])) {
                                    foreach ($presetsData['presets'] as $preset) {
                                        if (isset($preset['url']) && isset($preset['name'])) {
                                            $presets[$preset['url']] = $preset['name'];
                                        }
                                    }
                                }
                            }
                            
                            // Fallback to hardcoded preset if JSON file doesn't exist or is invalid
                            if (empty($presets)) {
                                $presets = array(
                                    'https://radio.themillerlights.com:8000/radio.mp3' => 'The Miller Lights Holiday Radio'
                                );
                            }
                            
                            // Check if current URL matches a preset
                            foreach ($presets as $url => $name) {
                                if ($currentStreamURL === $url) {
                                    $isCustom = false;
                                    break;
                                }
                            }
                            ?>
                            <option value="">-- Select Stream or Enter Custom --</option>
                            <?php foreach ($presets as $url => $name): ?>
                                <option value="<?php echo htmlspecialchars($url); ?>" 
                                        <?php echo ($currentStreamURL === $url) ? 'selected' : ''; ?>>
                                    <?php echo htmlspecialchars($name); ?>
                                </option>
                            <?php endforeach; ?>
                            <option value="custom" <?php echo $isCustom && !empty($currentStreamURL) ? 'selected' : ''; ?>>
                                Custom URL...
                            </option>
                        </select>
                        <div id="customStreamURLContainer" style="<?php echo (!$isCustom || empty($currentStreamURL)) ? 'display: none;' : ''; ?> margin-top: 5px;">
                            <input type="text" id="BackgroundMusicStreamURLInput" 
                                   value="<?php echo $isCustom ? htmlspecialchars($currentStreamURL) : ''; ?>" 
                                   style="width: 100%; max-width: 600px;" 
                                   placeholder="https://example.com:8000/stream.mp3">
                        </div>
                        <small>Select a preset stream or enter your own URL (HTTP/HTTPS)</small>
                    </td>
                </tr>
                <tr id="shuffleRow" style="<?php echo ($bgSource == 'stream') ? 'display: none;' : ''; ?>">
                    <td class="label">Shuffle Music Playlist:</td>
                    <td class="value">
                        <div style="display: flex; align-items: flex-start; gap: 10px;">
                            <input type="checkbox" name="ShuffleMusic" id="ShuffleMusic" value="1"
                                   <?php echo (isset($pluginSettings['ShuffleMusic']) && $pluginSettings['ShuffleMusic'] == '1') ? 'checked' : ''; ?>>
                            <label for="ShuffleMusic" style="margin: 0; line-height: 1.4;">
                                Randomly shuffle background music tracks for variety
                            </label>
                        </div>
                        <small>Playlist is reshuffled each time it loops to avoid gaps</small>
                    </td>
                </tr>
                <tr id="crossfadeRow" style="<?php echo ($bgSource == 'stream') ? 'display: none;' : ''; ?>">
                    <td class="label">Seamless Track Transitions:</td>
                    <td class="value">
                        <div style="display: flex; align-items: flex-start; gap: 10px;">
                            <input type="checkbox" name="EnableCrossfade" id="EnableCrossfade" value="1"
                                   onchange="toggleCrossfadeOptions()"
                                   <?php echo (isset($pluginSettings['EnableCrossfade']) && $pluginSettings['EnableCrossfade'] == '1') ? 'checked' : ''; ?>>
                            <label for="EnableCrossfade" style="margin: 0; line-height: 1.4;">
                                Enable crossfading to eliminate silence between tracks
                            </label>
                        </div>
                        <small>Smoothly blend tracks together for continuous playback</small>
                    </td>
                </tr>
                <tr id="crossfadeDurationRow" style="<?php echo ($bgSource == 'stream' || !isset($pluginSettings['EnableCrossfade']) || $pluginSettings['EnableCrossfade'] != '1') ? 'display: none;' : ''; ?>">
                    <td class="label">Crossfade Duration (seconds):</td>
                    <td class="value">
                        <input type="number" name="CrossfadeDuration" id="CrossfadeDuration" min="1" max="10" step="0.5"
                               value="<?php echo isset($pluginSettings['CrossfadeDuration']) ? $pluginSettings['CrossfadeDuration'] : '3'; ?>">
                        <small>Length of overlap between tracks (1-10 seconds). Recommended: 3-4 seconds</small>
                    </td>
                </tr>
            </table>

            <!-- Main Show Configuration -->
            <h3 style="margin: 30px auto 10px; max-width: 800px; color: #ff9800; border-bottom: 2px solid #ff9800; padding-bottom: 5px;">
                <i class="fas fa-star"></i> Main Show Configuration
            </h3>
            <table class="settingsTable">
                <tr>
                    <td class="label">Main Show Playlist:</td>
                    <td class="value">
                        <select name="ShowPlaylist" id="ShowPlaylist">
                            <option value="">-- Select Playlist --</option>
                            <?php
                            $savedShowPlaylist = isset($pluginSettings['ShowPlaylist']) ? $pluginSettings['ShowPlaylist'] : '';
                            error_log("BackgroundMusic: Saved Show Playlist: '" . $savedShowPlaylist . "'");
                            foreach ($allPlaylists as $playlist) {
                                $selected = '';
                                if ($savedShowPlaylist != '' && $savedShowPlaylist == $playlist) {
                                    $selected = 'selected';
                                    error_log("BackgroundMusic: Matched Show playlist: '" . $playlist . "'");
                                }
                                echo '<option value="' . htmlspecialchars($playlist) . '" ' . $selected . '>' . 
                                     htmlspecialchars($playlist) . '</option>';
                            }
                            ?>
                        </select>
                        <small>Main show playlist to start after fade and blackout</small>
                    </td>
                </tr>
            </table>

            <!-- Volume Settings -->
            <h3 style="margin: 30px auto 10px; max-width: 800px; color: #4CAF50; border-bottom: 2px solid #4CAF50; padding-bottom: 5px;">
                <i class="fas fa-volume-up"></i> Volume Settings
            </h3>
            <table class="settingsTable">
                <tr>
                    <td class="label">Background Music Volume (%):</td>
                    <td class="value">
                        <input type="number" name="BackgroundMusicVolume" id="BackgroundMusicVolume" min="0" max="100" 
                               value="<?php echo isset($pluginSettings['BackgroundMusicVolume']) ? $pluginSettings['BackgroundMusicVolume'] : '70'; ?>">
                        <small>Volume level for background music during pre-show (0-100%). Use the main control page to adjust in real-time.</small>
                    </td>
                </tr>
                <tr>
                    <td class="label">Show Playlist Volume (%):</td>
                    <td class="value">
                        <input type="number" name="ShowPlaylistVolume" id="ShowPlaylistVolume" min="0" max="100" 
                               value="<?php echo isset($pluginSettings['ShowPlaylistVolume']) ? $pluginSettings['ShowPlaylistVolume'] : '100'; ?>">
                        <small>System (ALSA) volume for main show sequences (0-100%). FPP's volume slider will still work at this level.</small>
                    </td>
                </tr>
                <tr>
                    <td class="label">Post-Show Background Volume (%):</td>
                    <td class="value">
                        <input type="number" name="PostShowBackgroundVolume" id="PostShowBackgroundVolume" min="0" max="100" 
                               value="<?php echo isset($pluginSettings['PostShowBackgroundVolume']) ? $pluginSettings['PostShowBackgroundVolume'] : '70'; ?>">
                        <small>Volume level for background music after show ends (often lower to wind down)</small>
                    </td>
                </tr>
            </table>

            <!-- Show Transition Settings -->
            <h3 style="margin: 30px auto 10px; max-width: 800px; color: #FF9800; border-bottom: 2px solid #FF9800; padding-bottom: 5px;">
                <i class="fas fa-adjust"></i> Show Transition Settings
            </h3>
            <table class="settingsTable">
                <tr>
                    <td class="label">Fade Out Time (seconds):</td>
                    <td class="value">
                        <input type="number" name="FadeTime" id="FadeTime" min="1" max="60" 
                               value="<?php echo isset($pluginSettings['FadeTime']) ? $pluginSettings['FadeTime'] : '5'; ?>">
                        <small>Time in seconds to fade out brightness and volume</small>
                    </td>
                </tr>
                <tr>
                    <td class="label">Blackout Duration (seconds):</td>
                    <td class="value">
                        <input type="number" name="BlackoutTime" id="BlackoutTime" min="0" max="30" 
                               value="<?php echo isset($pluginSettings['BlackoutTime']) ? $pluginSettings['BlackoutTime'] : '2'; ?>">
                        <small>Time in seconds to wait in blackout before starting show</small>
                    </td>
                </tr>
            </table>

            <!-- Plugin Behavior Settings -->
            <h3 style="margin: 30px auto 10px; max-width: 800px; color: #9C27B0; border-bottom: 2px solid #9C27B0; padding-bottom: 5px;">
                <i class="fas fa-redo"></i> Plugin Behavior Settings
            </h3>
            <table class="settingsTable">
                <tr>
                    <td class="label">Return to Pre-Show After Show:</td>
                    <td class="value">
                        <div style="display: flex; align-items: flex-start; gap: 10px;">
                            <input type="checkbox" name="ReturnToPreShow" id="ReturnToPreShow" value="1"
                                   <?php echo (isset($pluginSettings['ReturnToPreShow']) && $pluginSettings['ReturnToPreShow'] == '1') ? 'checked' : ''; ?>>
                            <label for="ReturnToPreShow" style="margin: 0; line-height: 1.4;">
                                Automatically restart background music when show playlist ends
                            </label>
                        </div>
                        <small>Your FPP scheduler should handle restarting the pre-show light sequence</small>
                    </td>
                </tr>
                <tr>
                    <td class="label">Resume Playlist Mode:</td>
                    <td class="value">
                        <select name="ResumeMode" id="ResumeMode">
                            <option value="continue" <?php echo (!isset($pluginSettings['ResumeMode']) || $pluginSettings['ResumeMode'] == 'continue') ? 'selected' : ''; ?>>
                                Continue from Next Track
                            </option>
                            <option value="restart" <?php echo (isset($pluginSettings['ResumeMode']) && $pluginSettings['ResumeMode'] == 'restart') ? 'selected' : ''; ?>>
                                Restart from Beginning
                            </option>
                        </select>
                        <small>Choose whether to continue from the next track or restart the playlist from the beginning after the show ends</small>
                    </td>
                </tr>
                <tr>
                    <td class="label">Post-Show Delay (seconds):</td>
                    <td class="value">
                        <input type="number" name="PostShowDelay" id="PostShowDelay" min="0" max="300" 
                               value="<?php echo isset($pluginSettings['PostShowDelay']) ? $pluginSettings['PostShowDelay'] : '0'; ?>">
                        <small>Time in seconds to wait after show ends before restarting background music</small>
                    </td>
                </tr>
                <tr>
                    <td class="label">Autostart on FPP Boot:</td>
                    <td class="value">
                        <div style="display: flex; align-items: flex-start; gap: 10px;">
                            <input type="checkbox" name="AutostartEnabled" id="AutostartEnabled" value="1"
                                   <?php echo (isset($pluginSettings['AutostartEnabled']) && $pluginSettings['AutostartEnabled'] == '1') ? 'checked' : ''; ?>>
                            <label for="AutostartEnabled" style="margin: 0; line-height: 1.4;">
                                Automatically start background music when FPP starts or restarts
                            </label>
                        </div>
                        <small>When enabled, background music will resume automatically from where it left off (or start fresh if never played)</small>
                    </td>
                </tr>
            </table>

            <!-- Public Service Announcement Settings -->
            <h3 style="margin: 30px auto 10px; max-width: 800px; color: #e91e63; border-bottom: 2px solid #e91e63; padding-bottom: 5px;">
                <i class="fas fa-bullhorn"></i> Public Service Announcements (PSA)
            </h3>
            <div class="description" style="margin-top: 15px;">
                <p><strong>About PSA:</strong> Play pre-recorded announcements over background music. The music volume will be 
                "ducked" (lowered) during announcements, then restored afterward. Announcements play through a separate audio 
                stream that mixes with the background music.</p>
            </div>
            <table class="settingsTable">
                <tr>
                    <td class="label">Announcement Volume (%):</td>
                    <td class="value">
                        <input type="number" name="PSAAnnouncementVolume" id="PSAAnnouncementVolume" min="0" max="100" 
                               value="<?php echo isset($pluginSettings['PSAAnnouncementVolume']) ? $pluginSettings['PSAAnnouncementVolume'] : '90'; ?>">
                        <small>Volume level for playing announcements (0-100%)</small>
                    </td>
                </tr>
                <tr>
                    <td class="label">Ducked Music Volume (%):</td>
                    <td class="value">
                        <input type="number" name="PSADuckVolume" id="PSADuckVolume" min="0" max="100" 
                               value="<?php echo isset($pluginSettings['PSADuckVolume']) ? $pluginSettings['PSADuckVolume'] : '30'; ?>">
                        <small>Volume level to lower background music to during announcements (0-100%)</small>
                    </td>
                </tr>
            </table>
            
            <h4 style="margin: 20px auto 10px; max-width: 800px; color: #555;">
                Configure Announcement Buttons:
                <button type="button" onclick="addPSAButton()" style="float: right; padding: 5px 15px; background: #4caf50; color: white; border: none; border-radius: 4px; cursor: pointer;">
                    <i class="fas fa-plus"></i> Add Button
                </button>
            </h4>
            <table class="settingsTable" id="psaButtonsTable">
                <?php 
                // Determine how many buttons are configured (default to 1)
                $buttonCount = 1;
                for ($i = 1; $i <= 20; $i++) {
                    if (isset($pluginSettings['PSAButton'.$i.'Label']) || isset($pluginSettings['PSAButton'.$i.'File'])) {
                        $buttonCount = $i;
                    }
                }
                if ($buttonCount < 1) $buttonCount = 1; // Always show at least 1
                
                for ($i = 1; $i <= $buttonCount; $i++): 
                ?>
                <tr class="psa-button-row" data-button-num="<?php echo $i; ?>">
                    <td class="label">
                        Button <?php echo $i; ?> Label:
                        <?php if ($i > 1): ?>
                        <button type="button" onclick="removePSAButton(<?php echo $i; ?>)" 
                                style="margin-left: 10px; padding: 2px 8px; background: #f44336; color: white; border: none; border-radius: 3px; cursor: pointer; font-size: 11px;">
                            <i class="fas fa-trash"></i>
                        </button>
                        <?php endif; ?>
                    </td>
                    <td class="value">
                        <input type="text" name="PSAButton<?php echo $i; ?>Label" id="PSAButton<?php echo $i; ?>Label" 
                               placeholder="e.g. Welcome Message" 
                               value="<?php echo isset($pluginSettings['PSAButton'.$i.'Label']) ? htmlspecialchars($pluginSettings['PSAButton'.$i.'Label']) : ''; ?>">
                    </td>
                </tr>
                <tr class="psa-button-row" data-button-num="<?php echo $i; ?>">
                    <td class="label">Button <?php echo $i; ?> MP3 File:</td>
                    <td class="value">
                        <select name="PSAButton<?php echo $i; ?>File" id="PSAButton<?php echo $i; ?>File">
                            <option value="">-- Select Audio File --</option>
                            <?php
                            $currentFile = isset($pluginSettings['PSAButton'.$i.'File']) ? $pluginSettings['PSAButton'.$i.'File'] : '';
                            // Extract just the filename if it's a full path
                            $currentFileName = basename($currentFile);
                            
                            foreach ($audioFiles as $audioFile) {
                                $fullPath = '/home/fpp/media/music/' . $audioFile;
                                $selected = '';
                                // Check if this file matches the saved setting (by filename or full path)
                                if ($currentFile === $fullPath || $currentFileName === $audioFile) {
                                    $selected = 'selected';
                                }
                                echo '<option value="' . htmlspecialchars($fullPath) . '" ' . $selected . '>' . 
                                     htmlspecialchars($audioFile) . '</option>';
                            }
                            ?>
                        </select>
                        <small>Select audio file from /home/fpp/media/music/</small>
                    </td>
                </tr>
                <tr class="psa-button-row psa-spacer" data-button-num="<?php echo $i; ?>"><td colspan="2" style="height: 10px;"></td></tr>
                <?php endfor; ?>
            </table>
            
            <script>
                // Track available audio files for dynamic button creation
                var availableAudioFiles = <?php echo json_encode($audioFiles); ?>;
                var nextButtonNum = <?php echo $buttonCount + 1; ?>;
                
                function addPSAButton() {
                    var buttonNum = nextButtonNum++;
                    var table = document.getElementById('psaButtonsTable');
                    
                    // Create label row
                    var labelRow = table.insertRow(-1);
                    labelRow.className = 'psa-button-row';
                    labelRow.setAttribute('data-button-num', buttonNum);
                    labelRow.innerHTML = 
                        '<td class="label">' +
                        'Button ' + buttonNum + ' Label:' +
                        '<button type="button" onclick="removePSAButton(' + buttonNum + ')" ' +
                        'style="margin-left: 10px; padding: 2px 8px; background: #f44336; color: white; border: none; border-radius: 3px; cursor: pointer; font-size: 11px;">' +
                        '<i class="fas fa-trash"></i>' +
                        '</button>' +
                        '</td>' +
                        '<td class="value">' +
                        '<input type="text" name="PSAButton' + buttonNum + 'Label" id="PSAButton' + buttonNum + 'Label" ' +
                        'placeholder="e.g. Welcome Message" value="">' +
                        '</td>';
                    
                    // Create file row
                    var fileRow = table.insertRow(-1);
                    fileRow.className = 'psa-button-row';
                    fileRow.setAttribute('data-button-num', buttonNum);
                    
                    var options = '<option value="">-- Select Audio File --</option>';
                    availableAudioFiles.forEach(function(audioFile) {
                        var fullPath = '/home/fpp/media/music/' + audioFile;
                        options += '<option value="' + fullPath.replace(/"/g, '&quot;') + '">' + 
                                   audioFile.replace(/</g, '&lt;').replace(/>/g, '&gt;') + '</option>';
                    });
                    
                    fileRow.innerHTML = 
                        '<td class="label">Button ' + buttonNum + ' MP3 File:</td>' +
                        '<td class="value">' +
                        '<select name="PSAButton' + buttonNum + 'File" id="PSAButton' + buttonNum + 'File">' +
                        options +
                        '</select>' +
                        '<small>Select audio file from /home/fpp/media/music/</small>' +
                        '</td>';
                    
                    // Create spacer row
                    var spacerRow = table.insertRow(-1);
                    spacerRow.className = 'psa-button-row psa-spacer';
                    spacerRow.setAttribute('data-button-num', buttonNum);
                    spacerRow.innerHTML = '<td colspan="2" style="height: 10px;"></td>';
                    
                    $.jGrowl('Button ' + buttonNum + ' added', {themeState: 'success'});
                }
                
                function removePSAButton(buttonNum) {
                    if (buttonNum === 1) {
                        $.jGrowl('Cannot remove button 1', {themeState: 'danger'});
                        return;
                    }
                    
                    if (confirm('Remove button ' + buttonNum + '? This will delete the configuration.')) {
                        // Remove all rows with this button number
                        var rows = document.querySelectorAll('.psa-button-row[data-button-num="' + buttonNum + '"]');
                        rows.forEach(function(row) {
                            row.remove();
                        });
                        $.jGrowl('Button ' + buttonNum + ' removed', {themeState: 'success'});
                    }
                }
            </script>

            <!-- Text-to-Speech (TTS) Settings -->
            <h3 style="margin: 30px auto 10px; max-width: 800px; color: #3f51b5; border-bottom: 2px solid #3f51b5; padding-bottom: 5px;">
                <i class="fas fa-robot"></i> Text-to-Speech (TTS) Announcements
            </h3>
            <div class="description" style="margin-top: 15px;">
                <p><strong>About TTS:</strong> Generate AI-powered voice announcements using either Piper TTS (local, free) 
                or ElevenLabs (cloud-based, premium quality). Create MP3 files from text for future use, or play announcements in real-time.</p>
            </div>
            
            <!-- TTS Engine Selection -->
            <div style="max-width: 800px; margin: 20px auto; padding: 15px; border: 2px solid #2196F3; border-radius: 8px; background-color: #E3F2FD;">
                <h4 style="margin-top: 0; color: #2196F3;"><i class="fas fa-cogs"></i> TTS Engine Configuration</h4>
                <table class="settingsTable" style="margin: 0;">
                    <tr>
                        <td class="label" style="width: 250px;">TTS Engine:</td>
                        <td class="value">
                            <?php
                            $ttsEngine = isset($pluginSettings['TTSEngine']) ? $pluginSettings['TTSEngine'] : 'piper';
                            ?>
                            <select id="TTSEngine" name="TTSEngine" class="form-control" style="width: 300px;" onchange="toggleTTSEngineSettings()">
                                <option value="piper" <?php echo ($ttsEngine == 'piper') ? 'selected' : ''; ?>>Piper (Local - Free)</option>
                                <option value="elevenlabs" <?php echo ($ttsEngine == 'elevenlabs') ? 'selected' : ''; ?>>ElevenLabs (Cloud - Premium)</option>
                            </select>
                            <small>Choose between local Piper TTS or cloud-based ElevenLabs</small>
                        </td>
                    </tr>
                </table>
                
                <!-- ElevenLabs Settings (hidden by default) -->
                <div id="elevenLabsSettings" style="<?php echo ($ttsEngine == 'elevenlabs') ? '' : 'display: none;'; ?> margin-top: 15px; padding-top: 15px; border-top: 1px solid #2196F3;">
                    <table class="settingsTable" style="margin: 0;">
                        <tr>
                            <td class="label" style="width: 250px;">
                                ElevenLabs API Key:
                                <a href="https://elevenlabs.io/api" target="_blank" style="font-size: 11px;">
                                    <i class="fas fa-external-link-alt"></i> Get API Key
                                </a>
                            </td>
                            <td class="value">
                                <input type="text" id="ElevenLabsAPIKey" name="ElevenLabsAPIKey" 
                                    value="<?php echo isset($pluginSettings['ElevenLabsAPIKey']) ? htmlspecialchars($pluginSettings['ElevenLabsAPIKey']) : ''; ?>"
                                    placeholder="sk_..." style="width: 400px;" class="form-control" onblur="loadElevenLabsDefaultVoices()">
                                <small>Your ElevenLabs API key (required for cloud TTS)</small>
                            </td>
                        </tr>
                        <tr>
                            <td class="label">Default Voice:</td>
                            <td class="value">
                                <select id="ElevenLabsVoiceID" name="ElevenLabsVoiceID" style="width: 400px;" class="form-control" data-saved-value="<?php echo isset($pluginSettings['ElevenLabsVoiceID']) ? htmlspecialchars($pluginSettings['ElevenLabsVoiceID']) : '21m00Tcm4TlvDq8ikWAM'; ?>">
                                    <option value="21m00Tcm4TlvDq8ikWAM" <?php echo (!isset($pluginSettings['ElevenLabsVoiceID']) || $pluginSettings['ElevenLabsVoiceID'] == '21m00Tcm4TlvDq8ikWAM') ? 'selected' : ''; ?>>
                                        Rachel (American - Female)
                                    </option>
                                </select>
                                <span id="elevenLabsVoiceLoadStatus" style="margin-left: 10px;"></span>
                                <br><small>Default voice for TTS generation (will load available voices when API key is provided)</small>
                            </td>
                        </tr>
                    </table>
                </div>
            </div>
            
            <div id="ttsStatusPanel" style="max-width: 800px; margin: 20px auto; padding: 15px; border: 2px solid #ddd; border-radius: 8px; background-color: #f9f9f9;">
                <h4 style="margin-top: 0;"><i class="fas fa-info-circle"></i> TTS Engine Status</h4>
                <div id="ttsStatus">
                    <p><i class="fas fa-spinner fa-spin"></i> Checking TTS engine status...</p>
                </div>
            </div>
            
            <div id="ttsGeneratorPanel" style="max-width: 800px; margin: 20px auto; padding: 15px; border: 2px solid #3f51b5; border-radius: 8px; background-color: #f0f4ff; display: none;">
                <h4 style="margin-top: 0; color: #3f51b5;"><i class="fas fa-magic"></i> Generate TTS Audio File</h4>
                <table class="settingsTable" style="margin: 0;">
                    <tr>
                        <td class="label" style="width: 200px;">Voice:</td>
                        <td class="value">
                            <select id="ttsVoiceSelect" style="width: 100%; padding: 8px;">
                                <option value="">Loading voices...</option>
                            </select>
                            <small>Select the voice to use for generation</small>
                        </td>
                    </tr>
                    <tr>
                        <td class="label" style="width: 200px;">Text to Speak:</td>
                        <td class="value">
                            <textarea id="ttsText" rows="3" style="width: 100%; font-family: sans-serif; font-size: 14px; padding: 8px; border: 1px solid #ccc; border-radius: 4px;" 
                                placeholder="Enter text to convert to speech, e.g., 'Welcome to our holiday light show! Please stay in your vehicle and tune to 87.9 FM.'"></textarea>
                            <small>Enter the text you want to convert to speech</small>
                        </td>
                    </tr>
                    <tr>
                        <td class="label">Filename:</td>
                        <td class="value">
                            <input type="text" id="ttsFilename" placeholder="e.g., welcome_message" style="width: 300px;">
                            <small>Filename (without extension) - will be saved as MP3 in /home/fpp/media/music/</small>
                        </td>
                    </tr>
                    <tr>
                        <td class="label"></td>
                        <td class="value">
                            <button type="button" class="btn btn-primary" onclick="generateTTS()" style="background-color: #3f51b5;">
                                <i class="fas fa-magic"></i> Generate MP3 File
                            </button>
                            <span id="ttsGenerateStatus" style="margin-left: 10px;"></span>
                        </td>
                    </tr>
                </table>
            </div>
            
            <!-- Voice Management Panel -->
            <div id="voiceManagementPanel" style="max-width: 800px; margin: 20px auto; padding: 15px; border: 2px solid #673ab7; border-radius: 8px; background-color: #f3e5f5; display: none;">
                <h4 style="margin-top: 0; color: #673ab7;"><i class="fas fa-microphone"></i> <span id="voiceManagementTitle">Voice Management</span></h4>
                <p id="voiceManagementDescription" style="margin-bottom: 15px; font-size: 13px;">Loading voices...</p>
                <div id="voicesList" style="margin-top: 10px;">
                    <p><i class="fas fa-spinner fa-spin"></i> Loading available voices...</p>
                </div>
            </div>
        </form>
    </div>

    <script>
        function toggleBackgroundSource() {
            var source = $('#BackgroundMusicSource').val();
            if (source === 'playlist') {
                $('#playlistRow').show();
                $('#streamRow').hide();
                $('#shuffleRow').show();
                $('#crossfadeRow').show();
                toggleCrossfadeOptions();
            } else {
                $('#playlistRow').hide();
                $('#streamRow').show();
                $('#shuffleRow').hide();
                $('#crossfadeRow').hide();
                $('#crossfadeDurationRow').hide();
            }
        }
        
        function toggleCrossfadeOptions() {
            if ($('#EnableCrossfade').is(':checked')) {
                $('#crossfadeDurationRow').show();
            } else {
                $('#crossfadeDurationRow').hide();
            }
        }
        
        function toggleTTSEngineSettings() {
            var engine = $('#TTSEngine').val();
            if (engine === 'elevenlabs') {
                $('#elevenLabsSettings').slideDown();
                // For ElevenLabs, hide Piper-specific panels
                $('#ttsStatusPanel').hide();
                $('#voiceManagementPanel').hide();
                // Load ElevenLabs voices into generator panel and default voice dropdown
                loadVoices(engine);
                loadElevenLabsDefaultVoices();
                $('#ttsGeneratorPanel').show();
            } else {
                $('#elevenLabsSettings').slideUp();
                // For Piper, show status panel and check if installed
                $('#ttsStatusPanel').show();
                $('#ttsGeneratorPanel').hide();
                checkTTSStatus();
            }
        }
        
        function loadElevenLabsDefaultVoices() {
            var apiKey = $('#ElevenLabsAPIKey').val().trim();
            if (!apiKey) {
                return;
            }
            
            $('#elevenLabsVoiceLoadStatus').html('<i class="fas fa-spinner fa-spin"></i>');
            
            $.ajax({
                url: '/api/plugin/fpp-plugin-BackgroundMusic/tts-voices',
                type: 'GET',
                data: { engine: 'elevenlabs' },
                success: function(data) {
                    if (data.status === 'OK' && data.voices) {
                        var select = $('#ElevenLabsVoiceID');
                        var savedValue = select.data('saved-value') || select.val();
                        select.empty();
                        
                        // Group voices by gender
                        var grouped = {};
                        data.voices.forEach(function(voice) {
                            var gender = voice.gender || 'Other';
                            if (!grouped[gender]) {
                                grouped[gender] = [];
                            }
                            grouped[gender].push(voice);
                        });
                        
                        // Add voices grouped by gender
                        Object.keys(grouped).sort().forEach(function(gender) {
                            var optgroup = $('<optgroup label="' + gender + '"></optgroup>');
                            grouped[gender].forEach(function(voice) {
                                var label = voice.name;
                                if (voice.accent && voice.accent !== 'unknown') {
                                    label += ' (' + voice.accent + ')';
                                }
                                var option = $('<option></option>')
                                    .val(voice.id)
                                    .text(label);
                                if (voice.id === savedValue) {
                                    option.prop('selected', true);
                                }
                                optgroup.append(option);
                            });
                            select.append(optgroup);
                        });
                        
                        // Set the saved value
                        select.val(savedValue);
                        
                        $('#elevenLabsVoiceLoadStatus').html('<i class="fas fa-check-circle" style="color: green;"></i>');
                    } else {
                        $('#elevenLabsVoiceLoadStatus').html('<i class="fas fa-exclamation-triangle" style="color: orange;"></i>');
                    }
                },
                error: function() {
                    $('#elevenLabsVoiceLoadStatus').html('<i class="fas fa-times-circle" style="color: red;"></i>');
                }
            });
        }
        
        function handleStreamPresetChange() {
            var preset = $('#BackgroundMusicStreamPreset').val();
            if (preset === 'custom') {
                $('#customStreamURLContainer').show();
                $('#BackgroundMusicStreamURLInput').focus();
            } else if (preset === '') {
                $('#customStreamURLContainer').hide();
                $('#BackgroundMusicStreamURLInput').val('');
            } else {
                $('#customStreamURLContainer').hide();
                $('#BackgroundMusicStreamURLInput').val(preset);
            }
        }
        
        function saveSettings() {
            // Get the actual stream URL value
            var streamURL = '';
            var preset = $('#BackgroundMusicStreamPreset').val();
            if (preset === 'custom') {
                streamURL = $('#BackgroundMusicStreamURLInput').val();
            } else if (preset !== '') {
                streamURL = preset;
            }
            
            var formData = {
                'BackgroundMusicSource': $('#BackgroundMusicSource').val(),
                'BackgroundMusicPlaylist': $('#BackgroundMusicPlaylist').val(),
                'BackgroundMusicStreamURL': streamURL,
                'ShowPlaylist': $('#ShowPlaylist').val(),
                'FadeTime': $('#FadeTime').val(),
                'BlackoutTime': $('#BlackoutTime').val(),
                'ReturnToPreShow': $('#ReturnToPreShow').is(':checked') ? '1' : '0',
                'ResumeMode': $('#ResumeMode').val(),
                'PostShowDelay': $('#PostShowDelay').val(),
                'PostShowBackgroundVolume': $('#PostShowBackgroundVolume').val(),
                'AutostartEnabled': $('#AutostartEnabled').is(':checked') ? '1' : '0',
                'ShuffleMusic': $('#ShuffleMusic').is(':checked') ? '1' : '0',
                'EnableCrossfade': $('#EnableCrossfade').is(':checked') ? '1' : '0',
                'CrossfadeDuration': $('#CrossfadeDuration').val(),
                'BackgroundMusicVolume': $('#BackgroundMusicVolume').val(),
                'ShowPlaylistVolume': $('#ShowPlaylistVolume').val(),
                'VolumeLevel': $('#BackgroundMusicVolume').val() || '70',  // Maintain backward compatibility
                // PSA settings
                'PSAAnnouncementVolume': $('#PSAAnnouncementVolume').val(),
                'PSADuckVolume': $('#PSADuckVolume').val(),
                // TTS settings
                'TTSEngine': $('#TTSEngine').val(),
                'ElevenLabsAPIKey': $('#ElevenLabsAPIKey').val(),
                'ElevenLabsVoiceID': $('#ElevenLabsVoiceID').val()
            };
            
            // Dynamically collect all PSA button settings
            for (var i = 1; i <= 20; i++) {
                var labelInput = $('#PSAButton' + i + 'Label');
                var fileInput = $('#PSAButton' + i + 'File');
                if (labelInput.length > 0) {
                    formData['PSAButton' + i + 'Label'] = labelInput.val();
                }
                if (fileInput.length > 0) {
                    formData['PSAButton' + i + 'File'] = fileInput.val();
                }
            }
            
            $.ajax({
                url: '/api/plugin/fpp-plugin-BackgroundMusic/save-settings',
                type: 'POST',
                contentType: 'application/json',
                data: JSON.stringify(formData),
                dataType: 'json',
                success: function(data) {
                    if (data.status === 'OK') {
                        $.jGrowl('Settings saved successfully', {themeState: 'success'});
                    } else {
                        $.jGrowl('Error: ' + (data.message || 'Unknown error'), {themeState: 'danger'});
                    }
                },
                error: function() {
                    $.jGrowl('Failed to save settings', {themeState: 'danger'});
                }
            });
            
            return false;
        }
        
        // TTS Functions
        function checkTTSStatus() {
            var engine = $('#TTSEngine').val();
            
            // If ElevenLabs is selected, show appropriate message
            if (engine === 'elevenlabs') {
                $('#ttsStatus').html(
                    '<p style="color: #2196F3;"><i class="fas fa-cloud"></i> <strong>ElevenLabs Cloud TTS</strong></p>' +
                    '<p>Using cloud-based text-to-speech. All voices are available instantly without installation.</p>' +
                    '<p style="font-size: 12px; color: #666;">Make sure your API key is configured above.</p>'
                );
                $('#ttsGeneratorPanel').show();
                loadVoices(engine);
                return;
            }
            
            // Check Piper TTS status
            $.ajax({
                url: '/api/plugin/fpp-plugin-BackgroundMusic/tts-status',
                type: 'GET',
                success: function(data) {
                    if (data.installed) {
                        $('#ttsStatus').html(
                            '<p style="color: green;"><i class="fas fa-check-circle"></i> <strong>Piper TTS Installed</strong></p>' +
                            '<ul style="margin: 5px 0; padding-left: 20px;">' +
                            '<li>Version: ' + (data.version || 'Unknown') + '</li>' +
                            '<li>Architecture: ' + (data.architecture || 'Unknown') + '</li>' +
                            '<li>Voices: ' + (data.voices.length > 0 ? data.voices.join(', ') : 'None') + '</li>' +
                            '<li>Default Voice: ' + (data.defaultVoice || 'None') + '</li>' +
                            '</ul>'
                        );
                        $('#ttsGeneratorPanel').show();
                        $('#voiceManagementPanel').show();
                        loadVoices('piper');
                    } else {
                        $('#ttsStatus').html(
                            '<p style="color: #ff9800;"><i class="fas fa-exclamation-triangle"></i> <strong>Piper TTS Not Installed</strong></p>' +
                            '<p>Piper TTS provides AI-powered text-to-speech with minimal storage requirements (~10MB).</p>' +
                            '<button type="button" class="btn btn-primary" onclick="installTTS()" style="background-color: #3f51b5;">' +
                            '<i class="fas fa-download"></i> Install Piper TTS</button>' +
                            '<p style="margin-top: 10px; font-size: 12px; color: #666;">Installation takes 2-5 minutes depending on your internet speed.</p>'
                        );
                        $('#ttsGeneratorPanel').hide();
                        $('#voiceManagementPanel').hide();
                    }
                },
                error: function() {
                    $('#ttsStatus').html('<p style="color: red;"><i class="fas fa-times-circle"></i> Error checking TTS status</p>');
                }
            });
        }
        
        function installTTS() {
            $('#ttsStatus').html('<p><i class="fas fa-spinner fa-spin"></i> Installing Piper TTS... This may take several minutes.</p>');
            
            $.ajax({
                url: '/api/plugin/fpp-plugin-BackgroundMusic/install-tts',
                type: 'POST',
                success: function(data) {
                    if (data.status === 'OK') {
                        $.jGrowl('Piper TTS installation started', {themeState: 'success'});
                        $('#ttsStatus').html(
                            '<p><i class="fas fa-spinner fa-spin"></i> Installing Piper TTS...</p>' +
                            '<p style="font-size: 12px;">Downloading ~10MB. Please wait 2-5 minutes then refresh this page.</p>' +
                            '<button type="button" class="btn btn-info" onclick="checkTTSStatus()" style="margin-top: 10px;">' +
                            '<i class="fas fa-sync"></i> Check Status</button>'
                        );
                        
                        // Auto-check status after 30 seconds
                        setTimeout(checkTTSStatus, 30000);
                    } else {
                        $.jGrowl('Error: ' + (data.message || 'Installation failed'), {themeState: 'danger'});
                        checkTTSStatus();
                    }
                },
                error: function() {
                    $.jGrowl('Failed to start installation', {themeState: 'danger'});
                    checkTTSStatus();
                }
            });
        }
        
        function generateTTS() {
            var text = $('#ttsText').val().trim();
            var filename = $('#ttsFilename').val().trim();
            var voiceId = $('#ttsVoiceSelect').val();
            var engine = $('#TTSEngine').val();
            
            if (!text) {
                $.jGrowl('Please enter text to convert', {themeState: 'danger'});
                return;
            }
            
            if (!filename) {
                $.jGrowl('Please enter a filename', {themeState: 'danger'});
                return;
            }
            
            if (!voiceId) {
                $.jGrowl('Please select a voice', {themeState: 'danger'});
                return;
            }
            
            $('#ttsGenerateStatus').html('<i class="fas fa-spinner fa-spin"></i> Generating...');
            
            var requestData = {
                text: text,
                filename: filename
            };
            
            // For ElevenLabs, always include voice ID
            // For Piper, only add voice if it's not the default
            if (engine === 'elevenlabs' || voiceId !== 'default') {
                requestData.voice = voiceId;
            }
            
            $.ajax({
                url: '/api/plugin/fpp-plugin-BackgroundMusic/generate-tts',
                type: 'POST',
                contentType: 'application/json',
                data: JSON.stringify(requestData),
                success: function(data) {
                    if (data.status === 'OK') {
                        $.jGrowl('TTS audio generated: ' + data.filename, {themeState: 'success', life: 3000});
                        $('#ttsGenerateStatus').html('<i class="fas fa-check-circle" style="color: green;"></i> Generated: ' + data.filename);
                        
                        // Clear inputs
                        $('#ttsText').val('');
                        $('#ttsFilename').val('');
                        
                        // Reload page after 2 seconds to update PSA file dropdowns
                        setTimeout(function() {
                            location.reload();
                        }, 2000);
                    } else {
                        $.jGrowl('Error: ' + (data.message || 'Generation failed'), {themeState: 'danger'});
                        $('#ttsGenerateStatus').html('<i class="fas fa-times-circle" style="color: red;"></i> Failed');
                    }
                },
                error: function() {
                    $.jGrowl('Failed to generate TTS audio', {themeState: 'danger'});
                    $('#ttsGenerateStatus').html('<i class="fas fa-times-circle" style="color: red;"></i> Error');
                }
            });
        }
        
        function loadVoices(engine) {
            // If no engine specified, get from UI
            if (!engine) {
                engine = $('#TTSEngine').val() || 'piper';
            }
            
            $.ajax({
                url: '/api/plugin/fpp-plugin-BackgroundMusic/tts-voices',
                type: 'GET',
                data: { engine: engine },
                success: function(data) {
                    if (data.status === 'OK') {
                        displayVoices(data.voices, data.default_voice, data.engine);
                        populateVoiceSelect(data.voices, data.default_voice, data.engine);
                    } else {
                        $('#voicesList').html('<p style="color: red;">Error: ' + data.message + '</p>');
                    }
                },
                error: function() {
                    $('#voicesList').html('<p style="color: red;">Failed to load voices</p>');
                }
            });
        }
        
        function populateVoiceSelect(voices, defaultVoice, engine) {
            var select = $('#ttsVoiceSelect');
            select.empty();
            
            if (engine === 'elevenlabs') {
                // ElevenLabs voices
                select.append('<option value="">Select a voice...</option>');
                voices.forEach(function(voice) {
                    var label = voice.name;
                    if (voice.accent && voice.accent !== 'unknown') {
                        label += ' (' + voice.accent + ')';
                    }
                    if (voice.gender && voice.gender !== 'unknown') {
                        label += ' - ' + voice.gender;
                    }
                    select.append('<option value="' + voice.id + '">' + label + '</option>');
                });
            } else {
                // Piper voices
                select.append('<option value="default">Use Default Voice (' + defaultVoice + ')</option>');
                voices.forEach(function(voice) {
                    if (voice.installed) {
                        var label = voice.name + ' - ' + voice.gender + ' (' + voice.quality + ')';
                        select.append('<option value="' + voice.id + '">' + label + '</option>');
                    }
                });
                select.val('default');
            }
        }
        
        function displayVoices(voices, defaultVoice, engine) {
            var html = '';
            
            if (engine === 'elevenlabs') {
                // For ElevenLabs, voices are only shown in the dropdown, not in the management panel
                // Just clear the voices list since the panel is hidden anyway
                $('#voicesList').html('');
                return;
            } else {
                // Update panel title and description for Piper
                $('#voiceManagementTitle').text('Piper Voice Management');
                $('#voiceManagementDescription').text('Install additional voices for different accents, genders, and qualities. Click on a voice to see details and install.');
                
                // Display Piper voices (existing code)
                var grouped = {};
                voices.forEach(function(voice) {
                    if (!grouped[voice.language]) {
                        grouped[voice.language] = [];
                    }
                    grouped[voice.language].push(voice);
                });
                
                Object.keys(grouped).sort().forEach(function(language) {
                    html += '<h5 style="margin: 15px 0 10px 0; color: #673ab7; border-bottom: 1px solid #673ab7;">' + language + '</h5>';
                    html += '<div style="display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 10px;">';
                    
                    grouped[language].forEach(function(voice) {
                        var isDefault = voice.id === defaultVoice;
                        var borderColor = isDefault ? '#4caf50' : (voice.installed ? '#2196f3' : '#ccc');
                        var bgColor = isDefault ? '#e8f5e9' : (voice.installed ? '#e3f2fd' : '#fafafa');
                        
                        html += '<div style="border: 2px solid ' + borderColor + '; border-radius: 6px; padding: 12px; background-color: ' + bgColor + ';">';
                        html += '<div style="font-weight: bold; font-size: 14px; margin-bottom: 5px;">';
                        html += '<i class="fas fa-' + getGenderIcon(voice.gender) + '"></i> ' + voice.name;
                        if (isDefault) html += ' <span style="color: #4caf50; font-size: 11px;">(DEFAULT)</span>';
                        html += '</div>';
                        html += '<div style="font-size: 12px; color: #666; margin-bottom: 8px;">' + voice.description + '</div>';
                        html += '<div style="font-size: 11px; color: #999; margin-bottom: 8px;">';
                        html += 'Gender: ' + voice.gender + ' | Quality: ' + voice.quality + ' | Size: ' + voice.size_mb + 'MB';
                        html += '</div>';
                        
                        if (voice.installed) {
                            html += '<button onclick="setDefaultVoice(\'' + voice.id + '\')" class="btn btn-sm btn-success" style="font-size: 11px; padding: 4px 8px; margin-right: 5px;">';
                            html += '<i class="fas fa-star"></i> Set Default</button>';
                            if (!isDefault) {
                                html += '<button onclick="deleteVoice(\'' + voice.id + '\')" class="btn btn-sm btn-danger" style="font-size: 11px; padding: 4px 8px;">';
                                html += '<i class="fas fa-trash"></i> Delete</button>';
                            }
                        } else {
                            html += '<button onclick="installVoice(\'' + voice.id + '\')" class="btn btn-sm btn-primary" style="font-size: 11px; padding: 4px 8px; background-color: #673ab7;">';
                            html += '<i class="fas fa-download"></i> Install (' + voice.size_mb + 'MB)</button>';
                        }
                        
                        html += '</div>';
                    });
                    
                    html += '</div>';
                });
            }
            
            $('#voicesList').html(html);
        }
        
        function getGenderIcon(gender) {
            if (gender === 'male') return 'mars';
            if (gender === 'female') return 'venus';
            return 'genderless';
        }
        
        function installVoice(voiceId) {
            $.jGrowl('Installing voice: ' + voiceId, {themeState: 'success'});
            
            $.ajax({
                url: '/api/plugin/fpp-plugin-BackgroundMusic/install-voice',
                type: 'POST',
                contentType: 'application/json',
                data: JSON.stringify({voice_id: voiceId}),
                success: function(data) {
                    if (data.status === 'OK') {
                        $.jGrowl('Voice installed successfully', {themeState: 'success'});
                        loadVoices();
                        checkTTSStatus();
                    } else {
                        $.jGrowl('Error: ' + (data.message || 'Installation failed'), {themeState: 'danger'});
                    }
                },
                error: function() {
                    $.jGrowl('Failed to install voice', {themeState: 'danger'});
                }
            });
        }
        
        function setDefaultVoice(voiceId) {
            $.ajax({
                url: '/api/plugin/fpp-plugin-BackgroundMusic/set-default-voice',
                type: 'POST',
                contentType: 'application/json',
                data: JSON.stringify({voice_id: voiceId}),
                success: function(data) {
                    if (data.status === 'OK') {
                        $.jGrowl('Default voice set successfully', {themeState: 'success'});
                        loadVoices();
                        checkTTSStatus();
                    } else {
                        $.jGrowl('Error: ' + (data.message || 'Failed to set default'), {themeState: 'danger'});
                    }
                },
                error: function() {
                    $.jGrowl('Failed to set default voice', {themeState: 'danger'});
                }
            });
        }
        
        function deleteVoice(voiceId) {
            if (!confirm('Are you sure you want to delete this voice?')) {
                return;
            }
            
            $.ajax({
                url: '/api/plugin/fpp-plugin-BackgroundMusic/delete-voice',
                type: 'POST',
                contentType: 'application/json',
                data: JSON.stringify({voice_id: voiceId}),
                success: function(data) {
                    if (data.status === 'OK') {
                        $.jGrowl('Voice deleted successfully', {themeState: 'success'});
                        loadVoices();
                        checkTTSStatus();
                    } else {
                        $.jGrowl('Error: ' + (data.message || 'Failed to delete'), {themeState: 'danger'});
                    }
                },
                error: function() {
                    $.jGrowl('Failed to delete voice', {themeState: 'danger'});
                }
            });
        }
        
        // Check TTS status on page load
        $(document).ready(function() {
            toggleBackgroundSource();
            toggleTTSEngineSettings();
        });
    </script>
</div>
