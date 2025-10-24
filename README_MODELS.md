# ComfyUI Model Auto-Download Feature

## Übersicht

Das Docker-Image enthält jetzt ein automatisches Model-Download-System, das alle validierten ComfyUI-Modelle aus der `comfyui_models_complete_library.md` herunterlädt.

## Funktionen

- ✅ **Automatische Link-Verifikation** - Überprüft alle Links vor dem Download
- 📦 **Intelligente Verzeichniszuordnung** - Sortiert Modelle automatisch in die richtigen ComfyUI-Ordner
- 🔄 **Retry-Logik** - Wiederholt fehlgeschlagene Downloads automatisch
- 📊 **Download-Statistiken** - Zeigt Fortschritt und Endergebnisse an
- 💾 **Zusammenfassung** - Erstellt eine detaillierte Übersicht aller heruntergeladenen Modelle

## Verwendung

### Automatischer Download beim Container-Start

Setze die Environment-Variable beim Start des Containers:

```bash
# Docker RunPod Template
DOWNLOAD_MODELS=true
HF_TOKEN=hf_xxx
```

> `HF_TOKEN` ist optional – ohne Token schlagen private/commercial Links (z. B. FLUX.1 Dev) mit **401 Unauthorized** fehl.

**HF_TOKEN Format**:

- Muss mit `hf_` beginnen und mindestens 10 Zeichen lang sein
- Token ohne `hf_` Präfix oder leere Tokens werden ignoriert
- Token bekommst du unter: <https://huggingface.co/settings/tokens>

### Manuelle Ausführung

Falls du den Download später starten möchtest:

```bash
# Im laufenden Container
docker exec -it <container_name> /usr/local/bin/download_comfyui_models.sh
```

Oder direkt mit Python:

```bash
# Im Container
cd /workspace
source model_dl_venv/bin/activate
python3 scripts/download_models.py /workspace
```

## Voraussetzungen

- **Speicherplatz**: Mindestens 200-300 GB freier Speicher für alle Modelle
- **Internet**: Stabile Verbindung für große Downloads
- **Zeit**: Downloads können mehrere Stunden dauern

## Download-Prozess

1. **Link-Verifikation** - Überprüft alle Hugging Face Links auf Erreichbarkeit
2. **Verzeichnisstruktur** - Erstellt die komplette ComfyUI-Modellstruktur
3. **Paralleler Download** - Lädt Modelle sequentiell für Stabilität
4. **Fortschrittsanzeige** - Zeigt Download-Status und -geschwindigkeit
5. **Zusammenfassung** - Erstellt `downloaded_models_summary.json`

## Model-Kategorien

Das System sortiert Modelle automatisch in die richtigen Verzeichnisse:

- `checkpoints/` - SD1.5, SDXL, SD3 Basis-Checkpoints
- `unet/` - FLUX, SD3, Hunyuan, Kolors UNet-Modelle
- `vae/` - VAE-Modelle für Latent Space
- `clip/` - CLIP Text Encoder
- `t5/` - T5 Text Encoder
- `clip_vision/` - CLIP Vision Encoder für IP-Adapter
- `controlnet/` - ControlNet Modelle
- `loras/` - LoRA-Modelle
- `upscale_models/` - ESRGAN, RealESRGAN, SwinIR
- `animatediff_models/` - AnimateDiff Motion Module
- `ipadapter/` - IP-Adapter Modelle

## Troubleshooting

### Model-Download startet nicht

**Symptom**: Ordner in `/workspace/ComfyUI/models/` bleiben leer, keine Download-Aktivität

**Ursache**: Die `comfyui_models_complete_library.md` fehlt im Container

**Lösung**: Image neu bauen nach dem neuesten Commit:

```bash
# Lokaler Build
./scripts/build.sh

# Oder via RunPod: Neues Image aus Registry pullen
```

**Verifikation**: Im laufenden Container prüfen:

```bash
# Checken ob die Datei existiert
ls -lh /opt/runpod/comfyui_models_complete_library.md
ls -lh /workspace/comfyui_models_complete_library.md

# Download-Log prüfen
tail -f /workspace/model_download.log
```

### Jupyter "File Load Error" beim Öffnen von Model-Ordnern

**Symptom**: Jupyter zeigt "File Load Error for 'put_vae_here'" oder ähnliche Fehler

**Ursache**: Die Model-Ordner enthalten nur `.placeholder` Dateien (z.B. `put_vae_here`) - diese sind Dummy-Dateien die Jupyter nicht öffnen kann

**Lösung**: Das ist kein Fehler! Die Placeholder-Dateien sind nur da um die Git-Ordnerstruktur zu erhalten. Sobald der Model-Download läuft, werden echte Model-Dateien hinzugefügt.

**Workaround**: Einfach ignorieren oder nur echte Model-Dateien (`.safetensors`, `.ckpt`) öffnen.

### Downloads schlagen fehl

```bash
# Erneut versuchen
cd /workspace
source model_dl_venv/bin/activate
python3 scripts/download_models.py /workspace
```

### Speicherplatz prüfen

```bash
# Verfügbaren Speicher anzeigen
df -h /workspace

# Model-Größen anzeigen
du -sh /workspace/ComfyUI/models/*
```

### Link-Verifikation erneut ausführen

```bash
# Links erneut überprüfen
cd /workspace
source model_dl_venv/bin/activate
python3 scripts/verify_links.py
```

## Statistiken

Nach dem Download erhältst du:

- **Link-Verifikationsbericht** in `link_verification_results.json`
- **Download-Zusammenfassung** in `downloaded_models_summary.json`
- **Detaillierte Logs** während des Downloads

## Performance-Tipps

1. **Volume-Größe**: Verwende mindestens 500 GB Volume für alle Modelle
2. **Network Storage**: Nutze schnelle Netzwerk-Volumes für bessere Download-Geschwindigkeit
3. **Parallele Downloads**: Standardmäßig sequentiell für Stabilität
4. **Retry-Logic**: Automatische Wiederholung bei Netzwerkfehlern

## Sicherheit

- ✅ **Validierte Links**: Nur funktionierende Hugging Face Links werden verwendet
- ✅ **Saubere Downloads**: Streaming-Download ohne Zwischenspeicherung
- ✅ **Fehlerbehandlung**: Sichere Behandlung von Netzwerkfehlern
- ✅ **Keine schädlichen Scripts**: Reine Python-Implementierung

## Lizenzhinweise

- **FLUX.1 Dev**: Erfordert Enterprise-Lizenz für kommerzielle Nutzung
- **SD3.x**: Community License mit Umsatzbegrenzung
- **Andere Modelle**: Verschiedene Open-Source Lizenzen

Siehe `comfyui_models_complete_library.md` für detaillierte Lizenzinformationen.

---

**Maintained by:** [@tensorvisuals](https://github.com/tensorvisuals)  
**Status:** ✅ Production Ready  
**Last Updated:** 2025-10-14
