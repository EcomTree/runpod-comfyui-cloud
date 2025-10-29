# RunPod Environment Variables

## Required Variables

### Enable Jupyter Lab
- **Variable**: `JUPYTER_ENABLE`
- **Value**: truthy (`true`, `1`, `yes`, `on`; case-insensitive)
- **Description**: Launches Jupyter Lab on port 8888. Any other value (including unset) disables Jupyter Lab and triggers a startup warning for unrecognized values.

### Jupyter Password (Optional)
- **Variable**: `JUPYTER_PASSWORD`
- **Value**: `<your-password>`
- **Description**: Sets a password for Jupyter Lab. If not provided, Jupyter will start without authentication (use only in trusted environments).

### Enable Model Downloads
- **Variable**: `DOWNLOAD_MODELS`
- **Value**: truthy (`true`, `1`, `yes`, `on`; case-insensitive)
- **Description**: Starts the automatic ComfyUI model download routine during container boot. Download progress is written to `/workspace/model_download.log`. Any other value (including unset) disables model downloads; unrecognized values trigger a startup warning.

## Optional Variables

### Hugging Face Token
- **Variable**: `HF_TOKEN`
- **Value**: `<your-hf-token>`
- **Description**: Grants access to gated Hugging Face models while downloading.

### Custom Workspace Path
- **Variable**: `WORKSPACE_DIR`
- **Value**: `/workspace`
- **Description**: Override only if your RunPod volume mounts to a different path.

### ComfyUI Version (Optional)
- **Variable**: `COMFYUI_VERSION`
- **Value**: `v0.3.67`, `master`, or any valid git tag/branch
- **Description**: Pin a specific ComfyUI version. If not set, the system automatically fetches the latest release tag from GitHub. Examples:
  - `v0.3.67` - Pin to specific version
  - `master` - Use latest master branch
  - Leave unset - Automatically use latest release tag
- **Note**: When building Docker images, you can also use build argument: `--build-arg COMFYUI_VERSION=v0.3.67`

## Usage Tips
- Set these variables in the RunPod pod template before launching.
- When running locally, pass them with `docker run -e VAR=value`.
- For sensitive values such as `HF_TOKEN`, prefer RunPod secrets or `.env` files.

### Ports
- **Port 8188**: ComfyUI web interface.
- **Port 8888**: Jupyter Lab (only available when `JUPYTER_ENABLE=true`).

## Debugging

### Check if Jupyter started
```bash
# Check Jupyter logs
tail -f /workspace/jupyter.log

# Check if Jupyter process is running
ps aux | grep jupyter
```

### Check if Model Download started
```bash
# Check model download logs
tail -f /workspace/model_download.log

# Check if download process is running
pgrep -f download_models.py
```

### Verify Environment Variables
```bash
# Check normalized values during startup
docker logs <container-id> | grep "DEBUG:"
```

### Common Issues

#### Jupyter not starting
- **Cause**: `JUPYTER_ENABLE` not set to truthy value
- **Solution**: Set `JUPYTER_ENABLE=true` (exact case doesn't matter)
- **Debug**: Check logs with `docker logs <container-id> | grep JUPYTER`

#### Model Download not starting  
- **Cause**: `DOWNLOAD_MODELS` not set to truthy value
- **Solution**: Set `DOWNLOAD_MODELS=true` (exact case doesn't matter)
- **Debug**: Check logs with `docker logs <container-id> | grep DOWNLOAD_MODELS`

#### Models not found
- **Cause**: `models_download.json` or `comfyui_models_complete_library.md` not copied to container
- **Solution**: Rebuild container with latest Dockerfile
- **Debug**: Check if files exist in `/opt/runpod/` and `/workspace/`
