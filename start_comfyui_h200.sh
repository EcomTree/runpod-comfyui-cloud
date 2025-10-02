#!/bin/bash
set -e

echo "🚀 Starting ComfyUI + Jupyter Lab for H200 (Docker Version)"
echo "=================================================="

# Check if ComfyUI exists (wichtig für Volume-Mounts)
if [ ! -d "/workspace/ComfyUI" ]; then
    echo "⚠️  ComfyUI not found in /workspace (Volume Mount detected)"
    echo "📦 Installing ComfyUI to persistent volume..."
    
    cd /workspace
    
    # ComfyUI klonen
    git clone https://github.com/comfyanonymous/ComfyUI.git
    cd ComfyUI
    git checkout v0.3.57
    
    # Python-Abhängigkeiten installieren (ohne PyTorch, da bereits installiert)
    pip install --no-cache-dir $(grep -v -E "^torch([^a-z]|$)|torchvision|torchaudio" requirements.txt | grep -v "^#" | grep -v "^$" | tr '\n' ' ')
    pip install --no-cache-dir librosa soundfile av moviepy
    
    # ComfyUI Manager installieren
    cd custom_nodes
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git
    cd ComfyUI-Manager
    pip install --no-cache-dir -r requirements.txt
    cd /workspace/ComfyUI
    
    # H200 Optimierungen erstellen
    cat > h200_optimizations.py << 'PYEOF'
import torch
import os

print("🚀 Applying H200 optimizations...")

# H200 Memory & Performance Backend-Optimierungen
torch.backends.cudnn.benchmark = True
torch.backends.cudnn.deterministic = False
torch.backends.cuda.matmul.allow_tf32 = True
torch.backends.cudnn.allow_tf32 = True

print("✅ H200 optimizations applied!")
PYEOF
    
    # Extra Model Paths erstellen
    cat > extra_model_paths.yaml << 'YAMLEOF'
comfyui:
    checkpoints: models/checkpoints/
    diffusion_models: models/diffusion_models/
    vae: models/vae/
    loras: models/loras/
    text_encoders: models/text_encoders/
    audio_encoders: models/audio_encoders/
YAMLEOF
    
    echo "✅ ComfyUI installation completed!"
else
    echo "✅ ComfyUI found in /workspace"
fi

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

