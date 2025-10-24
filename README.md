# 🚀 RunPod ComfyUI Cloud Pod

Production-ready ComfyUI Docker image optimized for NVIDIA H200 and RTX 5090 GPUs on RunPod cloud platform.

[![Docker Hub](https://img.shields.io/badge/Docker-Hub-blue?logo=docker)](https://hub.docker.com/r/ecomtree/comfyui-cloud)
[![RunPod](https://img.shields.io/badge/RunPod-Cloud-green?logo=runpod)](https://runpod.io/)
[![CUDA](https://img.shields.io/badge/CUDA-12.8+-brightgreen?logo=nvidia)](https://developer.nvidia.com/cuda-toolkit)

## ✨ Features

- **🎨 ComfyUI v0.3.57** with latest performance optimizations
- **🤖 Automatic model download** - 200+ validated models on demand
- **📊 Jupyter Lab** integrated development environment
- **🔥 H200 GPU optimizations** for maximum performance
- **🛡️ Crash-loop protection** with fallback mechanisms
- **⚡ Fast startup** under 3 minutes
- **💰 Cost optimized** RTX 5090 support ($0.69/hr)
- **🔓 No authentication** required for Jupyter Lab

## 🎯 Supported Hardware

| GPU           | VRAM      | Cost/Hr   | Status          | Use Case                     |
| ------------- | --------- | --------- | --------------- | ---------------------------- |
| **RTX 5090**  | 24GB      | **$0.69** | ✅ **Optimal**  | **Development & Production** |
| **H200**      | 80GB HBM3 | $3.59     | ✅ Premium      | Heavy workloads              |
| **H100 80GB** | 80GB      | ~$2.50    | ✅ Available    | Enterprise                   |
| RTX 4090      | 24GB      | $0.34     | ❌ Incompatible | CUDA < 12.8                  |

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
4. _Optional:_ Set Environment Variables:
   - `DOWNLOAD_MODELS=true` - for automatic model download
   - `HF_TOKEN=hf_xxx` - for protected Hugging Face models
5. Click **Deploy On-Demand**

### 3. Access Services

Once deployed:

- **Without Volume:** Ready in ~2-3 minutes
- **With Volume (first start):** ~5-10 minutes (one-time ComfyUI installation to volume)
- **With Volume (subsequent starts):** ~30 seconds (ComfyUI already on volume)

**Access:**

- **ComfyUI:** `http://<pod-ip>:8188`
- **Jupyter Lab:** `http://<pod-ip>:8888` (no login required)

## 🔧 Project Structure

```
runpod-comfyui-cloud/
├── Dockerfile                        # Main Docker image definition
├── comfyui_models_complete_library.md # Complete model library (200+ models)
├── README.md                         # This file
├── README_MODELS.md                  # Model download documentation
├── LICENSE                           # MIT License
├── requirements.txt                  # Development dependencies
├── runpod-template-example.json      # RunPod template configuration
├── docs/
│   ├── deployment-guide.md          # Deployment instructions
│   ├── troubleshooting.md           # Common issues & solutions
│   └── gpu-compatibility.md         # GPU compatibility matrix
└── scripts/
    ├── build.sh                     # Docker build script
    ├── deploy.sh                    # RunPod deployment script
    ├── test.sh                      # Local testing script
    ├── download_models.py           # Automatic model downloader
    └── verify_links.py              # Link verification tool
```

## 🛠️ Development

### Local Setup

**1. Install development dependencies:**

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

**2. Verify model links:**

```bash
python3 scripts/verify_links.py
```

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

### 🤖 Automatic Model Download

The image supports automatic downloading of all validated ComfyUI models at startup:

**Option 1: RunPod Environment Variable**

```bash
# In RunPod Pod Settings under "Environment Variables"
DOWNLOAD_MODELS=true
HF_TOKEN=hf_xxxxxxxxxxxxx  # Optional: for protected Hugging Face models
```

**Option 2: Docker Run**

```bash
docker run -e DOWNLOAD_MODELS=true -e HF_TOKEN=hf_xxx ecomtree/comfyui-cloud:latest
```

**Manual Download (in running container)**

```bash
# Direct in container
docker exec -it <container_name> /usr/local/bin/download_comfyui_models.sh

# Or Python script directly
docker exec -it <container_name> python3 /workspace/scripts/download_models.py /workspace
```

**Notes:**

- ⏱️ Download takes several hours depending on internet connection
- 💾 Requires approximately 200+ GB free storage
- 📋 Progress log: `/workspace/model_download.log`
- ✅ Runs in background - ComfyUI starts immediately

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

**Model download not working:**

- ✅ **Check:** Environment variable `DOWNLOAD_MODELS=true` is set
- ✅ **Verify:** Check log: `cat /workspace/model_download.log`
- ✅ **Retry:** Start manually with `/usr/local/bin/download_comfyui_models.sh`
- ⚠️ **HF Token:** For protected models set `HF_TOKEN`

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

## 🔄 Version & Updates

The image is continuously updated and available as **`:latest`**:

```bash
docker pull ecomtree/comfyui-cloud:latest
```

**Current Features:**

- ComfyUI v0.3.57
- Automatic model download support
- No Jupyter authentication
- H200 & RTX 5090 optimizations

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

**Maintained by:** [@tensorvisuals](https://github.com/tensorvisuals)  
**Status:** ✅ Production Ready  
**Last Updated:** 2025-10-24
