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

        # Run the classification test in a subprocess to avoid dependency issues
        import subprocess
        import json
        import tempfile
        
        # Write test script to temporary file to avoid quoting issues
        test_script = '''
import sys
import json
import os

# Ensure we can import from scripts directory
sys.path.insert(0, os.path.join(os.getcwd(), "scripts"))

try:
    from download_models import ComfyUIModelDownloader
    
    test_cases = [
        ("https://example.com/flux1-dev.safetensors", "unet"),
        ("https://example.com/sd_xl_base_1.0.safetensors", "checkpoints"),
        ("https://example.com/vae-ft-mse.safetensors", "vae"),
        ("https://example.com/clip_l.safetensors", "clip"),
        ("https://example.com/t5xxl_fp16.safetensors", "t5"),
        ("https://example.com/control_v11p_sd15_canny.pth", "controlnet"),
    ]
    
    # Use a temporary directory that definitely exists
    import tempfile
    temp_dir = tempfile.mkdtemp()
    
    try:
        downloader = ComfyUIModelDownloader(base_dir=temp_dir)
        correct = 0
        results = []
        
        for url, expected in test_cases:
            result = downloader.determine_target_directory(url)
            results.append({"url": url, "expected": expected, "result": result})
            if result == expected:
                correct += 1
        
        success_rate = (correct / len(test_cases)) * 100
        print(json.dumps({"results": results, "success_rate": success_rate}))
        sys.exit(0 if success_rate >= 80 else 1)
    finally:
        # Cleanup temp directory
        import shutil
        shutil.rmtree(temp_dir, ignore_errors=True)
        
except Exception as e:
    print(json.dumps({"error": str(e)}))
    sys.exit(2)
'''
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.py', delete=False) as f:
            f.write(test_script)
            script_path = f.name
        
        try:
            result = subprocess.run(
                [sys.executable, script_path],
                capture_output=True,
                text=True,
                timeout=30
            )
            
            if result.returncode == 2:
                try:
                    error_info = json.loads(result.stdout)
                    print(f"❌ Error during classification: {error_info.get('error', 'Unknown error')}")
                except Exception:
                    print(f"❌ Error during classification: {result.stdout.strip()}")
                    if result.stderr:
                        print(f"   stderr: {result.stderr.strip()}")
                return False
            elif result.returncode == 1:
                try:
                    from urllib.parse import urlparse
                    output = json.loads(result.stdout)
                    for entry in output.get('results', []):
                        # Extract filename from URL using urlparse
                        parsed_url = urlparse(entry['url'])
                        url_name = parsed_url.path.split('/')[-1] if parsed_url.path else 'unknown'
                        if entry['result'] == entry['expected']:
                            print(f"✅ {url_name} -> {entry['result']}")
                        else:
                            print(f"❌ {url_name} -> {entry['result']} (expected: {entry['expected']})")
                    print(f"📊 Classification accuracy: {output.get('success_rate', 0):.1f}%")
                except Exception:
                    print(f"❌ Error parsing classification results: {result.stdout.strip()}")
                return False
            elif result.returncode == 0:
                try:
                    from urllib.parse import urlparse
                    output = json.loads(result.stdout)
                    for entry in output.get('results', []):
                        # Extract filename from URL using urlparse
                        parsed_url = urlparse(entry['url'])
                        url_name = parsed_url.path.split('/')[-1] if parsed_url.path else 'unknown'
                        print(f"✅ {url_name} -> {entry['result']}")
                    print(f"📊 Classification accuracy: {output.get('success_rate', 0):.1f}%")
                    return True  # Return True on success
                except Exception:
                    print(f"❌ Error parsing classification results: {result.stdout.strip()}")
                    return False
            else:
                print(f"❌ Unknown error during classification: {result.stdout.strip()}")
                return False
        finally:
            # Clean up temp file
            import os
            try:
                os.unlink(script_path)
            except Exception:
                pass
                
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
