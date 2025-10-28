#!/bin/bash

# --- START COPY & PASTE BLOCK ---

# 1. DEIN HUGGING FACE API KEY (TOKEN)
# Ersetze <DEIN_HF_API_KEY_HIER> mit deinem echten HF Token (findest du unter Settings -> Access Tokens)
HF_TOKEN=""

# 2. ÜBERPRÜFEN, OB DIE LIZENZ AKZEPTIERT WURDE
echo "----------------------------------------------------------------"
echo "WARNUNG: Hast du die Lizenz für 'FLUX.1-dev' auf Hugging Face akzeptiert?"
echo "Link: https://huggingface.co/black-forest-labs/FLUX.1-dev"
echo "Das Skript wird in 10 Sekunden fortgesetzt..."
echo "Drücke STRG+C zum Abbrechen, falls nicht."
echo "----------------------------------------------------------------"
sleep 10

# 3. ORDNERSTRUKTUR ERSTELLEN (FALLS NICHT VORHANDEN)
echo "--- Erstelle Ordner (falls nicht vorhanden) ---"
mkdir -p ./models/unet
mkdir -p ./models/clip
mkdir -p ./models/vae

# 4. DOWNLOADS (FULL QUALITY / HEAVY VARIANTS)

echo "--- [1/4] Download UNET (FLUX.1-dev) - Full Precision (23.8 GB) ---"
# Das ist das Gated Model, braucht den API Key
wget --header="Authorization: Bearer $HF_TOKEN" https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/flux1-dev.sft -O ./models/unet/flux1-dev.sft

echo "--- [2/4] Download VAE (335 MB) ---"
wget https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/ae.safetensors -O ./models/vae/flux.ae.safetensors

echo "--- [3/4] Download Großer Text Encoder (T5-XXL FP16 - 9.79 GB) ---"
wget https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp16.safetensors -O ./models/clip/t5xxl_fp16.safetensors

echo "--- [4/4] Download Kleiner Text Encoder (CLIP-L - 246 MB) ---"
wget https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors -O ./models/clip/clip_l.safetensors

echo "----------------------------------------------------------------"
echo "--- Alle 'Heavy-Hitter' FLUX-Modelle sind downgeloadet. ---"
echo "--- Ready to cook! 🚀 ---"

# --- ENDE COPY & PASTE BLOCK ---