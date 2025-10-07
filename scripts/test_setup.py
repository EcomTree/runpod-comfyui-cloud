#!/usr/bin/env python3
"""
Test script for the ComfyUI model download setup.
Performs basic validation without performing real downloads.
"""

import os
import sys
import json
from pathlib import Path

def test_link_verification():
    """Tests the link verification script."""
    print("🔍 Testing link verification...")

    try:
        # Simulate the presence of a verified file
        verification_file = Path("link_verification_results.json")
        if not verification_file.exists():
            print("❌ Verification file missing - run verify_links.py first")
            return False

        # Load and validate structure
        with open(verification_file, 'r') as f:
            data = json.load(f)

        required_keys = ['valid_links', 'invalid_links', 'stats']
        for key in required_keys:
            if key not in data:
                print(f"❌ Missing key in verification file: {key}")
                return False

        valid_count = len(data['valid_links'])
        print(f"✅ {valid_count} validated links found")
        return True

    except Exception as e:
        print(f"❌ Error during link verification: {e}")
        return False

def test_directory_structure():
    """Tests directory structure creation."""
    print("📁 Testing directory structure...")

    try:
        # Simulate ComfyUI model directories
        base_dir = Path("/workspace")
        models_dir = base_dir / "ComfyUI" / "models"

        required_dirs = [
            "checkpoints", "unet", "vae", "clip", "t5",
            "clip_vision", "controlnet", "loras", "upscale_models",
            "diffusion_models", "animatediff_models", "text_encoders", "ipadapter"
        ]

        missing_dirs = []
        for dir_name in required_dirs:
            if not (models_dir / dir_name).exists():
                missing_dirs.append(dir_name)

        if missing_dirs:
            print(f"❌ Missing directories: {', '.join(missing_dirs)}")
            return False

        print(f"✅ All {len(required_dirs)} directories exist")
        return True

    except Exception as e:
        print(f"❌ Error checking directory structure: {e}")
        return False

def test_download_script_import():
    """Tests whether the download script can be imported."""
    print("🐍 Testing download script import...")

    try:
        # Ensure the script is syntactically correct
        import subprocess
        result = subprocess.run([
            sys.executable, "-m", "py_compile", "scripts/download_models.py"
        ], capture_output=True, text=True)

        if result.returncode != 0:
            print(f"❌ Syntax error in download script: {result.stderr}")
            return False

        print("✅ Download script is syntactically correct")
        return True

    except Exception as e:
        print(f"❌ Error during import test: {e}")
        return False

def test_model_classification():
    """Tests the model classification logic."""
    print("🏷️  Testing model classification...")

    try:
        # Test several example URLs
        test_cases = [
            ("https://example.com/flux1-dev.safetensors", "unet"),
            ("https://example.com/sd_xl_base_1.0.safetensors", "checkpoints"),
            ("https://example.com/vae-ft-mse.safetensors", "vae"),
            ("https://example.com/clip_l.safetensors", "clip"),
            ("https://example.com/t5xxl_fp16.safetensors", "t5"),
            ("https://example.com/control_v11p_sd15_canny.pth", "controlnet"),
        ]

        # Add scripts to path before import
        sys.path.append("scripts")

        # Import the function (without real dependencies)
        from download_models import ComfyUIModelDownloader

        downloader = ComfyUIModelDownloader()

        correct = 0
        for url, expected in test_cases:
            result = downloader.determine_target_directory(url)
            if result == expected:
                correct += 1
                print(f"✅ {Path(url).name} -> {result}")
            else:
                print(f"❌ {Path(url).name} -> {result} (expected: {expected})")

        success_rate = (correct / len(test_cases)) * 100
        print(f"📊 Classification accuracy: {success_rate:.1f}%")

        return success_rate >= 80  # At least 80% correct

    except Exception as e:
        print(f"❌ Error during classification: {e}")
        return False

def main():
    """Main entry point."""
    print("🧪 ComfyUI Model Download Setup Test")
    print("=" * 50)

    tests = [
        ("Link Verification", test_link_verification),
        ("Directory Structure", test_directory_structure),
        ("Download Script Import", test_download_script_import),
        ("Model Classification", test_model_classification),
    ]

    results = []
    for test_name, test_func in tests:
        print(f"\n{'='*50}")
        print(f"Test: {test_name}")
        print('='*50)

        success = test_func()
        results.append((test_name, success))

    # Summary
    print(f"\n{'='*60}")
    print("📋 TEST SUMMARY")
    print('='*60)

    passed = 0
    for test_name, success in results:
        status = "✅ PASSED" if success else "❌ FAILED"
        print(f"{test_name:25} {status}")
        if success:
            passed += 1

    success_rate = (passed / len(results)) * 100
    print(f"\n📊 Overall success rate: {success_rate:.1f}%")

    if success_rate == 100:
        print("🎉 All tests passed! Setup is ready.")
        return 0
    else:
        print(f"⚠️  {len(results) - passed} tests failed. Please review the configuration.")
        return 1

if __name__ == "__main__":
    sys.exit(main())
