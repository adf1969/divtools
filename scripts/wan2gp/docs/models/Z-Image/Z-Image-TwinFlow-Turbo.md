# TwinFlow Z-Image Turbo

## Model Overview
**TwinFlow Z-Image Turbo** is an ultra-fast distilled and fine-tuned variant of Z-Image Turbo optimized for 1 to 4 step image generation using a specialized unified sampler.

## Technical Specifications

### Model Details
- **Parameter Count**: 6 Billion (6B)
- **Architecture Type**: `z_image`
- **Model Identifier**: `z_image` (with unified_solver flag)
- **Base Family**: Z-Image
- **Training Method**: Distilled + Fine-tuned
- **Optimization**: 1-4 step specialized

### Model Files
**Location**: `/opt/wan2gp/Wan2GP/models/z_image/`

**Configuration**: `/opt/wan2gp/Wan2GP/defaults/z_image_twinflow_turbo.json` (Lines 1-11)

**URLs**:
- `https://huggingface.co/DeepBeepMeep/Z-Image/resolve/main/TwinFlow-Z-Image-Turbo_bf16.safetensors`
- `https://huggingface.co/DeepBeepMeep/Z-Image/resolve/main/TwinFlow-Z-Image-Turbo_quanto_bf16_int8.safetensors` (INT8 quantized)

**Handler**: `/opt/wan2gp/Wan2GP/models/z_image/z_image_handler.py` (Lines 1-189)

**Pipeline**: `/opt/wan2gp/Wan2GP/models/z_image/pipeline_z_image.py` (Lines 1-991)

**Unified Sampler**: `/opt/wan2gp/Wan2GP/models/z_image/unified_sampler.py`

## Primary Purpose
TwinFlow is designed for **extreme speed** with minimal quality loss. It's optimized specifically for 1-4 step generation, making it the fastest Z-Image variant available.

## Key Features

### 1. Unified Sampler
- **Sampler Type**: UnifiedSampler (proprietary)
- **Optimization**: 1-4 step specialized
- **Default Steps**: 2
- **Method**: Advanced prediction and extrapolation

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/pipeline_z_image.py` (Lines 148-200)

```python
_UNIFIED_SOLVERS = {"unified", "unified_2s", "unified_4s", "twinflow"}
```

### 2. Extreme Speed
- **2-Step Generation**: Primary use case
- **1-Step Capable**: Experimental, lowest quality
- **4-Step Maximum**: Highest quality for TwinFlow
- Significantly faster than standard Turbo

### 3. Unified Solver Flag
- **unified_solver**: true (in config)
- Enables special unified sampler code path
- Bypasses standard scheduler when active

**Code Reference**: `/opt/wan2gp/Wan2GP/defaults/z_image_twinflow_turbo.json` (Line 5)

```json
"unified_solver": true
```

### 4. No Guidance
- **Guidance Scale**: 0
- Pre-optimized for guidance-free operation
- CFG overhead eliminated

### 5. Automatic Preset Selection
Based on `num_inference_steps`:
- **≤2 steps**: "unified_2s" preset (few-step style)
- **3-4 steps**: "unified_4s" preset (any-step style)
- **>4 steps**: "unified_mul" preset (multi-step style)

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/pipeline_z_image.py` (Lines 168-200)

```python
def _resolve_unified_sampler_config(sample_solver, num_inference_steps, unified_sampler_config):
    sampling_steps = max(int(num_inference_steps), 1)
    if solver == "unified_2s":
        sampling_steps = 2
    elif solver == "unified_4s":
        sampling_steps = 4
        
    if sampling_steps <= 2:
        preset_key = "unified_2s"
        sampling_style = "few"
    elif sampling_steps <= 4:
        preset_key = "unified_4s"
        sampling_style = "any"
    else:
        preset_key = "unified_mul"
        sampling_style = "mul"
```

## Default Settings

### Generation Parameters
```json
{
  "resolution": "1024x1024",
  "batch_size": 1,
  "num_inference_steps": 2,
  "guidance_scale": 0
}
```

**Code Reference**: `/opt/wan2gp/Wan2GP/defaults/z_image_twinflow_turbo.json`

### Unified Sampler Presets

#### unified_2s (2-Step) - Default
```python
{
    "sampling_steps": 2,
    "stochast_ratio": 1.0,
    "extrapol_ratio": 0.0,
    "sampling_order": 1,
    "sampling_style": "few",
    "time_dist_ctrl": [1.0, 1.0, 1.0],
    "rfba_gap_steps": [0.001, 0.6],
}
```

#### unified_4s (4-Step)
```python
{
    "sampling_steps": 4,
    "sampling_style": "any",
    "rfba_gap_steps": [0.001, 0.5],
}
```

#### unified_mul (Multi-Step)
```python
{
    "sampling_style": "mul",
    "rfba_gap_steps": [0.001, 0.0],
}
```

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/pipeline_z_image.py` (Lines 148-155)

```python
_UNIFIED_PRESET_GAP = {
    "unified_2s": [0.001, 0.6],
    "unified_4s": [0.001, 0.5],
    "unified_mul": [0.001, 0.0],
}
```

## Unified Sampler Parameters

### sampling_steps
- **Default**: Auto-detected from num_inference_steps
- **Range**: 1-4 (optimized), 5+ (fallback)
- Number of denoising steps to perform

### stochast_ratio
- **Default**: 1.0
- **Range**: 0.0 - 2.0
- Controls stochasticity in sampling
- Higher = more randomness

### extrapol_ratio
- **Default**: 0.0
- **Range**: 0.0 - 1.0
- Extrapolation strength for prediction
- Used in multi-step mode

### sampling_order
- **Default**: 1
- **Options**: 1, 2, 3
- Order of the sampling polynomial

### sampling_style
- **few**: Optimized for ≤2 steps
- **any**: Optimized for 3-4 steps
- **mul**: Generic multi-step

### time_dist_ctrl
- **Default**: [1.0, 1.0, 1.0]
- Time distribution control parameters
- Advanced timestep scheduling

### rfba_gap_steps
- **Purpose**: RFBA (Recursive Feedback Accumulation) gap control
- **Preset-dependent**: Different per preset
- Controls prediction buffer intervals

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/pipeline_z_image.py` (Lines 183-198)

## Resolutions and Aspect Ratios

### Default Resolution
- **Standard**: 1024x1024 (1:1 aspect ratio)

### Supported Resolutions
- **Constraint**: Height and width must be divisible by 16
- **Minimum**: 512x512
- **Optimized**: 1024x1024 (trained for this)

**Common Resolutions**:
- 1024x1024 (1:1) - Default, optimized
- 1024x768 (4:3)
- 768x1024 (3:4)
- 1280x768 (16:9 approx)

**Note**: Higher resolutions may reduce quality due to 1-4 step limitation

## Text Encoder

### Architecture
- **Model**: Qwen3 (Causal Language Model)
- **Max Sequence Length**: 512 tokens
- **Tokenizer**: AutoTokenizer (Qwen3)
- **Shared**: Same as other Z-Image variants

### Text Encoder Files
**Folder**: `Qwen3/`

**URLs**:
- `qwen3_bf16.safetensors`
- `qwen3_quanto_bf16_int8.safetensors`

### Negative Prompting
**Default Negative Prompt**:
```
"low quality, worst quality, blurry, pixelated, noisy, artifacts, watermark, text, logo, bad anatomy, bad hands, extra limbs"
```

**Effectiveness**: Limited at 1-2 steps, better at 4 steps

## VAE (Variational Autoencoder)

### Configuration
- **Shared**: Same VAE as other Z-Image variants
- **Files**: `ZImageTurbo_VAE_bf16.safetensors`
- **Scale Factor**: 16
- **Dtype**: float32
- **Slicing**: Enabled

## Best Use Cases

### Ideal For:
1. **Real-Time Applications**
   - Live preview systems
   - Interactive tools
   - Instant feedback workflows
   - Streaming generation

2. **Extreme Batch Processing**
   - Massive dataset generation
   - Automated content creation
   - Thumbnail generation
   - Concept exploration at scale

3. **Resource-Constrained Scenarios**
   - Minimal compute budget
   - Time-critical deployments
   - Edge devices (with quantization)
   - Mobile applications

4. **Rapid Prototyping**
   - Quick concept validation
   - Fast iteration cycles
   - Exploratory generation

### Not Ideal For:
- High-quality final renders (use Base or standard Turbo)
- Detailed compositions (insufficient steps)
- Complex prompts (limited refinement)
- Print or professional use (quality limitations)

## Differences from Other Z-Image Variants

### vs. Z-Image Turbo
| Feature | TwinFlow | Turbo |
|---------|----------|-------|
| Steps | 2 | 8 |
| Speed | Fastest | Fast |
| Quality | Good | High |
| Sampler | Unified | Standard |
| Training | Distilled+Finetuned | Distilled |
| Purpose | Extreme speed | Speed+Quality |

### vs. Z-Image Base
| Feature | TwinFlow | Base |
|---------|----------|------|
| Steps | 2 | 30 |
| Speed | Fastest | Slowest |
| Quality | Good | Highest |
| Purpose | Speed | Quality |

### vs. Nunchaku Variants
| Feature | TwinFlow | Nunchaku |
|---------|----------|----------|
| Precision | BF16/INT8 | FP4/INT4 |
| Steps | 2 | 8 |
| Optimization | Step count | Quantization |
| Quality | Good | High (with quality-speed tradeoff) |

## Advanced Settings and Options

### Pipeline Arguments
```python
pipe(
    prompt: str,
    height: int = 1024,
    width: int = 1024,
    num_inference_steps: int = 2,
    sample_solver: str = "unified",  # or "unified_2s", "unified_4s"
    unified_sampler_config: dict = None,  # Optional overrides
    guidance_scale: float = 0.0,
    negative_prompt: str = None,
    generator: torch.Generator = None,
)
```

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/pipeline_z_image.py` (Lines 384-412)

### Sample Solver Selection

#### Automatic (Recommended)
```python
sample_solver="unified"  # Auto-selects preset based on steps
```

#### Explicit Presets
```python
sample_solver="unified_2s"  # Force 2-step preset
sample_solver="unified_4s"  # Force 4-step preset
sample_solver="twinflow"    # Alias for unified
```

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/pipeline_z_image.py` (Line 148)

### Custom Unified Sampler Config

Override specific parameters:
```python
unified_sampler_config = {
    "stochast_ratio": 0.8,  # Reduce randomness
    "extrapol_ratio": 0.1,  # Add extrapolation
    "sampling_order": 2,    # Higher order polynomial
}

pipe(
    prompt=prompt,
    num_inference_steps=2,
    sample_solver="unified",
    unified_sampler_config=unified_sampler_config,
)
```

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/pipeline_z_image.py` (Lines 195-198)

### Step Count Recommendations

#### 1 Step (Experimental)
- **Quality**: Lowest
- **Speed**: Absolute fastest
- **Use**: Extreme edge cases only

#### 2 Steps (Default)
- **Quality**: Good
- **Speed**: Fastest practical
- **Use**: General TwinFlow use
- **Preset**: unified_2s

#### 3-4 Steps
- **Quality**: Better
- **Speed**: Very fast
- **Use**: Quality-sensitive fast generation
- **Preset**: unified_4s

## Model Loading Example

```python
from models.z_image.z_image_handler import family_handler

pipe_processor, pipe = family_handler.load_model(
    model_filename="TwinFlow-Z-Image-Turbo_bf16.safetensors",
    base_model_type="z_image",  # Uses same type as Turbo
    quantizeTransformer=False,
    dtype=torch.bfloat16,
    VAE_dtype=torch.float32,
)

# Generation with unified sampler
image = pipe(
    prompt="Your prompt here",
    num_inference_steps=2,
    sample_solver="unified",
    height=1024,
    width=1024,
).images[0]
```

## Performance Characteristics

### Speed
- **2 steps** at 1024x1024
- Approximately **1-2 seconds** per image on RTX 4090
- Approximately **3-5 seconds** per image on RTX 3090
- **2-4x faster** than standard Turbo

### VRAM Requirements
- **BF16**: ~12-14 GB at 1024x1024 (same as Turbo)
- **INT8**: ~7-9 GB at 1024x1024
- **Batch Size 1**: Recommended

### Quality vs. Speed Tradeoff
```
Steps | Quality | Speed    | Use Case
------|---------|----------|------------------
1     | Low     | Fastest  | Extreme edge cases
2     | Good    | Very     | Default TwinFlow
      |         | Fast     |
3-4   | Better  | Fast     | Quality-sensitive
8     | High    | Normal   | Use standard Turbo instead
```

## Unified Sampler Technical Details

### Unified Sampler Detection
```python
def _is_unified_solver(sample_solver: Optional[str]) -> bool:
    solver = (sample_solver or "").strip().lower()
    return solver in _UNIFIED_SOLVERS or solver.startswith("unified_")
```

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/pipeline_z_image.py` (Lines 162-165)

### Pipeline Integration
When unified solver is detected:
1. Skip standard scheduler setup
2. Initialize UnifiedSampler
3. Use custom timestep generation
4. Apply RFBA (Recursive Feedback Accumulation)
5. Perform extrapolation (if configured)

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/pipeline_z_image.py` (Lines 629-850)

### RFBA (Recursive Feedback Accumulation)
Advanced prediction technique:
```python
if buffer_freq > 0 and extrapol_ratio > 0:
    # Extrapolate from previous predictions
    z_hat = z_hat + extrapol_ratio * (z_hat - z_hats[-buffer_freq - 1])
```

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/pipeline_z_image.py` (Lines 823-827)

## Compatibility Notes

### Model Type
- **Architecture**: `z_image` (same as standard Turbo)
- **Distinction**: `unified_solver: true` flag in config
- **Handler**: Shares all handler code with Turbo

### Supported Features
- ✅ LoRA support
- ✅ INT8 quantization
- ✅ VAE slicing
- ✅ MMGP offloading
- ✅ Text encoder caching
- ❌ NAG (not beneficial at <4 steps)
- ❌ CFG (pre-optimized without)

## Quality Optimization Tips

### For Best Quality (within 1-4 step constraint):
1. **Use 4 steps**: `num_inference_steps=4`
2. **Optimize prompts**: Be concise, avoid complexity
3. **Avoid fine details**: Model has limited refinement capability
4. **Use negative prompts**: More effective at 4 steps
5. **Standard resolutions**: Stick to 1024x1024

### Prompt Engineering for TwinFlow:
```python
# Good: Simple, clear
prompt = "portrait of a woman, professional photo, studio lighting"

# Not ideal: Too complex for 2 steps
prompt = "highly detailed portrait of a woman with intricate jewelry, ornate background with baroque details, dramatic chiaroscuro lighting, renaissance style, 8k uhd"
```

## Limitations

### Step Count Constraint
- **Optimized**: 1-4 steps only
- **Beyond 4 steps**: Use standard Turbo instead
- **Quality ceiling**: Cannot match 8+ step models

### Complexity Handling
- **Simple prompts**: Excellent
- **Complex scenes**: Limited by step count
- **Fine details**: May be lost or approximated

### Resolution Scaling
- **1024x1024**: Optimal
- **Higher resolutions**: Quality degrades faster than other variants

## Research and Development

### Training Methodology
1. **Base Training**: Z-Image Base (30 steps)
2. **Distillation**: Z-Image Turbo (8 steps)
3. **Fine-tuning**: TwinFlow specialization (1-4 steps)

### Unified Sampler Research
- Proprietary sampling method
- Combines prediction and extrapolation
- Adaptive timestep distribution
- RFBA (Recursive Feedback Accumulation) technique

---

**Last Updated**: 2/8/2026
**Model Version**: TwinFlow Z-Image Turbo 6B
**HuggingFace**: DeepBeepMeep/Z-Image
**Unified Solver**: Enabled
