#!/bin/bash
jupyter lab --ip=0.0.0.0 --port=${JUPYTER_PORT:-8888} --no-browser --allow-root \
    --NotebookApp.token='' --NotebookApp.password='' \
    --notebook-dir="/workspace" > "/workspace/logs/jupyter.log" 2>&1
