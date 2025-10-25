#!/bin/bash
#
# Unified Setup Script for RunPod ComfyUI Cloud Environment
# This script handles ComfyUI installation, model downloads, and environment configuration
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/EcomTree/runpod-comfyui-cloud/main/scripts/setup.sh | bash
#
# Version: 2.0 (Optimized for Codex)
#

set -euo pipefail

# Script configuration
SCRIPT_VERSION="2.0"
PROJECT_NAME="runpod-comfyui-cloud"
COMFYUI_REPO="https://github.com/comfyanonymous/ComfyUI.git"
COMFYUI_MANAGER_REPO="https://github.com/ltdrdata/ComfyUI-Manager.git"

# API endpoint constants
COMFYUI_QUEUE_ENDPOINT="/queue"
JUPYTER_ROOT_ENDPOINT="/"

# Global variables
MODEL_DOWNLOAD_PID=""
WORKSPACE_DIR=""

# Cleanup function for model download process
# Note: This function may be called before common-codex.sh is sourced,
# so it uses fallback logging when log functions are not available
cleanup_model_download() {
    if [ -n "$MODEL_DOWNLOAD_PID" ] && kill -0 "$MODEL_DOWNLOAD_PID" 2>/dev/null; then
        # Use log_info if available, otherwise fallback to echo
        if command -v log_info >/dev/null 2>&1; then
            log_info "Cleaning up model download process (PID: $MODEL_DOWNLOAD_PID)"
        else
            echo "ℹ️  Cleaning up model download process (PID: $MODEL_DOWNLOAD_PID)"
        fi
        
        # Try graceful SIGTERM first
        kill -TERM "$MODEL_DOWNLOAD_PID" 2>/dev/null
        
        # Wait up to 5 seconds for graceful exit
        local wait_count=0
        while [ $wait_count -lt 5 ]; do
            sleep 1
            if ! kill -0 "$MODEL_DOWNLOAD_PID" 2>/dev/null; then
                if command -v log_success >/dev/null 2>&1; then
                    log_success "Model download process terminated gracefully"
                else
                    echo "✅ Model download process terminated gracefully"
                fi
                MODEL_DOWNLOAD_PID=""
                return 0
            fi
            wait_count=$((wait_count + 1))
        done
        
        # Force kill if still running
        if kill -0 "$MODEL_DOWNLOAD_PID" 2>/dev/null; then
            if command -v log_info >/dev/null 2>&1; then
                log_info "Model download process did not exit after SIGTERM, sending SIGKILL"
            else
                echo "ℹ️  Model download process did not exit after SIGTERM, sending SIGKILL"
            fi
            kill -KILL "$MODEL_DOWNLOAD_PID" 2>/dev/null
            MODEL_DOWNLOAD_PID=""
        fi
    fi
}

# Get script directory
get_script_dir() {
    local source="${BASH_SOURCE[0]:-$0}"
    local dir
    dir="$(dirname "$source")"
    if [[ -d "$dir" ]]; then
        (cd "$dir" && pwd)
    else
        pwd
    fi
}

SCRIPT_DIR="$(get_script_dir)"

# Try to source common helpers
# shellcheck source=/dev/null
COMMON_HELPERS="$SCRIPT_DIR/common-codex.sh"

if [ -f "$COMMON_HELPERS" ]; then
    source "$COMMON_HELPERS"
else
    # Download helper script if not found
    echo "⚠️  Missing helper script: $COMMON_HELPERS"
    echo "ℹ️  Attempting to download from repository..."
    
    HELPER_URL="https://raw.githubusercontent.com/EcomTree/runpod-comfyui-cloud/main/scripts/common-codex.sh"
    mkdir -p "$SCRIPT_DIR"
    
    if command -v curl >/dev/null 2>&1; then
        if curl -fsSL "$HELPER_URL" -o "$COMMON_HELPERS"; then
            echo "✅ Helper script downloaded successfully"
            # shellcheck source=/dev/null
            source "$COMMON_HELPERS"
        else
            echo "❌ Failed to download helper script from $HELPER_URL"
            exit 1
        fi
    else
        echo "❌ curl not found - cannot download helper script"
        exit 1
    fi
fi

# Validate that logging functions are available
if ! command -v log_info >/dev/null 2>&1; then
    echo "❌ Failed to load helper functions. Setup cannot continue."
    exit 1
fi

# Detect environment
if is_codex_environment; then
    export IN_CODEX=true
else
    export IN_CODEX=false
fi

# Wait for stable connection in Codex
if [ "$IN_CODEX" = true ]; then
    log_info "🔄 Waiting for stable connection..."
    sleep 5
fi

# Main setup function
main() {
    log_info "🚀 Starting $PROJECT_NAME setup v$SCRIPT_VERSION"
    
    if [ "$IN_CODEX" = true ]; then
        log_success "Codex environment detected"
    else
        log_info "Running in standard environment"
    fi
    
    # Setup workspace
    setup_workspace || { log_error "Workspace setup failed"; exit 1; }
    
    # Install system dependencies
    install_system_dependencies || log_warning "Some system dependencies failed to install"
    
    # Setup ComfyUI
    setup_comfyui || { log_error "ComfyUI setup failed"; exit 1; }
    
    # Setup Python environment
    setup_python_environment || { log_error "Python environment setup failed"; exit 1; }
    
    # Download models (if enabled)
    download_models || log_warning "Model download encountered issues"
    
    # Setup services
    setup_services || log_warning "Service setup encountered issues"
    
    # Validate setup
    validate_setup || log_warning "Validation encountered issues"
    
    # Show summary
    show_summary
}

# Setup workspace directory
setup_workspace() {
    log_info "Setting up workspace..."
    
    if [ -d "/workspace" ]; then
        cd /workspace
        WORKSPACE_DIR="/workspace"
        export WORKSPACE_DIR
    else
        if mkdir -p /workspace 2>/dev/null; then
            cd /workspace
            WORKSPACE_DIR="/workspace"
            export WORKSPACE_DIR
        else
            log_warning "Cannot create /workspace, using current directory"
            WORKSPACE_DIR="$(pwd)"
            export WORKSPACE_DIR
        fi
    fi
    
    # Create directory structure
    mkdir -p logs scripts
    
    log_success "Workspace ready: $WORKSPACE_DIR"
}

# Install system dependencies
install_system_dependencies() {
    log_info "Installing system dependencies..."
    
    # Essential packages
    local packages=("wget" "curl" "git" "ffmpeg" "libgl1" "jq")
    
    ensure_system_packages "${packages[@]}" || log_warning "Some packages could not be installed"
    
    log_success "System dependencies ready"
}

# Setup ComfyUI
setup_comfyui() {
    log_info "Setting up ComfyUI..."
    
    # Clone ComfyUI if not exists
    if [ ! -d "$WORKSPACE_DIR/ComfyUI" ]; then
        log_info "Cloning ComfyUI repository..."
        if retry git clone "$COMFYUI_REPO" "$WORKSPACE_DIR/ComfyUI"; then
            log_success "ComfyUI cloned successfully"
        else
            log_error "Failed to clone ComfyUI"
            exit 1
        fi
    else
        log_info "ComfyUI already exists, updating..."
        cd "$WORKSPACE_DIR/ComfyUI"
        git pull || log_warning "Could not update ComfyUI"
        cd "$WORKSPACE_DIR"
    fi
    
    # Clone ComfyUI Manager if not exists
    if [ ! -d "$WORKSPACE_DIR/ComfyUI/custom_nodes/ComfyUI-Manager" ]; then
        log_info "Installing ComfyUI Manager..."
        mkdir -p "$WORKSPACE_DIR/ComfyUI/custom_nodes"
        if retry git clone "$COMFYUI_MANAGER_REPO" "$WORKSPACE_DIR/ComfyUI/custom_nodes/ComfyUI-Manager"; then
            log_success "ComfyUI Manager installed"
        else
            log_warning "Could not install ComfyUI Manager"
        fi
    else
        log_info "ComfyUI Manager already installed"
    fi
    
    # Create model directory structure
    local model_dirs=("checkpoints" "vae" "loras" "controlnet" "upscale_models" "unet" "clip" "t5" "clip_vision" "embeddings" "hypernetworks" "style_models")
    
    for dir in "${model_dirs[@]}"; do
        mkdir -p "$WORKSPACE_DIR/ComfyUI/models/$dir"
        # Create README file explaining the directory's purpose
        echo "Place your ${dir} model files here." > "$WORKSPACE_DIR/ComfyUI/models/$dir/README.txt"
    done
    
    # Create other directories
    mkdir -p "$WORKSPACE_DIR/ComfyUI/input"
    mkdir -p "$WORKSPACE_DIR/ComfyUI/output"
    mkdir -p "$WORKSPACE_DIR/ComfyUI/temp"
    
    log_success "ComfyUI setup complete"
}

# Setup Python environment
setup_python_environment() {
    log_info "Setting up Python environment..."
    
    # Check Python version
    if ! command_exists python3; then
        log_error "Python 3 is not installed"
        exit 1
    fi
    
    local python_version
    python_version=$(python3 --version 2>&1 | awk '{print $2}')
    log_info "Python version: $python_version"
    
    # Upgrade pip
    log_info "Upgrading pip..."
    python3 -m pip install --quiet --upgrade pip setuptools wheel || log_warning "Could not upgrade pip"
    
    # Install ComfyUI requirements
    if [ -f "$WORKSPACE_DIR/ComfyUI/requirements.txt" ]; then
        log_info "Installing ComfyUI requirements..."
        cd "$WORKSPACE_DIR/ComfyUI"
        if retry python3 -m pip install --no-cache-dir -r requirements.txt; then
            log_success "ComfyUI requirements installed"
        else
            log_error "Failed to install ComfyUI requirements"
            exit 1
        fi
        cd "$WORKSPACE_DIR"
    else
        log_warning "ComfyUI requirements.txt not found"
    fi
    
    # Install additional packages
    log_info "Installing additional packages..."
    python3 -m pip install --quiet --no-cache-dir jupyter jupyterlab || log_warning "Could not install Jupyter"
    
    # Check GPU support
    check_gpu_requirements || log_warning "GPU check failed - ComfyUI may not work properly"
    
    log_success "Python environment ready"
}

# Download models
download_models() {
    local download_enabled="${DOWNLOAD_MODELS:-true}"
    
    if [ "$download_enabled" != "true" ]; then
        log_info "Model download disabled (DOWNLOAD_MODELS=$download_enabled)"
        return 0
    fi
    
    log_info "Starting model download..."
    
    # Clone project repo if download script exists there
    if [ ! -f "$WORKSPACE_DIR/scripts/download_models.py" ]; then
        log_info "Downloading model download script..."
        mkdir -p "$WORKSPACE_DIR/scripts"
        
        local download_script_url="https://raw.githubusercontent.com/EcomTree/runpod-comfyui-cloud/main/scripts/download_models.py"
        if curl -fsSL "$download_script_url" -o "$WORKSPACE_DIR/scripts/download_models.py"; then
            log_success "Download script retrieved"
        else
            log_warning "Could not download model script - skipping model download"
            return 0
        fi
    fi
    
    # Run model download script
    if [ -f "$WORKSPACE_DIR/scripts/download_models.py" ]; then
        log_info "Running model download script..."
        cd "$WORKSPACE_DIR"
        
        # Set HF_TOKEN if available
        if [ -n "${HF_TOKEN:-}" ]; then
            export HF_TOKEN="$HF_TOKEN"
            log_info "Using provided HF_TOKEN"
        fi
        
        # Run download in background and log output
        python3 scripts/download_models.py > "$WORKSPACE_DIR/logs/model_download.log" 2>&1 &
        MODEL_DOWNLOAD_PID=$!
        
        # Briefly wait and check if process started successfully
        sleep 1
        if ! kill -0 "$MODEL_DOWNLOAD_PID" 2>/dev/null; then
            log_error "Model download process failed to start (PID: $MODEL_DOWNLOAD_PID)."
            log_error "Last 10 lines of log:"
            tail -n 10 "$WORKSPACE_DIR/logs/model_download.log" || true
            MODEL_DOWNLOAD_PID=""
            return 1
        fi
        
        log_info "Model download started (PID: $MODEL_DOWNLOAD_PID)"
        log_info "Monitor progress: tail -f $WORKSPACE_DIR/logs/model_download.log"
        
        # Set up trap to clean up background process on interruption only
        # Note: We don't trap EXIT to allow the process to continue after script completes
        trap cleanup_model_download INT TERM
        
        # Don't wait for download to complete - let it run in background
        log_success "Model download running in background"
    else
        log_warning "Model download script not found - skipping"
    fi
}

# Setup services
setup_services() {
    log_info "Setting up services..."
    
    # Create startup script for ComfyUI
    cat > "$WORKSPACE_DIR/start_comfyui.sh" <<EOF
#!/bin/bash
cd "$WORKSPACE_DIR/ComfyUI"
python3 main.py --listen 0.0.0.0 --port \${COMFYUI_PORT:-8188} > "$WORKSPACE_DIR/logs/comfyui.log" 2>&1
EOF
    chmod +x "$WORKSPACE_DIR/start_comfyui.sh"
    
    # Create startup script for Jupyter
    cat > "$WORKSPACE_DIR/start_jupyter.sh" <<EOF
#!/bin/bash
jupyter lab --ip=0.0.0.0 --port=\${JUPYTER_PORT:-8888} --no-browser --allow-root \\
    --NotebookApp.token='' --NotebookApp.password='' \\
    --notebook-dir="$WORKSPACE_DIR" > "$WORKSPACE_DIR/logs/jupyter.log" 2>&1
EOF
    chmod +x "$WORKSPACE_DIR/start_jupyter.sh"
    
    # Start services if in Codex
    if [ "$IN_CODEX" = true ]; then
        log_info "Starting services..."
        
        # Start ComfyUI
        nohup "$WORKSPACE_DIR/start_comfyui.sh" &
        log_success "ComfyUI started on port ${COMFYUI_PORT:-8188}"
        
        # Start Jupyter
        nohup "$WORKSPACE_DIR/start_jupyter.sh" &
        log_success "Jupyter Lab started on port ${JUPYTER_PORT:-8888}"
        
        # Wait a bit for services to start
        sleep 5
    else
        log_info "Service scripts created (not auto-starting outside Codex)"
    fi
    
    log_success "Services configured"
}

# Validate setup
validate_setup() {
    log_info "Validating setup..."
    
    local validation_passed=true
    
    # Check ComfyUI directory
    if [ -d "$WORKSPACE_DIR/ComfyUI" ]; then
        log_success "✓ ComfyUI directory"
    else
        log_error "✗ ComfyUI directory missing"
        validation_passed=false
    fi
    
    # Check main.py
    if [ -f "$WORKSPACE_DIR/ComfyUI/main.py" ]; then
        log_success "✓ ComfyUI main.py"
    else
        log_error "✗ ComfyUI main.py missing"
        validation_passed=false
    fi
    
    # Check model directories
    local essential_dirs=("checkpoints" "vae" "loras")
    for dir in "${essential_dirs[@]}"; do
        if [ -d "$WORKSPACE_DIR/ComfyUI/models/$dir" ]; then
            log_success "✓ models/$dir"
        else
            log_warning "✗ models/$dir missing"
        fi
    done
    
    # Check Python packages
    if python3 -c "import torch" 2>/dev/null; then
        log_success "✓ PyTorch installed"
    else
        log_error "✗ PyTorch not found"
        validation_passed=false
    fi
    
    # Check services (if in Codex)
    if [ "$IN_CODEX" = true ]; then
        # Check ComfyUI with robust wait mechanism
        if wait_for_service "http://localhost:${COMFYUI_PORT:-8188}${COMFYUI_QUEUE_ENDPOINT}" "ComfyUI API" 30 2; then
            log_success "✓ ComfyUI API responding"
        else
            log_warning "✗ ComfyUI API not responding yet (may need more time)"
        fi
        
        # Check Jupyter with robust wait mechanism
        if wait_for_service "http://localhost:${JUPYTER_PORT:-8888}${JUPYTER_ROOT_ENDPOINT}" "Jupyter Lab" 30 2; then
            log_success "✓ Jupyter Lab responding"
        else
            log_warning "✗ Jupyter Lab not responding yet (may need more time)"
        fi
    fi
    
    if [ "$validation_passed" = true ]; then
        log_success "Setup validation passed"
    else
        log_warning "Setup validation completed with warnings"
    fi
}

# Show summary
show_summary() {
    echo
    log_success "✨ Setup completed successfully!"
    echo
    log_info "📋 Environment Summary:"
    echo "   ├─ Workspace: $WORKSPACE_DIR"
    echo "   ├─ ComfyUI: $WORKSPACE_DIR/ComfyUI"
    echo "   ├─ Python: $(python3 --version 2>&1 | awk '{print $2}')"
    echo "   ├─ PyTorch: $(python3 -c 'import torch; print(torch.__version__)' 2>/dev/null || echo 'Not installed')"
    echo "   ├─ CUDA: $(python3 -c 'import torch; print(torch.version.cuda if torch.cuda.is_available() else "Not available")' 2>/dev/null || echo 'N/A')"
    echo
    
    if [ "$IN_CODEX" = true ]; then
        log_info "🌐 Services:"
        echo "   ├─ ComfyUI: http://localhost:${COMFYUI_PORT:-8188}"
        echo "   └─ Jupyter Lab: http://localhost:${JUPYTER_PORT:-8888}"
        echo
    fi
    
    log_info "📝 Useful Commands:"
    echo "   ├─ View ComfyUI logs: tail -f $WORKSPACE_DIR/logs/comfyui.log"
    echo "   ├─ View Jupyter logs: tail -f $WORKSPACE_DIR/logs/jupyter.log"
    echo "   ├─ View model download: tail -f $WORKSPACE_DIR/logs/model_download.log"
    echo "   ├─ Restart ComfyUI: $WORKSPACE_DIR/start_comfyui.sh"
    echo "   └─ Restart Jupyter: $WORKSPACE_DIR/start_jupyter.sh"
    echo
    
    if [ "$IN_CODEX" = true ]; then
        log_info "💡 Codex Tips:"
        echo "   • Enable 'Container Caching' for faster restarts"
        echo "   • Set HF_TOKEN env var for gated models"
        echo "   • Use network storage for persistent models"
        echo
    fi
    
    log_success "🎉 Environment is ready!"
}

# Run main function
main "$@"

