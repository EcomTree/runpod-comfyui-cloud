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

## Usage Tips
- Set these variables in the RunPod pod template before launching.
- When running locally, pass them with `docker run -e VAR=value`.
- For sensitive values such as `HF_TOKEN`, prefer RunPod secrets or `.env` files.
### Ports
- **Port 8188**: ComfyUI web interface.
- **Port 8888**: Jupyter Lab (only available when `JUPYTER_ENABLE=true`).
