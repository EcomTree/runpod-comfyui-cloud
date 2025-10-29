# ComfyUI Custom Nodes

This document describes the custom nodes included in this ComfyUI deployment and how to use them.

## Included Custom Nodes

All custom nodes are automatically installed during Docker image build. They are configured in `configs/custom_nodes.json` and installed via `scripts/install_custom_nodes.sh`.

### 1. ComfyUI-Manager

**Repository**: https://github.com/ltdrdata/ComfyUI-Manager  
**Description**: Essential GUI tool for managing and installing additional custom nodes.

**Features**:
- Visual interface for browsing and installing custom nodes
- Auto-update functionality for installed nodes
- Model downloading interface
- Dependency management

**Usage**:
- Access via ComfyUI web interface menu
- Browse available custom nodes from curated lists
- One-click installation of popular nodes
- Automatic dependency resolution

**Priority**: 1 (installed first to enable management of other nodes)

---

### 2. ComfyUI-Impact-Pack

**Repository**: https://github.com/ltdrdata/ComfyUI-Impact-Pack  
**Description**: Advanced masking, segmentation, and image enhancement utilities.

**Features**:
- Advanced masking nodes for precise image editing
- Object detection and segmentation
- Image enhancement and filtering utilities
- Batch processing capabilities

**Usage Examples**:
```
ImpactPack/MaskByColor: Extract masks based on color
ImpactPack/UltimateSDUpscale: Advanced upscaling with multiple passes
ImpactPack/EfficientLoader: Optimized model loading
```

**Priority**: 2

---

### 3. rgthree-comfy

**Repository**: https://github.com/rgthree/rgthree-comfy  
**Description**: Quality of life improvements and workflow optimization tools.

**Features**:
- Better node organization and grouping
- Workflow templates and presets
- Performance optimizations
- Enhanced UI elements

**Usage Examples**:
```
rgthree/ConditioningCombine: Combine multiple conditioning inputs
rgthree/ImageToRGBA: Convert images with alpha channel handling
rgthree/Any: Universal input/output type handling
```

**Priority**: 3

---

### 4. ComfyUI-Advanced-ControlNet

**Repository**: https://github.com/Kosinkadink/ComfyUI-Advanced-ControlNet  
**Description**: Enhanced ControlNet support with advanced features.

**Features**:
- Multiple ControlNet chaining
- Advanced pose and depth control
- Conditional prompting integration
- Preprocessor optimization

**Usage Examples**:
```
Advanced-ControlNet/ControlNetApplyAdvanced: Apply ControlNet with advanced options
Advanced-ControlNet/Multi-ControlNetStack: Chain multiple ControlNets
Advanced-ControlNet/PreprocessorLoader: Load and apply preprocessors
```

**Priority**: 4

---

### 5. ComfyUI-VideoHelperSuite

**Repository**: https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite  
**Description**: Video processing and manipulation utilities.

**Features**:
- Video input/output support
- Frame interpolation and generation
- Video to image sequence conversion
- Image sequence to video conversion
- Frame manipulation and editing

**Usage Examples**:
```
VHS_VideoCombine: Combine image sequences into video
VHS_LoadVideo: Load video files for processing
VHS_VideoFromBatch: Create video from batch of images
VHS_LoadImagesSequence: Load image sequences from directories
```

**Priority**: 5

---

## Installation Process

Custom nodes are installed automatically during Docker build:

1. **Build Time**: All nodes are cloned and installed into `/workspace/ComfyUI/custom_nodes/`
2. **Requirements**: Python dependencies from each node's `requirements.txt` are installed
3. **Order**: Nodes are installed in priority order (1-5) as defined in `configs/custom_nodes.json`

## Manual Installation

If you need to install additional custom nodes or reinstall existing ones:

```bash
# Using the installation script
/opt/runpod/scripts/install_custom_nodes.sh /workspace/ComfyUI

# Manually via ComfyUI-Manager
# Access the Manager menu in ComfyUI web interface
```

## Custom Nodes Configuration

The configuration file `configs/custom_nodes.json` defines:

- **name**: Node directory name
- **repo**: Git repository URL
- **branch**: Git branch to clone (default: master/main)
- **description**: Human-readable description
- **requirements**: Whether to install requirements.txt (default: true)
- **priority**: Installation order (lower numbers first)

### Adding New Custom Nodes

To add a new custom node:

1. Edit `configs/custom_nodes.json`
2. Add a new entry following the existing format
3. Set appropriate priority (6+ for new nodes)
4. Rebuild Docker image or run installation script

Example:
```json
{
  "name": "ComfyUI-Example-Node",
  "repo": "https://github.com/user/ComfyUI-Example-Node.git",
  "branch": "main",
  "description": "Example custom node",
  "requirements": true,
  "priority": 6
}
```

## Troubleshooting

### Custom Node Not Loading

1. **Check Installation**:
   ```bash
   ls -la /workspace/ComfyUI/custom_nodes/
   ```

2. **Check Logs**:
   ```bash
   tail -f /workspace/logs/comfyui.log | grep -i error
   ```

3. **Verify Requirements**:
   ```bash
   cd /workspace/ComfyUI/custom_nodes/NodeName
   pip install -r requirements.txt
   ```

### Missing Dependencies

If a custom node requires system packages:

1. Add to Dockerfile `apt-get install` section
2. Rebuild image
3. Or install manually: `apt-get update && apt-get install -y <package>`

### Node Conflicts

Some custom nodes may conflict with each other:

1. Check node documentation for known conflicts
2. Disable conflicting nodes by removing from `custom_nodes.json`
3. Restart ComfyUI

## Best Practices

1. **Keep Nodes Updated**: Use ComfyUI-Manager to update nodes regularly
2. **Test Before Production**: Test new nodes in development environment first
3. **Document Custom Nodes**: Maintain notes on custom workflows using specific nodes
4. **Monitor Performance**: Some nodes may impact performance; monitor GPU/CPU usage

## References

- [ComfyUI Custom Nodes Documentation](https://github.com/comfyanonymous/ComfyUI/wiki)
- [ComfyUI Manager](https://github.com/ltdrdata/ComfyUI-Manager)
- [Popular Custom Nodes List](https://github.com/ltdrdata/ComfyUI-Manager/wiki/Custom-Nodes-List)

