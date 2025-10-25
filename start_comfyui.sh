#!/bin/bash
# Ensure logs directory exists
mkdir -p "/workspace/logs"

# Change to ComfyUI directory with error handling
cd "/workspace/ComfyUI" || {
    echo "Error: Cannot access /workspace/ComfyUI directory" >&2
    exit 1
}

# Start ComfyUI with logging
python3 main.py --listen 0.0.0.0 --port ${COMFYUI_PORT:-8188} > "/workspace/logs/comfyui.log" 2>&1
