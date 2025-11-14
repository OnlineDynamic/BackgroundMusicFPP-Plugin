#!/usr/bin/env python

import time
import os
import argparse   
import sys
import json
import subprocess

class Logger(object):
    def __init__(self, filename="/home/fpp/media/logs/fpp-plugin-BackgroundMusic.log"):
        self.terminal = sys.stdout
        self.log = open(filename, "a")

    def write(self, message):
        self.terminal.write(message)
        self.log.write(message)
    
    def flush(self):
        self.terminal.flush()
        self.log.flush()

sys.stdout = Logger("/home/fpp/media/logs/fpp-plugin-BackgroundMusic.log")

parser = argparse.ArgumentParser(description='BackgroundMusic Plugin')
parser.add_argument('-l','--list', help='Plugin Actions',action='store_true')
parser.add_argument('--type', help='Callback type')
parser.add_argument('--data', help='Callback data')
args = parser.parse_args()

if args.list:
    # Register for daemon_start callback to handle autostart
    print('{"daemon_start": {"description": "FPP Daemon Started"}}')
    sys.exit(0)

if args.type == "daemon_start":
    print(time.strftime("%Y-%m-%d %H:%M:%S") + " [callback] FPP daemon started, checking autostart...")
    sys.stdout.flush()
    
    # Check if autostart is enabled
    config_file = "/home/fpp/media/config/plugin.fpp-plugin-BackgroundMusic"
    autostart_enabled = False
    
    if os.path.exists(config_file):
        with open(config_file, 'r') as f:
            for line in f:
                if line.startswith('AutostartEnabled='):
                    value = line.split('=')[1].strip().strip('"')
                    autostart_enabled = (value == '1')
                    break
    
    if autostart_enabled:
        print(time.strftime("%Y-%m-%d %H:%M:%S") + " [callback] Autostart enabled, starting background music in 5 seconds...")
        sys.stdout.flush()
        
        # Give FPP extra time to fully initialize after restart
        time.sleep(5)
        
        script_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "scripts", "background_music_player.sh")
        try:
            # Run as fpp user to avoid permission issues
            result = subprocess.run(["su", "-", "fpp", "-c", f"/bin/bash '{script_path}' start"], 
                                  capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                print(time.strftime("%Y-%m-%d %H:%M:%S") + " [callback] Background music autostart successful")
            else:
                print(time.strftime("%Y-%m-%d %H:%M:%S") + " [callback] Background music autostart failed: " + result.stderr)
        except Exception as e:
            print(time.strftime("%Y-%m-%d %H:%M:%S") + " [callback] Background music autostart error: " + str(e))
    else:
        print(time.strftime("%Y-%m-%d %H:%M:%S") + " [callback] Autostart not enabled, skipping")
