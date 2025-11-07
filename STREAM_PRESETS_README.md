# Stream Presets Configuration

This file contains the list of preset internet radio streams available in the Background Music plugin's dropdown menu.

## File Format

The `stream_presets.json` file uses a simple JSON structure:

```json
{
    "presets": [
        {
            "name": "Station Name",
            "url": "https://stream-url-here.com/stream.mp3"
        }
    ]
}
```

## Adding a New Stream

1. Open `stream_presets.json`
2. Add a new entry to the `presets` array:
   ```json
   {
       "name": "Your Station Name",
       "url": "https://your-stream-url.com/stream"
   }
   ```
3. Make sure to add a comma after the previous entry
4. Save the file
5. Refresh the Background Music settings page

## Removing a Stream

1. Open `stream_presets.json`
2. Delete the entire entry (including the curly braces)
3. Remove any trailing commas to keep valid JSON
4. Save the file
5. Refresh the Background Music settings page

## Finding Stream URLs

Common sources for finding stream URLs:
- Radio station websites (look for "Listen Live" or "Stream URL")
- Public radio directories
- Check for `.pls`, `.m3u`, or direct `.mp3` stream URLs
- Use your browser's developer tools to inspect network traffic when playing streams

## Example URLs

Different stream formats you might encounter:
- Direct MP3: `http://stream.example.com:8000/stream.mp3`
- Icecast: `http://icecast.example.com:8000/mountpoint`
- Shoutcast: `http://shoutcast.example.com:8000/`
- HTTPS: `https://secure-stream.example.com/radio`
- HLS (may not work): `https://example.com/playlist.m3u8`

**Note**: The plugin uses ffplay for streaming, which works best with:
- MP3 streams
- AAC streams
- Ogg Vorbis streams
- HTTP/HTTPS protocols

## JSON Validation

After editing, you can validate your JSON at: https://jsonlint.com/

Common JSON errors:
- Missing comma between entries
- Trailing comma after last entry (remove it)
- Unescaped quotes in strings (use `\"` for quotes within strings)
- Mismatched brackets `{` `}`

## Fallback Behavior

If the JSON file is missing or invalid, the plugin will fall back to a single hardcoded preset:
- The Miller Lights Holiday Radio

This ensures the plugin always has at least one preset available.
