# syntax=docker/dockerfile:1
# Base Image: Das von dir spezifizierte RunPod Template
# Platform wird über Build-Argument gesetzt (nicht konstant)  
FROM runpod/pytorch:2.8.0-py3.11-cuda12.8.1-cudnn-devel-ubuntu22.04

# Metadaten für das Image
LABEL maintainer="Sebastian"
LABEL description="Optimized ComfyUI with WAN 2.2 for NVIDIA H200 based on validated instructions."

# Umgebungsvariable, um interaktive Abfragen bei Installationen zu unterdrücken
ENV DEBIAN_FRONTEND=noninteractive

# --- TEIL 1 & 2: System Setup & Python Environment ---

# System-Abhängigkeiten installieren
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y git wget curl unzip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Python-Abhängigkeiten in einer einzigen Schicht installieren (optimiert für Docker Caching)
# Deinstalliert zuerst zur Sicherheit und installiert dann alle H200-optimierten Pakete.
RUN pip uninstall -y torch torchvision torchaudio xformers && \
    pip install --no-cache-dir torch==2.8.0 torchvision==0.23.0 torchaudio==2.8.0 --index-url https://download.pytorch.org/whl/cu128 && \
    pip install --no-cache-dir ninja flash-attn --no-build-isolation && \
    pip install --no-cache-dir tensorrt nvidia-tensorrt accelerate transformers diffusers scipy opencv-python Pillow numpy

# Workspace einrichten
WORKDIR /workspace

# --- TEIL 3: ComfyUI Installation ---

# ComfyUI klonen und dessen Python-Abhängigkeiten (ohne PyTorch) installieren
RUN git clone https://github.com/comfyanonymous/ComfyUI.git && \
    cd ComfyUI && \
    git checkout v0.3.57 && \
    pip install --no-cache-dir $(grep -v -E "^torch([^a-z]|$)|torchvision|torchaudio" requirements.txt | grep -v "^#" | grep -v "^$" | tr '\n' ' ') && \
    pip install --no-cache-dir librosa soundfile av moviepy

# ComfyUI Manager installieren
RUN cd /workspace/ComfyUI/custom_nodes && \
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git && \
    cd ComfyUI-Manager && \
    pip install --no-cache-dir -r requirements.txt

# --- TEIL 4: H200 Performance-Optimierungen ---

# Arbeitsverzeichnis auf ComfyUI setzen für die nächsten Schritte
WORKDIR /workspace/ComfyUI

# H200 Optimierungs-Skript erstellen (moderne HEREDOC Syntax)
RUN <<EOF cat > h200_optimizations.py
import torch
import os

print("🚀 Applying H200 optimizations...")

# H200 Memory & Performance Backend-Optimierungen
torch.backends.cudnn.benchmark = True
torch.backends.cudnn.deterministic = False
torch.backends.cuda.matmul.allow_tf32 = True
torch.backends.cudnn.allow_tf32 = True

print("✅ H200 optimizations applied!")
EOF

# Extra Model Paths Konfiguration erstellen (moderne HEREDOC Syntax)
RUN <<EOF cat > extra_model_paths.yaml
comfyui:
    checkpoints: models/checkpoints/
    diffusion_models: models/diffusion_models/
    vae: models/vae/
    loras: models/loras/
    text_encoders: models/text_encoders/
    audio_encoders: models/audio_encoders/
EOF

# H200-optimiertes Start-Skript erstellen (moderne HEREDOC Syntax)
RUN <<EOF cat > /workspace/start_comfyui_h200.sh
#!/bin/bash
set -e

echo "🚀 Starting ComfyUI + Jupyter Lab for H200 (Docker Version)"
echo "=================================================="

# Jupyter Lab im Hintergrund starten (Port 8888) - ohne Token Auth
echo "📊 Starting Jupyter Lab on port 8888..."
cd /workspace
nohup jupyter lab --no-browser --ip=0.0.0.0 --port=8888 --allow-root \
    --NotebookApp.token='' --NotebookApp.password='' \
    --notebook-dir=/workspace > /workspace/jupyter.log 2>&1 &
echo "✅ Jupyter Lab started in background (no auth required)"

# H200 Environment optimieren
export PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:1024,expandable_segments:True
export TORCH_ALLOW_TF32_CUBLAS_OVERRIDE=1

cd /workspace/ComfyUI

# Python-basierte Performance-Optimierungen laden
echo "Loading H200 optimizations..."
python3 h200_optimizations.py

echo "⚡ Starting ComfyUI with H200 launch flags..."

# Startparameter (ComfyUI als Hauptprozess)
exec python main.py \
    --listen 0.0.0.0 \
    --port 8188 \
    --highvram \
    --bf16-vae \
    --disable-smart-memory \
    --preview-method auto
EOF

# Start-Skript ausführbar machen
RUN chmod +x /workspace/start_comfyui_h200.sh

# --- TEIL 6: Start & Nutzung ---

# Port für das Web-Interface freigeben
EXPOSE 8188

# Standardbefehl, der beim Starten des Containers ausgeführt wird
# RunPod-optimiert: Falls ComfyUI nicht startet, wenigstens keep-alive
CMD ["/bin/bash", "-c", "/workspace/start_comfyui_h200.sh || (echo 'ComfyUI failed to start, keeping container alive for debugging...' && tail -f /dev/null)"]
