# Z-Image Turbo

## Model Overview
**Z-Image Turbo** is a powerful and highly efficient distilled image generation model designed for fast, high-quality image synthesis.

## Technical Specifications

### Model Details
- **Parameter Count**: 6 Billion (6B)
- **Architecture Type**: `z_image`
- **Model Identifier**: `z_image`
- **Base Family**: Z-Image
- **Model Priority**: 120

### Model Files
**Location**: `/opt/wan2gp/Wan2GP/models/z_image/`

**Configuration**: `/opt/wan2gp/Wan2GP/defaults/z_image.json` (Lines 1-11)

**URLs**:
- `https://huggingface.co/DeepBeepMeep/Z-Image/resolve/main/ZImageTurbo_bf16.safetensors`
- `https://huggingface.co/DeepBeepMeep/Z-Image/resolve/main/ZImageTurbo_quanto_bf16_int8.safetensors` (INT8 quantized)

**Handler**: `/opt/wan2gp/Wan2GP/models/z_image/z_image_handler.py` (Lines 1-189)

**Pipeline**: `/opt/wan2gp/Wan2GP/models/z_image/pipeline_z_image.py` (Lines 1-991)

## Primary Purpose
Z-Image Turbo is a **distilled version** of Z-Image Base that matches or exceeds leading competitors with significantly fewer steps. It's optimized for speed while maintaining high quality, making it ideal for real-time or interactive applications.

## Key Features

### 1. Fast Generation
- **Default Steps**: 8 NFEs (Neural Function Evaluations)
- **Speed-optimized** distilled model
- Achieves quality comparable to base model in ~27% of the steps

### 2. No Guidance Required
- **Guidance Scale**: 0 (guidance-free operation)
- Pre-distilled to produce high-quality results without CFG overhead
- Faster inference without guidance calculations

### 3. NAG Support (Negative-prompt Adaptive Guidance)
- **NAG Enabled**: Yes (unique to Turbo variant)
- **Default NAG Scale**: 1.0
- **Default NAG Tau**: 3.5
- **Default NAG Alpha**: 0.5
- Provides negative prompt control without traditional CFG
- Only active when `guidance_scale <= 1` and `NAG_scale > 1`

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/z_image_handler.py` (Lines 57, 174-178)

```python
extra_model_def["NAG"] = base_model_type in ["z_image"]
ui_defaults.update({
    "NAG_scale": 1.0,
    "NAG_tau": 3.5,
    "NAG_alpha": 0.5,
})
```

### 4. LoRA Support
- **LoRA Directory**: `lora_root/z_image/`
- **CLI Argument**: `--lora-dir-z-image`
- Full LoRA support for customization and fine-tuning

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/z_image_handler.py` (Lines 83-95)

## Default Settings

### Generation Parameters
```json
{
  "resolution": "1024x1024",
  "batch_size": 1,
  "num_inference_steps": 8,
  "guidance_scale": 0
}
```

### Advanced Settings
- **Flow Shift**: Not used (Base model only)
- **Guidance Max Phases**: 0
- **VAE Scale Factor**: 16 (8x8 downsampling)

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/z_image_handler.py` (Lines 9-12)

## Resolutions and Aspect Ratios

### Default Resolution
- **Standard**: 1024x1024 (1:1 aspect ratio)

### Supported Resolutions
- **Constraint**: Height and width must be divisible by 16 (VAE scale factor * 2)
- **Minimum**: 512x512 (practical minimum)
- **Maximum**: Limited by VRAM (4096x4096+ possible)

**Common Resolutions**:
- 1024x1024 (1:1) - Default
- 1024x768 (4:3)
- 768x1024 (3:4)
- 1280x768 (16:9 approx)
- 1920x1088 (16:9 HD)

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/pipeline_z_image.py` (Lines 495-509)

```python
height = height or 1024
width = width or 1024

vae_scale = self.vae_scale_factor * 2  # 16
if height % vae_scale != 0:
    raise ValueError(f"Height must be divisible by {vae_scale}")
if width % vae_scale != 0:
    raise ValueError(f"Width must be divisible by {vae_scale}")
```

### Image Sequence Length Calculation
```python
image_seq_len = (height // 16) * (width // 16)
```

## Text Encoder

### Architecture
- **Model**: Qwen3 (Causal Language Model)
- **Max Sequence Length**: 512 tokens
- **Tokenizer**: AutoTokenizer (Qwen3)

### Text Encoder Files
**Folder**: `Qwen3/`

**URLs**:
- `qwen3_bf16.safetensors`
- `qwen3_quanto_bf16_int8.safetensors` (INT8 quantized)

**Additional Files**:
- `tokenizer.json`
- `tokenizer_config.json`
- `vocab.json`
- `config.json`
- `merges.txt`

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/z_image_handler.py` (Lines 15-20)

### Negative Prompting
**Default Negative Prompt**:
```
"low quality, worst quality, blurry, pixelated, noisy, artifacts, watermark, text, logo, bad anatomy, bad hands, extra limbs"
```

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/pipeline_z_image.py` (Lines 71-74)

## VAE (Variational Autoencoder)

### Configuration Files
- `ZImageTurbo_VAE_bf16_config.json`
- `ZImageTurbo_VAE_bf16.safetensors`

### VAE Settings
- **Scale Factor**: 8 (base)
- **Effective Scale**: 16 (for height/width constraints)
- **Default Dtype**: float32 (for precision)
- **Slicing**: Enabled for VRAM optimization

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/z_image_handler.py` (Lines 107-108)

## Scheduler

### Type
- **FlowMatchEulerDiscreteScheduler**
- **Config**: `ZImageTurbo_scheduler_config.json`
- **Method**: Flow Matching with Euler discrete stepping

### Shift Calculation
Used for timestep scheduling based on image resolution:

```python
def calculate_shift(image_seq_len, 
                   base_seq_len=256, 
                   max_seq_len=4096,
                   base_shift=0.5, 
                   max_shift=1.15):
    m = (max_shift - base_shift) / (max_seq_len - base_seq_len)
    b = base_shift - m * base_seq_len
    mu = image_seq_len * m + b
    return mu
```

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/pipeline_z_image.py` (Lines 78-86)

## Best Use Cases

### Ideal For:
1. **Real-time Applications**
   - Interactive image generation
   - Live preview systems
   - Rapid iteration workflows

2. **Batch Processing**
   - High-volume image generation
   - Dataset creation
   - Automated content generation

3. **Creative Exploration**
   - Quick concept sketches
   - Idea exploration
   - Rapid prototyping

4. **Resource-Constrained Environments**
   - Limited GPU time
   - Cost-sensitive deployments
   - Mobile or edge deployment (with quantization)

### Not Ideal For:
- Extreme high-quality requirements (use Z-Image Base instead)
- Fine-grained control needs (use ControlNet variants)
- Specialized artistic styles requiring long inference

## Differences from Other Z-Image Variants

### vs. Z-Image Base
| Feature | Turbo | Base |
|---------|-------|------|
| Steps | 8 | 30 |
| Guidance | 0 (none) | 4.0 |
| Speed | Fast | Slower |
| Quality | High | Highest |
| NAG Support | Yes | No |
| Flow Shift | No | Yes (6.0) |
| Purpose | Speed | Quality |

### vs. TwinFlow Turbo
| Feature | Turbo | TwinFlow |
|---------|-------|----------|
| Steps | 8 | 2-4 |
| Sampler | Standard | Unified |
| Speed | Fast | Fastest |
| Optimization | General | 1-4 step specialized |

### vs. ControlNet Variants
| Feature | Turbo | ControlNet |
|---------|-------|------------|
| Control | Prompt only | Prompt + Visual |
| ControlNet | No | Yes |
| Steps | 8 | 9 |
| Control Weight | N/A | 0.65-0.75 |

### vs. Nunchaku Variants
| Feature | Turbo | Nunchaku |
|---------|-------|----------|
| Precision | BF16/INT8 | FP4/INT4 |
| VRAM | Standard | Minimal |
| Speed | Fast | Fastest (with sm120+) |
| Quality | Full | Slightly reduced |

## Advanced Settings and Options

### Pipeline Arguments
```python
pipe(
    prompt: str,
    height: int = 1024,
    width: int = 1024,
    num_inference_steps: int = 8,
    guidance_scale: float = 0.0,
    negative_prompt: str = None,
    num_images_per_prompt: int = 1,
    generator: torch.Generator = None,
    latents: torch.FloatTensor = None,
    NAG_scale: float = 1.0,
    NAG_tau: float = 3.5,
    NAG_alpha: float = 0.5,
    max_sequence_length: int = 512,
)
```

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/pipeline_z_image.py` (Lines 384-412)

### NAG Parameters

#### NAG_scale
- **Range**: 1.0 - 2.0 (higher = stronger negative guidance)
- **Default**: 1.0
- Controls the strength of negative prompt influence

#### NAG_tau
- **Range**: 1.0 - 10.0
- **Default**: 3.5
- Controls the timestep at which NAG is applied

#### NAG_alpha
- **Range**: 0.0 - 1.0
- **Default**: 0.5
- Controls blending between guided and unguided predictions

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/pipeline_z_image.py` (Lines 516-519)

```python
NAG = None
if NAG_scale > 1 and guidance_scale <= 1:
    NAG = {"scale": NAG_scale, "tau": NAG_tau, "alpha": NAG_alpha}
```

### Attention Backends
Configurable through transformer settings:
- **SDPA** (default): PyTorch Scaled Dot-Product Attention
- **flash**: Flash Attention 2
- **_flash_3**: Flash Attention 3

**Code Reference**: `/opt/wan2gp/Wan2GP/defaults/z_image.json` (Example comment in pipeline)

### Quantization Options

#### INT8 Quantization
- **Method**: Quanto BF16→INT8
- **VRAM Savings**: ~50%
- **Quality Impact**: Minimal
- **File**: `ZImageTurbo_quanto_bf16_int8.safetensors`

#### Text Encoder Quantization
- **Available**: Yes
- **Method**: Quanto BF16→INT8
- **File**: `qwen3_quanto_bf16_int8.safetensors`

## Model Loading Example

```python
from models.z_image.z_image_handler import family_handler

pipe_processor, pipe = family_handler.load_model(
    model_filename="ZImageTurbo_bf16.safetensors",
    base_model_type="z_image",
    quantizeTransformer=False,
    dtype=torch.bfloat16,
    VAE_dtype=torch.float32,
)
```

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/z_image_handler.py` (Lines 114-155)

## Performance Characteristics

### Speed
- **8 steps** at 1024x1024
- Approximately **3-5 seconds** per image on RTX 4090
- Approximately **8-12 seconds** per image on RTX 3090

### VRAM Requirements
- **BF16**: ~12-14 GB at 1024x1024
- **INT8**: ~7-9 GB at 1024x1024
- **Batch Size 1**: Recommended for most GPUs

### Scaling with Resolution
- 1024x1024: Baseline
- 1920x1088: ~2x compute
- 2048x2048: ~4x compute

## Compatibility Notes

### Supported Model Types
From handler: `["z_image", "z_image_base", "z_image_control", "z_image_control2", "z_image_control2_1"]`

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/z_image_handler.py` (Line 61)

### Model Equivalence Map
- `z_image_base` → `z_image` (shares base architecture)
- `z_image_control2_1` → `z_image_control2` (compatible)

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/z_image_handler.py` (Lines 65-72)

## Additional Notes

### Text Encoder Caching
- **Enabled**: Yes
- **Purpose**: Speeds up repeated generations with same prompts
- **Implementation**: TextEncoderCache class

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/pipeline_z_image.py` (Line 237)

### VAE Slicing
- **Enabled**: Always
- **Purpose**: Reduces VRAM usage during decode
- **Method**: Process VAE in tiles

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/pipeline_z_image.py` (Line 524)

### Offloading Support
- **MMGP Offload**: Supported
- **Sequential offload**: text_encoder→transformer→vae
- **Purpose**: Enable larger models on smaller GPUs

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/pipeline_z_image.py` (Line 210)

---

**Last Updated**: 2/8/2026
**Model Version**: Z-Image Turbo 6B
**HuggingFace**: DeepBeepMeep/Z-Image
