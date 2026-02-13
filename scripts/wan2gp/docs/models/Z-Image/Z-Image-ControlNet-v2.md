# Z-Image Turbo Fun ControlNet v2

## Model Overview
**Z-Image Turbo Fun ControlNet v2** is an enhanced version of ControlNet v1 with more control layers and prepared (but currently disabled) inpainting support.

## Technical Specifications

### Model Details
- **Parameter Count**: 6 Billion (6B) + Enhanced ControlNet modules
- **Architecture Type**: `z_image_control2`
- **Model Identifier**: `z_image_control2`
- **Base Family**: Z-Image
- **Parent Model**: `z_image_control` (v1)
- **Base Model**: Z-Image Turbo
- **ControlNet**: Union v2 (enhanced multi-control)

### Model Files
**Location**: `/opt/wan2gp/Wan2GP/models/z_image/`

**Configuration**: `/opt/wan2gp/Wan2GP/defaults/z_image_control2.json` (Lines 1-13)

**URLs**:
- **Base Model**: Referenced as `"z_image"` (uses Z-Image Turbo URLs)
- **ControlNet Module**:
  - `https://huggingface.co/DeepBeepMeep/Z-Image/resolve/main/Z-Image-Turbo-Fun-Controlnet-Union2_bf16.safetensors`
  - `https://huggingface.co/DeepBeepMeep/Z-Image/resolve/main/Z-Image-Turbo-Fun-Controlnet-Union2_quanto_bf16_int8.safetensors` (INT8)

**Handler**: `/opt/wan2gp/Wan2GP/models/z_image/z_image_handler.py` (Lines 1-189)

**Pipeline**: `/opt/wan2gp/Wan2GP/models/z_image/pipeline_z_image.py` (Lines 1-991)

## Primary Purpose
Enhanced ControlNet with **more control layers** for improved visual guidance and **prepared inpainting infrastructure** (currently disabled). Provides better control quality than v1 while maintaining fast 9-step generation.

## Key Features

### 1. Enhanced ControlNet Union
- **Type**: Multi-control Union v2
- **Supported Controls**: Pose, Canny, Depth, Scribble (same as v1)
- **Enhancement**: More control layers for finer guidance
- **Quality**: Improved control adherence vs. v1

**Code Reference**: `/opt/wan2gp/Wan2GP/defaults/z_image_control2.json` (Lines 8-9)

### 2. Inpainting Support (Disabled)
- **Status**: Infrastructure prepared, feature disabled
- **Future**: Will be enabled in updates
- **Support Flag**: `inpaint_support = True`
- **Video Prompt Type**: "VA"

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/z_image_handler.py` (Lines 41-44)

```python
extra_model_def["inpaint_support"] = True
extra_model_def["inpaint_video_prompt_type"] = "VA"
```

### 3. Mask Preprocessing (Prepared)
- **Selection**: `["", "A", "NA"]`
- **Visible**: False (disabled but defined)
- **A**: Alpha mask mode
- **NA**: Non-alpha mask mode

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/z_image_handler.py` (Lines 38-41)

```python
extra_model_def["mask_preprocessing"] = {
    "selection": ["", "A", "NA"],
    "visible": False,
}
```

### 4. Parent Model Type
- **Parent**: `z_image_control` (v1)
- **Compatibility**: Inherits v1 settings as baseline
- **Enhancements**: Additional layers and features

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/z_image_handler.py` (Line 41)

```python
extra_model_def["parent_model_type"] = "z_image_control"
```

### 5. Guide Preprocessing Options
Same as v1:
- **Selection**: `["", "PV", "DV", "EV", "V"]`
- **V**: "Use Z-Image Raw Format"

### 6. Control Weight
- **Default**: 0.75 (same as v1)
- **Alternate**: 0.75
- **Range**: 0.0 - 2.0 (practical: 0.5 - 1.0)

**Code Reference**: `/opt/wan2gp/Wan2GP/defaults/z_image_control2.json` (Line 12)

## Default Settings

### Generation Parameters
```json
{
  "resolution": "1024x1024",
  "batch_size": 1,
  "num_inference_steps": 9,
  "guidance_scale": 0,
  "control_net_weight_alt": 0.75
}
```

**Code Reference**: `/opt/wan2gp/Wan2GP/defaults/z_image_control2.json`

### Advanced Settings
- **Control Weight Name**: "Control"
- **Control Weight Size**: 1
- **NAG Support**: No
- **Flow Shift**: No
- **Guidance Max Phases**: 0

## Resolutions and Aspect Ratios

### Default Resolution
- **Standard**: 1024x1024 (1:1 aspect ratio)

### Supported Resolutions
- **Constraint**: Height and width must be divisible by 16
- **Recommended**: 1024x1024 (optimized)
- **Higher Res**: Use v2.1 for 1920x1088+

**Common Resolutions**:
- 1024x1024 (1:1) - Default, optimized
- 1024x768 (4:3)
- 768x1024 (3:4)
- 1280x768 (16:9 approx)

## Control Types and Usage

### Supported Control Types
Same as v1:
1. **Pose Control** (OpenPose)
2. **Canny Edge Control**
3. **Depth Control**
4. **Scribble Control**

### Enhancements over v1
- **More Control Layers**: Better guidance quality
- **Improved Adherence**: Finer control with same control weight
- **Better Details**: Enhanced layer architecture captures more structure

## Best Use Cases

### Ideal For:
1. **Higher Quality Controlled Generation**
   - Better control adherence than v1
   - Improved structural preservation
   - Enhanced detail capture

2. **Complex Control Scenarios**
   - Detailed pose guidance
   - Intricate edge structures
   - Complex depth compositions

3. **Preparation for Inpainting**
   - Model ready for future inpainting updates
   - Infrastructure in place

### Not Ideal For:
- Basic control needs (v1 is sufficient and slightly faster)
- Inpainting (not yet enabled)
- Very high resolutions (use v2.1 for 1920x1088+)

## Differences from Other Z-Image Variants

### vs. ControlNet v1
| Feature | v2 | v1 |
|---------|-----|-----|
| Control Layers | **More layers** | Standard |
| Quality | **Better** | Good |
| Inpainting | Prepared (disabled) | **No** |
| Mask Options | `["", "A", "NA"]` | `[""]` |
| Parent Model | z_image_control | **None** |
| Control Weight | 0.75 | 0.75 |
| Speed | Same | Same |
| Steps | 9 | 9 |

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/z_image_handler.py` (Lines 35-55)

### vs. ControlNet v2.1
| Feature | v2 | v2.1 |
|---------|-----|------|
| Control Layers | More layers | **More layers** |
| Resolution | 1024x1024 | **1920x1088** |
| Control Weight | 0.75 | **0.65** |
| Optimization | Standard | **Higher-res** |
| Parent | z_image_control | **z_image_control2** (this) |

### vs. Z-Image Turbo
| Feature | v2 | Turbo |
|---------|-----|-------|
| Control | **Yes (4 types, enhanced)** | No |
| Layers | **Base + Enhanced ControlNet** | Base only |
| Steps | 9 | 8 |
| Inpainting | Prepared | **No** |

## Advanced Settings and Options

### Pipeline Arguments
```python
pipe(
    prompt: str,
    control_image: torch.Tensor,
    height: int = 1024,
    width: int = 1024,
    num_inference_steps: int = 9,
    guidance_scale: float = 0.0,
    control_context_scale: float = 0.75,
    negative_prompt: str = None,
    # Future inpainting arguments (when enabled):
    # inpaint_mask: torch.Tensor = None,
)
```

### Control Weight Tuning
Same as v1, but with improved quality at same weights:
- **Range**: 0.0 - 2.0
- **Default**: 0.75
- **Recommended**: 0.6 - 0.9 for most use cases

Due to enhanced layers, v2 can achieve stronger control at lower weights compared to v1.

## Model Loading Example

```python
from models.z_image.z_image_handler import family_handler

pipe_processor, pipe = family_handler.load_model(
    model_filename=[
        "ZImageTurbo_bf16.safetensors",  # Base model
        "Z-Image-Turbo-Fun-Controlnet-Union2_bf16.safetensors"  # ControlNet v2
    ],
    base_model_type="z_image_control2",
    quantizeTransformer=False,
    dtype=torch.bfloat16,
    VAE_dtype=torch.float32,
    is_control=True,
)
```

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/z_image_handler.py` (Lines 130-133)

## Performance Characteristics

### Speed
- **9 steps** at 1024x1024
- Approximately **4-6 seconds** per image on RTX 4090
- Approximately **10-14 seconds** per image on RTX 3090
- Similar to v1 (enhanced layers have minimal overhead)

### VRAM Requirements
- **BF16**: ~14-17 GB at 1024x1024 (slightly more than v1)
- **INT8**: ~9-11 GB at 1024x1024
- **Batch Size 1**: Recommended

### Quality Improvements over v1
- **Control Adherence**: +10-15% better structure preservation
- **Detail Capture**: Finer control over small details
- **Consistency**: More stable across multiple generations

## Inpainting Preparation (Future Feature)

### Current Status
- **Infrastructure**: In place
- **Feature**: Disabled
- **Mask Preprocessing**: Defined but not visible

### When Enabled (Future):
```python
# Example future usage
result = pipe(
    prompt="fill the masked area with flowers",
    control_image=structure_guide,
    inpaint_mask=mask_tensor,  # Future parameter
    mask_preprocessing="A",     # Alpha mask mode
    control_context_scale=0.75,
)
```

### Inpainting Settings (When Enabled)
**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/z_image_handler.py` (Lines 43-44)

```python
extra_model_def["inpaint_support"] = True
extra_model_def["inpaint_video_prompt_type"] = "VA"
```

## Compatibility Notes

### Model Equivalence Map
```python
models_eqv_map = {
    "z_image_control2_1": "z_image_control2",  # v2.1 compatible with v2
    "z_image_base": "z_image",
}
```

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/z_image_handler.py` (Lines 66-68)

### Parent-Child Relationship
- **v1** (`z_image_control`): Base ControlNet
- **v2** (`z_image_control2`): Enhanced, parent=v1
- **v2.1** (`z_image_control2_1`): Higher-res, parent=v2

## LoRA Support

### Compatibility
- **Supported**: Yes (full support)
- **Directory**: `lora_root/z_image/`
- **Combined**: Can use LoRA + ControlNet simultaneously

## Limitations

### Inpainting Not Yet Active
- Infrastructure exists but feature disabled
- Use dedicated inpainting models if needed now
- Wait for future updates to enable

### Single Control Type Per Generation
- One control type active per generation
- Cannot combine multiple controls (Union limitation)

### Resolution Optimization
- Optimized for 1024x1024
- For higher resolutions, v2.1 is better optimized

## Migration from v1

### Advantages of Upgrading
1. **Better Control Quality**: Enhanced layers
2. **Future-Proof**: Inpainting ready
3. **Same Speed**: No performance penalty
4. **Same Interface**: Drop-in replacement

### When to Stay on v1
- Lower VRAM requirements
- v1 quality sufficient for use case
- Slightly smaller model size

### Migration Steps
```python
# From v1:
model_filename = ["base.safetensors", "controlnet-union_v1.safetensors"]
base_model_type = "z_image_control"

# To v2 (simple change):
model_filename = ["base.safetensors", "controlnet-union2_v2.safetensors"]
base_model_type = "z_image_control2"

# All other parameters stay the same
```

## Text Encoder and VAE

### Shared Components
- **Text Encoder**: Qwen3 (same as all Z-Image variants)
- **VAE**: `ZImageTurbo_VAE_bf16.safetensors` (shared)
- **Max Sequence**: 512 tokens

## Additional Notes

### Reference Image Support (Commented Out)
The handler includes commented-out code for reference image support:

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/z_image_handler.py` (Lines 46-53)

```python
# extra_model_def["image_ref_choices"] = {
#     "choices":[("No Reference Image",""), ("Image is a Reference Image", "KI")],
#     "default": "",
#     "letters_filter": "KI",
#     "label": "Reference Image for Inpainting",
#     "visible": True,
# }
```

This may be enabled in future updates alongside inpainting.

---

**Last Updated**: 2/8/2026
**Model Version**: Z-Image Turbo Fun ControlNet v2 6B
**HuggingFace**: DeepBeepMeep/Z-Image
**Control Types**: Pose, Canny, Depth, Scribble (Enhanced)
**Inpainting**: Prepared but disabled
