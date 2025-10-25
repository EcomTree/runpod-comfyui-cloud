#!/bin/bash
cd "/workspace/ComfyUI"
python3 main.py --listen 0.0.0.0 --port ${COMFYUI_PORT:-8188} > "/workspace/logs/comfyui.log" 2>&1
