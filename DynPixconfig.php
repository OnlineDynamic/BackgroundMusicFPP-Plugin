
<?php

include_once "/opt/fpp/www/common.php";
include_once 'functions.inc.php';
include_once 'version.inc';

$pluginName = basename(dirname(__FILE__));

$logFile = $settings['logDirectory'] . "/" . $pluginName . ".log";

$gitURL = "https://github.com/OnlineDynamic/DynamicPixelsFPPPlugin.git";

?>

<html>
<head>
<style>

* {
  box-sizing: border-box;
}

.subheader {
  background-color: #f1f1f1;
  padding: 20px;
  text-align: center;
}

.col-1 {width: 8.33%;}
.col-2 {width: 16.66%;}
.col-3 {width: 25%;}
.col-4 {width: 33.33%;}
.col-5 {width: 41.66%;}
.col-6 {width: 50%;}
.col-7 {width: 58.33%;}
.col-8 {width: 66.66%;}
.col-9 {width: 75%;}
.col-10 {width: 83.33%;}
.col-11 {width: 91.66%;}
.col-12 {width: 100%;}

[class*="col-"] {
  float: left;
  padding: 15px;
}

.row::after {
  content: "";
  clear: both;
  display: table;
}

@media screen and (max-width: 1000px) {
  div.graphic {
    display: none;
  }

.matrix-tool-bottom-panel {
	padding-top: 0px !important;
}

.red {
	background: #ff0000;
}

.green {
	background: #00ff00;
}

.blue {
	background: #0000ff;
}

.white {
	background: #ffffff;
}

.black {
	background: #000000;
}

.colorButton {
	-moz-transition: border-color 250ms ease-in-out 0s;
	background-clip: padding-box;
	border: 2px solid rgba(0, 0, 0, 0.25);
	border-radius: 50% 50% 50% 50%;
	cursor: pointer;
	display: inline-block;
	height: 20px;
	margin: 1px 2px;
	width: 20px;
}

#currentColor {
    border: 2px solid #000000;
}
#scroll-container {
  border: 3px solid black;
  border-radius: 5px;
  overflow: hidden;
}

#scroll-text {

	font-weight: bold;
	font-size: 30px;

  /* animation properties */
  -moz-transform: translateX(100%);
  -webkit-transform: translateX(100%);
  transform: translateX(100%);

  -moz-animation: my-animation 15s linear infinite;
  -webkit-animation: my-animation 15s linear infinite;
  animation: my-animation 15s linear infinite;
}

/* for Firefox */
@-moz-keyframes my-animation {
  from { -moz-transform: translateX(100%); }
  to { -moz-transform: translateX(-100%); }
}

/* for Chrome */
@-webkit-keyframes my-animation {
  from { -webkit-transform: translateX(100%); }
  to { -webkit-transform: translateX(-100%); }
}

@keyframes my-animation {
  from {
    -moz-transform: translateX(100%);
    -webkit-transform: translateX(100%);
    transform: translateX(100%);
  }
  to {
    -moz-transform: translateX(-50%);
    -webkit-transform: translateX(-50%);
    transform: translateX(-50%);
  }
}}

</style>
<script type="text/javascript">
/* var dynamicpixelsConfig = <?//echo json_encode($pluginJson, JSON_PRETTY_PRINT); ?>; */

var uniqueId = 1;
var modelOptions = "";

function AdddynamicpixelsItem() {
    var id = $("#dynamicpixelsTableBody > tr").length + 1;
    var html = "<tr class='fppTableRow";
    if (id % 2 != 0) {
        html += " oddRow ";
    }
    html += "stuart";
    html += "'><td class='colNumber rowNumber'>" + id + ".</td><td><span style='display: none;' class='uniqueId'>" + uniqueId + "</span></td>";
    html += "<td>" + <? PrintSettingSelect("MONTH", "MONTH", 0, 0, $defaultValue= "1", getMonths(), $pluginName, $callbackName = "updateOutputText", $changedFunction = "");?> +"</td>";
    html += "<td>" + <? PrintSettingTextSaved("ITEM_NAME", 0, 0, $maxlength = 32, $size = 32, $pluginName, $defaultValue = "ItemName", $callbackName = "updateOutputText", $changedFunction = "", $inputType = "text", $sData = array());?> +"</td>";
    html += "<td><input type='number' value='1' min='1' max='3' class='psu_num' />";
    html += "<td><input type='number' value='0' min='0' max='30' class='max_current' />";
    html += "</tr>";
    //selected
    $("#dynamicpixelsTableBody").append(html);

    newRow = $('#dynamicpixelsTableBody > tr').last();
    $('#dynamicpixelsTableBody > tr').removeClass('selectedEntry');
    DisableButtonClass('deleteEventButton');
    uniqueId++;

    return newRow;
}

// function SavedynamicpixelsItem(row) {
//     var itemname = $(row).find('.itemname').val();
//     var psu_num = parseInt($(row).find('.psu_num').val(),10);

//     var max_current = parseInt($(row).find('.max_current').val(),10);
// 	var devicetype = $(row).find('.devicetype').val();

//     var json = {
//         "itemname": itemname,
//         "psu_num": psu_num,
//         "devicetype": devicetype,
//         "max_current": max_current
//     };
//     return json;
// }

// function SavedynamicpixelsItems() {
//     var dynamicpixelsConfig = [];
//     var i = 0;
//     $("#dynamicpixelsTableBody > tr").each(function() {
//         dynamicpixelsConfig[i++] = SavedynamicpixelsItem(this);
//     });

//     var data = JSON.stringify(dynamicpixelsConfig);
//     $.ajax({
//         type: "POST",
//         url: 'fppjson.php?command=setPluginJSON&plugin=dynamicpixels',
//         dataType: 'json',
//         async: false,
//         data: data,
//         processData: false,
//         contentType: 'application/json',
//         success: function (data) {
//            SetRestartFlag(2);
//         }
//     });
// }


function RenumberRows() {
    var id = 1;
    $('#dynamicpixelsTableBody > tr').each(function() {
        $(this).find('.rowNumber').html('' + id++ + '.');
        $(this).removeClass('oddRow');

        if (id % 2 != 0) {
            $(this).addClass('oddRow');
        }
    });
}
function RemovedynamicpixelsItem() {
    if ($('#dynamicpixelsTableBody').find('.selectedEntry').length) {
        $('#dynamicpixelsTableBody').find('.selectedEntry').remove();
        RenumberRows();
    }
    DisableButtonClass('deleteEventButton');
}


$(document).ready(function() {

    $('#dynamicpixelsTableBody').sortable({
        update: function(event, ui) {
            RenumberRows();
        },
        item: '> tr',
        scroll: true
    }).disableSelection();

    $('#dynamicpixelsTableBody').on('mousedown', 'tr', function(event,ui){
        $('#dynamicpixelsTableBody tr').removeClass('selectedEntry');
        $(this).addClass('selectedEntry');
        EnableButtonClass('deleteEventButton');
    });
});

</script>
</head>





<div id="global" class="settings">
<fieldset>
<legend>Dynamic Pixels Controller (Cape) Config</legend>




<div>
<table border=0>
<tr><td colspan='2'>
        <!-- <input type="button" value="Save" class="buttons genericButton" onclick="SavedynamicpixelsItems();"> -->
        <input type="button" value="Add" class="buttons genericButton" onclick="AdddynamicpixelsItem();">
        <input id="delButton" type="button" value="Delete" class="deleteEventButton disableButtons genericButton" onclick="RemovedynamicpixelsItem();">
    </td>
</tr>
</table>

<div class='fppTableWrapper fppTableWrapperAsTable'>
<div class='fppTableContents'>
<table class="fppTable" id="dynamicpixelsTable"  width='100%'>
<thead><tr class="fppTableHeader"><th>#</th><th></th><th>Item Type</th><th>Item Name</th><th>PSU #</th><th>Max Current</th></tr></thead>
<tbody id='dynamicpixelsTableBody'>
</tbody>
</table>
</div>

</div>
<div>
<p>
<p>
</div>
</div>
<script>

// $.each(dynamicpixelsConfig, function( key, val ) {
//     var row = AdddynamicpixelsItem(val["devicetype"]);
//     $(row).find('.itemname').val(val["itemname"]);
//     $(row).find('.psu_num').val(val["psu_num"]);
//     $(row).find('.max_current').val(val["max_current"]);
// });
</script>

</fieldset>
</div>
