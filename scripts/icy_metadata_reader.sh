#!/bin/bash
# ICY Metadata Reader - Extracts StreamTitle from Icecast/Shoutcast streams
# Usage: icy_metadata_reader.sh <stream_url>

STREAM_URL="$1"

if [ -z "$STREAM_URL" ]; then
    echo "Usage: $0 <stream_url>"
    exit 1
fi

# Read stream with ICY metadata request and extract title
# This uses curl to read the stream and parse ICY metadata blocks
(
    # Request stream with ICY metadata
    curl -s -H "Icy-MetaData: 1" --max-time 30 "$STREAM_URL" | \
    while IFS= read -r -n1 byte; do
        # This is a simplified approach - proper parsing would need to handle icy-metaint
        # For now, we'll just grep the output
        printf "%s" "$byte"
    done
) 2>&1 | strings | grep -o "StreamTitle='[^']*'" | head -1 | sed "s/StreamTitle='\\(.*\\)'/\\1/"
