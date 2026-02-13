# Z-Image Base

## Model Overview
**Z-Image Base** is the foundation model behind Z-Image Turbo, optimized for high-quality generation, rich aesthetics, strong diversity, and controllability. It's well-suited for creative generation, fine-tuning, and downstream development.

## Technical Specifications

### Model Details
- **Parameter Count**: 6 Billion (6B)
- **Architecture Type**: `z_image_base`
- **Model Identifier**: `z_image_base`
- **Base Family**: Z-Image
- **Model Priority**: 120

### Model Files
**Location**: `/opt/wan2gp/Wan2GP/models/z_image/`

**Configuration**: `/opt/wan2gp/Wan2GP/defaults/z_image_base.json` (Lines 1-16)

**URLs**:
- `https://huggingface.co/DeepBeepMeep/Z-Image/resolve/main/ZImageBase_bf16.safetensors`
- `https://huggingface.co/DeepBeepMeep/Z-Image/resolve/main/ZImageBase_quanto_bf16_int8.safetensors` (INT8 quantized)

**Handler**: `/opt/wan2gp/Wan2GP/models/z_image/z_image_handler.py` (Lines 1-189)

**Pipeline**: `/opt/wan2gp/Wan2GP/models/z_image/pipeline_z_image.py` (Lines 1-991)

## Primary Purpose
Z-Image Base is the **foundation model** designed for **maximum quality** and **creative flexibility**. It serves as the base for distillation (creating Turbo variants) and is ideal when quality and diversity are more important than speed.

## Key Features

### 1. High-Quality Generation
- **Default Steps**: 30 NFEs (Neural Function Evaluations)
- **Full quality** undistilled model
- Superior detail and aesthetic quality compared to Turbo
- Excellent for final production renders

### 2. Classifier-Free Guidance (CFG)
- **Guidance Scale**: 4.0 (default)
- **Guidance Max Phases**: 1
- Traditional CFG for strong prompt adherence
- Adjustable guidance strength for quality/creativity balance

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/z_image_handler.py` (Lines 9-12, 166-169)

```python
z_image_base = base_model_type == "z_image_base"
guidance_max_phases = 1 if z_image_base else 0

ui_defaults.update({
    "guidance_scale": 4,
    "num_inference_steps": 30,
    "flow_shift": 6.0,
})
```

### 3. Flow Shift
- **Flow Shift**: 6.0
- **Enabled**: Yes (Base model only)
- Controls the flow matching schedule
- Optimizes quality across different resolutions

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/z_image_handler.py` (Line 56)

```python
extra_model_def["flow_shift"] = z_image_base
```

### 4. Rich Aesthetics and Diversity
Per the model description:
- **Wide range of artistic styles**
- **Effective negative prompting**
- **High diversity** across:
  - Identities
  - Poses
  - Compositions
  - Layouts

### 5. Strong Controllability
- Excellent prompt adherence
- Responsive to detailed prompts
- Effective negative prompt support
- Suitable for fine-tuning

### 6. LoRA Support
- **LoRA Directory**: `lora_root/z_image/`
- **CLI Argument**: `--lora-dir-z-image`
- Full LoRA support for customization and fine-tuning
- Ideal base for training custom LoRAs

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/z_image_handler.py` (Lines 83-95)

## Default Settings

### Generation Parameters
```json
{
  "resolution": "1024x1024",
  "batch_size": 1,
  "num_inference_steps": 30
}
```

**Code Reference**: `/opt/wan2gp/Wan2GP/defaults/z_image_base.json`

### Advanced Settings
- **Guidance Scale**: 4.0
- **Flow Shift**: 6.0
- **Guidance Max Phases**: 1
- **VAE Scale Factor**: 16 (8x8 downsampling)
- **NAG Support**: No (CFG used instead)

### Attention Backend Constraint
For PyTorch versions < 89:
- **Forced Backend**: SDPA (Scaled Dot-Product Attention)
- **Reason**: Compatibility with older PyTorch versions

**Code Reference**: `/opt/wan2gp/Wan2GP/defaults/z_image_base.json` (Lines 9-11)

```json
"attention": {
    "<89": "sdpa"
}
```

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
- 2048x2048 (high quality)

### Flow Shift and Resolution
The flow shift parameter automatically adjusts based on image sequence length:

```python
image_seq_len = (height // 16) * (width // 16)
mu = calculate_shift(image_seq_len, 
                    base_seq_len=256,
                    max_seq_len=4096, 
                    base_shift=0.5,
                    max_shift=1.15)
```

Then adjusted by flow_shift parameter (6.0):
```python
timesteps = scheduler.set_timesteps(
    num_inference_steps, 
    device=device,
    shift=flow_shift  # 6.0
)
```

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/pipeline_z_image.py` (Lines 78-86, 615-620)

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

**Effectiveness**: Highly responsive to negative prompts due to CFG support

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/pipeline_z_image.py` (Lines 71-74)

## VAE (Variational Autoencoder)

### Configuration Files
- `ZImageTurbo_VAE_bf16_config.json` (shared with Turbo)
- `ZImageTurbo_VAE_bf16.safetensors` (shared with Turbo)

### VAE Settings
- **Scale Factor**: 8 (base)
- **Effective Scale**: 16 (for height/width constraints)
- **Default Dtype**: float32 (for precision)
- **Slicing**: Enabled for VRAM optimization

## Scheduler

### Type
- **FlowMatchEulerDiscreteScheduler**
- **Config**: `ZImageTurbo_scheduler_config.json`
- **Method**: Flow Matching with Euler discrete stepping

### Scheduler Configuration
```python
scheduler.set_timesteps(
    num_inference_steps=30,
    device=device,
    shift=6.0  # flow_shift parameter
)
```

## Best Use Cases

### Ideal For:
1. **Final Production Renders**
   - Maximum quality output
   - Print-ready images
   - Professional artwork

2. **Creative Generation**
   - Artistic exploration
   - Diverse style generation
   - Complex compositions

3. **Fine-Tuning Base**
   - Training custom models
   - Creating specialized variants
   - LoRA development

4. **Detailed Prompts**
   - Complex scene descriptions
   - Specific artistic requirements
   - Precise control needs

5. **High Diversity Requirements**
   - Character variations
   - Scene diversity
   - Layout exploration

6. **Downstream Development**
   - Model research
   - Architecture experiments
   - Distillation source

### Not Ideal For:
- Real-time applications (use Turbo instead)
- Rapid iteration (use Turbo instead)
- Resource-constrained environments (use Turbo or Nunchaku)
- Visual control needs (use ControlNet variants)

## Differences from Other Z-Image Variants

### vs. Z-Image Turbo
| Feature | Base | Turbo |
|---------|------|-------|
| Steps | 30 | 8 |
| Guidance | 4.0 (CFG) | 0 (NAG) |
| Speed | Slower | Fast |
| Quality | Highest | High |
| Flow Shift | Yes (6.0) | No |
| Diversity | Highest | High |
| Purpose | Quality | Speed |
| Training | Full model | Distilled |

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/z_image_handler.py` (Lines 163-179)

### vs. TwinFlow Turbo
| Feature | Base | TwinFlow |
|---------|------|----------|
| Steps | 30 | 2-4 |
| Quality | Highest | Good |
| Training | Full | Distilled+Finetuned |
| Purpose | Quality | Extreme speed |

### vs. ControlNet Variants
| Feature | Base | ControlNet |
|---------|------|------------|
| Control | Prompt only | Prompt + Visual |
| ControlNet | No | Yes |
| Steps | 30 | 9 |
| Base Model | This | Turbo |

### Model Equivalence
In the handler, `z_image_base` is mapped to `z_image` for compatibility:

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/z_image_handler.py` (Lines 66-68)

```python
models_eqv_map = {
    "z_image_base": "z_image",
}
```

## Advanced Settings and Options

### Pipeline Arguments
```python
pipe(
    prompt: str,
    height: int = 1024,
    width: int = 1024,
    num_inference_steps: int = 30,
    guidance_scale: float = 4.0,
    negative_prompt: str = None,
    num_images_per_prompt: int = 1,
    generator: torch.Generator = None,
    latents: torch.FloatTensor = None,
    max_sequence_length: int = 512,
)
```

### Guidance Scale Tuning
- **Range**: 0.0 - 20.0 (practical: 2.0 - 8.0)
- **Default**: 4.0
- **Lower** (1.0-3.0): More creative, diverse results
- **Default** (4.0): Balanced prompt adherence and quality
- **Higher** (5.0-8.0): Stronger prompt adherence, less diversity
- **Very High** (>8.0): May reduce quality, oversaturated

### Flow Shift Tuning
- **Default**: 6.0
- **Range**: 1.0 - 10.0
- **Purpose**: Adjusts the timestep distribution
- **Lower**: Earlier timesteps emphasized
- **Higher**: Later timesteps emphasized
- Affects quality vs. coherence tradeoff

### CFG Normalization
- **cfg_normalization**: Optional boolean
- **cfg_truncation**: Optional float (default 1.0)
- Advanced CFG control for experimental use

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/pipeline_z_image.py` (Lines 443-445)

### Attention Backends
Configurable through transformer settings:
- **SDPA**: PyTorch Scaled Dot-Product Attention (default for PyTorch <89)
- **flash**: Flash Attention 2
- **_flash_3**: Flash Attention 3

### Quantization Options

#### INT8 Quantization
- **Method**: Quanto BF16→INT8
- **VRAM Savings**: ~50%
- **Quality Impact**: Minimal
- **File**: `ZImageBase_quanto_bf16_int8.safetensors`

#### Text Encoder Quantization
- **Available**: Yes
- **Method**: Quanto BF16→INT8
- **File**: `qwen3_quanto_bf16_int8.safetensors`

## Model Loading Example

```python
from models.z_image.z_image_handler import family_handler

pipe_processor, pipe = family_handler.load_model(
    model_filename="ZImageBase_bf16.safetensors",
    base_model_type="z_image_base",
    quantizeTransformer=False,
    dtype=torch.bfloat16,
    VAE_dtype=torch.float32,
)
```

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/z_image_handler.py` (Lines 114-155)

## Performance Characteristics

### Speed
- **30 steps** at 1024x1024
- Approximately **10-15 seconds** per image on RTX 4090
- Approximately **25-35 seconds** per image on RTX 3090

### VRAM Requirements
- **BF16**: ~13-15 GB at 1024x1024
- **INT8**: ~8-10 GB at 1024x1024
- **Batch Size 1**: Recommended for most GPUs

### Scaling with Resolution
- 1024x1024: Baseline
- 1920x1088: ~2x compute
- 2048x2048: ~4x compute
- Higher resolutions benefit from flow_shift adjustment

## Quality Characteristics

### Strengths
1. **Maximum Detail**: Full 30-step refinement
2. **Aesthetic Quality**: Superior color, composition, lighting
3. **Diversity**: Wide variation in output
4. **Prompt Adherence**: Strong CFG control
5. **Negative Prompts**: Highly effective
6. **Artistic Styles**: Broad style support

### Optimal Settings for Quality
```python
pipe(
    prompt=detailed_prompt,
    negative_prompt=detailed_negative,
    num_inference_steps=30,
    guidance_scale=4.0,  # Adjust 3.0-6.0 based on needs
    height=1024,
    width=1024,
)
```

## Fine-Tuning and Customization

### LoRA Training
- **Recommended**: Yes, this is the ideal base
- **Rank**: 8-64 (depending on complexity)
- **Alpha**: Equal to rank for balanced impact
- **Training Steps**: 500-5000 (dataset dependent)

### Distillation
- Source for creating faster variants
- Turbo was distilled from this base
- Can create custom distilled models

### Transfer Learning
- Strong foundation for specialized domains
- Maintains quality while adapting to new styles
- Effective for domain-specific fine-tuning

## Compatibility Notes

### Supported Model Types
From handler: `["z_image", "z_image_base", "z_image_control", "z_image_control2", "z_image_control2_1"]`

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/z_image_handler.py` (Line 61)

### Model Equivalence Map
```python
models_eqv_map = {
    "z_image_base": "z_image",  # Base shares architecture with turbo
    "z_image_control2_1": "z_image_control2",
}
```

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/z_image_handler.py` (Lines 65-72)

## Additional Notes

### Text Encoder Caching
- **Enabled**: Yes
- **Purpose**: Speeds up repeated generations with same prompts
- **Implementation**: TextEncoderCache class

### VAE Slicing
- **Enabled**: Always
- **Purpose**: Reduces VRAM usage during decode
- **Method**: Process VAE in tiles

### Offloading Support
- **MMGP Offload**: Supported
- **Sequential offload**: text_encoder→transformer→vae
- **Purpose**: Enable on smaller GPUs (required for 8GB cards)

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/pipeline_z_image.py` (Line 210)

### Profiles Directory
- **Enabled**: Yes (empty by default)
- **Purpose**: Store custom generation profiles
- **Location**: User-configurable

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/z_image_handler.py` (Line 15)

## Research and Development

### Use in Research
- Foundation for studying image generation
- Flow matching research
- Distillation experiments
- Architecture analysis

### Downstream Development
- Custom model development
- Specialized variants
- Domain adaptation
- Style transfer research

---

**Last Updated**: 2/8/2026
**Model Version**: Z-Image Base 6B
**HuggingFace**: DeepBeepMeep/Z-Image
**Model Description Source**: `/opt/wan2gp/Wan2GP/defaults/z_image_base.json`
