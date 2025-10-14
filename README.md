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
4. *Optional:* Set Environment Variables:
   - `DOWNLOAD_MODELS=true` - für automatischen Model-Download
   - `HF_TOKEN=hf_xxx` - für protected Hugging Face Modelle
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
├── Dockerfile                  # Main pod image
├── setup-codex.sh             # Codex environment setup
├── docs/
│   ├── deployment-guide.md
│   ├── troubleshooting.md
│   └── gpu-compatibility.md
├── scripts/
│   ├── build.sh               # Local build helper
│   ├── deploy.sh              # RunPod deployment
│   ├── download_models.py     # Model download script
│   ├── verify_links.py        # Link validation
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

### 🤖 Automatic Model Download

Das Image unterstützt automatisches Herunterladen aller validierten ComfyUI-Modelle beim Start:

**Option 1: RunPod Environment Variable**
```bash
# In RunPod Pod Settings unter "Environment Variables"
DOWNLOAD_MODELS=true
HF_TOKEN=hf_xxxxxxxxxxxxx  # Optional: für protected Hugging Face Modelle
```

**Option 2: Docker Run**
```bash
docker run -e DOWNLOAD_MODELS=true -e HF_TOKEN=hf_xxx ecomtree/comfyui-cloud:latest
```

**Manueller Download (im laufenden Container)**
```bash
# Direkt im Container
docker exec -it <container_name> /usr/local/bin/download_comfyui_models.sh

# Oder Python-Script direkt
docker exec -it <container_name> python3 /workspace/scripts/download_models.py /workspace
```

**Hinweise:**
- ⏱️ Download dauert je nach Internet-Verbindung mehrere Stunden
- 💾 Benötigt ca. 200+ GB freien Speicher
- 📋 Progress-Log: `/workspace/model_download.log`
- ✅ Läuft im Hintergrund - ComfyUI startet sofort

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
- ✅ **Check:** Environment variable `DOWNLOAD_MODELS=true` gesetzt
- ✅ **Verify:** Log checken: `cat /workspace/model_download.log`
- ✅ **Retry:** Manuell starten mit `/usr/local/bin/download_comfyui_models.sh`
- ⚠️ **HF Token:** Für protected models `HF_TOKEN` setzen

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

Das Image wird kontinuierlich aktualisiert und ist als **`:latest`** verfügbar:
```bash
docker pull ecomtree/comfyui-cloud:latest
```

**Aktuelle Features:**
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

**Maintained by:** [@sebastianhein](https://github.com/sebastianhein)  
**Status:** ✅ Production Ready  
**Last Updated:** 2025-10-14
