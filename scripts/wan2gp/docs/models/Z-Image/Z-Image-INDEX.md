# Z-Image Model Variants - Complete Index

## Overview
The Z-Image family consists of **8 distinct variants** optimized for different use cases, from maximum quality to minimum VRAM, from basic text-to-image to advanced ControlNet guidance.

**Base Repository**: [DeepBeepMeep/Z-Image](https://huggingface.co/DeepBeepMeep/Z-Image) on HuggingFace

## Quick Selection Guide

### By Primary Need

#### Need: Maximum Quality
→ **[Z-Image Base](Z-Image-Base.md)** (30 steps, CFG, 13-15 GB VRAM)

#### Need: Speed + Quality Balance
→ **[Z-Image Turbo](Z-Image-Turbo.md)** (8 steps, NAG, 12-14 GB VRAM)

#### Need: Extreme Speed (2-4 steps)
→ **[TwinFlow Turbo](Z-Image-TwinFlow-Turbo.md)** (2 steps, unified sampler, 12-14 GB VRAM)

#### Need: Visual Control (Pose, Depth, Canny, Scribble)
- **Standard 1024x1024**: [ControlNet v1](Z-Image-ControlNet-v1.md) or [v2](Z-Image-ControlNet-v2.md)
- **HD 1920x1088**: [ControlNet v2.1](Z-Image-ControlNet-v2.1.md)

#### Need: Minimum VRAM
- **Any GPU**: [Nunchaku INT4 r256](Z-Image-Nunchaku-INT4-r256.md) (~4 GB)
- **RTX 50xx only**: [Nunchaku FP4 r128](Z-Image-Nunchaku-FP4-r128.md) (~3 GB)

## All Variants Summary

### 1. Z-Image Base
**[Full Documentation](Z-Image-Base.md)**

- **Type**: Foundation model
- **Steps**: 30
- **Guidance**: 4.0 (CFG)
- **Resolution**: 1024x1024
- **VRAM**: 13-15 GB (BF16)
- **Purpose**: Maximum quality, creative generation, fine-tuning base
- **Features**: Flow shift, high diversity, rich aesthetics

**Best For**: Professional work, fine-tuning, research, maximum quality

---

### 2. Z-Image Turbo
**[Full Documentation](Z-Image-Turbo.md)**

- **Type**: Distilled (fast)
- **Steps**: 8
- **Guidance**: 0 (NAG available)
- **Resolution**: 1024x1024
- **VRAM**: 12-14 GB (BF16)
- **Purpose**: Fast, high-quality generation
- **Features**: NAG (Negative Adaptive Guidance), fast inference

**Best For**: Production workflows, real-time applications, general use

---

### 3. TwinFlow Z-Image Turbo
**[Full Documentation](Z-Image-TwinFlow-Turbo.md)**

- **Type**: Distilled + Fine-tuned (1-4 steps)
- **Steps**: 2 (default)
- **Guidance**: 0
- **Resolution**: 1024x1024
- **VRAM**: 12-14 GB (BF16)
- **Purpose**: Extreme speed
- **Features**: Unified sampler, 1-4 step optimization, RFBA

**Best For**: Real-time, interactive, rapid prototyping, preview generation

---

### 4. Z-Image Turbo Fun ControlNet v1
**[Full Documentation](Z-Image-ControlNet-v1.md)**

- **Type**: Turbo + ControlNet Union
- **Steps**: 9
- **Guidance**: 0
- **Resolution**: 1024x1024
- **VRAM**: 14-16 GB (BF16)
- **Control**: Pose, Canny, Depth, Scribble
- **Control Weight**: 0.75
- **Purpose**: Visual structure guidance

**Best For**: Pose-guided, edge-guided, depth-guided generation

---

### 5. Z-Image Turbo Fun ControlNet v2
**[Full Documentation](Z-Image-ControlNet-v2.md)**

- **Type**: Turbo + Enhanced ControlNet Union
- **Steps**: 9
- **Guidance**: 0
- **Resolution**: 1024x1024
- **VRAM**: 14-17 GB (BF16)
- **Control**: Pose, Canny, Depth, Scribble (more layers)
- **Control Weight**: 0.75
- **Purpose**: Enhanced visual control, inpainting-ready
- **Features**: More control layers, better quality, inpainting prepared (disabled)

**Best For**: Better control quality than v1, future inpainting

---

### 6. Z-Image Turbo Fun ControlNet v2.1
**[Full Documentation](Z-Image-ControlNet-v2.1.md)**

- **Type**: Turbo + Highest-Quality ControlNet Union
- **Steps**: 9
- **Guidance**: 0
- **Resolution**: 1920x1088 (HD, 16:9)
- **VRAM**: 20-22 GB (BF16)
- **Control**: Pose, Canny, Depth, Scribble (most layers)
- **Control Weight**: 0.65
- **Purpose**: HD visual control
- **Features**: HD optimized, most control layers, best quality

**Best For**: HD widescreen, 16:9 content, professional controlled work

---

### 7. Z-Image Turbo Nunchaku INT4 (r256)
**[Full Documentation](Z-Image-Nunchaku-INT4-r256.md)**

- **Type**: Turbo + SVDQ INT4 quantization
- **Steps**: 8
- **Guidance**: 0
- **Resolution**: 1024x1024
- **VRAM**: ~4 GB
- **Quality**: 85-90% vs BF16
- **Purpose**: VRAM reduction
- **Requirements**: Nunchaku kernels (for speed)

**Best For**: Limited VRAM (8-12 GB GPUs), batch processing, any GPU

---

### 8. Z-Image Turbo Nunchaku FP4 (r128)
**[Full Documentation](Z-Image-Nunchaku-FP4-r128.md)**

- **Type**: Turbo + SVDQ FP4 quantization
- **Steps**: 8
- **Guidance**: 0
- **Resolution**: 1024x1024
- **VRAM**: ~3 GB (lowest)
- **Quality**: 80-90% vs BF16
- **Purpose**: Extreme VRAM reduction + speed
- **Requirements**: RTX 50xx GPU (sm120+), Nunchaku kernels (mandatory)

**Best For**: RTX 50xx series, absolute minimum VRAM, maximum speed

---

## Comparison Tables

### By Main Category

#### Quality Focus (Highest to Lowest)
1. **Z-Image Base** - 100% quality, 30 steps
2. **Z-Image Turbo** - 95%+ quality, 8 steps
3. **ControlNet v2.1** - 95%+ quality, 9 steps, HD
4. **ControlNet v2** - 95% quality, 9 steps
5. **ControlNet v1** - 90%+ quality, 9 steps
6. **TwinFlow Turbo** - 85-90% quality, 2 steps
7. **Nunchaku INT4 r256** - 85-90% quality, 8 steps
8. **Nunchaku FP4 r128** - 80-90% quality, 8 steps

#### Speed Focus (Fastest to Slowest)
1. **TwinFlow Turbo** - 2 steps (~1-2s on RTX 4090)
2. **Nunchaku FP4 r128** - 8 steps (~1-2s on RTX 5090)
3. **Z-Image Turbo** - 8 steps (~3-5s on RTX 4090)
4. **Nunchaku INT4 r256** - 8 steps (~3-5s on RTX 4090)
5. **ControlNet v1/v2** - 9 steps (~4-6s on RTX 4090)
6. **ControlNet v2.1** - 9 steps (~8-12s on RTX 4090, HD)
7. **Z-Image Base** - 30 steps (~10-15s on RTX 4090)

#### VRAM Usage (Lowest to Highest, BF16)
1. **Nunchaku FP4 r128** - ~3 GB
2. **Nunchaku INT4 r256** - ~4 GB
3. **Z-Image Turbo** - ~12-14 GB
4. **TwinFlow Turbo** - ~12-14 GB
5. **Z-Image Base** - ~13-15 GB
6. **ControlNet v1** - ~14-16 GB
7. **ControlNet v2** - ~14-17 GB
8. **ControlNet v2.1** - ~20-22 GB

### Feature Matrix

| Variant | Steps | Guidance | Control | Inpainting | Resolution | VRAM (BF16) |
|---------|-------|----------|---------|------------|------------|-------------|
| Base | 30 | CFG 4.0 | No | No | 1024² | 13-15 GB |
| Turbo | 8 | NAG | No | No | 1024² | 12-14 GB |
| TwinFlow | 2 | No | No | No | 1024² | 12-14 GB |
| Control v1 | 9 | No | Yes (4) | No | 1024² | 14-16 GB |
| Control v2 | 9 | No | Yes (4+) | Ready | 1024² | 14-17 GB |
| Control v2.1 | 9 | No | Yes (4++) | Ready | 1920×1088 | 20-22 GB |
| Nunchaku INT4 | 8 | NAG* | No | No | 1024² | ~4 GB |
| Nunchaku FP4 | 8 | NAG* | No | No | 1024² | ~3 GB |

*NAG available but not recommended with quantization

### Use Case Recommendations

#### Professional Photography/Art
- ✅ **Z-Image Base** (maximum quality)
- ✅ **Z-Image Turbo** (fast + high quality)
- ✅ **ControlNet v2.1** (HD + control)

#### Real-Time Applications
- ✅ **TwinFlow Turbo** (2 steps)
- ✅ **Z-Image Turbo** (8 steps)
- ✅ **Nunchaku FP4** (RTX 50xx only)

#### Character Design with Poses
- ✅ **ControlNet v2.1** (best quality)
- ✅ **ControlNet v2** (good quality)
- ✅ **ControlNet v1** (standard)

#### Architectural Visualization
- ✅ **ControlNet v2.1** (HD, depth/edge control)
- ✅ **Z-Image Base** (no control, max quality)

#### Dataset Generation (High Volume)
- ✅ **TwinFlow Turbo** (fastest)
- ✅ **Nunchaku INT4** (low VRAM, batch)
- ✅ **Z-Image Turbo** (quality + speed)

#### Limited VRAM (8-12 GB)
- ✅ **Nunchaku INT4 r256** (4 GB)
- ✅ **Nunchaku FP4 r128** (3 GB, RTX 50xx)

#### RTX 50xx Series
- ✅ **Nunchaku FP4 r128** (fastest + lowest VRAM)
- ✅ Any other variant (standard speed)

## Code References

### Handler
**File**: `/opt/wan2gp/Wan2GP/models/z_image/z_image_handler.py`
- Lines 1-189: Family handler implementation
- Lines 61: Supported model types
- Lines 65-72: Model equivalence map
- Lines 83-95: LoRA support

### Configurations
**Directory**: `/opt/wan2gp/Wan2GP/defaults/`
- `z_image.json` - Turbo
- `z_image_base.json` - Base
- `z_image_twinflow_turbo.json` - TwinFlow
- `z_image_control.json` - ControlNet v1
- `z_image_control2.json` - ControlNet v2
- `z_image_control2_1.json` - ControlNet v2.1
- `z_image_nunchaku_r256_int4.json` - Nunchaku INT4
- `z_image_nunchaku_r128_fp4.json` - Nunchaku FP4

### Pipeline
**File**: `/opt/wan2gp/Wan2GP/models/z_image/pipeline_z_image.py`
- Lines 1-991: Main pipeline implementation
- Lines 148-200: Unified sampler (TwinFlow)
- Lines 384-850: Generation pipeline

## Shared Components

All Z-Image variants share:

### Text Encoder
- **Model**: Qwen3 (Causal Language Model)
- **Max Sequence**: 512 tokens
- **Files**: `qwen3_bf16.safetensors` or `qwen3_quanto_bf16_int8.safetensors`

### VAE
- **Files**: `ZImageTurbo_VAE_bf16.safetensors`
- **Scale Factor**: 16 (height/width must be divisible by 16)
- **Dtype**: float32 (recommended)

### Scheduler
- **Type**: FlowMatchEulerDiscreteScheduler
- **Config**: `ZImageTurbo_scheduler_config.json`

## Installation and Setup

### Basic Installation
```bash
# Models auto-download from HuggingFace
# Stored in: /opt/wan2gp/Wan2GP/models/z_image/
```

### For Nunchaku Variants
```bash
# Install Nunchaku kernels
pip install nunchaku

# Verify installation
python -c "import nunchaku; print('Kernels installed')"
```

### Loading Examples

#### Standard Variant
```python
from models.z_image.z_image_handler import family_handler

pipe_processor, pipe = family_handler.load_model(
    model_filename="ZImageTurbo_bf16.safetensors",
    base_model_type="z_image",
    dtype=torch.bfloat16,
    VAE_dtype=torch.float32,
)
```

#### ControlNet Variant
```python
pipe_processor, pipe = family_handler.load_model(
    model_filename=[
        "ZImageTurbo_bf16.safetensors",
        "Z-Image-Turbo-Fun-Controlnet-Union2.1_bf16.safetensors"
    ],
    base_model_type="z_image_control2_1",
    dtype=torch.bfloat16,
    is_control=True,
)
```

## Hardware Requirements

### Minimum
- **GPU**: CUDA-capable (GTX 1060 6GB with Nunchaku quantization)
- **VRAM**: 6GB (with FP4/INT4)
- **RAM**: 16GB system RAM
- **Storage**: ~20GB for full model set

### Recommended
- **GPU**: RTX 3090/4090 (24GB)
- **VRAM**: 16-24GB
- **RAM**: 32GB system RAM
- **Storage**: 50GB+ for models and cache

### Optimal (RTX 50xx)
- **GPU**: RTX 5090 (24GB)
- **VRAM**: 24GB
- **Features**: FP4 hardware acceleration
- **Speed**: Fastest possible generation

## Version Information

**Last Updated**: 2/8/2026
**Model Family**: Z-Image
**Total Variants**: 8
**HuggingFace**: DeepBeepMeep/Z-Image
**Architecture Family ID**: 120

## Quick Links

- [Z-Image Base](Z-Image-Base.md) - Foundation, maximum quality
- [Z-Image Turbo](Z-Image-Turbo.md) - Fast, balanced
- [TwinFlow Turbo](Z-Image-TwinFlow-Turbo.md) - Extreme speed
- [ControlNet v1](Z-Image-ControlNet-v1.md) - Visual control
- [ControlNet v2](Z-Image-ControlNet-v2.md) - Enhanced control
- [ControlNet v2.1](Z-Image-ControlNet-v2.1.md) - HD control
- [Nunchaku INT4](Z-Image-Nunchaku-INT4-r256.md) - Low VRAM (any GPU)
- [Nunchaku FP4](Z-Image-Nunchaku-FP4-r128.md) - Lowest VRAM (RTX 50xx)

## Additional Resources

### Model Handler
`/opt/wan2gp/Wan2GP/models/z_image/z_image_handler.py`

### Pipeline Implementation
`/opt/wan2gp/Wan2GP/models/z_image/pipeline_z_image.py`

### Configuration Files
`/opt/wan2gp/Wan2GP/defaults/z_image*.json`

### HuggingFace Repository
https://huggingface.co/DeepBeepMeep/Z-Image
