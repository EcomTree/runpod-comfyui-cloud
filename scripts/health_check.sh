#!/bin/bash
# Health Check Script for ComfyUI
# Checks ComfyUI API, GPU availability, and VRAM usage
# Exit 0 if healthy, 1 if issues detected

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
COMFYUI_URL="${COMFYUI_URL:-http://localhost:8188}"
VRAM_THRESHOLD_PERCENT="${VRAM_THRESHOLD_PERCENT:-95}"
MAX_QUEUE_SIZE="${MAX_QUEUE_SIZE:-100}"

echo "🏥 ComfyUI Health Check"
echo "========================"

# Exit code (0 = healthy, 1 = unhealthy)
EXIT_CODE=0

# Check 1: ComfyUI API
echo -n "Checking ComfyUI API... "
if curl -fsS "${COMFYUI_URL}/queue" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ OK${NC}"
else
    echo -e "${RED}✗ FAILED${NC}"
    echo "  ComfyUI API not responding at ${COMFYUI_URL}"
    EXIT_CODE=1
fi

# Check 2: GPU Availability
echo -n "Checking GPU availability... "
if command -v nvidia-smi &> /dev/null; then
    if nvidia-smi > /dev/null 2>&1; then
        GPU_COUNT=$(nvidia-smi --query-gpu=count --format=csv,noheader | head -n1)
        echo -e "${GREEN}✓ OK${NC} (${GPU_COUNT} GPU(s) detected)"
    else
        echo -e "${RED}✗ FAILED${NC}"
        echo "  nvidia-smi command failed"
        EXIT_CODE=1
    fi
else
    echo -e "${YELLOW}⚠ SKIPPED${NC}"
    echo "  nvidia-smi not available"
fi

# Check 3: VRAM Usage
echo -n "Checking VRAM usage... "
if command -v nvidia-smi &> /dev/null; then
    # Get VRAM usage for all GPUs
    VRAM_DATA=$(nvidia-smi --query-gpu=index,memory.used,memory.total --format=csv,noheader,nounits)
    
    VRAM_OK=true
    while IFS=',' read -r GPU_ID USED TOTAL; do
        # Trim whitespace
        GPU_ID=$(echo "$GPU_ID" | xargs)
        USED=$(echo "$USED" | xargs)
        TOTAL=$(echo "$TOTAL" | xargs)
        
        # Calculate percentage
        if [ "$TOTAL" -gt 0 ]; then
            PERCENT=$((USED * 100 / TOTAL))
            
            if [ "$PERCENT" -ge "$VRAM_THRESHOLD_PERCENT" ]; then
                echo -e "${RED}✗ CRITICAL${NC}"
                echo "  GPU $GPU_ID: ${USED}MB / ${TOTAL}MB (${PERCENT}%) - Threshold: ${VRAM_THRESHOLD_PERCENT}%"
                VRAM_OK=false
                EXIT_CODE=1
            fi
        fi
    done <<< "$VRAM_DATA"
    
    if [ "$VRAM_OK" = true ]; then
        echo -e "${GREEN}✓ OK${NC}"
        # Show VRAM usage summary
        while IFS=',' read -r GPU_ID USED TOTAL; do
            GPU_ID=$(echo "$GPU_ID" | xargs)
            USED=$(echo "$USED" | xargs)
            TOTAL=$(echo "$TOTAL" | xargs)
            PERCENT=$((USED * 100 / TOTAL))
            echo "  GPU $GPU_ID: ${USED}MB / ${TOTAL}MB (${PERCENT}%)"
        done <<< "$VRAM_DATA"
    fi
else
    echo -e "${YELLOW}⚠ SKIPPED${NC}"
    echo "  nvidia-smi not available"
fi

# Check 4: Queue Size
echo -n "Checking queue size... "
if command -v curl &> /dev/null && command -v jq &> /dev/null; then
    QUEUE_DATA=$(curl -fsS "${COMFYUI_URL}/queue" 2>/dev/null || echo "{}")
    
    if [ -n "$QUEUE_DATA" ]; then
        PENDING=$(echo "$QUEUE_DATA" | jq '.queue_pending | length' 2>/dev/null || echo "0")
        RUNNING=$(echo "$QUEUE_DATA" | jq '.queue_running | length' 2>/dev/null || echo "0")
        TOTAL=$((PENDING + RUNNING))
        
        if [ "$TOTAL" -ge "$MAX_QUEUE_SIZE" ]; then
            echo -e "${YELLOW}⚠ WARNING${NC}"
            echo "  Queue size: ${TOTAL} (Pending: ${PENDING}, Running: ${RUNNING}) - Threshold: ${MAX_QUEUE_SIZE}"
            # Don't fail on queue size, just warn
        else
            echo -e "${GREEN}✓ OK${NC}"
            echo "  Queue size: ${TOTAL} (Pending: ${PENDING}, Running: ${RUNNING})"
        fi
    else
        echo -e "${YELLOW}⚠ SKIPPED${NC}"
        echo "  Could not retrieve queue data"
    fi
else
    echo -e "${YELLOW}⚠ SKIPPED${NC}"
    echo "  curl or jq not available"
fi

# Check 5: Disk Space
echo -n "Checking disk space... "
WORKSPACE_USAGE=$(df -h /workspace 2>/dev/null | awk 'NR==2 {print $5}' | sed 's/%//')
if [ -n "$WORKSPACE_USAGE" ]; then
    if [ "$WORKSPACE_USAGE" -ge 95 ]; then
        echo -e "${RED}✗ CRITICAL${NC}"
        echo "  /workspace disk usage: ${WORKSPACE_USAGE}%"
        EXIT_CODE=1
    elif [ "$WORKSPACE_USAGE" -ge 85 ]; then
        echo -e "${YELLOW}⚠ WARNING${NC}"
        echo "  /workspace disk usage: ${WORKSPACE_USAGE}%"
    else
        echo -e "${GREEN}✓ OK${NC}"
        echo "  /workspace disk usage: ${WORKSPACE_USAGE}%"
    fi
else
    echo -e "${YELLOW}⚠ SKIPPED${NC}"
    echo "  Could not check disk space"
fi

# Summary
echo ""
echo "========================"
if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅ Health Check PASSED${NC}"
else
    echo -e "${RED}❌ Health Check FAILED${NC}"
fi
echo ""

exit $EXIT_CODE
