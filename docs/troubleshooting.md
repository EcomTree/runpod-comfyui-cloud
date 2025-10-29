# 🔧 Troubleshooting Guide

Common issues and solutions for RunPod ComfyUI Cloud deployment.

## Container Issues

### ❌ Container Crash-Loop / Infinite Restarts

**Symptoms:**
```
2025-09-18T17:57:40Z start container
2025-09-18T17:57:42Z start container  
2025-09-18T17:57:44Z start container
...infinite loop
```

**Root Causes & Solutions:**

#### 1. GPU CUDA Incompatibility (Most Common)
**Problem:** RTX 4090 and older GPUs have CUDA < 12.8
```
nvidia-container-cli: requirement error: unsatisfied condition: cuda>=12.8
```
**Solution:** ✅ Use compatible GPUs only:
- NVIDIA GeForce RTX 5090 ✅
- NVIDIA H200 ✅  
- NVIDIA H100 80GB HBM3 ✅

#### 2. Architecture Mismatch
**Problem:** ARM64 image on x86_64 RunPod infrastructure
```
exec /bin/bash: exec format error
```
**Solution:** ✅ Build with correct platform:
```bash
docker buildx build --platform linux/amd64 -f Dockerfile -t image:tag .
```

#### 3. Volume Mount Handling (Automatic in Current Version)
**What Happens:** When mounting a volume to `/workspace`, the directory starts empty.

**Automatic Solution:** ✅ The start script now auto-detects empty volumes and installs ComfyUI:
- Checks if `/workspace/ComfyUI` exists
- If not: Clones ComfyUI v0.3.57 to the volume
- Installs all dependencies
- Creates optimization files
- **First start takes ~5-10 minutes** (one-time setup)
- Subsequent starts are fast (~30 seconds)

**Benefits:**
- ✅ ComfyUI persists on the volume (survives pod restarts)
- ✅ Models stored on volume are preserved
- ✅ Works seamlessly with or without volumes
- ✅ Start script in `/usr/local/bin/` (not affected by volume)

**First Start with Volume:**
```bash
# Expected output:
⚠️  ComfyUI not found in /workspace (Volume Mount detected)
📦 Installing ComfyUI to persistent volume...
# ... installation progress ...
✅ ComfyUI installation completed!
```

### ❌ Services Not Starting

#### ComfyUI Not Accessible (Port 8188)

**Check List:**
1. **Wait Time:** Allow 2-3 minutes for full startup
2. **Port Mapping:** Verify 8188 is mapped in RunPod console
3. **Container Logs:** Check for Python errors
4. **GPU Access:** Verify with `nvidia-smi` in container

**Debug Commands:**
```bash
# SSH into pod
docker logs $(docker ps -q) | tail -50

# Check ComfyUI process
ps aux | grep python

# Test manual startup
cd /workspace/ComfyUI
python main.py --listen 0.0.0.0 --port 8188
```

#### Jupyter Lab Not Accessible (Port 8888)

**Version-Specific Solutions:**

**For `no-auth` image:**
- Should work immediately without login
- Check port 8888 is mapped
- Verify Jupyter process running: `ps aux | grep jupyter`

**For other images:**
```bash
# Find authentication token
cat /workspace/jupyter.log | grep token

# Look for line like:
# http://localhost:8888/?token=c8de56fa12345...
# Copy token and use in login field
```

## Build Issues

### ❌ Docker Build Failures

#### Platform Warnings
```
FromPlatformFlagConstDisallowed: FROM --platform flag should not use constant value
```
**Solution:** ✅ Use platform flag in build command, not Dockerfile:
```bash
# Correct approach:
docker buildx build --platform linux/amd64 -f Dockerfile -t image .

# Don't do this in Dockerfile:
# FROM --platform=linux/amd64 baseimage
```

#### HEREDOC Syntax Errors
```
unknown instruction: set (did you mean user?)
```
**Solution:** ✅ Ensure proper HEREDOC syntax:
```dockerfile
# Correct:
RUN <<EOF cat > script.sh
#!/bin/bash
echo "test"
EOF

# Wrong:
RUN cat > script.sh << 'EOF'
#!/bin/bash  
echo "test"
EOF
```

#### Cache Issues
**Problem:** Changes not reflected in image
**Solution:** ✅ Use no-cache build:
```bash
docker buildx build --no-cache --platform linux/amd64 -f Dockerfile -t image .
```

## GPU & Performance Issues

### ❌ Low Performance

#### GPU Not Utilized
**Check:**
```bash
# SSH into pod
nvidia-smi

# Should show:
# - GPU: RTX 5090 or H200
# - CUDA Version: 12.8+
# - Processes: Python (ComfyUI)
```

**If GPU not detected:**
- Verify pod has GPU allocated
- Check container started with `--gpus all`
- Restart container if needed

#### Memory Issues
**Symptoms:** OOM errors, slow generation
**Solutions:**
- ✅ Verify `--highvram` flag in ComfyUI startup
- ✅ Check H200 optimizations loaded:
```bash
# In container
cd /workspace/ComfyUI
python -c "import torch; print(torch.backends.cudnn.benchmark)"
# Should print: True
```

### ❌ CUDA Errors

#### Version Mismatch
```
RuntimeError: CUDA version mismatch
```
**Solution:** ✅ Use images built for CUDA 12.8:
- Only deploy on RTX 5090/H200/H100
- Avoid RTX 4090 and older GPUs

#### Memory Allocation
```
CUDA out of memory
```
**Solutions:**
- ✅ Reduce batch size in ComfyUI workflows
- ✅ Use smaller models if possible
- ✅ Consider H200 for memory-intensive tasks

## Network & Access Issues

### ❌ Can't Access Services

#### Port Not Mapped
**Check:** RunPod console shows port mappings
**Solution:** Wait for pod full initialization

#### Firewall/Network
**Symptoms:** Timeouts, connection refused
**Solutions:**
- ✅ Use pod's public IP from RunPod console
- ✅ Verify services bind to 0.0.0.0 (not 127.0.0.1)
- ✅ Check pod network status

#### SSL/HTTPS Issues
**Problem:** Some browsers require HTTPS
**Solution:** ✅ Use HTTP directly:
- `http://<pod-ip>:8188` (not https://)
- Most modern browsers accept HTTP for development

## Emergency Recovery

### ❌ Complete Pod Failure

#### Quick Recovery Steps
1. **Stop Failed Pod:**
   ```bash
   # Via RunPod console or API
   runpodctl stop <pod-id>
   ```

2. **Deploy Fresh Pod:**
   ```bash
   # Use working image version
   ./scripts/deploy.sh --image sebastianhein/comfyui-h200:no-auth --rtx5090
   ```

3. **Verify Hardware:**
   - Ensure RTX 5090 or H200 allocation
   - Check CUDA 12.8+ support

#### Rollback Strategy
**Stable Image Versions:**
- `sebastianhein/comfyui-h200:no-auth` - Latest stable
- `sebastianhein/comfyui-h200:complete` - With authentication
- `sebastianhein/comfyui-h200:final` - H200 baseline

## Advanced Troubleshooting

### ❌ Model Download Issues

#### Parallel Downloads Failing
**Symptoms:** Downloads timing out, connection errors
**Solutions:**
- ✅ Reduce parallel workers: `DOWNLOAD_MAX_WORKERS=2`
- ✅ Check internet connection stability
- ✅ Verify HF_TOKEN for protected models

#### Checksum Verification Failed
**Symptoms:** Model downloads complete but verification fails
**Solutions:**
- ✅ Re-download the model: `python scripts/model_manager.py download <model>`
- ✅ Check disk space: `df -h /workspace`
- ✅ Verify network integrity

#### Resume Not Working
**Symptoms:** Downloads restart from beginning
**Solutions:**
- ✅ Ensure server supports HTTP Range headers
- ✅ Check partial file exists and is valid
- ✅ Clear incomplete downloads and retry

### ❌ Monitoring Issues

#### GPU Stats Not Showing
**Problem:** Monitor shows "No GPU stats available"
**Solutions:**
- ✅ Install pynvml: `pip install pynvml>=11.5.0`
- ✅ Check NVIDIA drivers: `nvidia-smi`
- ✅ Verify container has GPU access: `docker run --gpus all`

#### Health Check Failures
**Symptoms:** Health check returns exit code 1
**Solutions:**
- ✅ Check ComfyUI is running: `curl http://localhost:8188/queue`
- ✅ Verify GPU access: `nvidia-smi`
- ✅ Check VRAM usage: `nvidia-smi --query-gpu=memory.used,memory.total`
- ✅ Review logs: `cat /workspace/logs/comfyui.log`

#### Prometheus Metrics Not Accessible
**Problem:** Cannot access metrics on port 9090
**Solutions:**
- ✅ Verify monitor started with `--prometheus-port 9090`
- ✅ Check port is exposed: `docker ps` or RunPod console
- ✅ Test locally: `curl http://localhost:9090/metrics`

### ❌ Security Issues

#### API Authentication Not Working
**Problem:** Requests succeed without API key
**Solutions:**
- ✅ Verify `COMFYUI_API_KEY` is set
- ✅ Check ComfyUI configuration
- ✅ Restart container to apply changes

#### Security Scan Failures
**Problem:** Security check reports issues
**Solutions:**
- ✅ Review reported issues: `python scripts/security_check.py`
- ✅ Fix file permissions: `chmod 700 /home/comfy/.cache`
- ✅ Update to HTTPS URLs in configs
- ✅ Rotate API keys and secrets

### ❌ Testing Issues

#### Tests Failing
**Problem:** pytest returns errors
**Solutions:**
- ✅ Install test dependencies: `pip install -r requirements.txt`
- ✅ Check models_download.json is valid JSON
- ✅ Verify all URLs use HTTPS
- ✅ Run specific test: `pytest tests/test_models.py -v`

### ❌ Model Manager Issues

#### Model Not Found
**Problem:** `model_manager.py search` returns no results
**Solutions:**
- ✅ Check model exists in models_download.json
- ✅ Try partial name match: `search "flux"`
- ✅ Verify JSON file is readable

#### Prune Dry Run Not Working
**Problem:** Models not being identified as unused
**Solutions:**
- ✅ Update models_download.json with latest configuration
- ✅ Check file naming matches exactly
- ✅ Run with `--no-dry-run` to actually remove files

## Getting Help

### Log Collection
Before seeking help, collect:
```bash
# Container logs
docker logs $(docker ps -q) > container.log

# System info
nvidia-smi > gpu-status.txt
df -h > disk-usage.txt

# Monitoring logs
cat /workspace/logs/monitor.log > monitor.log

# Health check
bash scripts/health_check.sh > health-check.txt 2>&1

# Security scan
python scripts/security_check.py > security-scan.txt 2>&1
```

### Support Resources
- GitHub Issues: [Report problems](https://github.com/sebastianhein/runpod-comfyui-h200/issues)
- RunPod Discord: Community support
- Documentation: Check other docs/ files

### Known Working Configurations
- **RTX 5090 + sebastianhein/comfyui-h200:no-auth** ✅
- **H200 + sebastianhein/comfyui-h200:no-auth** ✅
- **H100 + sebastianhein/comfyui-h200:complete** ✅
