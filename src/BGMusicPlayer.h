#pragma once
/*
 * Background Music Player for FPP Plugin
 *
 * This is a standalone audio player that uses SDL2 and FFmpeg
 * similar to FPP's SDLOutput, but runs independently so it doesn't
 * conflict with FPP's main media playback.
 *
 * Key differences from ffplay:
 * - Properly integrates with ALSA/SDL volume control
 * - Respects system volume changes in real-time
 * - Compatible with PCM5102 DAC (no hardware mixer) via softvol
 * - Works alongside FPP's main player without conflicts
 */

#include <string>
#include <atomic>
#include <mutex>
#include <thread>

extern "C"
{
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libswresample/swresample.h>
#include <SDL2/SDL.h>
}

class BGMusicPlayer
{
public:
    BGMusicPlayer();
    ~BGMusicPlayer();

    // Load an audio file
    bool Load(const std::string &filename);

    // Start playback from beginning or specific position (milliseconds)
    bool Start(int startTimeMs = 0);

    // Stop playback
    void Stop();

    // Close and cleanup
    void Close();

    // Check if currently playing
    bool IsPlaying() const;

    // Get current playback position in milliseconds
    int GetPositionMs() const;

    // Get total duration in milliseconds
    int GetDurationMs() const;

    // Pause/Resume
    void Pause();
    void Resume();
    bool IsPaused() const;

    // Volume control (0-100, where 100 is system volume)
    void SetVolumeGain(int percent);
    int GetVolumeGain() const;

private:
    // Audio format info
    struct AudioInfo
    {
        int sampleRate;
        int channels;
        int bytesPerSample;
        bool isFloat;
        AVSampleFormat format;
    };

    // FFmpeg context
    AVFormatContext *formatContext;
    AVCodecContext *audioCodecContext;
    SwrContext *swrContext;
    AVFrame *frame;
    AVPacket *packet;
    int audioStreamIndex;
    AudioInfo audioInfo;

    // SDL Audio
    SDL_AudioDeviceID audioDevice;
    SDL_AudioSpec audioSpec;

    // Playback state
    std::atomic<bool> playing;
    std::atomic<bool> paused;
    std::atomic<bool> shouldStop;
    std::atomic<int> currentPositionMs;
    int totalDurationMs;

    // Threading
    std::thread *decodeThread;
    std::mutex stateMutex;

    // Volume control
    std::atomic<float> volumeGain; // 1.0 = 100%, 2.0 = 200%, etc.

    // Audio buffer
    uint8_t *audioBuffer;
    int audioBufferSize;
    int audioBufferMaxSize;
    std::mutex bufferMutex;

    // Internal methods
    bool OpenAudioFile(const std::string &filename);
    bool InitializeSDL();
    void DecodeLoop();
    static void AudioCallback(void *userdata, uint8_t *stream, int len);
    void FillAudioBuffer(uint8_t *stream, int len);
    bool DecodeAudioPacket();
    void CleanupFFmpeg();
    void CleanupSDL();

    std::string currentFile;
};
