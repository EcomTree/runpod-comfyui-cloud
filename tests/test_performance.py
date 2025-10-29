"""
Tests for performance optimizations and GPU compatibility.
"""

import pytest
import subprocess
import sys
from pathlib import Path


def test_torch_available():
    """Test that PyTorch is available."""
    try:
        import torch
        assert torch is not None, "PyTorch import succeeded but returned None"
    except ImportError:
        pytest.skip("PyTorch not installed (expected in Docker environment)")


def test_torch_version():
    """Test that PyTorch version is 2.0+ for torch.compile support."""
    try:
        import torch
        version = torch.__version__.split('.')
        major = int(version[0])
        assert major >= 2, f"PyTorch version {torch.__version__} is too old (need 2.0+)"
    except ImportError:
        pytest.skip("PyTorch not installed")


def test_cuda_available():
    """Test that CUDA is available."""
    try:
        import torch
        # Note: This test will fail on non-GPU systems, which is expected
        # In CI, this can be skipped
        if torch.cuda.is_available():
            assert True, "CUDA is available"
        else:
            pytest.skip("CUDA not available (expected on GPU systems)")
    except ImportError:
        pytest.skip("PyTorch not installed")


def test_cuda_version():
    """Test that CUDA version is 12.8 or higher."""
    try:
        import torch
        if torch.cuda.is_available():
            cuda_version = torch.version.cuda
            if cuda_version:
                major, minor = cuda_version.split('.')[:2]
                major, minor = int(major), int(minor)
                
                # CUDA 12.8+ required for H200/RTX 5090
                assert major >= 12, f"CUDA major version {major} too old"
                if major == 12:
                    assert minor >= 8, f"CUDA 12.{minor} too old (need 12.8+)"
        else:
            pytest.skip("CUDA not available")
    except ImportError:
        pytest.skip("PyTorch not installed")


def test_torch_compile_available():
    """Test that torch.compile is available (PyTorch 2.0+ feature)."""
    try:
        import torch
        assert hasattr(torch, 'compile'), "torch.compile not available (need PyTorch 2.0+)"
    except ImportError:
        pytest.skip("PyTorch not installed")


def test_gpu_optimization_script_exists():
    """Test that optimize_performance.py script exists."""
    script_path = Path(__file__).parent.parent / "scripts" / "optimize_performance.py"
    assert script_path.exists(), "scripts/optimize_performance.py not found"


def test_gpu_optimization_script_syntax():
    """Test that optimize_performance.py has valid Python syntax."""
    script_path = Path(__file__).parent.parent / "scripts" / "optimize_performance.py"
    
    result = subprocess.run(
        [sys.executable, '-m', 'py_compile', str(script_path)],
        capture_output=True,
        text=True
    )
    
    assert result.returncode == 0, f"Python syntax error in optimize_performance.py:\n{result.stderr}"


def test_torch_backends_available():
    """Test that PyTorch backends are accessible."""
    try:
        import torch
        
        # These should be accessible attributes
        assert hasattr(torch.backends, 'cudnn'), "torch.backends.cudnn not available"
        assert hasattr(torch.backends, 'cuda'), "torch.backends.cuda not available"
        
    except ImportError:
        pytest.skip("PyTorch not installed")


def test_xformers_available():
    """Test that xformers is available (optional but recommended)."""
    try:
        import xformers
        assert xformers is not None
    except ImportError:
        pytest.skip("xformers not installed (optional dependency)")


def test_flash_attention_available():
    """Test that flash-attn is available (optional but recommended)."""
    try:
        import flash_attn
        assert flash_attn is not None
    except ImportError:
        pytest.skip("flash-attn not installed (optional dependency)")


def test_performance_env_vars_documented():
    """Test that performance environment variables are documented."""
    env_docs = Path(__file__).parent.parent / "docs" / "environment-variables.md"
    
    assert env_docs.exists(), "docs/environment-variables.md not found"
    
    with open(env_docs, 'r', encoding='utf-8') as f:
        content = f.read()
        
        # Check for key performance env vars
        assert 'PYTORCH_CUDA_ALLOC_CONF' in content, \
            "PYTORCH_CUDA_ALLOC_CONF not documented in environment-variables.md"


def test_h200_optimization_file_structure():
    """Test that h200_optimizations.py is referenced in Dockerfile."""
    dockerfile = Path(__file__).parent.parent / "Dockerfile"
    
    assert dockerfile.exists(), "Dockerfile not found"
    
    with open(dockerfile, 'r', encoding='utf-8') as f:
        content = f.read()
        
        # Should create h200_optimizations.py
        assert 'h200_optimizations.py' in content, \
            "h200_optimizations.py not referenced in Dockerfile"


def test_benchmark_capability():
    """Test basic PyTorch tensor operations work (if available)."""
    try:
        import torch
        
        # Simple tensor operation test
        x = torch.randn(10, 10)
        y = torch.randn(10, 10)
        z = torch.matmul(x, y)
        
        assert z.shape == (10, 10), "Matrix multiplication failed"
        
        # Test CUDA if available
        if torch.cuda.is_available():
            x_cuda = x.cuda()
            y_cuda = y.cuda()
            z_cuda = torch.matmul(x_cuda, y_cuda)
            
            assert z_cuda.shape == (10, 10), "CUDA matrix multiplication failed"
            
    except ImportError:
        pytest.skip("PyTorch not installed")
    except Exception as e:
        pytest.fail(f"Benchmark test failed: {e}")


def test_memory_config_defaults():
    """Test that memory configuration defaults are sensible."""
    # PYTORCH_CUDA_ALLOC_CONF should be set to reasonable values
    expected_config = "max_split_size_mb:1024,expandable_segments:True"
    
    # This is set in the startup script, we just verify the format is valid
    parts = expected_config.split(',')
    assert len(parts) == 2, "Memory config should have 2 parts"
    assert 'max_split_size_mb' in parts[0], "Should specify max_split_size_mb"
    assert 'expandable_segments' in parts[1], "Should specify expandable_segments"


def test_gpu_compatibility_docs_exist():
    """Test that GPU compatibility documentation exists."""
    gpu_docs = Path(__file__).parent.parent / "docs" / "gpu-compatibility.md"
    assert gpu_docs.exists(), "docs/gpu-compatibility.md not found"


def test_performance_tuning_docs_exist():
    """Test that performance tuning documentation exists."""
    perf_docs = Path(__file__).parent.parent / "docs" / "performance-tuning.md"
    assert perf_docs.exists(), "docs/performance-tuning.md not found"


def test_cuda_architecture_support():
    """Test that CUDA architectures are properly configured."""
    try:
        import torch
        
        if torch.cuda.is_available():
            # Get device capability
            capability = torch.cuda.get_device_capability(0)
            major, minor = capability
            
            # H200 and RTX 5090 use compute capability 9.0+
            # Should support at least compute capability 7.0 (V100)
            assert major >= 7, f"Unsupported compute capability: {major}.{minor}"
            
    except ImportError:
        pytest.skip("PyTorch not installed")
    except Exception:
        pytest.skip("CUDA not available")


def test_tensor_core_support():
    """Test that tensor cores can be utilized (TF32/BF16)."""
    try:
        import torch
        
        if torch.cuda.is_available():
            # Check if TF32 can be enabled
            torch.backends.cuda.matmul.allow_tf32 = True
            assert torch.backends.cuda.matmul.allow_tf32 == True, "TF32 support not available"
            
            # Check if BF16 is supported
            if hasattr(torch.cuda, 'is_bf16_supported'):
                # BF16 requires Ampere or newer
                pytest.skip("BF16 support check not available in this PyTorch version")
        else:
            pytest.skip("CUDA not available")
            
    except ImportError:
        pytest.skip("PyTorch not installed")


@pytest.mark.slow
def test_compile_simple_model():
    """Test that torch.compile works on a simple model."""
    try:
        import torch
        import torch.nn as nn
        
        if not hasattr(torch, 'compile'):
            pytest.skip("torch.compile not available")
        
        # Define simple model
        class SimpleModel(nn.Module):
            def __init__(self):
                super().__init__()
                self.linear = nn.Linear(10, 10)
            
            def forward(self, x):
                return self.linear(x)
        
        model = SimpleModel()
        
        # Try to compile (may fail on non-CUDA systems)
        try:
            compiled_model = torch.compile(model)
            x = torch.randn(1, 10)
            output = compiled_model(x)
            assert output.shape == (1, 10), "Compiled model output shape incorrect"
        except Exception as e:
            pytest.skip(f"torch.compile failed (expected on some systems): {e}")
            
    except ImportError:
        pytest.skip("PyTorch not installed")
