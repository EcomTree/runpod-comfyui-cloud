# syntax=docker/dockerfile:1.7

ARG BASE_IMAGE=runpod/pytorch:2.8.0-py3.11-cuda12.8.1-cudnn-devel-ubuntu22.04

FROM ${BASE_IMAGE} AS builder

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_NO_CACHE_DIR=1

RUN --mount=type=cache,target=/var/cache/apt,id=builder-apt-cache \
    apt-get update && apt-get install -y --no-install-recommends git jq ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /opt/build

COPY scripts/get_latest_version.sh /opt/build/scripts/get_latest_version.sh
COPY scripts/install_custom_nodes.sh /opt/build/scripts/install_custom_nodes.sh
COPY configs/custom_nodes.json /opt/build/configs/custom_nodes.json

RUN chmod +x /opt/build/scripts/get_latest_version.sh /opt/build/scripts/install_custom_nodes.sh

ARG COMFYUI_VERSION
RUN set -e; \
    VERSION_INPUT="${COMFYUI_VERSION:-}"; \
    if [ -z "$VERSION_INPUT" ]; then \
        VERSION_INPUT=$(/opt/build/scripts/get_latest_version.sh | tail -n1); \
    fi; \
    if [ -z "$VERSION_INPUT" ]; \
    then \
        VERSION_INPUT="master"; \
    fi; \
    echo "$VERSION_INPUT" > /opt/build/comfyui_version.txt

RUN set -e; \
    VERSION=$(cat /opt/build/comfyui_version.txt); \
    echo "📦 Cloning ComfyUI ${VERSION}..." >&2; \
    git clone --depth 1 --branch "$VERSION" https://github.com/comfyanonymous/ComfyUI.git || { \
        echo "⚠️  Branch ${VERSION} not found, using master" >&2; \
        rm -rf ComfyUI; \
        git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git; \
    }; \
    cd ComfyUI && rm -rf .git

RUN set +e; \
    INSTALL_REQUIREMENTS=false SKIP_EXISTING=false /opt/build/scripts/install_custom_nodes.sh /opt/build/ComfyUI; \
    EXIT_CODE=$?; \
    set -e; \
    echo "Custom node installation completed with exit code: $EXIT_CODE"; \
    find /opt/build/ComfyUI -name ".git" -type d -prune -exec rm -rf {} + 2>/dev/null || true; \
    find /opt/build/ComfyUI -name "__pycache__" -type d -prune -exec rm -rf {} + 2>/dev/null || true

FROM ${BASE_IMAGE} AS runtime

# Image metadata
LABEL maintainer="Sebastian"
LABEL description="Optimized ComfyUI with WAN 2.2 for NVIDIA H200 based on validated instructions."

# Environment variable to suppress interactive prompts during install
ENV DEBIAN_FRONTEND=noninteractive \
    PIP_NO_CACHE_DIR=1 \
    PATH="/home/comfy/.local/bin:${PATH}"
# --- PART 1 & 2: System setup & Python environment ---

# Install system dependencies (with BuildKit caching)
RUN --mount=type=cache,target=/var/cache/apt,id=runtime-apt-cache \
    apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends git wget curl unzip python3-venv jq ca-certificates tini && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install Python dependencies in a single layer (optimized for Docker caching)
# Removes existing packages first and installs the H200-optimized stack.
# NOTE: The 'nvidia-tensorrt' package has been removed from the pip install command.
# Reason: Migrated to upstream 'tensorrt' package for compatibility with H200 hardware and CUDA 12.8.
# If you require 'nvidia-tensorrt', please update your workflow or install it manually.
RUN --mount=type=cache,target=/root/.cache/pip \
    pip uninstall -y torch torchvision torchaudio xformers && \
    pip install torch==2.8.0 torchvision==0.23.0 torchaudio==2.8.0 --index-url https://download.pytorch.org/whl/cu128 && \
    pip install ninja flash-attn --no-build-isolation && \
    pip install tensorrt accelerate transformers diffusers scipy opencv-python Pillow numpy

# Install JupyterLab for interactive development
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install jupyterlab notebook jupyter-server-proxy

# Setup workspace
WORKDIR /workspace

# Prepare directory for bundled assets
RUN mkdir -p /opt/runpod

# --- PART 3: ComfyUI installation ---

# Copy ComfyUI from builder stage (pre-cloned with custom nodes)
COPY --from=builder /opt/build/ComfyUI /workspace/ComfyUI
COPY --from=builder /opt/build/comfyui_version.txt /opt/runpod/comfyui_version.txt

# Install ComfyUI Python dependencies (without PyTorch)
RUN --mount=type=cache,target=/root/.cache/pip \
    cd /workspace/ComfyUI && \
    if [ ! -f requirements.txt ]; then \
        echo "❌ requirements.txt not found in ComfyUI repository." >&2; \
        exit 1; \
    fi && \
    grep -v -E "^torch([^a-z]|$)|torchvision|torchaudio" requirements.txt | grep -v "^#" | grep -v "^$" > /tmp/comfyui-requirements.txt && \
    if [ -s /tmp/comfyui-requirements.txt ]; then \
        pip install -r /tmp/comfyui-requirements.txt; \
    else \
        echo "ℹ️  No additional ComfyUI Python dependencies detected."; \
    fi && \
    rm -f /tmp/comfyui-requirements.txt && \
    pip install librosa soundfile av moviepy

# Copy configuration assets
RUN mkdir -p /opt/runpod/configs /opt/runpod/scripts
COPY comfyui_models_complete_library.md /opt/runpod/
COPY models_download.json /opt/runpod/
COPY configs/custom_nodes.json /opt/runpod/configs/
COPY configs/ui_settings.json /opt/runpod/configs/

# Copy runtime scripts
COPY scripts/verify_links.py scripts/download_models.py scripts/manual_download.sh scripts/optimize_performance.py scripts/install_custom_nodes.sh scripts/get_latest_version.sh /opt/runpod/scripts/
RUN chmod +x /opt/runpod/scripts/*.sh && chmod +x /opt/runpod/scripts/*.py

# Install custom node Python requirements only
RUN --mount=type=cache,target=/root/.cache/pip \
    INSTALL_REQUIREMENTS_ONLY=true SKIP_EXISTING=true PIP_INSTALL_FLAGS="--user --no-cache-dir" /opt/runpod/scripts/install_custom_nodes.sh /workspace/ComfyUI && \
    echo "✅ Custom node requirements installed"

# --- PART 3.5: Model download scripts ---

# Create virtual environment for download scripts with enhanced features
RUN python3 -m venv /opt/runpod/model_dl_venv && \
    /opt/runpod/model_dl_venv/bin/pip install --no-cache-dir "requests>=2.32.4" "tqdm>=4.65.0"

# Provide shared utility for flag normalization to avoid duplication
RUN cat > /usr/local/bin/normalize_flag.sh <<'EOF'
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

# Echo combined normalized value and exit status as VALUE:STATUS
normalize_with_status() {
    local raw="$1"
    local value
    value="$(normalize_flag "$raw")"
    local status=$?
    printf "%s:%s" "$value" "$status"
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
NS_OUT="$(normalize_with_status "$DOWNLOAD_MODELS_RAW")"
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

    # Copy models_download.json (primary source)
    JSON_SOURCE="/opt/runpod/models_download.json"
    JSON_DEST="/workspace/models_download.json"
    
    echo "🔍 DEBUG: Checking models_download.json..."
    if [ -f "$JSON_SOURCE" ]; then
        echo "✅ JSON source found: $JSON_SOURCE"
        ls -lh "$JSON_SOURCE"
        if [ ! -f "$JSON_DEST" ]; then
            echo "📄 Copying models_download.json into /workspace"
            cp "$JSON_SOURCE" "$JSON_DEST" || {
                echo "❌ Failed to copy JSON file!"
                echo "Source: $JSON_SOURCE"
                echo "Destination: $JSON_DEST"
                exit 1
            }
            echo "✅ JSON file copied successfully"
        else
            echo "✅ JSON destination already exists: $JSON_DEST"
        fi
    else
        echo "⚠️  JSON source NOT found: $JSON_SOURCE"
    fi
    
    # Copy markdown file (fallback/legacy)
    LIBRARY_SOURCE="/opt/runpod/comfyui_models_complete_library.md"
    LIBRARY_DEST="/workspace/comfyui_models_complete_library.md"

    echo "🔍 DEBUG: Checking library file..."
    if [ -f "$LIBRARY_SOURCE" ]; then
        echo "✅ Library source found: $LIBRARY_SOURCE"
        ls -lh "$LIBRARY_SOURCE"
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
    else
        echo "⚠️  Library source NOT found: $LIBRARY_SOURCE"
    fi
    
    # Check if at least one source exists
    if [ ! -f "$JSON_DEST" ] && [ ! -f "$LIBRARY_DEST" ]; then
        echo "❌ Neither models_download.json nor comfyui_models_complete_library.md found!"
        echo "❌ Cannot proceed with model downloads!"
        echo "Available files in /opt/runpod/:"
        ls -la /opt/runpod/ || true
        exit 1
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
    echo "ℹ️  Model download skipped (raw='${DOWNLOAD_MODELS_DISPLAY}', normalized='${DOWNLOAD_MODELS_VALUE}')."
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
RUN <<'EOF' cat > /usr/local/bin/start_comfyui_h200.sh
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
    
    # Get ComfyUI version (use environment variable or fetch latest)
    if [ -n "${COMFYUI_VERSION:-}" ]; then
        COMFYUI_TAG="${COMFYUI_VERSION}"
        echo "📌 Using pinned version: ${COMFYUI_TAG}"
    else
        echo "🔍 Fetching latest ComfyUI version..."
        if [ -f /opt/runpod/scripts/get_latest_version.sh ]; then
            COMFYUI_TAG=$(/opt/runpod/scripts/get_latest_version.sh)
        else
            echo "⚠️  Version script not found, using master branch"
            COMFYUI_TAG="master"
        fi
        echo "✅ Using version: ${COMFYUI_TAG}"
    fi
    
    # Clone ComfyUI with determined version
    git clone --depth 1 --branch "${COMFYUI_TAG}" https://github.com/comfyanonymous/ComfyUI.git || {
        echo "⚠️  Branch ${COMFYUI_TAG} not found, trying master..." >&2
        git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git || {
            echo "❌ Failed to clone ComfyUI repository." >&2
            exit 1
        }
    }
    cd ComfyUI
    
    export PIP_INSTALL_FLAGS="--user --no-cache-dir"
    
    # Check if requirements.txt exists
    if [ ! -f requirements.txt ]; then
        echo "❌ requirements.txt not found in ComfyUI repository." >&2
        exit 1
    fi
    
    # Install Python dependencies (without PyTorch, already installed)
    grep -v -E "^torch([^a-z]|$)|torchvision|torchaudio" requirements.txt | grep -v "^#" | grep -v "^$" > /tmp/filtered_requirements.txt
    if [ -s /tmp/filtered_requirements.txt ]; then
        python3 -m pip install ${PIP_INSTALL_FLAGS} -r /tmp/filtered_requirements.txt
    else
        echo "ℹ️  No additional ComfyUI Python dependencies detected."
    fi
    rm -f /tmp/filtered_requirements.txt
    python3 -m pip install ${PIP_INSTALL_FLAGS} librosa soundfile av moviepy
    
    # Install custom nodes using installation script
    if [ -f /opt/runpod/scripts/install_custom_nodes.sh ]; then
        echo "🔌 Installing custom nodes..."
        PIP_INSTALL_FLAGS="--user --no-cache-dir" /opt/runpod/scripts/install_custom_nodes.sh /workspace/ComfyUI || {
            echo "⚠️  Custom nodes installation had issues, continuing..." >&2
        }
    else
        echo "⚠️  Custom nodes installation script not found, skipping..."
    fi
    
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

# Copy UI settings if not already present
if [ ! -f /workspace/.comfyui/user_settings.json ]; then
    mkdir -p /workspace/.comfyui
    if [ -f /opt/runpod/configs/ui_settings.json ]; then
        cp /opt/runpod/configs/ui_settings.json /workspace/.comfyui/user_settings.json
        echo "✅ UI settings configured (dark theme, auto-queue enabled)"
    fi
fi

# RunPod Secret Support: Check for RunPod-style secret variables
# RunPod may expose secrets as RUNPOD_SECRET_<NAME> or through /etc/runpod-volume/secrets/
secret_env() {
    VAR_NAME="$1"
    SECRET_VAR="RUNPOD_SECRET_${VAR_NAME}"
    # Use bash indirect expansion for variable lookup
    VAR_VALUE="${!VAR_NAME}"
    SECRET_VALUE="${!SECRET_VAR}"
    if [ -z "${VAR_VALUE}" ] && [ -n "${SECRET_VALUE}" ]; then
        echo "🔍 Using ${SECRET_VAR}"
        export "${VAR_NAME}=${SECRET_VALUE}"
    fi
}

secret_env "JUPYTER_ENABLE"
secret_env "DOWNLOAD_MODELS"
secret_env "HF_TOKEN"
# Check for secrets file (alternative RunPod mechanism)
read_secret_env() {
    VAR_NAME="$1"
    FILE_PATH="$2"
    # Only set if file exists and env var is unset
    VAR_VALUE="${!VAR_NAME}"
    if [ -f "$FILE_PATH" ] && [ -z "${VAR_VALUE}" ]; then
        echo "🔍 Reading $VAR_NAME from secrets file"
        export "${VAR_NAME}=$(cat "$FILE_PATH" 2>/dev/null || echo '')"
    fi
}

read_secret_env "JUPYTER_ENABLE" "/etc/runpod-volume/secrets/jupyter_enable"
read_secret_env "DOWNLOAD_MODELS" "/etc/runpod-volume/secrets/download_models"
read_secret_env "HF_TOKEN" "/etc/runpod-volume/secrets/hf_token"
# Normalize runtime feature flags
JUPYTER_ENABLE_RAW="${JUPYTER_ENABLE:-}"
set +e
NS_OUT="$(normalize_with_status "$JUPYTER_ENABLE_RAW")"
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

DOWNLOAD_MODELS_RAW="${DOWNLOAD_MODELS:-}"
set +e
NS_OUT="$(normalize_with_status "$DOWNLOAD_MODELS_RAW")"
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

# Debug: Print all environment variables starting with JUPYTER, DOWNLOAD, or RUNPOD
echo "🔍 DEBUG: Environment variable check:"
env | grep -E "^(JUPYTER|DOWNLOAD|RUNPOD|HF_)" | sort || echo "   (no matching variables found)"

# Start Jupyter Lab in the background (port 8888)
if [ "${JUPYTER_ENABLE_VALUE:-false}" = "true" ]; then
  echo "📊 Starting Jupyter Lab on port 8888..."
  cd /workspace
  
  # Ensure logs directory exists
  mkdir -p /workspace/logs
  
  # Pre-flight check: Verify Jupyter is installed
  if ! command -v jupyter >/dev/null 2>&1; then
    echo "❌ ERROR: Jupyter is not installed!" | tee -a /workspace/logs/jupyter.log
    echo "   This indicates a build problem with the Docker image." | tee -a /workspace/logs/jupyter.log
    echo "   Expected: 'jupyter' command should be available in PATH" | tee -a /workspace/logs/jupyter.log
    echo "   Please rebuild the image with JupyterLab installed." | tee -a /workspace/logs/jupyter.log
    exit 1
  fi
  
  echo "✅ Jupyter command found: $(command -v jupyter)"
  
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
    
    # Start Jupyter with error capture
    echo "🚀 Launching Jupyter Lab with password authentication..."
    nohup jupyter lab --no-browser --ip=0.0.0.0 --port=8888 --allow-root \
        --ServerApp.password="${HASHED_PASSWORD}" \
        --notebook-dir=/workspace > /workspace/logs/jupyter.log 2>&1 &
    JUPYTER_PID=$!
    
    # Verify process started with retry loop
    JUPYTER_STARTUP_TIMEOUT=${JUPYTER_STARTUP_TIMEOUT:-10}
    RETRY_COUNT=0
    MAX_RETRIES=$((JUPYTER_STARTUP_TIMEOUT * 2))  # Check every 0.5 seconds
    echo "⏳ Waiting for Jupyter Lab to start (timeout: ${JUPYTER_STARTUP_TIMEOUT}s)..."
    
    while [ "$RETRY_COUNT" -lt "$MAX_RETRIES" ]; do
      if ps -p "$JUPYTER_PID" > /dev/null 2>&1; then
        echo "✅ Jupyter Lab started successfully (PID: $JUPYTER_PID, password protected)"
        echo "📋 Logs: /workspace/logs/jupyter.log"
        break
      fi
      sleep 0.5
      RETRY_COUNT=$((RETRY_COUNT + 1))
    done
    
    # Final check after timeout
    if ! ps -p "$JUPYTER_PID" > /dev/null 2>&1; then
      echo "❌ ERROR: Jupyter Lab failed to start within ${JUPYTER_STARTUP_TIMEOUT}s!" | tee -a /workspace/logs/jupyter.log
      echo "📋 Check logs for details: /workspace/logs/jupyter.log" | tee -a /workspace/logs/jupyter.log
      if [ -f /workspace/logs/jupyter.log ]; then
        echo "Last 10 lines of log:" | tee -a /workspace/logs/jupyter.log
        tail -10 /workspace/logs/jupyter.log
      fi
      exit 1
    fi
  else
    # Start without auth (no password provided)
    echo "⚠️  Starting Jupyter Lab WITHOUT authentication"
    echo "   Anyone with network access can execute arbitrary code!"
    
    # Start Jupyter with error capture
    echo "🚀 Launching Jupyter Lab without authentication..."
    nohup jupyter lab --no-browser --ip=0.0.0.0 --port=8888 --allow-root \
        --ServerApp.token='' --ServerApp.password='' \
        --notebook-dir=/workspace > /workspace/logs/jupyter.log 2>&1 &
    JUPYTER_PID=$!
    
    # Verify process started with retry loop
    JUPYTER_STARTUP_TIMEOUT=${JUPYTER_STARTUP_TIMEOUT:-10}
    RETRY_COUNT=0
    MAX_RETRIES=$((JUPYTER_STARTUP_TIMEOUT * 2))  # Check every 0.5 seconds
    echo "⏳ Waiting for Jupyter Lab to start (timeout: ${JUPYTER_STARTUP_TIMEOUT}s)..."
    
    while [ "$RETRY_COUNT" -lt "$MAX_RETRIES" ]; do
      if ps -p "$JUPYTER_PID" > /dev/null 2>&1; then
        echo "✅ Jupyter Lab started successfully (PID: $JUPYTER_PID, no auth required)"
        echo "📋 Logs: /workspace/logs/jupyter.log"
        break
      fi
      sleep 0.5
      RETRY_COUNT=$((RETRY_COUNT + 1))
    done
    
    # Final check after timeout
    if ! ps -p "$JUPYTER_PID" > /dev/null 2>&1; then
      echo "❌ ERROR: Jupyter Lab failed to start within ${JUPYTER_STARTUP_TIMEOUT}s!" | tee -a /workspace/logs/jupyter.log
      echo "📋 Check logs for details: /workspace/logs/jupyter.log" | tee -a /workspace/logs/jupyter.log
      if [ -f /workspace/logs/jupyter.log ]; then
        echo "Last 10 lines of log:" | tee -a /workspace/logs/jupyter.log
        tail -10 /workspace/logs/jupyter.log
      fi
      exit 1
    fi
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

# Apply advanced performance optimizations
if [ -f /opt/runpod/scripts/optimize_performance.py ]; then
    echo "⚡ Applying performance optimizations..."
    python3 /opt/runpod/scripts/optimize_performance.py || echo "⚠️  Performance optimizations had issues, continuing..."
fi

echo "⚡ Starting ComfyUI with H200 launch flags..."

# Final safety check before starting ComfyUI
if [ ! -f "/workspace/ComfyUI/main.py" ]; then
    echo "❌ main.py not found in /workspace/ComfyUI - installation failed!"
    echo "🔍 Directory contents:"
    ls -la /workspace/ComfyUI/ || true
    exit 1
fi

# Check if torch.compile is available (PyTorch 2.0+)
TORCH_COMPILE_ENABLED=""
if python3 -c "import torch; print(int(torch.__version__.split('.')[0]) >= 2)" 2>/dev/null | grep -q "1"; then
    # Enable torch.compile if available (20-30% speed boost)
    TORCH_COMPILE_ENABLED="--enable-compile"
    echo "✅ torch.compile enabled (PyTorch 2.0+)"
else
    echo "ℹ️  torch.compile not available (requires PyTorch 2.0+)"
fi

# Launch parameters (ComfyUI as main process)
exec python main.py \
    --listen 0.0.0.0 \
    --port 8188 \
    --highvram \
    --bf16-vae \
    --disable-smart-memory \
    --preview-method auto \
    --enable-cors-header \
    --extra-model-paths-config extra_model_paths.yaml \
    ${TORCH_COMPILE_ENABLED}
EOF

# Make start script executable
RUN chmod +x /usr/local/bin/start_comfyui_h200.sh

# Create dedicated runtime user with secure permissions
RUN useradd -m -r -s /bin/bash comfy && \
    chown -R comfy:comfy /workspace /opt/runpod && \
    mkdir -p /home/comfy/.cache && \
    chown -R comfy:comfy /home/comfy/.cache && \
    chmod 700 /home/comfy/.cache

# Security: Make /opt/runpod read-only for runtime (scripts should not be modified)
RUN chmod -R 755 /opt/runpod/scripts && \
    chmod 644 /opt/runpod/*.json /opt/runpod/*.md 2>/dev/null || true

# Optional: API authentication environment variable (empty by default, set at runtime)
ENV COMFYUI_API_KEY=""

# Healthcheck to ensure ComfyUI is responding
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=5 CMD curl -fsS http://localhost:8188/queue/status || exit 1

# Switch to non-root user
USER comfy

# --- PART 6: Startup & usage ---

# Expose port for the web interface
EXPOSE 8188

# Default command executed when the container starts
# RunPod-optimized: keep container alive if ComfyUI fails
# Script lives in /usr/local/bin/ so it works with volume mounts
CMD ["/bin/bash", "-c", "/usr/local/bin/start_comfyui_h200.sh || (echo 'ComfyUI failed to start, keeping container alive for debugging...' && tail -f /dev/null)"]
