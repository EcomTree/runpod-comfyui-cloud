#!/bin/bash

# --- START COPY & PASTE BLOCK ---

# 1. YOUR HUGGING FACE API TOKEN
# Replace <YOUR_HF_TOKEN_HERE> with your real HF token (Settings -> Access Tokens)
HF_TOKEN=""

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

echo "--- [1/4] Download UNET (FLUX.1-dev) - Full Precision (23.8 GB) ---"
# This model is gated and requires the API token
wget --header="Authorization: Bearer $HF_TOKEN" https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/flux1-dev.sft -O ./models/unet/flux1-dev.sft

echo "--- [2/4] Download VAE (335 MB) ---"
wget https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/ae.safetensors -O ./models/vae/flux.ae.safetensors

echo "--- [3/4] Download Large Text Encoder (T5-XXL FP16 - 9.79 GB) ---"
wget https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp16.safetensors -O ./models/clip/t5xxl_fp16.safetensors

echo "--- [4/4] Download Small Text Encoder (CLIP-L - 246 MB) ---"
wget https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors -O ./models/clip/clip_l.safetensors

echo "----------------------------------------------------------------"
echo "--- All heavy-hitter FLUX models downloaded. ---"
echo "--- Ready to cook! 🚀 ---"

# --- END COPY & PASTE BLOCK ---
