#!/bin/bash
set -euo pipefail

# Ensure logs directory exists
mkdir -p "/workspace/logs"

# Security check: Require explicit opt-in for disabled authentication
if [ "${JUPYTER_ALLOW_NO_AUTH:-false}" != "true" ]; then
    echo "ERROR: Running Jupyter without authentication is a security risk!" >&2
    echo "Anyone with network access can execute arbitrary code." >&2
    echo "" >&2
    echo "This should ONLY be used in trusted, isolated environments." >&2
    echo "If you understand the risks, set JUPYTER_ALLOW_NO_AUTH=true" >&2
    echo "" >&2
    echo "Example: JUPYTER_ALLOW_NO_AUTH=true $0" >&2
    exit 1
fi

# Security warning: This configuration disables authentication
# WARNING: Only use this in trusted environments (e.g., isolated containers)
echo "WARNING: Jupyter Lab is running without authentication!" >&2
echo "This should only be used in trusted, isolated environments." >&2
echo "Anyone with network access can execute arbitrary code." >&2

# Start Jupyter Lab with disabled authentication
# Note: --allow-root is used for container environments where running as root is expected
# In production, consider running as a non-root user for better security
# Using ServerApp (newer) and NotebookApp (legacy) for broader compatibility
jupyter lab --ip=0.0.0.0 --port=${JUPYTER_PORT:-8888} --no-browser --allow-root \
    --ServerApp.token='' --ServerApp.password='' \
    --NotebookApp.token='' --NotebookApp.password='' \
    --notebook-dir="/workspace" > "/workspace/logs/jupyter.log" 2>&1
