# 🚀 RunPod Deployment Guide

Complete guide for deploying ComfyUI H200 on RunPod cloud platform.

## Prerequisites

- RunPod account with credits
- Basic understanding of Docker containers
- Knowledge of ComfyUI workflows

## Step-by-Step Deployment

### 1. Choose Your Hardware

**Recommended: RTX 5090**
- Cost: $0.69/hour (80% cheaper than H200)
- VRAM: 24GB (sufficient for most workloads)
- Performance: Excellent for ComfyUI

**Premium: H200**
- Cost: $3.59/hour
- VRAM: 80GB HBM3 (maximum performance)
- Use case: Heavy batch processing

**❌ Avoid: RTX 4090 and older**
- CUDA < 12.8 (incompatible with our image)
- Will result in container startup failures

### 2. Deploy via RunPod Template

1. **Access RunPod Console**
   - Go to [RunPod Pods](https://console.runpod.io/pods)
   - Click **Deploy**

2. **Select Template**
   - Choose **"STABLE SebastianHein ComfyUI RTX5090-H200"**
   - This template is pre-configured with optimal settings

3. **Configure Hardware**
   - **GPU Type:** Select RTX 5090 or H200
   - **Volume:** 100GB recommended for models
   - **Container Disk:** 40GB minimum

4. **Deploy**
   - Click **Deploy On-Demand**
   - Wait 2-3 minutes for initialization

### 3. Access Services

Once deployment is complete:

**ComfyUI Web Interface**
- URL: `http://<pod-ip>:8188`
- Purpose: AI image generation workflows
- No authentication required

**Jupyter Lab**
- URL: `http://<pod-ip>:8888`  
- Purpose: Development environment
- No authentication required (latest image)

### 4. Verify Deployment

**Check Service Status:**
1. Both ports should show "Ready" in RunPod console
2. Services accessible without login prompts
3. ComfyUI shows standard interface
4. Jupyter Lab opens workspace directory

**GPU Utilization:**
- SSH into pod: `nvidia-smi`
- Should show RTX 5090 or H200
- CUDA version should be 12.8+

## Manual Deployment (Advanced)

### Using RunPod API

```python
import runpod

# Configure API key
runpod.api_key = "your-api-key"

# Deploy pod
pod = runpod.create_pod(
    name="comfyui-production",
    image_name="sebastianhein/comfyui-h200:no-auth",
    gpu_type_id="NVIDIA GeForce RTX 5090",
    ports="8188/http,8888/http",
    volume_in_gb=100,
    container_disk_in_gb=40
)

print(f"Pod created: {pod['id']}")
```

### Using Docker (Local Testing)

```bash
# Test locally (requires NVIDIA GPU + Docker with GPU support)
docker run -d \
    --name comfyui-test \
    --gpus all \
    -p 8188:8188 \
    -p 8888:8888 \
    sebastianhein/comfyui-h200:no-auth
```

## Configuration Options

### Environment Variables

Available in pod configuration:

```bash
# GPU Memory optimization
PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:1024,expandable_segments:True

# Performance tuning
TORCH_ALLOW_TF32_CUBLAS_OVERRIDE=1

# ComfyUI settings
COMFY_HOST=0.0.0.0
COMFY_PORT=8188
```

### Volume Configuration

**Recommended Volume Setup:**
- **Size:** 100GB minimum for model storage
- **Mount:** `/workspace` (standard RunPod location)
- **Purpose:** Persistent model and workflow storage

**Model Directories:**
```
/workspace/ComfyUI/models/
├── checkpoints/        # Stable Diffusion models
├── vae/               # VAE models
├── loras/             # LoRA fine-tuning models
├── diffusion_models/  # Other diffusion models
└── text_encoders/     # Text encoder models
```

## Cost Optimization

### Hardware Selection Strategy

**Development/Testing:**
- Use RTX 5090 ($0.69/hr)
- 24GB VRAM sufficient for most workflows
- Excellent price/performance ratio

**Production/Heavy Workloads:**
- Consider H200 ($3.59/hr) for maximum performance
- 80GB HBM3 for large batch processing
- Use for complex multi-model workflows

### Resource Management

**Container Disk:**
- 40GB minimum (OS + ComfyUI + dependencies)
- No need to increase unless custom installations

**Volume Storage:**
- 100GB recommended starting point
- Scale up based on model collection size
- Can be shared across pod deployments

## Monitoring & Maintenance

### Health Checks

Monitor these indicators:
- Pod status: Should remain "RUNNING"
- Port mappings: Both 8188 and 8888 active
- GPU utilization: Check via `nvidia-smi`
- Service logs: ComfyUI and Jupyter Lab startup

### Log Access

**ComfyUI Logs:**
```bash
# SSH into pod
docker logs $(docker ps -q)
```

**Jupyter Lab Logs:**
```bash
# SSH into pod  
cat /workspace/jupyter.log
```

### Updating Images

1. Build new image version
2. Test locally or on development pod
3. Update production pod with new image
4. Verify services restart correctly

## Troubleshooting

Common deployment issues and solutions:

**Pod startup failures:**
- Verify GPU type is RTX 5090 or H200
- Check CUDA compatibility
- Review container logs

**Services not accessible:**
- Wait 2-3 minutes for full startup
- Verify port mappings in RunPod console
- Check network connectivity

See [troubleshooting.md](troubleshooting.md) for detailed solutions.
