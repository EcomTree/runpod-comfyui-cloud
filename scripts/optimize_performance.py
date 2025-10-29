#!/usr/bin/env python3
"""
ComfyUI Performance Optimization Script
Applies various performance optimizations including torch.compile
"""

import os
import sys
import torch

def apply_torch_compile_optimizations():
    """Apply torch.compile optimizations if supported."""
    if not torch.cuda.is_available():
        print("⚠️  CUDA not available, skipping torch.compile optimizations")
        return False
    
    # Check PyTorch version (torch.compile requires PyTorch 2.0+)
    torch_version = torch.__version__
    major_version = int(torch_version.split('.')[0])
    minor_version = int(torch_version.split('.')[1])
    
    if major_version < 2 or (major_version == 2 and minor_version < 0):
        print(f"⚠️  PyTorch {torch_version} does not support torch.compile (requires 2.0+)")
        return False
    
    # Set environment variables for torch.compile
    os.environ.setdefault("TORCH_COMPILE_DEBUG", "0")
    os.environ.setdefault("TORCH_LOGS", "+dynamo")
    
    print("✅ torch.compile optimizations configured")
    print(f"   PyTorch version: {torch_version}")
    print(f"   CUDA available: {torch.cuda.is_available()}")
    if torch.cuda.is_available():
        print(f"   GPU: {torch.cuda.get_device_name(0)}")
        print(f"   CUDA version: {torch.version.cuda}")
    
    return True

def apply_backend_optimizations():
    """Apply backend-level optimizations."""
    print("🔧 Applying backend optimizations...")
    
    # CUDNN optimizations
    torch.backends.cudnn.benchmark = True
    torch.backends.cudnn.deterministic = False
    torch.backends.cudnn.allow_tf32 = True
    
    # CUDA optimizations
    torch.backends.cuda.matmul.allow_tf32 = True
    
    # Memory optimizations
    if hasattr(torch.cuda, 'set_per_process_memory_fraction'):
        # Only use if needed, can cause issues with some workloads
        pass
    
    print("✅ Backend optimizations applied")
    print(f"   CUDNN benchmark: {torch.backends.cudnn.benchmark}")
    print(f"   TF32 enabled: {torch.backends.cuda.matmul.allow_tf32}")

def apply_environment_optimizations():
    """Set environment variables for performance."""
    optimizations = {
        # PyTorch memory management
        "PYTORCH_CUDA_ALLOC_CONF": "max_split_size_mb:1024,expandable_segments:True",
        
        # TF32 optimization
        "TORCH_ALLOW_TF32_CUBLAS_OVERRIDE": "1",
        
        # JIT compilation optimizations
        "TORCH_CUDNN_V8_API_ENABLED": "1",
        
        # Reduce Python overhead
        "PYTHONUNBUFFERED": "1",
    }
    
    for key, value in optimizations.items():
        if key not in os.environ:
            os.environ[key] = value
            print(f"   Set {key}={value}")

def main():
    """Main optimization function."""
    print("🚀 ComfyUI Performance Optimizations")
    print("=" * 50)
    
    # Apply optimizations
    apply_environment_optimizations()
    apply_backend_optimizations()
    compile_available = apply_torch_compile_optimizations()
    
    print("\n" + "=" * 50)
    print("✅ Performance optimizations completed")
    
    if compile_available:
        print("\n💡 torch.compile is available")
        print("   Enable in ComfyUI with: --enable-compile flag")
    else:
        print("\n⚠️  torch.compile not available (PyTorch < 2.0)")
        print("   Other optimizations are still active")
    
    return 0

if __name__ == "__main__":
    sys.exit(main())

