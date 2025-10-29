# ComfyUI Models Configuration

This document explains how to use the `models_download.json` file for automated model downloads.

## Overview

The `models_download.json` file contains a curated list of ~160+ ComfyUI-compatible models organized by category. The download system automatically detects and uses this JSON file (with fallback to the markdown library if needed).

## File Location

The `models_download.json` file should be located in the project root directory:
```
/Users/sebastianhein/Development/runpod-comfyui-cloud/models_download.json
```

In Docker containers, it's automatically copied to:
- Source: `/opt/runpod/models_download.json`
- Destination: `/workspace/models_download.json`

## Categories

The JSON file includes the following model categories:

### Image Generation
- **checkpoints**: SD1.5, SDXL, SD2.1, community fine-tunes (16 models)
- **unet**: FLUX.1 family, SD3.5, SD3 (22 models)
- **diffusion_models**: Alternative architectures (HunyuanDiT, Kolors, etc.) (10 models)
- **vae**: Variational autoencoders (8 models)
- **text_encoders**: CLIP and T5 encoders (9 models)

### Control & Style
- **controlnet**: ControlNet v1.1 and SDXL variants (22 models)
- **t2i_adapter**: T2I-Adapter models (4 models)
- **ipadapter**: IP-Adapter models for style transfer (10 models)
- **loras**: LoRA models (7 models)

### Enhancement
- **upscale_models**: ESRGAN, RealESRGAN, SwinIR, face restoration (12 models)
- **inpainting**: Specialized inpainting models (3 models)

### Video Generation
- **video_models**: CogVideoX, SVD, LTX, Mochi, HunyuanVideo, WanVideo (24 models)
- **animatediff**: AnimateDiff motion modules (7 models)

### Optimized Versions
- **flux_gguf**: Quantized FLUX.1 models (4 models)
- **sd35_gguf**: Quantized SD3.5 models (3 models)
- **wan_gguf**: Quantized WanVideo models (2 models)

### Vision & Utilities
- **clip_vision**: CLIP Vision encoders (4 models)
- **style_models**: (empty, reserved for future use)
- **clip**: (empty, reserved for future use)

## Usage

### Automatic Download

To enable automatic model downloads during container startup:

```bash
docker run -e DOWNLOAD_MODELS=true -e HF_TOKEN=<your-token> <image>
```

### Manual Download

You can also use the download scripts manually:

```bash
# Verify links first
python3 scripts/verify_links.py

# Download all models
python3 scripts/download_models.py /workspace
```

## File Structure

The JSON file follows this structure:

```json
{
  "category_name": [
    "https://huggingface.co/repo/model/resolve/main/model.safetensors",
    "https://huggingface.co/another/model/resolve/main/model.pth"
  ]
}
```

## How It Works

1. **Detection**: The `verify_links.py` script first looks for `models_download.json`
2. **Extraction**: All Hugging Face URLs are extracted from the JSON
3. **Verification**: Each link is checked for accessibility (HEAD request)
4. **Download**: Valid links are downloaded to the appropriate ComfyUI directories
5. **Classification**: Models are automatically sorted into the correct folders

## Model Classification

Models are automatically classified based on filename patterns:

| Pattern | Target Directory |
|---------|-----------------|
| `flux`, `sd3`, `auraflow` | `unet/` |
| `vae`, `kl-f8-anime` | `vae/` |
| `clip_vision` | `clip_vision/` |
| `controlnet`, `canny`, `depth` | `controlnet/` |
| `lora` | `loras/` |
| `esrgan`, `upscale` | `upscale_models/` |
| `animatediff` | `animatediff_models/` |
| `ip-adapter` | `ipadapter/` |
| `.safetensors`, `.ckpt` | `checkpoints/` (fallback) |

## Customization

You can customize the model list by editing `models_download.json`:

1. Add new URLs to existing categories
2. Remove unwanted models
3. Create new categories (requires updating classification logic)

### Example: Adding a New Model

```json
{
  "checkpoints": [
    "existing-model-url",
    "https://huggingface.co/your-repo/your-model/resolve/main/model.safetensors"
  ]
}
```

## Fallback Behavior

If `models_download.json` is not found, the system automatically falls back to:
- `comfyui_models_complete_library.md` (legacy markdown format)

This ensures backward compatibility.

## Storage Requirements

**Total Size**: ~400-500 GB for all models (varies based on quantization)

### Size Breakdown by Category:
- **Image Models (Full)**: ~150-200 GB
- **Image Models (FP8)**: ~75-100 GB
- **Video Models**: ~150-200 GB
- **ControlNets**: ~20-30 GB
- **Upscalers**: ~5-10 GB
- **LoRAs**: ~1-5 GB
- **Quantized (GGUF)**: ~50-100 GB

**Recommendation**: Use FP8 versions for GPU memory optimization.

## Performance Tips

1. **Use Quantized Models**: GGUF versions (Q4/Q5/Q8) reduce VRAM usage significantly
2. **FP8 Models**: ~50% smaller than FP16 with minimal quality loss
3. **Parallel Downloads**: Set `MAX_WORKERS=10` for faster downloads (default: 5)
4. **HF Token**: Required for some gated models (e.g., FLUX.1 Dev)

## Debugging

### Check Model Sources
```bash
# In container
ls -lh /opt/runpod/models_download.json
ls -lh /workspace/models_download.json
```

### Verify JSON Syntax
```bash
python3 -m json.tool models_download.json > /dev/null && echo "Valid JSON"
```

### Check Downloaded Models
```bash
# See download summary
cat /workspace/downloaded_models_summary.json

# List all downloaded models
find /workspace/ComfyUI/models -type f -name "*.safetensors" -o -name "*.ckpt" -o -name "*.pth"
```

## Related Files

- `comfyui_models_complete_library.md` - Comprehensive model documentation (legacy/reference)
- `scripts/verify_links.py` - Link verification script
- `scripts/download_models.py` - Model download script
- `docs/environment-variables.md` - Environment variable documentation

## License Information

Models have different licenses:
- **Apache 2.0**: FLUX.1 Schnell, most VAEs
- **FLUX.1 Dev License**: Non-commercial without enterprise license
- **Stability AI Community**: SD3.x (commercial < $1M revenue)
- **CreativeML OpenRAIL**: SD1.5/SDXL (open with restrictions)

**Always check individual model licenses before commercial use!**

## Support

For issues related to:
- Model downloads: Check `/workspace/model_download.log`
- Link verification: Run `python3 scripts/verify_links.py`
- Missing models: Rebuild container or manually copy `models_download.json`

## Updates

Last updated: October 2025

The model list is periodically updated. To get the latest:
```bash
git pull origin main
docker build -t your-image .
```
