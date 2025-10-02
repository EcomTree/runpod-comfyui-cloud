# 🎮 GPU Compatibility Guide

Hardware compatibility matrix for RunPod ComfyUI Cloud deployment.

## Supported Hardware

### ✅ Fully Compatible GPUs (CUDA 12.8+)

#### NVIDIA GeForce RTX 5090 (RECOMMENDED)
- **VRAM:** 24GB GDDR7
- **Cost:** $0.69/hour
- **Performance:** Excellent for ComfyUI
- **Memory:** Up to 186GB system RAM
- **Cores:** 12-16 vCPUs
- **Use Case:** Optimal balance of cost and performance

#### NVIDIA H200 (PREMIUM)
- **VRAM:** 80GB HBM3
- **Cost:** $3.59/hour (5x more expensive)
- **Performance:** Maximum available
- **Memory:** Up to 251GB system RAM  
- **Cores:** 24 vCPUs
- **Use Case:** Heavy batch processing, large models

#### NVIDIA H100 80GB HBM3
- **VRAM:** 80GB HBM3
- **Cost:** ~$2.50/hour
- **Performance:** Enterprise-grade
- **Use Case:** Production workloads, multi-tenant

#### NVIDIA H100 PCIe
- **VRAM:** 80GB
- **Cost:** ~$2.00/hour
- **Performance:** Excellent
- **Use Case:** Cost-effective high performance

### ❌ Incompatible Hardware (CUDA < 12.8)

#### NVIDIA GeForce RTX 4090
- **VRAM:** 24GB GDDR6X
- **Cost:** $0.34/hour (cheapest)
- **Problem:** CUDA 12.1-12.7 (incompatible)
- **Error:** `nvidia-container-cli: requirement error: unsatisfied condition: cuda>=12.8`

#### Older RTX Series (3090, 3080, etc.)
- **Problem:** CUDA < 12.8
- **Status:** Not supported by our CUDA 12.8 base image

#### Tesla V100 Series
- **Problem:** Very old CUDA versions
- **Status:** Not compatible

## Performance Comparison

### Benchmark Results (Estimated)

| GPU | VRAM | ComfyUI Speed | Cost/Hr | Performance/$ |
|-----|------|---------------|---------|---------------|
| RTX 5090 | 24GB | 100% | $0.69 | **145%** ⭐ |
| H200 | 80GB | 110% | $3.59 | 31% |
| H100 80GB | 80GB | 105% | $2.50 | 42% |
| RTX 4090 | 24GB | N/A | $0.34 | ❌ Incompatible |

### Workload Recommendations

#### RTX 5090 - Optimal Choice
**Best for:**
- Standard SD 1.5/SDXL workflows
- LoRA training and fine-tuning
- Real-time image generation
- Development and experimentation

**Limitations:**
- Large batch processing (use H200)
- Extremely large models (>20GB)

#### H200 - Premium Performance
**Best for:**
- Large batch image generation
- Multiple concurrent workflows
- Extremely large custom models
- Production environments with heavy load

**Consider if:**
- Cost is not primary concern
- Maximum performance required
- Working with cutting-edge large models

## Selection Guide

### Quick Decision Matrix

**Choose RTX 5090 if:**
- ✅ Cost optimization important
- ✅ Standard ComfyUI workflows
- ✅ Development/experimentation
- ✅ Single-user usage

**Choose H200 if:**
- ✅ Maximum performance needed
- ✅ Large batch processing
- ✅ Multiple concurrent users
- ✅ Budget allows premium pricing

### Regional Availability

GPU availability varies by region:

**High Availability:**
- US-East, US-West
- EU (various locations)
- Asia-Pacific

**Note:** RTX 5090 generally has better availability than H200

## CUDA Version Requirements

### Why CUDA 12.8 Matters

Our image uses:
- **PyTorch 2.8.0** with CUDA 12.8 optimizations
- **Flash Attention** requiring modern CUDA
- **TensorRT** with latest GPU features
- **Mixed Precision (BF16)** optimizations

### Checking CUDA Version

```bash
# In RunPod pod
nvidia-smi

# Should show:
# CUDA Version: 12.8 or higher
```

### Future Compatibility

**Planning ahead:**
- RTX 5090 series: Long-term support expected
- H200: Current flagship, ongoing support
- Newer GPUs: Should maintain CUDA 12.8+ compatibility

## Hardware Selection API

### RunPod GPU Type IDs

Use these exact strings when deploying via API:

```python
# Recommended
"NVIDIA GeForce RTX 5090"

# Premium options  
"NVIDIA H200"
"NVIDIA H100 80GB HBM3"
"NVIDIA H100 PCIe"

# Avoid (incompatible)
"NVIDIA GeForce RTX 4090"  # CUDA < 12.8
```

### Automated Selection

```python
# Smart GPU selection based on requirements
def select_gpu(performance_need="standard", budget="medium"):
    if budget == "high" and performance_need == "maximum":
        return "NVIDIA H200"
    elif performance_need in ["standard", "high"]:
        return "NVIDIA GeForce RTX 5090"  # Best balance
    else:
        return "NVIDIA H100 80GB HBM3"    # Enterprise
```
