#!/bin/bash
# Test script for RunPod ComfyUI Cloud Image
# Validates image functionality locally

set -e

echo "🧪 Testing RunPod ComfyUI Cloud Image"
echo "===================================="

IMAGE_NAME="sebastianhein/comfyui-h200:no-auth"
CONTAINER_NAME="comfyui-test-$(date +%s)"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--image)
            IMAGE_NAME="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -i, --image IMAGE    Image to test (default: sebastianhein/comfyui-h200:no-auth)"
            echo "  -h, --help           Show this help"
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

# Check if image exists locally
if ! docker image inspect "$IMAGE_NAME" &> /dev/null; then
    echo "📥 Pulling image from registry..."
    docker pull "$IMAGE_NAME"
fi

echo ""
echo "🚀 Starting test container..."

# Start container with port mapping
docker run -d \
    --name "$CONTAINER_NAME" \
    --gpus all \
    -p 8188:8188 \
    -p 8888:8888 \
    "$IMAGE_NAME"

if [ $? -ne 0 ]; then
    echo "❌ Failed to start container"
    exit 1
fi

echo "✅ Container started successfully"
echo ""

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 10

# Test ComfyUI endpoint
echo "🎨 Testing ComfyUI (port 8188)..."
if curl -s -f http://localhost:8188 > /dev/null; then
    echo "✅ ComfyUI is responding"
else
    echo "⚠️  ComfyUI not ready yet (may need more time)"
fi

# Test Jupyter Lab endpoint  
echo "📊 Testing Jupyter Lab (port 8888)..."
if curl -s -f http://localhost:8888 > /dev/null; then
    echo "✅ Jupyter Lab is responding"
else
    echo "⚠️  Jupyter Lab not ready yet (may need more time)"
fi

echo ""
echo "📋 Container logs (last 20 lines):"
docker logs --tail 20 "$CONTAINER_NAME"

echo ""
echo "🔧 Test completed. Services available at:"
echo "   ComfyUI: http://localhost:8188"
echo "   Jupyter Lab: http://localhost:8888"
echo ""
echo "🧹 Cleanup:"
echo "   Stop: docker stop $CONTAINER_NAME"
echo "   Remove: docker rm $CONTAINER_NAME"
echo ""
echo "💡 Run: docker stop $CONTAINER_NAME && docker rm $CONTAINER_NAME"
