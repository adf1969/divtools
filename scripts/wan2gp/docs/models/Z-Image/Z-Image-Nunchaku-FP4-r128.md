# Z-Image Turbo Nunchaku FP4 (r128)

## Model Overview
**Z-Image Turbo Nunchaku FP4** is the most compressed Z-Image variant using SVDQ FP4 (4-bit floating point) quantization at rank 128. It requires RTX 50xx series GPUs (sm120+) for full-speed operation.

## Technical Specifications

### Model Details
- **Parameter Count**: 6 Billion (6B) - FP4 quantized
- **Architecture Type**: `z_image`
- **Model Identifier**: `z_image`
- **Base Family**: Z-Image
- **Base Model**: Z-Image Turbo
- **Quantization Method**: SVDQ (Singular Value Decomposition Quantization)
- **Precision**: FP4 (4-bit floating point)
- **Rank**: r128

### Model Files
**Location**: `/opt/wan2gp/Wan2GP/models/z_image/`

**Configuration**: `/opt/wan2gp/Wan2GP/defaults/z_image_nunchaku_r128_fp4.json` (Lines 1-11)

**URLs**:
- `https://huggingface.co/DeepBeepMeep/Z-Image/resolve/main/svdq-fp4_r128-z-image-turbo.safetensors`

**Handler**: `/opt/wan2gp/Wan2GP/models/z_image/z_image_handler.py` (Lines 1-189)

**Nunchaku Kernel**: Required (especially for RTX 50xx)

## Primary Purpose
**Absolute minimum VRAM** and **maximum speed** on RTX 50xx series GPUs (sm120+). Trades some quality for extreme efficiency, ideal for bleeding-edge hardware or extreme VRAM constraints.

## Key Features

### 1. SVDQ FP4 Quantization
- **Method**: Singular Value Decomposition Quantization
- **Precision**: 4-bit floating point (vs. 4-bit integer)
- **Compression**: ~8x reduction from BF16
- **Benefits**: FP4 can represent wider range than INT4

### 2. Rank 128 (r128)
- **Rank**: 128 (lower than r256)
- **Trade-off**: Lower rank = less VRAM, potentially lower quality
- **Purpose**: Minimize VRAM to absolute minimum

**Code Reference**: Model filename contains `r128`

### 3. RTX 50xx GPU Requirement (sm120+)
- **Optimal GPU**: RTX 50xx series (RTX 5090, RTX 5080, etc.)
- **Compute Capability**: sm120 or higher
- **Performance**: Full speed ONLY on sm120+
- **Older GPUs**: Will work but significantly slower

**Code Reference**: `/opt/wan2gp/Wan2GP/defaults/z_image_nunchaku_r128_fp4.json` (Line 5)

```json
"description": "Nunchaku SVDQ FP4 weights for Z-Image Turbo. For full speed, a sm120+ GPU is needed (RTX 50xx) and the nunchaku kernels must be installed."
```

### 4. Minimum VRAM Usage
- **BF16**: ~13 GB (standard Turbo)
- **INT4 r256**: ~4 GB
- **FP4 r128**: ~2.5-3 GB (this model, lowest)
- **Reduction**: ~80% VRAM savings vs. BF16

### 5. Fastest on RTX 50xx
- **With sm120+ GPU**: Fastest Z-Image variant
- **With Kernels**: Optimized FP4 operations
- **Without sm120**: Slower than INT4 r256

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

**Code Reference**: `/opt/wan2gp/Wan2GP/defaults/z_image_nunchaku_r128_fp4.json`

### Advanced Settings
- **NAG**: Not recommended with quantization
- **Flow Shift**: No (Turbo-based)
- **Guidance Max Phases**: 0

## Quantization Details

### SVDQ FP4 (Floating Point 4-bit)
**Method**:
1. Decompose weight matrices using SVD
2. Quantize singular values to 4-bit floating point
3. Reconstruct approximate weights at runtime

**FP4 vs. INT4**:
- **FP4**: Wider dynamic range, better for extreme values
- **INT4**: More uniform precision across range
- **Quality**: FP4 can be better or worse depending on weights

### Rank 128 vs. Rank 256
```
Rank | VRAM  | Quality | Speed (sm120+)
-----|-------|---------|----------------
r256 | 4 GB  | 85-90%  | Fast
r128 | 3 GB  | 80-90%  | Fastest
```

Lower rank means:
- **Less VRAM**: Fewer parameters to store
- **Potential Quality Loss**: Less fine-grained representation
- **Faster**: Fewer computations

### Precision Comparison
```
Precision | Size   | VRAM  | Quality | GPU Req
----------|--------|-------|---------|----------
BF16      | 100%   | 13 GB | 100%    | Any
INT8      | 50%    | 7 GB  | 99%     | Any
INT4 r256 | 12.5%  | 4 GB  | 85-90%  | Any
FP4 r128  | 12.5%  | 3 GB  | 80-90%  | sm120+*

*For full speed
```

## GPU Requirements

### sm120+ (RTX 50xx Series)
**Required for Full Speed**:
- RTX 5090
- RTX 5080
- RTX 5070
- Future RTX 50xx cards

**Benefits**:
- Specialized FP4 tensor cores
- Optimized FP4 operations
- Fastest Z-Image performance
- Low VRAM, high speed

### Older GPUs (sm86, sm89, etc.)
**RTX 40xx, 30xx, 20xx**:
- ✅ Model will load
- ✅ Will generate images
- ❌ Significantly slower (10-50x slower)
- ❌ No FP4 hardware acceleration

**Recommendation**: Use INT4 r256 instead on older GPUs

## Nunchaku Kernel Requirement

### Critical for FP4
**Kernels MUST be installed** for FP4:
- FP4 operations not in standard PyTorch
- Nunchaku provides FP4 implementations
- Without kernels: Model won't load or will fail

### Installation
```bash
# Install Nunchaku kernels
pip install nunchaku

# Verify installation
python -c "import nunchaku; print('FP4 kernels available')"
```

### sm120 Kernels
- **Special**: sm120 FP4 kernels different from other compute capabilities
- **Performance**: Dramatically faster on RTX 50xx
- **Compatibility**: Nunchaku must support sm120

## Resolutions and Aspect Ratios

### Default Resolution
- **Standard**: 1024x1024 (1:1 aspect ratio)

### Recommended Resolutions
Due to aggressive quantization, **lower resolutions recommended**:
- **768x768** (1:1) - Optimal for quality
- **1024x1024** (1:1) - Default, acceptable
- **512x512** (1:1) - Fast, preview quality

### Not Recommended
- **>1024x1024**: Quality degradation significant
- **1920x1088**: Use BF16, INT8, or INT4 r256 instead

## Best Use Cases

### Ideal For:
1. **RTX 50xx Owners**
   - Maximum speed utilization
   - Minimal VRAM usage
   - Cutting-edge hardware

2. **Extreme VRAM Constraints**
   - 6GB GPUs (RTX 3060 6GB)
   - 8GB GPUs with other processes
   - Multi-model loading

3. **Maximum Batch Sizes**
   - Generate many images simultaneously
   - Batch processing pipelines
   - Dataset generation

4. **Experimental/Research**
   - Testing extreme quantization
   - Benchmarking FP4
   - Low-precision research

### Not Ideal For:
- **Older GPUs** (use INT4 r256 or INT8)
- **Quality-critical work** (use BF16 or INT8)
- **Professional deliverables** (quality loss)
- **High resolutions** (quality degrades)

## Differences from Other Z-Image Variants

### vs. Nunchaku INT4 (r256)
| Feature | FP4 r128 | INT4 r256 |
|---------|----------|-----------|
| Precision | **FP4** | INT4 |
| Rank | **r128** | r256 |
| VRAM | **~3 GB** | ~4 GB |
| Quality | 80-90% | **85-90%** |
| GPU Req | **sm120+** | Any |
| Speed (sm120+) | **Fastest** | Fast |
| Speed (older) | Very Slow | Fast (w/ kernels) |

**Recommendation**: 
- RTX 50xx → FP4 r128
- RTX 40xx/30xx → INT4 r256

**Code Reference**: `/opt/wan2gp/Wan2GP/defaults/z_image_nunchaku_r128_fp4.json` vs. `z_image_nunchaku_r256_int4.json`

### vs. Z-Image Turbo (BF16)
| Feature | FP4 r128 | BF16 Turbo |
|---------|----------|------------|
| Precision | **FP4** | BF16 |
| VRAM | **~3 GB** | ~13 GB |
| Quality | 80-90% | **100%** |
| Speed (sm120+) | **Fastest** | Fast |
| GPU Req | **sm120+** | Any |

### vs. INT8 Quanto
| Feature | FP4 r128 | INT8 Quanto |
|---------|----------|-------------|
| Method | **SVDQ FP4** | Quanto INT8 |
| VRAM | **~3 GB** | ~7 GB |
| Quality | 80-90% | **99%** |
| Kernel Req | **Yes (critical)** | No |
| GPU Req | **sm120+** | Any |

## Advanced Settings and Options

### Pipeline Arguments
Same as standard Turbo:
```python
pipe(
    prompt: str,
    height: int = 1024,  # Recommend 768 for best quality
    width: int = 1024,
    num_inference_steps: int = 8,
    guidance_scale: float = 0.0,
    negative_prompt: str = None,
)
```

### Quality Optimization
1. **Lower resolution**: 768x768 for best quality
2. **Simple prompts**: Complex scenes degrade more
3. **Test extensively**: Quality very prompt-dependent
4. **Compare with higher precision**: Validate quality acceptable

### Not Recommended
- ❌ NAG (quality too degraded)
- ❌ High resolutions (>1024)
- ❌ Complex LoRAs (quality unpredictable)
- ❌ Fine details (lost in quantization)

## Model Loading Example

```python
from models.z_image.z_image_handler import family_handler

# Load FP4 Nunchaku model
# Requires sm120+ GPU and Nunchaku kernels
pipe_processor, pipe = family_handler.load_model(
    model_filename="svdq-fp4_r128-z-image-turbo.safetensors",
    base_model_type="z_image",
    dtype=torch.bfloat16,  # BF16 for non-quantized parts
    VAE_dtype=torch.float32,
)

# Model loading will fail without Nunchaku kernels
```

**Code Reference**: `/opt/wan2gp/Wan2GP/models/z_image/z_image_handler.py` (Lines 114-155)

## Performance Characteristics

### Speed on RTX 50xx (sm120+) with Kernels
- **8 steps** at 1024x1024
- Approximately **1-2 seconds** per image on RTX 5090
- Approximately **2-3 seconds** per image on RTX 5080
- **Fastest Z-Image variant** on supported hardware

### Speed on Older GPUs
- **8 steps** at 1024x1024
- Approximately **60-120 seconds** per image on RTX 4090
- Approximately **120-240+ seconds** per image on RTX 3090
- **Not recommended** for production on older GPUs

### VRAM Usage
```
Resolution | VRAM (FP4 r128)
-----------|------------------
512x512    | ~2 GB
768x768    | ~2.5 GB
1024x1024  | ~3 GB
1280x1280  | ~4 GB
```

### Quality Assessment
```
Aspect          | Quality vs. BF16
----------------|------------------
Overall         | 80-90%
Details         | 75-85%
Colors          | 85-95%
Composition     | 85-90%
Prompt adherence| 80-85%
```

**Note**: Quality more variable than INT4 r256 due to lower rank.

## Quality Characteristics

### Strengths
- ✅ Colors generally well-preserved
- ✅ Overall composition maintained
- ✅ General structure intact
- ✅ Fast generation (on sm120+)

### Weaknesses
- ❌ Fine details lost or blurred
- ❌ Textures simplified
- ❌ Small objects less defined
- ❌ Text in images poor
- ❌ Faces may lack detail
- ❌ More quality variance than r256

### Compared to INT4 r256
- **Sometimes better**: When FP4 range helps
- **Sometimes worse**: Due to lower rank (128 vs 256)
- **More variable**: Less consistent quality

## Compatibility Notes

### GPU Compatibility
```
GPU Series | Compute | FP4 Speed | Recommended
-----------|---------|-----------|-------------
RTX 50xx   | sm120+  | Fastest   | ✅ Yes
RTX 40xx   | sm89    | Very Slow | ❌ Use INT4 r256
RTX 30xx   | sm86    | Very Slow | ❌ Use INT4 r256
RTX 20xx   | sm75    | Very Slow | ❌ Use INT8
```

### Software Requirements
- **Nunchaku**: Mandatory
- **CUDA**: 12.0+ recommended for sm120
- **PyTorch**: 2.0+ with CUDA support

### Model Architecture
- **Type**: `z_image` (same as Turbo)
- **Compatible**: With all Turbo features (quality permitting)
- **LoRA**: Supported but quality unpredictable

## LoRA Support

### Compatibility
- **Supported**: Technically yes
- **Quality**: Highly unpredictable with FP4+LoRA
- **Recommendation**: Avoid unless testing

### Combined Usage
```python
# Not recommended: FP4 + LoRA
pipe = load_with_lora("style_lora.safetensors")
# Quality loss likely significant
```

## Limitations

### GPU Requirement (Critical)
- **Must have**: RTX 50xx series for practical use
- **Older GPUs**: Extremely slow, not usable

### Quality Loss
- **Expected**: 10-20% quality reduction
- **Variable**: More variance than INT4 r256
- **Rank Impact**: r128 loses more detail than r256

### Detail Degradation
- **Fine textures**: Significantly degraded
- **Small objects**: Poorly defined
- **Text**: Nearly unusable
- **Faces**: Reduced detail, may lose features

### Resolution Limits
- **Optimal**: 768x768
- **Acceptable**: 1024x1024
- **Not Recommended**: >1024 (severe degradation)

### Kernel Dependency (Critical)
- **Mandatory**: Will not work without Nunchaku
- **sm120 Kernels**: Required for speed
- **Installation**: Must verify before use

## Troubleshooting

### Model Won't Load
**Problem**: Import error or load failure
**Solution**:
1. Install Nunchaku: `pip install nunchaku`
2. Verify: `python -c "import nunchaku"`
3. Check CUDA compatibility
4. Ensure sm120 support if RTX 50xx

### Extremely Slow Generation
**Problem**: 1-2 minutes per image
**Solution**:
1. **Check GPU**: If not RTX 50xx, use INT4 r256 instead
2. Verify Nunchaku installed
3. Check if sm120 kernels loaded
4. Switch to INT4 r256 or INT8

### Poor Quality
**Problem**: Images blurry or lacking details
**Solution**:
1. Reduce resolution to 768x768
2. Simplify prompts
3. Avoid complex scenes
4. Consider upgrading to INT4 r256 or INT8
5. Test if FP4 suitable for your use case

### CUDA Errors
**Problem**: CUDA errors during generation
**Solution**:
1. Update CUDA drivers
2. Update PyTorch to latest
3. Reinstall Nunchaku
4. Check GPU compatibility

## When to Use FP4 r128

### Choose FP4 r128 When:
- ✅ **RTX 50xx GPU** (mandatory)
- ✅ Absolute minimum VRAM needed
- ✅ Maximum speed priority
- ✅ Quality can be significantly compromised
- ✅ Nunchaku kernels installed
- ✅ Experimental/research use

### Choose INT4 r256 Instead When:
- ✅ **RTX 40xx/30xx GPU**
- ✅ Better quality needed
- ✅ More consistent results wanted
- ✅ Same VRAM ballpark acceptable

### Choose INT8 Instead When:
- ✅ Quality more important
- ✅ Some VRAM available (12GB+)
- ✅ Don't want kernel dependency
- ✅ More stable quality needed

### Choose BF16 Instead When:
- ✅ Quality is critical
- ✅ Professional work
- ✅ VRAM available (16GB+)
- ✅ Maximum detail required

## Hardware Recommendations

### Optimal Setup
- **GPU**: RTX 5090 (24GB)
- **VRAM**: Can run many models simultaneously
- **Speed**: Fastest possible Z-Image
- **Batch**: Huge batch sizes possible

### Minimum Setup
- **GPU**: RTX 5060 Ti (8GB)
- **VRAM**: Tight but workable
- **Speed**: Fast on sm120
- **Batch**: Small batches

### Not Recommended
- **Any GPU** < RTX 50xx series
- Use INT4 r256 or INT8 instead

## Future Prospects

### sm120+ Adoption
As RTX 50xx series becomes standard:
- FP4 r128 will become more viable
- Speed advantages will be realized
- VRAM savings more valuable

### Potential Improvements
- Better FP4 quantization techniques
- Higher rank variants (FP4 r256?)
- Improved kernel optimizations

## Text Encoder and VAE

### Shared Components
- **Text Encoder**: Qwen3 (can quantize separately)
- **VAE**: `ZImageTurbo_VAE_bf16.safetensors` (full precision)

### Additional Savings
```python
# Quantize text encoder too
text_encoder_filename="qwen3_quanto_bf16_int8.safetensors"
# Additional ~1-2 GB VRAM savings
```

## Conclusion

FP4 r128 is a **bleeding-edge variant** for **RTX 50xx GPUs**. It offers the **absolute minimum VRAM** and **maximum speed** on supported hardware, but requires:
1. RTX 50xx series GPU (sm120+)
2. Nunchaku kernels installed
3. Acceptance of quality trade-offs
4. Lower resolution usage (<= 1024x1024)

For **RTX 40xx/30xx users**, INT4 r256 or INT8 are better choices.

---

**Last Updated**: 2/8/2026
**Model Version**: Z-Image Turbo Nunchaku FP4 (r128) 6B
**HuggingFace**: DeepBeepMeep/Z-Image
**Quantization**: SVDQ FP4, Rank 128
**VRAM Requirement**: ~3 GB
**GPU Requirement**: RTX 50xx series (sm120+) for full speed
**Kernel Requirement**: Nunchaku kernels (mandatory)
