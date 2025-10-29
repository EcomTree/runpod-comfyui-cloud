# Performance Tuning Guide

This guide explains the performance optimizations implemented in this ComfyUI deployment and how to fine-tune them for your specific use case.

## Automatic Optimizations

The following optimizations are automatically applied when starting ComfyUI:

### Backend Optimizations

- **CUDNN Benchmark**: Enabled for optimal performance on stable input sizes
- **TF32**: Enabled for faster computation on Ampere+ GPUs (H200, RTX 5090)
- **Expandable Segments**: CUDA memory allocation with expandable segments for better fragmentation handling

### torch.compile (PyTorch 2.0+)

Automatically enabled if PyTorch 2.0+ is detected. Provides **20-30% speed boost** on compatible workloads.

**Requirements**:
- PyTorch 2.0 or higher
- CUDA-capable GPU
- First run may be slower (compilation cache)

**Disable if needed**:
```bash
# Remove --enable-compile flag from start script
# Or set environment variable:
export COMFYUI_DISABLE_COMPILE=1
```

## Performance Metrics

Expected performance improvements:

| Optimization | Speed Boost | Memory Impact | Compatibility |
|-------------|-------------|---------------|---------------|
| torch.compile | 20-30% | +100-200MB | PyTorch 2.0+ |
| TF32 | 10-15% | None | Ampere+ GPUs |
| CUDNN Benchmark | 5-10% | None | All CUDA GPUs |
| Expandable Segments | Variable | Better usage | CUDA 11.2+ |

## GPU-Specific Optimizations

### NVIDIA H200

The deployment includes H200-specific optimizations:

```python
# h200_optimizations.py
torch.backends.cudnn.benchmark = True
torch.backends.cudnn.deterministic = False
torch.backends.cuda.matmul.allow_tf32 = True
torch.backends.cudnn.allow_tf32 = True
```

### RTX 5090

Same optimizations apply. RTX 5090 benefits from:
- TF32 acceleration
- torch.compile optimizations
- High VRAM bandwidth

## Environment Variables

Fine-tune performance with these environment variables:

```bash
# Memory optimization
PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:1024,expandable_segments:True

# TF32 optimization
TORCH_ALLOW_TF32_CUBLAS_OVERRIDE=1

# CUDNN optimizations
TORCH_CUDNN_V8_API_ENABLED=1

# Debug torch.compile (set to 1 for verbose output)
TORCH_COMPILE_DEBUG=0
```

## ComfyUI Launch Flags

The container starts ComfyUI with these flags:

```bash
python main.py \
    --listen 0.0.0.0 \
    --port 8188 \
    --highvram \              # Use high VRAM mode
    --bf16-vae \              # Use bfloat16 for VAE (lower memory)
    --disable-smart-memory \  # Disable smart memory management
    --preview-method auto \    # Automatic preview method
    --enable-compile          # Enable torch.compile (if available)
```

### Flag Descriptions

- `--highvram`: Assume high VRAM availability, reduces offloading
- `--bf16-vae`: Use bfloat16 precision for VAE (good balance)
- `--disable-smart-memory`: Disable automatic memory management
- `--preview-method auto`: Let ComfyUI choose best preview method
- `--enable-compile`: Enable torch.compile (PyTorch 2.0+)

## Custom Performance Script

Run the performance optimization script manually:

```bash
# Inside container
python3 /opt/runpod/scripts/optimize_performance.py
```

This script will:
1. Check PyTorch version and CUDA availability
2. Apply backend optimizations
3. Configure torch.compile if available
4. Set optimal environment variables

## Troubleshooting

### Slow First Run

**Symptom**: First inference is much slower than subsequent runs.

**Cause**: torch.compile compilation cache generation.

**Solution**: This is normal. First run compiles the model, subsequent runs use cached compilation.

### Out of Memory

**Symptom**: CUDA out of memory errors.

**Solutions**:
1. Disable torch.compile: `export COMFYUI_DISABLE_COMPILE=1`
2. Use `--normalvram` instead of `--highvram`
3. Reduce batch size in workflows
4. Enable model offloading

### Poor Performance

**Check**:
1. GPU utilization: `nvidia-smi`
2. CUDA version compatibility
3. PyTorch version (should be 2.0+ for best performance)
4. Enable debug: `TORCH_COMPILE_DEBUG=1`

## Benchmarking

Test performance improvements:

```bash
# Baseline (without optimizations)
COMFYUI_DISABLE_COMPILE=1 python main.py ...

# With optimizations
python main.py --enable-compile ...

# Compare inference times
time python -c "import torch; x=torch.randn(1,3,512,512).cuda(); _=x@x"
```

## Best Practices

1. **First Time Setup**: Allow first run to complete for compilation cache
2. **Monitor VRAM**: Use `nvidia-smi` to monitor memory usage
3. **Batch Size**: Start with small batches, increase gradually
4. **Model Size**: Larger models benefit more from torch.compile
5. **Workflow Complexity**: Complex workflows see larger improvements

## References

- [PyTorch torch.compile Documentation](https://pytorch.org/tutorials/intermediate/torch_compile_tutorial.html)
- [CUDA Performance Best Practices](https://docs.nvidia.com/cuda/cuda-c-best-practices-guide/)
- [ComfyUI Performance Tips](https://github.com/comfyanonymous/ComfyUI/wiki/Performance-Tips)

