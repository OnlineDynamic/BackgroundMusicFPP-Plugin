/*
 * Command-line wrapper for Background Music Player
 * 
 * This executable replaces ffplay in the background music plugin
 * Usage: bgmplayer [options] <audio_file>
 * 
 * Options:
 *   -nodisp          Ignored (for ffplay compatibility)
 *   -autoexit        Ignored (for ffplay compatibility)
 *   -loglevel <level> Ignored (for ffplay compatibility)
 */

#include "BGMusicPlayer.h"
#include <iostream>
#include <csignal>
#include <unistd.h>

static BGMusicPlayer* player = nullptr;
static bool shouldExit = false;

// Signal handler for clean shutdown
void signalHandler(int signum) {
    std::cout << "\nReceived signal " << signum << ", stopping..." << std::endl;
    shouldExit = true;
    if (player) {
        player->Stop();
    }
}

int main(int argc, char* argv[]) {
    // Parse arguments
    std::string filename;
    
    for (int i = 1; i < argc; i++) {
        std::string arg = argv[i];
        
        // Skip ffplay compatibility options
        if (arg == "-nodisp" || arg == "-autoexit") {
            continue;
        }
        if (arg == "-loglevel" || arg == "-reconnect" || arg == "-reconnect_streamed" || 
            arg == "-reconnect_delay_max") {
            i++;  // Skip next arg (value)
            continue;
        }
        
        // Assume it's the filename
        if (filename.empty()) {
            filename = arg;
        }
    }
    
    if (filename.empty()) {
        std::cerr << "Usage: " << argv[0] << " [options] <audio_file>" << std::endl;
        return 1;
    }
    
    // Setup signal handlers
    signal(SIGINT, signalHandler);
    signal(SIGTERM, signalHandler);
    
    // Create player
    player = new BGMusicPlayer();
    
    // Load file
    if (!player->Load(filename)) {
        std::cerr << "Failed to load: " << filename << std::endl;
        delete player;
        return 1;
    }
    
    // Start playback
    if (!player->Start()) {
        std::cerr << "Failed to start playback" << std::endl;
        delete player;
        return 1;
    }
    
    std::cout << "Playing: " << filename << std::endl;
    std::cout << "Duration: " << player->GetDurationMs() / 1000 << "s" << std::endl;
    
    // Wait for playback to finish
    while (player->IsPlaying() && !shouldExit) {
        sleep(1);
        
        // Optional: print progress
        // int pos = player->GetPositionMs();
        // int dur = player->GetDurationMs();
        // std::cout << "\rPosition: " << pos/1000 << "s / " << dur/1000 << "s" << std::flush;
    }
    
    std::cout << "\nPlayback finished" << std::endl;
    
    // Cleanup
    player->Close();
    delete player;
    player = nullptr;
    
    return 0;
}
