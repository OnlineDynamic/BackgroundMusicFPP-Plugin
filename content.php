<?php
include_once("/opt/fpp/www/common.php");
$pluginName = "fpp-plugin-BackgroundMusic";
$pluginConfigFile = $settings['configDirectory'] . "/plugin." . $pluginName;

// Load current settings
if (file_exists($pluginConfigFile)){
    $pluginSettings = parse_ini_file($pluginConfigFile);
} else {
    $pluginSettings = array();
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
    
    // Check if playlist is empty
    if (isset($playlist['empty']) && $playlist['empty'] === true) {
        return false;
    }
    
    if (!isset($playlist['mainPlaylist']) || !is_array($playlist['mainPlaylist'])) {
        return false;
    }
    
    // Check if playlist has items
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
    
    // Use the empty flag from FPP API if available
    if (isset($playlist['empty'])) {
        return $playlist['empty'] !== true;
    }
    
    // Fallback: check mainPlaylist array
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
</style>

<div id="global" class="settings">
    <h1>Background Music Configuration</h1>
    
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
        <li><strong>Background Music Playlist:</strong> Audio-only playlist that plays over your existing pre-show sequence (already running via FPP scheduler)</li>
        <li><strong>Show Playlist:</strong> Main show playlist to start after fade transition</li>
        <li><strong>Fade Time:</strong> Duration to gradually fade out brightness and music before show</li>
        <li><strong>Blackout Time:</strong> Silent period after fade before starting the show</li>
        <li><strong>Return to Pre-Show:</strong> After the show completes, automatically restart background music (your scheduler will handle restarting the sequence)</li>
    </ul>
    <p><strong>Expected Setup:</strong> Your pre-show sequence (or non media playlist) should already be running (looping) via FPP's scheduler. This plugin adds background music on top.</p>
</div>        <form id="settingsForm" onsubmit="return saveSettings();">
            <!-- Playlist Selection -->
            <h3 style="margin: 30px auto 10px; max-width: 800px; color: #2196F3; border-bottom: 2px solid #2196F3; padding-bottom: 5px;">
                <i class="fas fa-list"></i> Playlist Selection
            </h3>
            <table class="settingsTable">
                <tr>
                    <td class="label">Background Music Playlist:</td>
                    <td class="value">
                        <select name="BackgroundMusicPlaylist" id="BackgroundMusicPlaylist">
                            <option value="">-- Select Playlist --</option>
                            <?php
                            foreach ($mediaOnlyPlaylists as $playlist) {
                                $selected = '';
                                if (isset($pluginSettings['BackgroundMusicPlaylist']) && 
                                    $pluginSettings['BackgroundMusicPlaylist'] == $playlist) {
                                    $selected = 'selected';
                                }
                                echo '<option value="' . htmlspecialchars($playlist) . '" ' . $selected . '>' . 
                                     htmlspecialchars($playlist) . '</option>';
                            }
                            ?>
                        </select>
                        <small>Audio playlist to play as background music (media-only playlists)</small>
                    </td>
                </tr>
                <tr>
                    <td class="label">Main Show Playlist:</td>
                    <td class="value">
                        <select name="ShowPlaylist" id="ShowPlaylist">
                            <option value="">-- Select Playlist --</option>
                            <?php
                            foreach ($allPlaylists as $playlist) {
                                $selected = '';
                                if (isset($pluginSettings['ShowPlaylist']) && 
                                    $pluginSettings['ShowPlaylist'] == $playlist) {
                                    $selected = 'selected';
                                }
                                echo '<option value="' . htmlspecialchars($playlist) . '" ' . $selected . '>' . 
                                     htmlspecialchars($playlist) . '</option>';
                            }
                            ?>
                        </select>
                        <small>Main show playlist to start after fade and blackout</small>
                    </td>
                </tr>
                <tr>
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
                        <small>Volume level for background music during pre-show (0-100%)</small>
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

            <!-- Post-Show Settings -->
            <h3 style="margin: 30px auto 10px; max-width: 800px; color: #9C27B0; border-bottom: 2px solid #9C27B0; padding-bottom: 5px;">
                <i class="fas fa-redo"></i> Post-Show Settings
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
                        <small>Your FPP scheduler should handle restarting the pre-show sequence</small>
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
            
            <h4 style="margin: 20px auto 10px; max-width: 800px; color: #555;">Configure Announcement Buttons:</h4>
            <table class="settingsTable">
                <?php for ($i = 1; $i <= 5; $i++): ?>
                <tr>
                    <td class="label">Button <?php echo $i; ?> Label:</td>
                    <td class="value">
                        <input type="text" name="PSAButton<?php echo $i; ?>Label" id="PSAButton<?php echo $i; ?>Label" 
                               placeholder="e.g. Welcome Message" 
                               value="<?php echo isset($pluginSettings['PSAButton'.$i.'Label']) ? htmlspecialchars($pluginSettings['PSAButton'.$i.'Label']) : ''; ?>">
                    </td>
                </tr>
                <tr>
                    <td class="label">Button <?php echo $i; ?> MP3 File:</td>
                    <td class="value">
                        <input type="text" name="PSAButton<?php echo $i; ?>File" id="PSAButton<?php echo $i; ?>File" 
                               placeholder="/home/fpp/media/upload/announcement<?php echo $i; ?>.mp3" 
                               value="<?php echo isset($pluginSettings['PSAButton'.$i.'File']) ? htmlspecialchars($pluginSettings['PSAButton'.$i.'File']) : ''; ?>">
                        <small>Full path to MP3 file (typically in /home/fpp/media/upload/)</small>
                    </td>
                </tr>
                <?php if ($i < 5): ?>
                <tr><td colspan="2" style="height: 10px;"></td></tr>
                <?php endif; ?>
                <?php endfor; ?>
            </table>
            
            <div class="buttonRow">
                <button type="submit" class="btn btn-success"><i class="fas fa-save"></i> Save Settings</button>
                <a href="plugin.php?_menu=status&plugin=fpp-plugin-BackgroundMusic&page=backgroundmusic.php" class="btn btn-primary">
                    <i class="fas fa-arrow-left"></i> Back to Controller
                </a>
            </div>
        </form>
    </div>

    <script>
        function saveSettings() {
            var formData = {
                'BackgroundMusicPlaylist': $('#BackgroundMusicPlaylist').val(),
                'ShowPlaylist': $('#ShowPlaylist').val(),
                'FadeTime': $('#FadeTime').val(),
                'BlackoutTime': $('#BlackoutTime').val(),
                'ReturnToPreShow': $('#ReturnToPreShow').is(':checked') ? '1' : '0',
                'PostShowDelay': $('#PostShowDelay').val(),
                'PostShowBackgroundVolume': $('#PostShowBackgroundVolume').val(),
                'ShuffleMusic': $('#ShuffleMusic').is(':checked') ? '1' : '0',
                'BackgroundMusicVolume': $('#BackgroundMusicVolume').val(),
                'ShowPlaylistVolume': $('#ShowPlaylistVolume').val(),
                'VolumeLevel': $('#BackgroundMusicVolume').val() || '70',  // Maintain backward compatibility
                // PSA settings
                'PSAAnnouncementVolume': $('#PSAAnnouncementVolume').val(),
                'PSADuckVolume': $('#PSADuckVolume').val(),
                'PSAButton1Label': $('#PSAButton1Label').val(),
                'PSAButton1File': $('#PSAButton1File').val(),
                'PSAButton2Label': $('#PSAButton2Label').val(),
                'PSAButton2File': $('#PSAButton2File').val(),
                'PSAButton3Label': $('#PSAButton3Label').val(),
                'PSAButton3File': $('#PSAButton3File').val(),
                'PSAButton4Label': $('#PSAButton4Label').val(),
                'PSAButton4File': $('#PSAButton4File').val(),
                'PSAButton5Label': $('#PSAButton5Label').val(),
                'PSAButton5File': $('#PSAButton5File').val()
            };
            
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
                        $.jGrowl('Error: ' + (data.message || 'Unknown error'), {themeState: 'error'});
                    }
                },
                error: function() {
                    $.jGrowl('Failed to save settings', {themeState: 'error'});
                }
            });
            
            return false;
        }
    </script>
</div>
