# 🔧 Troubleshooting Guide

Common issues and solutions for RunPod ComfyUI H200 deployment.

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
docker buildx build --platform linux/amd64 -f dockerfiles/Dockerfile -t image:tag .
```

#### 3. Missing Start Script
**Problem:** Script not found in container
```
/bin/bash: line 1: /workspace/start_comfyui_h200.sh: No such file or directory
```
**Solutions:**
- ✅ Verify HEREDOC syntax in Dockerfile
- ✅ Check WORKDIR paths are correct
- ✅ Ensure script permissions with `chmod +x`

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
docker buildx build --no-cache --platform linux/amd64 -f dockerfiles/Dockerfile -t image .
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

## Getting Help

### Log Collection
Before seeking help, collect:
```bash
# Container logs
docker logs $(docker ps -q) > container.log

# System info
nvidia-smi > gpu-status.txt
df -h > disk-usage.txt
```

### Support Resources
- GitHub Issues: [Report problems](https://github.com/sebastianhein/runpod-comfyui-h200/issues)
- RunPod Discord: Community support
- Documentation: Check other docs/ files

### Known Working Configurations
- **RTX 5090 + sebastianhein/comfyui-h200:no-auth** ✅
- **H200 + sebastianhein/comfyui-h200:no-auth** ✅
- **H100 + sebastianhein/comfyui-h200:complete** ✅
