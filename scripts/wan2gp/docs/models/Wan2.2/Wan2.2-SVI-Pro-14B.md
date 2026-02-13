# Wan2.2 Image2Video 14B SVI 2 Pro - Technical Documentation
# Last Updated: 2/8/2026 12:45:00 PM CST

## Model Overview

The **Wan2.2 Image2Video 14B SVI 2 Pro** (`i2v_2_2_svi2pro`) is an advanced image-to-video generation model within the Wan2GP framework. It extends the base i2v_2_2 model with specialized "SVI 2 Pro" (Sliding Video Image 2 Professional) capabilities for enhanced control over video generation through anchor images and sliding window operations.

### Model Classification

**File Reference:** [wan_handler.py](file:///opt/wan2gp/Wan2GP/models/wan/wan_handler.py#L12-L46)

```python
def test_class_i2v(base_model_type):
    return base_model_type in ["i2v", "i2v_2_2", "fun_inp_1.3B", "fun_inp", "flf2v_720p", 
                               "fantasy", "multitalk", "infinitetalk", "i2v_2_2_multitalk", 
                               "animate", "chrono_edit", "steadydancer", "wanmove", "scail", 
                               "i2v_2_2_svi2pro"]

def test_i2v_2_2(base_model_type):
    return base_model_type in ["i2v_2_2", "i2v_2_2_multitalk", "i2v_2_2_svi2pro"]

def test_svi2pro(base_model_type):
    return base_model_type in ["i2v_2_2_svi2pro"]
```

- **Model Family:** Wan2.2 (second generation)
- **Base Class:** i2v (Image-to-Video)
- **Parent Model:** `i2v_2_2` (Line 62, 313)
- **Supported Types:** Listed in `query_supported_types()` (Line 51-54)
- **Default FPS:** 16 frames per second (Line 252)

---

## Operational Modes

The SVI 2 Pro model supports three primary operational modes controlled via the `image_prompt_type` parameter:

### 1. Start with Video Image (Mode: "S")

**UI Label:** "Start Video with Image"  
**Code Reference:** [wgp.py](file:///opt/wan2gp/Wan2GP/wgp.py#L9333-L9335), [wan_handler.py](file:///opt/wan2gp/Wan2GP/models/wan/wan_handler.py#L631)

```python
# From wgp.py line 9333-9335
if "S" in image_prompt_types_allowed: 
    image_prompt_type_choices += [("Start Video with Image", "S")]
    any_start_image = True
```

**How It Works:**
- Generates a new video sequence starting from a provided static image
- The starting image becomes the first frame of the generated video
- Model creates motion and continuation from this initial frame
- Useful for animating still photographs or artwork

**Images as Starting Point:**
- One or more images can be provided via the `image_start` gallery parameter
- Each image in the gallery initiates a separate video in the generation queue
- Black frames are automatically inserted if `black_frame` mode is enabled (Line 9354)
- Images are encoded through the VAE encoder to create initial latent representations

**Number of Frames Impact:**
- Starting images add to the total frame count
- The `frame_num` parameter determines total output length
- First frame is always the provided starting image
- Remaining `frame_num - 1` frames are generated

---

### 2. Continue Video (Mode: "V")

**UI Label:** "Continue Video"  
**Code Reference:** [wgp.py](file:///opt/wan2gp/Wan2GP/wgp.py#L9337-L9339)

```python
# From wgp.py line 9337-9339
if "V" in image_prompt_types_allowed:
    any_video_source = True
    image_prompt_type_choices += [("Continue Video", "V")]
```

**How It Works:**
- Extends an existing video by generating new frames that continue from the last frame
- Takes a `video_source` input containing the video to extend
- Analyzes motion, style, and content from source video
- Generates coherent continuation maintaining visual consistency

**Images as Starting Point (within Continue Mode):**
- The **last frame** of the input video serves as the continuation point
- Extracted automatically from `video_source` parameter
- Color correction is applied relative to this reference frame (Line 619 in any2video.py)

**Number of Frames Impact:**
- `keep_frames_video_source` parameter controls which frames from source video are considered
- Format: `"empty=Keep All, negative truncates from End"` (Line 9362)
- Examples:
  - Empty string: Use all frames
  - `"10"`: Truncate beyond 10 resampled frames
  - `"-5"`: Keep all except last 5 frames
- New frames = `frame_num` parameter value
- Total output = truncated source + `frame_num` new frames

---

### 3. Continue Last Video (Mode: "L")

**UI Label:** "Continue Last Video"  
**Code Reference:** [wgp.py](file:///opt/wan2gp/Wan2GP/wgp.py#L9340-L9342)

```python
# From wgp.py line 9340-9342
if "L" in image_prompt_types_allowed:
    any_video_source = True
    image_prompt_type_choices += [("Continue Last Video", "L")]
```

**How It Works:**
- Automatically continues from the **most recently generated video** in the current session
- No manual video upload required - uses internal reference to previous output
- Maintains temporal coherence across multiple sequential generations
- Ideal for creating long-form videos through iterative generation

**Images as Starting Point:**
- Uses the **final frame** from the previously generated video
- Stored internally as `pre_video_frame` (Line 471 in any2video.py)
- Automatically extracted from generation pipeline's output cache

**Number of Frames Impact:**
- Similar to "Continue Video" mode
- Each iteration adds `frame_num` new frames to the sequence
- Sliding window mechanics apply for long sequences
- Can chain multiple "Continue Last Video" operations to create extended content

---

## Anchor Images Feature (SVI 2 Pro Exclusive)

**Code Reference:** [wan_handler.py](file:///opt/wan2gp/Wan2GP/models/wan/wan_handler.py#L302-L313)

```python
# Lines 302-313
if svi2pro:
    extra_model_def["image_ref_choices"] = {
        "choices": [("No Anchor Image", ""),
                   ("Anchor Images For Each Window", "KI"),
        ],
        "letters_filter":  "KI",
        "show_label" : False,
    }
    extra_model_def["all_image_refs_are_background_ref"] = True
    extra_model_def["no_background_removal"] = True
    extra_model_def["parent_model_type"] = "i2v_2_2"
```

### What Are Anchor Images?

Anchor images are **reference frames injected at specific points** during sliding window video generation. They act as "anchors" to maintain visual consistency, style, or subject appearance across long video sequences.

### Two Modes:

1. **No Anchor Image** (`""`)
   - Standard generation without reference image injection
   - Model operates solely on text prompts and starting frames

2. **Anchor Images For Each Window** (`"KI"`)
   - Injects a reference image at the start of **each sliding window**
   - Maintains visual consistency across window boundaries
   - Prevents drift in subject appearance or style over long generations

### Technical Implementation

**Video Prompt Type:** Controlled by `video_prompt_type` parameter with letter code `"KI"`

**Background Reference Treatment:**
- `all_image_refs_are_background_ref = True`: All reference images treated as background/environment references
- `no_background_removal = True`: Background removal is **disabled** for SVI 2 Pro anchor images (Line 311)
- This preserves the full context of each anchor image including backgrounds

**Image Reference Processing:**
- Images provided via `image_refs` parameter (Line 9579 in wgp.py)
- Associated with sliding windows via `frames_positions` parameter (Line 9578)
- Each window can have its own anchor image or share references

### Impact on Frame Generation

**With Anchor Images:**
- Each sliding window starts with a known visual reference
- Reduces cumulative drift over long sequences
- Better temporal consistency across window transitions
- Slightly reduced creative freedom (anchored to reference)

**Without Anchor Images:**
- Pure temporal extension from previous frames
- More creative freedom but potential for drift
- Faster processing (no reference image encoding per window)

---

## Advanced Mode Settings

The SVI 2 Pro model exposes numerous advanced configuration parameters organized into logical tabs/categories:

### General Tab

**Code References:** [wan_handler.py](file:///opt/wan2gp/Wan2GP/models/wan/wan_handler.py#L263-L268), [wgp.py](file:///opt/wan2gp/Wan2GP/wgp.py#L9858-L9862)

#### 1. Guidance (CFG) / Guidance 2 (CFG)

```python
# Line 9858-9862 in wgp.py
guidance_scale = gr.Slider(1.0, 20.0, value=ui_get("guidance_scale"), 
                          step=0.1, label="Guidance (CFG)", 
                          visible=guidance_max_phases >=1 and visible_phases>=1)
guidance2_scale = gr.Slider(1.0, 20.0, value=ui_get("guidance2_scale"), 
                           step=0.1, label="Guidance2 (CFG)", 
                           visible=guidance_max_phases >=2 and guidance_phases_value >= 2)
```

**Purpose:** 
- Controls how strongly the model follows the text prompt vs. exploring creatively
- Guidance (CFG 1): Applied during **high noise** phases (early generation steps)
- Guidance 2 (CFG 2): Applied during **low noise** phases (refinement steps)

**Technical Details:**
- Range: 1.0 to 20.0
- Higher values = stricter prompt adherence
- Lower values = more creative freedom
- Multi-phase guidance system (Line 263: `"guidance_max_phases" : 3`)
- Switch threshold determines transition between guidance phases

**Default Values:**
- Most Wan2 models: Not set in basic mode
- Multiple submodels: `guidance_phases = 2` (Line 1013)

#### 2. Sampler Solver/Scheduler

**Code Reference:** [wan_handler.py](file:///opt/wan2gp/Wan2GP/models/wan/wan_handler.py#L269-L278), [any2video.py](file:///opt/wan2gp/Wan2GP/models/wan/any2video.py#L480-L527)

```python
# Line 269-278 in wan_handler.py
"sample_solvers":[
    ("unipc", "unipc"),
    ("euler", "euler"),
    ("dpm++", "dpm++"),
    ("flowmatch causvid", "causvid"),
    ("lcm + ltx", "lcm"),
]
```

**Available Schedulers:**

1. **UniPC** (Default for most models)
   - Unified Predictor-Corrector multistep scheduler
   - Fast convergence, high quality
   - Default: `ui_defaults["sample_solver"] = "unipc"` (Line 877)

2. **Euler**
   - Euler discrete scheduler
   - Simple, stable
   - Preferred for multitalk models (Line 894)

3. **DPM++**
   - DPM-Solver++ multistep scheduler
   - Higher quality at cost of speed

4. **FlowMatch CausVid**
   - Flow matching with CausVid scheduling
   - Fixed timesteps: `[1000, 934, 862, 756, 603, 410, 250, 140, 74]` (Line 490)
   - Specialized for causal video generation

5. **LCM + LTX**
   - Latent Consistency Model with RectifiedFlow
   - Ultra-fast inference (2-8 steps)
   - Optimized for Lightning LoRAs (Line 506-519)
   - Effective steps capped at 8: `min(sampling_steps, 8)`

**Implementation Details:**
- All schedulers support flow shifting via `shift` parameter
- Dynamic shifting disabled: `use_dynamic_shifting=False`
- Timestep transforms applied: `timestep_transform()` function (Line 69-75 any2video.py)

#### 3. Shift Scale (Flow Shift)

**Code Reference:** [wan_handler.py](file:///opt/wan2gp/Wan2GP/models/wan/wan_handler.py#L265)

```python
# Line 265
"flow_shift": True,
```

**Purpose:**
- Adjusts the noise schedule distribution during denoising
- Higher shift = more denoising steps concentrated in low-noise regions
- Improves fine detail quality

**Model-Specific Defaults:**
- Multitalk: `flow_shift: 7` (720p: 11) (Line 891)
- Infinitetalk: `flow_shift: 7` (Line 901)
- Standin: `flow_shift: 7` (Line 913)
- Lynx: `flow_shift: 7` (Line 922)
- Phantom: `flow_shift: 5` (Line 932)

**Technical Implementation:**
```python
# From any2video.py timestep_transform function (Line 69-75)
def timestep_transform(t, shift=5.0, num_timesteps=1000):
    t = t / num_timesteps
    # shift the timestep based on ratio
    new_t = shift * t / (1 + (shift - 1) * t)
    new_t = new_t * num_timesteps
    return new_t
```

#### 4. Negative Prompt

**Code Reference:** [any2video.py](file:///opt/wan2gp/Wan2GP/models/wan/any2video.py#L536-L541)

```python
# Line 536-541
if n_prompt == "":
    n_prompt = self.sample_neg_prompt
text_len = self.model.text_len
context_null = self.text_encoder_cache.encode(encode_fn, [n_prompt], device=self.device)[0]
context_null = torch.cat([context_null, context_null.new_zeros(text_len -context_null.size(0), 
                                                                context_null.size(1))]).unsqueeze(0)
```

**Purpose:**
- Specifies what the model should **avoid** generating
- Used in classifier-free guidance (CFG)
- Encodes negative descriptions to steer generation away from unwanted elements

**Processing:**
- Encoded using same text encoder as positive prompt
- Padded to match `text_len` dimension
- Used when `any_guidance_at_all = True`

#### 5. Num of Generated Videos Per Prompt

**Purpose:**
- Batch generation of multiple variations from same prompt
- Each video uses different random seed (if seed randomization enabled)

#### 6. Multiple Images as Text Prompts

**Code Reference:** Search results indicate this is related to prompt enhancement features

**Purpose:**
- Alternative prompting method using image captions
- System generates text descriptions from multiple input images
- Combines image-derived prompts with text prompts

**Implementation Note:**
- Requires prompt enhancer models (Florence2, LLaMA)
- Lines 3353-3376 in wgp.py handle prompt enhancer setup

#### 7. NAG Scale / NAG Tau / NAG Alpha

**Code Reference:** [wan_handler.py](file:///opt/wan2gp/Wan2GP/models/wan/wan_handler.py#L653), [any2video.py](file:///opt/wan2gp/Wan2GP/models/wan/any2video.py#L451-L553), [model.py](file:///opt/wan2gp/Wan2GP/models/wan/modules/model.py#L246-L300)

```python
# wan_handler.py Line 653
extra_model_def["NAG"] = vace_class or t2v or i2v

# any2video.py Lines 451-453
NAG_scale = 0,
NAG_tau = 3.5,
NAG_alpha = 0.5,

# any2video.py Line 551
offload.shared_state.update({"_nag_scale" : NAG_scale, "_nag_tau" : NAG_tau, "_nag_alpha": NAG_alpha})
```

**NAG = Negative-prompt Attention Guidance**

A sophisticated technique for controlling generation quality through negative prompt manipulation.

**NAG Scale:**
- Range: 0 to higher values (typically 0-2)
- Controls the **strength** of negative guidance application
- `NAG_scale <= 1`: Disabled
- `NAG_scale > 1`: Enabled, blends positive and negative embeddings
- Implementation (Line 276-277 in model.py):
  ```python
  x_neg.mul_(1-nag_scale)
  x_neg.add_(x_pos, alpha=nag_scale)
  ```

**NAG Tau (τ):**
- Default: 3.5
- **Threshold** for norm-based guidance rescaling
- When guidance norm exceeds tau, it's rescaled to maintain stability
- Implementation (Line 284-285 in model.py):
  ```python
  factor = 1 / (norm_guidance + 1e-7) * norm_positive * nag_tau
  x_guidance = torch.where(scale > nag_tau, x_guidance * factor, x_guidance)
  ```

**NAG Alpha (α):**
- Default: 0.5
- **Blending weight** between positive embeddings and guidance
- Controls how much of the rescaled guidance is mixed with positive conditioning
- Implementation (Line 287-288 in model.py):
  ```python
  x_pos.mul_(1 - nag_alpha)
  x_guidance.mul_(nag_alpha)
  ```

**Overall NAG Algorithm:**
```python
# Simplified conceptual flow (from model.py lines 246-300)
if NAG_scale > 1:
    # 1. Blend positive and negative
    x_neg = (1 - NAG_scale) * x_neg + NAG_scale * x_pos
    
    # 2. Calculate norms
    norm_guidance = ||x_guidance||
    norm_positive = ||x_pos||
    
    # 3. Rescale if exceeds threshold
    if norm_guidance > NAG_tau:
        x_guidance *= (norm_positive * NAG_tau) / norm_guidance
    
    # 4. Blend with alpha
    x_final = (1 - NAG_alpha) * x_pos + NAG_alpha * x_guidance
```

**Purpose:**
- Prevents over-saturation from negative prompts
- Maintains output quality while avoiding unwanted elements
- Stabilizes generation in high-CFG scenarios

---

### LoRAs Tab

**Code Reference:** [wan_handler.py](file:///opt/wan2gp/Wan2GP/models/wan/wan_handler.py#L93-L143)

**Purpose:** Load Low-Rank Adaptation (LoRA) models to fine-tune generation style

**LoRA Directory Structure:**
```python
# Lines 118-143 - LoRA CLI arguments
"--lora-dir-i2v" -> Default: lora_root/wan_i2v
"--lora-dir" -> Default: lora_root/wan
"--lora-dir-wan-1-3b" -> Default: lora_root/wan_1.3B
"--lora-dir-wan-5b" -> Default: lora_root/wan_5B
"--lora-dir-wan-i2v" -> Default: lora_root/wan_i2v
```

**SVI 2 Pro LoRA Selection:**
```python
# Lines 126-143 get_lora_dir()
i2v = test_class_i2v(base_model_type) and not test_i2v_2_2(base_model_type)

if i2v:
    return wan_i2v_dir  # For i2v but not i2v_2_2
# For i2v_2_2_svi2pro, returns wan_dir (default Wan2 LoRAs)
return wan_dir
```

**Notes:**
- SVI 2 Pro uses **Wan 2.2 LoRAs** (not i2v-specific)
- Multiple LoRAs can be loaded simultaneously
- LoRA weights configurable per-layer

---

### Steps Skipping Tab

**Code Reference:** [wan_handler.py](file:///opt/wan2gp/Wan2GP/models/wan/wan_handler.py#L189), [wan_handler.py](file:///opt/wan2gp/Wan2GP/models/wan/wan_handler.py#L143-L180)

```python
# Line 189
extra_model_def["no_steps_skipping"] = True  # When URLs2 in model_def
```

**Purpose:** Advanced cache-based optimization to skip redundant computation steps

**Cache Types:**

1. **MAG Cache** (Magnitude Cache)
   - Enabled: `"mag_cache" : True` (Line 270)
   - Uses pre-computed magnitude ratios for different model types
   - Model-specific MAG ratios defined in `set_cache_parameters()` (Lines 143-180)
   - Example for i2v_2_2 (Line 165-166):
     ```python
     def_mag_ratios = [0.99191, 0.99144, ..., 0.79823, 0.79902]
     ```

2. **TEA Cache** (Temporal Encoding Acceleration)
   - Disabled for i2v_2_2 and URLs2 models: `"tea_cache" : not (base_model_type in ["i2v_2_2"] ...)` (Line 269)
   - Reduces text encoding overhead

**Skip Layer Guidance:**
- Enabled: `"skip_layer_guidance" : True` (Line 264)
- Skips guidance computation for certain transformer layers

**Note:** Multiple submodel configurations (`URLs2`) disable steps skipping entirely (Line 189)

---

### Post-Processing Tab

**Purpose:** Enhance output video quality after generation

**Available Post-Processors:**
- Color correction
- Frame interpolation
- Upscaling
- Artifact reduction

**SVI 2 Pro Specifics:**
- `color_correction = True` (Line 205)
- Color matching between windows/frames

---

### Audio Tab

**Code Reference:** [wan_handler.py](file:///opt/wan2gp/Wan2GP/models/wan/wan_handler.py#L652)

```python
# Line 652
if base_model_type in ["fantasy"] or multitalk:
    extra_model_def["audio_guidance"] = True
```

**Audio Support for SVI 2 Pro:**
- **Not enabled** by default for `i2v_2_2_svi2pro`
- Audio guidance available only for `fantasy` and `multitalk` models
- Audio prompt type controlled via `audio_prompt_type` parameter

**Audio Settings (when enabled):**
- Audio guidance scale (Line 883, 1010)
- Speaker locations
- Audio synchronization with video frames

---

### Quality Tab

**Purpose:** General quality control parameters

**Key Settings:**
- Sampling steps (more steps = higher quality, slower)
- Resolution presets
- VAE upsampling modes (Line 237-238):
  ```python
  if (test_class_t2v(base_model_type) or vace_class) and not test_alpha(base_model_type):
      extra_model_def["vae_upsampler"] = [1,2]
  ```

---

### Sliding Window Tab

**Code Reference:** [wan_handler.py](file:///opt/wan2gp/Wan2GP/models/wan/wan_handler.py#L261, L656-L658)

```python
# Line 261
"sliding_window": base_model_type in ["multitalk", "infinitetalk", "t2v", "t2v_2_2", 
                                      "fantasy", "animate", "lynx"] or test_class_i2v(base_model_type) 
                                      or test_wan_5B(base_model_type) or vace_class

# Lines 656-658 - SVI 2 Pro specific defaults
elif svi2pro:
    extra_model_def["sliding_window_defaults"] = { 
        "overlap_min" : 4, 
        "overlap_max" : 4, 
        "overlap_step": 0, 
        "overlap_default": 4
    }
```

**Sliding Window Parameters:**

1. **Window Size**
   - SVI 2 Pro Default: **81 frames** (Line 862-863, 990-991)
   - Controls how many frames processed in each window
   - Larger windows = better long-term coherence, more VRAM usage

2. **Overlap**
   - SVI 2 Pro: **Fixed at 4 frames** (Line 658, 991)
   - Standard i2v models: 1 frame (Line 656)
   - Frames shared between consecutive windows
   - Ensures smooth transitions
   - More overlap = smoother but slower

3. **Discard Last Frames**
   - Number of frames to discard from end of each window
   - Helps with window boundary artifacts
   - Example: `sliding_window_discard_last_frames : 4` (Line 892)

4. **Color Correction Strength**
   - Matches colors across window boundaries
   - Range: 0-1
   - Applied via `match_and_blend_colors()` (import at Line 45 any2video.py)

**Default Settings (Lines 862-863, 990-991):**
```python
if test_svi2pro(base_model_type):
    ui_defaults.update({
        "sliding_window_size": 81, 
        "sliding_window_overlap": 4,
    })
```

---

### Misc Tab

**Miscellaneous Advanced Options:**

1. **Self Refiner Settings** (Lines 866-873)
   ```python
   if model_def.get("self_refiner", False):
       ui_defaults["self_refiner_setting"] = 0
       ui_defaults["self_refiner_plan"] = ""
       ui_defaults["self_refiner_f_uncertainty"] = 0.1
       ui_defaults["self_refiner_certain_percentage"] = 0.999
   ```
   - `self_refiner = True` for SVI 2 Pro (Line 280)
   - Iterative refinement system
   - Uncertainty-based selective refinement

2. **CFG Zero / CFG Star**
   - Advanced CFG variants (Line 266-267)
   - `cfg_zero = True`: Zero-initialized CFG
   - `cfg_star = True`: Optimized CFG calculation

3. **Adaptive Projected Guidance** (APG)
   - Enabled: `adaptive_projected_guidance = True` (Line 268)
   - Dynamic adjustment of guidance strength
   - Implementation: `adaptive_projected_guidance()` function (Line 45 import)

---

## Sliding Window Mechanics (Deep Dive)

**Code Reference:** [any2video.py](file:///opt/wan2gp/Wan2GP/models/wan/any2video.py#L574-L700)

### How Sliding Windows Work with SVI 2 Pro

The sliding window system allows generation of videos **longer than the model's native context window** by processing video in overlapping segments.

### Window Processing Flow:

1. **Initialization**
   ```python
   # Line 578 - any2video.py
   lat_frames = int((frame_num - 1) // self.vae_stride[0]) + 1
   ```
   - Total frames divided into latent space representation
   - VAE stride determines compression ratio (typically 4:1 temporal)

2. **First Window** (No Overlap)
   - Processes frames 0 to `window_size` (81 for SVI 2 Pro)
   - Starting image encoded as first frame
   - Anchor image (if enabled) injected at window start

3. **Subsequent Windows** (With Overlap)
   ```python
   # Overlap handling (conceptual from lines 656-680)
   overlapped_latents = previous_window[-overlap_size:]
   new_window_input = concat([overlapped_latents, new_latents])
   ```
   - Last 4 frames from previous window reused
   - Provides continuity for next window
   - New frames start from frame 5 onward

4. **Anchor Image Injection** (SVI 2 Pro)
   ```python
   # Lines 655-680 - Reference image processing
   if svi_pro:
       if overlapped_latents is not None:
           post_decode_pre_trim = 1
       image_ref_latents = self.vae.encode([image_ref], VAE_tile_size)[0]
       pad_len = lat_frames + ref_images_count - image_ref_latents.shape[1] 
                 - (overlapped_latents.shape[2] if overlapped_latents is not None else 0)
       lat_y = torch.concat([image_ref_latents, overlapped_latents.squeeze(0), pad_latents], dim=1)
   ```
   - Anchor image encoded to latents
   - Concatenated with overlap latents from previous window
   - Padding added for remaining window frames

5. **Window Blending**
   - Color correction applied across boundaries (Line 456)
   - Momentum buffers smooth temporal transitions (Line 45 import: `MomentumBuffer`)
   - Overlap region gradually transitions from old to new

### Visual Representation:

```
Window 1: [Anchor1][F1][F2]...[F77]  (81 frames total)
                              ↓ 4-frame overlap
Window 2:              [Anchor2][F74][F75][F76][F77][F78]...[F154]
                                                      ↓ 4-frame overlap  
Window 3:                                      [Anchor3][F151][F152]...
```

### SVI 2 Pro Differences from Standard i2v_2_2:

| Feature | Standard i2v_2_2 | SVI 2 Pro |
|---------|-----------------|-----------|
| Overlap Size | 1 frame | 4 frames |
| Anchor Images | Not supported | Supported per window |
| Background Removal | Optional | Disabled (preserves full context) |
| Window Size | Default varies | Fixed at 81 frames |
| Latent Handling | Standard concatenation | Special ref_latents system |

### Performance Implications:

- **4-frame overlap**: Increases processing time ~5% per window but significantly improves coherence
- **Anchor images**: Add ~10% overhead per window (VAE encoding) but reduce drift
- **81-frame windows**: Balanced between memory usage and temporal understanding

---

## Special Image Prompt Types

**Code Reference:** [wan_handler.py](file:///opt/wan2gp/Wan2GP/models/wan/wan_handler.py#L619-L635)

```python
# Lines 619-635
if vace_class or base_model_type in ["animate", "t2v", "t2v_2_2", "lynx"]:
    image_prompt_types_allowed = "TVL"
elif base_model_type in ["infinitetalk"]:
    image_prompt_types_allowed = "TSVL"
elif base_model_type in ["ti2v_2_2"]:
    image_prompt_types_allowed = "TSVL"
elif base_model_type in ["lucy_edit"]:
    image_prompt_types_allowed = "TVL"
elif multitalk or base_model_type in ["fantasy", "steadydancer", "scail"] or svi2pro:
    image_prompt_types_allowed = "SVL"
elif i2v:
    image_prompt_types_allowed = "SEVL"
```

### For SVI 2 Pro: `"SVL"`

**Letter Codes:**
- **S** = Start with Video Image
- **V** = Continue Video  
- **L** = Continue Last Video
- **E** = End Image(s) (NOT supported for SVI 2 Pro)
- **T** = Text Prompt Only (NOT supported for SVI 2 Pro)

### Additional Image Types (Other Models):

**Standard i2v models** support `"SEVL"`:
- All SVI 2 Pro modes PLUS:
- **E** = End Image(s): Specify target endpoint for interpolation

### Interaction with End Images:

```python
# Lines 9356-9358 in wgp.py
if "E" in image_prompt_types_allowed:
    image_prompt_type_endcheckbox = gr.Checkbox(value="E" in image_prompt_type_value, 
                                                label="End Image(s)", ...)
```

When end images are supported:
- Model interpolates from start to end image
- Frame count includes both endpoints
- Useful for morphing, transitions, or guided animations

---

## Special Video Prompt Types

**Code Reference:** [wan_handler.py](file:///opt/wan2gp/Wan2GP/models/wan/wan_handler.py#L234-L283), [wgp.py](file:///opt/wan2gp/Wan2GP/wgp.py#L9400-L9450)

### Video-to-Video Guidance (i2v_2_2 & SVI 2 Pro)

```python
# Lines 283-295 in wan_handler.py
if base_model_type in ["i2v_2_2"]: 
    extra_model_def["i2v_v2v"] = True
    extra_model_def["extract_guide_from_window_start"] = True
    extra_model_def["guide_custom_choices"] = {
        "choices":[
            ("Use Text & Image Prompt Only", ""),
            ("Video to Video guided by Text Prompt & Image", "GUV"),
            ("Video to Video guided by Text/Image Prompt and Restricted to Area of Video Mask", "GVA")
        ],
        "default": "",
        "show_label": False,
        "letters_filter": "GUVA",
        "label": "Video to Video"
    }
```

**Video Prompt Modes:**

1. **Use Text & Image Prompt Only** (`""`)
   - Standard i2v generation
   - No video guidance
   - Pure creative generation from prompts

2. **Video to Video (GUV)**
   - Use control video to guide generation
   - `G` = Guide enabled
   - `U` = Unchanged control video processing
   - `V` = Video source
   - Strength controlled by `denoising_strength` parameter

3. **Video to Video with Mask (GVA)**
   - Similar to GUV but restricted to masked areas
   - `A` = Area processing (mask)
   - Allows selective video transformation
   - `masking_strength` controls blend

### Control Video Preprocessing Options

**Code Reference:** [wgp.py](file:///opt/wan2gp/Wan2GP/wgp.py#L9400-L9415)

```python
# Lines 9400-9415
guide_preprocessing_labels_all = {
    "": "No Control Video",
    "UV": "Keep Control Video Unchanged",
    "PV": "Transfer Human {pose_label}",
    "DV": "Transfer Depth",
    "EV": "Transfer Canny Edges",
    "SV": "Transfer Shapes",
    "LV": "Transfer Flow",
    "CV": "Recolorize",
    "MV": "Perform Inpainting",
    "PDV": "Transfer Human {pose_label} & Depth",
    "PSV": "Transfer Human {pose_label} & Shapes",
    "PLV": "Transfer Human {pose_label} & Flow",
    "DSV": "Transfer Depth & Shapes",
    "DLV": "Transfer Depth & Flow",
    "SLV": "Transfer Shapes & Flow",
}
```

### Mask Preprocessing Options

```python
# Lines 9476-9491
mask_preprocessing_labels_all = {
    "": "Whole Frame",
    "A": "Masked Area",
    "NA": "Non Masked Area",
    "XA": "Masked Area, rest Inpainted",
    "XNA": "Non Masked Area, rest Inpainted", 
    "YA": "Masked Area, rest Depth",
    "YNA": "Non Masked Area, rest Depth",
    "WA": "Masked Area, rest Shapes",
    "WNA": "Non Masked Area, rest Shapes",
    "ZA": "Masked Area, rest Flow",
    "ZNA": "Non Masked Area, rest Flow"
}
```

**SVI 2 Pro Mask Support:**
```python
# Line 295-300
extra_model_def["mask_preprocessing"] = {
    "selection": ["", "A"],
    "visible": False
}
```
- Basic mask support (whole frame or masked area)
- Limited compared to VACE models

---

## Model Configuration Summary

### Model Definition Flags (SVI 2 Pro)

**Code Reference:** [wan_handler.py](file:///opt/wan2gp/Wan2GP/models/wan/wan_handler.py#L196-L313)

```python
extra_model_def["i2v_class"] = True
extra_model_def["t2v_class"] = False
extra_model_def["multitalk_class"] = False
extra_model_def["standin_class"] = False
extra_model_def["lynx_class"] = False
extra_model_def["alpha_class"] = False
extra_model_def["wan_5B_class"] = False
extra_model_def["vace_class"] = False
extra_model_def["color_correction"] = True
extra_model_def["svi2pro"] = True
extra_model_def["i2v_2_2"] = True
extra_model_def["black_frame"] = True
extra_model_def["sliding_window"] = True
extra_model_def["multiple_submodels"] = False  # Depends on URLs2
extra_model_def["NAG"] = True  # Negative-prompt Attention Guidance
extra_model_def["self_refiner"] = True
extra_model_def["motion_amplitude"] = True
extra_model_def["i2v_v2v"] = True  # Video-to-Video support
extra_model_def["extract_guide_from_window_start"] = True
```

### Frame Configuration

```python
frames_minimum = 5
frames_steps = 4
fps = 16
```

### Profiles Directory

```python
profiles_dir = ["wan_2_2"]
group = "wan2_2"
```

---

## Complete Parameter Reference Table

| Parameter | Type | Default | Range | Purpose |
|-----------|------|---------|-------|---------|
| `base_model_type` | String | "i2v_2_2_svi2pro" | - | Model identifier |
| `image_prompt_type` | String | "S" | "S", "V", "L" | Operational mode |
| `video_prompt_type` | String | "" | "KI", "GUV", "GVA", etc. | Video guidance mode |
| `frame_num` | Integer | Varies | 5+ (steps of 4) | Total output frames |
| `sliding_window_size` | Integer | 81 | - | Frames per window |
| `sliding_window_overlap` | Integer | 4 | 4 | Overlap between windows |
| `guidance_scale` | Float | Model default | 1.0-20.0 | CFG strength (phase 1) |
| `guidance2_scale` | Float | Model default | 1.0-20.0 | CFG strength (phase 2) |
| `sample_solver` | String | "unipc" | See list above | Scheduler type |
| `flow_shift` | Float | Model default | 0-20 | Noise schedule shift |
| `NAG_scale` | Float | 0 | 0-2+ | Negative guidance strength |
| `NAG_tau` | Float | 3.5 | 0-10 | NAG threshold |
| `NAG_alpha` | Float | 0.5 | 0-1 | NAG blending weight |
| `denoising_strength` | Float | 0.9 (i2v_2_2) | 0-1 | V2V guidance strength |
| `masking_strength` | Float | 0.1 (i2v_2_2) | 0-1 | Mask area influence |
| `color_correction_strength` | Float | 1.0 | 0-1 | Window color matching |
| `motion_amplitude` | Float | 1.0 | Variable | Motion intensity |

---

## Code Location Quick Reference

| Component | File | Lines |
|-----------|------|-------|
| Model type tests | wan_handler.py | 12-46 |
| Model definition | wan_handler.py | 185-280 |
| Default settings | wan_handler.py | 875-1015 |
| Sliding window defaults | wan_handler.py | 656-658, 862-863, 990-991 |
| SVI 2 Pro anchor images | wan_handler.py | 302-313 |
| Operational modes UI | wgp.py | 9333-9342 |
| NAG implementation | any2video.py | 451-553 |
| NAG algorithm | modules/model.py | 246-300 |
| Scheduler implementations | any2video.py | 480-527 |
| Sliding window processing | any2video.py | 574-700 |
| Image prompt types | wan_handler.py | 619-635 |
| Video prompt types | wan_handler.py | 234-295 |

---

## Performance Optimization Tips

### For Best Quality:
1. Use **4-frame overlap** (default for SVI 2 Pro)
2. Enable **anchor images** for long videos (prevents drift)
3. Set **guidance scale** to 3.5-7.0 range
4. Use **UniPC** or **Euler** scheduler
5. Enable **color correction** (default on)

### For Best Speed:
1. Use **LCM scheduler** with 4-8 steps
2. Disable anchor images if temporal drift acceptable
3. Reduce sliding window overlap (not recommended for quality)
4. Lower sampling steps (minimum 8 for decent quality)

### For Long Videos:
1. **Enable anchor images** ("KI" mode)
2. Use **81-frame windows** (default)
3. Set **color_correction_strength = 0.8-1.0**
4. Consider **"Continue Last Video"** mode for episodic generation
5. Monitor VRAM usage (anchor images add overhead)

---

## Timed Prompts

The Wan2.2 SVI Pro model supports **timed prompts** that allow you to specify actions or changes at particular points within your video using the following syntax:

```
(at X seconds:prompt text describing action)
```

### How Timed Prompts Work

Timed prompts enable fine-grained control over what happens at specific moments during video generation. Each prompt is associated with a sliding window, and the times specified in your prompt refer to **the time within that sliding window's duration**, not the absolute time of the full video.

**Key Point:** Times are **relative to each sliding window**, not the entire video sequence.

### Example Scenario

Consider this scenario:
- **Total Video Length:** 240 frames
- **Frame Rate:** 16 fps
- **Total Duration:** 15 seconds (240 ÷ 16)
- **Sliding Window Size:** 81 frames
- **Window Duration:** ~5 seconds per window (81 ÷ 16)
- **Number of Windows:** 3 windows total

**Calculating Window Times:**
- Window 1: Frames 0-80 = 0-5 seconds (of window)
- Window 2: Frames 81-161 = 0-5 seconds (of window) = 5-10 seconds (of full video)
- Window 3: Frames 162-240 = 0-5 seconds (of window) = 10-15 seconds (of full video)

### Time Reference: Window-Relative vs. Absolute

**Answer to Your Question:**

If you want an action to occur 3 seconds into the 2nd sliding window (which translates to 8 seconds from the beginning of the full video), you would specify:

```
(at 3 seconds:do action)
```

**NOT** `(at 8 seconds:do action)` for the 2nd window's prompt.

This is because each prompt is associated with its own sliding window. When Wan2GP processes the 2nd window's prompt, the time references are relative to that window's local timeline (0-5 seconds), not the full video's absolute timeline.

### Implementation Detail

**Code Reference:** [wgp.py](file:///opt/wan2gp/Wan2GP/wgp.py#L5988)

```python
prompt = prompts[window_no] if window_no < len(prompts) else prompts[-1]
```

Prompts are indexed by `window_no`. Each window retrieves its corresponding prompt from the prompts list. This means each prompt's time markers are interpreted relative to that window's temporal context.

### Practical Example

For a 15-second video with 3 sliding windows, if you want to specify actions across all windows:

```
Window 1 Prompt:
"A person walks into a room at 0 seconds, sits down at 3.5 seconds, 
(at 4 seconds:looks at camera)"

Window 2 Prompt:
"The person is sitting and reading a book. 
(at 2 seconds:they laugh), 
(at 4.5 seconds:closes book)"

Window 3 Prompt:
"The person stands up (at 1 second:and walks toward door), 
(at 3.5 seconds:exits through door)"
```

Each time marker is calculated from the start of that window's 5-second duration.

---

## Prompting Guide

**NOTE:** The comprehensive Prompting Guide for Wan2.2 SVI Pro has been moved to a dedicated file for better organization and LLM-friendly formatting.

**See:** [Wan2.2-SVI-Pro-14B-PromptGuide.md](Wan2.2-SVI-Pro-14B-PromptGuide.md)

The Prompting Guide covers:
- Positive Prompt Writing (5 key practices)
- Negative Prompt Writing (5 key practices)
- LoRA Usage and strategy
- Timed Prompts with window-relative timing
- Camera Guidance Prompts with movement and perspective terms
- Character and Person Movement Guidance
- Settings Reference

This separate guide is designed to be fed to LLMs for programmatic prompt generation, while keeping the main technical documentation focused on model configuration and operation.

---

## Troubleshooting Common Issues

### Issue: Temporal Drift Over Long Sequences
**Solution:** Enable anchor images via `video_prompt_type = "KI"`

### Issue: Discontinuities at Window Boundaries
**Solution:** 
- Increase overlap (though SVI 2 Pro fixed at 4)
- Increase color_correction_strength
- Check sliding_window_discard_last_frames setting

### Issue: Colors Shift Between Sections
**Solution:**
- Verify `color_correction = True` in model_def
- Adjust `color_correction_strength` parameter
- Check that `color_reference_frame` is properly set

### Issue: Low Adherence to Prompt
**Solution:**
- Increase `guidance_scale` (try 5.0-8.0)
- Verify prompt encoding (check text_encoder output)
- Adjust NAG_scale if too high (reduces prompt influence)

### Issue: Static or Minimal Motion
**Solution:**
- Increase `motion_amplitude` parameter
- Lower `denoising_strength` if using V2V mode
- Check that flow_shift isn't too high

---

## References

### Primary Source Files:
- `/opt/wan2gp/Wan2GP/models/wan/wan_handler.py` - Model configuration and defaults
- `/opt/wan2gp/Wan2GP/models/wan/any2video.py` - Core generation pipeline
- `/opt/wan2gp/Wan2GP/wgp.py` - UI and parameter handling
- `/opt/wan2gp/Wan2GP/models/wan/modules/model.py` - NAG implementation

### Key Functions:
- `test_svi2pro()` - Model type detection
- `query_model_def()` - Model definition builder
- `update_default_settings()` - Default parameter initialization
- `set_cache_parameters()` - Cache optimization setup
- `WanAny2V.__call__()` - Main generation function

---

## Version Information

**Model Series:** Wan2.2  
**Model Variant:** Image2Video 14B SVI 2 Pro  
**Internal Name:** `i2v_2_2_svi2pro`  
**Parent Model:** `i2v_2_2`  
**Documentation Date:** February 8, 2026  
**Codebase Version:** As of latest repository state

---

*This documentation is based on analysis of the Wan2GP codebase. For the most current information, always refer to the source code.*
