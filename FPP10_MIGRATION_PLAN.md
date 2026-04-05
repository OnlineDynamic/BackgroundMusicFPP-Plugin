# FPP 10 Migration Plan — Background Music Plugin

## Overview

Migrate plugin from custom bgmplayer (SDL2+FFmpeg) + self-managed PipeWire to
GStreamer + FPP 10's system-wide PipeWire (`fpp-pipewire.service`).

**Decision:** Plugin uses its own PipeWire combine-stream sink `fpp_bgmusic_group`
for audio routing, independent of fppd's show audio group.

---

## Architecture Change Summary

| Area            | Pre-FPP10                                    | FPP 10                                                  |
| --------------- | -------------------------------------------- | ------------------------------------------------------- |
| Player          | `bgmplayer` (custom C++ SDL2+FFmpeg)         | `gst-launch-1.0 ... pipewiresink`                       |
| Audio server    | Plugin starts/stops its own PipeWire         | System-wide `fpp-pipewire.service` (always on)          |
| Audio routing   | Plugin manages ALSA device                   | `pipewiresink target-object=fpp_bgmusic_group`          |
| PipeWire socket | `/run/user/500/pipewire-0`                   | `/run/pipewire-fpp/pipewire-0`                          |
| Volume control  | `pw-cli set-param <stream> Props {volume:X}` | `wpctl set-volume <node-id> <float>`                    |
| Show transition | Kill PipeWire + bgmplayer, release ALSA      | Just stop GStreamer pipeline (PipeWire stays running)   |
| Crossfade       | Two bgmplayer processes                      | Two GStreamer pipelines targeting same sink             |
| PSA/Announce    | Separate bgmplayer + ducking                 | Separate GStreamer pipeline + wpctl ducking             |
| Stream identity | `PIPEWIRE_PROPS={media.name=X}`              | `stream-properties="props,node.name=X"` on pipewiresink |
| Env vars        | `XDG_RUNTIME_DIR=/run/user/500`              | `PIPEWIRE_REMOTE=/run/pipewire-fpp/pipewire-0`          |

---

## Files to Remove

- [ ] `src/bgmplayer_main.cpp` — replaced by gst-launch-1.0
- [ ] `src/BGMusicPlayer.cpp` — replaced by gst-launch-1.0
- [ ] `src/BGMusicPlayer.h` — replaced by gst-launch-1.0
- [ ] `Makefile` — no more C++ compilation
- [ ] `bgmplayer` (binary) — no more custom player
- [ ] `scripts/start_pipewire.sh` — PipeWire is system service
- [ ] `scripts/set_audio_output.sh` — routing via audio groups
- [ ] `scripts/fade_to_stop.sh` — legacy mpg123 script (unused)

---

## Files to Rewrite

### scripts/fpp_install.sh
- Remove: SDL2/FFmpeg dev packages, `make` bgmplayer compilation
- Remove: PipeWire package installation (already system service)
- Remove: Per-user PipeWire config (`~/.config/pipewire/`)
- Remove: WirePlumber per-user config
- Remove: `/run/user/500` creation
- Remove: `start_pipewire.sh` call
- Add: Verify GStreamer + PipeWire available (`gst-launch-1.0`, `wpctl`)
- Add: Verify `fpp-pipewire.service` is running
- Keep: jq install, permissions, brightness plugin check, log setup

### scripts/fpp_uninstall.sh
- Change: Kill `gst-launch-1.0` processes instead of `bgmplayer`
- Remove: PipeWire config cleanup (system-managed)
- Keep: PID/state file cleanup, header indicator removal

### scripts/background_music_player.sh
- Replace `bgmplayer` invocations with `gst-launch-1.0` pipelines:
  - **Local files:** `gst-launch-1.0 filesrc location=X ! decodebin ! audioconvert ! audioresample ! audio/x-raw,rate=48000 ! pipewiresink target-object=fpp_bgmusic_group stream-properties="props,node.name=bgmusic_main"`
  - **Streams:** `gst-launch-1.0 souphttpsrc location=URL ! decodebin ! audioconvert ! audioresample ! audio/x-raw,rate=48000 ! pipewiresink target-object=fpp_bgmusic_group stream-properties="props,node.name=bgmusic_main"`
  - **Crossfade:** Same but `node.name=bgmusic_crossfade`
- Remove: All `SDL_AUDIODRIVER`, `SDL_AUDIO_SAMPLES` env vars
- Remove: `get_audio_device()` function (no more ALSA device detection)
- Remove: PipeWire start/restart/socket cleanup logic
- Remove: `set_audio_output.sh` calls
- Change env vars: `PIPEWIRE_REMOTE=/run/pipewire-fpp/pipewire-0`
- Change stream detection: Use `pw-dump` with `PIPEWIRE_REMOTE` instead of `XDG_RUNTIME_DIR`
- Volume control: Switch from per-stream `pw-cli set-param` to `wpctl`

### scripts/fade_bgmplayer.sh → scripts/fade_bgmusic.sh (rename)
- Change: Find stream by `node.name=bgmusic_main` in PipeWire
- Change: Use `PIPEWIRE_REMOTE=/run/pipewire-fpp/pipewire-0`
- Change: Volume via `wpctl set-volume <node-id> <float>` steps
- Remove: References to bgmplayer PID file

### scripts/set_bgmplayer_volume.sh → scripts/set_bgmusic_volume.sh (rename)
- Change: Find node by `node.name` prefix `bgmusic_`
- Change: Use `wpctl` instead of `pw-cli set-param`
- Change: Use `PIPEWIRE_REMOTE`

### scripts/set_pipewire_volume.sh
- Simplify: Use `PIPEWIRE_REMOTE`, `wpctl`, find by `node.name`
- Remove: `sudo -u fpp` (commands run as root with PIPEWIRE_REMOTE)

### scripts/start_show_transition.sh
- Remove: `pkill -u fpp pipewire` — PipeWire stays running
- Remove: PipeWire socket cleanup
- Remove: ALSA device availability check
- Change: Kill `gst-launch-1.0` instead of `bgmplayer`
- Change: Use `PIPEWIRE_REMOTE` for wpctl/pw-cli calls
- Keep: Brightness fade, bgmusic volume fade, show playlist start

### scripts/play_announcement.sh
- Change: Use `gst-launch-1.0 ... pipewiresink target-object=fpp_bgmusic_group stream-properties="props,node.name=bgmusic_psa"` instead of bgmplayer
- Remove: `ffmpeg` transcode to 48kHz WAV (GStreamer handles conversion)
- Remove: PipeWire start check (always running)
- Change: Volume control via `wpctl`

### scripts/fade_audio.sh
- Change: Use `wpctl` with `PIPEWIRE_REMOTE` for volume fade
- Remove: ALSA `amixer` fallback

### scripts/restore_audio_volume.sh
- Simplify: Use `wpctl set-volume @DEFAULT_AUDIO_SINK@` with `PIPEWIRE_REMOTE`
- Remove: ALSA card detection, amixer calls

### scripts/postStart.sh
- Remove: PipeWire socket cleanup (system service manages)
- Remove: PipeWire start logic
- Keep: Autostart background music

### scripts/postStop.sh
- Remove: PipeWire process killing (system service stays running)
- Remove: PipeWire socket cleanup
- Change: Kill `gst-launch-1.0` instead of `bgmplayer`
- Keep: State/PID file cleanup

### scripts/playlistStart.sh
- Remove: PipeWire killing (no longer needed — coexist)
- Change: Stop background music GStreamer pipelines only

### scripts/preStart.sh
- Remove: `make` call (no more C++ build)

### scripts/return_to_preshow.sh
- Keep: Logic mostly unchanged
- Change: Volume via `wpctl` / FPP API

### scripts/monitor_show_completion.sh
- Keep: Mostly unchanged (monitors FPP API)

---

## New Helper: scripts/pw_env.sh

Shared environment setup sourced by all scripts:

```bash
#!/bin/bash
# Common PipeWire environment for FPP 10
export PIPEWIRE_REMOTE=/run/pipewire-fpp/pipewire-0
export PIPEWIRE_RUNTIME_DIR=/run/pipewire-fpp
export XDG_RUNTIME_DIR=/run/pipewire-fpp

# Plugin's combine-stream sink name
BGMUSIC_SINK="fpp_bgmusic_group"

# GStreamer pipeline helpers
gst_play_file() {
    local file="$1"
    local node_name="${2:-bgmusic_main}"
    gst-launch-1.0 -q \
        filesrc location="$file" ! decodebin ! audioconvert ! audioresample \
        ! "audio/x-raw,rate=48000" \
        ! pipewiresink target-object="$BGMUSIC_SINK" \
          stream-properties="props,node.name=$node_name,media.class=Stream/Output/Audio"
}

gst_play_stream() {
    local url="$1"
    local node_name="${2:-bgmusic_main}"
    gst-launch-1.0 -q \
        souphttpsrc location="$url" ! decodebin ! audioconvert ! audioresample \
        ! "audio/x-raw,rate=48000" \
        ! pipewiresink target-object="$BGMUSIC_SINK" \
          stream-properties="props,node.name=$node_name,media.class=Stream/Output/Audio"
}

# Find a bgmusic node ID by name
find_bgmusic_node() {
    local name="${1:-bgmusic_main}"
    pw-dump 2>/dev/null | jq -r \
        --arg name "$name" \
        '.[] | select(.type == "PipeWire:Interface:Node")
             | select(.info.props["node.name"]? == $name)
             | .id' | tail -1
}

# Set volume on a bgmusic node (0-100)
set_bgmusic_volume() {
    local node_id="$1"
    local volume_pct="$2"
    local vol_float=$(awk "BEGIN {printf \"%.4f\", $volume_pct / 100.0}")
    wpctl set-volume "$node_id" "$vol_float"
}
```

---

## Implementation Order

1. Create `scripts/pw_env.sh` helper
2. Remove C++ source files and Makefile
3. Rewrite `scripts/fpp_install.sh`
4. Rewrite `scripts/background_music_player.sh`
5. Rewrite `scripts/fade_bgmplayer.sh` → `scripts/fade_bgmusic.sh`
6. Rewrite `scripts/set_bgmplayer_volume.sh` → `scripts/set_bgmusic_volume.sh`
7. Rewrite `scripts/set_pipewire_volume.sh`
8. Rewrite `scripts/start_show_transition.sh`
9. Rewrite `scripts/play_announcement.sh`
10. Rewrite `scripts/fade_audio.sh`
11. Rewrite `scripts/restore_audio_volume.sh`
12. Update lifecycle hooks (postStart, postStop, preStart, preStop, playlistStart)
13. Remove obsolete scripts (start_pipewire.sh, set_audio_output.sh, fade_to_stop.sh)
14. Update API (api.php) and functions (functions.inc.php) for new process names
15. Update UI (backgroundmusic.php, content.php) if needed

---

## Status Tracking

- [x] Plan created
- [ ] Step 1: pw_env.sh helper
- [ ] Step 2: Remove C++ source files
- [ ] Step 3: fpp_install.sh
- [ ] Step 4: background_music_player.sh
- [ ] Step 5: fade_bgmusic.sh
- [ ] Step 6: set_bgmusic_volume.sh
- [ ] Step 7: set_pipewire_volume.sh
- [ ] Step 8: start_show_transition.sh
- [ ] Step 9: play_announcement.sh
- [ ] Step 10: fade_audio.sh
- [ ] Step 11: restore_audio_volume.sh
- [ ] Step 12: Lifecycle hooks
- [ ] Step 13: Remove obsolete scripts
- [ ] Step 14: API/functions update
- [ ] Step 15: UI update
