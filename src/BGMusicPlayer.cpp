/*
 * Background Music Player for FPP Plugin
 * Implementation file
 */

#include "BGMusicPlayer.h"
#include <iostream>
#include <cstring>
#include <unistd.h>

// Constructor
BGMusicPlayer::BGMusicPlayer() : formatContext(nullptr),
                                 audioCodecContext(nullptr),
                                 swrContext(nullptr),
                                 frame(nullptr),
                                 packet(nullptr),
                                 audioStreamIndex(-1),
                                 audioDevice(0),
                                 playing(false),
                                 paused(false),
                                 shouldStop(false),
                                 currentPositionMs(0),
                                 totalDurationMs(0),
                                 decodeThread(nullptr),
                                 volumeGain(1.0f),
                                 audioBuffer(nullptr),
                                 audioBufferSize(0),
                                 audioBufferMaxSize(0)
{

    memset(&audioInfo, 0, sizeof(audioInfo));
    memset(&audioSpec, 0, sizeof(audioSpec));
}

// Destructor
BGMusicPlayer::~BGMusicPlayer()
{
    Close();
}

// Load an audio file
bool BGMusicPlayer::Load(const std::string &filename)
{
    std::lock_guard<std::mutex> lock(stateMutex);

    // Close any existing file
    if (formatContext)
    {
        CleanupFFmpeg();
    }

    currentFile = filename;

    if (!OpenAudioFile(filename))
    {
        std::cerr << "Failed to open audio file: " << filename << std::endl;
        return false;
    }

    if (!InitializeSDL())
    {
        std::cerr << "Failed to initialize SDL" << std::endl;
        CleanupFFmpeg();
        return false;
    }

    std::cout << "Loaded: " << filename << " (" << totalDurationMs << "ms)" << std::endl;
    return true;
}

// Open and analyze audio file with FFmpeg
bool BGMusicPlayer::OpenAudioFile(const std::string &filename)
{
    // Set options for network streams
    AVDictionary *options = nullptr;
    av_dict_set(&options, "timeout", "10000000", 0); // 10 second timeout in microseconds
    av_dict_set(&options, "reconnect", "1", 0);      // Enable reconnect
    av_dict_set(&options, "reconnect_streamed", "1", 0);
    av_dict_set(&options, "reconnect_delay_max", "5", 0); // Max 5 seconds between reconnects

    // Open input file or stream
    int ret = avformat_open_input(&formatContext, filename.c_str(), nullptr, &options);
    av_dict_free(&options);

    if (ret < 0)
    {
        std::cerr << "Could not open file/stream: " << filename << std::endl;
        return false;
    }

    // Retrieve stream information
    if (avformat_find_stream_info(formatContext, nullptr) < 0)
    {
        std::cerr << "Could not find stream information" << std::endl;
        avformat_close_input(&formatContext);
        return false;
    }

    // Find the audio stream
    audioStreamIndex = -1;
    for (unsigned int i = 0; i < formatContext->nb_streams; i++)
    {
        if (formatContext->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_AUDIO)
        {
            audioStreamIndex = i;
            break;
        }
    }

    if (audioStreamIndex == -1)
    {
        std::cerr << "Could not find audio stream" << std::endl;
        avformat_close_input(&formatContext);
        return false;
    }

    // Get codec parameters
    AVCodecParameters *codecParams = formatContext->streams[audioStreamIndex]->codecpar;

    // Find decoder
    const AVCodec *codec = avcodec_find_decoder(codecParams->codec_id);
    if (!codec)
    {
        std::cerr << "Codec not found" << std::endl;
        avformat_close_input(&formatContext);
        return false;
    }

    // Allocate codec context
    audioCodecContext = avcodec_alloc_context3(codec);
    if (!audioCodecContext)
    {
        std::cerr << "Could not allocate codec context" << std::endl;
        avformat_close_input(&formatContext);
        return false;
    }

    // Copy codec parameters to context
    if (avcodec_parameters_to_context(audioCodecContext, codecParams) < 0)
    {
        std::cerr << "Could not copy codec parameters" << std::endl;
        avcodec_free_context(&audioCodecContext);
        avformat_close_input(&formatContext);
        return false;
    }

    // Open codec
    if (avcodec_open2(audioCodecContext, codec, nullptr) < 0)
    {
        std::cerr << "Could not open codec" << std::endl;
        avcodec_free_context(&audioCodecContext);
        avformat_close_input(&formatContext);
        return false;
    }

    // Store audio info
    audioInfo.sampleRate = audioCodecContext->sample_rate;
    audioInfo.channels = audioCodecContext->ch_layout.nb_channels;
    audioInfo.format = audioCodecContext->sample_fmt;

    // Allocate frame and packet
    frame = av_frame_alloc();
    packet = av_packet_alloc();

    if (!frame || !packet)
    {
        std::cerr << "Could not allocate frame or packet" << std::endl;
        CleanupFFmpeg();
        return false;
    }

    // Calculate duration
    if (formatContext->duration != AV_NOPTS_VALUE)
    {
        totalDurationMs = (formatContext->duration / AV_TIME_BASE) * 1000;
    }
    else
    {
        totalDurationMs = 0;
    }

    return true;
}

// Initialize SDL audio
bool BGMusicPlayer::InitializeSDL()
{
    // Initialize SDL audio subsystem
    if (SDL_Init(SDL_INIT_AUDIO) < 0)
    {
        std::cerr << "SDL_Init failed: " << SDL_GetError() << std::endl;
        return false;
    }

    // Set desired audio format - use ALSA default device for volume control integration
    SDL_AudioSpec wantedSpec;
    memset(&wantedSpec, 0, sizeof(wantedSpec));

    wantedSpec.freq = audioInfo.sampleRate;
    wantedSpec.format = AUDIO_S16SYS; // 16-bit signed audio
    wantedSpec.channels = audioInfo.channels;
    wantedSpec.silence = 0;
    wantedSpec.samples = 4096;           // Buffer size
    wantedSpec.callback = AudioCallback; // Use callback mode for dmix compatibility
    wantedSpec.userdata = this;

    // Open audio device - use NULL/default to respect ALSA configuration
    audioDevice = SDL_OpenAudioDevice(NULL, 0, &wantedSpec, &audioSpec,
                                      SDL_AUDIO_ALLOW_FREQUENCY_CHANGE);

    if (audioDevice == 0)
    {
        std::cerr << "Failed to open audio device: " << SDL_GetError() << std::endl;
        return false;
    }

    std::cout << "SDL Audio opened: " << audioSpec.freq << "Hz, "
              << (int)audioSpec.channels << " channels" << std::endl;

    // Store actual format info
    audioInfo.sampleRate = audioSpec.freq;
    audioInfo.channels = audioSpec.channels;
    audioInfo.bytesPerSample = 2; // S16
    audioInfo.isFloat = false;

    // Initialize audio buffer for callback mode
    audioBufferMaxSize = audioSpec.size * 8; // 8 buffers worth
    audioBuffer = new uint8_t[audioBufferMaxSize];
    audioBufferSize = 0;

    // Setup resampler if needed
    AVChannelLayout outLayout;
    av_channel_layout_default(&outLayout, audioInfo.channels);

    swr_alloc_set_opts2(&swrContext,
                        &outLayout,
                        AV_SAMPLE_FMT_S16,
                        audioInfo.sampleRate,
                        &audioCodecContext->ch_layout,
                        audioCodecContext->sample_fmt,
                        audioCodecContext->sample_rate,
                        0, nullptr);

    if (!swrContext || swr_init(swrContext) < 0)
    {
        std::cerr << "Failed to initialize resampler" << std::endl;
        CleanupSDL();
        return false;
    }

    return true;
}

// Start playback
bool BGMusicPlayer::Start(int startTimeMs)
{
    std::lock_guard<std::mutex> lock(stateMutex);

    if (playing)
    {
        return true;
    }

    if (!formatContext || audioDevice == 0)
    {
        std::cerr << "No file loaded or SDL not initialized" << std::endl;
        return false;
    }

    // Seek if start time specified
    if (startTimeMs > 0 && formatContext->duration != AV_NOPTS_VALUE)
    {
        int64_t seekTarget = (int64_t)startTimeMs * AV_TIME_BASE / 1000;
        av_seek_frame(formatContext, -1, seekTarget, AVSEEK_FLAG_ANY);
    }

    shouldStop = false;
    playing = true;
    paused = false;
    currentPositionMs = startTimeMs;

    // Start decode thread
    decodeThread = new std::thread(&BGMusicPlayer::DecodeLoop, this);

    // Start SDL audio
    SDL_PauseAudioDevice(audioDevice, 0);

    return true;
}

// Stop playback
void BGMusicPlayer::Stop()
{
    if (!playing)
    {
        return;
    }

    shouldStop = true;
    playing = false;

    // Wait for decode thread to finish
    if (decodeThread && decodeThread->joinable())
    {
        decodeThread->join();
        delete decodeThread;
        decodeThread = nullptr;
    }

    // Pause SDL audio
    if (audioDevice)
    {
        SDL_PauseAudioDevice(audioDevice, 1);
        SDL_ClearQueuedAudio(audioDevice);
    }

    currentPositionMs = 0;
}

// Close and cleanup
void BGMusicPlayer::Close()
{
    Stop();

    std::lock_guard<std::mutex> lock(stateMutex);

    CleanupSDL();
    CleanupFFmpeg();

    currentFile.clear();
}

// Cleanup FFmpeg resources
void BGMusicPlayer::CleanupFFmpeg()
{
    if (swrContext)
    {
        swr_free(&swrContext);
        swrContext = nullptr;
    }

    if (frame)
    {
        av_frame_free(&frame);
        frame = nullptr;
    }

    if (packet)
    {
        av_packet_free(&packet);
        packet = nullptr;
    }

    if (audioCodecContext)
    {
        avcodec_free_context(&audioCodecContext);
        audioCodecContext = nullptr;
    }

    if (formatContext)
    {
        avformat_close_input(&formatContext);
        formatContext = nullptr;
    }

    audioStreamIndex = -1;
    totalDurationMs = 0;
}

// Cleanup SDL resources
void BGMusicPlayer::CleanupSDL()
{
    if (audioDevice)
    {
        SDL_CloseAudioDevice(audioDevice);
        audioDevice = 0;
    }

    if (audioBuffer)
    {
        delete[] audioBuffer;
        audioBuffer = nullptr;
        audioBufferSize = 0;
        audioBufferMaxSize = 0;
    }
}

// Decoding thread loop
void BGMusicPlayer::DecodeLoop()
{
    while (playing && !shouldStop)
    {
        if (paused)
        {
            usleep(10000); // 10ms
            continue;
        }

        // Check buffer size - keep it reasonably full
        int currentBufferSize;
        {
            std::lock_guard<std::mutex> lock(bufferMutex);
            currentBufferSize = audioBufferSize;
        }

        if (currentBufferSize > audioBufferMaxSize / 2)
        {
            usleep(10000); // 10ms - buffer has enough data
            continue;
        }

        // Decode next packet
        if (!DecodeAudioPacket())
        {
            // End of file - wait for buffer to drain
            while (true)
            {
                std::lock_guard<std::mutex> lock(bufferMutex);
                if (audioBufferSize == 0 || shouldStop)
                    break;
                usleep(100000); // 100ms
            }
            playing = false;
            break;
        }
    }
}

// Decode one audio packet
bool BGMusicPlayer::DecodeAudioPacket()
{
    int ret = av_read_frame(formatContext, packet);

    if (ret < 0)
    {
        if (ret == AVERROR_EOF)
        {
            return false; // End of file
        }
        std::cerr << "Error reading frame" << std::endl;
        return false;
    }

    // Only process audio packets
    if (packet->stream_index != audioStreamIndex)
    {
        av_packet_unref(packet);
        return true;
    }

    // Send packet to decoder
    ret = avcodec_send_packet(audioCodecContext, packet);
    if (ret < 0)
    {
        std::cerr << "Error sending packet to decoder" << std::endl;
        av_packet_unref(packet);
        return false;
    }

    // Receive decoded frame
    while (ret >= 0)
    {
        ret = avcodec_receive_frame(audioCodecContext, frame);

        if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF)
        {
            break;
        }
        else if (ret < 0)
        {
            std::cerr << "Error decoding audio frame" << std::endl;
            av_packet_unref(packet);
            return false;
        }

        // Resample to output format
        uint8_t *outputBuffer[1];
        int maxSamples = av_rescale_rnd(frame->nb_samples, audioSpec.freq,
                                        audioCodecContext->sample_rate, AV_ROUND_UP);
        int bufferSize = maxSamples * audioInfo.channels * audioInfo.bytesPerSample;
        uint8_t *tempBuffer = new uint8_t[bufferSize];
        outputBuffer[0] = tempBuffer;

        int samples = swr_convert(swrContext, outputBuffer, maxSamples,
                                  (const uint8_t **)frame->data, frame->nb_samples);

        if (samples > 0)
        {
            int dataSize = samples * audioInfo.channels * audioInfo.bytesPerSample;

            // Apply volume gain if not 1.0
            if (volumeGain != 1.0f)
            {
                // Assuming 16-bit signed integer samples (AUDIO_S16SYS)
                int16_t *samplePtr = reinterpret_cast<int16_t *>(tempBuffer);
                int numSamples = dataSize / sizeof(int16_t);

                for (int i = 0; i < numSamples; i++)
                {
                    float sample = static_cast<float>(samplePtr[i]) * volumeGain;

                    // Clamp to prevent overflow
                    if (sample > 32767.0f)
                        sample = 32767.0f;
                    if (sample < -32768.0f)
                        sample = -32768.0f;

                    samplePtr[i] = static_cast<int16_t>(sample);
                }
            }

            // Add to internal buffer for callback
            std::lock_guard<std::mutex> lock(bufferMutex);
            if (audioBufferSize + dataSize <= audioBufferMaxSize)
            {
                memcpy(audioBuffer + audioBufferSize, tempBuffer, dataSize);
                audioBufferSize += dataSize;
            }

            // Update position
            if (frame->pts != AV_NOPTS_VALUE)
            {
                AVRational timeBase = formatContext->streams[audioStreamIndex]->time_base;
                currentPositionMs = (frame->pts * timeBase.num * 1000) / timeBase.den;
            }
        }

        delete[] tempBuffer;
        av_frame_unref(frame);
    }

    av_packet_unref(packet);
    return true;
}

// Static audio callback for SDL
void BGMusicPlayer::AudioCallback(void *userdata, uint8_t *stream, int len)
{
    BGMusicPlayer *player = static_cast<BGMusicPlayer *>(userdata);
    if (player)
    {
        player->FillAudioBuffer(stream, len);
    }
}

// Fill audio buffer for SDL callback
void BGMusicPlayer::FillAudioBuffer(uint8_t *stream, int len)
{
    std::lock_guard<std::mutex> lock(bufferMutex);

    if (audioBufferSize >= len)
    {
        // Enough data available
        memcpy(stream, audioBuffer, len);

        // Shift remaining data
        audioBufferSize -= len;
        if (audioBufferSize > 0)
        {
            memmove(audioBuffer, audioBuffer + len, audioBufferSize);
        }
    }
    else if (audioBufferSize > 0)
    {
        // Some data available, fill rest with silence
        memcpy(stream, audioBuffer, audioBufferSize);
        memset(stream + audioBufferSize, 0, len - audioBufferSize);
        audioBufferSize = 0;
    }
    else
    {
        // No data available, fill with silence
        memset(stream, 0, len);
    }
}

// Check if playing
bool BGMusicPlayer::IsPlaying() const
{
    return playing;
}

// Get current position
int BGMusicPlayer::GetPositionMs() const
{
    return currentPositionMs;
}

// Get duration
int BGMusicPlayer::GetDurationMs() const
{
    return totalDurationMs;
}

// Pause
void BGMusicPlayer::Pause()
{
    paused = true;
    if (audioDevice)
    {
        SDL_PauseAudioDevice(audioDevice, 1);
    }
}

// Resume
void BGMusicPlayer::Resume()
{
    paused = false;
    if (audioDevice && playing)
    {
        SDL_PauseAudioDevice(audioDevice, 0);
    }
}

// Check if paused
bool BGMusicPlayer::IsPaused() const
{
    return paused;
}

// Set volume gain (percent: 100 = normal, 200 = 2x, etc.)
void BGMusicPlayer::SetVolumeGain(int percent)
{
    if (percent < 0)
        percent = 0;
    if (percent > 400)
        percent = 400; // Max 4x gain to prevent excessive distortion
    volumeGain = static_cast<float>(percent) / 100.0f;
}

// Get volume gain as percent
int BGMusicPlayer::GetVolumeGain() const
{
    return static_cast<int>(volumeGain * 100.0f);
}
