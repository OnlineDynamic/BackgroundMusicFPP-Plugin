# Header Indicator Feature

## About
The header indicator displays a small music icon in the top-right corner of all FPP pages when background music is active. It shows:
- A pulsing music icon when background music is playing
- The current track name (for playlists) or "Streaming" (for internet streams)
- Clicking the indicator navigates to the Background Music Controller page

## Installation

The `header-indicator.js` file is automatically installed with the plugin, but it needs to be included in FPP's page header to work globally.

### Option 1: Add to FPP Custom Header (Recommended)
If FPP supports custom JavaScript injection:
1. Access FPP's settings for custom JavaScript/CSS
2. Add the following script tag:
```html
<script src="/plugin.php?plugin=fpp-plugin-BackgroundMusic&file=header-indicator.js"></script>
```

### Option 2: Browser Extension
Use a browser extension like "User JavaScript and CSS" to automatically inject the script on all FPP pages.

### Option 3: Manual Include
The script is automatically included on the Background Music Controller page and will show the indicator while on that page.

## Features
- **Auto-updating**: Checks status every 5 seconds
- **Click to navigate**: Click the indicator to go to the controller
- **Smart display**: Shows current track for playlists, "Streaming" for streams
- **Smooth animations**: Fade in/out with hover effects
- **Responsive**: Works on mobile and desktop

## Styling
The indicator appears as a purple gradient pill in the top-right corner with:
- White text and icon
- Smooth slide-in animation
- Pulse animation on the music icon
- Hover effect for better interaction
- Click-through to the controller page
