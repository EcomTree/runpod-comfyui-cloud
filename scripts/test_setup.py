#!/usr/bin/env python3
"""
Test Script für das ComfyUI Model Download Setup
Überprüft grundlegende Funktionalität ohne echte Downloads.
"""

import os
import sys
import json
from pathlib import Path

def test_link_verification():
    """Testet das Link-Verification Script."""
    print("🔍 Teste Link-Verifikation...")

    try:
        # Simuliere das Vorhandensein einer verifizierten Datei
        verification_file = Path("link_verification_results.json")
        if not verification_file.exists():
            print("❌ Verifikationsdatei fehlt - führe zuerst verify_links.py aus")
            return False

        # Lade und überprüfe Struktur
        with open(verification_file, 'r') as f:
            data = json.load(f)

        required_keys = ['valid_links', 'invalid_links', 'stats']
        for key in required_keys:
            if key not in data:
                print(f"❌ Fehlende Schlüssel in Verifikationsdatei: {key}")
                return False

        valid_count = len(data['valid_links'])
        print(f"✅ {valid_count} validierte Links gefunden")
        return True

    except Exception as e:
        print(f"❌ Fehler bei Link-Verifikation: {e}")
        return False

def test_directory_structure():
    """Testet die Verzeichnisstruktur-Erstellung."""
    print("📁 Teste Verzeichnisstruktur...")

    try:
        # Simuliere ComfyUI-Modell-Verzeichnisse
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
            print(f"❌ Fehlende Verzeichnisse: {', '.join(missing_dirs)}")
            return False

        print(f"✅ Alle {len(required_dirs)} Verzeichnisse vorhanden")
        return True

    except Exception as e:
        print(f"❌ Fehler bei Verzeichnisstruktur: {e}")
        return False

def test_download_script_import():
    """Testet, ob das Download-Script importierbar ist."""
    print("🐍 Teste Download-Script Import...")

    try:
        # Teste, ob das Script syntaktisch korrekt ist
        import subprocess
        result = subprocess.run([
            sys.executable, "-m", "py_compile", "scripts/download_models.py"
        ], capture_output=True, text=True)

        if result.returncode != 0:
            print(f"❌ Syntaxfehler im Download-Script: {result.stderr}")
            return False

        print("✅ Download-Script ist syntaktisch korrekt")
        return True

    except Exception as e:
        print(f"❌ Fehler beim Import-Test: {e}")
        return False

def test_model_classification():
    """Testet die Modell-Klassifikation."""
    print("🏷️  Teste Modell-Klassifikation...")

    try:
        # Teste einige Beispiel-URLs
        test_cases = [
            ("https://example.com/flux1-dev.safetensors", "unet"),
            ("https://example.com/sd_xl_base_1.0.safetensors", "checkpoints"),
            ("https://example.com/vae-ft-mse.safetensors", "vae"),
            ("https://example.com/clip_l.safetensors", "clip"),
            ("https://example.com/t5xxl_fp16.safetensors", "t5"),
            ("https://example.com/control_v11p_sd15_canny.pth", "controlnet"),
        ]

        # Importiere die Funktion (ohne echte Abhängigkeiten)
        sys.path.append("scripts")
        from download_models import ComfyUIModelDownloader

        downloader = ComfyUIModelDownloader()

        correct = 0
        for url, expected in test_cases:
            result = downloader.determine_target_directory(url)
            if result == expected:
                correct += 1
                print(f"✅ {Path(url).name} -> {result}")
            else:
                print(f"❌ {Path(url).name} -> {result} (erwartet: {expected})")

        success_rate = (correct / len(test_cases)) * 100
        print(f"📊 Klassifikationsgenauigkeit: {success_rate:.1f}%")

        return success_rate >= 80  # Mindestens 80% korrekt

    except Exception as e:
        print(f"❌ Fehler bei Klassifikation: {e}")
        return False

def main():
    """Hauptfunktion."""
    print("🧪 ComfyUI Model Download Setup Test")
    print("=" * 50)

    tests = [
        ("Link-Verifikation", test_link_verification),
        ("Verzeichnisstruktur", test_directory_structure),
        ("Download-Script Import", test_download_script_import),
        ("Modell-Klassifikation", test_model_classification),
    ]

    results = []
    for test_name, test_func in tests:
        print(f"\n{'='*50}")
        print(f"Test: {test_name}")
        print('='*50)

        success = test_func()
        results.append((test_name, success))

    # Zusammenfassung
    print(f"\n{'='*60}")
    print("📋 TEST-ZUSAMMENFASSUNG")
    print('='*60)

    passed = 0
    for test_name, success in results:
        status = "✅ BESTANDEN" if success else "❌ FEHLGESCHLAGEN"
        print(f"{test_name:25} {status}")
        if success:
            passed += 1

    success_rate = (passed / len(results)) * 100
    print(f"\n📊 Gesamterfolgsrate: {success_rate:.1f}%")

    if success_rate == 100:
        print("🎉 Alle Tests bestanden! Setup ist bereit.")
        return 0
    else:
        print(f"⚠️  {len(results) - passed} Tests fehlgeschlagen. Bitte überprüfe die Konfiguration.")
        return 1

if __name__ == "__main__":
    sys.exit(main())
