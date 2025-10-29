#!/usr/bin/env python3
"""
Link Verification Script for ComfyUI Models Library
Verifies all Hugging Face links for accessibility and correctness.
"""

import json
import os
import re
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from urllib.parse import urlsplit, urlunsplit

import requests


def validate_hf_token():
    """Validates and returns HF_TOKEN, or None if invalid."""
    token = os.getenv("HF_TOKEN")

    if not token:
        return None

    token = token.strip()

    # Check if token becomes empty after stripping
    if not token:
        print("⚠️  Warning: HF_TOKEN is empty or contains only whitespace.")
        print("⚠️  Protected Hugging Face links may fail.")
        return None

    # Validate token format
    if not token.startswith("hf_") or len(token) < 10:
        print(
            "⚠️  Warning: HF_TOKEN format appears invalid. Valid tokens start with 'hf_' and have sufficient length."
        )
        print("⚠️  Protected Hugging Face links may fail.")
        return None

    return token


HF_TOKEN = validate_hf_token()

SESSION = requests.Session()
SESSION.headers.update({"User-Agent": "ComfyUI-Model-Link-Checker/1.0"})

if HF_TOKEN:
    SESSION.headers["Authorization"] = f"Bearer {HF_TOKEN}"
else:
    print("ℹ️  No HF_TOKEN set. Protected Hugging Face links may fail.")


def extract_huggingface_links(content):
    """Extracts all Hugging Face links from the markdown content."""
    # Regex for Hugging Face links (https://huggingface.co/...)
    hf_pattern = r"https://huggingface\.co/[^\s\)]+"
    links = re.findall(hf_pattern, content)

    # Filter only actual download links (safetensors, ckpt, etc.)
    download_links = []
    for link in links:
        if any(ext in link.lower() for ext in [".safetensors", ".ckpt", ".pth", ".bin", ".pt"]):
            download_links.append(link)

    return download_links


def check_link(link, timeout=10):
    """Checks a single link."""
    try:
        # Remove query parameters for a clean URL while preserving path normalization
        parsed = urlsplit(link)
        clean_link = urlunsplit((parsed.scheme, parsed.netloc, parsed.path, "", ""))

        # HEAD request for faster verification
        response = SESSION.head(clean_link, timeout=timeout, allow_redirects=True)

        # For Hugging Face: 200, 302, 307 are OK
        if response.status_code in [200, 302, 307]:
            return {
                "link": link,
                "status": "valid",
                "status_code": response.status_code,
                "final_url": response.url,
                "error": None,
            }
        else:
            return {
                "link": link,
                "status": "invalid",
                "status_code": response.status_code,
                "final_url": response.url,
                "error": f"HTTP {response.status_code}",
            }

    except requests.exceptions.Timeout:
        return {
            "link": link,
            "status": "timeout",
            "status_code": None,
            "final_url": None,
            "error": f"Timeout after {timeout}s",
        }
    except requests.exceptions.ConnectionError:
        return {
            "link": link,
            "status": "connection_error",
            "status_code": None,
            "final_url": None,
            "error": "Connection failed",
        }
    except Exception as e:
        return {
            "link": link,
            "status": "error",
            "status_code": None,
            "final_url": None,
            "error": str(e),
        }


def verify_links_parallel(links, max_workers=10):
    """Verifies links in parallel."""
    results = []

    print(f"🔍 Checking {len(links)} links with {max_workers} parallel requests...")

    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        # Submit all tasks
        future_to_link = {executor.submit(check_link, link): link for link in links}

        # Collect results as they complete
        for future in as_completed(future_to_link):
            result = future.result()
            results.append(result)

            # Progress indicator
            valid = sum(1 for r in results if r["status"] == "valid")
            total = len(results)
            print(f"\r📊 Progress: {total}/{len(links)} - ✅ {valid} valid", end="", flush=True)

    print()  # New line after progress
    return results


def analyze_results(results):
    """Analyzes the verification results."""
    stats = {"valid": 0, "invalid": 0, "timeout": 0, "connection_error": 0, "error": 0}

    invalid_links = []
    valid_links = []

    for result in results:
        stats[result["status"]] += 1

        if result["status"] == "valid":
            valid_links.append(result["link"])
        else:
            invalid_links.append(result)

    return stats, valid_links, invalid_links


def print_report(stats, valid_links, invalid_links):
    """Prints a detailed report."""
    print("\n" + "=" * 60)
    print("📋 LINK VERIFICATION REPORT")
    print("=" * 60)

    print(f"✅ Valid links: {stats['valid']}")
    print(f"❌ Invalid links: {stats['invalid']}")
    print(f"⏱️  Timeouts: {stats['timeout']}")
    print(f"🔗 Connection errors: {stats['connection_error']}")
    print(f"🚨 Other errors: {stats['error']}")

    total = sum(stats.values())
    success_rate = (stats["valid"] / total) * 100 if total > 0 else 0
    print(f"\n📈 Success rate: {success_rate:.1f}%")

    if invalid_links:
        print(f"\n❌ INVALID LINKS ({len(invalid_links)}):")
        print("-" * 40)
        for invalid in invalid_links[:10]:  # Show first 10
            print(f"• {invalid['link']}")
            print(f"  Error: {invalid['error']}")
            if invalid["status_code"]:
                print(f"  Status: {invalid['status_code']}")

        if len(invalid_links) > 10:
            print(f"  ... and {len(invalid_links) - 10} more")

    print("\n✅ FIRST 5 VALID LINKS:")
    print("-" * 40)
    for link in valid_links[:5]:
        print(f"• {link}")


def get_max_workers():
    """
    Parse and validate MAX_WORKERS environment variable.

    Returns:
        int: Number of worker threads (1-32, default 5).
    """
    max_workers_env = os.getenv("MAX_WORKERS")
    default_workers = 5
    max_allowed_workers = 32

    try:
        if max_workers_env is None:
            return default_workers

        workers = int(max_workers_env)

        if workers < 1:
            print(f"⚠️  MAX_WORKERS must be >= 1, got {workers}. Defaulting to {default_workers}.")
            return default_workers
        elif workers > max_allowed_workers:
            print(
                f"⚠️  MAX_WORKERS must be <= {max_allowed_workers}, got {workers}. Limiting to {max_allowed_workers}."
            )
            return max_allowed_workers

        return workers
    except ValueError:
        print(f"⚠️  Invalid MAX_WORKERS format: {max_workers_env}. Defaulting to {default_workers}.")
        return default_workers


def extract_links_from_json(json_file):
    """Extracts all Hugging Face links from models_download.json."""
    try:
        with open(json_file, "r", encoding="utf-8") as f:
            data = json.load(f)
        
        links = []
        for category, urls in data.items():
            if isinstance(urls, list):
                for url in urls:
                    if isinstance(url, str) and "huggingface.co" in url:
                        links.append(url)
        
        return links
    except Exception as e:
        print(f"❌ Error reading JSON file: {e}")
        return []


def main():
    """Main function."""
    print("🔍 DEBUG: Starting link verification...")

    # Try JSON file first (new format), then fallback to markdown (legacy)
    json_paths = [
        Path("/opt/runpod/models_download.json"),  # Docker source
        Path("/workspace/models_download.json"),  # Docker destination
        Path(__file__).parent.parent / "models_download.json",  # Local dev
    ]
    
    markdown_paths = [
        Path("/opt/runpod/comfyui_models_complete_library.md"),  # Docker source
        Path("/workspace/comfyui_models_complete_library.md"),  # Docker destination
        Path(__file__).parent.parent / "comfyui_models_complete_library.md",  # Local dev
    ]

    # Try JSON first
    source_file = None
    file_type = None
    
    print("🔍 Looking for models_download.json...")
    for path in json_paths:
        print(f"🔍 DEBUG: Checking for JSON file at: {path}")
        if path.exists():
            source_file = path
            file_type = "json"
            print(f"✅ Found JSON file: {path}")
            break
    
    # Fallback to markdown if JSON not found
    if not source_file:
        print("⚠️  models_download.json not found, trying markdown fallback...")
        for path in markdown_paths:
            print(f"🔍 DEBUG: Checking for markdown file at: {path}")
            if path.exists():
                source_file = path
                file_type = "markdown"
                print(f"✅ Found markdown file: {path}")
                break

    if not source_file:
        print("❌ Neither models_download.json nor comfyui_models_complete_library.md found!")
        print("🔍 DEBUG: Tried paths:")
        print("\nJSON paths:")
        for path in json_paths:
            print(f"   {path} - {'EXISTS' if path.exists() else 'NOT FOUND'}")
        print("\nMarkdown paths:")
        for path in markdown_paths:
            print(f"   {path} - {'EXISTS' if path.exists() else 'NOT FOUND'}")
        sys.exit(1)

    # Extract links based on file type
    print(f"🔍 Extracting links from {file_type} file...")
    if file_type == "json":
        links = extract_links_from_json(source_file)
        if links:
            print(f"✅ Successfully extracted {len(links)} links from JSON")
    else:
        try:
            print(f"📖 Reading markdown file: {source_file}")
            with open(source_file, "r", encoding="utf-8") as f:
                content = f.read()
            print(f"✅ Successfully read {len(content)} characters from markdown file")
            
            # Debug: Show first few lines
            lines = content.split("\n")[:10]
            print("🔍 DEBUG: First 10 lines of markdown file:")
            for i, line in enumerate(lines, 1):
                print(f"   {i:2d}: {line}")
            
            links = extract_huggingface_links(content)
        except Exception as e:
            print(f"❌ Error reading markdown file: {e}")
            sys.exit(1)

    if not links:
        print("❌ No Hugging Face links found!")
        sys.exit(1)

    print(f"📎 Found: {len(links)} links")
    print("🔍 Checking accessibility...")

    # Verify links with configurable max_workers
    max_workers = get_max_workers()
    results = verify_links_parallel(links, max_workers=max_workers)

    # Analyze results
    stats, valid_links, invalid_links = analyze_results(results)

    # Print report
    print_report(stats, valid_links, invalid_links)

    # Save detailed results
    # Try to save to script directory first, fallback to /workspace if not writable
    script_dir = Path(__file__).parent
    output_file = script_dir.parent / "link_verification_results.json"

    # Check if directory exists and is writable with improved error handling
    try:
        parent_dir = output_file.parent
        # First check if parent directory exists
        if not parent_dir.exists():
            print(f"⚠️  Parent directory {parent_dir} does not exist. Using /workspace instead.")
            output_file = Path("/workspace/link_verification_results.json")
        else:
            # Only check writability if directory exists
            try:
                if not os.access(parent_dir, os.W_OK):
                    print(
                        f"⚠️  Parent directory {parent_dir} is not writable. Using /workspace instead."
                    )
                    output_file = Path("/workspace/link_verification_results.json")
            except (OSError, PermissionError) as e:
                print(
                    f"⚠️  Cannot check write permissions for {parent_dir}: {e}. Using /workspace instead."
                )
                output_file = Path("/workspace/link_verification_results.json")
    except Exception as e:
        print(f"⚠️  Unexpected error checking output path: {e}. Using /workspace instead.")
        output_file = Path("/workspace/link_verification_results.json")

    try:
        with open(output_file, "w", encoding="utf-8") as f:
            json.dump(
                {
                    "stats": stats,
                    "valid_links": valid_links,
                    "invalid_links": invalid_links,
                    "timestamp": time.time(),
                },
                f,
                indent=2,
                ensure_ascii=False,
            )
    except Exception as e:
        print(f"❌ Failed to save results to {output_file}: {e}")
        sys.exit(1)

    print(f"\n💾 Detailed results saved to: {output_file}")

    # Exit code based on success
    if stats["valid"] == 0:
        print("❌ All links are invalid!")
        sys.exit(1)
    elif stats["invalid"] > 0:
        print(f"⚠️  {stats['invalid']} links are invalid, but {stats['valid']} work.")
        sys.exit(0)  # Non-critical
    else:
        print("✅ All links are valid!")
        sys.exit(0)


if __name__ == "__main__":
    main()
