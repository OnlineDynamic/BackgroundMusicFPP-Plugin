<?php

include_once("/opt/fpp/www/common.php");
$pluginName = basename(dirname(__FILE__));
$pluginConfigFile = $settings['configDirectory'] . "/plugin." .$pluginName;

if (file_exists($pluginConfigFile)){
$pluginSettings = parse_ini_file($pluginConfigFile);
}else{
$pluginSettings = array();
}

// Get plugin setting by key
function getPluginSetting($key, $default = '') {
global $pluginSettings;
return isset($pluginSettings[$key]) ? $pluginSettings[$key] : $default;
}

// Get all playlists from FPP
function getPlaylistsFromFPP() {
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

// Get FPP status
function getFPPStatus() {
$ch = curl_init('http://localhost/api/fppd/status');
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_HEADER, 0);
$data = curl_exec($ch);
curl_close($ch);
return json_decode($data, true);
}

// Check if a playlist is currently running
function isPlaylistRunning($playlistName) {
$status = getFPPStatus();
$currentPlaylist = isset($status['current_playlist']['playlist']) ? $status['current_playlist']['playlist'] : '';
return ($currentPlaylist === $playlistName && $playlistName !== '');
}

// Start a playlist
function startPlaylist($playlistName, $repeat = false) {
$data = array('command' => 'start', 'playlist' => $playlistName);
if ($repeat) {
$data['repeat'] = true;
}

$ch = curl_init('http://localhost/api/command');
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_HTTPHEADER, array('Content-Type: application/json'));
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
$response = curl_exec($ch);
curl_close($ch);

return json_decode($response, true);
}

// Stop all playlists
function stopAllPlaylists() {
$data = array('command' => 'stop');
$ch = curl_init('http://localhost/api/command');
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_HTTPHEADER, array('Content-Type: application/json'));
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
$response = curl_exec($ch);
curl_close($ch);

return json_decode($response, true);
}

// Get current brightness
function getCurrentBrightness() {
$brightness = getSetting('brightness');
if ($brightness === false || $brightness === '') {
return 100;
}
return intval($brightness);
}

// Set brightness
function setFPPBrightness($level) {
if ($level < 0) $level = 0;
if ($level > 100) $level = 100;

$ch = curl_init('http://localhost/api/system/brightness/' . $level);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_CUSTOMREQUEST, 'PUT');
$response = curl_exec($ch);
curl_close($ch);

return json_decode($response, true);
}

// Log to plugin log file
function logPluginMessage($message) {
$logFile = '/home/fpp/media/logs/fpp-plugin-BackgroundMusic.log';
$timestamp = date('Y-m-d H:i:s');
$logMessage = "[$timestamp] $message\n";
file_put_contents($logFile, $logMessage, FILE_APPEND);
}

?>
