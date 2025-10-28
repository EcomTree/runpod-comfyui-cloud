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
# NOTE: The 'nvidia-tensorrt' package has been removed from the pip install command.
# Reason: Migrated to upstream 'tensorrt' package for compatibility with H200 hardware and CUDA 12.8.
# If you require 'nvidia-tensorrt', please update your workflow or install it manually.
RUN pip uninstall -y torch torchvision torchaudio xformers && \
    pip install --no-cache-dir torch==2.8.0 torchvision==0.23.0 torchaudio==2.8.0 --index-url https://download.pytorch.org/whl/cu128 && \
    pip install --no-cache-dir ninja flash-attn --no-build-isolation && \
    pip install --no-cache-dir tensorrt accelerate transformers diffusers scipy opencv-python Pillow numpy

# Setup workspace
WORKDIR /workspace

# Prepare directory for bundled assets
RUN mkdir -p /opt/runpod

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
COPY comfyui_models_complete_library.md /opt/runpod/
RUN mkdir -p /opt/runpod/scripts
COPY scripts/verify_links.py scripts/download_models.py scripts/manual_download.sh /opt/runpod/scripts/
RUN chmod +x /opt/runpod/scripts/*.sh

# Create virtual environment for download scripts
RUN python3 -m venv /opt/runpod/model_dl_venv && \
    /opt/runpod/model_dl_venv/bin/pip install --no-cache-dir "requests>=2.32.4"

# Provide shared utility for flag normalization to avoid duplication
RUN <<'EOF' cat > /usr/local/bin/normalize_flag.sh
#!/bin/bash
normalize_flag() {
    local raw="$1"
    local lowered
    lowered="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')"
    case "$lowered" in
        1|true|yes|on)
            printf "true"
            return 0
            ;;
        0|false|no|off|'')
            printf "false"
            return 0
            ;;
        *)
            printf "false"
            return 1
            ;;
    esac
}
EOF
RUN chmod +x /usr/local/bin/normalize_flag.sh

# Create model download script (runs only when DOWNLOAD_MODELS=true)
RUN <<'EOF' cat > /usr/local/bin/download_comfyui_models.sh
#!/bin/bash

source /usr/local/bin/normalize_flag.sh

# Read environment variables at runtime (values from docker run -e flags)
echo "🔍 DEBUG: Environment variables (read at runtime):"
HF_TOKEN="${HF_TOKEN:-}"
DOWNLOAD_MODELS_RAW="${DOWNLOAD_MODELS:-}"
NS_OUT="$(normalize_flag "$DOWNLOAD_MODELS_RAW"; printf ':%s' "$?")"
DOWNLOAD_MODELS_VALUE="${NS_OUT%:*}"
DOWNLOAD_MODELS_STATUS="${NS_OUT##*:}"
DOWNLOAD_MODELS_DISPLAY="$DOWNLOAD_MODELS_RAW"
if [ -z "$DOWNLOAD_MODELS_DISPLAY" ]; then
    DOWNLOAD_MODELS_DISPLAY="<unset>"
fi
if [ "$DOWNLOAD_MODELS_STATUS" -ne 0 ]; then
    echo "⚠️  Unrecognized value for DOWNLOAD_MODELS ('${DOWNLOAD_MODELS_DISPLAY}'). Defaulting to disabled."
fi
echo "   DOWNLOAD_MODELS raw='${DOWNLOAD_MODELS_DISPLAY}' normalized='${DOWNLOAD_MODELS_VALUE}'"
DOWNLOAD_MODELS="${DOWNLOAD_MODELS_VALUE}"
if [ -n "$HF_TOKEN" ]; then
    echo "   HF_TOKEN='YES'"
else
    echo "   HF_TOKEN='NO'"
fi

if [ "${DOWNLOAD_MODELS_VALUE:-false}" = "true" ]; then
    echo "🚀 Starting automatic download of ComfyUI models in background..."
    echo "📁 This may take a long time and require significant storage!"
    echo "💾 Ensure the mounted volume has enough free space."
    echo "📋 Check /workspace/model_download.log for progress."

    cd /workspace

    LIBRARY_SOURCE="/opt/runpod/comfyui_models_complete_library.md"
    LIBRARY_DEST="/workspace/comfyui_models_complete_library.md"

    echo "🔍 DEBUG: Checking library file..."
    if [ -f "$LIBRARY_SOURCE" ]; then
        echo "✅ Library source found: $LIBRARY_SOURCE"
        ls -lh "$LIBRARY_SOURCE"
    else
        echo "❌ Library source NOT found: $LIBRARY_SOURCE"
        echo "❌ Cannot proceed with model downloads without library file!"
        echo "Available files in /opt/runpod/:"
        ls -la /opt/runpod/ || true
        exit 1
    fi

    if [ ! -f "$LIBRARY_DEST" ]; then
        echo "📄 Copying comfyui_models_complete_library.md into /workspace"
        cp "$LIBRARY_SOURCE" "$LIBRARY_DEST" || {
            echo "❌ Failed to copy library file!"
            echo "Source: $LIBRARY_SOURCE"
            echo "Destination: $LIBRARY_DEST"
            exit 1
        }
        echo "✅ Library file copied successfully"
    else
        echo "✅ Library destination already exists: $LIBRARY_DEST"
    fi

    # Check if virtual environment exists
    echo "🔍 DEBUG: Checking virtual environment..."
    if [ -d "/opt/runpod/model_dl_venv" ]; then
        echo "✅ Virtual environment found"
        echo "🔍 DEBUG: Checking activation script..."
        if [ -f "/opt/runpod/model_dl_venv/bin/activate" ]; then
            echo "✅ Activation script found"
        else
            echo "❌ Activation script missing!"
        fi
    else
        echo "❌ Virtual environment not found!"
        echo "Available directories in /workspace:"
        ls -la /workspace/ | grep -E "^d" || true
    fi

    # Check if scripts exist
    echo "🔍 DEBUG: Checking download scripts..."
    if [ -f "/opt/runpod/scripts/verify_links.py" ]; then
        echo "✅ verify_links.py found"
    else
        echo "❌ verify_links.py NOT found"
        echo "Available files in /opt/runpod/scripts/:"
        ls -la /opt/runpod/scripts/ || true
    fi

    if [ -f "/opt/runpod/scripts/download_models.py" ]; then
        echo "✅ download_models.py found"
    else
        echo "❌ download_models.py NOT found"
    fi

    # Run model download in background with logging
    # Export HF_TOKEN directly in the environment for the background job
    # Using 'env' ensures the variable is properly propagated to all child processes
    env HF_TOKEN="${HF_TOKEN}" nohup bash -c "
        set -e

        echo \"🔍 DEBUG: Inside background process\"
        echo \"   Working directory: \$(pwd)\"
        echo \"   HF_TOKEN set: \$(if [ -n \"\$HF_TOKEN\" ]; then echo 'YES'; else echo 'NO'; fi)\"

        # Activate virtual environment
        echo \"🔍 DEBUG: Activating virtual environment...\"
        source /opt/runpod/model_dl_venv/bin/activate || {
            echo \"❌ Failed to activate virtual environment!\"
            exit 1
        }

        # Verify links (if not already done)
        echo \"🔍 DEBUG: Checking for link verification results...\"
        if [ ! -f \"link_verification_results.json\" ]; then
            echo \"🔍 Checking link accessibility...\"
            if ! python3 /opt/runpod/scripts/verify_links.py; then
                verify_exit=\$?
                echo \"❌ Link verification failed!\"
                echo \"   Exit code: \$verify_exit\"
                echo \"   Check /workspace/model_download.log for details\"
                exit \$verify_exit
            fi
        else
            echo \"✅ Link verification already completed\"
        fi

        # Check if verification results exist
        if [ -f \"link_verification_results.json\" ]; then
            echo \"✅ Verification results found\"
            echo \"🔍 DEBUG: Verification results preview:\"
            head -5 link_verification_results.json || true
        else
            echo \"❌ No verification results found!\"
            echo \"Available JSON files:\"
            find . -name \"*.json\" -type f 2>/dev/null || true
        fi

        # Download models
        echo \"⬇️  Starting model download...\"
        if ! python3 /opt/runpod/scripts/download_models.py /workspace; then
            download_exit=\$?
            echo \"❌ Model download failed!\"
            echo \"   Exit code: \$download_exit\"
            echo \"   Check /workspace/model_download.log for details\"
            exit \$download_exit
        fi

        echo \"✅ Model download finished!\"
    " > /workspace/model_download.log 2>&1 &
    
    DOWNLOAD_PID=$!
    echo "✅ Model download started in background (nohup wrapper PID: $DOWNLOAD_PID)"
    echo "   Note: This is the PID of the wrapper process, not the actual Python script."
    echo "   Use 'pgrep -f download_models.py' to find the actual process PID."
else
    echo "ℹ️  Model download skipped (raw='${DOWNLOAD_MODELS_DISPLAY}', normalized='${DOWNLOAD_MODELS}')."
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

source /usr/local/bin/normalize_flag.sh

echo "🚀 Starting ComfyUI + Jupyter Lab for H200 (Docker Version)"
echo "=================================================="

# Install ComfyUI function to avoid code duplication
install_comfyui() {
    echo "📦 Installing ComfyUI to persistent volume..."
    cd /workspace
    
    # Remove incomplete installation if it exists
    if [ -d ComfyUI ]; then
        echo "ℹ️  Removing incomplete ComfyUI directory..."
        rm -rf ComfyUI
    fi
    
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
    
    echo "✅ ComfyUI installation completed!"
}

# Check if ComfyUI exists and is properly installed (important for volume mounts)
if [ ! -d "/workspace/ComfyUI" ] || [ ! -f "/workspace/ComfyUI/main.py" ]; then
    echo "⚠️  ComfyUI not found or incomplete in /workspace (volume mount detected)"
    install_comfyui
else
    echo "✅ ComfyUI found in /workspace"
fi

# Always create/update H200 optimization files (even if ComfyUI was already present)
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

# Create extra model paths file if it does not already exist (preserve user customizations)
if [ ! -f extra_model_paths.yaml ]; then
    cat > extra_model_paths.yaml << 'YAMLEOF'
comfyui:
    checkpoints: models/checkpoints/
    diffusion_models: models/diffusion_models/
    vae: models/vae/
    loras: models/loras/
    text_encoders: models/text_encoders/
    audio_encoders: models/audio_encoders/
YAMLEOF
else
    echo "ℹ️ Preserving existing extra_model_paths.yaml"
fi

# Normalize runtime feature flags
JUPYTER_ENABLE_RAW="${JUPYTER_ENABLE:-}"
set +e
NS_OUT="$(normalize_flag "$JUPYTER_ENABLE_RAW"; printf ':%s' "$?")"
set -e
JUPYTER_ENABLE_VALUE="${NS_OUT%:*}"
JUPYTER_ENABLE_STATUS="${NS_OUT##*:}"
JUPYTER_ENABLE_DISPLAY="$JUPYTER_ENABLE_RAW"
if [ -z "$JUPYTER_ENABLE_DISPLAY" ]; then
    JUPYTER_ENABLE_DISPLAY="<unset>"
fi
if [ "$JUPYTER_ENABLE_STATUS" -ne 0 ]; then
    echo "⚠️  Unrecognized value for JUPYTER_ENABLE ('${JUPYTER_ENABLE_DISPLAY}'). Defaulting to disabled."
fi
echo "🔍 DEBUG: JUPYTER_ENABLE raw='${JUPYTER_ENABLE_DISPLAY}' normalized='${JUPYTER_ENABLE_VALUE}'"
export JUPYTER_ENABLE="${JUPYTER_ENABLE_VALUE}"

DOWNLOAD_MODELS_RAW="${DOWNLOAD_MODELS:-}"
set +e
NS_OUT="$(normalize_flag "$DOWNLOAD_MODELS_RAW"; printf ':%s' "$?")"
set -e
DOWNLOAD_MODELS_VALUE="${NS_OUT%:*}"
DOWNLOAD_MODELS_STATUS="${NS_OUT##*:}"
DOWNLOAD_MODELS_DISPLAY="$DOWNLOAD_MODELS_RAW"
if [ -z "$DOWNLOAD_MODELS_DISPLAY" ]; then
    DOWNLOAD_MODELS_DISPLAY="<unset>"
fi
if [ "$DOWNLOAD_MODELS_STATUS" -ne 0 ]; then
    echo "⚠️  Unrecognized value for DOWNLOAD_MODELS ('${DOWNLOAD_MODELS_DISPLAY}'). Defaulting to disabled."
fi
echo "🔍 DEBUG: DOWNLOAD_MODELS raw='${DOWNLOAD_MODELS_DISPLAY}' normalized='${DOWNLOAD_MODELS_VALUE}'"
export DOWNLOAD_MODELS="${DOWNLOAD_MODELS_VALUE}"

# Start Jupyter Lab in the background (port 8888)
if [ "${JUPYTER_ENABLE_VALUE:-false}" = "true" ]; then
  echo "📊 Starting Jupyter Lab on port 8888..."
  cd /workspace
  
  # Check if password is set
  if [ -n "${JUPYTER_PASSWORD:-}" ]; then
    # Start with password authentication
    echo "🔐 Using password authentication"
    # Hash the password without exposing it via command-line args
    HASHED_PASSWORD_AND_ERROR=$(python3 - <<'PY'
import os
import sys
try:
    from jupyter_server.auth import passwd
except ImportError as e:
    print(f"IMPORT_ERROR: {e}", file=sys.stderr)
    sys.exit(2)
try:
    password = os.environ.get("JUPYTER_PASSWORD", "")
    print(passwd(password))
except Exception as e:
    print(f"HASH_ERROR: {e}", file=sys.stderr)
    sys.exit(3)
PY
)
    PYTHON_EXIT_CODE=$?
    if [ $PYTHON_EXIT_CODE -ne 0 ]; then
        echo "❌ Failed to hash password! Python error output:"
        echo "${HASHED_PASSWORD_AND_ERROR}"
        exit 1
    fi
    HASHED_PASSWORD="${HASHED_PASSWORD_AND_ERROR}"
    # Remove plaintext password from environment
    unset JUPYTER_PASSWORD
    nohup jupyter lab --no-browser --ip=0.0.0.0 --port=8888 --allow-root \
        --ServerApp.password="${HASHED_PASSWORD}" \
        --notebook-dir=/workspace > /workspace/jupyter.log 2>&1 &
    echo "✅ Jupyter Lab started in background (password protected)"
  else
    # Start without auth (no password provided)
    echo "⚠️  Starting Jupyter Lab WITHOUT authentication"
    nohup jupyter lab --no-browser --ip=0.0.0.0 --port=8888 --allow-root \
        --ServerApp.token='' --ServerApp.password='' \
        --notebook-dir=/workspace > /workspace/jupyter.log 2>&1 &
    echo "✅ Jupyter Lab started in background (no auth required)"
  fi
else
  echo "ℹ️  Jupyter disabled (set JUPYTER_ENABLE=true to start)"
fi

# Optimize H200 environment variables
export PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:1024,expandable_segments:True
export TORCH_ALLOW_TF32_CUBLAS_OVERRIDE=1

# Download models if requested
echo "🔍 Checking model download status..."
echo "🔧 Running enhanced model download script..."

# Create log file first to avoid "unary operator expected" errors
touch /workspace/model_download.log

/usr/local/bin/download_comfyui_models.sh

# Wait for the background model downloader only when enabled
if [ "${DOWNLOAD_MODELS_VALUE:-false}" = "true" ]; then
    echo "⏳ Waiting for model download to start writing logs..."
    MAX_WAIT_SECONDS=${DOWNLOAD_LOG_WAIT_SECS:-10}
    WAIT_COUNT=0
    while [ ! -s "/workspace/model_download.log" ] && [ "$WAIT_COUNT" -lt "$MAX_WAIT_SECONDS" ]; do
        sleep 1
        WAIT_COUNT=$((WAIT_COUNT + 1))
    done

    # Show the beginning of the model download log if it has content
    if [ -s "/workspace/model_download.log" ]; then
        echo "📋 Recent model download log entries:"
        tail -20 /workspace/model_download.log || true
    else
        echo "⚠️  Model download log is still empty after ${MAX_WAIT_SECONDS} seconds."
        echo "   This can occur if downloads are slow to start."
    fi
else
    echo "ℹ️  DOWNLOAD_MODELS disabled (raw='${DOWNLOAD_MODELS_DISPLAY}', normalized='${DOWNLOAD_MODELS_VALUE}'); skipping log wait."
fi

cd /workspace/ComfyUI

# Load Python-based performance optimizations
echo "Loading H200 optimizations..."
python3 h200_optimizations.py

echo "⚡ Starting ComfyUI with H200 launch flags..."

# Final safety check before starting ComfyUI
if [ ! -f "/workspace/ComfyUI/main.py" ]; then
    echo "❌ main.py not found in /workspace/ComfyUI - installation failed!"
    echo "🔍 Directory contents:"
    ls -la /workspace/ComfyUI/ || true
    exit 1
fi

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
