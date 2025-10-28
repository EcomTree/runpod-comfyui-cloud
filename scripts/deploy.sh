#!/bin/bash
# RunPod deployment script for ComfyUI Cloud Image
# Creates and manages RunPod pods with optimal configuration
# DEPRECATED: This script uses outdated image names
# Use RunPod web console or update IMAGE_NAME variable

set -e

echo "🚀 RunPod ComfyUI Cloud Deployment Script"
echo "========================================"

# Default configuration
# NOTE: Update this to the correct image name
IMAGE_NAME="ecomtree/comfyui-cloud:latest"
POD_NAME="comfyui-$(date +%s)"
GPU_TYPE="NVIDIA GeForce RTX 5090"
VOLUME_SIZE=100
CONTAINER_DISK=40

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--image)
            IMAGE_NAME="$2"
            shift 2
            ;;
        -n|--name)
            POD_NAME="$2"
            shift 2
            ;;
        -g|--gpu)
            GPU_TYPE="$2"
            shift 2
            ;;
        --h200)
            GPU_TYPE="NVIDIA H200"
            shift
            ;;
        --rtx5090)
            GPU_TYPE="NVIDIA GeForce RTX 5090"
            shift
            ;;
        -v|--volume)
            VOLUME_SIZE="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -i, --image IMAGE    Docker image to deploy (default: sebastianhein/comfyui-h200:no-auth)"
            echo "  -n, --name NAME      Pod name (default: comfyui-timestamp)"
            echo "  -g, --gpu GPU        GPU type (default: RTX 5090)"
            echo "  --h200               Use H200 GPU (premium)"
            echo "  --rtx5090            Use RTX 5090 GPU (optimal)"
            echo "  -v, --volume SIZE    Volume size in GB (default: 100)"
            echo "  -h, --help           Show this help"
            echo ""
            echo "Supported GPUs:"
            echo "  - NVIDIA GeForce RTX 5090 (24GB, $0.69/hr) - RECOMMENDED"
            echo "  - NVIDIA H200 (80GB HBM3, $3.59/hr) - Premium"
            echo "  - NVIDIA H100 80GB HBM3 - Enterprise"
            echo ""
            echo "⚠️  RTX 4090 and older GPUs are NOT compatible (CUDA < 12.8)"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "📦 Image: $IMAGE_NAME"
echo "🏷️  Name: $POD_NAME"
echo "🎮 GPU: $GPU_TYPE"
echo "💾 Volume: ${VOLUME_SIZE}GB"
echo ""

# Check if RunPod CLI is available
if ! command -v runpodctl &> /dev/null; then
    echo "⚠️  RunPod CLI not found. Using manual deployment instructions."
    echo ""
    echo "Manual deployment steps:"
    echo "1. Go to https://console.runpod.io/pods"
    echo "2. Click 'Deploy' → 'sebastianhein-comfyui-h200' template"
    echo "3. Select GPU: $GPU_TYPE"
    echo "4. Set Image: $IMAGE_NAME"
    echo "5. Configure Volume: ${VOLUME_SIZE}GB"
    echo "6. Deploy!"
    echo ""
    echo "💡 Install RunPod CLI for automated deployment:"
    echo "   pip install runpod"
    exit 0
fi

echo "🚀 Deploying to RunPod..."

# Deploy using RunPod CLI (if available)
runpodctl create pod \
    --name "$POD_NAME" \
    --image-name "$IMAGE_NAME" \
    --gpu-type "$GPU_TYPE" \
    --volume-size "$VOLUME_SIZE" \
    --container-disk "$CONTAINER_DISK" \
    --ports "8188/http,8888/http"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Deployment successful!"
    echo "📊 Monitor your pod at: https://console.runpod.io/pods"
    echo ""
    echo "Services will be available in 2-3 minutes:"
    echo "🎨 ComfyUI: Port 8188"
    echo "📊 Jupyter Lab: Port 8888 (no auth required)"
else
    echo "❌ Deployment failed"
    exit 1
fi
