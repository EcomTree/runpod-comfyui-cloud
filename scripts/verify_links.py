#!/usr/bin/env python3
"""
Link Verification Script for ComfyUI Models Library
Verifies all Hugging Face links for accessibility and correctness.
"""

import os
import requests
import re
import json
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from urllib.parse import urlparse
from pathlib import Path
import time

HF_TOKEN = os.getenv("HF_TOKEN")

# Validate HF_TOKEN format if provided
if HF_TOKEN:
    HF_TOKEN = HF_TOKEN.strip()
    if not HF_TOKEN.startswith('hf_') or len(HF_TOKEN) < 10:
        print("⚠️  Warning: HF_TOKEN format appears invalid. Valid tokens start with 'hf_' and have sufficient length.")
        print("⚠️  Protected Hugging Face links may fail.")

SESSION = requests.Session()
SESSION.headers.update({
    'User-Agent': 'ComfyUI-Model-Link-Checker/1.0'
})

if HF_TOKEN:
    SESSION.headers['Authorization'] = f'Bearer {HF_TOKEN}'
else:
    print("⚠️  No HF_TOKEN set. Protected Hugging Face links may fail.")

def extract_huggingface_links(content):
    """Extracts all Hugging Face links from the markdown content."""
    # Regex for Hugging Face links (https://huggingface.co/...)
    hf_pattern = r'https://huggingface\.co/[^\s\)]+'
    links = re.findall(hf_pattern, content)

    # Filter only actual download links (safetensors, ckpt, etc.)
    download_links = []
    for link in links:
        if any(ext in link.lower() for ext in ['.safetensors', '.ckpt', '.pth', '.bin', '.pt']):
            download_links.append(link)

    return download_links

def check_link(link, timeout=10):
    """Checks a single link."""
    try:
        # Remove query parameters for a clean URL
        clean_link = link.split('?')[0] if '?' in link else link

        # HEAD request for faster verification
        response = SESSION.head(clean_link, timeout=timeout, allow_redirects=True)

        # For Hugging Face: 200, 302, 307 are OK
        if response.status_code in [200, 302, 307]:
            return {
                'link': link,
                'status': 'valid',
                'status_code': response.status_code,
                'final_url': response.url,
                'error': None
            }
        else:
            return {
                'link': link,
                'status': 'invalid',
                'status_code': response.status_code,
                'final_url': response.url,
                'error': f'HTTP {response.status_code}'
            }

    except requests.exceptions.Timeout:
        return {
            'link': link,
            'status': 'timeout',
            'status_code': None,
            'final_url': None,
            'error': f'Timeout after {timeout}s'
        }
    except requests.exceptions.ConnectionError:
        return {
            'link': link,
            'status': 'connection_error',
            'status_code': None,
            'final_url': None,
            'error': 'Connection failed'
        }
    except Exception as e:
        return {
            'link': link,
            'status': 'error',
            'status_code': None,
            'final_url': None,
            'error': str(e)
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
            valid = sum(1 for r in results if r['status'] == 'valid')
            total = len(results)
            print(f"\r📊 Progress: {total}/{len(links)} - ✅ {valid} valid", end="", flush=True)

    print()  # New line after progress
    return results

def analyze_results(results):
    """Analyzes the verification results."""
    stats = {
        'valid': 0,
        'invalid': 0,
        'timeout': 0,
        'connection_error': 0,
        'error': 0
    }

    invalid_links = []
    valid_links = []

    for result in results:
        stats[result['status']] += 1

        if result['status'] == 'valid':
            valid_links.append(result['link'])
        else:
            invalid_links.append(result)

    return stats, valid_links, invalid_links

def print_report(stats, valid_links, invalid_links):
    """Prints a detailed report."""
    print("\n" + "="*60)
    print("📋 LINK VERIFICATION REPORT")
    print("="*60)

    print(f"✅ Valid links: {stats['valid']}")
    print(f"❌ Invalid links: {stats['invalid']}")
    print(f"⏱️  Timeouts: {stats['timeout']}")
    print(f"🔗 Connection errors: {stats['connection_error']}")
    print(f"🚨 Other errors: {stats['error']}")

    total = sum(stats.values())
    success_rate = (stats['valid'] / total) * 100 if total > 0 else 0
    print(f"\n📈 Success rate: {success_rate:.1f}%")

    if invalid_links:
        print(f"\n❌ INVALID LINKS ({len(invalid_links)}):")
        print("-" * 40)
        for invalid in invalid_links[:10]:  # Show first 10
            print(f"• {invalid['link']}")
            print(f"  Error: {invalid['error']}")
            if invalid['status_code']:
                print(f"  Status: {invalid['status_code']}")

        if len(invalid_links) > 10:
            print(f"  ... and {len(invalid_links) - 10} more")

    print(f"\n✅ FIRST 5 VALID LINKS:")
    print("-" * 40)
    for link in valid_links[:5]:
        print(f"• {link}")

def main():
    """Main function."""
    # Find the markdown file relative to the script location
    script_dir = Path(__file__).parent
    markdown_file = script_dir.parent / 'comfyui_models_complete_library.md'
    
    # If running from /workspace (Docker), try there too
    if not markdown_file.exists():
        markdown_file = Path('/workspace/comfyui_models_complete_library.md')
    
    # Read the markdown file
    try:
        with open(markdown_file, 'r', encoding='utf-8') as f:
            content = f.read()
    except FileNotFoundError:
        print(f"❌ comfyui_models_complete_library.md not found at {markdown_file}!")
        sys.exit(1)

    # Extract links
    print("🔍 Extracting links from documentation...")
    links = extract_huggingface_links(content)

    if not links:
        print("❌ No Hugging Face links found!")
        sys.exit(1)

    print(f"📎 Found: {len(links)} links")
    print(f"🔍 Checking accessibility...")

    # Verify links (with rate limiting)
    # Allow max_workers to be configured via environment variable
    max_workers_env = os.getenv("MAX_WORKERS")
    try:
        max_workers = int(max_workers_env) if max_workers_env is not None else 5
        if max_workers < 1:
            print(f"⚠️  MAX_WORKERS must be >= 1, got {max_workers}. Defaulting to 5.")
            max_workers = 5
    except ValueError:
        print(f"⚠️  Invalid MAX_WORKERS value: {max_workers_env}. Defaulting to 5.")
        max_workers = 5
    results = verify_links_parallel(links, max_workers=max_workers)  # Fewer workers for polite requests

    # Analyze results
    stats, valid_links, invalid_links = analyze_results(results)

    # Print report
    print_report(stats, valid_links, invalid_links)

    # Save detailed results
    # Save to script directory or /workspace if in Docker
    output_file = script_dir.parent / 'link_verification_results.json'
    if not output_file.parent.exists():
        output_file = Path('/workspace/link_verification_results.json')
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump({
            'stats': stats,
            'valid_links': valid_links,
            'invalid_links': invalid_links,
            'timestamp': time.time()
        }, f, indent=2, ensure_ascii=False)

    print(f"\n💾 Detailed results saved to: {output_file}")

    # Exit code based on success
    if stats['valid'] == 0:
        print("❌ All links are invalid!")
        sys.exit(1)
    elif stats['invalid'] > 0:
        print(f"⚠️  {stats['invalid']} links are invalid, but {stats['valid']} work.")
        sys.exit(0)  # Non-critical
    else:
        print("✅ All links are valid!")
        sys.exit(0)

if __name__ == "__main__":
    main()
