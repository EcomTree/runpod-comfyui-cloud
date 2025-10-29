#!/usr/bin/env python3
"""
Model Manager CLI Tool for ComfyUI
Manage, download, update, and verify models.

Usage:
    python model_manager.py list                 # Show installed models
    python model_manager.py download <model>     # Download specific model
    python model_manager.py remove <model>       # Remove model
    python model_manager.py update               # Update all models
    python model_manager.py prune                # Remove unused models
    python model_manager.py verify               # Check checksums
"""

import argparse
import json
import sys
from pathlib import Path
from typing import Dict, Optional
import hashlib
from urllib.parse import urlparse


def get_models_dir(base_dir: Path = Path("/workspace")) -> Path:
    """Get the ComfyUI models directory."""
    return base_dir / "ComfyUI" / "models"


def load_models_config(config_file: Optional[Path] = None) -> Dict:
    """Load models configuration from JSON."""
    if not config_file:
        config_file = Path("/workspace/models_download.json")
        if not config_file.exists():
            config_file = Path("models_download.json")
    
    if not config_file.exists():
        print(f"❌ Models config not found: {config_file}")
        return {}
    
    with open(config_file, 'r', encoding='utf-8') as f:
        return json.load(f)


def list_installed_models(base_dir: Path = Path("/workspace")):
    """List all installed models."""
    models_dir = get_models_dir(base_dir)
    
    if not models_dir.exists():
        print("❌ Models directory not found")
        return
    
    print("📦 Installed Models")
    print("=" * 80)
    
    categories = [
        'checkpoints', 'unet', 'vae', 'clip', 't5', 'clip_vision',
        'controlnet', 'loras', 'upscale_models', 'diffusion_models',
        'animatediff_models', 'text_encoders', 'ipadapter'
    ]
    
    total_files = 0
    total_size_mb = 0
    
    for category in categories:
        category_dir = models_dir / category
        if not category_dir.exists():
            continue
        
        files = list(category_dir.glob('*.safetensors')) + \
                list(category_dir.glob('*.ckpt')) + \
                list(category_dir.glob('*.pth')) + \
                list(category_dir.glob('*.bin')) + \
                list(category_dir.glob('*.pt'))
        
        if not files:
            continue
        
        print(f"\n{category.upper()}: ({len(files)} files)")
        print("-" * 80)
        
        for file in sorted(files):
            size_mb = file.stat().st_size / (1024 * 1024)
            total_size_mb += size_mb
            total_files += 1
            print(f"  • {file.name:<60} {size_mb:>10.1f} MB")
    
    print("\n" + "=" * 80)
    print(f"Total: {total_files} files, {total_size_mb:.1f} MB ({total_size_mb/1024:.2f} GB)")


def find_model_by_name(name: str, base_dir: Path = Path("/workspace")) -> Optional[Path]:
    """Find a model file by partial name match."""
    models_dir = get_models_dir(base_dir)
    
    if not models_dir.exists():
        return None
    
    # Search all subdirectories
    for category_dir in models_dir.iterdir():
        if not category_dir.is_dir():
            continue
        
        for file in category_dir.glob('*'):
            if name.lower() in file.name.lower():
                return file
    
    return None


def download_model(model_name: str, base_dir: Path = Path("/workspace")):
    """Download a specific model by name."""
    config = load_models_config()
    
    if not config:
        print("❌ Could not load models configuration")
        return
    
    # Search for model URL
    model_url = None
    model_category = None
    
    for category, items in config.items():
        for item in items:
            if isinstance(item, str):
                url = item
            elif isinstance(item, dict):
                url = item.get('url', '')
            else:
                continue
            
            # Extract filename from URL
            parsed_url = urlparse(url)
            filename = parsed_url.path.split("/")[-1] if parsed_url.path else ""
            
            if model_name.lower() in filename.lower():
                model_url = url
                model_category = category
                break
        
        if model_url:
            break
    
    if not model_url:
        print(f"❌ Model '{model_name}' not found in configuration")
        print("💡 Use 'python model_manager.py search <name>' to find available models")
        return
    
    print(f"📥 Downloading: {model_name}")
    print(f"   Category: {model_category}")
    print(f"   URL: {model_url}")
    
    # Import download functionality
    sys.path.insert(0, str(Path(__file__).parent))
    try:
        import download_models
        
        downloader = download_models.ComfyUIModelDownloader(base_dir=str(base_dir))
        
        # Determine target path
        parsed_url = urlparse(model_url)
        filename = parsed_url.path.split("/")[-1] if parsed_url.path else "model"
        target_path = get_models_dir(base_dir) / model_category / filename
        
        # Download
        success = downloader.download_file_with_resume(model_url, target_path)
        
        if success:
            print(f"✅ Successfully downloaded: {filename}")
        else:
            print(f"❌ Download failed for: {filename}")
            
    finally:
        sys.path.pop(0)


def remove_model(model_name: str, base_dir: Path = Path("/workspace")):
    """Remove a model by name."""
    model_path = find_model_by_name(model_name, base_dir)
    
    if not model_path:
        print(f"❌ Model not found: {model_name}")
        return
    
    size_mb = model_path.stat().st_size / (1024 * 1024)
    
    print(f"⚠️  About to delete:")
    print(f"   File: {model_path}")
    print(f"   Size: {size_mb:.1f} MB")
    
    if sys.stdin.isatty():
        response = input("   Continue? [y/N]: ")
        if response.lower() != 'y':
            print("❌ Cancelled")
            return
    
    try:
        model_path.unlink()
        print(f"✅ Removed: {model_path.name}")
        print(f"💾 Freed: {size_mb:.1f} MB")
    except Exception as e:
        print(f"❌ Error removing model: {e}")


def verify_checksums(base_dir: Path = Path("/workspace")):
    """Verify checksums of all models with known checksums."""
    config = load_models_config()
    
    if not config:
        print("❌ Could not load models configuration")
        return
    
    # Collect models with checksums
    models_with_checksums = []
    for category, items in config.items():
        for item in items:
            if isinstance(item, dict) and 'checksum' in item:
                models_with_checksums.append({
                    'url': item['url'],
                    'checksum': item['checksum'],
                    'category': category
                })
    
    if not models_with_checksums:
        print("ℹ️  No checksums found in models configuration")
        return
    
    print(f"🔐 Verifying {len(models_with_checksums)} model checksums...")
    print("=" * 80)
    
    verified = 0
    failed = 0
    missing = 0
    
    for model_info in models_with_checksums:
        url = model_info['url']
        expected_checksum = model_info['checksum']
        category = model_info['category']
        
        # Get filename from URL
        parsed_url = urlparse(url)
        filename = parsed_url.path.split("/")[-1] if parsed_url.path else ""
        
        # Find file
        model_path = get_models_dir(base_dir) / category / filename
        
        if not model_path.exists():
            print(f"⏭️  Skipped (not downloaded): {filename}")
            missing += 1
            continue
        
        # Calculate checksum
        print(f"🔍 Checking: {filename}... ", end='', flush=True)
        
        sha256_hash = hashlib.sha256()
        with open(model_path, "rb") as f:
            for byte_block in iter(lambda: f.read(8192), b""):
                sha256_hash.update(byte_block)
        
        calculated = sha256_hash.hexdigest()
        
        if calculated.lower() == expected_checksum.lower():
            print("✅ OK")
            verified += 1
        else:
            print("❌ FAILED")
            print(f"   Expected: {expected_checksum}")
            print(f"   Got:      {calculated}")
            failed += 1
    
    print("\n" + "=" * 80)
    print(f"✅ Verified: {verified}")
    print(f"⏭️  Missing: {missing}")
    print(f"❌ Failed: {failed}")


def prune_unused_models(base_dir: Path = Path("/workspace"), dry_run: bool = True):
    """Remove models not in the configuration."""
    config = load_models_config()
    
    if not config:
        print("❌ Could not load models configuration")
        return
    
    # Build set of known model filenames
    known_models = set()
    for category, items in config.items():
        for item in items:
            if isinstance(item, str):
                url = item
            elif isinstance(item, dict):
                url = item.get('url', '')
            else:
                continue
            
            parsed_url = urlparse(url)
            filename = parsed_url.path.split("/")[-1] if parsed_url.path else ""
            if filename:
                known_models.add(filename.lower())
    
    # Scan for unknown models
    models_dir = get_models_dir(base_dir)
    unknown_models = []
    
    for category_dir in models_dir.iterdir():
        if not category_dir.is_dir():
            continue
        
        for file in category_dir.glob('*'):
            if file.is_file() and file.name.lower() not in known_models:
                unknown_models.append(file)
    
    if not unknown_models:
        print("✅ No unused models found")
        return
    
    print(f"⚠️  Found {len(unknown_models)} unused models:")
    print("=" * 80)
    
    total_size = 0
    for model in unknown_models:
        size_mb = model.stat().st_size / (1024 * 1024)
        total_size += size_mb
        print(f"  • {model.name:<60} {size_mb:>10.1f} MB")
    
    print("=" * 80)
    print(f"Total: {len(unknown_models)} files, {total_size:.1f} MB ({total_size/1024:.2f} GB)")
    
    if dry_run:
        print("\n💡 This was a dry run. Use '--no-dry-run' to actually remove files.")
    else:
        if sys.stdin.isatty():
            response = input("\n⚠️  Remove all unused models? [y/N]: ")
            if response.lower() != 'y':
                print("❌ Cancelled")
                return
        
        removed = 0
        for model in unknown_models:
            try:
                model.unlink()
                removed += 1
            except Exception as e:
                print(f"❌ Error removing {model.name}: {e}")
        
        print(f"\n✅ Removed {removed} files, freed {total_size:.1f} MB")


def search_models(query: str):
    """Search for models in configuration."""
    config = load_models_config()
    
    if not config:
        print("❌ Could not load models configuration")
        return
    
    matches = []
    
    for category, items in config.items():
        for item in items:
            if isinstance(item, str):
                url = item
            elif isinstance(item, dict):
                url = item.get('url', '')
            else:
                continue
            
            parsed_url = urlparse(url)
            filename = parsed_url.path.split("/")[-1] if parsed_url.path else ""
            
            if query.lower() in filename.lower():
                matches.append((category, filename, url))
    
    if not matches:
        print(f"❌ No models found matching '{query}'")
        return
    
    print(f"🔍 Found {len(matches)} models matching '{query}':")
    print("=" * 80)
    
    for category, filename, url in matches:
        print(f"\n{filename}")
        print(f"  Category: {category}")
        print(f"  URL: {url}")


def update_models(base_dir: Path = Path("/workspace")):
    """Update all installed models."""
    print("🔄 Updating all models...")
    print("⚠️  This will re-download all installed models")
    
    if sys.stdin.isatty():
        response = input("Continue? [y/N]: ")
        if response.lower() != 'y':
            print("❌ Cancelled")
            return
    
    # Import download functionality
    sys.path.insert(0, str(Path(__file__).parent))
    try:
        import download_models
        
        downloader = download_models.ComfyUIModelDownloader(base_dir=str(base_dir))
        
        # Load models with checksums
        models_with_checksums = download_models.load_models_with_checksums()
        
        if not models_with_checksums:
            print("❌ No models to update")
            return
        
        # Filter to only installed models
        models_dir = get_models_dir(base_dir)
        installed_models = []
        
        for model_info in models_with_checksums:
            url = model_info.get('url')
            parsed_url = urlparse(url)
            filename = parsed_url.path.split("/")[-1] if parsed_url.path else ""
            
            # Check if model exists
            found = False
            for category_dir in models_dir.iterdir():
                if (category_dir / filename).exists():
                    found = True
                    break
            
            if found:
                installed_models.append(model_info)
        
        if not installed_models:
            print("✅ No installed models to update")
            return
        
        print(f"📥 Updating {len(installed_models)} models...")
        downloader.download_all_models_parallel(installed_models)
        
    finally:
        sys.path.pop(0)


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Model Manager for ComfyUI",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Commands:
  list                  List all installed models
  download <model>      Download a specific model
  remove <model>        Remove a model
  verify                Verify model checksums
  prune                 Remove unused models (dry run)
  prune --no-dry-run    Remove unused models (actual)
  search <query>        Search for models
  update                Update all installed models

Examples:
  # List installed models
  python model_manager.py list
  
  # Search for a model
  python model_manager.py search "flux"
  
  # Download a model
  python model_manager.py download "flux1-dev"
  
  # Verify checksums
  python model_manager.py verify
  
  # Remove unused models (dry run)
  python model_manager.py prune
  
  # Actually remove unused models
  python model_manager.py prune --no-dry-run
        """
    )
    
    parser.add_argument(
        'command',
        choices=['list', 'download', 'remove', 'verify', 'prune', 'search', 'update'],
        help='Command to execute'
    )
    
    parser.add_argument(
        'argument',
        nargs='?',
        help='Argument for command (model name or search query)'
    )
    
    parser.add_argument(
        '--base-dir',
        type=Path,
        default=Path('/workspace'),
        help='Base directory (default: /workspace)'
    )
    
    parser.add_argument(
        '--no-dry-run',
        action='store_true',
        help='Actually perform actions (for prune command)'
    )
    
    args = parser.parse_args()
    
    # Execute command
    if args.command == 'list':
        list_installed_models(args.base_dir)
    
    elif args.command == 'download':
        if not args.argument:
            print("❌ Please specify model name")
            print("💡 Use 'search' command to find models")
            sys.exit(1)
        download_model(args.argument, args.base_dir)
    
    elif args.command == 'remove':
        if not args.argument:
            print("❌ Please specify model name")
            sys.exit(1)
        remove_model(args.argument, args.base_dir)
    
    elif args.command == 'verify':
        verify_checksums(args.base_dir)
    
    elif args.command == 'prune':
        prune_unused_models(args.base_dir, dry_run=not args.no_dry_run)
    
    elif args.command == 'search':
        if not args.argument:
            print("❌ Please specify search query")
            sys.exit(1)
        search_models(args.argument)
    
    elif args.command == 'update':
        update_models(args.base_dir)


if __name__ == '__main__':
    main()
