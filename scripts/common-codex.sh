#!/bin/bash
# Common helper functions for Codex setup scripts
# Provides shared utilities for RunPod ComfyUI Cloud setup
# Enhanced with features from serverless project

set -eo pipefail

# Prevent multiple loading
if [[ -z "${CODEX_COMMON_HELPERS_LOADED:-}" ]]; then
    CODEX_COMMON_HELPERS_LOADED=1

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# CUDA version requirements
MIN_CUDA_MAJOR=12
MIN_CUDA_MINOR=8

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Retry mechanism for robust operations
retry() {
    local attempt=1
    local exit_code=0
    local max_attempts=${RETRY_ATTEMPTS:-3}
    local delay=${RETRY_DELAY:-2}

    while true; do
        "$@" && return 0
        exit_code=$?

        if (( attempt >= max_attempts )); then
            return "$exit_code"
        fi

        log_warning "Attempt ${attempt}/${max_attempts} failed – retrying in ${delay}s"
        sleep "$delay"
        attempt=$((attempt + 1))
    done
}

# Environment detection
is_codex_environment() {
    [ -n "${CODEX_CONTAINER:-}" ] || \
    [ -n "${RUNPOD_POD_ID:-}" ] || \
    [ -n "${CODEX_WORKSPACE:-}" ] || \
    [ -d "/workspace" ]
}

# Path resolution
resolve_path() {
    local path="$1"
    if [[ -z "$path" ]]; then
        return 1
    fi
    if [[ "$path" == /* ]]; then
        printf '%s\n' "$path"
    else
        printf '%s/%s\n' "$(pwd)" "$path"
    fi
}

# Check if a file exists and is readable
file_exists() {
    [ -f "$1" ] && [ -r "$1" ]
}

# Check if a directory exists and is accessible
dir_exists() {
    [ -d "$1" ] && [ -x "$1" ]
}

# Download a file with error handling
download_file() {
    local url="$1"
    local output="$2"
    local description="${3:-file}"
    
    log_info "Downloading $description from $url..."
    
    if command_exists curl; then
        if curl -fsSL --retry 3 --retry-delay 2 --retry-connrefused "$url" -o "$output"; then
            log_success "Downloaded $description successfully"
            return 0
        else
            log_error "Failed to download $description using curl"
            return 1
        fi
    elif command_exists wget; then
        if wget -q --show-progress --tries=3 --waitretry=2 -O "$output" "$url"; then
            log_success "Downloaded $description successfully"
            return 0
        else
            log_error "Failed to download $description using wget"
            return 1
        fi
    else
        log_error "Neither curl nor wget found. Cannot download $description"
        return 1
    fi
}

# Install system packages with retry mechanism
install_system_packages() {
    local packages=("$@")
    local missing=()

    for pkg in "${packages[@]}"; do
        if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
            log_success "$pkg installed"
        else
            missing+=("$pkg")
        fi
    done

    if (( ${#missing[@]} == 0 )); then
        return 0
    fi

    if ! command_exists apt-get; then
        log_warning "apt-get not available – skipping install for (${missing[*]})"
        return 1
    fi

    if command_exists sudo && sudo -n true 2>/dev/null; then
        log_info "Installing packages via sudo apt-get: ${missing[*]}"
        if retry sudo apt-get update -qq; then
            retry sudo apt-get install -y "${missing[@]}"
        else
            log_warning "apt-get update failed – skipping install for (${missing[*]})"
            return 1
        fi
    elif [ "$(id -u)" -eq 0 ]; then
        log_info "Installing packages with root privileges: ${missing[*]}"
        if retry apt-get update -qq; then
            retry apt-get install -y "${missing[@]}"
        else
            log_warning "apt-get update failed – skipping install for (${missing[*]})"
            return 1
        fi
    else
        log_warning "No sudo privileges – cannot install packages (${missing[*]})"
        return 1
    fi

    for pkg in "${missing[@]}"; do
        if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
            log_success "$pkg installed"
        else
            log_warning "$pkg installation failed"
        fi
    done
}

# Verify system requirements
check_system_requirements() {
    log_info "Checking system requirements..."
    
    local missing_deps=()
    
    # Check for required commands
    local required_commands=("python3" "git")
    
    # Check for pip (pip3 on macOS, pip on Linux)
    if ! command_exists "pip" && ! command_exists "pip3"; then
        missing_deps+=("pip")
    fi
    for cmd in "${required_commands[@]}"; do
        if ! command_exists "$cmd"; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_info "Please install the missing dependencies and try again"
        return 1
    fi
    
    log_success "All system requirements met"
    return 0
}

# Setup Python virtual environment
setup_python_env() {
    local venv_path="$1"
    local requirements_file="${2:-requirements.txt}"
    
    log_info "Setting up Python virtual environment at $venv_path..."
    
    if [ -d "$venv_path" ]; then
        log_warning "Virtual environment already exists at $venv_path"
        if file_exists "$requirements_file"; then
            log_info "Upgrading requirements in existing venv..."
            "$venv_path/bin/pip" install -r "$requirements_file"
        fi
        return 0
    fi
    
    if python3 -m venv "$venv_path"; then
        log_success "Created virtual environment at $venv_path"
        
        # Activate and install requirements if file exists
        if file_exists "$requirements_file"; then
            log_info "Installing requirements from $requirements_file..."
            if "$venv_path/bin/pip" install -r "$requirements_file"; then
                log_success "Requirements installed successfully"
            else
                log_error "Failed to install requirements – environment is incomplete"
                return 1
            fi
        fi
        
        return 0
    else
        log_error "Failed to create virtual environment at $venv_path"
        return 1
    fi
}

# Clone repository with error handling
clone_repository() {
    local repo_url="$1"
    local target_dir="$2"
    local branch="${3:-main}"
    
    log_info "Cloning repository $repo_url to $target_dir..."
    
    if [ -d "$target_dir" ]; then
        log_warning "Directory $target_dir already exists"
        return 0
    fi
    
    if git clone --depth 1 --branch "$branch" "$repo_url" "$target_dir"; then
        log_success "Repository cloned successfully"
        return 0
    else
        log_error "Failed to clone repository $repo_url"
        return 1
    fi
}

# Check GPU availability and CUDA version
check_gpu_requirements() {
    log_info "Checking GPU requirements..."
    
    if command_exists nvidia-smi; then
        local driver_version
        driver_version=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader,nounits | head -1)
        
        if [ -n "$driver_version" ]; then
            log_success "NVIDIA GPU detected with driver version $driver_version"
            
            # Try to check CUDA version with torch if available
            if command_exists python3; then
                local cuda_check_result
                cuda_check_result=$(python3 -c "
try:
    import torch
    if torch.cuda.is_available():
        cuda_version = torch.version.cuda
        if cuda_version:
            print(f'CUDA_{cuda_version}')
        else:
            print('CUDA_NONE')
    else:
        print('CUDA_NOT_AVAILABLE')
except ImportError:
    print('TORCH_NOT_INSTALLED')
except Exception as e:
    print(f'ERROR_{e}')
" 2>/dev/null)
                
                case "$cuda_check_result" in
                    CUDA_*)
                        local cuda_ver="${cuda_check_result#CUDA_}"
                        if [ "$cuda_ver" = "NONE" ] || [ "$cuda_ver" = "NOT_AVAILABLE" ]; then
                            log_warning "CUDA not available in torch"
                            return 1
                        else
                            log_success "CUDA version detected: $cuda_ver"
                            # Validate and parse major.minor version for comparison using regex
                            # Example valid CUDA version strings: "12.1", "11.8", "12.8"
                            if [[ "$cuda_ver" =~ ^([0-9]+)\.([0-9]+) ]]; then
                                local major="${BASH_REMATCH[1]}"
                                local minor="${BASH_REMATCH[2]}"
                                
                                # Check if version meets minimum requirements
                                if [ "$major" -gt "$MIN_CUDA_MAJOR" ] || { [ "$major" -eq "$MIN_CUDA_MAJOR" ] && [ "$minor" -ge "$MIN_CUDA_MINOR" ]; }; then
                                    log_success "CUDA version is compatible (>= ${MIN_CUDA_MAJOR}.${MIN_CUDA_MINOR})"
                                    return 0
                                else
                                    log_warning "CUDA version $cuda_ver is below recommended ${MIN_CUDA_MAJOR}.${MIN_CUDA_MINOR}+"
                                    return 0  # Don't fail, just warn
                                fi
                            else
                                log_warning "CUDA version format is invalid: $cuda_ver"
                                return 0  # Don't fail, just warn
                            fi
                        fi
                        ;;
                    TORCH_NOT_INSTALLED)
                        log_warning "PyTorch not installed - cannot verify CUDA runtime version"
                        log_info "Driver version $driver_version detected, assuming compatible"
                        return 0  # Don't fail if torch not available
                        ;;
                    ERROR_*)
                        log_warning "Error checking CUDA version: ${cuda_check_result#ERROR_}"
                        return 0  # Don't fail on check errors
                        ;;
                    *)
                        log_warning "Unexpected CUDA check result: $cuda_check_result"
                        return 0
                        ;;
                esac
            else
                log_warning "Python not available - cannot verify CUDA runtime version"
                return 0  # Don't fail if python not available
            fi
        else
            log_error "Could not determine GPU driver version"
            return 1
        fi
    else
        log_warning "nvidia-smi not found - GPU requirements cannot be verified"
        return 1
    fi
}

# Create directory structure
create_directory_structure() {
    local base_dir="$1"
    local dirs=("models" "models/checkpoints" "models/vae" "models/loras" "models/controlnet" "models/upscale_models" "custom_nodes" "output")
    
    log_info "Creating directory structure in $base_dir..."
    
    for dir in "${dirs[@]}"; do
        local full_path="$base_dir/$dir"
        if ! dir_exists "$full_path"; then
            if mkdir -p "$full_path"; then
                log_success "Created directory: $full_path"
            else
                log_error "Failed to create directory: $full_path"
                return 1
            fi
        else
            log_info "Directory already exists: $full_path"
        fi
    done
    
    return 0
}

# Validate environment variables
validate_env_vars() {
    local required_vars=("$@")
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        log_error "Missing required environment variables: ${missing_vars[*]}"
        return 1
    fi
    
    return 0
}

# Wait for service to be ready
wait_for_service() {
    local url="$1"
    local service_name="${2:-service}"
    local max_attempts="${3:-30}"
    local delay="${4:-10}"
    
    log_info "Waiting for $service_name to be ready at $url..."
    
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        if curl -sSf --connect-timeout 2 --max-time 5 "$url" >/dev/null 2>&1; then
            log_success "$service_name is ready!"
            return 0
        fi
        
        log_info "Attempt $attempt/$max_attempts: $service_name not ready yet, waiting ${delay}s..."
        sleep $delay
        ((attempt++))
    done
    
    log_error "$service_name failed to start within $((max_attempts * delay)) seconds"
    return 1
}

# Cleanup function for trap
cleanup() {
    log_info "Cleaning up..."
    # Add any cleanup logic here
}

# Set up signal handlers
setup_signal_handlers() {
    trap cleanup EXIT INT TERM
}

# Main initialization function
init_codex_environment() {
    log_info "Initializing Codex environment..."
    
    # Set up signal handlers
    setup_signal_handlers
    
    # Check system requirements
    if ! check_system_requirements; then
        log_error "System requirements check failed"
        exit 1
    fi
    
    log_success "Codex environment initialized successfully"
}

# Export functions for use in other scripts
export -f log_info log_success log_warning log_error
export -f command_exists file_exists dir_exists
export -f retry is_codex_environment resolve_path
export -f download_file install_system_packages check_system_requirements setup_python_env
export -f clone_repository check_gpu_requirements create_directory_structure
export -f validate_env_vars wait_for_service cleanup setup_signal_handlers
export -f init_codex_environment

fi  # End of CODEX_COMMON_HELPERS_LOADED check

# If script is executed directly, run initialization
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    init_codex_environment
fi
