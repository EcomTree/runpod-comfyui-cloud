# Environment Variables

This document describes all available environment variables for configuring the ComfyUI RunPod deployment.

## Core Configuration

### `COMFYUI_VERSION`
- **Type:** String
- **Default:** Latest release from GitHub
- **Description:** Pin a specific ComfyUI version (e.g., `v0.3.67`) or use `master` branch
- **Example:** `COMFYUI_VERSION=v0.3.67`

## Model Download Configuration

### `DOWNLOAD_MODELS`
- **Type:** Boolean (`true`/`false`)
- **Default:** `false`
- **Description:** Enable automatic model download on container startup
- **Example:** `DOWNLOAD_MODELS=true`

### `DOWNLOAD_MAX_WORKERS`
- **Type:** Integer
- **Default:** `4`
- **Description:** Number of parallel download workers
- **Example:** `DOWNLOAD_MAX_WORKERS=8`

### `HF_TOKEN`
- **Type:** String
- **Default:** (none)
- **Description:** Hugging Face API token for protected model downloads
- **Example:** `HF_TOKEN=hf_xxxxxxxxxxxxx`
- **Security:** Keep this secret! Use environment variables, not code.

## Jupyter Lab Configuration

### `JUPYTER_ENABLE`
- **Type:** Boolean (`true`/`false`)
- **Default:** `false`
- **Description:** Enable Jupyter Lab on port 8888
- **Example:** `JUPYTER_ENABLE=true`

### `JUPYTER_PASSWORD`
- **Type:** String
- **Default:** (none - no authentication)
- **Description:** Password for Jupyter Lab authentication
- **Example:** `JUPYTER_PASSWORD=SecurePassword123!`
- **Security:** Always set a strong password in production!

## Monitoring Configuration

### `MONITOR_ENABLED`
- **Type:** Boolean (`true`/`false`)
- **Default:** `false`
- **Description:** Enable GPU monitoring on startup
- **Example:** `MONITOR_ENABLED=true`

### `MONITOR_INTERVAL`
- **Type:** Integer (seconds)
- **Default:** `5`
- **Description:** GPU monitoring polling interval
- **Example:** `MONITOR_INTERVAL=10`

### `PROMETHEUS_PORT`
- **Type:** Integer
- **Default:** (disabled)
- **Description:** Port for Prometheus metrics export
- **Example:** `PROMETHEUS_PORT=9090`

## Security Configuration

### `COMFYUI_API_KEY`
- **Type:** String
- **Default:** (none - no authentication)
- **Description:** API key for ComfyUI API authentication
- **Example:** `COMFYUI_API_KEY=your-secure-api-key-here`
- **Security:** Generate with `openssl rand -hex 32`

## Performance Configuration

### `PYTORCH_CUDA_ALLOC_CONF`
- **Type:** String
- **Default:** `max_split_size_mb:1024,expandable_segments:True`
- **Description:** PyTorch CUDA memory allocator configuration for H200 optimization
- **Example:** `PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:2048,expandable_segments:True`

### `TORCH_ALLOW_TF32_CUBLAS_OVERRIDE`
- **Type:** Boolean (`1`/`0`)
- **Default:** `1`
- **Description:** Enable TF32 tensor cores for better performance
- **Example:** `TORCH_ALLOW_TF32_CUBLAS_OVERRIDE=1`

## Advanced Configuration

### `DOWNLOAD_LOG_WAIT_SECS`
- **Type:** Integer (seconds)
- **Default:** `10`
- **Description:** Wait time for model download log to start
- **Example:** `DOWNLOAD_LOG_WAIT_SECS=20`

### `COMFYUI_PORT`
- **Type:** Integer
- **Default:** `8188`
- **Description:** Port for ComfyUI web interface
- **Example:** `COMFYUI_PORT=8188`

### `VRAM_THRESHOLD_PERCENT`
- **Type:** Integer (0-100)
- **Default:** `95`
- **Description:** VRAM usage threshold for health checks
- **Example:** `VRAM_THRESHOLD_PERCENT=90`

### `MAX_QUEUE_SIZE`
- **Type:** Integer
- **Default:** `100`
- **Description:** Maximum ComfyUI queue size before warning
- **Example:** `MAX_QUEUE_SIZE=50`

## Example Configurations

### Development Setup
```bash
DOWNLOAD_MODELS=false
JUPYTER_ENABLE=true
JUPYTER_PASSWORD=dev123
MONITOR_ENABLED=true
```

### Production Setup
```bash
DOWNLOAD_MODELS=true
DOWNLOAD_MAX_WORKERS=4
HF_TOKEN=hf_xxxxxxxxxxxxx
COMFYUI_API_KEY=your-secure-api-key-here
JUPYTER_ENABLE=false
MONITOR_ENABLED=true
PROMETHEUS_PORT=9090
VRAM_THRESHOLD_PERCENT=90
```

### High-Performance Setup
```bash
DOWNLOAD_MODELS=true
DOWNLOAD_MAX_WORKERS=8
PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:2048,expandable_segments:True
TORCH_ALLOW_TF32_CUBLAS_OVERRIDE=1
MONITOR_ENABLED=true
```

## Setting Environment Variables

### RunPod Console
1. Go to your pod settings
2. Navigate to "Environment Variables" section
3. Add key-value pairs
4. Restart pod to apply changes

### Docker Command
```bash
docker run \
  -e DOWNLOAD_MODELS=true \
  -e HF_TOKEN=hf_xxx \
  -e JUPYTER_ENABLE=true \
  --gpus all \
  -p 8188:8188 \
  ecomtree/comfyui-cloud:latest
```

### Docker Compose
```yaml
services:
  comfyui:
    image: ecomtree/comfyui-cloud:latest
    environment:
      - DOWNLOAD_MODELS=true
      - HF_TOKEN=hf_xxx
      - JUPYTER_ENABLE=true
    deploy:
      resources:
        reservations:
          devices:
            - capabilities: [gpu]
```

## Boolean Values

Boolean environment variables accept multiple formats:
- **True:** `true`, `True`, `TRUE`, `1`, `yes`, `Yes`, `YES`, `on`, `On`, `ON`
- **False:** `false`, `False`, `FALSE`, `0`, `no`, `No`, `NO`, `off`, `Off`, `OFF`, (empty)

## Security Best Practices

1. **Never commit secrets** to version control
2. **Use RunPod secrets** for sensitive values
3. **Rotate API keys** regularly (every 90 days)
4. **Use strong passwords** for Jupyter (20+ characters)
5. **Enable API authentication** in production
6. **Restrict network access** with firewall rules

## Troubleshooting

### Variable Not Working
- Check spelling (case-sensitive)
- Verify pod has been restarted
- Check logs: `docker logs <container_id>`

### Boolean Not Recognized
- Use lowercase: `true` instead of `True`
- Check for typos: `ture` → `true`

### Secret Values Exposed
- Never use `printenv` or `env` in public logs
- Rotate compromised secrets immediately
- Use RunPod secret management

## See Also

- [Security Guide](security.md)
- [Monitoring Guide](monitoring.md)
- [Deployment Guide](deployment-guide.md)

---

**Last Updated:** 2025-10-29
