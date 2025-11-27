# Header Indicator Feature

## About
The header indicator displays a small music icon in the FPP header (top bar) on all pages when background music is active. It shows:
- A pulsing music icon when background music is playing
- The current track name (for playlists) or stream title (for internet streams)
- Clicking the indicator navigates to the Background Music Controller page

**This plugin uses FPP's built-in plugin header indicator system** - a generic framework that allows any plugin to display status indicators in the FPP header.

## How It Works

### For Users
The indicator automatically appears in the FPP header between the player status and sensors when background music is playing. No configuration needed - it's built into FPP core!

### For Plugin Developers
FPP now includes a generic plugin header indicator system that any plugin can use:

1. **Add a headerIndicator endpoint** to your plugin's API that returns indicator configuration
2. **FPP automatically queries** all installed plugins for their indicators
3. **Indicators appear automatically** in the header between player status and sensors

## Plugin Developer Guide

### 1. Add Endpoint to Your Plugin API

In your plugin's `api.php`, add a headerIndicator endpoint:

```php
function getEndpointsYourPluginName() {
    $result = array();
    
    // ... your other endpoints ...
    
    $ep = array(
        'method' => 'GET',
        'endpoint' => 'headerIndicator',
        'callback' => 'yourPluginHeaderIndicator');
    array_push($result, $ep);
    
    return $result;
}
```

### 2. Implement the Callback Function

Create a function that returns your indicator configuration:

```php
function yourPluginHeaderIndicator() {
    // Check if your plugin feature is active
    $isActive = false; // Your logic here
    
    if (!$isActive) {
        return json(null); // Return null when indicator should not show
    }
    
    // Return indicator configuration
    $indicator = array(
        'visible' => true,
        'icon' => 'fa-music',           // Font Awesome icon class
        'color' => '#8b5cf6',            // Icon color (CSS color)
        'tooltip' => 'Your Plugin Status', // Hover tooltip text
        'link' => '/your-plugin-page.php', // Click destination
        'animate' => 'pulse'             // Optional: 'pulse' or ''
    );
    
    return json($indicator);
}
```

### 3. Indicator Configuration Options

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `visible` | boolean | Yes | Set to `true` to show the indicator |
| `icon` | string | Yes | Font Awesome icon class (e.g., `fa-music`, `fa-bell`, `fa-star`) |
| `color` | string | Yes | CSS color for the icon (hex, rgb, or named color) |
| `tooltip` | string | Yes | Text shown when hovering over the indicator |
| `link` | string | Yes | URL to navigate to when clicking the indicator |
| `animate` | string | No | Animation type: `'pulse'` for pulsing effect, or `''` for none |

### 4. That's It!

FPP will automatically:
- Query your endpoint every status refresh (every few seconds)
- Render your indicator in the header
- Handle click events and tooltips
- Update the indicator as your plugin's status changes

## Example: Background Music Plugin

This plugin's implementation:

```php
function fppBackgroundMusicHeaderIndicator() {
    // Check if background music is running
    $pidFile = '/tmp/background_music_start.pid';
    $backgroundMusicRunning = false;
    
    if (file_exists($pidFile)) {
        $pid = trim(file_get_contents($pidFile));
        exec("ps -p $pid > /dev/null 2>&1", $output, $returnCode);
        $backgroundMusicRunning = ($returnCode === 0);
    }
    
    // Only show when music is playing
    if (!$backgroundMusicRunning) {
        return json(null);
    }
    
    // Get current track for tooltip
    $currentTrack = ''; // ... get from status file ...
    $tooltip = !empty($currentTrack) 
        ? 'Background Music: ' . $currentTrack 
        : 'Background Music Playing';
    
    return json(array(
        'visible' => true,
        'icon' => 'fa-music',
        'color' => '#8b5cf6',
        'tooltip' => $tooltip,
        'link' => '/plugin.php?plugin=fpp-plugin-BackgroundMusic&page=backgroundmusic.php',
        'animate' => 'pulse'
    ));
}
```

## Technical Details

### FPP Core Implementation
- **API Endpoint**: `/api/plugin/headerIndicators` - Returns array of all plugin indicators
- **Status Integration**: Plugin indicators included in `/api/system/status` response
- **Auto-Discovery**: FPP queries all installed plugins for `headerIndicator` endpoints
- **Refresh Rate**: Updates every status refresh cycle (typically every 1-5 seconds)

### Multiple Plugins
Multiple plugins can display indicators simultaneously - they appear side by side in the header.

### Performance
- Non-blocking queries with 200ms timeout
- Cached in status response
- Only active/visible indicators are rendered

## Benefits Over Old System

The old header-indicator.js approach required:
- Manual JavaScript injection
- Browser extensions or custom code
- Only worked on plugin's own page

The new built-in system:
- ✅ Works on **all FPP pages** automatically
- ✅ No configuration needed
- ✅ Built into FPP core
- ✅ Any plugin can use it
- ✅ Centrally managed and cached
