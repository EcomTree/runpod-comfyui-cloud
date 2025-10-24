#!/bin/bash
# Enhanced test script for RunPod ComfyUI Cloud Image with model download testing
# Validates image functionality locally

set -e

echo "🧪 Testing RunPod ComfyUI Cloud Image (Enhanced)"
echo "==============================================="

# Default values
IMAGE_NAME="ecomtree/comfyui-cloud"
CONTAINER_NAME="comfyui-test-$(date +%s)"
DOWNLOAD_MODELS="true"
HF_TOKEN="${HF_TOKEN:-}"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--image)
            IMAGE_NAME="$2"
            shift 2
            ;;
        -c|--container)
            CONTAINER_NAME="$2"
            shift 2
            ;;
        --no-download)
            DOWNLOAD_MODELS="false"
            shift
            ;;
        --hf-token)
            HF_TOKEN="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -i, --image IMAGE       Image to test (default: ecomtree/comfyui-cloud)"
            echo "  -c, --container NAME    Container name (default: comfyui-test-timestamp)"
            echo "  --no-download           Skip model download testing"
            echo "  --hf-token TOKEN        Hugging Face token for model downloads"
            echo "  -h, --help              Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "📦 Testing image: $IMAGE_NAME"
echo "🐳 Container: $CONTAINER_NAME"
echo "⬇️  Download Models: $DOWNLOAD_MODELS"

if [ -n "$HF_TOKEN" ]; then
    echo "🔑 HF_TOKEN provided"
else
    echo "⚠️ No HF_TOKEN provided - some models may fail to download"
fi

echo ""

# Check if image exists locally
echo "🔍 Checking if image exists locally..."
if ! docker image inspect "$IMAGE_NAME" &> /dev/null; then
    echo "📥 Image not found locally. Building image..."
    ./scripts/build.sh -t latest -n "$IMAGE_NAME" 2>&1 || {
        echo "❌ Failed to build image. See output above for details"
        exit 1
    }
else
    echo "✅ Image found locally"
fi

echo ""
echo "🚀 Starting test container with enhanced debugging..."

# Build docker run command
DOCKER_RUN_CMD=(
    -d
    --name "$CONTAINER_NAME"
    --platform linux/amd64
    -p 8188:8188
    -p 8888:8888
    -e DOWNLOAD_MODELS="$DOWNLOAD_MODELS"
)

if [ -n "$HF_TOKEN" ]; then
    DOCKER_RUN_CMD+=(-e HF_TOKEN="$HF_TOKEN")
fi

DOCKER_RUN_CMD+=("$IMAGE_NAME")

echo "🐳 Running: docker run ${DOCKER_RUN_CMD[*]}"
CONTAINER_ID=$(docker run "${DOCKER_RUN_CMD[@]}")

if [ $? -ne 0 ]; then
    echo "❌ Failed to start container"
    exit 1
fi

echo "✅ Container started: $CONTAINER_ID"
echo ""

# Wait for container to initialize
echo "⏳ Waiting 15 seconds for container initialization..."
sleep 15

# Show container logs for debugging
echo "📋 Recent container logs:"
docker logs "$CONTAINER_NAME" | tail -30

echo ""
echo "🔍 Enhanced Model Download Analysis:"
echo "===================================="

# Check if model download log exists
if docker exec "$CONTAINER_NAME" test -f /workspace/model_download.log 2>/dev/null; then
    echo "📄 Model download log found:"
    echo "🔍 Last 20 lines:"
    docker exec "$CONTAINER_NAME" tail -20 /workspace/model_download.log 2>/dev/null || echo "❌ Could not read log"

    echo ""
    echo "🔍 First 20 lines (for debugging):"
    docker exec "$CONTAINER_NAME" head -20 /workspace/model_download.log 2>/dev/null || echo "❌ Could not read log"
else
    echo "❌ No model download log found"
fi

# Check if verification results exist
echo ""
echo "🔍 Link verification status:"
if docker exec "$CONTAINER_NAME" test -f /workspace/link_verification_results.json 2>/dev/null; then
    echo "✅ Link verification completed"
    echo "📊 Verification results:"
    docker exec "$CONTAINER_NAME" head -20 /workspace/link_verification_results.json 2>/dev/null || echo "❌ Could not read verification results"
else
    echo "❌ No link verification results found"
    echo "🔍 Available JSON files in /workspace:"
    docker exec "$CONTAINER_NAME" find /workspace -name "*.json" -type f 2>/dev/null || echo "No JSON files found"
fi

# Check model directories
echo ""
echo "📁 Model directories status:"
MODEL_DIRS=("checkpoints" "vae" "loras" "controlnet" "upscale_models" "unet" "clip" "t5" "clip_vision")
for dir in "${MODEL_DIRS[@]}"; do
    if docker exec "$CONTAINER_NAME" test -d "/workspace/ComfyUI/models/$dir" 2>/dev/null; then
        # Count model files; 2>/dev/null suppresses find permission errors, || echo "0" handles command failures
        COUNT=$(docker exec "$CONTAINER_NAME" find "/workspace/ComfyUI/models/$dir" \( -name "*.safetensors" -o -name "*.ckpt" -o -name "*.pth" \) 2>/dev/null | wc -l || echo "0")
        SIZE=$(docker exec "$CONTAINER_NAME" du -sh "/workspace/ComfyUI/models/$dir" 2>/dev/null | cut -f1 || echo "0")
        echo "   $dir: $COUNT models ($SIZE)"
    else
        echo "   $dir: ❌ directory not found"
    fi
done

# Check placeholder files (should disappear after model download)
echo ""
echo "📄 Placeholder files status:"
PLACEHOLDER_COUNT=$(docker exec "$CONTAINER_NAME" find /workspace/ComfyUI/models -name "put_*_here" 2>/dev/null | wc -l || echo "0")
echo "   Placeholder files remaining: $PLACEHOLDER_COUNT"

if [ "$PLACEHOLDER_COUNT" -eq 0 ]; then
    echo "   ✅ All placeholder files replaced with real models!"
else
    echo "   ⚠️  Placeholder files still present (models not downloaded yet)"
fi

# Test ComfyUI API with enhanced error checking
echo ""
echo "🔌 Testing ComfyUI API endpoint..."
# Execute curl inside container and capture both output and exit code
COMFYUI_QUEUE_OUTPUT=$(docker exec "$CONTAINER_NAME" sh -c 'curl -s -f http://localhost:8188/queue; echo "EXIT_CODE:$?"' 2>/dev/null)
DOCKER_EXEC_EXIT_CODE=$?
CURL_EXIT_CODE=$(echo "$COMFYUI_QUEUE_OUTPUT" | grep -o 'EXIT_CODE:[0-9]*' | cut -d: -f2)
COMFYUI_QUEUE_OUTPUT=$(echo "$COMFYUI_QUEUE_OUTPUT" | grep -v 'EXIT_CODE:')

# First, check if docker exec itself failed
if [ $DOCKER_EXEC_EXIT_CODE -ne 0 ]; then
    echo "❌ docker exec failed (exit code: $DOCKER_EXEC_EXIT_CODE)"
    echo "🔍 ComfyUI logs:"
    docker exec "$CONTAINER_NAME" tail -15 /workspace/ComfyUI/user/comfyui.log 2>/dev/null || echo "No ComfyUI logs available"
# Next, check if we could extract the curl exit code
elif [ -z "$CURL_EXIT_CODE" ]; then
    echo "❌ Failed to extract curl exit code (curl command failed to produce output)"
    echo "🔍 ComfyUI logs:"
    docker exec "$CONTAINER_NAME" tail -15 /workspace/ComfyUI/user/comfyui.log 2>/dev/null || echo "No ComfyUI logs available"
elif [ "$CURL_EXIT_CODE" -eq 0 ]; then
    echo "✅ ComfyUI API is responding"
    echo "📊 ComfyUI status:"
    echo "$COMFYUI_QUEUE_OUTPUT" | head -5 2>/dev/null || echo "Could not parse queue status"
else
    echo "❌ ComfyUI API is not responding (curl exit code: $CURL_EXIT_CODE)"
    echo "🔍 ComfyUI logs:"
    docker exec "$CONTAINER_NAME" tail -15 /workspace/ComfyUI/user/comfyui.log 2>/dev/null || echo "No ComfyUI logs available"
fi

# Test Jupyter Lab
echo ""
echo "📊 Testing Jupyter Lab..."
# Execute curl inside container and capture exit code properly
# Try both /lab and / endpoints since Jupyter can redirect
docker exec "$CONTAINER_NAME" sh -c 'curl -s -f -L http://localhost:8888/ > /dev/null' 2>&1
JUPYTER_EXIT_CODE=$?

if [ $JUPYTER_EXIT_CODE -eq 0 ]; then
    echo "✅ Jupyter Lab is responding"
else
    echo "❌ Jupyter Lab is not responding (exit code: $JUPYTER_EXIT_CODE)"
    echo "🔍 Jupyter logs:"
    docker exec "$CONTAINER_NAME" tail -10 /workspace/jupyter.log 2>/dev/null || echo "No Jupyter logs available"
fi

echo ""
echo "🎉 Enhanced test completed!"
echo ""
echo "📋 Container Info:"
echo "   Name: $CONTAINER_NAME"
echo "   ID: $CONTAINER_ID"
echo "   Image: $IMAGE_NAME"
echo ""
echo "🔧 Useful commands:"
echo "   docker logs -f $CONTAINER_NAME                                    # Follow logs"
echo "   docker exec -it $CONTAINER_NAME bash                              # Enter container"
echo "   docker exec $CONTAINER_NAME tail -f /workspace/model_download.log  # Monitor downloads"
echo "   docker exec $CONTAINER_NAME find /workspace/ComfyUI/models -name \"*.safetensors\" | wc -l  # Count models"
echo ""
echo "🧹 Cleanup:"
echo "   docker stop $CONTAINER_NAME"
echo "   docker rm $CONTAINER_NAME"
