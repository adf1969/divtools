# Z-Image Turbo Fun ControlNet v1

## Model Overview
**Z-Image Turbo Fun ControlNet v1** is Z-Image Turbo enhanced with ControlNet Union support for visual control via Pose, Canny, Depth, and Scribble conditioning.

## Technical Specifications

### Model Details
- **Parameter Count**: 6 Billion (6B) + ControlNet modules
- **Architecture Type**: `z_image_control`
- **Model Identifier**: `z_image_control`
- **Base Family**: Z-Image
- **Base Model**: Z-Image Turbo
- **ControlNet**: Union (multi-control)

### Model Files
**Location**: `/opt/wan2gp/Wan2GP/models/z_image/`

**Configuration**: `/opt/wan2gp/Wan2GP/defaults/z_image_control.json` (Lines 1-12)

**URLs**:
- **Base Model**: Referenced as `"z_image"` (uses Z-Image Turbo URLs)
- **ControlNet Module**:
  - `https://huggingface.co/DeepBeepMeep/Z-Image/resolve/main/Z-Image-Turbo-Fun-Controlnet-Union_bf16.safetensors`
  - `https://huggingface.co/DeepBeepMeep/Z-Image/resolve/main/Z-Image-Turbo-Fun-Controlnet-Union_quanto_bf16_int8.safetensors` (INT8)

**Handler**: `/opt/wan2gp/Wan2GP/models/z_image/z_image_handler.py` (Lines 1-189)

**ControlNet Class**: `/opt/wan2gp/Wan2GP/models/z_image/z_image_controlnet.py`

## Primary Purpose
Adds **visual control** capabilities to Z-Image Turbo, allowing generation guided by structural inputs like poses, edges, depth maps, and sketches while maintaining fast 9-step generation.

## Key Features

### 1. ControlNet Union
- **Type**: Multi-control (single model, multiple control types)
- **Supported Controls**:
  - **Pose**: OpenPose skeletal structure
  - **Canny**: Edge detection
  - **Depth**: Depth map guidance
  - **Scribble**: Hand-drawn sketches

**Code Reference**: `/opt/wan2gp/Wan2GP/defaults/z_image_control.json` (Lines 3-4)

### 2. Guide Preprocessing Options
- **Selection**: `["", "PV", "DV", "EV", "V"]`
- **V**: "Use Z-Image Raw Format" (native format)
- **PV/DV/EV**: Preprocessing variants

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/z_image_handler.py` (Lines 29-33)

```python
extra_model_def["guide_preprocessing"] = {
    "selection": ["", "PV", "DV", "EV", "V"],
    "labels": {"V": "Use Z-Image Raw Format"},
}
```

### 3. Control Weight
- **Parameter**: `control_net_weight`
- **Default**: 0.75
- **Alternate**: `control_net_weight_alt` also 0.75
- **Range**: 0.0 - 2.0 (practical: 0.5 - 1.0)

**Code Reference**: `/opt/wan2gp/Wan2GP/defaults/z_image_control.json` (Line 11)

### 4. Fast Generation
- **Steps**: 9 (one more than base Turbo for control integration)
- **Guidance**: 0 (guidance-free)
- Still fast while adding control capability

### 5. Mask Preprocessing (Disabled)
- **Selection**: `[""]` (empty, no options)
- **Visible**: False
- Reserved for future inpainting support

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/z_image_handler.py` (Lines 25-28)

```python
extra_model_def["mask_preprocessing"] = {
    "selection": [""],
    "visible": False
}
```

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

**Code Reference**: `/opt/wan2gp/Wan2GP/defaults/z_image_control.json`

### Advanced Settings
- **Control Weight Name**: "Control"
- **Control Weight Size**: 1
- **NAG Support**: No (inherited from Turbo, but disabled for control)
- **Flow Shift**: No
- **Guidance Max Phases**: 0

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/z_image_handler.py` (Lines 30-32, 183-188)

```python
extra_model_def["control_net_weight_name"] = "Control"
extra_model_def["control_net_weight_size"] = 1

# Control defaults
if base_model_type in ["z_image_control", "z_image_control2", "z_image_control2_1"]:
    ui_defaults.update({
        "control_net_weight": 0.75,
    })
```

## Resolutions and Aspect Ratios

### Default Resolution
- **Standard**: 1024x1024 (1:1 aspect ratio)

### Supported Resolutions
- **Constraint**: Height and width must be divisible by 16
- **Recommended**: Match control image resolution
- **Minimum**: 512x512
- **Maximum**: VRAM-dependent (2048x2048+)

**Common Resolutions**:
- 1024x1024 (1:1) - Default
- 1024x768 (4:3)
- 768x1024 (3:4)
- 1280x768 (16:9 approx)
- 1920x1088 (16:9 HD) - Use v2.1 instead

### Control Image Requirements
- **Resolution**: Must match output resolution
- **Format**: RGB or grayscale (depending on control type)
- **Preprocessing**: Auto-applied based on guide_preprocessing setting

## Control Types and Usage

### 1. Pose Control (OpenPose)
**Input**: OpenPose skeletal keypoints
**Use Cases**:
- Character posing
- Human figure guidance
- Maintaining posture across variations
- Dance/action sequences

**Preprocessing**:
- Automatic keypoint detection from images
- Or provide pre-computed OpenPose JSON

### 2. Canny Edge Control
**Input**: Canny edge detection map
**Use Cases**:
- Structural guidance
- Preserving compositions
- Architectural outlines
- Detail preservation

**Preprocessing**:
- Automatic Canny edge detection
- Configurable thresholds

### 3. Depth Control
**Input**: Depth map (monocular or stereo)
**Use Cases**:
- 3D structure guidance
- Spatial composition
- Perspective control
- Layered scenes

**Preprocessing**:
- Automatic depth estimation
- Normalized depth values

### 4. Scribble Control
**Input**: Hand-drawn sketch or scribble
**Use Cases**:
- Creative sketching
- Rough composition guidance
- Freeform artistic input
- Quick ideation

**Preprocessing**:
- Minimal (preserves hand-drawn character)
- Optional edge refinement

## Best Use Cases

### Ideal For:
1. **Pose-Guided Generation**
   - Character design with specific poses
   - Animation keyframes
   - Reference-based character creation

2. **Structure Preservation**
   - Maintaining composition from reference
   - Architectural visualization
   - Product design with specific shapes

3. **Depth-Aware Generation**
   - 3D-consistent scenes
   - Layered compositions
   - Perspective-correct rendering

4. **Sketch-to-Image**
   - Concept art from sketches
   - Rough idea to refined image
   - Creative exploration

5. **Fast Controlled Generation**
   - Interactive workflows with control
   - Real-time controlled generation
   - Batch processing with structure

### Not Ideal For:
- Uncontrolled generation (use standard Turbo)
- Maximum quality (use Base + slower ControlNet)
- Inpainting (not yet supported in v1)
- Multiple simultaneous controls (Union but single type per generation)

## Differences from Other Z-Image Variants

### vs. Z-Image Turbo
| Feature | ControlNet v1 | Turbo |
|---------|---------------|-------|
| Control | Yes (4 types) | No |
| Steps | 9 | 8 |
| Speed | Fast | Faster |
| Modules | Base + ControlNet | Base only |
| Control Weight | 0.75 | N/A |
| Purpose | Controlled generation | Pure text-to-image |

### vs. ControlNet v2
| Feature | v1 | v2 |
|---------|-----|-----|
| Control Layers | Standard | More layers |
| Inpainting | No | Disabled (prepared) |
| Mask Preprocessing | Empty | `["", "A", "NA"]` |
| Parent Model | None | z_image_control |
| Resolution | 1024x1024 | 1024x1024 |
| Steps | 9 | 9 |

### vs. ControlNet v2.1
| Feature | v1 | v2.1 |
|---------|-----|------|
| Control Layers | Standard | More layers |
| Inpainting | No | Disabled (prepared) |
| Resolution | 1024x1024 | 1920x1088 |
| Control Weight | 0.75 | 0.65 |
| Optimization | General | Higher-res optimized |

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/z_image_handler.py` (Lines 35-55)

## Advanced Settings and Options

### Pipeline Arguments
```python
pipe(
    prompt: str,
    control_image: torch.Tensor,  # Required
    height: int = 1024,
    width: int = 1024,
    num_inference_steps: int = 9,
    guidance_scale: float = 0.0,
    control_context_scale: float = 0.75,  # Same as control_net_weight
    negative_prompt: str = None,
    generator: torch.Generator = None,
)
```

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/pipeline_z_image.py` (Lines 384-412)

### Control Weight Tuning
- **Range**: 0.0 - 2.0
- **Default**: 0.75
- **Lower** (0.3-0.6): More creative freedom, loose control
- **Default** (0.75): Balanced control and quality
- **Higher** (0.8-1.2): Stronger control adherence
- **Very High** (>1.2): May reduce quality, over-constrained

### Control Image Preprocessing

#### Auto-Preprocessing
Set via `guide_preprocessing` option:
- **""**: No preprocessing (provide preprocessed control image)
- **"PV"**: Pose Variant
- **"DV"**: Depth Variant
- **"EV"**: Edge Variant
- **"V"**: Raw Z-Image format

#### Manual Preprocessing
Provide pre-processed control image:
```python
# Example: Canny edge detection
import cv2
edges = cv2.Canny(input_image, 100, 200)
control_tensor = convert_image_to_tensor(edges)
```

## Model Loading Example

```python
from models.z_image.z_image_handler import family_handler

pipe_processor, pipe = family_handler.load_model(
    model_filename=[
        "ZImageTurbo_bf16.safetensors",  # Base model
        "Z-Image-Turbo-Fun-Controlnet-Union_bf16.safetensors"  # ControlNet
    ],
    base_model_type="z_image_control",
    quantizeTransformer=False,
    dtype=torch.bfloat16,
    VAE_dtype=torch.float32,
    is_control=True,
)
```

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/z_image_handler.py` (Lines 130-133)

## Generation Workflow Example

### Pose-Guided Generation
```python
# 1. Load model
pipe = load_z_image_controlnet_v1()

# 2. Prepare pose control image
from pose_detector import PoseDetector
pose_detector = PoseDetector()
pose_image = pose_detector.detect(reference_image)

# 3. Generate
result = pipe(
    prompt="professional portrait photo, studio lighting",
    control_image=pose_image,
    control_context_scale=0.75,
    height=1024,
    width=1024,
    num_inference_steps=9,
)
```

### Canny Edge-Guided Generation
```python
# 1. Prepare edge control
import cv2
edges = cv2.Canny(reference_image, 100, 200)
control_tensor = preprocess_control_image(edges)

# 2. Generate
result = pipe(
    prompt="beautiful landscape, sunset, vibrant colors",
    control_image=control_tensor,
    control_context_scale=0.65,  # Looser control for creativity
    num_inference_steps=9,
)
```

## Performance Characteristics

### Speed
- **9 steps** at 1024x1024
- Approximately **4-6 seconds** per image on RTX 4090
- Approximately **10-14 seconds** per image on RTX 3090
- Slightly slower than base Turbo due to ControlNet processing

### VRAM Requirements
- **BF16**: ~14-16 GB at 1024x1024 (Base + ControlNet)
- **INT8**: ~9-11 GB at 1024x1024
- **Batch Size 1**: Recommended

### Quality vs. Control Strength
```
Control Weight | Control Adherence | Creative Freedom
---------------|-------------------|------------------
0.3 - 0.5      | Loose            | High
0.6 - 0.75     | Balanced         | Medium
0.8 - 1.0      | Strong           | Low
1.1 - 2.0      | Very Strong      | Minimal
```

## LoRA Support

### Compatibility
- **Supported**: Yes
- **Directory**: `lora_root/z_image/`
- **Applies to**: Base transformer
- **ControlNet**: Separate from LoRA (both can be used together)

### Combined Usage
```python
# Load model with LoRA
pipe = load_with_lora("style_lora.safetensors")

# Generate with both LoRA and ControlNet
result = pipe(
    prompt="your prompt",
    control_image=pose_image,
    lora_scale=0.8,
    control_context_scale=0.75,
)
```

## Limitations

### Single Control Type Per Generation
- Union ControlNet supports 4 control types
- Only **one type active** per generation
- Cannot combine Pose + Depth simultaneously (v1 limitation)

### No Inpainting (v1)
- Mask preprocessing disabled
- Inpainting support reserved for v2/v2.1
- Pure control-guided text-to-image only

### Resolution Constraints
- Optimized for 1024x1024
- Higher resolutions possible but not optimized
- For 1920x1088+, use v2.1 instead

### Control Quality at 9 Steps
- Faster than standard ControlNet (typically 20+ steps)
- May have less fine-grained control than slow variants
- Good balance for most use cases

## Compatibility Notes

### Parent Model Type
- **None** (v1 is base ControlNet variant)
- v2 uses v1 as parent

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/z_image_handler.py` (Line 41)

### Model Family
Supported types: `["z_image", "z_image_base", "z_image_control", "z_image_control2", "z_image_control2_1"]`

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/z_image_handler.py` (Line 61)

## Text Encoder

### Shared with Base
- **Model**: Qwen3
- **Max Sequence**: 512 tokens
- **Files**: Same as Z-Image Turbo

### Negative Prompting
- **Supported**: Yes
- **Effectiveness**: Good (works with ControlNet)
- **Default**: Standard Z-Image negative prompt

## VAE (Variational Autoencoder)

### Shared with Base
- **Files**: `ZImageTurbo_VAE_bf16.safetensors`
- **Scale Factor**: 16
- **Slicing**: Enabled

## Additional Notes

### ControlNet Weight Naming
```python
control_net_weight_name = "Control"
control_net_weight_size = 1
```
Used for UI generation and parameter management.

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/z_image_handler.py` (Lines 30-32)

### Future Features (Prepared but Disabled)
- **Inpainting**: Mask preprocessing infrastructure exists but disabled
- Will be enabled in future updates or v2/v2.1

---

**Last Updated**: 2/8/2026
**Model Version**: Z-Image Turbo Fun ControlNet v1 6B
**HuggingFace**: DeepBeepMeep/Z-Image
**Control Types**: Pose, Canny, Depth, Scribble
