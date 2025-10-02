# Contributing to RunPod ComfyUI Cloud

Thanks for your interest in contributing! This project maintains production-ready ComfyUI Docker images for RunPod.

## Development Setup

### Prerequisites
- Docker with Buildx support
- RunPod account for testing
- Basic knowledge of ComfyUI and Docker

### Local Development
```bash
# Clone repository
git clone https://github.com/sebastianhein/runpod-comfyui-h200.git
cd runpod-comfyui-h200

# Build image
./scripts/build.sh

# Test locally (requires NVIDIA GPU)
./scripts/test.sh
```

## Contributing Guidelines

### 1. Hardware Compatibility
- **Always test on RTX 5090** (primary target)
- **Verify H200 compatibility** for performance features
- **Document GPU requirements** for new features

### 2. Docker Best Practices
- Use modern BuildKit syntax (`# syntax=docker/dockerfile:1`)
- Employ HEREDOC for multi-line scripts
- Optimize layer caching for faster builds
- Maintain cross-platform compatibility

### 3. Performance Considerations
- Test GPU utilization with `nvidia-smi`
- Verify memory efficiency improvements
- Benchmark against baseline versions
- Document performance impacts

## Pull Request Process

### 1. Fork & Branch
```bash
git checkout -b feature/your-feature-name
```

### 2. Make Changes
- Update relevant Dockerfile(s)
- Add documentation for new features
- Include tests where applicable

### 3. Test Thoroughly
```bash
# Build test
./scripts/build.sh -t test

# Local test (if GPU available)
./scripts/test.sh -i your-image:test

# RunPod test (recommended)
# Deploy test pod with your image
```

### 4. Documentation
- Update README.md if needed
- Add troubleshooting entries for new issues
- Document configuration changes

### 5. Submit PR
- Clear description of changes
- Include test results
- Reference any related issues

## Testing Requirements

### Minimum Testing
- ✅ **Docker build** succeeds without errors
- ✅ **Container starts** without crash-loops
- ✅ **Services accessible** (ports 8188, 8888)

### Comprehensive Testing
- ✅ **RTX 5090 deployment** on RunPod
- ✅ **ComfyUI workflows** execute successfully
- ✅ **Jupyter Lab access** works without issues
- ✅ **GPU utilization** shows expected performance

### Test Environments
1. **Local:** Docker with NVIDIA GPU support
2. **RunPod RTX 5090:** Primary test platform
3. **RunPod H200:** Performance validation (optional)

## Code Standards

### Dockerfile Guidelines
```dockerfile
# syntax=docker/dockerfile:1
# Always use modern syntax

# Use HEREDOC for multi-line scripts
RUN <<EOF cat > script.py
#!/usr/bin/env python3
# Clean, readable syntax
EOF

# Optimize layer caching
RUN apt-get update && apt-get install -y package \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
```

### Script Standards
- Use bash with `set -e` for error handling
- Include help text (`--help` flag)
- Provide meaningful error messages
- Test on both macOS and Linux

### Documentation Standards
- Include code examples
- Provide troubleshooting steps
- Link to relevant external resources
- Keep formatting consistent

## Release Process

### Version Numbering
- **Major:** Breaking changes (v2.0.0)
- **Minor:** New features (v1.1.0)  
- **Patch:** Bug fixes (v1.0.1)

### Release Checklist
- [ ] All tests pass
- [ ] Documentation updated
- [ ] Version bumped in relevant files
- [ ] GitHub release created
- [ ] Docker images pushed to registry

## Community

### Communication
- **GitHub Issues:** Bug reports and feature requests
- **Discussions:** Questions and general discussion
- **Pull Requests:** Code contributions

### Getting Help
- Check [troubleshooting.md](docs/troubleshooting.md)
- Search existing GitHub issues
- Ask in GitHub Discussions

## Recognition

Contributors will be:
- Listed in README.md acknowledgments
- Mentioned in release notes for significant contributions
- Given credit in relevant documentation

Thank you for contributing to the RunPod ComfyUI community! 🚀
