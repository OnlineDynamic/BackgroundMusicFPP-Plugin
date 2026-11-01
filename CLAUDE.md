# BackgroundMusic FPP Plugin — context for Claude

Falcon Player (FPP) plugin that plays background music (local playlist or internet
stream) during the pre-show, fades it out and starts the main show, and optionally
restarts the music after the show. Also: PSA announcements with ducking, Piper /
ElevenLabs TTS, header indicator, autostart.

- Repo: github.com/OnlineDynamic/BackgroundMusicFPP-Plugin (`master` = FPP 10+,
  `pre-fpp10` branch = FPP 9). `gh` is not installed; use the GitHub REST API via curl.
- Runs live on this device: plugin dir `/home/fpp/media/plugins/fpp-plugin-BackgroundMusic`.
  Changes take effect immediately (PHP served by FPP's web server, scripts run by path).
- No build step, no test suite. Verify with `php -l <file>`, `bash -n <script>`, and by
  running scripts with a stubbed `curl` on PATH plus sed-redirected config/log/pid paths
  (in the scratchpad), so the real config and a live monitor aren't touched.

## Key paths (runtime)

| What | Path |
|---|---|
| Plugin settings (INI `Key=value`, values with spaces quoted) | `/home/fpp/media/config/plugin.fpp-plugin-BackgroundMusic` |
| Plugin log | `/home/fpp/media/logs/fpp-plugin-BackgroundMusic.log` |
| FPP playlists / sequences / music | `/home/fpp/media/{playlists/*.json,sequences/*.fseq,music}` |
| FPP status API | `http://localhost/api/fppd/status` → `status_name`, `current_playlist.playlist`, `current_sequence` |
| PipeWire socket (FPP 10 system-wide) | `/run/pipewire-fpp/pipewire-0` |
| State/PID files | `/tmp/background_music_player.pid`, `/tmp/bg_music_loop.sh` (generated), `/tmp/bg_music_status.txt`, `/tmp/show_monitor.pid`, `/tmp/announcement_*.pid` |

## File map

**PHP / UI**
- `api.php` — every REST endpoint (`/api/plugin/fpp-plugin-BackgroundMusic/<endpoint>`),
  registered in `getEndpointsfpppluginBackgroundMusic()` at the top. Notable ones:
  `status` (~L206, returns `config` object used by status page), `save-settings` (~L759,
  writes **every key posted**, replacing the whole config file), `start-show`,
  `system-diagnostics` (~L1949, text dump of settings).
- `content.php` — Settings page. PHP helpers at top (`getPlaylists`, `getSequences`,
  `filterNonEmptyPlaylists`, `getMediaOnlyPlaylists`), HTML settings tables, then JS
  `saveSettings()` (~L1175) that builds `formData` explicitly.
- `backgroundmusic.php` — Status/controller page; reads `data.config.*` from the `status` API.
- `help/backgroundmusic-help.php` — Tabbed help page (overview, setup, PSA, API, troubleshooting).
- `functions.inc.php` — small shared PHP helpers (`getPluginSetting`, `getFPPStatus`, ...).
- `menu.inc` — FPP menu entries. `pluginInfo.json` — FPP plugin manifest.

**Scripts (`scripts/`)**
- `pw_env.sh` — sourced by most scripts: PipeWire env, common paths, PID file names,
  `log_message`, `get_plugin_setting KEY DEFAULT`. (Older scripts like
  `monitor_show_completion.sh` / `return_to_preshow.sh` define their own paths and
  `grep "^Key="` the config instead.)
- `background_music_player.sh` — `start|stop|pause|resume|next|previous|jump N`. Generates
  `/tmp/bg_music_loop.sh` (GStreamer playback loop, crossfade, auto-PSA, stream metadata) and
  runs it with nohup. Control is via flag files in `/tmp` (`bg_music_next.txt` etc.).
- `start_show_transition.sh FADE BLACKOUT PLAYLIST` — fade brightness (fpp-brightness plugin
  API) + music, stop playlists & music, blackout, set show volume, start show, then launch
  `monitor_show_completion.sh`.
- `monitor_show_completion.sh SHOW_PLAYLIST` — polls FPP every 2s; on show end runs
  `return_to_preshow.sh`. End condition: playlist name changed or idle; with
  `ResumeOnlyWhenIdle=1`, only idle or the `PreShowSequence` playlist/sequence running.
- `return_to_preshow.sh [SHOW_PLAYLIST]` — honours `ReturnToPreShow`, `PostShowDelay`,
  `PostShowBackgroundVolume`, `ResumeMode`; re-checks idle in idle-only mode (relaunches
  monitor if not idle); restarts music.
- PSA/TTS: `play_announcement.sh`, `play_tts_announcement.sh`, `generate_tts.sh` (Piper),
  `generate_tts_elevenlabs.sh`, `install_piper.sh`, `install_voice.sh`.
- Volume/fade: `fade_bgmusic.sh`, `fade_audio.sh`, `set_bgmusic_volume.sh`,
  `set_pipewire_volume.sh`, `restore_audio_volume.sh`.
- FPP lifecycle hooks: `fpp_install.sh`, `fpp_uninstall.sh`, `preStart.sh`, `postStart.sh`,
  `preStop.sh`, `postStop.sh` (kills plugin processes), `playlistStart.sh`.
- `callbacks.py` — FPP callback; on `daemon_start` handles `AutostartEnabled`.

**FPP commands (`commands/`)** — `descriptions.json` declares commands shown in FPP's
command list; each maps to a `.sh` (start-show, start/stop background music, play-psa, GPIO).

## Adding a new setting — touch all of these

1. `content.php`: input in the right settings table (use `$pluginSettings['Key']` for the
   saved value) **and** add to `formData` in `saveSettings()` — otherwise it gets wiped on
   the next save, because save-settings rewrites the whole file.
2. Scripts that use it: read via `get_plugin_setting` or `grep "^Key=" ... | cut -d'=' -f2-`
   (strip `\r` and surrounding quotes if values can contain spaces).
3. `api.php`: add to `status` → `config` array and to `system-diagnostics` if useful.
4. `backgroundmusic.php`: status item + `$('#configX').text(data.config.x)` if shown.
5. Docs: `help/backgroundmusic-help.php`, README config example.

## Conventions

- Bash scripts: header comment block, `log_message` to the plugin log, `curl -s
  --connect-timeout 3 --max-time 5` against localhost APIs, `jq -r '.x // ""'` for parsing.
- Booleans in config are `'1'` / `'0'` strings.
- Commit style: conventional prefixes (`feat:`, `fix:`), reference issues as `(#NN)`.
- Existing setups must keep working: new behaviour goes behind a setting that defaults off.
