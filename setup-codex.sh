#!/bin/bash
#
# Optimized Codex Setup Script for RunPod ComfyUI Cloud Pod
# This script sets up the Codex environment for ComfyUI development
# with improved error handling, validation, and Codex-specific optimizations
#
# Version: 4.1 (ComfyUI Cloud Pod Edition)
#

# Resolve script directory and load shared helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_HELPERS="${SCRIPT_DIR}/scripts/common-codex.sh"

if [ -f "$COMMON_HELPERS" ]; then
    # shellcheck disable=SC1090
    source "$COMMON_HELPERS"
else
    # Fallback: Try to download helper from repository if not present
    echo "⚠️  Missing helper script: $COMMON_HELPERS" >&2
    echo "ℹ️  Attempting to download from repository..." >&2
    
    HELPER_URL="https://raw.githubusercontent.com/EcomTree/runpod-comfyui-cloud/main/scripts/common-codex.sh"
    mkdir -p "${SCRIPT_DIR}/scripts"
    
    if command -v curl >/dev/null 2>&1; then
        if curl -fsSL "$HELPER_URL" -o "$COMMON_HELPERS" 2>/dev/null; then
            echo "✅ Helper script downloaded successfully" >&2
            # shellcheck disable=SC1090
            source "$COMMON_HELPERS"
        else
            echo "❌ Failed to download helper script from $HELPER_URL" >&2
            echo "ℹ️  Please ensure the repository is cloned or the helper script exists" >&2
            exit 1
        fi
    elif command -v wget >/dev/null 2>&1; then
        if wget -qO "$COMMON_HELPERS" "$HELPER_URL" 2>/dev/null; then
            echo "✅ Helper script downloaded successfully" >&2
            # shellcheck disable=SC1090
            source "$COMMON_HELPERS"
        else
            echo "❌ Failed to download helper script from $HELPER_URL" >&2
            echo "ℹ️  Please ensure the repository is cloned or the helper script exists" >&2
            exit 1
        fi
    else
        echo "❌ Neither curl nor wget available to download helper script" >&2
        echo "ℹ️  Please install curl or wget, or clone the full repository" >&2
        exit 1
    fi
fi

# Detect Codex environment early
if is_codex_environment; then
    export IN_CODEX=true
else
    export IN_CODEX=false
fi

# Add connection stability check
if [ "$IN_CODEX" = true ]; then
    echo_info "🔄 Waiting for stable connection..."
    sleep 2
fi

# Use strict mode, but in Codex environments use only a single '-e' flag.
# This makes error handling slightly more predictable in containerized environments,
# as duplicate '-e' flags have no effect in bash, but the single flag avoids subtle issues.
if [ "$IN_CODEX" = true ]; then
    set -Euo pipefail
    trap 'echo -e "${RED}❌ Error on line ${BASH_LINENO[0]}${NC}"' ERR
else
    set -Eeuo pipefail
    trap 'echo -e "${RED}❌ Error on line ${BASH_LINENO[0]}${NC}"' ERR
fi

# Optional Logging
if [[ -n "${LOG_FILE:-}" ]]; then
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    exec > >(tee -a "$LOG_FILE") 2>&1
    echo_info "📜 Logging to $LOG_FILE"
fi

RETRY_ATTEMPTS=${RETRY_ATTEMPTS:-3}
RETRY_DELAY=${RETRY_DELAY:-2}
PYTHON_CMD=python3

# Python packages to install and validate (minimal for development tools)
PYTHON_PACKAGES=("requests")
PYTHON_IMPORT_NAMES=("requests")

REPO_BASENAME="runpod-comfyui-cloud"
if [[ "$(basename "$SCRIPT_DIR")" == "$REPO_BASENAME" ]]; then
    PREEXISTING_REPO=true
else
    PREEXISTING_REPO=false
fi

# Function: Check Python version
check_python_version() {
    local required_major=3
    local required_minor=11

    if ! command_exists "$PYTHON_CMD"; then
        echo_error "Python 3 is not installed"
        return 1
    fi

    local version=$($PYTHON_CMD --version 2>&1 | awk '{print $2}')
    local major=$(echo "$version" | cut -d. -f1)
    local minor=$(echo "$version" | cut -d. -f2)

    echo_info "Python Version: $version"

    # Validate that major and minor are numeric
    if ! [[ "$major" =~ ^[0-9]+$ ]] || ! [[ "$minor" =~ ^[0-9]+$ ]]; then
        echo_warning "Could not parse version numbers from $version"
        return 0
    fi

    if [ "$major" -lt "$required_major" ] || ([ "$major" -eq "$required_major" ] && [ "$minor" -lt "$required_minor" ]); then
        echo_warning "Python $required_major.$required_minor+ recommended, found $version"
        return 0
    fi

    echo_success "Python version check passed"
    return 0
}

# Function to validate Python package installation
validate_python_packages() {
    local all_ok=true
    
    echo_info "Validating Python packages..."
    
    for pkg in "${PYTHON_IMPORT_NAMES[@]}"; do
        if $PYTHON_CMD -c "import $pkg" 2>/dev/null; then
            echo_success "✓ $pkg"
        else
            echo_warning "✗ $pkg not found"
            all_ok=false
        fi
    done
    
    if $all_ok; then
        echo_success "All Python packages validated"
        return 0
    else
        echo_warning "Some packages missing - may cause issues"
        return 1
    fi
}

echo_info "🚀 Starting Codex environment setup for RunPod ComfyUI Cloud Pod..."
echo_info "📝 Script Version: 4.1 (ComfyUI Cloud Pod Edition)"

# Check if we're in a test/container environment
if [ -f "/.dockerenv" ] || [ -n "${CONTAINER_ID:-}" ] || [ -n "${RUNPOD_TEST:-}" ]; then
    echo_warning "📦 Running in container/test environment - some features may be limited"
    export CONTAINER_MODE=true
else
    export CONTAINER_MODE=false
fi

# ============================================================
# 0. Pre-flight Checks
# ============================================================
echo_info "🔍 Running pre-flight checks..."

# Codex environment already detected at script start
if [ "$IN_CODEX" = true ]; then
    echo_success "Codex environment detected"
else
    echo_warning "Not in typical Codex environment - some features may differ"
fi

# Check Python version
check_python_version || {
    echo_warning "Python version check failed - continuing anyway"
}

# ============================================================
# 1. Create Workspace Directory
# ============================================================
echo_info "📁 Creating workspace structure..."
if $PREEXISTING_REPO; then
    WORKSPACE_DIR="$(dirname "$SCRIPT_DIR")"
    cd "$WORKSPACE_DIR"
    echo_success "Workspace ready (existing repo): $(pwd)"
else
    if mkdir -p /workspace 2>/dev/null; then
        cd /workspace
        WORKSPACE_DIR="/workspace"
    else
        echo_warning "Could not create /workspace - using current directory"
        WORKSPACE_DIR="$(pwd)"
    fi
    echo_success "Workspace ready: $(pwd)"
fi

# ============================================================
# 2. Clone Repository (if not present)
# ============================================================
if $PREEXISTING_REPO; then
    REPO_DIR="$SCRIPT_DIR"
else
    REPO_DIR="${WORKSPACE_DIR}/${REPO_BASENAME}"
fi

if $PREEXISTING_REPO; then
    echo_info "📦 Existing repository detected at $REPO_DIR"
    cd "$REPO_DIR"
elif [ ! -d "$REPO_DIR" ]; then
echo_info "📦 Cloning repository..."
GIT_CLONE_LOG="$(mktemp /tmp/git-clone.XXXXXX.log)"
# Use timeout and shallow clone for faster operation with retries
if retry bash -c "timeout 60s git clone --depth 1 https://github.com/EcomTree/runpod-comfyui-cloud.git '$REPO_DIR' >'$GIT_CLONE_LOG' 2>&1"; then
    rm -f "$GIT_CLONE_LOG"
    cd "$REPO_DIR"
    echo_success "Repository cloned"
else
    echo_error "Git clone failed"
    if [ -s "$GIT_CLONE_LOG" ]; then
        echo_warning "Details:" && cat "$GIT_CLONE_LOG"
    fi
    rm -f "$GIT_CLONE_LOG"
    # Exit unless in container mode or Codex environment
    if [ "$CONTAINER_MODE" != "true" ] && [ "$IN_CODEX" != "true" ]; then
        exit 1
    fi
    echo_warning "Continuing without repository (container/Codex mode)"
fi
elif [ -d "$REPO_DIR" ]; then
    echo_warning "Repository already exists, skipping clone"
    cd "$REPO_DIR"
fi

# ============================================================
# 3. Git Branch Management
# ============================================================
# Only run git commands if we're actually in a git repository
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
    echo_info "🌿 Current branch: $CURRENT_BRANCH"

    GIT_FETCH_LOG="$(mktemp /tmp/git-fetch.XXXXXX.log)"
    GIT_PULL_LOG="$(mktemp /tmp/git-pull.XXXXXX.log)"

    # Fetch latest changes (gracefully handle network errors)
    # Add timeout to prevent hanging on network issues
    if retry bash -c "timeout 30s git fetch origin >'$GIT_FETCH_LOG' 2>&1"; then
        echo_success "Fetched latest changes from origin"
        
        # Try to update current branch if tracking remote
        if git status --short --porcelain | grep -q ""; then
            echo_warning "Local changes present – skipping git pull"
            echo_info "Run 'git status' to see changes"
        else
            # Only pull if we have a tracking branch
            if git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
                if retry bash -c "timeout 30s git pull --ff-only >'$GIT_PULL_LOG' 2>&1"; then
                    echo_success "Branch $CURRENT_BRANCH successfully updated"
                else
                    echo_info "Could not fast-forward – manual merge may be needed"
                fi
            else
                echo_info "No upstream tracking branch configured"
            fi
        fi
    else
        echo_info "Fetch from origin skipped (no network or not needed)"
        # Not a warning - this is expected in test environments
    fi
    rm -f "$GIT_FETCH_LOG" "$GIT_PULL_LOG"
else
    echo_info "🌿 Not in a git repository – skipping git branch management"
fi
# ============================================================
# 4. Python Environment Setup (with venv)
# ============================================================
echo_info "🐍 Setting up Python environment..."

if [ -f ".venv/bin/activate" ]; then
    echo_info "Reusing existing virtual environment"
else
    echo_info "Creating virtual environment (.venv)"
    retry "$PYTHON_CMD" -m venv .venv
fi

source .venv/bin/activate
PYTHON_CMD="$(command -v python)"

echo_success "Virtual environment active: $PYTHON_CMD"

echo_info "Upgrading pip, setuptools, wheel..."
retry "$PYTHON_CMD" -m pip install --quiet --upgrade pip setuptools wheel 2>&1 \
    | grep -v "^Requirement already satisfied" || true

echo_info "📦 Installing Python dependencies..."
echo_info "Installing development tools: ${PYTHON_PACKAGES[*]}"
retry "$PYTHON_CMD" -m pip install --quiet --no-cache-dir \
    "${PYTHON_PACKAGES[@]}" 2>&1 \
    | grep -v "^Requirement already satisfied\|^Using cached" || true

validate_python_packages || {
    echo_warning "Package validation failed - some functionality may be limited"
}

# ============================================================
# 5. System Tools (optional - graceful degradation)
# ============================================================
echo_info "🔧 Ensuring system tools (optional)..."
# Note: 'docker' package is not included because it does not exist on Debian/Ubuntu systems.
# If Docker is needed, install 'docker.io' instead. Docker installation was intentionally omitted.
ensure_system_packages jq curl git || echo_info "Some system tools could not be installed (non-critical)"

# ============================================================
# 6. Environment Variables Setup
# ============================================================
echo_info "🌍 Configuring environment variables..."

# Create .env.example template if not present
if [ ! -f ".env.example" ]; then
    cat > .env.example << 'EOF'
# ComfyUI Configuration
COMFY_PORT=8188
COMFY_HOST=0.0.0.0

# Jupyter Lab Configuration
JUPYTER_PORT=8888
JUPYTER_HOST=0.0.0.0

# GPU Optimization
PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:1024,expandable_segments:True
TORCH_ALLOW_TF32_CUBLAS_OVERRIDE=1

# ComfyUI Launch Parameters
COMFY_VRAM_MODE=highvram
COMFY_PREVIEW_METHOD=auto

# Network Volume (if available)
RUNPOD_VOLUME_PATH=/runpod-volume

# Development
DEBUG=false
EOF
    echo_success ".env.example created"
else
    echo_success ".env.example already exists"
fi

# Create .env from .env.example if it doesn't exist
if [ ! -f ".env" ]; then
    echo_info "Creating .env from .env.example"
    cp .env.example .env
    echo_success ".env file created"
fi

# ============================================================
# 7. Output Directory Structure
# ============================================================
echo_info "📂 Creating output directories..."

mkdir -p "${WORKSPACE_DIR}/outputs" 2>/dev/null || echo_warning "Could not create /workspace/outputs"
mkdir -p "${WORKSPACE_DIR}/logs" 2>/dev/null || echo_warning "Could not create /workspace/logs"

# Network Volume - may or may not exist in Codex
if [ -d "/runpod-volume" ]; then
    echo_success "Network Volume detected: /runpod-volume"
else
    echo_info "📦 Network Volume not detected (optional)"
fi

echo_success "Directory structure created"

# ============================================================
# 8. Make Scripts Executable
# ============================================================
echo_info "🔧 Making scripts executable..."

if [ -d "scripts" ]; then
    chmod +x scripts/*.sh 2>/dev/null || echo_info "No shell scripts in scripts/ folder"
    chmod +x scripts/*.py 2>/dev/null || echo_info "No Python scripts to make executable"
    echo_success "Scripts configured"
fi

# ============================================================
# 9. Git Configuration (safe approach)
# ============================================================
echo_info "🔧 Configuring Git..."

# Only set git config if not already set and if we have write access to git config
if [ -z "$(git config --global user.email 2>/dev/null || true)" ]; then
    if git config --global user.email "${GIT_USER_EMAIL:-codex@runpod.io}" 2>/dev/null; then
        echo_success "Git email configured"
    else
        echo_warning "Could not set git email (non-critical)"
    fi
fi

if [ -z "$(git config --global user.name 2>/dev/null || true)" ]; then
    if git config --global user.name "${GIT_USER_NAME:-Codex User}" 2>/dev/null; then
        echo_success "Git name configured"
    else
        echo_warning "Could not set git name (non-critical)"
    fi
fi

if git config --global init.defaultBranch main 2>/dev/null; then
    echo_success "Git default branch configured"
else
    echo_warning "Could not set git default branch (non-critical)"
fi

# ============================================================
# 10. Validation & Health Check
# ============================================================
echo ""
echo_info "🏥 Running health checks..."

echo_info "🔎 Static analysis"

# Check if all required files exist
REQUIRED_FILES=("Dockerfile" "README.md" "scripts/download_models.py" "scripts/build.sh")
all_files_ok=true

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo_success "✓ $file"
    else
        echo_warning "✗ $file missing"
        all_files_ok=false
    fi
done

# Check Dockerfile syntax
if [ -f "Dockerfile" ]; then
    if grep -q "FROM" Dockerfile && grep -q "WORKDIR" Dockerfile; then
        echo_success "✓ Dockerfile syntax looks good"
    else
        echo_warning "✗ Dockerfile might be incomplete"
    fi
fi

# Check Python scripts syntax
if [ -f "scripts/download_models.py" ]; then
    if $PYTHON_CMD -m py_compile scripts/download_models.py 2>/dev/null; then
        echo_success "✓ download_models.py syntax valid"
    else
        echo_warning "✗ download_models.py has syntax issues"
    fi
fi

if [ -f "scripts/test_setup.py" ]; then
    if $PYTHON_CMD -m py_compile scripts/test_setup.py 2>/dev/null; then
        echo_success "✓ test_setup.py syntax valid"
    else
        echo_warning "✗ test_setup.py has syntax issues"
    fi
fi

# ============================================================
# 11. Final Summary
# ============================================================
# Cache version results to avoid repeated execution
PYTHON_VERSION="$($PYTHON_CMD --version 2>&1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1 || echo 'N/A')"
PIP_VERSION="$($PYTHON_CMD -m pip --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1 || echo 'N/A')"
DOCKER_VERSION="$(docker --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1 || echo 'not available')"
NODE_VERSION="$(node --version 2>/dev/null || echo 'not detected')"
JQ_VERSION="$(jq --version 2>/dev/null || echo 'not available')"
CURL_VERSION="$(curl --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1 || echo 'not available')"
GIT_VERSION="$(git --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1 || echo 'not available')"

echo ""
echo_success "✨ Setup completed successfully!"
echo ""
echo_info "📋 Environment Summary:"
echo "   ├─ Python: $PYTHON_VERSION"
echo "   ├─ pip: $PIP_VERSION"
echo "   ├─ Docker: $DOCKER_VERSION"
echo "   ├─ Node.js: $NODE_VERSION"
echo "   ├─ jq: $JQ_VERSION"
echo "   ├─ curl: $CURL_VERSION"
echo "   └─ git: $GIT_VERSION"
echo ""
echo_info "📁 Paths:"
echo "   ├─ Workspace: $(pwd)"
echo "   ├─ Logs: ${WORKSPACE_DIR}/logs"
echo "   ├─ Outputs: ${WORKSPACE_DIR}/outputs"
echo "   ├─ Repo: $REPO_DIR"
echo "   └─ Virtualenv: $(dirname "$PYTHON_CMD")"
echo ""
echo_info "📝 Next steps:"
echo "   1. Review and customize .env file if needed"
echo "   2. Build Docker image: ./scripts/build.sh"
echo "   3. Test locally: ./scripts/test.sh"
echo "   4. Deploy to RunPod: ./scripts/deploy.sh"
echo ""

# Codex-specific tips
if [ "$IN_CODEX" = true ]; then
    echo_info "💡 Codex-specific tips:"
    echo "   • This is a Pod template, not a Serverless endpoint"
    echo "   • ComfyUI will run on port 8188, Jupyter on port 8888"
    echo "   • Network volume recommended for model persistence"
    echo "   • Supports RTX 5090 and H200 GPUs (CUDA 12.8+)"
    echo ""
fi

echo_success "🎉 Codex Environment is ready for ComfyUI development!"
echo ""
