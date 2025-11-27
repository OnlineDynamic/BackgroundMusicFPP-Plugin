# FPP Core - Plugin Header Indicator System Implementation

## Overview
Implemented a generic plugin header indicator system in FPP core that allows any plugin to display status indicators in the main FPP header. Previously, the BackgroundMusic plugin used a custom JavaScript solution that only worked on its own page. Now, any plugin can register indicators that appear globally across all FPP pages.

## Files Modified in FPP Core

### 1. `/opt/fpp/www/api/controllers/pluginHeaders.php` (NEW)
**Purpose**: Central controller for plugin header indicators

**Functionality**:
- Queries all installed plugins for their `headerIndicator` endpoints
- Aggregates indicator configurations from all plugins
- Returns array of indicator objects
- Handles timeouts and errors gracefully (200ms timeout per plugin)

**Endpoint**: `GET /api/plugin/headerIndicators`

**Response Format**:
```json
[
  {
    "visible": true,
    "icon": "fa-music",
    "color": "#8b5cf6",
    "tooltip": "Background Music: Track Name",
    "link": "/plugin-page.php",
    "animate": "pulse",
    "pluginName": "fpp-plugin-BackgroundMusic"
  }
]
```

### 2. `/opt/fpp/www/api/index.php` (MODIFIED)
**Change**: Added route for plugin header indicators

**Line 117** (inserted):
```php
dispatch_get('/plugin/headerIndicators', 'GetPluginHeaderIndicators');
```

**Backup**: `/opt/fpp/www/api/index.php.backup`

### 3. `/opt/fpp/www/api/controllers/system.php` (MODIFIED)
**Change**: Modified `finalizeStatusJson()` to include plugin indicators in status API

**Lines 390-394** (added):
```php
// Add plugin header indicators
if (!isset($_GET['noplugins'])) {
    $obj['pluginHeaderIndicators'] = json_decode(GetPluginHeaderIndicators(), true);
}
```

**Integration**: Plugin indicators now included in `/api/system/status` response, automatically refreshed with all status updates

**Backup**: `/opt/fpp/www/api/controllers/system.php.backup`

### 4. `/opt/fpp/www/js/fpp.js` (MODIFIED)
**Change**: Added client-side rendering of plugin indicators

**Lines 8661-8687** (inserted after header_player update):
```javascript
// Render plugin header indicators
if (data.pluginHeaderIndicators != undefined) {
    var indicators = [];
    data.pluginHeaderIndicators.forEach(function(indicator) {
        if (indicator && indicator.visible) {
            var icon = indicator.icon || 'fa-puzzle-piece';
            var color = indicator.color || '#999';
            var tooltip = indicator.tooltip || 'Plugin Indicator';
            var link = indicator.link || '#';
            var animate = indicator.animate || '';
            var animStyle = animate ? ' style="animation: ' + animate + ' 2s infinite;"' : '';
            
            var row = '<span class="pluginIndicator headerBox" data-plugin="' + indicator.pluginName + '"' +
                ' style="cursor: pointer; color: ' + color + '; margin-left: 5px; transition: color 0.3s ease;"' +
                ' title="' + tooltip + '"' +
                ' onclick="window.location.href=\'' + link + '\'">' +
                '<i class="fas ' + icon + '"' + animStyle + '></i>' +
                '</span>';
            indicators.push(row);
        }
    });
    var indicatorsJoined = indicators.join('');
    if (headerCache.PluginIndicators != indicatorsJoined) {
        $('#header_plugin_indicators').html(indicatorsJoined);
        headerCache.PluginIndicators = indicatorsJoined;
    }
}
```

**Backup**: `/opt/fpp/www/js/fpp.js.backup`

### 5. `/opt/fpp/www/menu.inc` (MODIFIED)
**Change**: Added placeholder span for plugin indicators in header HTML

**Line 110** (inserted):
```html
<span class="headerBox" id="header_plugin_indicators"></span>
```

**Location**: Between `header_player` and `header_sensors` spans

**Backup**: `/opt/fpp/www/menu.inc.backup`

### 6. `/opt/fpp/www/css/fpp.css` (MODIFIED)
**Change**: Added CSS styles for plugin indicators and pulse animation

**Lines appended**:
```css
/* Plugin Header Indicators */
.pluginIndicator {
    display: inline-block;
    margin-left: 5px;
    transition: color 0.3s ease, transform 0.2s ease;
}

.pluginIndicator:hover {
    transform: scale(1.1);
    opacity: 0.8;
}

@keyframes pulse {
    0%, 100% {
        transform: scale(1);
        opacity: 1;
    }
    50% {
        transform: scale(1.15);
        opacity: 0.85;
    }
}
```

## Plugin Integration

### How Plugins Use This System

Plugins add a `headerIndicator` endpoint to their API:

1. **Register the endpoint** in `getEndpoints{PluginName}()`:
```php
$ep = array(
    'method' => 'GET',
    'endpoint' => 'headerIndicator',
    'callback' => 'pluginHeaderIndicator'
);
array_push($result, $ep);
```

2. **Implement the callback** returning indicator config:
```php
function pluginHeaderIndicator() {
    if (!$featureActive) {
        return json(null); // Don't show indicator
    }
    
    return json(array(
        'visible' => true,
        'icon' => 'fa-icon-name',
        'color' => '#hexcolor',
        'tooltip' => 'Status text',
        'link' => '/plugin-page.php',
        'animate' => 'pulse' // optional
    ));
}
```

### Example: BackgroundMusic Plugin

The BackgroundMusic plugin now uses this system instead of its custom header-indicator.js:

**File**: `/home/fpp/media/plugins/fpp-plugin-BackgroundMusic/api.php`

**Implementation**:
- Added `headerIndicator` endpoint (line ~20)
- Implemented `fppBackgroundMusicHeaderIndicator()` function (lines ~383-445)
- Returns purple pulsing music icon when playing
- Tooltip shows current track or stream title
- Links to plugin controller page

## Architecture

### Data Flow

1. **Client Status Request**: Browser requests `/api/system/status`
2. **Plugin Discovery**: `finalizeStatusJson()` calls `GetPluginHeaderIndicators()`
3. **Plugin Queries**: Each plugin's `headerIndicator` endpoint is queried (200ms timeout)
4. **Aggregation**: All indicator configs collected into array
5. **Response**: Status JSON includes `pluginHeaderIndicators` field
6. **Rendering**: JavaScript in fpp.js renders indicators into `header_plugin_indicators` span
7. **Auto-Refresh**: Process repeats on each status refresh cycle

### Performance Characteristics

- **Caching**: Indicators cached in status response (no separate queries needed)
- **Timeout**: 200ms per plugin prevents slowdowns
- **Non-blocking**: Failed plugins don't affect others
- **Efficient**: Only queries plugins that have an `api.php` file
- **Scalable**: Multiple plugins can have indicators without performance impact

## Benefits

### For Plugin Developers
- ✅ Simple API - just return JSON configuration
- ✅ No JavaScript required
- ✅ Auto-discovery - FPP finds your endpoint
- ✅ Centrally managed styling and positioning
- ✅ Works on all FPP pages automatically

### For Users
- ✅ Consistent indicator location and behavior
- ✅ No configuration needed
- ✅ Multiple plugin indicators supported
- ✅ Responsive and accessible
- ✅ Updates in real-time with status

### For FPP Core
- ✅ Extensible architecture
- ✅ Backwards compatible (opt-in for plugins)
- ✅ Minimal performance impact
- ✅ Generic - works for any plugin type

## Testing

### Test URLs
- Main endpoint: `http://localhost/api/plugin/headerIndicators`
- Status with indicators: `http://localhost/api/system/status | jq '.pluginHeaderIndicators'`
- Example plugin: `http://localhost/api/plugin/fpp-plugin-BackgroundMusic/headerIndicator`

### Verification
1. Check indicator appears in FPP header when BackgroundMusic is playing
2. Verify tooltip shows current track
3. Click indicator navigates to plugin page
4. Check pulse animation is smooth
5. Verify works on all FPP pages (index, settings, etc.)

## Future Enhancements

Potential improvements:
- Add indicator priority/ordering system
- Support for badges/counters on indicators
- Indicator grouping for related plugins
- User preferences for which indicators to show
- Indicator animation customization options

## Rollback Instructions

If issues arise, restore from backups:
```bash
cp /opt/fpp/www/api/index.php.backup /opt/fpp/www/api/index.php
cp /opt/fpp/www/api/controllers/system.php.backup /opt/fpp/www/api/controllers/system.php
cp /opt/fpp/www/js/fpp.js.backup /opt/fpp/www/js/fpp.js
cp /opt/fpp/www/menu.inc.backup /opt/fpp/www/menu.inc
rm /opt/fpp/www/api/controllers/pluginHeaders.php
```

Remove CSS additions from `/opt/fpp/www/css/fpp.css` (last ~20 lines)

## Credits

**Implementation Date**: November 27, 2025
**Implemented For**: BackgroundMusic Plugin header indicator feature
**FPP Version**: Compatible with FPP 8.x+
**Implementation**: Added generic framework to FPP core for all plugins to use
