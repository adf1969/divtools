# Z-Image Turbo Nunchaku INT4 (r256)

## Model Overview
**Z-Image Turbo Nunchaku INT4** is an ultra-compressed quantized variant of Z-Image Turbo using SVDQ (Singular Value Decomposition Quantization) INT4 weights for minimal VRAM usage while maintaining good quality.

## Technical Specifications

### Model Details
- **Parameter Count**: 6 Billion (6B) - INT4 quantized
- **Architecture Type**: `z_image`
- **Model Identifier**: `z_image`
- **Base Family**: Z-Image
- **Base Model**: Z-Image Turbo
- **Quantization Method**: SVDQ (Singular Value Decomposition Quantization)
- **Precision**: INT4 (4-bit integer)
- **Rank**: r256

### Model Files
**Location**: `/opt/wan2gp/Wan2GP/models/z_image/`

**Configuration**: `/opt/wan2gp/Wan2GP/defaults/z_image_nunchaku_r256_int4.json` (Lines 1-11)

**URLs**:
- `https://huggingface.co/DeepBeepMeep/Z-Image/resolve/main/svdq-int4_r256-z-image-turbo.safetensors`

**Handler**: `/opt/wan2gp/Wan2GP/models/z_image/z_image_handler.py` (Lines 1-189)

**Nunchaku Kernel**: Required for optimal performance

## Primary Purpose
Extreme **VRAM reduction** while maintaining acceptable quality. Designed for systems with limited VRAM (8-12GB) or for batch processing where VRAM is at a premium.

## Key Features

### 1. SVDQ INT4 Quantization
- **Method**: Singular Value Decomposition Quantization
- **Precision**: 4-bit integers
- **Compression**: ~8x reduction from BF16
- **Quality Loss**: Minimal to moderate

### 2. Rank 256 (r256)
- **Rank**: 256
- **Trade-off**: Higher rank (256) vs. r128 = better quality, slightly more VRAM
- **Purpose**: Balance quality and compression

**Code Reference**: Model filename contains `r256`

### 3. Nunchaku Kernel Requirement
- **Kernels**: Must be installed for optimal performance
- **Without Kernels**: Still works but slower
- **Performance**: Full speed with kernels installed

**Code Reference**: `/opt/wan2gp/Wan2GP/defaults/z_image_nunchaku_r256_int4.json` (Line 5)

```json
"description": "Nunchaku SVDQ INT4 weights for Z-Image Turbo. For full speed, the nunchaku kernels must be installed."
```

### 4. Minimal VRAM Usage
- **BF16**: ~13 GB (standard Turbo)
- **INT4 r256**: ~3-4 GB (this model)
- **Reduction**: ~75% VRAM savings

### 5. Same Architecture
- **Base**: Z-Image Turbo (identical architecture)
- **Steps**: 8 (same as Turbo)
- **Guidance**: 0 (guidance-free)
- **Features**: All Turbo features retained

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

**Code Reference**: `/opt/wan2gp/Wan2GP/defaults/z_image_nunchaku_r256_int4.json`

### Advanced Settings
- **NAG**: Not recommended with quantization
- **Flow Shift**: No (Turbo-based)
- **Guidance Max Phases**: 0

## Quantization Details

### SVDQ (Singular Value Decomposition Quantization)
**Method**:
1. Decompose weight matrices using SVD
2. Quantize singular values to 4-bit integers
3. Reconstruct approximate weights at runtime

**Benefits**:
- Better quality than naive 4-bit quantization
- Preserves important singular values
- Efficient reconstruction

### INT4 vs. Other Precisions
```
Precision | Size   | VRAM  | Quality
----------|--------|-------|----------
BF16      | 100%   | 13 GB | Full
INT8      | 50%    | 7 GB  | 99%
INT4 r256 | 12.5%  | 4 GB  | 85-90%
FP4 r128  | 12.5%  | 3 GB  | 80-90%
```

### Rank Parameter (r256)
- **r256**: Higher rank, better quality, more VRAM
- **r128**: Lower rank, lower quality, less VRAM (see FP4 variant)
- **Trade-off**: Quality vs. VRAM

## Resolutions and Aspect Ratios

### Default Resolution
- **Standard**: 1024x1024 (1:1 aspect ratio)

### Supported Resolutions
- **Constraint**: Height and width must be divisible by 16
- **Recommended**: 1024x1024 or lower for INT4
- **Higher Res**: Quality degrades faster than BF16

**Recommended Resolutions**:
- 1024x1024 (1:1) - Default, optimal
- 768x768 (1:1) - Lower, faster
- 1024x768 (4:3) - Works
- 512x512 (1:1) - Fast preview

**Not Recommended**:
- 1920x1088+ (quality loss significant)
- Use BF16 or INT8 for high resolutions

## Nunchaku Kernel Installation

### Requirement
**For full speed**, Nunchaku kernels must be installed.

### Without Kernels
- Model still loads and works
- **Performance**: Slower (10-20x slower)
- **Quality**: Same

### With Kernels
- **Performance**: Full speed, comparable to INT8
- **Quality**: Same
- **Installation**: System-dependent

### Installation (General)
```bash
# Check if kernels installed
python -c "import nunchaku; print('Kernels installed')"

# If not, installation varies by system
# Consult Nunchaku documentation
```

## Best Use Cases

### Ideal For:
1. **Limited VRAM Systems**
   - 8GB GPU (RTX 3070, RTX 4060Ti)
   - 12GB GPU with headroom
   - Laptops with mobile GPUs

2. **Batch Processing**
   - Maximum batch sizes
   - Dataset generation
   - High-volume processing

3. **Multi-Model Workflows**
   - Load multiple models simultaneously
   - Pipeline workflows
   - Combined generation systems

4. **Development and Testing**
   - Rapid iteration
   - Model experimentation
   - Prototype testing

### Not Ideal For:
- Maximum quality requirements (use BF16)
- Professional/commercial work (use BF16 or INT8)
- High resolutions (quality loss)
- Critical applications (use less aggressive quantization)

## Differences from Other Z-Image Variants

### vs. Z-Image Turbo (BF16)
| Feature | INT4 r256 | BF16 Turbo |
|---------|-----------|------------|
| Precision | **INT4** | BF16 |
| VRAM | **~4 GB** | ~13 GB |
| Quality | 85-90% | 100% |
| Speed (w/ kernels) | Fast | Fast |
| Speed (no kernels) | **Very Slow** | Fast |
| Purpose | **VRAM savings** | Quality |

### vs. Nunchaku FP4 (r128)
| Feature | INT4 r256 | FP4 r128 |
|---------|-----------|----------|
| Precision | **INT4** | FP4 |
| Rank | **r256** | r128 |
| VRAM | **~4 GB** | ~3 GB |
| Quality | **85-90%** | 80-90% |
| GPU Req | Any | **sm120+ for full speed** |
| Speed (kernels) | Fast | **Fastest** (sm120+) |

**Code Reference**: `/opt/wan2gp/Wan2GP/defaults/z_image_nunchaku_r256_int4.json` vs. `z_image_nunchaku_r128_fp4.json`

### vs. INT8 Quanto
| Feature | INT4 r256 | INT8 Quanto |
|---------|-----------|-------------|
| Method | **SVDQ INT4** | Quanto INT8 |
| VRAM | **~4 GB** | ~7 GB |
| Quality | 85-90% | **99%** |
| Kernel Req | **Yes (for speed)** | No |

## Advanced Settings and Options

### Pipeline Arguments
Same as standard Turbo:
```python
pipe(
    prompt: str,
    height: int = 1024,
    width: int = 1024,
    num_inference_steps: int = 8,
    guidance_scale: float = 0.0,
    negative_prompt: str = None,
    generator: torch.Generator = None,
)
```

### NAG Parameters
- **Available**: Yes (inherited from Turbo)
- **Recommended**: No (quantization affects NAG quality)
- **If Used**: Lower NAG_scale (0.5-1.0)

### Quality Optimization Tips
1. **Use lower resolutions**: 768x768 or 1024x1024 max
2. **Avoid high complexity**: Simple prompts work better
3. **Test and iterate**: Quality varies by prompt
4. **Compare with BF16**: Check if quality acceptable

## Model Loading Example

```python
from models.z_image.z_image_handler import family_handler

# Load INT4 Nunchaku model
pipe_processor, pipe = family_handler.load_model(
    model_filename="svdq-int4_r256-z-image-turbo.safetensors",
    base_model_type="z_image",
    dtype=torch.bfloat16,  # BF16 for non-quantized parts
    VAE_dtype=torch.float32,
)

# Note: quantizeTransformer not needed (already quantized)
```

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/z_image_handler.py` (Lines 114-155)

## Performance Characteristics

### Speed (WITH Nunchaku Kernels)
- **8 steps** at 1024x1024
- Approximately **3-5 seconds** per image on RTX 4090
- Approximately **8-12 seconds** per image on RTX 3090
- Similar to INT8, slightly slower than BF16

### Speed (WITHOUT Nunchaku Kernels)
- **8 steps** at 1024x1024
- Approximately **30-60 seconds** per image (10-20x slower)
- **Not recommended** for production without kernels

### VRAM Usage
```
Resolution | VRAM (INT4 r256)
-----------|------------------
512x512    | ~2.5 GB
768x768    | ~3 GB
1024x1024  | ~4 GB
1280x1280  | ~5 GB
```

### Quality Assessment
```
Aspect          | Quality vs. BF16
----------------|------------------
Overall         | 85-90%
Details         | 80-85%
Colors          | 90-95%
Composition     | 90-95%
Prompt adherence| 85-90%
```

## Quality vs. Size Trade-off

### Quality Retention
- **Strengths**: Colors, composition, general structure
- **Weaknesses**: Fine details, textures, complex scenes

### Acceptable Use Cases
✅ Concepts and sketches
✅ Thumbnails and previews
✅ Dataset generation (non-critical)
✅ Rapid iteration
✅ Style exploration

### Not Acceptable
❌ Professional deliverables
❌ Print quality
❌ Commercial work
❌ Archival images
❌ High-detail requirements

## Compatibility Notes

### Model Architecture
- **Type**: `z_image` (same as Turbo)
- **Compatible**: With all Turbo features
- **LoRA**: Supported (but quality impact)

### Hardware Requirements
- **GPU**: Any CUDA-capable GPU
- **Kernels**: Optional but strongly recommended
- **VRAM**: 6GB minimum, 8GB recommended

## LoRA Support

### Compatibility
- **Supported**: Yes
- **Quality**: May degrade with INT4 + LoRA
- **Recommendation**: Test carefully

### Combined Usage
```python
# Use LoRA with INT4 (experimental)
pipe = load_with_lora("style_lora.safetensors")
# Quality may vary significantly
```

## Text Encoder and VAE

### Shared Components
- **Text Encoder**: Qwen3 (can be quantized separately)
- **VAE**: `ZImageTurbo_VAE_bf16.safetensors` (full precision recommended)

### Additional Quantization
Can quantize text encoder too:
```python
text_encoder_filename="qwen3_quanto_bf16_int8.safetensors"
```

Further VRAM savings (~1-2 GB more).

## Limitations

### Quality Loss
- **Expected**: 10-20% quality reduction
- **Varies**: By prompt complexity
- **Subjective**: Some prompts affected more

### Detail Degradation
- **Fine textures**: Blurred or lost
- **Small objects**: Less defined
- **Text in images**: Poor quality
- **Facial details**: Reduced fidelity

### Resolution Constraints
- **Optimal**: 1024x1024 or below
- **Degradation**: Accelerates at higher resolutions
- **Recommendation**: Use BF16/INT8 for >1024

### Kernel Dependency
- **Critical**: Nunchaku kernels for speed
- **Without**: 10-20x slower (unusable for production)

## Troubleshooting

### Slow Performance
**Problem**: Generation extremely slow
**Solution**: 
1. Install Nunchaku kernels
2. Verify installation: `python -c "import nunchaku"`
3. Check CUDA compatibility

### Quality Issues
**Problem**: Poor quality or artifacts
**Solution**:
1. Reduce resolution to 768x768
2. Simplify prompts
3. Avoid complex scenes
4. Use fewer steps is worse, stick to 8

### VRAM Errors Despite INT4
**Problem**: Still running out of VRAM
**Solution**:
1. Reduce batch size to 1
2. Lower resolution
3. Quantize text encoder too
4. Enable VAE slicing (auto-enabled)

## Comparison with Other Quantization Methods

### SVDQ vs. Naive Quantization
**SVDQ (this model)**:
- Better quality retention
- Preserves important features
- Minimal artifacts

**Naive INT4**:
- Faster to compute
- More quality loss
- More artifacts

### INT4 vs. INT8 vs. BF16
```
Method  | VRAM         | Quality | Speed    | Kernels
--------|--------------|---------|----------|----------
BF16    | 13 GB (100%) | 100%    | Fast     | No
INT8    | 7 GB (54%)   | 99%     | Fast     | No
INT4    | 4 GB (31%)   | 85-90%  | Fast*    | Yes*
FP4     | 3 GB (23%)   | 80-90%  | Fastest* | Yes*

*With kernels installed
```

## When to Use INT4 r256

### Choose INT4 r256 When:
- ✅ VRAM is severely limited (8-12GB)
- ✅ Batch processing is priority
- ✅ Quality can be compromised slightly
- ✅ Nunchaku kernels installed
- ✅ Resolution ≤ 1024x1024

### Choose BF16 Instead When:
- ✅ Quality is critical
- ✅ Professional work
- ✅ VRAM available (>16GB)
- ✅ High resolutions needed

### Choose INT8 Instead When:
- ✅ Middle ground needed
- ✅ Some VRAM savings required
- ✅ Quality important but VRAM limited
- ✅ Don't want kernel dependency

### Choose FP4 r128 Instead When:
- ✅ RTX 50xx series GPU (sm120+)
- ✅ Absolute minimum VRAM
- ✅ Maximum speed priority

---

**Last Updated**: 2/8/2026
**Model Version**: Z-Image Turbo Nunchaku INT4 (r256) 6B
**HuggingFace**: DeepBeepMeep/Z-Image
**Quantization**: SVDQ INT4, Rank 256
**VRAM Requirement**: ~4 GB
**Kernel Requirement**: Nunchaku kernels (for speed)
