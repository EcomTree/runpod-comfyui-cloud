#!/bin/bash
# Ensure logs directory exists
mkdir -p "/workspace/logs"

# Security warning: This configuration disables authentication
# WARNING: Only use this in trusted environments (e.g., isolated containers)
# Anyone with network access can execute arbitrary code
echo "WARNING: Jupyter Lab is running without authentication!" >&2
echo "This should only be used in trusted, isolated environments." >&2

# Start Jupyter Lab with disabled authentication
# Note: --allow-root is used for container environments
jupyter lab --ip=0.0.0.0 --port=${JUPYTER_PORT:-8888} --no-browser --allow-root \
    --NotebookApp.token='' --NotebookApp.password='' \
    --notebook-dir="/workspace" > "/workspace/logs/jupyter.log" 2>&1
