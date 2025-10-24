#!/bin/bash
# Common helper functions for Codex setup scripts
# Provides shared utilities for RunPod ComfyUI Cloud setup

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
    printf "%b\n" "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    printf "%b\n" "${GREEN}✅ $1${NC}"
}

log_warning() {
    printf "%b\n" "${YELLOW}⚠️  $1${NC}" >&2
}

log_error() {
    printf "%b\n" "${RED}❌ $1${NC}" >&2
}

# Alias functions for compatibility with echo_* naming convention
echo_info() {
    log_info "$@"
}

echo_success() {
    log_success "$@"
}

echo_warning() {
    log_warning "$@"
}

echo_error() {
    log_error "$@"
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

# Install system packages with retry mechanism
ensure_system_packages() {
    local packages=("$@")
    local missing=()

    for pkg in "${packages[@]}"; do
        if dpkg -s "$pkg" >/dev/null 2>&1; then
            log_success "$pkg available (package present)"
        elif command_exists "$pkg"; then
            log_success "$pkg available (command found)"
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
        if dpkg -s "$pkg" >/dev/null 2>&1; then
            log_success "$pkg installed (package present)"
        elif command_exists "$pkg"; then
            log_success "$pkg installed (command available)"
        else
            log_warning "$pkg installation failed"
        fi
    done
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

fi  # End of CODEX_COMMON_HELPERS_LOADED check
