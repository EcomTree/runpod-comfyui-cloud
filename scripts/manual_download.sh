#!/bin/bash
# Manual model download script for debugging and manual execution
# This script can be run inside a running ComfyUI container

set -e

echo "🔧 Manual ComfyUI Model Download Script"
echo "======================================="

# Check if we're in the right directory
if [ ! -d "/workspace" ]; then
    echo "❌ Not in /workspace directory!"
    echo "💡 Run this script from inside the container: docker exec -it <container> bash"
    exit 1
fi

cd /workspace

echo "🔍 Environment check:"
echo "   DOWNLOAD_MODELS: ${DOWNLOAD_MODELS:-'not set'}"
echo "   HF_TOKEN: ${HF_TOKEN:+'set'}"
if [ -z "${HF_TOKEN:-}" ]; then
    echo "   HF_TOKEN: not set"
    echo "⚠️  Warning: HF_TOKEN not set - protected models may fail"
fi

# Check if virtual environment exists
echo ""
echo "🔍 Checking virtual environment..."
if [ ! -d "model_dl_venv" ]; then
    echo "❌ Virtual environment not found!"
    echo "💡 This suggests the container wasn't built correctly"
    exit 1
fi

if [ ! -f "model_dl_venv/bin/activate" ]; then
    echo "❌ Virtual environment activation script missing!"
    exit 1
fi

echo "✅ Virtual environment found"

# Check if scripts exist
echo ""
echo "🔍 Checking download scripts..."
if [ ! -f "scripts/verify_links.py" ]; then
    echo "❌ verify_links.py not found!"
    exit 1
fi

if [ ! -f "scripts/download_models.py" ]; then
    echo "❌ download_models.py not found!"
    exit 1
fi

echo "✅ Download scripts found"

# Check if model library exists
echo ""
echo "🔍 Checking model library..."
LIBRARY_PATHS=(
    "/opt/runpod/comfyui_models_complete_library.md"
    "/workspace/comfyui_models_complete_library.md"
    "comfyui_models_complete_library.md"
)

LIBRARY_FOUND=false
for path in "${LIBRARY_PATHS[@]}"; do
    if [ -f "$path" ]; then
        echo "✅ Model library found: $path"
        LIBRARY_FOUND=true
        break
    fi
done

if [ "$LIBRARY_FOUND" = false ]; then
    echo "❌ Model library not found in any location!"
    echo "🔍 Searched paths:"
    for path in "${LIBRARY_PATHS[@]}"; do
        echo "   $path"
    done
    exit 1
fi

# Check if ComfyUI models directory exists
echo ""
echo "🔍 Checking ComfyUI setup..."
if [ ! -d "ComfyUI" ]; then
    echo "❌ ComfyUI directory not found!"
    exit 1
fi

if [ ! -d "ComfyUI/models" ]; then
    echo "❌ ComfyUI/models directory not found!"
    echo "💡 Creating model directories..."
    mkdir -p ComfyUI/models/{checkpoints,vae,loras,controlnet,upscale_models,unet,clip,t5,clip_vision,animatediff_models,ipadapter,text_encoders,diffusion_models}
fi

echo "✅ ComfyUI found"

# Step 1: Link verification
echo ""
echo "🚀 Step 1: Verifying links..."
echo "This may take a few minutes..."
echo ""

source model_dl_venv/bin/activate

if [ -z "$VIRTUAL_ENV" ]; then
    echo "❌ Failed to activate virtual environment!"
    exit 1
fi

echo "✅ Virtual environment activated: $VIRTUAL_ENV"

python3 scripts/verify_links.py

if [ ! -f "link_verification_results.json" ]; then
    echo "❌ Link verification failed!"
    exit 1
fi

echo ""
echo "✅ Link verification completed"

# Show verification results
echo ""
echo "📊 Verification results:"
VALID_COUNT=$(python3 -c "
import json
try:
    with open('link_verification_results.json', 'r') as f:
        data = json.load(f)
        print(data.get('stats', {}).get('valid', 0))
except:
    print('0')
")
echo "   Valid links: $VALID_COUNT"

if [ "$VALID_COUNT" -eq 0 ]; then
    echo "❌ No valid links found!"
    echo "🔍 Check HF_TOKEN and internet connection"
    exit 1
fi

# Step 2: Download models
echo ""
echo "🚀 Step 2: Downloading models..."
echo "This may take several hours depending on your internet connection!"
echo "💾 Ensure you have enough storage space (200-300GB recommended)"
echo ""
echo "📋 Monitor progress in another terminal:"
echo "   docker logs -f <container_name>"
echo "   or: tail -f /workspace/model_download.log"
echo ""

# Ask for confirmation unless running non-interactively
# Use stdout TTY check (works with docker exec -it)
if [ -t 1 ]; then
    echo "⚠️  This will download many large models!"
    read -p "Continue? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "⏹️  Download cancelled"
        exit 0
    fi
fi

echo "⬇️  Starting download..."
python3 scripts/download_models.py /workspace

echo ""
echo "✅ Manual download completed!"

# Show summary
echo ""
echo "📋 Download summary:"
if [ -f "downloaded_models_summary.json" ]; then
    echo "✅ Summary file created"
    TOTAL_FILES=$(python3 -c "
import json
try:
    with open('downloaded_models_summary.json', 'r') as f:
        data = json.load(f)
        print(data.get('total_files', 0))
except:
    print('0')
")
    TOTAL_SIZE=$(python3 -c "
import json
try:
    with open('downloaded_models_summary.json', 'r') as f:
        data = json.load(f)
        size = data.get('total_size_mb', 0)
        print(f'{size:.1f}')
except:
    print('0.0')
")
    echo "   Files downloaded: $TOTAL_FILES"
    echo "   Total size: ${TOTAL_SIZE} MB"
else
    echo "⚠️  No summary file found"
fi

# Count actual model files
echo ""
echo "📁 Model directories:"
MODEL_DIRS=("checkpoints" "vae" "loras" "controlnet" "upscale_models" "unet" "clip" "t5" "clip_vision" "animatediff_models" "ipadapter")
for dir in "${MODEL_DIRS[@]}"; do
    if [ -d "ComfyUI/models/$dir" ]; then
        COUNT=$(find "ComfyUI/models/$dir" \( -name "*.safetensors" -o -name "*.ckpt" -o -name "*.pth" \) | wc -l 2>/dev/null || echo "0")
        if [ "$COUNT" -gt 0 ]; then
            echo "   $dir: $COUNT models"
        fi
    fi
done

echo ""
echo "🎉 Manual download process completed!"
echo ""
echo "💡 Next steps:"
echo "   - Restart ComfyUI to load the new models"
echo "   - Check Jupyter Lab for model availability"
echo "   - Test with a simple workflow"
