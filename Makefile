# Background Music Plugin Makefile
# Compiles the custom audio player (bgmplayer) that replaces ffplay

CXX = g++
CXXFLAGS = -std=c++11 -Wall -O2
LDFLAGS = -pthread

# FFmpeg libraries
FFMPEG_LIBS = -lavformat -lavcodec -lavutil -lswresample

# SDL2 libraries
SDL_CFLAGS = $(shell sdl2-config --cflags 2>/dev/null || echo "")
SDL_LIBS = $(shell sdl2-config --libs 2>/dev/null || echo "-lSDL2")

# Combine all flags
ALL_CFLAGS = $(CXXFLAGS) $(SDL_CFLAGS)
ALL_LIBS = $(FFMPEG_LIBS) $(SDL_LIBS) $(LDFLAGS)

# Source files
SRC_DIR = src
SOURCES = $(SRC_DIR)/BGMusicPlayer.cpp $(SRC_DIR)/bgmplayer_main.cpp
OBJECTS = $(SOURCES:.cpp=.o)

# Output binary
TARGET = bgmplayer

# Default target
all: check-deps $(TARGET)

# Link the final executable
$(TARGET): $(OBJECTS)
	@echo "Linking $(TARGET)..."
	$(CXX) $(OBJECTS) $(ALL_LIBS) -o $(TARGET)
	@echo "Build complete: $(TARGET)"

# Compile source files
$(SRC_DIR)/%.o: $(SRC_DIR)/%.cpp $(SRC_DIR)/BGMusicPlayer.h
	@echo "Compiling $<..."
	$(CXX) $(ALL_CFLAGS) -c $< -o $@

# Clean build artifacts
clean:
	@echo "Cleaning..."
	rm -f $(OBJECTS) $(TARGET)
	@echo "Clean complete"

# Install (done by fpp_install.sh, but included for manual use)
install: $(TARGET)
	@echo "Player already in plugin directory"

# Check dependencies
check-deps:
	@echo "Checking build dependencies..."
	@which g++ > /dev/null 2>&1 || (echo "ERROR: g++ not found. Install: apt-get install g++" && exit 1)
	@which sdl2-config > /dev/null 2>&1 || (echo "ERROR: SDL2 development files not found. Install: apt-get install libsdl2-dev" && exit 1)
	@pkg-config --exists libavformat 2>/dev/null || (echo "ERROR: FFmpeg development files not found. Install: apt-get install libavformat-dev libavcodec-dev libavutil-dev libswresample-dev" && exit 1)
	@echo "All dependencies found ✓"

.PHONY: all clean install check-deps