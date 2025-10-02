#!/bin/bash
set -e

echo "🚀 Starting ComfyUI + Jupyter Lab for H200 (Docker Version)"
echo "=================================================="

# Jupyter Lab im Hintergrund starten (Port 8888) - Authentifizierung per ENV
echo "📊 Starting Jupyter Lab on port 8888..."
cd /workspace

# Authentifizierung konfigurieren
JUPYTER_CMD="jupyter lab --no-browser --ip=0.0.0.0 --port=8888 --allow-root --notebook-dir=/workspace"

if [[ -n "$JUPYTER_TOKEN" ]]; then
    JUPYTER_CMD="$JUPYTER_CMD --NotebookApp.token='$JUPYTER_TOKEN'"
fi
if [[ -n "$JUPYTER_PASSWORD" ]]; then
    JUPYTER_CMD="$JUPYTER_CMD --NotebookApp.password='$JUPYTER_PASSWORD'"
fi

if [[ -z "$JUPYTER_TOKEN" && -z "$JUPYTER_PASSWORD" ]]; then
    if [[ "$ALLOW_NO_AUTH" == "true" ]]; then
        echo "⚠️  WARNING: Starting Jupyter Lab WITHOUT authentication! (Not recommended for production)"
        JUPYTER_CMD="$JUPYTER_CMD --NotebookApp.token='' --NotebookApp.password=''"
    else
        echo "❌ ERROR: No Jupyter authentication configured. Set JUPYTER_TOKEN and/or JUPYTER_PASSWORD environment variables."
        echo "      To explicitly allow no authentication (NOT RECOMMENDED), set ALLOW_NO_AUTH=true."
        exit 1
    fi
else
    echo "🔒 Jupyter Lab will require authentication (token/password)."
fi

nohup $JUPYTER_CMD > /workspace/jupyter.log 2>&1 &
echo "✅ Jupyter Lab started in background (see /workspace/jupyter.log for details)"

# H200 Environment optimieren
export PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:1024,expandable_segments:True
export TORCH_ALLOW_TF32_CUBLAS_OVERRIDE=1

cd /workspace/ComfyUI

# Python-basierte Performance-Optimierungen laden
echo "Loading H200 optimizations..."
if [ -f h200_optimizations.py ]; then
    python3 h200_optimizations.py
else
    echo "⚠️  Warning: h200_optimizations.py not found, skipping H200 optimizations."
fi

echo "⚡ Starting ComfyUI with H200 launch flags..."

# Startparameter (ComfyUI als Hauptprozess)
exec python main.py \
    --listen 0.0.0.0 \
    --port 8188 \
    --highvram \
    --bf16-vae \
    --disable-smart-memory \
    --preview-method auto

