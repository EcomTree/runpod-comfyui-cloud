# 🚀 RunPod ComfyUI Cloud Pod

Production-ready ComfyUI Docker image optimized for NVIDIA H200 and RTX 5090 GPUs on RunPod cloud platform.

[![Docker Hub](https://img.shields.io/badge/Docker-Hub-blue?logo=docker)](https://hub.docker.com/r/ecomtree/comfyui-cloud)
[![RunPod](https://img.shields.io/badge/RunPod-Cloud-green?logo=runpod)](https://runpod.io/)
[![CUDA](https://img.shields.io/badge/CUDA-12.8+-brightgreen?logo=nvidia)](https://developer.nvidia.com/cuda-toolkit)

## ✨ Features

### Core Features
- **🎨 ComfyUI Latest** - Automatically fetches latest version (configurable via `COMFYUI_VERSION`)
- **🔌 5 Essential Custom Nodes** - Pre-installed: Manager, Impact-Pack, rgthree, Advanced-ControlNet, VideoHelperSuite
- **🤖 Enhanced Model Download** - Parallel downloads with resume capability and checksum verification
- **📊 Jupyter Lab** - Integrated development environment with optional password protection
- **🔥 H200 GPU Optimizations** - Maximum performance with torch.compile support
- **🛡️ Crash-Loop Protection** - Fallback mechanisms for stability

### Advanced Features
- **⚡ Parallel Model Downloads** - Download multiple models simultaneously (configurable workers)
- **🔐 Checksum Verification** - SHA256 validation for all downloaded models
- **📈 GPU Monitoring** - Real-time VRAM, utilization, and temperature tracking
- **🏥 Health Checks** - Automated system health validation
- **🔒 Security Hardening** - Non-root user, file permissions, API authentication
- **🧪 Testing Framework** - Comprehensive test coverage with CI/CD
- **🎯 Model Manager CLI** - Easy model management (list, download, remove, verify)
- **📊 Prometheus Metrics** - Optional metrics export for Grafana dashboards
- **🎨 UI/UX Enhancements** - Dark theme, auto-queue, CORS support
- **💰 Cost Optimized** - RTX 5090 support ($0.69/hr)
- **🔄 Dynamic Version Management** - Always get latest features automatically

## 🎯 Supported Hardware

| GPU           | VRAM      | Cost/Hr   | Status          | Use Case                     |
| --- | --- | --- | --- | --- |
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
- **Jupyter Lab:** `http://<pod-ip>:8888` (no login required by default; set `JUPYTER_PASSWORD` to enable login)

## 🔧 Project Structure

```
runpod-comfyui-cloud/
├── Dockerfile                        # Main Docker image definition
├── comfyui_models_complete_library.md # Complete model library (200+ models)
├── models_download.json              # JSON model configuration (primary)
├── README.md                         # This file
├── README_MODELS.md                  # Model download documentation
├── LICENSE                           # MIT License
├── requirements.txt                  # Development dependencies
├── runpod-template-example.json      # RunPod template configuration
├── configs/
│   └── custom_nodes.json            # Custom nodes configuration
├── docs/
│   ├── deployment-guide.md          # Deployment instructions
│   ├── environment-variables.md    # Environment variables reference
│   ├── custom-nodes.md             # Custom nodes documentation
│   ├── troubleshooting.md           # Common issues & solutions
│   └── gpu-compatibility.md         # GPU compatibility matrix
└── scripts/
    ├── build.sh                     # Docker build script
    ├── deploy.sh                    # RunPod deployment script
    ├── test.sh                      # Local testing script
    ├── get_latest_version.sh        # Fetch latest ComfyUI version
    ├── install_custom_nodes.sh      # Install custom nodes
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

### Deployment Checklist

```bash
# Build image locally
./scripts/build.sh

docker run -it \
  -e DOWNLOAD_MODELS=true \
  -e JUPYTER_ENABLE=true \
  -e HF_TOKEN=<optional-hf-token> \
  -p 8188:8188 \
  -p 8888:8888 \
  -v $(pwd)/workspace:/workspace \
  ecomtree/comfyui-cloud:latest

# Inside container, confirm Jupyter
curl http://localhost:8888

# Confirm download logs
cat /workspace/model_download.log
```

## 🔧 Configuration

### 🎨 ComfyUI Version Control

By default, the image automatically fetches the latest ComfyUI release. You can pin a specific version:

**Option 1: Environment Variable (Runtime)**
```bash
# Use latest version (default)
# Don't set COMFYUI_VERSION

# Pin to specific version
COMFYUI_VERSION=v0.3.67

# Use master branch
COMFYUI_VERSION=master
```

**Option 2: Build Argument (Build Time)**
```bash
docker buildx build \
  --build-arg COMFYUI_VERSION=v0.3.67 \
  --platform linux/amd64 \
  -t ecomtree/comfyui-cloud:latest .
```

### 🔌 Custom Nodes

Five essential custom nodes are pre-installed:

1. **ComfyUI-Manager** - GUI for managing custom nodes
2. **ComfyUI-Impact-Pack** - Advanced masking and image enhancement
3. **rgthree-comfy** - Quality of life improvements
4. **ComfyUI-Advanced-ControlNet** - Enhanced ControlNet support
5. **ComfyUI-VideoHelperSuite** - Video processing utilities

See [docs/custom-nodes.md](docs/custom-nodes.md) for detailed documentation.

**To add more custom nodes:**
- Edit `configs/custom_nodes.json` and rebuild
- Or use ComfyUI-Manager GUI in the web interface

### 🤖 Enhanced Model Download System

The image includes an advanced model download system with parallel downloads, checksum verification, and resume capability:

**Features:**
- ✅ **Parallel Downloads** - Download multiple models simultaneously (4 workers by default)
- ✅ **Checksum Verification** - SHA256 validation for data integrity
- ✅ **Resume Capability** - Continue interrupted downloads from where they stopped
- ✅ **Progress Bars** - Real-time download progress with tqdm
- ✅ **Exponential Backoff** - Intelligent retry logic for failed downloads

### Option 1: RunPod Environment Variables

**IMPORTANT:** In RunPod, you MUST click the "Save" button at the bottom of the Environment Variables section **BEFORE** deploying the pod!

```bash
# In RunPod Pod Settings under "Environment Variables"
DOWNLOAD_MODELS=true
DOWNLOAD_MAX_WORKERS=4         # Number of parallel download workers (default: 4)
HF_TOKEN=hf_xxxxxxxxxxxxx      # Optional: for protected Hugging Face models
JUPYTER_ENABLE=true            # Optional: enable Jupyter Lab on port 8888
JUPYTER_PASSWORD=<your-secure-password> # Optional: enable Jupyter with password
```

**RunPod Setup Steps:**
1. Go to your template settings
2. Scroll to "Environment Variables"
3. Add each variable **one by one**:
   - Click "+ Environment Variable"
   - Enter `JUPYTER_ENABLE` as key
   - Enter `true` as value
   - Click the ✓ (checkmark) to confirm
4. **IMPORTANT:** Click "Save" at the bottom
5. **Then** deploy your pod

**Troubleshooting:** If Jupyter doesn't start, the variables might not be set. Check the logs:
```bash
# SSH into your pod and run:
env | grep -E "JUPYTER|DOWNLOAD|RUNPOD"
# You should see your variables listed
```

### Option 2: Docker Run

```bash
docker run \
  -e DOWNLOAD_MODELS=true \
  -e HF_TOKEN=hf_xxx \
  -e JUPYTER_ENABLE=true \
  -e JUPYTER_PASSWORD=<your-secure-password> \
  -p 8188:8188 \
  -p 8888:8888 \
  ecomtree/comfyui-cloud:latest
```

**Manual Download (in running container)**

```bash
# Direct in container
docker exec -it <container_name> /usr/local/bin/download_comfyui_models.sh

# Or Python script directly
docker exec -it <container_name> python3 /opt/runpod/scripts/download_models.py /workspace
```

> See `docs/environment-variables.md` for the full list of tunables.

**Notes:**

- ⏱️ Download time reduced by ~60% with parallel downloads (4 workers)
- 💾 Requires approximately 200+ GB free storage
- 📋 Progress log: `/workspace/model_download.log`
- ✅ Runs in background - ComfyUI starts immediately
- 🔐 Automatic checksum verification for data integrity
- ▶️ Resume interrupted downloads automatically

### 🛠️ Model Manager CLI

Manage your models with the included CLI tool:

```bash
# List installed models
python scripts/model_manager.py list

# Search for models
python scripts/model_manager.py search "flux"

# Download specific model
python scripts/model_manager.py download "flux1-dev"

# Verify checksums
python scripts/model_manager.py verify

# Remove unused models (dry run)
python scripts/model_manager.py prune

# Update all installed models
python scripts/model_manager.py update
```

See `python scripts/model_manager.py --help` for full documentation.

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
    --preview-method auto \
    --enable-cors-header \
    --extra-model-paths-config extra_model_paths.yaml
```

### 📈 GPU Monitoring & Health Checks

**Real-time GPU monitoring:**

```bash
# Start GPU monitor
python scripts/monitor.py

# With custom interval
python scripts/monitor.py --interval 10

# Enable Prometheus metrics
python scripts/monitor.py --prometheus-port 9090

# Get current summary
python scripts/monitor.py --summary
```

**Health checks:**

```bash
# Run health check
bash scripts/health_check.sh

# Exit code 0 = healthy, 1 = issues detected
```

**Monitoring features:**
- 📊 GPU utilization, VRAM usage, temperature, power
- 🔍 ComfyUI queue status tracking
- 📝 JSON log files for analysis
- 📈 Optional Prometheus metrics export
- 🏥 Automated health validation

See [docs/monitoring.md](docs/monitoring.md) for detailed documentation.

### 🔒 Security Features

**Built-in security hardening:**

- ✅ **Non-root user** - Runs as `comfy` user
- ✅ **File permissions** - Secure cache directory (chmod 700)
- ✅ **API authentication** - Optional `COMFYUI_API_KEY` support
- ✅ **HTTPS URLs only** - All model downloads use HTTPS
- ✅ **Secret management** - Environment variables for credentials
- ✅ **Security scanning** - Automated vulnerability checks

**Run security scan:**

```bash
# Basic security check
python scripts/security_check.py

# With secret scanning
python scripts/security_check.py --scan-secrets
```

See [docs/security.md](docs/security.md) for security best practices.

### 🧪 Testing & Quality

**Comprehensive test coverage:**

```bash
# Run all tests
pytest tests/

# Run with coverage
pytest tests/ --cov=scripts --cov-report=term

# Run specific test file
pytest tests/test_models.py -v
```

**CI/CD:**
- Automated testing on push/PR
- Docker build validation
- Security scanning with Trivy
- Configuration validation

See `.github/workflows/test.yml` for CI/CD configuration.

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

**Monitoring issues:**

- ✅ **GPU stats not showing:** Install pynvml (`pip install pynvml>=11.5.0`)
- ✅ **Health check failing:** Verify ComfyUI is running and GPU is accessible
- ✅ **Prometheus metrics unavailable:** Check port 9090 is exposed

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

- ComfyUI v0.3.57 (automatically updated)
- Enhanced model download with parallel support
- GPU monitoring and health checks
- Security hardening and testing framework
- Model Manager CLI utility
- Optional Jupyter Lab password protection
- H200 & RTX 5090 optimizations
- Prometheus metrics export

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
> Maintainer change from [@sebastianhein](https://github.com/sebastianhein) to [@tensorvisuals](https://github.com/tensorvisuals) has been coordinated with all stakeholders.
**Status:** ✅ Production Ready  
**Last Updated:** 2025-10-24
