#!/bin/bash
#
# Install ComfyUI Custom Nodes
# Automatically installs all configured custom nodes from configs/custom_nodes.json
#
# Usage:
#   ./scripts/install_custom_nodes.sh [COMFYUI_DIR]
#
# Environment variables:
#   COMFYUI_DIR: Path to ComfyUI installation (default: /workspace/ComfyUI)
#   SKIP_EXISTING: Skip nodes that already exist (default: true)
#

set -euo pipefail

# Configuration
COMFYUI_DIR="${1:-${COMFYUI_DIR:-/workspace/ComfyUI}}"
CUSTOM_NODES_DIR="${COMFYUI_DIR}/custom_nodes"
CONFIG_FILE="${SCRIPT_DIR:-$(dirname "$0")/..}/configs/custom_nodes.json"
SKIP_EXISTING="${SKIP_EXISTING:-true}"
INSTALL_REQUIREMENTS_OVERRIDE="${INSTALL_REQUIREMENTS:-}"
INSTALL_REQUIREMENTS_ONLY="${INSTALL_REQUIREMENTS_ONLY:-false}"
PIP_INSTALL_FLAGS="${PIP_INSTALL_FLAGS:---no-cache-dir}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $*${NC}" >&2
}

log_success() {
    echo -e "${GREEN}✅ $*${NC}" >&2
}

log_warning() {
    echo -e "${YELLOW}⚠️  $*${NC}" >&2
}

log_error() {
    echo -e "${RED}❌ $*${NC}" >&2
}

# Check if jq is available for JSON parsing
if ! command -v jq >/dev/null 2>&1; then
    log_error "jq is required but not installed. Installing..."
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update && apt-get install -y jq
    elif command -v yum >/dev/null 2>&1; then
        yum install -y jq
    else
        log_error "Cannot install jq automatically. Please install it manually."
        exit 1
    fi
fi

# Check if config file exists
if [ ! -f "${CONFIG_FILE}" ]; then
    log_error "Config file not found: ${CONFIG_FILE}"
    log_info "Trying alternative locations..."
    
    # Try alternative locations
    ALTERNATIVE_PATHS=(
        "/opt/runpod/configs/custom_nodes.json"
        "$(dirname "$0")/../configs/custom_nodes.json"
        "./configs/custom_nodes.json"
    )
    
    for alt_path in "${ALTERNATIVE_PATHS[@]}"; do
        if [ -f "${alt_path}" ]; then
            CONFIG_FILE="${alt_path}"
            log_success "Found config file at: ${CONFIG_FILE}"
            break
        fi
    done
    
    if [ ! -f "${CONFIG_FILE}" ]; then
        log_error "Config file not found in any location!"
        exit 1
    fi
fi

# Validate ComfyUI directory
if [ ! -d "${COMFYUI_DIR}" ]; then
    log_error "ComfyUI directory not found: ${COMFYUI_DIR}"
    exit 1
fi

# Create custom_nodes directory if it doesn't exist
mkdir -p "${CUSTOM_NODES_DIR}"

log_info "Installing custom nodes from: ${CONFIG_FILE}"
log_info "Target directory: ${CUSTOM_NODES_DIR}"

# Read and install each custom node
NODE_COUNT=$(jq '.custom_nodes | length' "${CONFIG_FILE}")
log_info "Found ${NODE_COUNT} custom nodes to install"

SUCCESSFUL=0
FAILED=0
SKIPPED=0

# Sort nodes by priority
NODES_JSON=$(jq -c '.custom_nodes | sort_by(.priority) | .[]' "${CONFIG_FILE}")

while IFS= read -r node_json; do
    NODE_NAME=$(echo "${node_json}" | jq -r '.name')
    NODE_REPO=$(echo "${node_json}" | jq -r '.repo')
    NODE_BRANCH=$(echo "${node_json}" | jq -r '.branch // "master"')
    NODE_DESC=$(echo "${node_json}" | jq -r '.description // ""')
    INSTALL_REQUIREMENTS=$(echo "${node_json}" | jq -r '.requirements // true')
    
    if [ -n "${INSTALL_REQUIREMENTS_OVERRIDE}" ]; then
        INSTALL_REQUIREMENTS="${INSTALL_REQUIREMENTS_OVERRIDE}"
    fi
    
    NODE_DIR="${CUSTOM_NODES_DIR}/${NODE_NAME}"
    
    log_info ""
    log_info "Processing: ${NODE_NAME}"
    if [ -n "${NODE_DESC}" ]; then
        log_info "  Description: ${NODE_DESC}"
    fi
    
    if [ "${INSTALL_REQUIREMENTS_ONLY}" = "true" ]; then
        if [ -d "${NODE_DIR}" ]; then
            if [ -f "${NODE_DIR}/requirements.txt" ] && [ "${INSTALL_REQUIREMENTS}" = "true" ]; then
                log_info "  Installing requirements (existing node)..."
                if python3 -m pip install ${PIP_INSTALL_FLAGS} -q -r "${NODE_DIR}/requirements.txt" 2>&1; then
                    log_success "  Requirements installed: ${NODE_NAME}"
                else
                    log_warning "  Failed to install some requirements for: ${NODE_NAME}"
                fi
            else
                log_info "  No requirements to install for: ${NODE_NAME}"
            fi
        else
            log_warning "  Node directory missing, cannot install requirements: ${NODE_NAME}"
        fi
        continue
    fi
    
    # Check if node already exists
    if [ -d "${NODE_DIR}" ]; then
        if [ "${SKIP_EXISTING}" = "true" ]; then
            log_warning "  Already exists, skipping: ${NODE_NAME}"
            SKIPPED=$((SKIPPED + 1))
            continue
        else
            log_info "  Removing existing installation..."
            rm -rf "${NODE_DIR}"
        fi
    fi
    
    # Clone the repository
    log_info "  Cloning from: ${NODE_REPO} (branch: ${NODE_BRANCH})"
    
    if git clone --depth 1 --branch "${NODE_BRANCH}" "${NODE_REPO}" "${NODE_DIR}" 2>&1; then
        log_success "  Cloned successfully: ${NODE_NAME}"
        
        # Install requirements if needed
        if [ "${INSTALL_REQUIREMENTS}" = "true" ] && [ -f "${NODE_DIR}/requirements.txt" ]; then
            log_info "  Installing requirements..."
            if python3 -m pip install ${PIP_INSTALL_FLAGS} -q -r "${NODE_DIR}/requirements.txt" 2>&1; then
                log_success "  Requirements installed: ${NODE_NAME}"
            else
                log_warning "  Failed to install some requirements for: ${NODE_NAME}"
            fi
        fi
        
        SUCCESSFUL=$((SUCCESSFUL + 1))
    else
        log_error "  Failed to clone: ${NODE_NAME}"
        FAILED=$((FAILED + 1))
        
        # Clean up partial installation
        if [ -d "${NODE_DIR}" ]; then
            rm -rf "${NODE_DIR}"
        fi
    fi
    
done <<< "${NODES_JSON}"

# Summary
log_info ""
log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_info "Installation Summary:"
log_success "  Successful: ${SUCCESSFUL}"
log_warning "  Skipped: ${SKIPPED}"
if [ ${FAILED} -gt 0 ]; then
    log_error "  Failed: ${FAILED}"
else
    log_info "  Failed: ${FAILED}"
fi
log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ ${FAILED} -gt 0 ]; then
    exit 1
fi

exit 0

