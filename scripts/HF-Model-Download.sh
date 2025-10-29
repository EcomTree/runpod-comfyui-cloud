#!/bin/bash
# FLUX Model Download Script
# Downloads FLUX.1-dev models for ComfyUI
# DEPRECATED: Use download_models.py for comprehensive model downloads
# This script is kept for legacy support and specific FLUX model needs

set -e

# --- START COPY & PASTE BLOCK ---

# 1. YOUR HUGGING FACE API TOKEN
# Prefer setting via environment: export HF_TOKEN="hf_xxxxxxxxxxxxx"
# If not set, you can paste it here as a placeholder:
HF_TOKEN="${HF_TOKEN:-}"

# 2. VERIFY LICENSE ACCEPTANCE
echo "----------------------------------------------------------------"
echo "WARNING: Have you accepted the license for 'FLUX.1-dev' on Hugging Face?"
echo "Link: https://huggingface.co/black-forest-labs/FLUX.1-dev"
echo "The script will continue in 10 seconds..."
echo "Press CTRL+C to cancel if you have not accepted it."
echo "----------------------------------------------------------------"
sleep 10

# 3. CREATE DIRECTORY STRUCTURE (IF NEEDED)
echo "--- Creating directories (if missing) ---"
mkdir -p ./models/unet
mkdir -p ./models/clip
mkdir -p ./models/vae

# 4. DOWNLOADS (FULL QUALITY / HEAVY VARIANTS)

# Check if HF_TOKEN is set and non-empty
if [ -z "$HF_TOKEN" ]; then
    echo "ERROR: HF_TOKEN is not set. Please export your Hugging Face API token (Settings -> Access Tokens)."
    echo "Example: export HF_TOKEN=hf_xxxxxxxxxxxxx"
    exit 1
fi
echo "--- [1/4] Download UNET (FLUX.1-dev) - Full Precision (23.8 GB) ---"
# This model is gated and requires the API token
wget --header="Authorization: Bearer $HF_TOKEN" https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/flux1-dev.sft -O ./models/unet/flux1-dev.sft || { echo "Failed to download UNET (flux1-dev.sft)"; exit 1; }

echo "--- [2/4] Download VAE (335 MB) ---"
wget https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/ae.safetensors -O ./models/vae/flux.ae.safetensors || { echo "Failed to download VAE (flux.ae.safetensors)"; exit 1; }

echo "--- [3/4] Download Large Text Encoder (T5-XXL FP16 - 9.79 GB) ---"
wget https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp16.safetensors -O ./models/clip/t5xxl_fp16.safetensors || { echo "Failed to download Large Text Encoder (t5xxl_fp16.safetensors)"; exit 1; }

echo "--- [4/4] Download Small Text Encoder (CLIP-L - 246 MB) ---"
wget https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors -O ./models/clip/clip_l.safetensors || { echo "Failed to download Small Text Encoder (clip_l.safetensors)"; exit 1; }

echo "----------------------------------------------------------------"
echo "--- All heavy-hitter FLUX models downloaded. ---"
echo "--- Ready to cook! 🚀 ---"

# --- END COPY & PASTE BLOCK ---
