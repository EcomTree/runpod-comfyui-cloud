#!/usr/bin/env python3
"""
ComfyUI Model Downloader Script
Downloads all validated ComfyUI models to the specified directory.
"""

import os
import json
import requests
import time
import sys
import shutil
from pathlib import Path
from urllib.parse import urlparse
import subprocess

# Constants
PROGRESS_REPORT_INTERVAL_MB = 10  # Report progress every 10 MB
RETRY_BASE_DELAY_SECONDS = 5  # Base delay for exponential backoff
MIB_TO_BYTES = 1024 * 1024  # Bytes in one mebibyte (binary megabyte)
KB_TO_BYTES = 1024  # Bytes in one kilobyte
MIN_VALID_FILE_SIZE_KB = 10  # Minimum file size in KB to consider a download complete (10KB for small LoRAs)

# Model classification mapping: ordered from most specific to most general
MODEL_CLASSIFICATION_MAPPING = [
    ('unet', ['flux', 'sd3', 'auraflow', 'hunyuan', 'kolors', 'lumina']),
    ('vae', ['vae', 'kl-f8-anime']),
    ('clip_vision', ['clip_vision', 'image_encoder']),
    ('clip', ['clip', 'open_clip']),
    ('t5', ['t5', 'umt5']),
    ('controlnet', ['controlnet', 'control_', 'canny', 'depth', 'openpose', 'scribble']),
    ('loras', ['lora', '.lora']),
    ('upscale_models', ['esrgan', 'realesrgan', 'swinir', '4x', '2x', 'upscale']),
    ('animatediff_models', ['animatediff', 'mm_', 'motion']),
    ('ipadapter', ['ip-adapter', 'ip_adapter']),
    ('text_encoders', ['text_encoder', 'encoder']),
    ('checkpoints', ['.ckpt', '.safetensors']),
]

HF_TOKEN = os.getenv("HF_TOKEN")

SESSION = requests.Session()
SESSION.headers.update({
    'User-Agent': 'ComfyUI-Model-Downloader/1.0'
})

if HF_TOKEN:
    SESSION.headers['Authorization'] = f'Bearer {HF_TOKEN.strip()}'
else:
    print("⚠️  No HF_TOKEN set. Protected Hugging Face downloads may fail.")


class ComfyUIModelDownloader:
    def __init__(self, base_dir="/workspace", verification_file="link_verification_results.json"):
        self.base_dir = Path(base_dir)
        self.verification_file = verification_file
        self.models_dir = self.base_dir / "ComfyUI" / "models"
        self.session = SESSION

        # Create the directory structure
        self.create_directory_structure()

    def create_directory_structure(self):
        """Creates the necessary ComfyUI directory structure."""
        directories = [
            "checkpoints",
            "unet",
            "vae",
            "clip",
            "t5",
            "clip_vision",
            "controlnet",
            "loras",
            "upscale_models",
            "diffusion_models",
            "animatediff_models",
            "text_encoders",
            "ipadapter"
        ]

        for dir_name in directories:
            (self.models_dir / dir_name).mkdir(parents=True, exist_ok=True)

        print(f"📁 Directory structure created in: {self.models_dir}")

    def load_verified_links(self):
        """Loads the verified links from the JSON file."""
        try:
            with open(self.verification_file, 'r', encoding='utf-8') as f:
                data = json.load(f)
                return data.get('valid_links', [])
        except FileNotFoundError:
            print(f"❌ Verification file {self.verification_file} not found!")
            print("🔍 Run 'python3 scripts/verify_links.py' first.")
            sys.exit(1)

    def determine_target_directory(self, url):
        """Determines the target directory based on URL and filename."""
        filename = Path(urlparse(url).path).name.lower()

        # Use global classification mapping
        for directory, patterns in MODEL_CLASSIFICATION_MAPPING:
            # Check if filename contains patterns or has specific extensions
            for pattern in patterns:
                if pattern.startswith('.'):
                    if filename.endswith(pattern):
                        return directory
                elif pattern in filename:
                    return directory

        # Default fallback
        return "diffusion_models"

    def download_file(self, url, target_path, retry_count=3):
        """Downloads a single file with retry logic."""
        target_path = Path(target_path)
        target_path.parent.mkdir(parents=True, exist_ok=True)

        for attempt in range(retry_count):
            # Reset progress tracking for each attempt
            last_reported = 0
            
            try:
                # Clean filename from URL (remove query parameters)
                clean_url = url.split('?')[0]
                filename = Path(urlparse(clean_url).path).name
                print(f"⬇️  Downloading: {filename} (Attempt {attempt + 1}/{retry_count})")

                # Stream download for large files
                with self.session.get(url, stream=True, timeout=30) as response:
                    response.raise_for_status()

                    # Retrieve file size for progress output
                    total_size = int(response.headers.get('content-length', 0))

                    with open(target_path, 'wb') as f:
                        downloaded = 0
                        for chunk in response.iter_content(chunk_size=8192):
                            if chunk:
                                f.write(chunk)
                                downloaded += len(chunk)

                                # Progress reporting
                                if total_size > 0:
                                    report_threshold = PROGRESS_REPORT_INTERVAL_MB * MIB_TO_BYTES
                                    if downloaded - last_reported >= report_threshold or downloaded == total_size:
                                        progress = (downloaded / total_size) * 100
                                        print(f"   📈 {progress:.1f}% ({downloaded / MIB_TO_BYTES:.1f} MB)")
                                        last_reported = downloaded
                                else:
                                    # For files without content-length header, throttle logging
                                    report_threshold = PROGRESS_REPORT_INTERVAL_MB * MIB_TO_BYTES
                                    if downloaded - last_reported >= report_threshold:
                                        print(f"   📥 Downloaded: {downloaded / MIB_TO_BYTES:.1f} MB")
                                        last_reported = downloaded

                print(f"✅ Successfully downloaded: {target_path}")
                return True

            except requests.exceptions.RequestException as e:
                print(f"❌ Download error (Attempt {attempt + 1}): {e}")
                if attempt < retry_count - 1:
                    wait_time = (attempt + 1) * RETRY_BASE_DELAY_SECONDS  # Exponential backoff
                    print(f"⏳ Waiting {wait_time} seconds before retry...")
                    time.sleep(wait_time)
                else:
                    print(f"❌ Maximum retries reached for: {url}")
                    return False

            except Exception as e:
                print(f"❌ Unexpected error: {e}")
                return False

    def download_all_models(self):
        """Downloads all models sequentially for stability."""
        valid_links = self.load_verified_links()

        if not valid_links:
            print("❌ No validated links found!")
            return

        print(f"🚀 Starting download of {len(valid_links)} models...")
        print(f"📁 Target directory: {self.models_dir}")

        successful = 0
        failed = 0

        def download_single_model(url):
            # Extract clean filename from URL
            clean_url = url.split('?')[0]
            filename = Path(urlparse(clean_url).path).name
            
            target_dir = self.determine_target_directory(url)
            target_path = self.models_dir / target_dir / filename

            # Check if file exists and has reasonable size (not just a partial download)
            if target_path.exists():
                file_size = target_path.stat().st_size
                # Use conservative threshold (10KB) - catches obvious failures
                # but allows small models like LoRAs (which can be <1MB)
                min_valid_size = MIN_VALID_FILE_SIZE_KB * KB_TO_BYTES
                if file_size > min_valid_size:
                    print(f"⏭️  Skipping (already exists): {target_path.name} ({file_size / MIB_TO_BYTES:.1f} MB)")
                    return True
                else:
                    print(f"⚠️  Incomplete file detected ({file_size / KB_TO_BYTES:.1f} KB), re-downloading: {target_path.name}")
                    target_path.unlink()  # Delete incomplete file

            return self.download_file(url, target_path)

        # Execute downloads sequentially (more stable for large files)
        for i, url in enumerate(valid_links, 1):
            # Extract filename from URL properly (handle query parameters)
            clean_url = url.split('?')[0]
            filename = Path(urlparse(clean_url).path).name
            print(f"\n📦 [{i}/{len(valid_links)}] Processing: {filename}")

            if download_single_model(url):
                successful += 1
            else:
                failed += 1

            # Short pause between downloads
            time.sleep(1)

        print("\n🎉 Download Statistics:")
        print(f"✅ Successful: {successful}")
        print(f"❌ Failed: {failed}")
        print(f"📊 Success rate: {(successful / (successful + failed)) * 100:.1f}%")

        if failed > 0:
            print(f"\n⚠️  {failed} downloads failed.")
            print("🔄 You can run the script again to retry failed downloads.")
        else:
            print("\n🎊 All downloads completed successfully!")

    def create_download_summary(self):
        """Creates a summary of downloaded models."""
        summary_file = self.base_dir / "downloaded_models_summary.json"

        model_info = {}
        for root, dirs, files in os.walk(self.models_dir):
            for file in files:
                if file.endswith(('.safetensors', '.ckpt', '.pth', '.bin', '.pt')):
                    rel_path = os.path.relpath(root, self.models_dir)
                    category = rel_path if rel_path != '.' else 'root'

                    if category not in model_info:
                        model_info[category] = []

                    file_path = Path(root) / file
                    size_mb = file_path.stat().st_size / MIB_TO_BYTES

                    model_info[category].append({
                        'filename': file,
                        'size_mb': round(size_mb, 2),
                        'path': str(file_path.relative_to(self.base_dir))
                    })

        # Sort by category and filename
        for category in model_info:
            model_info[category].sort(key=lambda x: x['filename'])

        # Get repository URL from environment or use default
        repository_url = os.getenv('REPOSITORY_URL', 'https://github.com/EcomTree/runpod-comfyui-cloud')
        
        with open(summary_file, 'w', encoding='utf-8') as f:
            json.dump({
                'total_files': sum(len(files) for files in model_info.values()),
                'total_size_mb': round(sum(sum(f['size_mb'] for f in files) for files in model_info.values()), 2),
                'download_date': time.time(),
                'repository': repository_url,
                'models': model_info
            }, f, indent=2, ensure_ascii=False)

        print(f"📋 Download summary created: {summary_file}")

        return summary_file

def main():
    """Main function."""
    if len(sys.argv) > 1:
        base_dir = sys.argv[1]
    else:
        base_dir = "/workspace"

    print("🤖 ComfyUI Model Downloader")
    print("=" * 50)
    print(f"📁 Base directory: {base_dir}")

    downloader = ComfyUIModelDownloader(base_dir)

    # Get confirmation (only if running interactively)
    print("\n⚠️  WARNING: This will download many large models!")
    print("💾 Make sure you have enough storage space available.")
    print("🌐 A stable internet connection is recommended.")

    if sys.stdin.isatty():
        try:
            input("\n🚀 Press Enter to start the download...")
        except KeyboardInterrupt:
            print("\n⏹️  Download cancelled.")
            sys.exit(0)

    # Start download
    start_time = time.time()
    downloader.download_all_models()  # Sequential for stability
    download_time = time.time() - start_time

    # Create summary
    print("\n📋 Creating download summary...")
    summary_file = downloader.create_download_summary()

    print("\n⏱️  Download duration:")
    print(f"   {download_time:.1f} seconds ({download_time/60:.1f} minutes)")

    print("\n✅ Download process completed!")
    print(f"📄 See {summary_file} for details.")

if __name__ == "__main__":
    main()
