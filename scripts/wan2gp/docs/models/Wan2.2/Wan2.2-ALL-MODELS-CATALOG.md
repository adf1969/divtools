# Wan2.2 Complete Model Catalog
# Comprehensive list of all Wan2.2 model variants in Wan2GP
# Last Updated: 2/8/2026 9:42:00 PM CST

## Overview

This document catalogs ALL Wan2.2 model variants found in the Wan2GP codebase at `/opt/wan2gp/Wan2GP/`. Each model is documented with its exact identifier, parameter size, purpose, and key features.

**Source Files:**
- Model Handler: [wan_handler.py](file:///opt/wan2gp/Wan2GP/models/wan/wan_handler.py)
- Model Definitions: `/opt/wan2gp/Wan2GP/defaults/*.json`

---

## 1. Wan2.2 Image2Video 14B (i2v_2_2)

### Model Identifiers
- **Architecture Code**: `i2v_2_2`
- **Model Type String**: `"i2v_2_2"`
- **Display Name**: "Wan2.2 Image2video 14B"

### Specifications
- **Parameter Size**: 14B (14 billion parameters)
- **Primary Purpose**: Image-to-Video generation
- **Release Info**: Wan 2.2 series
- **Group**: `wan2_2`
- **FPS**: 16

### Model Files (HuggingFace)
```
DeepBeepMeep/Wan2.2:
  - wan2.2_image2video_14B_high_mbf16.safetensors
  - wan2.2_image2video_14B_high_quanto_mbf16_int8.safetensors
  - wan2.2_image2video_14B_high_quanto_mfp16_int8.safetensors
  - wan2.2_image2video_14B_low_mbf16.safetensors (URLs2)
  - wan2.2_image2video_14B_low_quanto_mbf16_int8.safetensors (URLs2)
  - wan2.2_image2video_14B_low_quanto_mfp16_int8.safetensors (URLs2)
```

### Key Features
- **Dual Model Architecture**: Uses both high-noise and low-noise models (URLs and URLs2)
- **Video-to-Video Support**: `i2v_v2v` enabled
- **Sliding Window**: Enabled with 1-frame overlap
- **Black Frame Support**: Yes
- **Color Correction**: Enabled
- **Motion Amplitude Control**: Supported
- **Extract Guide from Window Start**: Yes

### Default Settings
```json
{
  "guidance_phases": 2,
  "switch_threshold": 900,
  "guidance_scale": 3.5,
  "guidance2_scale": 3.5,
  "masking_strength": 0.1,
  "denoising_strength": 0.9,
  "flow_shift": 5
}
```

### Video Prompts (Guide Modes)
- `""` - Use Text & Image Prompt Only
- `"GUV"` - Video to Video guided by Text Prompt & Image
- `"GVA"` - Video to Video guided by Text/Image Prompt and Restricted to the Area of the Video Mask

### Image Prompt Types Allowed
`"SEVL"` (Standard, Enhanced, Video, Lora)

### Mask Preprocessing Options
- `""` - No mask
- `"A"` - Apply mask

### Profiles Directory
`["wan_2_2"]`

### Code References
- Handler Check: [wan_handler.py#L33](file:///opt/wan2gp/Wan2GP/models/wan/wan_handler.py#L33) - `test_i2v_2_2()`
- Test Function: [wan_handler.py#L11](file:///opt/wan2gp/Wan2GP/models/wan/wan_handler.py#L11) - `test_class_i2v()`
- Model Config: [wan_handler.py#L279-L303](file:///opt/wan2gp/Wan2GP/models/wan/wan_handler.py#L279-L303)

---

## 2. Wan2.2 Text2Video 14B (t2v_2_2)

### Model Identifiers
- **Architecture Code**: `t2v_2_2`
- **Model Type String**: `"t2v_2_2"`
- **Display Name**: "Wan2.2 Text2video 14B"

### Specifications
- **Parameter Size**: 14B (14 billion parameters)
- **Primary Purpose**: Text-to-Video generation
- **Release Info**: Wan 2.2 series
- **Group**: `wan2_2`
- **FPS**: 16

### Model Files (HuggingFace)
```
DeepBeepMeep/Wan2.2:
  - wan2.2_text2video_14B_high_mbf16.safetensors
  - wan2.2_text2video_14B_high_quanto_mbf16_int8.safetensors
  - wan2.2_text2video_14B_high_quanto_mfp16_int8.safetensors
  - wan2.2_text2video_14B_low_mbf16.safetensors (URLs2)
  - wan2.2_text2video_14B_low_quanto_mbf16_int8.safetensors (URLs2)
  - wan2.2_text2video_14B_low_quanto_mfp16_int8.safetensors (URLs2)
```

### Key Features
- **Dual Model Architecture**: Uses both high-noise and low-noise models
- **Sliding Window**: Enabled
- **Video-to-Video Support**: Yes (`GUV`, `GVA` modes)
- **V2I Switch**: Supported (can switch to Image mode)
- **VAE Upsampler**: Supported [1,2]

### Default Settings
```json
{
  "guidance_phases": 2,
  "switch_threshold": 875,
  "guidance_scale": 4,
  "guidance2_scale": 3,
  "flow_shift": 12
}
```

### Video Prompts (Guide Modes)
- `""` - Use Text Prompt Only
- `"GUV"` - Video to Video guided by Text Prompt
- `"GVA"` - Video to Video guided by Text Prompt and Restricted to the Area of the Video Mask

### Image Prompt Types Allowed
`"TVL"` (Text, Video, Lora)

### Mask Preprocessing Options
- `""` - No mask
- `"A"` - Apply mask

### Profiles Directory
`["wan_2_2"]`

### Code References
- Handler Check: [wan_handler.py#L14](file:///opt/wan2gp/Wan2GP/models/wan/wan_handler.py#L14) - `test_class_t2v()`
- Model Config: [wan_handler.py#L217-L224](file:///opt/wan2gp/Wan2GP/models/wan/wan_handler.py#L217-L224)

---

## 3. Wan2.2 TextImage2Video 5B (ti2v_2_2)

### Model Identifiers
- **Architecture Code**: `ti2v_2_2`
- **Model Type String**: `"ti2v_2_2"`
- **Display Name**: "Wan2.2 TextImage2video 5B"

### Specifications
- **Parameter Size**: 5B (5 billion parameters)
- **Primary Purpose**: Text+Image to Video generation (hybrid input)
- **Release Info**: Wan 2.2 series
- **Group**: `wan2_2`
- **FPS**: 24
- **VAE Block Size**: 32 (different from 14B models)

### Model Files (HuggingFace)
```
DeepBeepMeep/Wan2.2:
  - wan2.2_text2video_5B_mbf16.safetensors
  - wan2.2_text2video_5B_quanto_mbf16_int8.safetensors

DeepBeepMeep/Wan2.1:
  - Wan2.2_VAE.safetensors (uses 2.2 VAE, not 2.1)
```

### Key Features
- **5B Class Model**: Identified by `test_wan_5B()` function
- **Separate VAE**: Uses Wan2.2_VAE (32 block size vs 16 for 14B)
- **Sliding Window**: Enabled with locked size of 121 frames
- **Default Window Overlap**: 1 frame
- **Color Correction Strength**: 0 (disabled)
- **Lora Directory**: `wan_5B`
- **Image Prompt Default**: "T" (Text mode)

### Default Settings
```json
{
  "video_length": 121,
  "guidance_scale": 5,
  "flow_shift": 5,
  "num_inference_steps": 50,
  "resolution": "1280x720",
  "sliding_window_size": 121,
  "sliding_window_overlap": 1,
  "image_prompt_type": "T"
}
```

### Image Prompt Types Allowed
`"TSVL"` (Text, Standard, Video, Lora)

### Profiles Directory
`["wan_2_2_5B"]`

### Code References
- Handler Check: [wan_handler.py#L29](file:///opt/wan2gp/Wan2GP/models/wan/wan_handler.py#L29) - `test_wan_5B()`
- VAE Block Size: [wan_handler.py#L674](file:///opt/wan2gp/Wan2GP/models/wan/wan_handler.py#L674)
- Lora Dir: [wan_handler.py#L124](file:///opt/wan2gp/Wan2GP/models/wan/wan_handler.py#L124)

---

## 4. Wan2.2 Lucy Edit v1 5B (lucy_edit)

### Model Identifiers
- **Architecture Code**: `lucy_edit`
- **Model Type String**: `"lucy_edit"`
- **Display Name**: "Wan2.2 Lucy Edit v1 5B"

### Specifications
- **Parameter Size**: 5B (5 billion parameters)
- **Primary Purpose**: Video editing with instruction-guided prompts
- **Release Info**: Wan 2.2 series
- **Group**: `wan2_2`
- **FPS**: 24

### Model Files (HuggingFace)
```
DeepBeepMeep/Wan2.2:
  - wan2.2_lucy_edit_mbf16.safetensors
  - wan2.2_lucy_edit_quanto_mbf16_int8.safetensors
  - wan2.2_lucy_edit_quanto_mfp16_int8.safetensors
```

### Key Features
- **5B Class Model**: Part of the wan_5B family
- **Video Editing Specialist**: Instruction-guided edits on videos
- **Edit Types Supported**:
  - Clothing & accessory changes
  - Character changes
  - Object insertions
  - Scene replacements
- **Motion Preservation**: Preserves motion and composition perfectly
- **Control Video Required**: Uses `"UV"` (Use Video) guide preprocessing
- **Keep Frames Not Supported**: Cannot preserve specific frames

### Default Settings
```json
{
  "prompt": "change the clothes to red",
  "video_length": 81,
  "guidance_scale": 5,
  "flow_shift": 5,
  "num_inference_steps": 30,
  "resolution": "1280x720",
  "video_prompt_type": "UV",
  "sliding_window_size": 121,
  "sliding_window_overlap": 1
}
```

### Guide Preprocessing
- **Selection**: `["UV"]`
- **Labels**: `{"UV": "Control Video"}`
- **Visible**: False (always uses UV)

### Image Prompt Types Allowed
`"TVL"` (Text, Video, Lora)

### Profiles Directory
`["wan_2_2_5B"]` (shares settings with ti2v_2_2)

### Code References
- Model Config: [wan_handler.py#L413-L420](file:///opt/wan2gp/Wan2GP/models/wan/wan_handler.py#L413-L420)

---

## 5. Wan2.2 OVI v1.0 10B (ovi)

### Model Identifiers
- **Architecture Code**: `ovi`
- **Model Type String**: `"ovi"`
- **Display Name**: "Wan2.2 Ovi v1.0 5s 10B"
- **Handler File**: [ovi_handler.py](file:///opt/wan2gp/Wan2GP/models/wan/ovi_handler.py)

### Specifications
- **Parameter Size**: 10B (10 billion parameters)
- **Primary Purpose**: Audio-Video generation (speaking characters)
- **Release Info**: Wan 2.2 series, v1.0
- **Group**: `wan2_2`
- **FPS**: 24
- **Unique Feature**: **Returns Audio** alongside video

### Model Files (HuggingFace)
```
DeepBeepMeep/Wan2.2:
  Video Model:
    - wan2.2_ovi_video_10B_bf16.safetensors
    - wan2.2_ovi_video_10B_quanto_bf16_int8.safetensors
  
  Audio Model (URLs2):
    - wan2.2_ovi_audio_10B_bf16.safetensors
    - wan2.2_ovi_audio_10B_quanto_bf16_int8.safetensors

DeepBeepMeep/Wan2.1:
  Audio Processing:
    - mmaudio/v1-16.pth
    - mmaudio/best_netG.pt
```

### Key Features
- **Dual-Modal Output**: Generates both video AND audio
- **Speaking Character Specialist**: Optimized for characters speaking
- **Audio Guidance**: Enabled
- **Special Prompt Tags**:
  - `<S>...</E>` - Delimits speaker words
  - `<AUDCAP>...</ENDAUDCAP>` - Sets background noise/audio caption
- **Based On**: ti2v_2_2 architecture (5B foundation + audio layers)
- **Sliding Window**: Enabled, size locked
- **Default Overlap**: 1 frame
- **Compile Support**: Both transformer and transformer2

### Default Settings
```json
{
  "num_inference_steps": 30,
  "video_length": 121,
  "guidance_scale": 5,
  "flow_shift": 5,
  "sliding_window_size": 121,
  "sliding_window_overlap": 1
}
```

### Example Prompt
```
A singer in a glittering jacket grips the microphone, sweat shining on his brow, 
and shouts, <S>The end is night<E>. The crowd roars in response, fists in the air. 
Behind him, a guitarist steps to the mic and adds to say 
<S>We must all find a bunker where to hide.<E>. The energy peaks as the lights 
flare brighter. <AUDCAP>Electric guitar riffs, cheering crowd, shouted male voices.<ENDAUDCAP>
```

### Image Prompt Types Allowed
`"TSVL"` (Text, Standard, Video, Lora)

### Profiles Directory
`["wan_2_2_ovi"]`

### Lora Directory
`wan_5B` (same as ti2v_2_2)

### Code References
- Handler: [ovi_handler.py](file:///opt/wan2gp/Wan2GP/models/wan/ovi_handler.py)
- Config: [ovi_handler.py#L37-L70](file:///opt/wan2gp/Wan2GP/models/wan/ovi_handler.py#L37-L70)

---

## 6. Wan2.2 Image2Video SVI 2 Pro 14B (i2v_2_2_svi2pro)

### Model Identifiers
- **Architecture Code**: `i2v_2_2_svi2pro`
- **Model Type String**: `"i2v_2_2_svi2pro"`
- **Display Name**: "Wan2.2 Image2video SVI 2 Pro 14B"
- **Full Name**: Stable Video Infinity 2 Pro

### Specifications
- **Parameter Size**: 14B (14 billion parameters - same as i2v_2_2)
- **Primary Purpose**: Extended/infinite video generation with anchor images
- **Parent Model**: `i2v_2_2`
- **Release Info**: Wan 2.2 series, SVI v2.0 Pro
- **Group**: `wan2_2`
- **FPS**: 16

### Model Files (HuggingFace)
```
Uses i2v_2_2 base models PLUS LoRAs:

DeepBeepMeep/Wan2.2:
  Base (references i2v_2_2):
    - wan2.2_image2video_14B_high_*.safetensors
    - wan2.2_image2video_14B_low_*.safetensors
  
  LoRAs (SVI-specific):
    - SVI_Wan2.2-I2V-A14B_high_noise_lora_v2.0_pro.safetensors
    - SVI_Wan2.2-I2V-A14B_low_noise_lora_v2.0_pro.safetensors
```

### Key Features
- **Potentially Unlimited Videos**: Continue generation indefinitely
- **Anchor Images**: Use reference images across windows
  - `""` - No Anchor Image
  - `"KI"` - Anchor Images For Each Window
- **Parent Model**: i2v_2_2 (inherits all i2v_2_2 features)
- **LoRA Multipliers**: `["1;0", "0;1"]` (phase-based)
- **Sliding Window**: 81 frames (larger than base i2v_2_2)
- **Window Overlap**: 4 frames (vs 1 for base model)
- **All Image Refs Are Background**: Yes
- **No Background Removal**: Yes (preserves background)

### Default Settings
```json
{
  "guidance_phases": 2,
  "switch_threshold": 900,
  "guidance_scale": 3.5,
  "guidance2_scale": 3.5,
  "flow_shift": 5,
  "sliding_window_size": 81,
  "sliding_window_overlap": 4
}
```

### Image Reference Choices
- **No Anchor Image** (`""`)
- **Anchor Images For Each Window** (`"KI"`)

### Image Prompt Types Allowed
`"SVL"` (Standard, Video, Lora)

### Profiles Directory
`["wan_2_2"]` (same as i2v_2_2)

### Code References
- SVI Check: [wan_handler.py#L36](file:///opt/wan2gp/Wan2GP/models/wan/wan_handler.py#L36) - `test_svi2pro()`
- Config: [wan_handler.py#L304-L315](file:///opt/wan2gp/Wan2GP/models/wan/wan_handler.py#L304-L315)

---

## 7. Wan2.2 VACE 14B (vace_14B_2_2)

### Model Identifiers
- **Architecture Code**: `vace_14B_2_2`
- **Model Type String**: `"vace_14B_2_2"`
- **Display Name**: "Wan2.2 Vace 14B"
- **Full Name**: Video Adaptive ControlNet Engine

### Specifications
- **Parameter Size**: 14B (14 billion parameters)
- **Primary Purpose**: Video generation with advanced control (poses, depth, etc.)
- **Parent Model**: `vace_14B` (2.1 version)
- **Release Info**: Wan 2.2 series (PARTIAL support - uses 2.1 VACE module)
- **Group**: `wan2_2`
- **FPS**: 16

### Model Files (HuggingFace)
```
Uses t2v_2_2 base models PLUS VACE module:

DeepBeepMeep/Wan2.2:
  Base (references t2v_2_2):
    - wan2.2_text2video_14B_high_*.safetensors
    - wan2.2_text2video_14B_low_*.safetensors

Module from Wan2.1:
  - vace_14B module (2.1 version)
```

### Key Features
- **VACE Module**: Uses Wan 2.1 VACE with 2.2 base
- **Control Net Weight**: Named "Vace", size 2
- **Extensive Guide Preprocessing**: 14 different control modes
- **Image Reference Options**: Landscape, People/Objects, Positioned Frames
- **Video Guide Outpainting**: [0,1]
- **Pad Guide Video**: Yes
- **Guide Inpaint Color**: 127.5
- **Forced Guide Mask Inputs**: Yes
- **V2I Switch**: Supported
- **VAE Upsampler**: [1,2]
- **Frame Range**: 17 minimum, steps of 4

### Default Settings
```json
{
  "guidance_phases": 2,
  "guidance_scale": 1,
  "guidance2_scale": 1,
  "flow_shift": 2,
  "switch_threshold": 875,
  "sliding_window_discard_last_frames": 0
}
```

### Guide Preprocessing Options (14 modes)
- `""` - None
- `"UV"` - Use Video
- `"PV"` - Pose Video
- `"DV"` - Depth Video
- `"SV"` - Segmentation Video
- `"LV"` - Line Video
- `"CV"` - Canny Video
- `"MV"` - Motion Video
- `"V"` - Use Vace raw format
- `"PDV"` - Pose+Depth Video
- `"PSV"` - Pose+Segmentation Video
- `"PLV"` - Pose+Line Video
- `"DSV"` - Depth+Segmentation Video
- `"DLV"` - Depth+Line Video
- `"SLV"` - Segmentation+Line Video

### Mask Preprocessing Options (11 modes)
- `""` - None
- `"A"` - Apply mask
- `"NA"` - Negative Apply
- `"XA"` - X Apply
- `"XNA"` - X Negative Apply
- `"YA"` - Y Apply
- `"YNA"` - Y Negative Apply
- `"WA"` - W Apply
- `"WNA"` - W Negative Apply
- `"ZA"` - Z Apply
- `"ZNA"` - Z Negative Apply

### Image Reference Choices
- **None** (`""`)
- **People / Objects** (`"I"`)
- **Landscape followed by People / Objects (if any)** (`"KI"`)
- **Positioned Frames followed by People / Objects (if any)** (`"FI"`)

### Image Prompt Types Allowed
`"TVL"` (Text, Video, Lora)

### Profiles Directory
`["wan_2_2"]`

### Code References
- VACE Check: [wan_handler.py#L8](file:///opt/wan2gp/Wan2GP/models/wan/wan_handler.py#L8) - `test_vace()`
- Config: [wan_handler.py#L496-L532](file:///opt/wan2gp/Wan2GP/models/wan/wan_handler.py#L496-L532)

---

## 8. Wan2.2 Multitalk 14B (i2v_2_2_multitalk)

### Model Identifiers
- **Architecture Code**: `i2v_2_2_multitalk`
- **Model Type String**: `"i2v_2_2_multitalk"`
- **Display Name**: "Wan2.2 Multitalk 14B"

### Specifications
- **Parameter Size**: 14B (14 billion parameters)
- **Primary Purpose**: Multi-person conversation videos (up to 2 people)
- **Parent Model**: `i2v_2_2`
- **Module**: `multitalk` (from Wan 2.1)
- **Release Info**: Wan 2.2 series (combines 2.1 Multitalk with 2.2 I2V)
- **Group**: `wan2_2`
- **FPS**: 25 (different from base i2v_2_2)
- **Visibility**: Hidden by default

### Model Files (HuggingFace)
```
Uses i2v_2_2 base models PLUS multitalk module:

DeepBeepMeep/Wan2.2:
  Base (references i2v_2_2):
    - wan2.2_image2video_14B_high_*.safetensors
    - wan2.2_image2video_14B_low_*.safetensors

Module from Wan2.1:
  - multitalk module
```

### Key Features
- **Multi-Speaker Support**: Up to 2 people in conversation
- **Audio Prompt Choices**: Enabled
- **Any Audio Prompt**: Yes
- **Audio Guidance**: Enabled
- **Audio Guidance Scale**: 4 (default)
- **Sliding Window Overlap**: 1 frame
- **Discard Last Frames**: 4
- **Sample Solver**: "euler" (default)

### Default Settings
```json
{
  "switch_threshold": 900,
  "guidance_scale": 3.5,
  "guidance2_scale": 3.5,
  "flow_shift": 5,
  "audio_guidance_scale": 4,
  "sliding_window_overlap": 1,
  "adaptive_switch": 1,
  "audio_prompt_type": "A"
}
```

### Image Prompt Types Allowed
`"SVL"` (Standard, Video, Lora)

### Profiles Directory
`["wan_2_2"]`

### Code References
- Multitalk Check: [wan_handler.py#L23](file:///opt/wan2gp/Wan2GP/models/wan/wan_handler.py#L23) - `test_multitalk()`
- Config: [wan_handler.py#L210-L213](file:///opt/wan2gp/Wan2GP/models/wan/wan_handler.py#L210-L213)

---

## Model Family Hierarchy

### Parent-Child Relationships

```
Wan2.2 Family Tree:

wan2_2 (Group)
├── 14B Models
│   ├── i2v_2_2 (Base I2V)
│   │   ├── i2v_2_2_svi2pro (SVI variant with LoRAs)
│   │   └── i2v_2_2_multitalk (Multitalk variant with module)
│   ├── t2v_2_2 (Base T2V)
│   │   └── vace_14B_2_2 (VACE variant with module)
│   └── ovi (10B dual-modal - video + audio)
└── 5B Models
    ├── ti2v_2_2 (Base Text+Image2Video)
    └── lucy_edit (Video editing variant)
```

### Equivalence Map (from code)
```python
models_eqv_map = {
    "i2v_2_2_svi2pro": "i2v_2_2",
    "t2v_2_2": "t2v",
    "vace_14B_2_2": "vace_14B"
}
```

### Compatibility Map (from code)
```python
models_comp_map = {
    "i2v_2_2": ["i2v_2_2_multitalk", "i2v_2_2_svi2pro"]
}
```

---

## Supported Model Types (Complete List)

From [wan_handler.py#L40-L43](file:///opt/wan2gp/Wan2GP/models/wan/wan_handler.py#L40-L43):

```python
def query_supported_types():
    return [
        # Wan 2.2 Models (8 total):
        "i2v_2_2",           # Image2Video 14B
        "i2v_2_2_multitalk", # Multitalk 14B
        "i2v_2_2_svi2pro",   # SVI 2 Pro 14B
        "t2v_2_2",           # Text2Video 14B
        "ti2v_2_2",          # TextImage2Video 5B
        "lucy_edit",         # Lucy Edit 5B
        "vace_14B_2_2",      # VACE 14B
        # ovi handled separately in ovi_handler.py
        
        # Wan 2.1 Models (included for reference):
        "multitalk", "infinitetalk", "fantasy",
        "vace_14B", "vace_multitalk_14B", "vace_standin_14B",
        "vace_lynx_14B", "vace_1.3B", "vace_ditto_14B",
        "t2v", "t2v_1.3B", "standin", "lynx_lite", "lynx",
        "phantom_1.3B", "phantom_14B", "recam_1.3B",
        "animate", "alpha", "alpha2", "alpha_lynx", "chrono_edit",
        "i2v", "flf2v_720p", "fun_inp_1.3B", "fun_inp",
        "mocha", "steadydancer", "wanmove", "scail"
    ]
```

---

## Model Classification Functions

### By Model Class

```python
# Image2Video Class (6 Wan2.2 models)
test_class_i2v():
    return base_model_type in [
        "i2v_2_2",
        "i2v_2_2_multitalk",
        "i2v_2_2_svi2pro",
        # ... plus 2.1 models
    ]

# Text2Video Class (2 Wan2.2 models)  
test_class_t2v():
    return base_model_type in [
        "t2v_2_2",
        # ... plus 2.1 models
    ]

# 5B Class (3 Wan2.2 models, including OVI)
test_wan_5B():
    return base_model_type in [
        "ti2v_2_2",
        "lucy_edit",
        # ovi uses ti2v_2_2 base
    ]

# I2V 2.2 Specific (3 Wan2.2 models)
test_i2v_2_2():
    return base_model_type in [
        "i2v_2_2",
        "i2v_2_2_multitalk",
        "i2v_2_2_svi2pro"
    ]

# SVI 2 Pro Specific (1 Wan2.2 model)
test_svi2pro():
    return base_model_type in ["i2v_2_2_svi2pro"]

# VACE Class (1 Wan2.2 model)
test_vace():
    return base_model_type in [
        "vace_14B_2_2",
        # ... plus 2.1 models
    ]

# Multitalk (1 Wan2.2 model)
test_multitalk():
    return base_model_type in [
        "i2v_2_2_multitalk",
        # ... plus 2.1 models
    ]
```

---

## Model Variants by JSON Files

### Available Variants (defaults folder)

```
Wan2.2 Base Models:
├── i2v_2_2.json                    # Standard Image2Video
├── i2v_2_2_Enhanced_Lightning_v2.json
├── i2v_2_2_Enhanced_Lightning_v2_svi2pro.json
├── i2v_2_2_multitalk.json          # Multitalk variant
├── i2v_2_2_svi2pro.json            # SVI 2 Pro variant
├── t2v_2_2.json                    # Standard Text2Video
├── ti2v_2_2.json                   # TextImage2Video 5B
├── ti2v_2_2_fastwan.json           # Fast variant
├── vace_14B_2_2.json               # VACE variant
├── vace_14B_cocktail_2_2.json      # VACE Cocktail
├── vace_14B_lightning_3p_2_2.json  # VACE Lightning
├── vace_fun_14B_2_2.json           # VACE Fun
├── vace_fun_14B_cocktail_2_2.json  # VACE Fun Cocktail
├── lucy_edit.json                  # Lucy Edit v1
├── lucy_edit_1_1.json              # Lucy Edit v1.1
├── lucy_edit_fastwan.json          # Lucy Edit Fast
├── lucy_edit_fastwan_1_1.json      # Lucy Edit Fast v1.1
├── ovi.json                        # OVI v1.0
├── ovi_1_1.json                    # OVI v1.1
├── ovi_1_1_10s.json                # OVI v1.1 10s
├── ovi_1_1_10s_fastwan.json        # OVI v1.1 10s Fast
├── ovi_1_1_fastwan.json            # OVI v1.1 Fast
└── ovi_fastwan.json                # OVI Fast
```

**Total Wan2.2 Variants**: 26+ (including all the enhanced/fast/cocktail versions)

---

## Profiles Directory Structure

Each model uses specific profile directories for settings:

```
/opt/wan2gp/Wan2GP/profiles/
├── wan_2_2/              # i2v_2_2, t2v_2_2, vace_14B_2_2, i2v_2_2_svi2pro, i2v_2_2_multitalk
├── wan_2_2_5B/           # ti2v_2_2, lucy_edit
└── wan_2_2_ovi/          # ovi
```

---

## Lora Directory Structure

Each model class uses different LoRA directories:

```
lora_root/
├── wan/                  # t2v_2_2, vace_14B_2_2
├── wan_5B/               # ti2v_2_2, lucy_edit, ovi
└── wan_i2v/              # i2v_2_2* (all i2v_2_2 variants except when test_i2v_2_2 is true)
```

Note: `i2v_2_2` variants use `wan/` directory (not `wan_i2v/`) due to `test_i2v_2_2()` check in code.

---

## Common Features Across All Wan2.2 Models

### Shared Capabilities
1. **Flow Shift**: All models support flow shift
2. **CFG Zero**: Classifier-free guidance zero enabled
3. **CFG Star**: CFG star enabled
4. **Adaptive Projected Guidance**: All models support this
5. **Skip Layer Guidance**: Enabled for all
6. **Self Refiner**: All models support self-refinement
7. **Sliding Window**: All models support sliding window (except OVI has locked size)
8. **MAG Cache**: Magnitude cache enabled for all

### Sample Solvers
All Wan2.2 models support:
- `"unipc"`
- `"euler"`
- `"dpm++"`
- `"flowmatch causvid"` (causvid)
- `"lcm + ltx"` (lcm)

### Text Encoder
All models use the same text encoder:
```
DeepBeepMeep/Wan2.1/umt5-xxl/:
  - models_t5_umt5-xxl-enc-bf16.safetensors
  - models_t5_umt5-xxl-enc-quanto_int8.safetensors
```

---

## Model Parameter Comparison

| Model | Parameters | VAE Block Size | FPS | Window Size | Overlap | Notes |
|-------|-----------|----------------|-----|-------------|---------|-------|
| i2v_2_2 | 14B | 16 | 16 | Variable | 1 | Base I2V |
| i2v_2_2_svi2pro | 14B | 16 | 16 | 81 (locked) | 4 | Extended video |
| i2v_2_2_multitalk | 14B | 16 | 25 | Variable | 1 | 2-person talk |
| t2v_2_2 | 14B | 16 | 16 | Variable | Variable | Base T2V |
| vace_14B_2_2 | 14B | 16 | 16 | Variable | Variable | Control modes |
| ti2v_2_2 | 5B | 32 | 24 | 121 (locked) | 1 | Text+Image input |
| lucy_edit | 5B | 32 | 24 | 121 | 1 | Video editing |
| ovi | 10B | 32 | 24 | 121 (locked) | 1 | Audio+Video |

---

## Release Timeline & Versions

### Known Versions
- **Lucy Edit**: v1.0, v1.1
- **OVI**: v1.0, v1.1
- **SVI**: v2.0 Pro
- **Base Models**: Standard 2.2 release

### Enhanced Variants
- Lightning versions (3-step distilled)
- FastWan versions (optimized)
- Cocktail versions (mixed capabilities)

---

## Summary Statistics

- **Total Wan2.2 Base Architectures**: 8
  1. i2v_2_2
  2. i2v_2_2_svi2pro
  3. i2v_2_2_multitalk
  4. t2v_2_2
  5. vace_14B_2_2
  6. ti2v_2_2
  7. lucy_edit
  8. ovi

- **14B Models**: 5 (i2v_2_2, i2v_2_2_svi2pro, i2v_2_2_multitalk, t2v_2_2, vace_14B_2_2)
- **10B Models**: 1 (ovi)
- **5B Models**: 2 (ti2v_2_2, lucy_edit)

- **Image2Video Models**: 3 (i2v_2_2, i2v_2_2_svi2pro, i2v_2_2_multitalk)
- **Text2Video Models**: 1 (t2v_2_2)
- **Hybrid Models**: 1 (ti2v_2_2)
- **Specialized Models**: 3 (lucy_edit, ovi, vace_14B_2_2)

- **Models with Dual Architecture (URLs + URLs2)**: 4 (i2v_2_2, t2v_2_2, vace_14B_2_2, ovi)
- **Models with Audio Support**: 2 (i2v_2_2_multitalk, ovi)
- **Models with LoRA Support**: 1 (i2v_2_2_svi2pro)

---

## References

### Source Code Files
- [wan_handler.py](file:///opt/wan2gp/Wan2GP/models/wan/wan_handler.py) - Main model handler
- [ovi_handler.py](file:///opt/wan2gp/Wan2GP/models/wan/ovi_handler.py) - OVI-specific handler

### Model Definition Files
- `/opt/wan2gp/Wan2GP/defaults/*.json` - Individual model configurations

### HuggingFace Repositories
- `DeepBeepMeep/Wan2.2` - Primary Wan2.2 models
- `DeepBeepMeep/Wan2.1` - Shared components (VAE, text encoder, modules)

---

## Notes

1. **Module System**: Some 2.2 models (vace_14B_2_2, i2v_2_2_multitalk) use modules from Wan 2.1
2. **Partial Support**: VACE 2.2 currently uses 2.1 VACE module (partial support noted in code)
3. **Hidden Models**: i2v_2_2_multitalk is marked as hidden (`"visible": false`)
4. **OVI Unique**: Only model that outputs both video AND audio
5. **SVI Unique**: Only model with "potentially unlimited" video generation capability
6. **Lucy Edit Unique**: Only dedicated video editing model with instruction prompts

---

*Document generated from codebase analysis of Wan2GP v2.x*  
*Last verified: February 8, 2026*
