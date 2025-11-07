#!/usr/bin/env python3
"""
ICY Metadata Reader for Icecast/Shoutcast streams
Extracts StreamTitle from internet radio streams
"""
import urllib.request
import sys
import struct

def extract_icy_metadata(stream_url, timeout=10):
    """Extract ICY metadata from a stream URL"""
    try:
        # Create request with ICY metadata header
        req = urllib.request.Request(stream_url)
        req.add_header('Icy-MetaData', '1')
        req.add_header('User-Agent', 'FPP Background Music Plugin/1.0')
        
        # Open stream
        response = urllib.request.urlopen(req, timeout=timeout)
        headers = response.info()
        
        # Check if stream supports ICY metadata
        metaint = headers.get('icy-metaint')
        if not metaint:
            # No ICY metadata support
            return None
        
        metaint = int(metaint)
        
        # Read audio data up to metadata block
        audio_data = response.read(metaint)
        
        # Read metadata length (1 byte, multiply by 16 to get actual length)
        meta_length_byte = response.read(1)
        if not meta_length_byte:
            return None
            
        meta_length = struct.unpack('B', meta_length_byte)[0] * 16
        
        if meta_length == 0:
            return None
        
        # Read metadata
        metadata = response.read(meta_length).decode('utf-8', errors='ignore').strip('\x00')
        
        # Extract StreamTitle
        if 'StreamTitle=' in metadata:
            # Parse StreamTitle='...'
            start = metadata.index('StreamTitle=') + 13
            end = metadata.index("'", start) if "'" in metadata[start:] else len(metadata)
            stream_title = metadata[start:end].strip()
            return stream_title
        
        return None
        
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return None

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: icy_metadata_reader.py <stream_url>", file=sys.stderr)
        sys.exit(1)
    
    stream_url = sys.argv[1]
    title = extract_icy_metadata(stream_url)
    
    if title:
        print(title)
    else:
        # Return empty string if no metadata found
        print("")
