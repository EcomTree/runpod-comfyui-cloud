# syntax=docker/dockerfile:1
# Base image specified by the RunPod template
# Platform is provided through build arguments
FROM runpod/pytorch:2.8.0-py3.11-cuda12.8.1-cudnn-devel-ubuntu22.04

# Image metadata
LABEL maintainer="Sebastian"
LABEL description="Optimized ComfyUI with WAN 2.2 for NVIDIA H200 based on validated instructions."

# Environment variable to suppress interactive prompts during install
ENV DEBIAN_FRONTEND=noninteractive

# --- PART 1 & 2: System setup & Python environment ---

# Install system dependencies
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y git wget curl unzip python3-venv && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install Python dependencies in a single layer (optimized for Docker caching)
# Removes existing packages first and installs the H200-optimized stack.
RUN pip uninstall -y torch torchvision torchaudio xformers && \
    pip install --no-cache-dir torch==2.8.0 torchvision==0.23.0 torchaudio==2.8.0 --index-url https://download.pytorch.org/whl/cu128 && \
    pip install --no-cache-dir ninja flash-attn --no-build-isolation && \
    pip install --no-cache-dir tensorrt nvidia-tensorrt accelerate transformers diffusers scipy opencv-python Pillow numpy

# Workspace einrichten
WORKDIR /workspace

# --- PART 3: ComfyUI installation ---

# Clone ComfyUI and install its Python dependencies (without PyTorch)
RUN set -e; \
    git clone --depth 1 --branch v0.3.57 https://github.com/comfyanonymous/ComfyUI.git && \
    cd ComfyUI && \
    if [ ! -f requirements.txt ]; then \
        echo "❌ requirements.txt not found in ComfyUI repository." >&2; \
        exit 1; \
    fi && \
    grep -v -E "^torch([^a-z]|$)|torchvision|torchaudio" requirements.txt | grep -v "^#" | grep -v "^$" > /tmp/comfyui-requirements.txt && \
    if [ -s /tmp/comfyui-requirements.txt ]; then \
        pip install --no-cache-dir -r /tmp/comfyui-requirements.txt; \
    else \
        echo "ℹ️  No additional ComfyUI Python dependencies detected."; \
    fi && \
    rm -f /tmp/comfyui-requirements.txt && \
    pip install --no-cache-dir librosa soundfile av moviepy

# Install ComfyUI Manager
RUN set -e; \
    cd /workspace/ComfyUI && \
    mkdir -p custom_nodes && \
    cd custom_nodes && \
    if [ -d ComfyUI-Manager/.git ]; then \
        echo "ℹ️  ComfyUI-Manager already present, skipping fresh clone."; \
    else \
        git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Manager.git || { echo "❌ Failed to clone ComfyUI-Manager." >&2; exit 1; }; \
    fi && \
    cd ComfyUI-Manager && \
    if [ ! -f requirements.txt ]; then \
        echo "❌ requirements.txt not found in ComfyUI-Manager." >&2; \
        exit 1; \
    fi && \
    pip install --no-cache-dir -r requirements.txt

# --- PART 3.5: Model download scripts ---

# Copy model documentation and scripts into the image
COPY comfyui_models_complete_library.md /workspace/
COPY scripts/verify_links.py scripts/download_models.py /workspace/scripts/

# Create virtual environment for download scripts
RUN cd /workspace && \
    python3 -m venv model_dl_venv && \
    /workspace/model_dl_venv/bin/pip install --no-cache-dir requests==2.31.0

# Create model download script (runs only when DOWNLOAD_MODELS=true)
RUN <<'EOF' cat > /usr/local/bin/download_comfyui_models.sh
#!/bin/bash

DOWNLOAD_MODELS=${DOWNLOAD_MODELS:-false}
HF_TOKEN=${HF_TOKEN:-}

if [ "$DOWNLOAD_MODELS" = "true" ]; then
    echo "🚀 Starting automatic download of ComfyUI models in background..."
    echo "📁 This may take a long time and require significant storage!"
    echo "💾 Ensure the mounted volume has enough free space."
    echo "📋 Check /workspace/model_download.log for progress."

    cd /workspace

    # Run model download in background with logging
    # Pass HF_TOKEN explicitly to the background process for reliable propagation
    # Using env ensures the token is available regardless of shell quoting issues
    env HF_TOKEN="${HF_TOKEN}" nohup bash -c '
        set -e
        
        # Activate virtual environment
        source model_dl_venv/bin/activate

        # Verify links (if not already done)
        if [ ! -f "link_verification_results.json" ]; then
            echo "🔍 Checking link accessibility..."
            python3 /workspace/scripts/verify_links.py
        fi

        # Download models
        echo "⬇️  Starting model download..."
        python3 /workspace/scripts/download_models.py /workspace

        echo "✅ Model download finished!"
    ' > /workspace/model_download.log 2>&1 &
    
    echo "✅ Model download started in background (PID: $!)"
else
    echo "ℹ️  Model download skipped (DOWNLOAD_MODELS != true)"
fi
EOF

# Make script executable
RUN chmod +x /usr/local/bin/download_comfyui_models.sh

# --- PART 4: H200 performance optimizations ---

# Set workdir to ComfyUI for the next steps
WORKDIR /workspace/ComfyUI

# Create H200 optimization script (modern HEREDOC syntax)
RUN <<EOF cat > h200_optimizations.py
import torch

print("🚀 Applying H200 optimizations...")

# H200 memory & performance backend optimizations
torch.backends.cudnn.benchmark = True
torch.backends.cudnn.deterministic = False
torch.backends.cuda.matmul.allow_tf32 = True
torch.backends.cudnn.allow_tf32 = True

print("✅ H200 optimizations applied!")
EOF

# Create extra model paths configuration (modern HEREDOC syntax)
RUN <<EOF cat > extra_model_paths.yaml
comfyui:
    checkpoints: models/checkpoints/
    diffusion_models: models/diffusion_models/
    vae: models/vae/
    loras: models/loras/
    text_encoders: models/text_encoders/
    audio_encoders: models/audio_encoders/
EOF

# Create H200-optimized start script (modern HEREDOC syntax)
# IMPORTANT: copy to /usr/local/bin/ so it works with volume mounts on /workspace
RUN <<EOF cat > /usr/local/bin/start_comfyui_h200.sh
#!/bin/bash
set -e

echo "🚀 Starting ComfyUI + Jupyter Lab for H200 (Docker Version)"
echo "=================================================="

# Check if ComfyUI exists (important for volume mounts)
if [ ! -d "/workspace/ComfyUI" ]; then
    echo "⚠️  ComfyUI not found in /workspace (volume mount detected)"
    echo "📦 Installing ComfyUI to persistent volume..."
    
    cd /workspace
    
    # Clone ComfyUI (shallow clone at tag v0.3.57)
    git clone --depth 1 --branch v0.3.57 https://github.com/comfyanonymous/ComfyUI.git || {
        echo "❌ Failed to clone ComfyUI repository." >&2
        exit 1
    }
    cd ComfyUI
    
    # Check if requirements.txt exists
    if [ ! -f requirements.txt ]; then
        echo "❌ requirements.txt not found in ComfyUI repository." >&2
        exit 1
    fi
    
    # Install Python dependencies (without PyTorch, already installed)
    grep -v -E "^torch([^a-z]|$)|torchvision|torchaudio" requirements.txt | grep -v "^#" | grep -v "^$" > /tmp/filtered_requirements.txt
    if [ -s /tmp/filtered_requirements.txt ]; then
        pip install --no-cache-dir -r /tmp/filtered_requirements.txt
    else
        echo "ℹ️  No additional ComfyUI Python dependencies detected."
    fi
    rm -f /tmp/filtered_requirements.txt
    pip install --no-cache-dir librosa soundfile av moviepy
    
    # Install ComfyUI Manager
    mkdir -p custom_nodes
    cd custom_nodes
    git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Manager.git || {
        echo "❌ Failed to clone ComfyUI-Manager repository." >&2
        exit 1
    }
    
    # Check if ComfyUI-Manager directory exists
    if [ ! -d "ComfyUI-Manager" ]; then
        echo "❌ ComfyUI-Manager directory not found after clone!" >&2
        exit 1
    fi
    
    cd ComfyUI-Manager
    
    # Check if requirements.txt exists
    if [ ! -f requirements.txt ]; then
        echo "❌ requirements.txt not found in ComfyUI-Manager!" >&2
        exit 1
    fi
    
    pip install --no-cache-dir -r requirements.txt
    cd /workspace/ComfyUI
    
    # Create H200 optimization helper
    cat > h200_optimizations.py << 'PYEOF'
import torch

print("🚀 Applying H200 optimizations...")

# H200 memory & performance backend optimizations
torch.backends.cudnn.benchmark = True
torch.backends.cudnn.deterministic = False
torch.backends.cuda.matmul.allow_tf32 = True
torch.backends.cudnn.allow_tf32 = True

print("✅ H200 optimizations applied!")
PYEOF
    
    # Create extra model paths file
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

# Start Jupyter Lab in the background (port 8888) without token auth
echo "📊 Starting Jupyter Lab on port 8888..."
cd /workspace
nohup jupyter lab --no-browser --ip=0.0.0.0 --port=8888 --allow-root \
    --NotebookApp.token='' --NotebookApp.password='' \
    --notebook-dir=/workspace > /workspace/jupyter.log 2>&1 &
echo "✅ Jupyter Lab started in background (no auth required)"

# Optimize H200 environment variables
export PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:1024,expandable_segments:True
export TORCH_ALLOW_TF32_CUBLAS_OVERRIDE=1

# Download models if requested
echo "🔍 Checking model download status..."
/usr/local/bin/download_comfyui_models.sh

cd /workspace/ComfyUI

# Load Python-based performance optimizations
echo "Loading H200 optimizations..."
python3 h200_optimizations.py

echo "⚡ Starting ComfyUI with H200 launch flags..."

# Launch parameters (ComfyUI as main process)
exec python main.py \
    --listen 0.0.0.0 \
    --port 8188 \
    --highvram \
    --bf16-vae \
    --disable-smart-memory \
    --preview-method auto
EOF

# Make start script executable
RUN chmod +x /usr/local/bin/start_comfyui_h200.sh

# --- PART 6: Startup & usage ---

# Expose port for the web interface
EXPOSE 8188

# Default command executed when the container starts
# RunPod-optimized: keep container alive if ComfyUI fails
# Script lives in /usr/local/bin/ so it works with volume mounts
CMD ["/bin/bash", "-c", "/usr/local/bin/start_comfyui_h200.sh || (echo 'ComfyUI failed to start, keeping container alive for debugging...' && tail -f /dev/null)"]
