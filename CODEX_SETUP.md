# Codex Environment Setup Guide

## 🎯 Quick Start

### One-Line Setup in Codex:

1. **Go to Codex → Setup Script → Manual**
2. **Paste this command:**

```bash
curl -fsSL https://raw.githubusercontent.com/EcomTree/runpod-comfyui-cloud/main/scripts/setup.sh | bash
```

That's it! ✨

---

## 📦 What Gets Installed?

The setup script automatically installs and configures:

### ComfyUI Environment:
- ✅ ComfyUI from official repository
- ✅ ComfyUI Manager for custom nodes
- ✅ Model directory structure
- ✅ Essential AI models (checkpoints, VAE, LoRAs, etc.)

### Python Packages:
- ✅ PyTorch with CUDA 12.8+ support
- ✅ torchvision, torchaudio
- ✅ xformers (memory-efficient attention)
- ✅ All ComfyUI dependencies

### System Tools:
- ✅ wget, curl, git
- ✅ ffmpeg (video processing)
- ✅ libgl1 (OpenGL support)

### Services:
- ✅ ComfyUI Web UI (Port 8188)
- ✅ Jupyter Lab (Port 8888, no auth)

---

## 🔧 Environment Variables (Optional)

Set these in Codex UI before starting:

| Variable | Default | Description |
|----------|---------|-------------|
| `DOWNLOAD_MODELS` | `true` | Auto-download AI models |
| `HF_TOKEN` | - | Hugging Face token (for gated models) |
| `COMFYUI_PORT` | `8188` | ComfyUI web interface port |
| `JUPYTER_PORT` | `8888` | Jupyter Lab port |

---

## 🧪 Testing After Setup

```bash
# Check ComfyUI
curl http://localhost:8188/queue

# Check Jupyter Lab
curl http://localhost:8888/

# List installed models
find /workspace/ComfyUI/models -name "*.safetensors" | wc -l

# View logs
tail -f /workspace/comfyui.log
```

---

## 🎨 Using ComfyUI in Codex

1. **Access Web UI:**
   - ComfyUI: `https://your-codex-url:8188`
   - Jupyter: `https://your-codex-url:8888`

2. **Load Workflows:**
   - Upload workflow JSON files
   - Use ComfyUI Manager to install custom nodes

3. **Generate Images:**
   - Configure your workflow
   - Queue prompts
   - Download results from output folder

---

## 📁 Directory Structure

```
/workspace/
├── ComfyUI/                    # Main ComfyUI installation
│   ├── models/                 # AI models
│   │   ├── checkpoints/        # Base models (SDXL, Flux, etc.)
│   │   ├── vae/                # VAE models
│   │   ├── loras/              # LoRA models
│   │   ├── controlnet/         # ControlNet models
│   │   ├── upscale_models/     # Upscaler models
│   │   ├── clip/               # CLIP models
│   │   └── unet/               # UNET models
│   ├── custom_nodes/           # Custom nodes
│   ├── output/                 # Generated images
│   └── input/                  # Input images
├── scripts/                    # Setup scripts
└── logs/                       # Log files
```

---

## 🚀 Advanced: Custom Model Downloads

Edit the model list in `scripts/download_models.py`:

```python
MODELS = {
    "checkpoints": [
        {
            "name": "your-model.safetensors",
            "url": "https://huggingface.co/...",
            "size": "6.5GB"
        }
    ]
}
```

Then run:
```bash
python3 /workspace/scripts/download_models.py
```

---

## 🐛 Troubleshooting

### ComfyUI not starting?
```bash
# Check logs
tail -50 /workspace/comfyui.log

# Restart ComfyUI
pkill -f "python.*main.py"
cd /workspace/ComfyUI && python3 main.py --listen 0.0.0.0 --port 8188
```

### Models not downloading?
```bash
# Check download log
tail -50 /workspace/model_download.log

# Manually download models
cd /workspace
python3 scripts/download_models.py
```

### Out of disk space?
```bash
# Check disk usage
df -h /workspace

# Clean up old outputs
rm -rf /workspace/ComfyUI/output/*

# Remove temp files
find /tmp -type f -mtime +1 -delete
```

### CUDA errors?
```bash
# Check GPU
nvidia-smi

# Verify CUDA version
python3 -c "import torch; print(f'CUDA: {torch.version.cuda}')"

# Check PyTorch GPU support
python3 -c "import torch; print(f'GPU Available: {torch.cuda.is_available()}')"
```

---

## 💡 Tips & Best Practices

- ✅ **Enable Container Caching** in Codex for faster restarts
- ✅ **Use Network Storage** for persistent model storage
- ✅ **Set HF_TOKEN** for accessing gated models (Flux, SDXL variants)
- ✅ **Monitor GPU usage** with `nvidia-smi` or `watch -n 1 nvidia-smi`
- ✅ **Save workflows** regularly (Download JSON from ComfyUI)
- ✅ **Use Jupyter** for batch processing and automation

---

## 🔄 Updating ComfyUI

```bash
cd /workspace/ComfyUI
git pull
pip install -r requirements.txt
```

---

## 📚 Resources

- **ComfyUI Docs:** https://github.com/comfyanonymous/ComfyUI
- **ComfyUI Manager:** https://github.com/ltdrdata/ComfyUI-Manager
- **Model Library:** See `comfyui_models_complete_library.md`
- **GPU Compatibility:** See `docs/gpu-compatibility.md`
- **Troubleshooting:** See `docs/troubleshooting.md`

---

## 🆘 Support

For issues or questions:
- Check logs: `/workspace/*.log`
- GitHub Issues: https://github.com/EcomTree/runpod-comfyui-cloud/issues
- RunPod Docs: https://docs.runpod.io/

---

**Created for Codex Environment** 🚀  
**Compatible with:** RunPod, Vast.ai, Lambda Labs, and other cloud GPU providers

