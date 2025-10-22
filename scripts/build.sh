#!/bin/bash
# Build script for RunPod ComfyUI Cloud Image
# Builds for x86_64 architecture (RunPod compatible)

set -e

echo "🚀 Building RunPod ComfyUI Cloud Image..."
echo "========================================"

# Check if Docker Buildx is available
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found. Please install Docker first."
    exit 1
fi

# Default values
IMAGE_NAME="ecomtree/comfyui-cloud"
TAG="latest"
DOCKERFILE="Dockerfile"
PUSH=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--tag)
            TAG="$2"
            shift 2
            ;;
        -n|--name)
            IMAGE_NAME="$2"
            shift 2
            ;;
        --push)
            PUSH=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -t, --tag TAG        Image tag (default: latest)"
            echo "  -n, --name NAME      Image name (default: ecomtree/comfyui-cloud)"
            echo "  --push               Push to registry after build"
            echo "  -h, --help           Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

FULL_IMAGE="${IMAGE_NAME}:${TAG}"

echo "📦 Building: $FULL_IMAGE"
echo "📋 Dockerfile: $DOCKERFILE"
echo "🏗️ Platform: linux/amd64 (RunPod compatible)"
echo ""

# Build with Docker Buildx for cross-platform compatibility
BUILD_ARGS=(
    --platform linux/amd64
    -f "$DOCKERFILE"
    -t "$FULL_IMAGE"
    .
)

if [ "${PUSH:-false}" = "true" ]; then
    BUILD_ARGS+=(--push)
fi

if docker buildx build "${BUILD_ARGS[@]}"; then
    echo ""
    echo "✅ Build successful: $FULL_IMAGE"

    if [ "${PUSH:-false}" = "true" ]; then
        echo "📤 Image pushed via Buildx"
    fi

    echo ""
    echo "🎉 Ready for RunPod deployment!"
    echo "💡 Use: docker run -p 8188:8188 -p 8888:8888 $FULL_IMAGE"
else
    echo "❌ Build failed"
    exit 1
fi
