# Z-Image Turbo Fun ControlNet v2.1

## Model Overview
**Z-Image Turbo Fun ControlNet v2.1** is the latest and most advanced ControlNet variant, optimized for higher resolutions (1920x1088) with enhanced control layers and prepared inpainting support.

## Technical Specifications

### Model Details
- **Parameter Count**: 6 Billion (6B) + Enhanced ControlNet modules
- **Architecture Type**: `z_image_control2_1`
- **Model Identifier**: `z_image_control2_1`
- **Base Family**: Z-Image
- **Parent Model**: `z_image_control2` (v2, which inherits from v1)
- **Base Model**: Z-Image Turbo
- **ControlNet**: Union v2.1 (highest resolution variant)

### Model Files
**Location**: `/opt/wan2gp/Wan2GP/models/z_image/`

**Configuration**: `/opt/wan2gp/Wan2GP/defaults/z_image_control2_1.json` (Lines 1-13)

**URLs**:
- **Base Model**: Referenced as `"z_image"` (uses Z-Image Turbo URLs)
- **ControlNet Module**:
  - `https://huggingface.co/DeepBeepMeep/Z-Image/resolve/main/Z-Image-Turbo-Fun-Controlnet-Union2.1_bf16.safetensors`
  - `https://huggingface.co/DeepBeepMeep/Z-Image/resolve/main/Z-Image-Turbo-Fun-Controlnet-Union2.1_quanto_bf16_int8.safetensors` (INT8)

**Handler**: `/opt/wan2gp/Wan2GP/models/z_image/z_image_handler.py` (Lines 1-189)

**Pipeline**: `/opt/wan2gp/Wan2GP/models/z_image/pipeline_z_image.py` (Lines 1-991)

## Primary Purpose
The **highest quality ControlNet variant**, optimized for **higher resolutions** (especially 1920x1088 for 16:9 content) with more control layers and lower control weight for balanced guidance.

## Key Features

### 1. Higher Resolution Optimization
- **Default Resolution**: 1920x1088 (16:9 aspect ratio)
- **Target Use**: HD content, widescreen images
- **Optimization**: Trained/fine-tuned for larger image sizes
- **Quality**: Better detail preservation at high resolutions

**Code Reference**: `/opt/wan2gp/Wan2GP/defaults/z_image_control2_1.json` (Line 10)

```json
"resolution": "1920x1088"
```

### 2. Reduced Control Weight
- **Default**: 0.65 (vs. 0.75 in v1/v2)
- **Reason**: More control layers allow lower weight for same adherence
- **Benefit**: Better image quality with less over-controlling

**Code Reference**: `/opt/wan2gp/Wan2GP/defaults/z_image_control2_1.json` (Line 12)

```json
"control_net_weight_alt": 0.65
```

### 3. Enhanced ControlNet Union
- **Type**: Multi-control Union v2.1
- **Supported Controls**: Pose, Canny, Depth, Scribble
- **Enhancement**: Most control layers of any variant
- **Quality**: Best control adherence and detail

**Code Reference**: `/opt/wan2gp/Wan2GP/defaults/z_image_control2_1.json` (Lines 8-9)

### 4. Inpainting Support (Disabled)
- **Status**: Infrastructure prepared, feature disabled
- **Support Flag**: `inpaint_support = True` (inherited from v2)
- **Mask Options**: `["", "A", "NA"]`

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/z_image_handler.py` (Lines 38-44)

### 5. Parent Model Architecture
- **Immediate Parent**: `z_image_control2` (v2)
- **Grandparent**: `z_image_control` (v1)
- **Compatibility**: Inherits all v2 features

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/z_image_handler.py` (Line 41)

```python
extra_model_def["parent_model_type"] = "z_image_control"
```

### 6. Model Equivalence
v2.1 is mapped to v2 for compatibility:

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/z_image_handler.py` (Lines 66-68)

```python
models_eqv_map = {
    "z_image_control2_1": "z_image_control2",
}
```

## Default Settings

### Generation Parameters
```json
{
  "resolution": "1920x1088",
  "batch_size": 1,
  "num_inference_steps": 9,
  "guidance_scale": 0,
  "control_net_weight_alt": 0.65
}
```

**Code Reference**: `/opt/wan2gp/Wan2GP/defaults/z_image_control2_1.json`

### Advanced Settings
- **Control Weight**: 0.65 (optimized for more layers)
- **NAG Support**: No
- **Flow Shift**: No
- **Guidance Max Phases**: 0

## Resolutions and Aspect Ratios

### Default Resolution
- **Primary**: 1920x1088 (16:9, HD aspect ratio)
- **Why 1088**: Divisible by 16 (VAE constraint), closest to 1080p

### Supported Resolutions
- **Constraint**: Height and width must be divisible by 16

**Optimized Resolutions** (16:9 and similar):
- **1920x1088** (16:9) - Default, optimized
- 1920x1072 (16:9, alternative)
- 1792x1008 (16:9, slightly lower)
- 1664x944 (16:9, medium)
- 1536x864 (16:9, lower)

**Standard Resolutions** (also supported):
- 1024x1024 (1:1) - Works but not optimized
- 1024x768 (4:3)
- 768x1024 (3:4)

**Higher Resolutions**:
- 2048x1152 (16:9, VRAM permitting)
- 2560x1440 (16:9, high VRAM required)

### Resolution and VRAM
```
Resolution  | BF16 VRAM | INT8 VRAM
------------|-----------|----------
1024x1024   | ~15 GB    | ~10 GB
1920x1088   | ~20 GB    | ~13 GB
2048x1152   | ~24 GB    | ~15 GB
2560x1440   | ~32 GB    | ~20 GB
```

## Control Types and Usage

### Supported Control Types
Same as v1/v2:
1. **Pose Control** (OpenPose)
2. **Canny Edge Control**
3. **Depth Control**
4. **Scribble Control**

### Enhancements in v2.1
- **Highest Layer Count**: Most control layers
- **Best Quality**: Superior detail at high resolutions
- **Balanced Control**: Lower weight (0.65) with better adherence
- **HD Optimized**: Specifically tuned for 1920x1088

## Best Use Cases

### Ideal For:
1. **HD Content Creation**
   - 16:9 widescreen images
   - YouTube thumbnails (1920x1080)
   - Web banners
   - Presentation graphics

2. **High-Resolution Controlled Generation**
   - Detailed architectural visualization
   - Large-format prints
   - Professional imagery
   - Marketing materials

3. **Cinematic Compositions**
   - Widescreen aspect ratio
   - Movie-style framing
   - Panoramic scenes

4. **Professional Workflows**
   - Client deliverables
   - Commercial work
   - Portfolio pieces

### Not Ideal For:
- Square images (use v1/v2 for 1024x1024)
- Portrait orientation (3:4, use v1/v2)
- Lower resolutions (v1/v2 more efficient)
- Low VRAM systems (requires 16+ GB for BF16)

## Differences from Other Z-Image Variants

### vs. ControlNet v2
| Feature | v2.1 | v2 |
|---------|------|-----|
| Resolution | **1920x1088** | 1024x1024 |
| Control Weight | **0.65** | 0.75 |
| Optimization | **Higher-res** | Standard |
| Control Layers | **Most layers** | More layers |
| VRAM | **Higher** (~20GB) | Standard (~15GB) |
| Aspect Ratio | **16:9 optimized** | 1:1 optimized |

**Code Reference**: `/opt/wan2gp/Wan2GP/defaults/z_image_control2_1.json` vs. `z_image_control2.json`

### vs. ControlNet v1
| Feature | v2.1 | v1 |
|---------|------|-----|
| Control Layers | **Most** | Standard |
| Resolution | **1920x1088** | 1024x1024 |
| Control Weight | **0.65** | 0.75 |
| Quality | **Highest** | Good |
| VRAM | **20GB+** | 15GB |
| Inpainting | **Prepared** | No |

### vs. Z-Image Turbo
| Feature | v2.1 | Turbo |
|---------|------|-------|
| Control | **Yes (4 types, best)** | No |
| Resolution | **1920x1088** | 1024x1024 |
| Steps | 9 | 8 |
| VRAM | **Higher** | Lower |
| Purpose | **HD Controlled** | Fast T2I |

### Hierarchy Summary
```
v1 (z_image_control)
  └─> v2 (z_image_control2)
        └─> v2.1 (z_image_control2_1) ← Highest quality
```

## Advanced Settings and Options

### Pipeline Arguments
```python
pipe(
    prompt: str,
    control_image: torch.Tensor,
    height: int = 1920,
    width: int = 1088,
    num_inference_steps: int = 9,
    guidance_scale: float = 0.0,
    control_context_scale: float = 0.65,  # Lower than v1/v2
    negative_prompt: str = None,
)
```

### Control Weight Tuning for v2.1
Due to more control layers, **lower weights recommended**:
- **Range**: 0.0 - 2.0
- **Default**: 0.65 (optimal for v2.1)
- **Lower** (0.4-0.6): More creative, loose control
- **Default** (0.65): Balanced (recommended)
- **Higher** (0.7-0.9): Stronger control
- **Very High** (>0.9): May over-constrain at high res

### Resolution Recommendations
```python
# HD 16:9 (optimal)
height=1920, width=1088

# Alternative 16:9
height=1792, width=1008
height=1536, width=864

# Square (works but use v1/v2 instead)
height=1024, width=1024

# Ultra-HD (requires 24GB+ VRAM)
height=2048, width=1152
```

## Model Loading Example

```python
from models.z_image.z_image_handler import family_handler

pipe_processor, pipe = family_handler.load_model(
    model_filename=[
        "ZImageTurbo_bf16.safetensors",  # Base model
        "Z-Image-Turbo-Fun-Controlnet-Union2.1_bf16.safetensors"  # ControlNet v2.1
    ],
    base_model_type="z_image_control2_1",
    quantizeTransformer=False,
    dtype=torch.bfloat16,
    VAE_dtype=torch.float32,
    is_control=True,
)
```

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/z_image_handler.py` (Lines 130-133)

## HD Generation Workflow Example

### Widescreen Pose-Guided Generation
```python
# 1. Load model
pipe = load_z_image_controlnet_v2_1()

# 2. Prepare pose control at HD resolution
pose_image = detect_pose(reference_image)
pose_image_hd = resize_to_hd(pose_image, 1920, 1088)

# 3. Generate HD image
result = pipe(
    prompt="cinematic portrait, professional photography, studio lighting",
    control_image=pose_image_hd,
    control_context_scale=0.65,
    height=1920,
    width=1088,
    num_inference_steps=9,
)
```

### HD Canny Edge Control
```python
# For architectural visualization
import cv2

# Prepare HD edge control
edges = cv2.Canny(reference_image_hd, 100, 200)
control_tensor = preprocess_control_image(edges, 1920, 1088)

result = pipe(
    prompt="modern glass building, urban architecture, blue sky",
    control_image=control_tensor,
    control_context_scale=0.60,  # Slightly lower for creativity
    height=1920,
    width=1088,
)
```

## Performance Characteristics

### Speed
- **9 steps** at 1920x1088
- Approximately **8-12 seconds** per image on RTX 4090
- Approximately **20-30 seconds** per image on RTX 3090
- About **2x slower** than v1/v2 at 1024x1024 (due to resolution)

### VRAM Requirements
- **BF16**: ~20-22 GB at 1920x1088
- **INT8**: ~13-15 GB at 1920x1088
- **Recommended**: RTX 4090 (24GB) or better for BF16
- **Minimum**: RTX 3090Ti (24GB) or RTX 4080 (16GB with INT8)

### Quality Characteristics
- **Control Adherence**: Best of all variants
- **Detail Preservation**: Excellent at high res
- **Consistency**: High stability
- **Balanced Control**: Lower weight doesn't compromise quality

## 8-Step Variant (Experimental)

A special 8-step variant exists (mostly hidden):

**Configuration**: `/opt/wan2gp/Wan2GP/defaults/z_image_control2_1_8s.json`

**Code Reference**: `/opt/wan2gp/Wan2GP/defaults/z_image_control2_1_8s.json` (Line 11)

```json
{
  "name": "Z-Image Turbo Fun ControlNet v2.1 8 Steps YYY 6B",
  "visible": false,
  "num_inference_steps": 8,
  // ...
}
```

- **Steps**: 8 (instead of 9)
- **Purpose**: Slightly faster
- **Visibility**: Hidden (experimental)
- **Quality**: Slightly lower than 9-step

## Compatibility Notes

### Model Equivalence
v2.1 maps to v2 for model loading:

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/z_image_handler.py` (Lines 66-68)

```python
models_eqv_map = {
    "z_image_control2_1": "z_image_control2",
    "z_image_base": "z_image",
}
```

### Parent-Child Hierarchy
```
z_image_control (v1)
  └─ (parent of)
     z_image_control2 (v2)
       └─ (parent of)
          z_image_control2_1 (v2.1) ← This model
```

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/z_image_handler.py` (Line 41)

## LoRA Support

### Compatibility
- **Supported**: Yes (full support)
- **Directory**: `lora_root/z_image/`
- **Combined**: Can use LoRA + ControlNet simultaneously
- **Resolution**: LoRAs trained at 1024x1024 may work differently at 1920x1088

## Inpainting Preparation (Future Feature)

### Current Status
Same as v2:
- **Infrastructure**: In place
- **Feature**: Disabled
- **Mask Preprocessing**: `["", "A", "NA"]` defined

### Future Enhancement
When enabled, will support HD inpainting with control:
```python
# Future usage
result = pipe(
    prompt="fill area with detailed texture",
    control_image=structure_guide_hd,
    inpaint_mask=mask_hd,
    height=1920,
    width=1088,
)
```

## Optimization Tips for HD Generation

### 1. VRAM Management
```python
# Enable VAE slicing (always on)
pipe.vae.enable_slicing()

# Use INT8 quantization if needed
quantizeTransformer=True

# Sequential offloading for lower VRAM
pipe.enable_sequential_cpu_offload()
```

### 2. Control Weight Tuning
```python
# For creative freedom at HD
control_context_scale=0.50-0.60

# For strong adherence
control_context_scale=0.65-0.75  # Don't exceed 0.75
```

### 3. Batch Processing
```python
# Process multiple images sequentially, not in batches
batch_size=1  # Required for HD

# Clear cache between generations
torch.cuda.empty_cache()
```

## Migration from v1/v2

### When to Migrate to v2.1
- ✅ Need HD/widescreen output
- ✅ 16:9 aspect ratio required
- ✅ Have 20GB+ VRAM
- ✅ Want best control quality

### When to Stay on v1/v2
- ❌ Primarily use 1024x1024
- ❌ Limited VRAM (<16GB)
- ❌ Square or portrait images
- ❌ v1/v2 quality sufficient

### Migration Example
```python
# From v2:
base_model_type="z_image_control2"
height=1024, width=1024
control_weight=0.75

# To v2.1:
base_model_type="z_image_control2_1"
height=1920, width=1088  # HD resolution
control_weight=0.65      # Adjust down
```

## Limitations

### Resolution Focus
- **Optimized**: 1920x1088 and 16:9 ratios
- **Not Optimal**: Square (1024x1024) - use v1/v2 instead
- **Not Optimal**: Portrait (3:4) - use v1/v2 instead

### VRAM Requirements
- **High**: 20GB+ for BF16
- **Minimum**: 16GB with INT8
- Not suitable for low VRAM systems

### Inpainting
- Still disabled (same as v2)
- Wait for future updates

## Text Encoder and VAE

### Shared Components
- **Text Encoder**: Qwen3 (512 tokens)
- **VAE**: `ZImageTurbo_VAE_bf16.safetensors`
- **Scale Factor**: 16
- All shared with other Z-Image variants

## Additional Notes

### Why 1088 instead of 1080?
- **Divisibility**: Must be divisible by 16 (VAE constraint)
- **1080 ÷ 16 = 67.5** (not integer)
- **1088 ÷ 16 = 68** (perfect)
- Minimal visual difference from 1080p

### Recommended GPU
- **RTX 4090** (24GB): Ideal, BF16
- **RTX 3090/3090Ti** (24GB): Good, BF16
- **RTX 4080** (16GB): Use INT8, works
- **RTX 4070Ti/S** (12GB): Too small for BF16

---

**Last Updated**: 2/8/2026
**Model Version**: Z-Image Turbo Fun ControlNet v2.1 6B
**HuggingFace**: DeepBeepMeep/Z-Image
**Control Types**: Pose, Canny, Depth, Scribble (Most Enhanced)
**Optimized Resolution**: 1920x1088 (16:9 HD)
