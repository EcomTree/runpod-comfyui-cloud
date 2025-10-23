#!/bin/bash
set -euo pipefail

log() {
    local level="$1"
    shift
    echo "${level} $*"
}

trap 'log "❌" "Installation failed at line ${LINENO}. Check the logs above."; exit 1' ERR

log "🚀" "Starting ComfyUI + Jupyter Lab for H200 (Docker Version)"
echo "=================================================="

ensure_comfyui_exists() {
    if [ -d "/workspace/ComfyUI/.git" ] && [ -f "/workspace/ComfyUI/main.py" ]; then
        log "✅" "ComfyUI found in /workspace"
        return
    fi

    log "⚠️" "ComfyUI not found in /workspace (Volume Mount detected)"
    log "📦" "Installing ComfyUI to persistent volume..."

    cd /workspace

    if [ -d ComfyUI ] && [ ! -d ComfyUI/.git ]; then
        log "ℹ️" "Removing leftover /workspace/ComfyUI directory without git metadata."
        rm -rf ComfyUI
    fi

    git clone --depth 1 --branch v0.3.57 https://github.com/comfyanonymous/ComfyUI.git
    cd ComfyUI

    if [ ! -f requirements.txt ]; then
        log "❌" "requirements.txt missing in ComfyUI repo; aborting."
        exit 1
    fi

    grep -v -E "^torch([^a-z]|$)|torchvision|torchaudio" requirements.txt | grep -v "^#" | grep -v "^$" > /tmp/comfyui-requirements.txt
    status=$?
    if [ $status -ne 0 ] && [ $status -ne 1 ]; then
        log "❌" "Error filtering requirements.txt (grep failed with exit code $status)."
        exit 1
    fi

    if [ -s /tmp/comfyui-requirements.txt ]; then
        pip install --no-cache-dir -r /tmp/comfyui-requirements.txt
    else
        log "ℹ️" "No additional ComfyUI Python dependencies detected."
    fi
    rm -f /tmp/comfyui-requirements.txt

    pip install --no-cache-dir librosa soundfile av moviepy

    install_comfyui_manager

    log "✅" "ComfyUI installation completed!"
}

install_comfyui_manager() {
    cd /workspace/ComfyUI
    mkdir -p custom_nodes
    cd custom_nodes

    if [ -d ComfyUI-Manager/.git ]; then
        log "ℹ️" "ComfyUI-Manager already present. Pulling latest changes."
        git -C ComfyUI-Manager fetch --depth 1 origin || log "⚠️" "Failed to fetch updates for ComfyUI-Manager."
        git -C ComfyUI-Manager reset --hard origin/main || log "⚠️" "Failed to reset ComfyUI-Manager to origin/main."
    else
        git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Manager.git
    fi

    cd ComfyUI-Manager

    if [ ! -f requirements.txt ]; then
        log "❌" "requirements.txt missing in ComfyUI-Manager; aborting."
        exit 1
    fi

    pip install --no-cache-dir -r requirements.txt
}

generate_files() {
    cd /workspace/ComfyUI

    cat > h200_optimizations.py <<'PYEOF'
import torch

print("🚀 Applying H200 optimizations...")

torch.backends.cudnn.benchmark = True
torch.backends.cudnn.deterministic = False
torch.backends.cuda.matmul.allow_tf32 = True
torch.backends.cudnn.allow_tf32 = True

print("✅ H200 optimizations applied!")
PYEOF

    cat > extra_model_paths.yaml <<'YAMLEOF'
comfyui:
    checkpoints: models/checkpoints/
    diffusion_models: models/diffusion_models/
    vae: models/vae/
    loras: models/loras/
    text_encoders: models/text_encoders/
    audio_encoders: models/audio_encoders/
YAMLEOF
}

ensure_comfyui_exists

# Always ensure required files exist (even if ComfyUI was already installed)
generate_files

log "📊" "Starting Jupyter Lab on port 8888..."
cd /workspace
nohup jupyter lab --no-browser --ip=0.0.0.0 --port=8888 --allow-root \
    --NotebookApp.token='' --NotebookApp.password='' \
    --notebook-dir=/workspace > /workspace/jupyter.log 2>&1 &
log "✅" "Jupyter Lab started in background (no auth required)"

export PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:1024,expandable_segments:True
export TORCH_ALLOW_TF32_CUBLAS_OVERRIDE=1

cd /workspace/ComfyUI

log "Loading" "H200 optimizations..."
python3 h200_optimizations.py

log "⚡" "Starting ComfyUI with H200 launch flags..."

# Final safety check before starting ComfyUI
if [ ! -f "/workspace/ComfyUI/main.py" ]; then
    log "❌" "main.py not found in /workspace/ComfyUI - installation failed!"
    log "🔍" "Directory contents:"
    ls -la . || true
    exit 1
fi

exec python main.py \
    --listen 0.0.0.0 \
    --port 8188 \
    --highvram \
    --bf16-vae \
    --disable-smart-memory \
    --preview-method auto

