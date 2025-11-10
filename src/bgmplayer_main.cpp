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
 *   -volume <percent> Set volume gain (100 = normal, 200 = 2x, etc.)
 *
 * Runtime Volume Control:
 *   Create file /tmp/bgmplayer_<pid>_volume.txt with desired volume percentage
 *   Player checks this file every second and adjusts volume dynamically
 */

#include "BGMusicPlayer.h"
#include <iostream>
#include <fstream>
#include <csignal>
#include <unistd.h>
#include <sys/stat.h>

static BGMusicPlayer *player = nullptr;
static bool shouldExit = false;
static std::string volumeControlFile;

// Signal handler for clean shutdown
void signalHandler(int signum)
{
    if (signum == SIGINT || signum == SIGTERM)
    {
        std::cout << "\nReceived signal " << signum << ", stopping..." << std::endl;
        shouldExit = true;
        if (player)
        {
            player->Stop();
        }
    }
    else if (signum == SIGUSR1)
    {
        // SIGUSR1: Reduce volume by 10%
        if (player)
        {
            int currentVol = player->GetVolumeGain();
            int newVol = currentVol - 10;
            if (newVol < 0) newVol = 0;
            player->SetVolumeGain(newVol);
            std::cout << "Volume decreased to " << newVol << "%" << std::endl;
        }
    }
    else if (signum == SIGUSR2)
    {
        // SIGUSR2: Increase volume by 10%
        if (player)
        {
            int currentVol = player->GetVolumeGain();
            int newVol = currentVol + 10;
            if (newVol > 200) newVol = 200;
            player->SetVolumeGain(newVol);
            std::cout << "Volume increased to " << newVol << "%" << std::endl;
        }
    }
}

int main(int argc, char *argv[])
{
    // Parse arguments
    std::string filename;
    int volumePercent = 100;  // Default 100% (no gain)

    for (int i = 1; i < argc; i++)
    {
        std::string arg = argv[i];

        // Skip ffplay compatibility options
        if (arg == "-nodisp" || arg == "-autoexit")
        {
            continue;
        }
        if (arg == "-loglevel" || arg == "-reconnect" || arg == "-reconnect_streamed" ||
            arg == "-reconnect_delay_max")
        {
            i++; // Skip next arg (value)
            continue;
        }

        // Volume parameter
        if (arg == "-volume")
        {
            if (i + 1 < argc)
            {
                volumePercent = std::atoi(argv[++i]);
            }
            continue;
        }

        // Assume it's the filename
        if (filename.empty())
        {
            filename = arg;
        }
    }

    if (filename.empty())
    {
        std::cerr << "Usage: " << argv[0] << " [options] <audio_file>" << std::endl;
        return 1;
    }

    // Setup signal handlers
    signal(SIGINT, signalHandler);
    signal(SIGTERM, signalHandler);
    signal(SIGUSR1, signalHandler);  // Volume down
    signal(SIGUSR2, signalHandler);  // Volume up

    // Create player
    player = new BGMusicPlayer();

    // Load file
    if (!player->Load(filename))
    {
        std::cerr << "Failed to load: " << filename << std::endl;
        delete player;
        return 1;
    }

    // Set volume gain
    player->SetVolumeGain(volumePercent);

    // Start playback
    if (!player->Start())
    {
        std::cerr << "Failed to start playback" << std::endl;
        delete player;
        return 1;
    }

    std::cout << "Playing: " << filename << std::endl;
    std::cout << "Duration: " << player->GetDurationMs() / 1000 << "s" << std::endl;
    if (volumePercent != 100)
    {
        std::cout << "Volume: " << volumePercent << "%" << std::endl;
    }
    
    // Setup volume control file (allows external volume changes)
    pid_t myPid = getpid();
    volumeControlFile = "/tmp/bgmplayer_" + std::to_string(myPid) + "_volume.txt";
    std::cout << "Volume control: " << volumeControlFile << std::endl;

    // Wait for playback to finish
    int checkCount = 0;
    while (player->IsPlaying() && !shouldExit)
    {
        sleep(1);
        checkCount++;
        
        // Check for volume control file every second
        struct stat buffer;
        if (stat(volumeControlFile.c_str(), &buffer) == 0)
        {
            std::ifstream volumeFile(volumeControlFile);
            if (volumeFile.is_open())
            {
                int newVolume;
                volumeFile >> newVolume;
                volumeFile.close();
                
                if (newVolume >= 0 && newVolume <= 400)
                {
                    player->SetVolumeGain(newVolume);
                    std::cout << "Volume adjusted to " << newVolume << "%" << std::endl;
                }
                
                // Remove the control file after reading
                unlink(volumeControlFile.c_str());
            }
        }

        // Optional: print progress
        // int pos = player->GetPositionMs();
        // int dur = player->GetDurationMs();
        // std::cout << "\rPosition: " << pos/1000 << "s / " << dur/1000 << "s" << std::flush;
    }

    std::cout << "\nPlayback finished" << std::endl;
    
    // Cleanup volume control file
    unlink(volumeControlFile.c_str());

    // Cleanup
    player->Close();
    delete player;
    player = nullptr;

    return 0;
}
