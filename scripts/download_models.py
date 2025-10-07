#!/usr/bin/env python3
"""
ComfyUI Model Downloader Script
Lädt alle validierten ComfyUI Modelle in das angegebene Verzeichnis herunter.
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

HF_TOKEN = os.getenv("HF_TOKEN")

SESSION = requests.Session()
SESSION.headers.update({
    'User-Agent': 'ComfyUI-Model-Downloader/1.0'
})

if HF_TOKEN:
    SESSION.headers['Authorization'] = f'Bearer {HF_TOKEN.strip()}'
else:
    print("⚠️  Kein HF_TOKEN gesetzt. Geschützte Hugging Face Downloads können fehlschlagen.")


class ComfyUIModelDownloader:
    def __init__(self, base_dir="/workspace", verification_file="link_verification_results.json"):
        self.base_dir = Path(base_dir)
        self.verification_file = verification_file
        self.models_dir = self.base_dir / "ComfyUI" / "models"
        self.session = SESSION

        # Erstelle Verzeichnisstruktur
        self.create_directory_structure()

    def create_directory_structure(self):
        """Erstellt die notwendige ComfyUI Verzeichnisstruktur."""
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

        print(f"📁 Verzeichnisstruktur erstellt in: {self.models_dir}")

    def load_verified_links(self):
        """Lädt die verifizierten Links aus der JSON-Datei."""
        try:
            with open(self.verification_file, 'r', encoding='utf-8') as f:
                data = json.load(f)
                return data.get('valid_links', [])
        except FileNotFoundError:
            print(f"❌ Verifikationsdatei {self.verification_file} nicht gefunden!")
            print("🔍 Führe zuerst 'python3 scripts/verify_links.py' aus.")
            sys.exit(1)

    def determine_target_directory(self, url):
        """Bestimmt das Zielverzeichnis basierend auf der URL und dem Dateinamen."""
        filename = Path(urlparse(url).path).name.lower()

        # Mapping von Dateiendungen zu Verzeichnissen
        mapping = {
            # Checkpoints (SD1.5, SDXL, etc.)
            'checkpoints': ['.ckpt', '.safetensors'],

            # FLUX und andere UNet Modelle
            'unet': ['flux', 'sd3', 'auraflow', 'hunyuan', 'kolors', 'lumina'],

            # VAE Modelle
            'vae': ['vae', 'kl-f8-anime'],

            # CLIP Encoder
            'clip': ['clip', 'open_clip'],

            # T5 Encoder
            't5': ['t5', 'umt5'],

            # CLIP Vision
            'clip_vision': ['clip_vision', 'image_encoder'],

            # ControlNet
            'controlnet': ['controlnet', 'control_', 'canny', 'depth', 'openpose', 'scribble'],

            # LoRAs
            'loras': ['lora', '.lora'],

            # Upscaler
            'upscale_models': ['esrgan', 'realesrgan', 'swinir', '4x', '2x', 'upscale'],

            # AnimateDiff
            'animatediff_models': ['animatediff', 'mm_', 'motion'],

            # IP-Adapter
            'ipadapter': ['ip-adapter', 'ip_adapter'],

            # Text Encoders (allgemein)
            'text_encoders': ['text_encoder', 'encoder']
        }

        for directory, patterns in mapping.items():
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
        """Lädt eine einzelne Datei herunter mit Retry-Logik."""
        target_path = Path(target_path)
        target_path.parent.mkdir(parents=True, exist_ok=True)

        for attempt in range(retry_count):
            try:
                print(f"⬇️  Lade herunter: {Path(url).name} (Versuch {attempt + 1}/{retry_count})")

                # Stream download für große Dateien
                with self.session.get(url, stream=True, timeout=30) as response:
                    response.raise_for_status()

                    # Hole Dateigröße für Fortschrittsanzeige
                    total_size = int(response.headers.get('content-length', 0))

                    with open(target_path, 'wb') as f:
                        downloaded = 0
                        for chunk in response.iter_content(chunk_size=8192):
                            if chunk:
                                f.write(chunk)
                                downloaded += len(chunk)

                                # Fortschritt für große Dateien
                                if total_size > 0 and downloaded % (10 * 1024 * 1024) == 0:  # Alle 10MB
                                    progress = (downloaded / total_size) * 100
                                    print(f"   📈 {progress:.1f}% ({downloaded / 1024 / 1024:.1f} MB)")

                print(f"✅ Erfolgreich heruntergeladen: {target_path}")
                return True

            except requests.exceptions.RequestException as e:
                print(f"❌ Fehler beim Download (Versuch {attempt + 1}): {e}")
                if attempt < retry_count - 1:
                    wait_time = (attempt + 1) * 5  # Exponentielles Backoff
                    print(f"⏳ Warte {wait_time} Sekunden vor erneutem Versuch...")
                    time.sleep(wait_time)
                else:
                    print(f"❌ Maximale Versuche erreicht für: {url}")
                    return False

            except Exception as e:
                print(f"❌ Unerwarteter Fehler: {e}")
                return False

    def download_all_models(self, parallel_downloads=3):
        """Lädt alle Modelle herunter."""
        valid_links = self.load_verified_links()

        if not valid_links:
            print("❌ Keine validierten Links gefunden!")
            return

        print(f"🚀 Starte Download von {len(valid_links)} Modellen...")
        print(f"📁 Zielverzeichnis: {self.models_dir}")
        print(f"⚡ Parallele Downloads: {parallel_downloads}")

        successful = 0
        failed = 0

        # Für einfachere parallele Downloads verwenden wir einen ThreadPool
        from concurrent.futures import ThreadPoolExecutor, as_completed

        def download_single_model(url):
            target_dir = self.determine_target_directory(url)
            target_path = self.models_dir / target_dir / Path(url).name

            # Überspringe, wenn Datei bereits existiert
            if target_path.exists():
                print(f"⏭️  Überspringe (bereits vorhanden): {target_path.name}")
                return True

            return self.download_file(url, target_path)

        # Führe Downloads sequentiell aus (stabiler für große Dateien)
        for i, url in enumerate(valid_links, 1):
            print(f"\n📦 [{i}/{len(valid_links)}] Verarbeite: {Path(url).name}")

            if download_single_model(url):
                successful += 1
            else:
                failed += 1

            # Kurze Pause zwischen Downloads
            time.sleep(1)

        print("\n🎉 Download-Statistik:")
        print(f"✅ Erfolgreich: {successful}")
        print(f"❌ Fehlgeschlagen: {failed}")
        print(f"📊 Erfolgsrate: {(successful / (successful + failed)) * 100:.1f}%")

        if failed > 0:
            print(f"\n⚠️  {failed} Downloads sind fehlgeschlagen.")
            print("🔄 Du kannst das Script erneut ausführen, um fehlgeschlagene Downloads zu wiederholen.")
        else:
            print("\n🎊 Alle Downloads erfolgreich abgeschlossen!")

    def create_download_summary(self):
        """Erstellt eine Zusammenfassung der heruntergeladenen Modelle."""
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
                    size_mb = file_path.stat().st_size / (1024 * 1024)

                    model_info[category].append({
                        'filename': file,
                        'size_mb': round(size_mb, 2),
                        'path': str(file_path.relative_to(self.base_dir))
                    })

        # Sortiere nach Kategorie und Dateiname
        for category in model_info:
            model_info[category].sort(key=lambda x: x['filename'])

        with open(summary_file, 'w', encoding='utf-8') as f:
            json.dump({
                'total_files': sum(len(files) for files in model_info.values()),
                'total_size_mb': round(sum(sum(f['size_mb'] for f in files) for files in model_info.values()), 2),
                'download_date': time.time(),
                'models': model_info
            }, f, indent=2, ensure_ascii=False)

        print(f"📋 Download-Zusammenfassung erstellt: {summary_file}")

        return summary_file

def main():
    """Hauptfunktion."""
    if len(sys.argv) > 1:
        base_dir = sys.argv[1]
    else:
        base_dir = "/workspace"

    print("🤖 ComfyUI Model Downloader")
    print("=" * 50)
    print(f"📁 Basisverzeichnis: {base_dir}")

    downloader = ComfyUIModelDownloader(base_dir)

    # Bestätigung einholen
    print("\n⚠️  ACHTUNG: Dies wird viele große Modelle herunterladen!")
    print("💾 Stelle sicher, dass genügend Speicherplatz verfügbar ist.")
    print("🌐 Eine stabile Internetverbindung wird empfohlen.")

    try:
        input("\n🚀 Drücke Enter um mit dem Download zu beginnen...")
    except KeyboardInterrupt:
        print("\n⏹️  Download abgebrochen.")
        sys.exit(0)

    # Start download
    start_time = time.time()
    downloader.download_all_models(parallel_downloads=1)  # Sequentiell für Stabilität
    download_time = time.time() - start_time

    # Erstelle Zusammenfassung
    print("\n📋 Erstelle Download-Zusammenfassung...")
    summary_file = downloader.create_download_summary()

    print("\n⏱️  Download-Dauer:")
    print(f"   {download_time:.1f} Sekunden ({download_time/60:.1f} Minuten)")

    print("\n✅ Download-Prozess abgeschlossen!")
    print(f"📄 Siehe {summary_file} für Details.")

if __name__ == "__main__":
    main()
