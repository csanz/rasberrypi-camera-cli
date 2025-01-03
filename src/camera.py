#!/usr/bin/env python3
import argparse
import subprocess
import sys
import os
import time
from datetime import datetime
from pathlib import Path
from dotenv import load_dotenv

def load_config():
    # Try to load from root directory first, then fall back to src directory
    root_env = Path(__file__).parent.parent / 'config.env'
    src_env = Path(__file__).parent / 'config.env'
    
    if root_env.exists():
        load_dotenv(root_env)
    elif src_env.exists():
        load_dotenv(src_env)
    else:
        print("Warning: No config.env found, using default values")

class CameraConfig:
    def __init__(self):
        load_config()
        # ... rest of the config initialization ...

class CameraManager:
    def __init__(self):
        self.camera_type = self._detect_camera_system()

    def _detect_camera_system(self):
        """Detect whether to use picamera or libcamera"""
        try:
            import picamera
            print("Using PiCamera (legacy camera system)")
            return "picamera"
        except ImportError:
            # Check if libcamera is available
            try:
                result = subprocess.run(['libcamera-jpeg', '--version'], 
                                     capture_output=True, 
                                     text=True)
                print("Using libcamera (new camera system)")
                return "libcamera"
            except FileNotFoundError:
                print("Error: Neither PiCamera nor libcamera found!")
                sys.exit(1)

    def take_photo(self, filename):
        if not filename.lower().endswith('.jpg'):
            filename += '.jpg'

        if self.camera_type == "picamera":
            self._take_photo_picamera(filename)
        else:
            self._take_photo_libcamera(filename)

    def take_video(self, filename, duration=10):
        if not filename.lower().endswith('.mp4'):
            filename += '.mp4'

        if self.camera_type == "picamera":
            self._take_video_picamera(filename, duration)
        else:
            self._take_video_libcamera(filename, duration)

    def _take_photo_picamera(self, filename):
        try:
            import picamera
            with picamera.PiCamera() as camera:
                camera.resolution = (2592, 1944)  # Max resolution
                camera.start_preview()
                time.sleep(2)  # Camera warm-up time
                camera.capture(filename)
                print(f"Photo saved as: {filename}")
        except Exception as e:
            print(f"Error taking photo with PiCamera: {e}")

    def _take_photo_libcamera(self, filename):
        try:
            cmd = [
                'libcamera-jpeg',
                '-o', filename,
                '--width', '2592',
                '--height', '1944',
                '--nopreview'
            ]
            subprocess.run(cmd, check=True)
            print(f"Photo saved as: {filename}")
        except subprocess.CalledProcessError as e:
            print(f"Error taking photo with libcamera: {e}")

    def _take_video_picamera(self, filename, duration):
        try:
            import picamera
            with picamera.PiCamera() as camera:
                camera.resolution = (1920, 1080)
                camera.start_preview()
                print(f"Recording video for {duration} seconds...")
                camera.start_recording(filename)
                camera.wait_recording(duration)
                camera.stop_recording()
                print(f"Video saved as: {filename}")
        except Exception as e:
            print(f"Error recording video with PiCamera: {e}")

    def _take_video_libcamera(self, filename, duration):
        try:
            cmd = [
                'libcamera-vid',
                '-o', filename,
                '--width', '1920',
                '--height', '1080',
                '-t', str(duration * 1000)  # Convert to milliseconds
            ]
            print(f"Recording video for {duration} seconds...")
            subprocess.run(cmd, check=True)
            print(f"Video saved as: {filename}")
        except subprocess.CalledProcessError as e:
            print(f"Error recording video with libcamera: {e}")

def main():
    parser = argparse.ArgumentParser(
        description='Raspberry Pi Camera CLI tool (supports both PiCamera and libcamera)'
    )
    
    parser.add_argument('--take-photo', metavar='filename',
                        help='Take a photo and save it as JPG')
    parser.add_argument('--take-video', metavar='filename',
                        help='Record a video and save it as MP4')
    parser.add_argument('--duration', type=int, default=10,
                        help='Video duration in seconds (default: 10)')

    args = parser.parse_args()

    if len(sys.argv) == 1:
        parser.print_help()
        sys.exit(1)

    camera = CameraManager()

    if args.take_photo:
        camera.take_photo(args.take_photo)
    elif args.take_video:
        camera.take_video(args.take_video, args.duration)

if __name__ == "__main__":
    main()