<?php

include_once("/opt/fpp/www/common.php");
$pluginName = basename(dirname(__FILE__));
$pluginConfigFile = $settings['configDirectory'] . "/plugin." .$pluginName;

$controllerPhysicalConfigFile = "./controllerPhysicalConfigs.json";

if (file_exists($pluginConfigFile)){
	$pluginSettings = parse_ini_file($pluginConfigFile);
}else{
	$pluginSettings = array(); //There have been no settings saved by the user, create empty array
}


if (file_exists($controllerPhysicalConfigFile)){
	$controllerConfig = parse_ini_file($controllerPhysicalConfigFile);
}else{
	$controllerConfig = array(); //There have been no settings saved by the user, create empty array
}

if (isset($pluginSettings['YEAR'])){
	$setyear = $pluginSettings['YEAR'];
}else{
	$setyear = date("Y")-1;	
}

function getMonths(){
	return $monthList= array('January' => 1, 'February' => 2, 'March' => 3, 'April' => 4, 'May' => 5, 'June' => 6, 'July' => 7, 'August' => 8, 'September' => 9, 'October' => 10, 'November' => 11, 'December' => 12);
}

function getDaysOfMonth(){
	for($i=1; $i<=31; $i++){
		$daysList[$i]=$i;
	}
	return $daysList;
}

function getYears(){
	global $setyear;
    if ($setyear>date("Y")){
        $setyear=date("Y");
    }
	for($i=$setyear; $i<=date("Y")+5; $i++){
		$yearList[$i]=$i;
	}
	return $yearList;
}

function getHours(){
	return $hours= array(0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23);
}

function getMinutes(){
	for( $i= 0; $i<=59; $i++){
		$minuteList[str_pad($i,2,'0',STR_PAD_LEFT)] = $i;
	}
	return $minuteList;
}
function GetOverlayList() { 
	$modelsList = GetModels("");
	for($i=0;$i<=count($modelsList)-1;$i++) {
        $OverlayModels[trim($modelsList[$i]["Name"])]=trim($modelsList[$i]["Name"]);
	}
	return $OverlayModels;
}
function GetModels($host) {
    if ($host == "") {
        $host = "localhost";
    }
    $ch = curl_init("http://" . $host . "/api/overlays/models");
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_HEADER, 0);
    $data = curl_exec($ch);
    curl_close($ch);
    return json_decode($data, true);
}

function getFontsInstalled() {
	$host = "localhost";
    $ch = curl_init("http://" . $host . "/api/overlays/fonts");
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_HEADER, 0);
    $data = curl_exec($ch);
    curl_close($ch);
    $fontsList= json_decode($data, true);
	for($i=1;$i<=count($fontsList)-1;$i++) {
		$installedFonts[$fontsList[$i]]=$fontsList[$i];
	}
return $installedFonts;        
}

function getFontSizes(){
	$maxFontSize = 80;
	
	for($i=5; $i<=$maxFontSize; $i++) {
		$fontSize[$i]=$i;
    }
return $fontSize;	
}
function getScrollSpeed(){
	$MAX_PIXELS_PER_SECOND = 100;

        for($i=0;$i<=$MAX_PIXELS_PER_SECOND;$i++) {
			$scrollSpeed[$i]= $i;
        }
	return $scrollSpeed;
}
function getDuration(){
	$MAX_DURATION = 300;

        for($i=1;$i<=$MAX_DURATION;$i++) {
			$maxDuration[$i]= $i;
        }
	return $maxDuration;
}

function ScrollText($host="127.0.0.1", $model, $msg, $Position, $Font, $FontSize="20", $color="#ffffff", $PPS="20", $AntiAlias="", $Duration="10", $autoenable="true") {
        
    $data["command"] = "Overlay Model Effect";
    
    $args = array();
    $args[] = $model;
    $args[] = "" . $autoenable;
    $args[] = "Text";
    $args[] = $color;
    $args[] = $Font;
    $args[] = "" . $FontSize;
    $args[] = "" . $AntiAlias;
    $args[] = $Position;
    $args[] = "" . $PPS;
    $args[] = "" . $Duration;
    $args[] = $msg;
    $data["args"] = $args;
    echo json_encode($data);
    $data = json_encode($data);
    
    if ($host == "") {
        $host = "localhost";
    }
    $ch = curl_init("http://" . $host . "/api/command");
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_CUSTOMREQUEST, "POST");
    curl_setopt($ch, CURLOPT_HTTPHEADER, array('Content-Type: application/json','Content-Length: ' . strlen($data)));
    curl_setopt($ch, CURLOPT_CUSTOMREQUEST, 'POST');
    curl_setopt($ch, CURLOPT_POSTFIELDS,$data);

    $data = curl_exec($ch);
    curl_close($ch);
}


function logEntry($data,$logLevel=1) {

	global $logFile,$myPid, $LOG_LEVEL;

	
	if($logLevel <= $LOG_LEVEL) 
		return
		
		$data = $_SERVER['PHP_SELF']." : [".$myPid."] ".$data;
		
		$logWrite= fopen($logFile, "a") or die("Unable to open file!");
		fwrite($logWrite, date('Y-m-d h:i:s A',time()).": ".$data."\n");
		fclose($logWrite);
}

?>