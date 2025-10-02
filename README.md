# 🚀 RunPod ComfyUI Cloud Pod

Production-ready ComfyUI Docker image optimized for NVIDIA H200 and RTX 5090 GPUs on RunPod cloud platform.

[![Docker Hub](https://img.shields.io/badge/Docker-Hub-blue?logo=docker)](https://hub.docker.com/r/ecomtree/comfyui-cloud)
[![RunPod](https://img.shields.io/badge/RunPod-Cloud-green?logo=runpod)](https://runpod.io/)
[![CUDA](https://img.shields.io/badge/CUDA-12.8+-brightgreen?logo=nvidia)](https://developer.nvidia.com/cuda-toolkit)

## ✨ Features

- **🎨 ComfyUI v0.3.57** with latest performance optimizations
- **📊 Jupyter Lab** integrated development environment  
- **🔥 H200 GPU optimizations** for maximum performance
- **🛡️ Crash-loop protection** with fallback mechanisms
- **⚡ Fast startup** under 3 minutes
- **💰 Cost optimized** RTX 5090 support ($0.69/hr)
- **🔓 No authentication** required for Jupyter Lab

## 🎯 Supported Hardware

| GPU | VRAM | Cost/Hr | Status | Use Case |
|-----|------|---------|--------|----------|
| **RTX 5090** | 24GB | **$0.69** | ✅ **Optimal** | **Development & Production** |
| **H200** | 80GB HBM3 | $3.59 | ✅ Premium | Heavy workloads |
| **H100 80GB** | 80GB | ~$2.50 | ✅ Available | Enterprise |
| RTX 4090 | 24GB | $0.34 | ❌ Incompatible | CUDA < 12.8 |

## 🚀 Quick Start

### 1. Deploy on RunPod

**Option A: Use Pre-built Image**
```bash
docker pull ecomtree/comfyui-cloud:latest
```

**Option B: Build Locally**
```bash
# Build for RunPod (x86_64 architecture required)
docker buildx build --platform linux/amd64 -f Dockerfile -t ecomtree/comfyui-cloud .
```

### 2. RunPod Deployment

1. Go to [RunPod Pods](https://console.runpod.io/pods)
2. Click **Deploy** → Select **ecomtree-comfyui-cloud** template
3. **Important:** Choose RTX 5090 or H200 GPU (CUDA 12.8+ required)
4. Click **Deploy On-Demand**

### 3. Access Services

Once deployed (2-3 minutes):
- **ComfyUI:** `http://<pod-ip>:8188`
- **Jupyter Lab:** `http://<pod-ip>:8888` (no login required)

## 🔧 Project Structure

```
runpod-comfyui-h200/
├── Dockerfile                  # Main pod image
├── start_comfyui_h200.sh      # Startup script (reference)
├── docs/
│   ├── deployment-guide.md
│   ├── troubleshooting.md
│   └── gpu-compatibility.md
├── scripts/
│   ├── build.sh               # Local build helper
│   ├── deploy.sh              # RunPod deployment
│   └── test.sh                # Image testing
├── .github/
│   └── workflows/
│       └── docker-build.yml    # CI/CD pipeline
├── .dockerignore
├── .gitignore
└── README.md
```

## 🛠️ Development

### Building Images

**For RunPod deployment (x86_64):**
```bash
./scripts/build.sh
```

**Manual build:**
```bash
docker buildx build --platform linux/amd64 -f Dockerfile -t ecomtree/comfyui-cloud:latest .
```

### Testing Locally
```bash
./scripts/test.sh
```

## 🔧 Configuration

### GPU Optimizations

The image includes H200-specific optimizations:

```python
# PyTorch backend optimizations
torch.backends.cudnn.benchmark = True
torch.backends.cudnn.deterministic = False
torch.backends.cuda.matmul.allow_tf32 = True
torch.backends.cudnn.allow_tf32 = True

# Memory allocation optimization
export PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:1024,expandable_segments:True
export TORCH_ALLOW_TF32_CUBLAS_OVERRIDE=1
```

### ComfyUI Launch Parameters

```bash
python main.py \
    --listen 0.0.0.0 \
    --port 8188 \
    --highvram \
    --bf16-vae \
    --disable-smart-memory \
    --preview-method auto
```

## 🐛 Troubleshooting

### Common Issues

**Container crash-loop:**
- ✅ **Solution:** Use RTX 5090 or H200 (CUDA 12.8+ required)
- ❌ **Avoid:** RTX 4090 and older GPUs

**"exec format error":**
- ✅ **Solution:** Build with `--platform linux/amd64`
- ❌ **Problem:** ARM64 Mac builds won't work on RunPod

**Services not accessible:**
- ✅ **Check:** Wait 2-3 minutes for full startup
- ✅ **Verify:** Pod has Port Mappings in RunPod console

See [troubleshooting.md](docs/troubleshooting.md) for detailed solutions.

## 💰 Cost Analysis

### Performance vs Cost

- **RTX 5090:** $0.69/hr - **Recommended** (optimal balance)
- **H200:** $3.59/hr - Premium (maximum performance)
- **Cost Savings:** 80% with RTX 5090 vs H200

### Usage Recommendations

- **Development:** RTX 5090 (cost-effective)
- **Heavy Batch Processing:** H200 (maximum performance)
- **Production Workloads:** RTX 5090 (optimal balance)

## 🔄 Version History

- **v1.2** (`no-auth`) - No Jupyter authentication, dual services
- **v1.1** (`complete`) - Dual service setup with authentication  
- **v1.0** (`final`) - H200 optimized baseline
- **v0.9** (`working`) - Stable RTX compatibility

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Test on RTX 5090 before H200 deployment
4. Submit a pull request

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

## 🙏 Acknowledgments

- [ComfyUI](https://github.com/comfyanonymous/ComfyUI) - Amazing AI workflow tool
- [RunPod](https://runpod.io/) - GPU cloud infrastructure
- [Docker](https://docker.com/) - Containerization platform

---

**Maintained by:** [@sebastianhein](https://github.com/sebastianhein)  
**Status:** ✅ Production Ready  
**Last Updated:** 2025-09-18
