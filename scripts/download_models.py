#!/usr/bin/env python3
"""
ComfyUI Model Downloader Script - Enhanced Version
Downloads all validated ComfyUI models to the specified directory.

Features:
- Parallel downloads with ThreadPoolExecutor
- SHA256 checksum verification
- Resume capability with HTTP Range headers
- Progress bars with tqdm
- Exponential backoff retry logic
"""

import os
import json
import requests
import time
import sys
import hashlib
from pathlib import Path
from urllib.parse import urlparse
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Optional, Dict, List, Tuple
from tqdm import tqdm

# Constants
PROGRESS_REPORT_INTERVAL_MB = 10  # Report progress every 10 MB
RETRY_BASE_DELAY_SECONDS = 5  # Base delay for exponential backoff
MIB_TO_BYTES = 1024 * 1024  # Bytes in one mebibyte (binary megabyte)
KB_TO_BYTES = 1024  # Bytes in one kilobyte
MIN_VALID_FILE_SIZE_KB = (
    10  # Minimum file size in KB to consider a download complete (10KB for small LoRAs)
)
MAX_WORKERS = int(os.getenv("DOWNLOAD_MAX_WORKERS", "4"))  # Parallel download workers

# Model classification mapping: ordered from most specific to most general
MODEL_CLASSIFICATION_MAPPING = [
    ("unet", ["flux", "sd3", "auraflow", "hunyuan", "kolors", "lumina"]),
    ("vae", ["vae", "kl-f8-anime"]),
    ("clip_vision", ["clip_vision", "image_encoder"]),
    ("clip", ["clip", "open_clip"]),
    ("t5", ["t5", "umt5"]),
    ("controlnet", ["controlnet", "control_", "canny", "depth", "openpose", "scribble"]),
    ("loras", ["lora", ".lora"]),
    ("upscale_models", ["esrgan", "realesrgan", "swinir", "4x", "2x", "upscale"]),
    ("animatediff_models", ["animatediff", "mm_", "motion"]),
    ("ipadapter", ["ip-adapter", "ip_adapter"]),
    ("text_encoders", ["text_encoder"]),
    ("checkpoints", [".ckpt", ".safetensors"]),
]


def setup_hf_session():
    """Set up a requests.Session with Hugging Face token if available."""
    session = requests.Session()
    session.headers.update({"User-Agent": "ComfyUI-Model-Downloader/2.0"})
    hf_token = os.getenv("HF_TOKEN")
    if hf_token:
        session.headers["Authorization"] = f"Bearer {hf_token.strip()}"
    else:
        print("⚠️  No HF_TOKEN set. Protected Hugging Face downloads may fail.")
    return session


SESSION = setup_hf_session()


def verify_checksum(file_path: Path, expected_sha256: str) -> bool:
    """
    Verify SHA256 checksum of a file.
    
    Args:
        file_path: Path to the file
        expected_sha256: Expected SHA256 hash
        
    Returns:
        True if checksum matches, False otherwise
    """
    if not expected_sha256:
        return True  # Skip verification if no checksum provided
    
    print(f"🔐 Verifying checksum for {file_path.name}...")
    sha256_hash = hashlib.sha256()
    
    try:
        with open(file_path, "rb") as f:
            # Read in chunks to handle large files
            for byte_block in iter(lambda: f.read(8192), b""):
                sha256_hash.update(byte_block)
        
        calculated_hash = sha256_hash.hexdigest()
        
        if calculated_hash.lower() == expected_sha256.lower():
            print(f"✅ Checksum verified for {file_path.name}")
            return True
        else:
            print(f"❌ Checksum mismatch for {file_path.name}")
            print(f"   Expected: {expected_sha256}")
            print(f"   Got:      {calculated_hash}")
            return False
    except Exception as e:
        print(f"❌ Error verifying checksum: {e}")
        return False


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
            "ipadapter",
        ]

        for dir_name in directories:
            (self.models_dir / dir_name).mkdir(parents=True, exist_ok=True)

        print(f"📁 Directory structure created in: {self.models_dir}")

    def load_verified_links(self):
        """Loads the verified links from the JSON file."""
        print(f"🔍 DEBUG: Looking for verification file: {self.verification_file}")

        # Check if verification file exists
        if not os.path.exists(self.verification_file):
            print(f"❌ Verification file {self.verification_file} not found!")

            # Try alternative locations
            alternative_paths = [
                "/workspace/link_verification_results.json",
                "link_verification_results.json",
                "./link_verification_results.json",
            ]

            print("🔍 DEBUG: Trying alternative paths...")
            for alt_path in alternative_paths:
                print(f"   Checking: {alt_path}")
                if os.path.exists(alt_path):
                    print(f"✅ Found verification file at: {alt_path}")
                    self.verification_file = alt_path
                    break
            else:
                print("❌ No verification file found in any location!")
                print(
                    "🔍 Searching for JSON files in likely /workspace subdirectories (this may take a moment)..."
                )
                try:
                    # Limit search to specific subdirectories and reduce maxdepth to avoid issues in large filesystems
                    search_dirs = [
                        "/workspace",
                        "/workspace/models",
                        "/workspace/data",
                        "/workspace/ComfyUI",
                    ]
                    max_list = int(os.getenv("FIND_MAX_RESULTS", "100"))
                    found_files = []

                    # Iterate through each search directory
                    for d in search_dirs:
                        if not os.path.isdir(d):
                            continue
                        try:
                            # Use os.walk to traverse up to depth 2
                            for root, dirs, files in os.walk(d):
                                # Calculate depth relative to the search directory
                                rel_path = os.path.relpath(root, d)
                                depth = 0 if rel_path == "." else rel_path.count(os.sep) + 1
                                if depth > 2:
                                    # Prevent descending further
                                    dirs[:] = []
                                    continue
                                for file in files:
                                    if file.endswith(".json"):
                                        found_files.append(os.path.join(root, file))
                        except (OSError, PermissionError) as e:
                            print(f"⚠️  Error searching in {d} ({type(e).__name__}): {e}")

                    if found_files:
                        for f in found_files[:max_list]:
                            print(f"  {f}")
                        if len(found_files) > max_list:
                            print(f"  ... (+{len(found_files)-max_list} more)")
                    else:
                        print("No JSON files found in searched directories")
                except (OSError, PermissionError) as e:
                    print(f"⚠️  Error searching for JSON files ({type(e).__name__}): {e}")

                print("\n🔧 SOLUTION: Run link verification first:")
                print("   python3 scripts/verify_links.py")
                sys.exit(1)

        try:
            print(f"📖 Loading verification file: {self.verification_file}")
            with open(self.verification_file, "r", encoding="utf-8") as f:
                data = json.load(f)
                valid_links = data.get("valid_links", [])
                print(f"✅ Loaded {len(valid_links)} valid links")

                if not valid_links:
                    print("⚠️  Warning: No valid links found in verification file!")
                    print("🔍 DEBUG: Verification file contents:")
                    pretty = json.dumps(data, indent=2)
                    print(pretty[:500] + "..." if len(pretty) > 500 else pretty)

                return valid_links

        except json.JSONDecodeError as e:
            print(f"❌ Invalid JSON in verification file: {e}")
            print("🔧 SOLUTION: Delete the corrupted file and run verification again:")
            print(f"   rm {self.verification_file}")
            print("   python3 scripts/verify_links.py")
            sys.exit(1)
        except (OSError, IOError) as e:
            print(f"❌ Error loading verification file ({type(e).__name__}): {e}")
            sys.exit(1)

    def determine_target_directory(self, url):
        """Determines the target directory based on URL and filename."""
        parsed_url = urlparse(url)
        filename = parsed_url.path.split("/")[-1] if parsed_url.path else "unknown"
        filename = filename.lower()

        # Use global classification mapping
        for directory, patterns in MODEL_CLASSIFICATION_MAPPING:
            # Check if filename contains patterns or has specific extensions
            for pattern in patterns:
                if pattern.startswith("."):
                    if filename.endswith(pattern):
                        return directory
                elif pattern in filename:
                    return directory

        # Default fallback
        return "diffusion_models"

    def download_file_with_resume(
        self, 
        url: str, 
        target_path: Path, 
        expected_checksum: Optional[str] = None,
        retry_count: int = 3
    ) -> bool:
        """
        Downloads a single file with resume capability and retry logic.
        
        Args:
            url: URL to download from
            target_path: Path to save the file
            expected_checksum: Expected SHA256 checksum (optional)
            retry_count: Number of retry attempts
            
        Returns:
            True if download successful, False otherwise
        """
        target_path = Path(target_path)
        target_path.parent.mkdir(parents=True, exist_ok=True)

        # Clean filename from URL (remove query parameters)
        clean_url = url.split("?")[0]
        parsed_url = urlparse(clean_url)
        filename = parsed_url.path.split("/")[-1] if parsed_url.path else "unknown"

        for attempt in range(retry_count):
            try:
                # Check if file exists and get current size
                existing_size = 0
                if target_path.exists():
                    existing_size = target_path.stat().st_size
                    
                    # Try HEAD request to get total size
                    try:
                        head_response = self.session.head(url, timeout=10, allow_redirects=True)
                        total_size = int(head_response.headers.get("content-length", 0))
                        
                        # If file is complete, verify checksum if provided
                        if existing_size == total_size and total_size > 0:
                            if expected_checksum:
                                if verify_checksum(target_path, expected_checksum):
                                    print(f"✅ File already complete: {filename}")
                                    return True
                                else:
                                    print(f"⚠️  Checksum mismatch, re-downloading: {filename}")
                                    target_path.unlink()
                                    existing_size = 0
                            else:
                                print(f"✅ File already complete: {filename}")
                                return True
                    except Exception as e:
                        print(f"⚠️  Could not verify existing file size: {e}")

                # Set up headers for resume capability
                headers = {}
                mode = "wb"
                if existing_size > MIN_VALID_FILE_SIZE_KB * KB_TO_BYTES:
                    headers["Range"] = f"bytes={existing_size}-"
                    mode = "ab"
                    print(f"▶️  Resuming download: {filename} from {existing_size / MIB_TO_BYTES:.1f} MB")
                else:
                    print(f"⬇️  Downloading: {filename} (Attempt {attempt + 1}/{retry_count})")

                # Stream download with progress bar
                with self.session.get(url, stream=True, timeout=30, headers=headers) as response:
                    response.raise_for_status()
                    
                    # Handle HTTP 416 Range Not Satisfiable
                    if response.status_code == 416:
                        print(f"⚠️  Resume not supported, restarting download: {filename}")
                        if target_path.exists():
                            target_path.unlink()
                        existing_size = 0
                        headers = {}
                        mode = "wb"
                        # Retry without Range header
                        response = self.session.get(url, stream=True, timeout=30)
                        response.raise_for_status()

                    # Get total size
                    if response.status_code == 206:  # Partial content
                        content_range = response.headers.get("content-range", "")
                        if content_range:
                            total_size = int(content_range.split("/")[-1])
                        else:
                            total_size = existing_size + int(response.headers.get("content-length", 0))
                    else:
                        total_size = int(response.headers.get("content-length", 0))

                    # Create progress bar
                    with tqdm(
                        total=total_size,
                        initial=existing_size,
                        unit="B",
                        unit_scale=True,
                        unit_divisor=1024,
                        desc=filename[:40],
                        disable=not sys.stdout.isatty()  # Disable in non-interactive mode
                    ) as pbar:
                        with open(target_path, mode) as f:
                            for chunk in response.iter_content(chunk_size=8192):
                                if chunk:
                                    f.write(chunk)
                                    pbar.update(len(chunk))

                # Verify checksum if provided
                if expected_checksum:
                    if not verify_checksum(target_path, expected_checksum):
                        print(f"❌ Checksum verification failed for: {filename}")
                        if attempt < retry_count - 1:
                            print(f"🔄 Retrying download...")
                            target_path.unlink()
                            continue
                        return False

                print(f"✅ Successfully downloaded: {filename}")
                return True

            except requests.exceptions.RequestException as e:
                print(f"❌ Download error (Attempt {attempt + 1}): {e}")
                if attempt < retry_count - 1:
                    # Exponential backoff with cap at 60 seconds
                    wait_time = min((2 ** (attempt + 1)) * RETRY_BASE_DELAY_SECONDS, 60)
                    print(f"⏳ Waiting {wait_time} seconds before retry...")
                    time.sleep(wait_time)
                else:
                    print(f"❌ Maximum retries reached for: {url}")
                    return False

            except Exception as e:
                print(f"❌ Unexpected error: {e}")
                return False

        return False

    def download_all_models_parallel(self, models_with_checksums: List[Dict]):
        """
        Downloads all models using parallel workers.
        
        Args:
            models_with_checksums: List of dicts with 'url' and optional 'checksum' keys
        """
        if not models_with_checksums:
            print("❌ No models to download!")
            return

        print(f"🚀 Starting parallel download of {len(models_with_checksums)} models...")
        print(f"👷 Using {MAX_WORKERS} parallel workers")
        print(f"📁 Target directory: {self.models_dir}")

        successful = 0
        failed = 0
        skipped = 0

        def download_single_model(model_info: Dict) -> Tuple[str, bool]:
            """Download a single model and return (url, success)"""
            url = model_info.get("url")
            checksum = model_info.get("checksum")
            
            # Extract clean filename from URL
            clean_url = url.split("?")[0]
            parsed_url = urlparse(clean_url)
            filename = parsed_url.path.split("/")[-1] if parsed_url.path else "unknown"

            target_dir = self.determine_target_directory(url)
            target_path = self.models_dir / target_dir / filename

            # Check if file exists and has reasonable size
            if target_path.exists():
                file_size = target_path.stat().st_size
                min_valid_size = MIN_VALID_FILE_SIZE_KB * KB_TO_BYTES
                if file_size > min_valid_size:
                    # If checksum provided, verify it
                    if checksum:
                        if verify_checksum(target_path, checksum):
                            print(f"⏭️  Skipping (already exists with valid checksum): {filename}")
                            return (url, True, True)  # URL, success, skipped
                        else:
                            print(f"⚠️  Checksum mismatch, re-downloading: {filename}")
                            target_path.unlink()
                    else:
                        print(f"⏭️  Skipping (already exists): {filename} ({file_size / MIB_TO_BYTES:.1f} MB)")
                        return (url, True, True)  # URL, success, skipped
                else:
                    print(f"⚠️  Incomplete file detected ({file_size / KB_TO_BYTES:.1f} KB), re-downloading: {filename}")
                    target_path.unlink()

            success = self.download_file_with_resume(url, target_path, checksum)
            return (url, success, False)  # URL, success, not skipped

        # Use ThreadPoolExecutor for parallel downloads
        with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
            # Submit all download tasks
            future_to_model = {
                executor.submit(download_single_model, model): model 
                for model in models_with_checksums
            }

            # Process completed downloads
            for future in as_completed(future_to_model):
                try:
                    url, success, was_skipped = future.result()
                    if was_skipped:
                        skipped += 1
                    elif success:
                        successful += 1
                    else:
                        failed += 1
                except Exception as e:
                    print(f"❌ Unexpected error in download task: {e}")
                    failed += 1

        print("\n🎉 Download Statistics:")
        print(f"✅ Successful: {successful}")
        print(f"⏭️  Skipped: {skipped}")
        print(f"❌ Failed: {failed}")
        total = successful + failed
        if total > 0:
            print(f"📊 Success rate: {(successful / total) * 100:.1f}%")

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
                if file.endswith((".safetensors", ".ckpt", ".pth", ".bin", ".pt")):
                    rel_path = os.path.relpath(root, self.models_dir)
                    category = rel_path if rel_path != "." else "root"

                    if category not in model_info:
                        model_info[category] = []

                    file_path = Path(root) / file
                    size_mb = file_path.stat().st_size / MIB_TO_BYTES

                    model_info[category].append(
                        {
                            "filename": file,
                            "size_mb": round(size_mb, 2),
                            "path": str(file_path.relative_to(self.base_dir)),
                        }
                    )

        # Sort by category and filename
        for category in model_info:
            model_info[category].sort(key=lambda x: x["filename"])

        # Get repository URL from environment or use default
        repository_url = os.getenv(
            "REPOSITORY_URL", "https://github.com/EcomTree/runpod-comfyui-cloud"
        )

        with open(summary_file, "w", encoding="utf-8") as f:
            json.dump(
                {
                    "total_files": sum(len(files) for files in model_info.values()),
                    "total_size_mb": round(
                        sum(sum(f["size_mb"] for f in files) for files in model_info.values()), 2
                    ),
                    "download_date": time.time(),
                    "repository": repository_url,
                    "models": model_info,
                },
                f,
                indent=2,
                ensure_ascii=False,
            )

        print(f"📋 Download summary created: {summary_file}")

        return summary_file


def load_models_with_checksums() -> List[Dict]:
    """
    Load models from models_download.json with checksum support.
    
    Returns:
        List of dicts with 'url' and optional 'checksum' keys
    """
    models_file = Path("/workspace/models_download.json")
    
    if not models_file.exists():
        # Try alternative location
        models_file = Path("models_download.json")
    
    if not models_file.exists():
        print("❌ models_download.json not found!")
        return []
    
    try:
        with open(models_file, "r", encoding="utf-8") as f:
            data = json.load(f)
        
        models_list = []
        for category, items in data.items():
            if isinstance(items, list):
                for item in items:
                    if isinstance(item, str):
                        # Legacy format: just URL string
                        models_list.append({"url": item})
                    elif isinstance(item, dict):
                        # New format: dict with url and optional checksum
                        models_list.append(item)
        
        print(f"✅ Loaded {len(models_list)} models from models_download.json")
        return models_list
        
    except Exception as e:
        print(f"❌ Error loading models_download.json: {e}")
        return []


def main():
    """Main function."""
    if len(sys.argv) > 1:
        base_dir = sys.argv[1]
    else:
        base_dir = "/workspace"

    print("🤖 ComfyUI Model Downloader v2.0 (Enhanced)")
    print("=" * 50)
    print(f"📁 Base directory: {base_dir}")
    print(f"👷 Max workers: {MAX_WORKERS}")

    downloader = ComfyUIModelDownloader(base_dir)

    # Get confirmation (only if running interactively)
    print("\n⚠️  WARNING: This will download many large models!")
    print("💾 Make sure you have enough storage space available.")
    print("🌐 A stable internet connection is recommended.")
    print("⚡ Using parallel downloads for better performance.")

    if sys.stdin.isatty():
        try:
            input("\n🚀 Press Enter to start the download...")
        except KeyboardInterrupt:
            print("\n⏹️  Download cancelled.")
            sys.exit(0)

    # Load models with checksums from JSON
    models_with_checksums = load_models_with_checksums()
    
    if not models_with_checksums:
        # Fallback to old method using verified links
        print("⚠️  Falling back to link verification method...")
        valid_links = downloader.load_verified_links()
        models_with_checksums = [{"url": url} for url in valid_links]

    # Start parallel download
    start_time = time.time()
    downloader.download_all_models_parallel(models_with_checksums)
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
