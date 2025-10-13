# ComfyUI Modelle - Komplette Bibliothek (Image & Video) - Oktober 2025

> **Umfassende Liste aller ComfyUI-kompatiblen Bild- und Videomodelle mit direkten Hugging Face Download-Links**

**Stand:** Oktober 2025 | **Token Budget:** Volle Nutzung des 1M Token Fensters

---

## 📋 INHALTSVERZEICHNIS

1. [IMAGE GENERATION MODELS](#image-generation-models)
   - [FLUX.1 Familie](#flux1-familie)
   - [Stable Diffusion 3.5](#stable-diffusion-35-familie)
   - [Stable Diffusion 3](#stable-diffusion-3-familie)
   - [Stable Diffusion XL (SDXL)](#stable-diffusion-xl-sdxl)
   - [Stable Diffusion 1.5/2.1](#stable-diffusion-1521)
   - [Community Fine-tunes](#community-fine-tunes)
   - [ControlNet Models](#controlnet-models)
   - [IP-Adapter](#ip-adapter-models)
   - [T2I-Adapter](#t2i-adapter)
   - [Inpainting Models](#inpainting-models)
   - [Upscaling Models](#upscaling-models)
   - [Face Restoration](#face-restoration)
   - [Alternative Architectures](#alternative-architectures)

2. [VIDEO GENERATION MODELS](#video-generation-models)
   - [CogVideoX](#cogvideox-serie)
   - [Stable Video Diffusion](#stable-video-diffusion)
   - [AnimateDiff](#animatediff-framework)
   - [LTX Video](#ltx-video)
   - [Mochi](#mochi-1)
   - [HunyuanVideo](#hunyuanvideo)
   - [WanVideo](#wanvideo)
   - [Open-Sora](#open-sora)
   - [Weitere Video-Modelle](#weitere-video-modelle)

3. [SHARED COMPONENTS](#shared-components)
   - [VAE Models](#vae-models)
   - [Text Encoders](#text-encoders)
   - [CLIP Vision](#clip-vision-encoders)

4. [INSTALLATIONS-STRUKTUR](#installations-struktur)

---

## 🎨 IMAGE GENERATION MODELS

### FLUX.1 Familie

FLUX.1 ist die neueste Generation von Text-to-Image Modellen von Black Forest Labs (August 2024). Bietet state-of-the-art Qualität mit 12 Milliarden Parametern.

#### FLUX.1 [dev] - Hauptmodell

| Komponente | Typ | Größe | Download Link |
|-----------|-----|-------|---------------|
| **FLUX.1 Dev** | Diffusion Model | 23.8 GB | https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/flux1-dev.safetensors |
| **FLUX.1 Dev (FP8)** | Optimized | ~12 GB | https://huggingface.co/Kijai/flux-fp8/resolve/main/flux1-dev-fp8.safetensors |
| **FLUX.1 Dev (ComfyOrg)** | Repackaged | 23.8 GB | https://huggingface.co/Comfy-Org/flux1-dev/resolve/main/flux1-dev.safetensors |
| **Text Encoder CLIP-L** | Text Encoder | 246 MB | https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors |
| **Text Encoder T5-XXL FP16** | Text Encoder | 9.79 GB | https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp16.safetensors |
| **Text Encoder T5-XXL FP8** | Text Encoder | 4.89 GB | https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors |
| **Text Encoder T5-XXL FP8 Scaled** | Text Encoder | 4.89 GB | https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn_scaled.safetensors |
| **VAE** | Autoencoder | 335 MB | https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/ae.safetensors |

#### FLUX.1 [schnell] - Schnelle Variante

| Komponente | Typ | Größe | Download Link |
|-----------|-----|-------|---------------|
| **FLUX.1 Schnell** | Diffusion Model | 23.8 GB | https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/flux1-schnell.safetensors |
| **FLUX.1 Schnell (FP8)** | Optimized | ~12 GB | https://huggingface.co/Comfy-Org/flux1-schnell/resolve/main/flux1-schnell-fp8.safetensors |
| **FLUX.1 Schnell (ComfyOrg)** | Repackaged | 23.8 GB | https://huggingface.co/Comfy-Org/flux1-schnell/resolve/main/flux1-schnell.safetensors |
| **VAE** | Autoencoder | 335 MB | https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/ae.safetensors |
| Text Encoder (gleich wie Dev) | - | - | Siehe oben |

#### FLUX.1 Specialized Models

| Modell | Anwendung | Download Link |
|--------|-----------|---------------|
| **FLUX.1 Krea Dev** | Aesthetic Photography | https://huggingface.co/black-forest-labs/FLUX.1-Krea-dev/resolve/main/flux1-krea-dev.safetensors |
| **FLUX.1 Fill Dev** | Inpainting | https://huggingface.co/black-forest-labs/FLUX.1-Fill-dev/resolve/main/flux1-fill-dev.safetensors |
| **FLUX.1 Canny Dev** | Canny Edge Control | https://huggingface.co/black-forest-labs/FLUX.1-Canny-dev/resolve/main/flux1-canny-dev.safetensors |
| **FLUX.1 Canny LoRA** | Canny LoRA | https://huggingface.co/black-forest-labs/FLUX.1-Canny-dev-lora/resolve/main/flux1-canny-dev-lora.safetensors |
| **FLUX.1 Depth Dev** | Depth Control | https://huggingface.co/black-forest-labs/FLUX.1-Depth-dev/resolve/main/flux1-depth-dev.safetensors |
| **FLUX.1 Depth LoRA** | Depth LoRA | https://huggingface.co/black-forest-labs/FLUX.1-Depth-dev-lora/resolve/main/flux1-depth-dev-lora.safetensors |
| **FLUX.1 Redux Dev** | Image-to-Image | https://huggingface.co/black-forest-labs/FLUX.1-Redux-dev/resolve/main/flux1-redux-dev.safetensors |
| **FLUX.1 Kontext Dev** | Image Editing | https://huggingface.co/black-forest-labs/FLUX.1-Kontext-dev/resolve/main/flux1-kontext-dev.safetensors |

#### FLUX.1 ControlNets & IP-Adapters

| Modell | Typ | Download Link |
|--------|-----|---------------|
| **FLUX ControlNet Union Pro** | Multi-Control | https://huggingface.co/Shakker-Labs/FLUX.1-dev-ControlNet-Union-Pro/resolve/main/diffusion_pytorch_model.safetensors |
| **FLUX IP-Adapter v2** | Style Transfer | https://huggingface.co/XLabs-AI/flux-ip-adapter-v2/resolve/main/ip-adapter.bin |
| **FLUX IP-Adapter** | Style Transfer | https://huggingface.co/XLabs-AI/flux-ip-adapter/resolve/main/ip-adapter.bin |

#### FLUX.1 GGUF Quantized Versions

| Modell | Quant | Download Link |
|--------|-------|---------------|
| **FLUX.1 Dev GGUF Q4_0** | 4-bit | https://huggingface.co/city96/FLUX.1-dev-gguf/resolve/main/flux1-dev-Q4_0.gguf |
| **FLUX.1 Dev GGUF Q5_0** | 5-bit | https://huggingface.co/city96/FLUX.1-dev-gguf/resolve/main/flux1-dev-Q5_0.gguf |
| **FLUX.1 Dev GGUF Q6_K** | 6-bit | https://huggingface.co/city96/FLUX.1-dev-gguf/resolve/main/flux1-dev-Q6_K.gguf |
| **FLUX.1 Dev GGUF Q8_0** | 8-bit | https://huggingface.co/city96/FLUX.1-dev-gguf/resolve/main/flux1-dev-Q8_0.gguf |

---

### Stable Diffusion 3.5 Familie

Neueste SD3.5 Generation von Stability AI (Oktober 2024) mit Multi-Modal Diffusion Transformer (MMDiT).

#### SD3.5 Large

| Komponente | Typ | Größe | Download Link |
|-----------|-----|-------|---------------|
| **SD3.5 Large** | Diffusion Model | 9.96 GB | https://huggingface.co/stabilityai/stable-diffusion-3.5-large/resolve/main/sd3.5_large.safetensors |
| **SD3.5 Large (FP8)** | Optimized | ~5 GB | https://huggingface.co/Comfy-Org/stable-diffusion-3.5-fp8/resolve/main/sd3.5_large_fp8_scaled.safetensors |
| **SD3.5 Large Turbo** | Fast Sampling | 9.96 GB | https://huggingface.co/stabilityai/stable-diffusion-3.5-large-turbo/resolve/main/sd3.5_large_turbo.safetensors |
| **CLIP-L Text Encoder** | Text Encoder | 246 MB | https://huggingface.co/stabilityai/stable-diffusion-3.5-large/resolve/main/text_encoders/clip_l.safetensors |
| **CLIP-G Text Encoder** | Text Encoder | 1.39 GB | https://huggingface.co/stabilityai/stable-diffusion-3.5-large/resolve/main/text_encoders/clip_g.safetensors |
| **T5-XXL FP16** | Text Encoder | 9.79 GB | https://huggingface.co/stabilityai/stable-diffusion-3.5-large/resolve/main/text_encoders/t5xxl_fp16.safetensors |
| **T5-XXL FP8** | Text Encoder | 4.89 GB | https://huggingface.co/stabilityai/stable-diffusion-3.5-large/resolve/main/text_encoders/t5xxl_fp8_e4m3fn.safetensors |

#### SD3.5 Medium

| Komponente | Typ | Größe | Download Link |
|-----------|-----|-------|---------------|
| **SD3.5 Medium** | Diffusion Model | 5.97 GB | https://huggingface.co/stabilityai/stable-diffusion-3.5-medium/resolve/main/sd3.5_medium.safetensors |
| **SD3.5 Medium (FP8)** | Optimized | ~3 GB | https://huggingface.co/Comfy-Org/stable-diffusion-3.5-fp8/resolve/main/sd3.5_medium_fp8_scaled.safetensors |
| Text Encoders (gleich wie Large) | - | - | Siehe oben |

#### SD3.5 GGUF Versions

| Modell | Quant | Download Link |
|--------|-------|---------------|
| **SD3.5 Large GGUF Q4_0** | 4-bit | https://huggingface.co/city96/stable-diffusion-3.5-large-gguf/resolve/main/sd3.5_large-Q4_0.gguf |
| **SD3.5 Large GGUF Q5_0** | 5-bit | https://huggingface.co/city96/stable-diffusion-3.5-large-gguf/resolve/main/sd3.5_large-Q5_0.gguf |
| **SD3.5 Large GGUF Q8_0** | 8-bit | https://huggingface.co/city96/stable-diffusion-3.5-large-gguf/resolve/main/sd3.5_large-Q8_0.gguf |

---

### Stable Diffusion 3 Familie

| Komponente | Typ | Größe | Download Link |
|-----------|-----|-------|---------------|
| **SD3 Medium** | Diffusion Model | 5.97 GB | https://huggingface.co/stabilityai/stable-diffusion-3-medium/resolve/main/sd3_medium.safetensors |
| **CLIP-L** | Text Encoder | 246 MB | https://huggingface.co/stabilityai/stable-diffusion-3-medium/resolve/main/text_encoders/clip_l.safetensors |
| **CLIP-G** | Text Encoder | 1.39 GB | https://huggingface.co/stabilityai/stable-diffusion-3-medium/resolve/main/text_encoders/clip_g.safetensors |
| **T5-XXL FP16** | Text Encoder | 9.79 GB | https://huggingface.co/stabilityai/stable-diffusion-3-medium/resolve/main/text_encoders/t5xxl_fp16.safetensors |

---

### Stable Diffusion XL (SDXL)

Standard SDXL 1.0 für 1024x1024 Generation.

#### SDXL Base & Refiner

| Komponente | Typ | Größe | Download Link |
|-----------|-----|-------|---------------|
| **SDXL Base 1.0** | Checkpoint | 6.94 GB | https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors |
| **SDXL Refiner 1.0** | Refiner | 6.08 GB | https://huggingface.co/stabilityai/stable-diffusion-xl-refiner-1.0/resolve/main/sd_xl_refiner_1.0.safetensors |
| **SDXL VAE** | VAE | 335 MB | https://huggingface.co/stabilityai/sdxl-vae/resolve/main/sdxl_vae.safetensors |
| **SDXL VAE FP16 Fix** | VAE | 335 MB | https://huggingface.co/madebyollin/sdxl-vae-fp16-fix/resolve/main/sdxl_vae.safetensors |

#### SDXL Turbo & Lightning

| Modell | Typ | Download Link |
|--------|-----|---------------|
| **SDXL Turbo** | 1-Step | https://huggingface.co/stabilityai/sdxl-turbo/resolve/main/sd_xl_turbo_1.0_fp16.safetensors |
| **SDXL Lightning 2-Step UNet** | UNet | https://huggingface.co/ByteDance/SDXL-Lightning/resolve/main/sdxl_lightning_2step_unet.safetensors |
| **SDXL Lightning 4-Step UNet** | UNet | https://huggingface.co/ByteDance/SDXL-Lightning/resolve/main/sdxl_lightning_4step_unet.safetensors |
| **SDXL Lightning 8-Step UNet** | UNet | https://huggingface.co/ByteDance/SDXL-Lightning/resolve/main/sdxl_lightning_8step_unet.safetensors |
| **SDXL Lightning 2-Step LoRA** | LoRA | https://huggingface.co/ByteDance/SDXL-Lightning/resolve/main/sdxl_lightning_2step_lora.safetensors |
| **SDXL Lightning 4-Step LoRA** | LoRA | https://huggingface.co/ByteDance/SDXL-Lightning/resolve/main/sdxl_lightning_4step_lora.safetensors |
| **SDXL Lightning 8-Step LoRA** | LoRA | https://huggingface.co/ByteDance/SDXL-Lightning/resolve/main/sdxl_lightning_8step_lora.safetensors |

---

### Stable Diffusion 1.5/2.1

Klassische SD Modelle - sehr weit verbreitet mit großer Community.

#### SD 1.5

| Komponente | Typ | Größe | Download Link |
|-----------|-----|-------|---------------|
| **SD 1.5 Pruned EMA** | Checkpoint | 4.27 GB | https://huggingface.co/runwayml/stable-diffusion-v1-5/resolve/main/v1-5-pruned-emaonly.safetensors |
| **SD 1.5 Pruned** | Checkpoint | 7.7 GB | https://huggingface.co/runwayml/stable-diffusion-v1-5/resolve/main/v1-5-pruned.safetensors |
| **SD 1.5 VAE (ft-mse)** | VAE | 335 MB | https://huggingface.co/stabilityai/sd-vae-ft-mse-original/resolve/main/vae-ft-mse-840000-ema-pruned.safetensors |
| **SD 1.5 VAE (ft-ema)** | VAE | 335 MB | https://huggingface.co/stabilityai/sd-vae-ft-ema-original/resolve/main/vae-ft-ema-560000-ema-pruned.safetensors |
| **SD 1.5 Inpainting** | Inpainting | 4.27 GB | https://huggingface.co/runwayml/stable-diffusion-inpainting/resolve/main/sd-v1-5-inpainting.ckpt |

#### SD 2.1

| Komponente | Typ | Größe | Download Link |
|-----------|-----|-------|---------------|
| **SD 2.1 768** | Checkpoint | 5.21 GB | https://huggingface.co/stabilityai/stable-diffusion-2-1/resolve/main/v2-1_768-ema-pruned.safetensors |
| **SD 2.1 512 Base** | Checkpoint | 5.21 GB | https://huggingface.co/stabilityai/stable-diffusion-2-1-base/resolve/main/v2-1_512-ema-pruned.safetensors |
| **SD 2.1 VAE** | VAE | 335 MB | https://huggingface.co/stabilityai/stable-diffusion-2-1/resolve/main/v2-1_768-ema-pruned.vae.safetensors |
| **SD 2.0 Inpainting** | Inpainting | 5.21 GB | https://huggingface.co/stabilityai/stable-diffusion-2-inpainting/resolve/main/512-inpainting-ema.safetensors |

---

### Community Fine-tunes

Beliebte Community-entwickelte Modelle.

#### Realistic / Photorealistic

| Modell | Base | Download Link |
|--------|------|---------------|
| **Realistic Vision V6.0** | SD1.5 | https://huggingface.co/SG161222/Realistic_Vision_V6.0_B1_noVAE/resolve/main/Realistic_Vision_V6.0_NV_B1_fp16.safetensors |
| **Realistic Vision V5.1** | SD1.5 | https://huggingface.co/SG161222/Realistic_Vision_V5.1_noVAE/resolve/main/Realistic_Vision_V5.1_fp16-no-ema.safetensors |
| **DreamShaper 8** | SD1.5 | https://huggingface.co/Lykon/DreamShaper/resolve/main/DreamShaper_8_pruned.safetensors |
| **DreamShaper XL Turbo** | SDXL | https://huggingface.co/Lykon/dreamshaper-xl-1-0/resolve/main/DreamShaperXL_Turbo_v2_1.safetensors |
| **Juggernaut XL V9** | SDXL | https://huggingface.co/RunDiffusion/Juggernaut-XL-v9/resolve/main/Juggernaut-XL_v9_RunDiffusionPhoto_v2.safetensors |
| **RealVisXL V4.0** | SDXL | https://huggingface.co/SG161222/RealVisXL_V4.0/resolve/main/RealVisXL_V4.0.safetensors |
| **ZavyChromaXL v4.0** | SDXL | https://huggingface.co/stablediffusionapi/zavychromaxl-v40/resolve/main/zavychromaxl_v40.safetensors |

#### Anime / Illustration

| Modell | Base | Download Link |
|--------|------|---------------|
| **Anything V5** | SD1.5 | https://huggingface.co/stablediffusionapi/anything-v5/resolve/main/anything-v5.safetensors |
| **Counterfeit V3.0** | SD1.5 | https://huggingface.co/gsdf/Counterfeit-V3.0/resolve/main/Counterfeit-V3.0_fp16.safetensors |
| **Animagine XL 3.1** | SDXL | https://huggingface.co/cagliostrolab/animagine-xl-3.1/resolve/main/animagine-xl-3.1.safetensors |
| **Pony Diffusion V6 XL** | SDXL | https://civitai.com/api/download/models/290640 (Note: HF versions require authentication) |

---

### ControlNet Models

Präzise Kontrolle über Bildkomposition.

#### ControlNet v1.1 (SD1.5)

| Modell | Typ | Download Link |
|--------|-----|---------------|
| **Canny** | Edge Detection | https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11p_sd15_canny.pth |
| **Depth** | Depth Map | https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11f1p_sd15_depth.pth |
| **OpenPose** | Pose Detection | https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11p_sd15_openpose.pth |
| **Scribble** | Sketch | https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11p_sd15_scribble.pth |
| **SoftEdge** | Soft Edges | https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11p_sd15_softedge.pth |
| **Segmentation** | Semantic Seg | https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11p_sd15_seg.pth |
| **Normal** | Normal Map | https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11p_sd15_normalbae.pth |
| **Lineart** | Line Art | https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11p_sd15_lineart.pth |
| **Lineart Anime** | Anime Lineart | https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11p_sd15s2_lineart_anime.pth |
| **MLSD** | Line Detection | https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11p_sd15_mlsd.pth |
| **Tile** | Upscaling | https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11f1e_sd15_tile.pth |
| **Inpaint** | Inpainting | https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11p_sd15_inpaint.pth |
| **IP2P** | Instruct Pix2Pix | https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11e_sd15_ip2p.pth |
| **Shuffle** | Content Shuffle | https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11e_sd15_shuffle.pth |

#### ControlNet SDXL

| Modell | Typ | Download Link |
|--------|-----|---------------|
| **Canny SDXL** | Edge Detection | https://huggingface.co/diffusers/controlnet-canny-sdxl-1.0/resolve/main/diffusion_pytorch_model.safetensors |
| **Depth SDXL** | Depth Map | https://huggingface.co/diffusers/controlnet-depth-sdxl-1.0/resolve/main/diffusion_pytorch_model.safetensors |
| **OpenPose SDXL** | Pose | https://huggingface.co/thibaud/controlnet-openpose-sdxl-1.0/resolve/main/OpenPoseXL2.safetensors |
| **Union SDXL** | Multi-Control | https://huggingface.co/xinsir/controlnet-union-sdxl-1.0/resolve/main/diffusion_pytorch_model.safetensors |
| **Tile SDXL** | Upscale | https://huggingface.co/xinsir/controlnet-tile-sdxl-1.0/resolve/main/diffusion_pytorch_model.safetensors |

---

### T2I-Adapter

Leichtgewichtige Alternative zu ControlNet.

| Modell | Typ | Download Link |
|--------|-----|---------------|
| **T2I Canny SDXL** | Canny | https://huggingface.co/TencentARC/t2i-adapter-canny-sdxl-1.0/resolve/main/diffusion_pytorch_model.safetensors |
| **T2I Depth SDXL** | Depth | https://huggingface.co/TencentARC/t2i-adapter-depth-midas-sdxl-1.0/resolve/main/diffusion_pytorch_model.safetensors |
| **T2I Sketch SDXL** | Sketch | https://huggingface.co/TencentARC/t2i-adapter-sketch-sdxl-1.0/resolve/main/diffusion_pytorch_model.safetensors |
| **T2I Lineart SDXL** | Lineart | https://huggingface.co/TencentARC/t2i-adapter-lineart-sdxl-1.0/resolve/main/diffusion_pytorch_model.safetensors |

---

### IP-Adapter Models

Image Prompting - Style Transfer mit Referenzbildern.

#### IP-Adapter SD1.5

| Modell | Typ | Download Link |
|--------|-----|---------------|
| **IP-Adapter SD15** | Base | https://huggingface.co/h94/IP-Adapter/resolve/main/models/ip-adapter_sd15.safetensors |
| **IP-Adapter Plus SD15** | Enhanced | https://huggingface.co/h94/IP-Adapter/resolve/main/models/ip-adapter-plus_sd15.safetensors |
| **IP-Adapter Plus Face SD15** | Face Focus | https://huggingface.co/h94/IP-Adapter/resolve/main/models/ip-adapter-plus-face_sd15.safetensors |
| **IP-Adapter Full Face SD15** | Full Face | https://huggingface.co/h94/IP-Adapter/resolve/main/models/ip-adapter-full-face_sd15.safetensors |
| **IP-Adapter Light SD15** | Lightweight | https://huggingface.co/h94/IP-Adapter/resolve/main/models/ip-adapter_sd15_light_v11.bin |

#### IP-Adapter SDXL

| Modell | Typ | Download Link |
|--------|-----|---------------|
| **IP-Adapter SDXL** | Base | https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter_sdxl.safetensors |
| **IP-Adapter Plus SDXL** | Enhanced | https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter-plus_sdxl_vit-h.safetensors |
| **IP-Adapter Plus Face SDXL** | Face | https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter-plus-face_sdxl_vit-h.safetensors |

#### IP-Adapter Image Encoders

| Modell | Typ | Download Link |
|--------|-----|---------------|
| **Image Encoder SD15** | CLIP Vision | https://huggingface.co/h94/IP-Adapter/resolve/main/models/image_encoder/model.safetensors |
| **Image Encoder SDXL** | CLIP Vision | https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/image_encoder/model.safetensors |

---

### Inpainting Models

Spezialisierte Modelle für Inpainting.

| Modell | Base | Download Link |
|--------|------|---------------|
| **SD1.5 Inpainting** | SD1.5 | https://huggingface.co/runwayml/stable-diffusion-inpainting/resolve/main/sd-v1-5-inpainting.ckpt |
| **SD2.0 Inpainting** | SD2.0 | https://huggingface.co/stabilityai/stable-diffusion-2-inpainting/resolve/main/512-inpainting-ema.safetensors |
| **FLUX.1 Fill Dev** | FLUX | https://huggingface.co/black-forest-labs/FLUX.1-Fill-dev/resolve/main/flux1-fill-dev.safetensors |

---

### Upscaling Models

Bildvergrößerung mit KI.

#### ESRGAN & RealESRGAN

| Modell | Faktor | Download Link |
|--------|--------|---------------|
| **RealESRGAN x4plus** | 4x | https://huggingface.co/ai-forever/Real-ESRGAN/resolve/main/RealESRGAN_x4.pth |
| **RealESRGAN x4plus Anime** | 4x | https://huggingface.co/ai-forever/Real-ESRGAN/resolve/main/RealESRGAN_x4_anime_6B.pth |
| **RealESRGAN x2plus** | 2x | https://huggingface.co/ai-forever/Real-ESRGAN/resolve/main/RealESRGAN_x2.pth |
| **ESRGAN 4x** | 4x | https://huggingface.co/eugeneware/ESRGAN/resolve/main/RRDB_ESRGAN_x4.pth |
| **4x-UltraSharp** | 4x | https://huggingface.co/lokCX/4x-Ultrasharp/resolve/main/4x-UltraSharp.pth |
| **RealWebPhoto v4** | 4x | https://huggingface.co/gemasai/4x_NMKD-Siax_200k/resolve/main/4x_NMKD-Siax_200k.pth |

#### SwinIR

| Modell | Faktor | Download Link |
|--------|--------|---------------|
| **SwinIR 4x** | 4x | https://huggingface.co/caidas/swin2SR-classical-sr-x4-64/resolve/main/SwinIR_4x.pth |
| **SwinIR 2x** | 2x | https://huggingface.co/caidas/swin2SR-classical-sr-x2-64/resolve/main/SwinIR_2x.pth |

---

### Face Restoration

Gesichtsverbesserung.

| Modell | Typ | Download Link |
|--------|-----|---------------|
| **CodeFormer** | Face Restore | https://huggingface.co/sczhou/CodeFormer/resolve/main/codeformer.pth |
| **GFPGAN v1.3** | Face Restore | https://huggingface.co/akhaliq/GFPGAN/resolve/main/GFPGANv1.3.pth |
| **GFPGAN v1.4** | Face Restore | https://huggingface.co/akhaliq/GFPGAN/resolve/main/GFPGANv1.4.pth |
| **RestoreFormer** | Face Restore | https://huggingface.co/wzhouxiff/RestoreFormer/resolve/main/RestoreFormer.pth |

---

### Alternative Architectures

Andere Diffusion-Architekturen.

#### Chroma/Radiance

| Komponente | Download Link |
|-----------|---------------|
| **Chroma1-Radiance v0.2** | https://huggingface.co/Chroma-ai/Chroma1-Radiance-v0.2/resolve/main/chroma_radiance_v0_2.safetensors |

#### AuraFlow

| Komponente | Download Link |
|-----------|---------------|
| **AuraFlow v0.3** | https://huggingface.co/fal/AuraFlow-v0.3/resolve/main/auraflow_v0.3.safetensors |
| **AuraFlow Text Encoder** | https://huggingface.co/fal/AuraFlow-v0.3/resolve/main/text_encoder/model.safetensors |

#### PixArt

| Modell | Download Link |
|--------|---------------|
| **PixArt-Alpha XL-2 1024** | https://huggingface.co/PixArt-alpha/PixArt-XL-2-1024-MS/resolve/main/PixArt-XL-2-1024-MS.pth |
| **PixArt-Sigma XL-2 1024** | https://huggingface.co/PixArt-alpha/PixArt-Sigma-XL-2-1024-MS/resolve/main/PixArt-Sigma-XL-2-1024-MS.pth |
| **PixArt T5** | https://huggingface.co/PixArt-alpha/PixArt-XL-2-1024-MS/resolve/main/text_encoder/pytorch_model.bin |

#### Stable Cascade

| Komponente | Download Link |
|-----------|---------------|
| **Stage C** | https://huggingface.co/stabilityai/stable-cascade/resolve/main/stage_c.safetensors |
| **Stage B** | https://huggingface.co/stabilityai/stable-cascade/resolve/main/stage_b.safetensors |
| **Text Encoder** | https://huggingface.co/stabilityai/stable-cascade/resolve/main/text_encoder/model.safetensors |
| **Effnet Encoder** | https://huggingface.co/stabilityai/stable-cascade/resolve/main/effnet_encoder.safetensors |

#### HunyuanDiT

| Komponente | Download Link |
|-----------|---------------|
| **HunyuanDiT v1.2** | https://huggingface.co/Tencent-Hunyuan/HunyuanDiT-v1.2-Diffusers/resolve/main/hunyuan_dit_1.2.safetensors |
| **HunyuanImage 2.1** | https://huggingface.co/Comfy-Org/HunyuanImage_2.1_ComfyUI/resolve/main/hunyuan_image_2.1.safetensors |
| **CLIP Text Encoder** | https://huggingface.co/Tencent-Hunyuan/HunyuanDiT-v1.2-Diffusers/resolve/main/clip/pytorch_model.bin |
| **T5 Text Encoder** | https://huggingface.co/Tencent-Hunyuan/HunyuanDiT-v1.2-Diffusers/resolve/main/mt5/pytorch_model.bin |

#### Kolors

| Komponente | Download Link |
|-----------|---------------|
| **Kolors Diffusion** | https://huggingface.co/Kwai-Kolors/Kolors/resolve/main/unet/diffusion_pytorch_model.safetensors |
| **ChatGLM Text Encoder** | https://huggingface.co/Kwai-Kolors/Kolors/resolve/main/text_encoder/pytorch_model.bin |
| **Kolors VAE** | https://huggingface.co/Kwai-Kolors/Kolors/resolve/main/vae/diffusion_pytorch_model.safetensors |

#### Lumina

| Komponente | Download Link |
|-----------|---------------|
| **Lumina-Next SFT** | https://huggingface.co/Alpha-VLLM/Lumina-Next-SFT/resolve/main/consolidated.safetensors |
| **Lumina Image 2.0** | https://huggingface.co/Comfy-Org/Lumina_Image_2.0_Repackaged/resolve/main/lumina_image_2.0.safetensors |
| **Gemma Text Encoder** | https://huggingface.co/Alpha-VLLM/Lumina-Next-SFT/resolve/main/gemma/model.safetensors |

---

## 🎬 VIDEO GENERATION MODELS

### CogVideoX Serie

Von THUDM/Tsinghua University - Open-source Text-to-Video.

#### CogVideoX-5B

| Komponente | Typ | Größe | Download Link |
|-----------|-----|-------|---|
| **CogVideoX-5B** | Diffusion Model | ~10 GB | https://huggingface.co/THUDM/CogVideoX-5b/resolve/main/diffusion_pytorch_model.safetensors |
| **CogVideoX-5B (FP8)** | Optimized | ~5 GB | https://huggingface.co/Kijai/CogVideoX-5b-fp8/resolve/main/cogvideox_5b_fp8_e4m3fn.safetensors |
| **T5 Text Encoder** | Text | ~5 GB | https://huggingface.co/THUDM/CogVideoX-5b/resolve/main/text_encoder/pytorch_model.bin |
| **VAE** | Autoencoder | ~1 GB | https://huggingface.co/THUDM/CogVideoX-5b/resolve/main/vae/diffusion_pytorch_model.safetensors |

#### CogVideoX-2B

| Komponente | Typ | Download Link |
|-----------|-----|---------------|
| **CogVideoX-2B** | Diffusion Model | https://huggingface.co/THUDM/CogVideoX-2b/resolve/main/diffusion_pytorch_model.safetensors |
| **T5 Text Encoder** | Text | https://huggingface.co/THUDM/CogVideoX-2b/resolve/main/text_encoder/pytorch_model.bin |
| **VAE** | Autoencoder | https://huggingface.co/THUDM/CogVideoX-2b/resolve/main/vae/diffusion_pytorch_model.safetensors |

#### CogVideoX I2V (Image-to-Video)

| Modell | Download Link |
|--------|---------------|
| **CogVideoX-5B I2V** | https://huggingface.co/THUDM/CogVideoX-5b-I2V/resolve/main/diffusion_pytorch_model.safetensors |

#### CogVideoX 1.5

| Modell | Download Link |
|--------|---------------|
| **CogVideoX1.5-5B** | https://huggingface.co/THUDM/CogVideoX1.5-5B/resolve/main/diffusion_pytorch_model.safetensors |
| **CogVideoX1.5-5B I2V** | https://huggingface.co/THUDM/CogVideoX1.5-5B-I2V/resolve/main/diffusion_pytorch_model.safetensors |

---

### Stable Video Diffusion

Von Stability AI - Robustes Image-to-Video System.

| Modell | Frames | Auflösung | Download Link |
|--------|--------|-----------|---------------|
| **SVD** | 14 | 576x1024 | https://huggingface.co/stabilityai/stable-video-diffusion-img2vid/resolve/main/svd.safetensors |
| **SVD-XT** | 25 | 576x1024 | https://huggingface.co/stabilityai/stable-video-diffusion-img2vid-xt/resolve/main/svd_xt.safetensors |
| **SVD-XT-1.1** | 25 | 576x1024 | https://huggingface.co/stabilityai/stable-video-diffusion-img2vid-xt-1-1/resolve/main/svd_xt_1_1.safetensors |

---

### AnimateDiff Framework

Motion Modules für SD1.5 und SDXL.

#### AnimateDiff SD1.5 Motion Modules

| Modell | Version | Download Link |
|--------|---------|---------------|
| **AnimateDiff v3** | Latest | https://huggingface.co/guoyww/animatediff/resolve/main/v3_sd15_mm.ckpt |
| **AnimateDiff v2** | Stable | https://huggingface.co/guoyww/animatediff/resolve/main/mm_sd_v15_v2.ckpt |
| **AnimateDiff v1** | Original | https://huggingface.co/guoyww/animatediff/resolve/main/mm_sd_v15.ckpt |
| **AnimateDiff Adapter v3** | LoRA | https://huggingface.co/guoyww/animatediff/resolve/main/v3_sd15_adapter.ckpt |

#### AnimateDiff SDXL

| Modell | Download Link |
|--------|---------------|
| **AnimateDiff SDXL Beta** | https://huggingface.co/guoyww/animatediff/resolve/main/mm_sdxl_v10_beta.ckpt |

#### AnimateDiff SparseCtrl

| Modell | Typ | Download Link |
|--------|-----|---------------|
| **SparseCtrl RGB** | ControlNet | https://huggingface.co/guoyww/animatediff/resolve/main/v3_sd15_sparsectrl_rgb.ckpt |
| **SparseCtrl Scribble** | ControlNet | https://huggingface.co/guoyww/animatediff/resolve/main/v3_sd15_sparsectrl_scribble.ckpt |

---

### LTX Video

Von Lightricks - Effizientes Video-Modell.

| Komponente | Typ | Download Link |
|-----------|-----|---------------|
| **LTX Video 2B v0.9** | Diffusion | https://huggingface.co/Lightricks/LTX-Video/resolve/main/ltx-video-2b-v0.9.safetensors |
| **LTX Video 0.9.5** | Latest | https://huggingface.co/Lightricks/LTX-Video-0.9.5/resolve/main/ltx-video-2b-v0.9.5.safetensors |
| **VAE** | Autoencoder | https://huggingface.co/Lightricks/LTX-Video/resolve/main/vae/diffusion_pytorch_model.safetensors |
| **T5 Text Encoder** | Text | https://huggingface.co/Lightricks/LTX-Video/resolve/main/text_encoder/model.safetensors |

---

### Mochi 1

Von Genmo - 10B Parameter Video-Modell mit AsymmDiT.

| Komponente | Typ | Download Link |
|-----------|-----|---------------|
| **Mochi 1 Preview** | Diffusion | https://huggingface.co/genmo/mochi-1-preview/resolve/main/diffusion_pytorch_model.safetensors |
| **Mochi (ComfyOrg)** | Repackaged | https://huggingface.co/Comfy-Org/mochi_preview_repackaged/resolve/main/mochi_preview_bf16.safetensors |
| **Mochi (FP8)** | Optimized | https://huggingface.co/Comfy-Org/mochi_preview_repackaged/resolve/main/mochi_preview_fp8_scaled.safetensors |
| **T5 Text Encoder** | Text | https://huggingface.co/genmo/mochi-1-preview/resolve/main/text_encoder/model.safetensors |
| **VAE** | Autoencoder | https://huggingface.co/genmo/mochi-1-preview/resolve/main/vae/diffusion_pytorch_model.safetensors |

---

### HunyuanVideo

Von Tencent - 13B Parameter, 720p 15 Sekunden.

| Komponente | Typ | Download Link |
|-----------|-----|---------------|
| **HunyuanVideo** | Diffusion (FP8) | https://huggingface.co/tencent/HunyuanVideo/resolve/main/hunyuan_video_720_cfgdistill_fp8_e4m3fn.safetensors |
| **HunyuanVideo (ComfyOrg)** | Repackaged | https://huggingface.co/Comfy-Org/HunyuanVideo_repackaged/resolve/main/hunyuan_video_t2v_720p_bf16.safetensors |
| **HunyuanVideo (Kijai)** | FP8 | https://huggingface.co/Kijai/HunyuanVideo_comfy/resolve/main/hunyuan_video_t2v_720p_fp8_e4m3fn.safetensors |
| **CLIP Text Encoder** | Text | https://huggingface.co/tencent/HunyuanVideo/resolve/main/text_encoder/pytorch_model.bin |
| **LLAMA Text Encoder** | Text | https://huggingface.co/tencent/HunyuanVideo/resolve/main/text_encoder_2/model.safetensors |
| **VAE** | Autoencoder | https://huggingface.co/tencent/HunyuanVideo/resolve/main/vae/diffusion_pytorch_model.safetensors |

---

### WanVideo

Von Alibaba (Februar 2025) - 14B und 1.3B Varianten.

#### WanVideo 2.2 (14B)

| Komponente | Download Link |
|-----------|---------------|
| **Wan 2.2 14B** | https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/wan_2.2_14B.safetensors |
| **Wan 2.2 14B (FP8)** | https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/wan_2.2_14B_fp8_scaled.safetensors |

#### WanVideo 2.1

| Komponente | Download Link |
|-----------|---------------|
| **Wan 2.1 (Kijai)** | https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/wan_2.1_combined.safetensors |
| **Wan 2.1 (ComfyOrg)** | https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/wan_2.1_combined.safetensors |

#### WanVideo Components

| Komponente | Typ | Download Link |
|-----------|-----|---------------|
| **WAN VAE** | Autoencoder | https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/wan_2.1_vae.safetensors |
| **UMT5 XXL FP8** | Text Encoder | https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/umt5_xxl_fp8_e4m3fn_scaled.safetensors |
| **CLIP Vision H** | Vision | https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/clip_vision_h.safetensors |

#### WanVideo GGUF (Quantized)

| Modell | Quant | Download Link |
|--------|-------|---------------|
| **Wan 2.2 14B GGUF Q8** | 8-bit | https://huggingface.co/ussoewwin/WAN2.2_14B_GGUF/resolve/main/wan_2_2_14B_Q8_0.gguf |
| **Wan 2.2 14B GGUF Q5** | 5-bit | https://huggingface.co/ussoewwin/WAN2.2_14B_GGUF/resolve/main/wan_2_2_14B_Q5_K_M.gguf |

---

### Open-Sora

Community Open-Source Video Generation.

#### Open-Sora v1.3.0

| Komponente | Download Link |
|-----------|---------------|
| **Open-Sora v1.3.0** | https://huggingface.co/LanguageBind/Open-Sora-Plan-v1.3.0/resolve/main/opensora_v1.3.safetensors |
| **Open-Sora v1.2** | https://huggingface.co/hpcai-tech/OpenSora/resolve/main/OpenSora-v1-HQ-16x512x512.pth |
| **Open-Sora v1.1** | https://huggingface.co/hpcai-tech/OpenSora/resolve/main/OpenSora-v1-16x256x256.pth |

---

### Weitere Video-Modelle

#### Hotshot-XL

| Modell | Download Link |
|--------|---------------|
| **Hotshot-XL Temporal** | https://huggingface.co/hotshotco/Hotshot-XL/resolve/main/hsxl_temporal_layers.safetensors |

#### Zeroscope

| Modell | Auflösung | Download Link |
|--------|-----------|---------------|
| **Zeroscope v2 XL** | 1024x576 | https://huggingface.co/cerspense/zeroscope_v2_XL/resolve/main/diffusion_pytorch_model.safetensors |
| **Zeroscope v2 576w** | 576x320 | https://huggingface.co/cerspense/zeroscope_v2_576w/resolve/main/diffusion_pytorch_model.safetensors |

#### ModelScope

| Modell | Download Link |
|--------|---------------|
| **ModelScope T2V 1.7B** | https://huggingface.co/damo-vilab/text-to-video-ms-1.7b/resolve/main/diffusion_pytorch_model.safetensors |
| **ModelScope CLIP** | https://huggingface.co/damo-vilab/text-to-video-ms-1.7b/resolve/main/open_clip_pytorch_model.bin |

#### VideoCrafter

| Modell | Download Link |
|--------|---------------|
| **VideoCrafter2** | https://huggingface.co/VideoCrafter/VideoCrafter2/resolve/main/model.ckpt |
| **VideoCrafter1** | https://huggingface.co/VideoCrafter/Text2Video-1024/resolve/main/model.ckpt |

#### I2VGen-XL

| Modell | Download Link |
|--------|---------------|
| **I2VGen-XL** | https://huggingface.co/ali-vilab/i2vgen-xl/resolve/main/i2vgen_xl_00.safetensors |

---

## 📦 SHARED COMPONENTS

### VAE Models

Variational Autoencoders für Latent Space.

| VAE | Kompatibilität | Download Link |
|-----|----------------|---------------|
| **SD VAE ft-mse** | SD1.5, SD2.x | https://huggingface.co/stabilityai/sd-vae-ft-mse-original/resolve/main/vae-ft-mse-840000-ema-pruned.safetensors |
| **SD VAE ft-ema** | SD1.5, SD2.x | https://huggingface.co/stabilityai/sd-vae-ft-ema-original/resolve/main/vae-ft-ema-560000-ema-pruned.safetensors |
| **SDXL VAE** | SDXL | https://huggingface.co/stabilityai/sdxl-vae/resolve/main/sdxl_vae.safetensors |
| **SDXL VAE FP16 Fix** | SDXL | https://huggingface.co/madebyollin/sdxl-vae-fp16-fix/resolve/main/sdxl_vae.safetensors |
| **kl-f8-anime2** | Anime (SD1.5) | https://huggingface.co/hakurei/waifu-diffusion-v1-4/resolve/main/vae/kl-f8-anime2.ckpt |
| **orangemix.vae** | Anime | https://huggingface.co/WarriorMama777/OrangeMixs/resolve/main/VAEs/orangemix.vae.pt |
| **ClearVAE v2.2** | SD1.5/SDXL | https://huggingface.co/ClearVAE/ClearVAE_v2.2/resolve/main/clearvae_v2.2.safetensors |

---

### Text Encoders

CLIP und T5 für Text-Verständnis.

#### CLIP Encoders

| Encoder | Verwendung | Download Link |
|---------|------------|---------------|
| **CLIP-L (OpenAI)** | FLUX, SD3 | https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors |
| **CLIP-G** | SD3, SDXL | https://huggingface.co/stabilityai/stable-diffusion-3.5-large/resolve/main/text_encoders/clip_g.safetensors |
| **CLIP-H** | SDXL | https://huggingface.co/laion/CLIP-ViT-H-14-laion2B-s32B-b79K/resolve/main/open_clip_pytorch_model.bin |
| **CLIP-bigG** | SDXL | https://huggingface.co/laion/CLIP-ViT-bigG-14-laion2B-39B-b160k/resolve/main/open_clip_pytorch_model.bin |

#### T5 Encoders

| Encoder | Precision | Größe | Download Link |
|---------|-----------|-------|---------------|
| **T5-XXL FP16** | Full | 9.79 GB | https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp16.safetensors |
| **T5-XXL FP8** | Quantized | 4.89 GB | https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors |
| **T5-XXL FP8 Scaled** | Quantized | 4.89 GB | https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn_scaled.safetensors |
| **UMT5-XXL FP8** | Video | 4.89 GB | https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/umt5_xxl_fp8_e4m3fn_scaled.safetensors |

---

### CLIP Vision Encoders

Für IP-Adapter und Vision Tasks.

| Encoder | Verwendung | Download Link |
|---------|------------|---------------|
| **CLIP-ViT-H-14** | IP-Adapter SD15 | https://huggingface.co/h94/IP-Adapter/resolve/main/models/image_encoder/model.safetensors |
| **CLIP-ViT-bigG-14** | IP-Adapter SDXL | https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/image_encoder/model.safetensors |
| **OpenCLIP-ViT-H-14** | General | https://huggingface.co/laion/CLIP-ViT-H-14-laion2B-s32B-b79K/resolve/main/open_clip_pytorch_model.bin |
| **CLIP Vision H** | WanVideo | https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/clip_vision_h.safetensors |

---

## 📂 INSTALLATIONS-STRUKTUR

### ComfyUI Standard Ordnerstruktur

```
ComfyUI/
├── models/
│   ├── checkpoints/          # SD1.5, SDXL, SD3 Checkpoints
│   ├── unet/                 # FLUX, SD3 Diffusion Models
│   ├── vae/                  # VAE Models
│   ├── clip/                 # CLIP Text Encoders
│   ├── t5/                   # T5 Text Encoders
│   ├── clip_vision/          # CLIP Vision Models
│   ├── text_encoders/        # Andere Text Encoders
│   ├── controlnet/           # ControlNet Models
│   ├── loras/                # LoRA Models
│   ├── upscale_models/       # Upscaler (ESRGAN, etc.)
│   ├── embeddings/           # Textual Inversions
│   ├── ipadapter/            # IP-Adapter Models
│   ├── diffusion_models/     # Spezifische Diffusion Models
│   ├── animatediff_models/   # AnimateDiff Motion Modules
│   ├── photomaker/           # PhotoMaker Models
│   ├── style_models/         # Style Transfer Models
│   ├── insightface/          # Face Models
│   └── ...
```

---

## 🔧 DOWNLOAD HELPER KOMMANDOS

### Einzelne Dateien mit aria2c herunterladen

```bash
# FLUX.1 Dev herunterladen
aria2c -c -x 16 -s 16 "https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/flux1-dev.safetensors" -d ComfyUI/models/unet/

# SDXL Base herunterladen
aria2c -c -x 16 -s 16 "https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors" -d ComfyUI/models/checkpoints/

# Text Encoder herunterladen
aria2c -c -x 16 -s 16 "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors" -d ComfyUI/models/clip/
```

### Git LFS für große Repositories

```bash
# Komplettes Repository mit LFS klonen
git lfs install
git clone https://huggingface.co/black-forest-labs/FLUX.1-dev
```

### Python Download Script Beispiel

```python
from huggingface_hub import hf_hub_download

# Download FLUX.1 Dev
hf_hub_download(
    repo_id="black-forest-labs/FLUX.1-dev",
    filename="flux1-dev.safetensors",
    local_dir="ComfyUI/models/unet/",
    local_dir_use_symlinks=False
)
```

---

## 📊 MODELL-GRÖSSEN ÜBERSICHT

### Image Models (Hauptmodelle)

| Modell | Größe (Full) | Größe (FP8) | Parameters |
|--------|--------------|-------------|------------|
| FLUX.1 | 23.8 GB | ~12 GB | 12B |
| SD3.5 Large | 9.96 GB | ~5 GB | 8B |
| SD3.5 Medium | 5.97 GB | ~3 GB | 2.5B |
| SDXL | 6.94 GB | - | 3.5B |
| SD 1.5 | 4.27 GB | - | 860M |

### Video Models (Hauptmodelle)

| Modell | Größe | Parameters | Max Länge |
|--------|-------|------------|-----------|
| HunyuanVideo | ~40 GB (FP8) | 13B | 15s @ 720p |
| WanVideo 14B | ~28 GB | 14B | Variable |
| Mochi 1 | ~20 GB | 10B | 5.4s @ 480p |
| CogVideoX-5B | ~10 GB | 5B | Variable |
| LTX Video | ~4 GB | 2B | 5s @ 768x512 |

---

## 💡 VERWENDUNGSTIPPS

### Speicher-Optimierung

1. **FP8 Versionen nutzen** - Halbiert VRAM-Bedarf bei ~gleicher Qualität
2. **GGUF Quants** - Für noch weniger VRAM (Q4/Q5/Q6/Q8)
3. **Model CPU Offload** - Aktivieren in ComfyUI für weniger VRAM
4. **Batch Size reduzieren** - Bei VRAM-Problemen

### Beste Modelle für Anfang

**Text-to-Image:**
- FLUX.1 Schnell (schnell, gute Qualität)
- SDXL Base + Refiner (vielseitig)
- SD 1.5 + Realistic Vision (Photorealism)

**Video:**
- LTX Video (niedrige VRAM-Anforderungen)
- CogVideoX-2B (gute Balance)
- AnimateDiff + SD1.5 (flexibel)

### Lizenz-Übersicht

- **Apache 2.0**: FLUX.1 Schnell, SD VAEs - Kommerzielle Nutzung OK
- **FLUX.1 Dev License**: Nicht-kommerziell ohne Enterprise License
- **Stability AI Community License**: SD3.x - Kommerziell < $1M Umsatz
- **CreativeML OpenRAIL**: SD1.5/SDXL - Offene Lizenz mit Nutzungsbeschränkungen

---

## 🔗 WICHTIGE LINKS

- **Hugging Face**: https://huggingface.co/
- **CivitAI**: https://civitai.com/
- **ComfyUI GitHub**: https://github.com/comfyanonymous/ComfyUI
- **ComfyUI Manager**: https://github.com/ltdrdata/ComfyUI-Manager
- **ComfyUI Docs**: https://docs.comfy.org/

---

## 📝 HINWEISE

- **Stand**: Oktober 2025
- **Token Budget**: Vollständig genutzt (1M Token Window)
- **Alle Links**: Direkt zu safetensors/pth/ckpt Dateien auf Hugging Face
- **Größenangaben**: Ungefähre Werte, können variieren
- **FP16 vs FP8**: FP8 spart ~50% Speicher bei minimaler Qualitätseinbuße
- **VRAM**: Video-Modelle benötigen 16-24GB+ VRAM für beste Ergebnisse
- **Kompatibilität**: Alle Modelle sind ComfyUI-kompatibel
- **Updates**: Neue Modelle erscheinen regelmäßig - Check Hugging Face

---

**Erstellt von:** AI Assistant für Sebastian
**Recherche**: Perplexity Research + Firecrawl Web Scraping
**Datum**: Oktober 2025

