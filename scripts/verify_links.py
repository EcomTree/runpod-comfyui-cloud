#!/usr/bin/env python3
"""
Link Verification Script for ComfyUI Models Library
Überprüft alle Hugging Face Links auf Erreichbarkeit und Korrektheit.
"""

import os
import requests
import re
import json
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from urllib.parse import urlparse
import time

HF_TOKEN = os.getenv("HF_TOKEN")

SESSION = requests.Session()
SESSION.headers.update({
    'User-Agent': 'ComfyUI-Model-Link-Checker/1.0'
})

if HF_TOKEN:
    SESSION.headers['Authorization'] = f'Bearer {HF_TOKEN.strip()}'
else:
    print("⚠️  Kein HF_TOKEN gesetzt. Geschützte Hugging Face Links können fehlschlagen.")

def extract_huggingface_links(content):
    """Extrahiert alle Hugging Face Links aus dem Markdown-Inhalt."""
    # Regex für Hugging Face Links (https://huggingface.co/...)
    hf_pattern = r'https://huggingface\.co/[^\s\)]+'
    links = re.findall(hf_pattern, content)

    # Filtere nur echte Download-Links (safetensors, ckpt, etc.)
    download_links = []
    for link in links:
        if any(ext in link.lower() for ext in ['.safetensors', '.ckpt', '.pth', '.bin', '.pt']):
            download_links.append(link)

    return download_links

def check_link(link, timeout=10):
    """Überprüft einen einzelnen Link."""
    try:
        # Entferne query parameters für saubere URL
        clean_link = link.split('?')[0] if '?' in link else link

        # HEAD request für schnellere Überprüfung
        response = SESSION.head(clean_link, timeout=timeout, allow_redirects=True)

        # Für Hugging Face: 200, 302, 307 sind OK
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
    """Überprüft Links parallel."""
    results = []

    print(f"🔍 Überprüfe {len(links)} Links mit {max_workers} parallelen Anfragen...")

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
    """Analysiert die Überprüfungsergebnisse."""
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
    """Gibt einen detaillierten Bericht aus."""
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
    """Hauptfunktion."""
    # Lese die Markdown-Datei
    try:
        with open('/Users/sebastianhein/Development/runpod-comfyui-cloud/comfyui_models_complete_library.md', 'r', encoding='utf-8') as f:
            content = f.read()
    except FileNotFoundError:
        print("❌ comfyui_models_complete_library.md nicht gefunden!")
        sys.exit(1)

    # Extrahiere Links
    print("🔍 Extrahiere Links aus der Dokumentation...")
    links = extract_huggingface_links(content)

    if not links:
        print("❌ Keine Hugging Face Links gefunden!")
        sys.exit(1)

    print(f"📎 Gefunden: {len(links)} Links")
    print(f"🔍 Überprüfe Erreichbarkeit...")

    # Überprüfe Links (mit Rate Limiting)
    results = verify_links_parallel(links, max_workers=5)  # Weniger Worker für höfliche Anfragen

    # Analysiere Ergebnisse
    stats, valid_links, invalid_links = analyze_results(results)

    # Bericht ausgeben
    print_report(stats, valid_links, invalid_links)

    # Speichere detaillierte Ergebnisse
    output_file = '/Users/sebastianhein/Development/runpod-comfyui-cloud/link_verification_results.json'
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump({
            'stats': stats,
            'valid_links': valid_links,
            'invalid_links': invalid_links,
            'timestamp': time.time()
        }, f, indent=2, ensure_ascii=False)

    print(f"\n💾 Detaillierte Ergebnisse gespeichert in: {output_file}")

    # Exit code basierend auf Erfolg
    if stats['valid'] == 0:
        print("❌ Alle Links sind ungültig!")
        sys.exit(1)
    elif stats['invalid'] > 0:
        print(f"⚠️  {stats['invalid']} Links sind ungültig, aber {stats['valid']} funktionieren.")
        sys.exit(0)  # Nicht-kritisch
    else:
        print("✅ Alle Links sind gültig!")
        sys.exit(0)

if __name__ == "__main__":
    main()
