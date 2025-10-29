#!/bin/bash
#
# Get Latest ComfyUI Version
# Fetches the latest release tag from GitHub API with fallback to master branch
#
# Usage:
#   COMFYUI_VERSION=$(./scripts/get_latest_version.sh)
#   echo "Using version: $COMFYUI_VERSION"
#
# Environment variables:
#   COMFYUI_VERSION: Override to pin a specific version (e.g., "v0.3.67" or "master")
#   GITHUB_API_TIMEOUT: Timeout for API requests (default: 10 seconds)
#

set -euo pipefail

# Configuration
COMFYUI_REPO="comfyanonymous/ComfyUI"
GITHUB_API_URL="https://api.github.com/repos/${COMFYUI_REPO}/releases/latest"
TIMEOUT="${GITHUB_API_TIMEOUT:-10}"

# If version is explicitly set via environment variable, use it
if [ -n "${COMFYUI_VERSION:-}" ]; then
    echo "ℹ️  Using pinned version from COMFYUI_VERSION: ${COMFYUI_VERSION}" >&2
    echo "${COMFYUI_VERSION}"
    exit 0
fi

# Function to fetch latest release tag from GitHub API
fetch_latest_tag() {
    local tag
    
    # Check if curl is available
    if ! command -v curl >/dev/null 2>&1; then
        echo "⚠️  curl not found, falling back to master branch" >&2
        echo "master"
        return 0
    fi
    
    # Try to fetch latest release tag
    if tag=$(curl -sfL --max-time "${TIMEOUT}" "${GITHUB_API_URL}" 2>/dev/null | \
             grep -o '"tag_name": "[^"]*' | \
             head -1 | \
             cut -d'"' -f4); then
        
        if [ -n "${tag}" ]; then
            echo "✅ Latest release tag found: ${tag}" >&2
            echo "${tag}"
            return 0
        fi
    fi
    
    # If API call failed, fall back to master
    echo "⚠️  Failed to fetch latest tag from GitHub API, falling back to master branch" >&2
    echo "master"
    return 0
}

# Get the version
VERSION=$(fetch_latest_tag)

# Validate version format (should start with 'v' or be 'master')
if [[ ! "${VERSION}" =~ ^(v[0-9]+\.[0-9]+\.[0-9]+|master)$ ]]; then
    echo "⚠️  Unexpected version format: ${VERSION}, defaulting to master" >&2
    echo "master"
    exit 0
fi

echo "${VERSION}"

