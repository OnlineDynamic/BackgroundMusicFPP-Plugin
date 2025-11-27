// Background Music Plugin - Header Indicator
// Adds a music icon to the FPP header when background music is active
// NOTE: This is the legacy implementation. FPP now has built-in plugin header indicator support.
// This script only runs if the new system is not available (backwards compatibility).

(function () {
    'use strict';

    // Check if FPP has the new plugin header indicator system
    // If header_plugin_indicators element exists, the new system is available
    function hasNewHeaderSystem() {
        return document.getElementById('header_plugin_indicators') !== null;
    }

    // Exit early if new system is available
    if (hasNewHeaderSystem()) {
        console.debug('Background Music: Using new FPP plugin header indicator system');
        return; // Don't initialize legacy indicator
    }

    console.debug('Background Music: Using legacy header indicator (FPP core support not detected)');

    let indicatorElement = null;
    let updateInterval = null;

    function createIndicator() {
        if (indicatorElement) return;

        // Find the FPP header player box
        const headerPlayer = document.getElementById('header_player');
        if (!headerPlayer) {
            console.debug('Background Music indicator: header_player not found, will retry');
            return;
        }

        // Create the indicator element as a span to match FPP's header style
        indicatorElement = document.createElement('span');
        indicatorElement.id = 'bgMusicIndicator';
        indicatorElement.style.cssText = `
            display: none;
            cursor: pointer;
            margin-left: 10px;
            margin-right: 15px;
            color: #8b5cf6;
            transition: color 0.3s ease;
        `;

        indicatorElement.innerHTML = `
            <span id="bgMusicTooltip" title="Background Music Playing">
                <i class="fas fa-music" style="animation: pulse 2s infinite; font-size: 16px;"></i>
            </span>
        `;

        // Add hover effect
        indicatorElement.addEventListener('mouseenter', function () {
            this.style.color = '#a78bfa';
        });

        indicatorElement.addEventListener('mouseleave', function () {
            this.style.color = '#8b5cf6';
        });

        // Click to navigate to controller
        indicatorElement.addEventListener('click', function () {
            window.location.href = '/plugin.php?_menu=status&plugin=fpp-plugin-BackgroundMusic&page=backgroundmusic.php';
        });

        // Add pulse animation
        const style = document.createElement('style');
        style.textContent = `
            @keyframes pulse {
                0%, 100% {
                    transform: scale(1);
                    opacity: 1;
                }
                50% {
                    transform: scale(1.2);
                    opacity: 0.8;
                }
            }
        `;
        document.head.appendChild(style);

        // Insert after the header_player span
        headerPlayer.parentNode.insertBefore(indicatorElement, headerPlayer.nextSibling);
    }

    function updateIndicator() {
        // Fetch status from the API
        fetch('/api/plugin/fpp-plugin-BackgroundMusic/status')
            .then(response => response.json())
            .then(data => {
                if (!indicatorElement) {
                    createIndicator();
                }

                if (!indicatorElement) return; // Still not created, skip this update

                if (data.backgroundMusicRunning) {
                    indicatorElement.style.display = 'inline';

                    // Update tooltip text based on source type
                    const tooltipSpan = document.getElementById('bgMusicTooltip');

                    if (data.config && data.config.backgroundMusicSource === 'stream') {
                        if (tooltipSpan) tooltipSpan.setAttribute('title', 'Background Music: Streaming');
                    } else if (data.currentTrack) {
                        if (tooltipSpan) tooltipSpan.setAttribute('title', 'Background Music: ' + data.currentTrack);
                    } else {
                        if (tooltipSpan) tooltipSpan.setAttribute('title', 'Background Music Playing');
                    }
                } else {
                    if (indicatorElement) {
                        indicatorElement.style.display = 'none';
                    }
                }
            })
            .catch(error => {
                console.debug('Background Music indicator: Error fetching status', error);
                if (indicatorElement) {
                    indicatorElement.style.display = 'none';
                }
            });
    }

    // Initialize when DOM is ready
    function init() {
        // Initial update
        updateIndicator();

        // Update every 5 seconds
        updateInterval = setInterval(updateIndicator, 5000);
    }

    // Wait for DOM to be ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }

    // Cleanup on page unload
    window.addEventListener('beforeunload', function () {
        if (updateInterval) {
            clearInterval(updateInterval);
        }
    });
})();
