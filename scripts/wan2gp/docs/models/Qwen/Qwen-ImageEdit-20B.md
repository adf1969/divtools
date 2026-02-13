# Qwen Image Edit 20B

**Model Family:** Qwen Image  
**Parameter Count:** 20 Billion  
**Version:** 2511 (December 2025)  
**Wan2GP Support:** v10.70+

---

## General Description

The Qwen Image Edit family represents state-of-the-art diffusion models for image editing and generation, developed by Alibaba's Qwen team. These models excel at precise image manipulation tasks including inpainting, outpainting, recoloring, and structure-preserving edits. Unlike traditional text-to-image models, Qwen Image Edit specializes in conditional image generation where existing visual content guides the output.

### Model Variants

1. **qwen_image_20B** - Base text-to-image generation model
2. **qwen_image_edit_20B** - Basic inpainting with reference image support
3. **qwen_image_edit_plus_20B** - Advanced editing with control image preprocessing ⭐ **Recommended**
4. **qwen_image_edit_plus2_20B** - Alias of edit_plus (functionally identical)
5. **qwen_image_layered_20B** - Specialized layered composition model

### Best Use Cases

**Qwen Image Edit Plus (Recommended):**
- **Precise Inpainting** - Remove/replace specific objects with mask control
- **Pose-Guided Editing** - Transfer human poses to new characters
- **Depth-Preserving Edits** - Maintain 3D structure while changing content
- **Style Transfers** - Recolor images while preserving structure
- **Character Consistency** - Inject reference characters into new scenes
- **Architectural Rendering** - Edit building designs with depth preservation

**When to Use Each Variant:**
- **qwen_image_20B** → Standard text-to-image generation
- **qwen_image_edit_20B** → Basic inpainting without advanced controls
- **qwen_image_edit_plus_20B** → Professional editing with full control suite
- **qwen_image_layered_20B** → Multi-layer composition workflows

---

## Release Information

**Release Date:** December 2025 (2511 version)  
**Text Encoder:** Qwen2.5-VL-7B-Instruct  
**Architecture:** Diffusion-based image generation with conditional controls  
**Quantization:** bf16 (default), int8 (quanto)

**Related Models:**
- Qwen2.5-VL (Vision-Language model family)
- Qwen Image generation models
- VACE pre-processing modules (for image/video control)

---

## LoRA Ecosystem

### Available LoRA Categories

| Category | Approximate Count | Description |
|----------|-------------------|-------------|
| **Character** | 150-200+ | Anime characters, celebrities, custom OCs |
| **Style** | 100-150+ | Art styles, anime styles, photography styles |
| **Camera/Util** | 50-75+ | Camera angles, lighting, composition utilities |

*Note: LoRA counts are approximate and growing. Check the Wan2GP LoRA manager for current catalog.*

**Popular LoRA Types for Qwen:**
- **Face LoRAs** - Celebrity/character faces for character injection
- **Art Style LoRAs** - Anime, oil painting, watercolor, photography
- **Detail Enhancers** - Quality boosters, detail refinement
- **Composition LoRAs** - Specific camera angles, framing

---

## Control Image Process Options

Available **only** for `qwen_image_edit_plus_20B` and `qwen_image_edit_plus2_20B`.

### Overview

Control Image Processing extracts structural information from a reference image (control image) to guide generation while allowing the prompt to define the content. Think of it as providing a "structure blueprint" that the model follows.

### Available Processing Modes

| Mode | Code | When to Use | Example Use Case |
|------|------|-------------|------------------|
| **None** | `""` | No structural guidance needed | Standard text-to-image generation |
| **Transfer Human Pose** | `PV` | Match character posing/positioning | "Same pose, different character" edits |
| **Transfer Depth** | `DV` | Preserve 3D spatial structure | Architectural redesigns, scene relighting |
| **Transfer Shapes** | `SV` | Follow edge/outline structure | Line art to full render, sketch refinement |
| **Recolorize** | `CV` | Match color distribution | Style transfer, color grading |
| **Qwen Raw Format** | `V` | Direct image conditioning | Special preprocessing workflows |

### Combined Processing (Advanced)

| Mode | Description | Use Case |
|------|-------------|----------|
| **DSV** | Depth + Shapes | Complex architectural edits preserving both 3D and 2D structure |
| **DLV** | Depth + Flow | Motion-aware depth preservation |
| **SLV** | Shapes + Flow | Dynamic scene editing with motion guidance |

### Technical Details

Each mode extracts different structural information:

- **Pose (`PV`)** - OpenPose skeleton detection for human figures
- **Depth (`DV`)** - Depth map estimation (MiDaS or similar)
- **Shapes (`SV`)** - Scribble/edge detection (simplified line art)
- **Canny (`EV`)** - Canny edge detection (sharper edges than shapes)
- **Flow (`LV`)** - Optical flow (motion vectors)
- **Gray (`CV`)** - Grayscale/luminance information
- **Identity (`U`)** - Unprocessed image (raw format)

**Processing Pipeline:** Control Image → Preprocessing Module → Structural Guidance → Generation with Prompt

---

## Area Processed (Masking)

Controls which regions of the image are modified during editing.

### Basic Options

| Option | Description | When to Use |
|--------|-------------|-------------|
| **Whole Frame** | Process entire image uniformly | Full-image style transfers, recoloring, no selective edits |
| **Masked Area** | Only modify pixels within mask | Object removal, selective inpainting, localized edits |

### Advanced Masking Modes

| Code | Mode | Description |
|------|------|-------------|
| `A` | Masked Area | Modify only inside mask |
| `NA` | Non Masked Area | Modify only outside mask (inverse masking) |
| `XA` | Masked + Inpaint Rest | Edit mask area, inpaint remainder |
| `XNA` | Non-Masked + Inpaint Rest | Edit outside mask, inpaint inside |
| `YA` | Masked + Depth Rest | Edit mask, apply depth guidance to rest |
| `YNA` | Non-Masked + Depth Rest | Edit outside mask, depth-process inside |
| `WA` | Masked + Shapes Rest | Edit mask, apply shape guidance to rest |
| `WNA` | Non-Masked + Shapes Rest | Edit outside mask, shape-process inside |
| `ZA` | Masked + Flow Rest | Edit mask, apply flow to rest |
| `ZNA` | Non-Masked + Flow Rest | Edit outside mask, flow-process inside |

### Masking Strength

**Feature:** Masking Strength is **always enabled** for Qwen Image Edit Plus models.

**Range:** 0.0 to 1.0  
**Effect:** Controls how many denoising steps the mask is active  
**Formula:** `active_steps = ceil(total_steps × strength)`

**Example:**
- `strength = 1.0` → Mask active for all 30 steps
- `strength = 0.5` → Mask active for first 15 steps, then full-frame denoising
- `strength = 0.3` → Mask active for first 9 steps

**Use Cases:**
- **High Strength (0.8-1.0)** → Sharp mask boundaries, precise object removal
- **Medium Strength (0.5-0.7)** → Blended edges, natural transitions
- **Low Strength (0.2-0.4)** → Subtle guidance, heavy blending with surroundings

---

## Inject Reference Images

Reference image injection allows you to insert people, objects, or scenes from reference photos into your generated image.

### Available Options

| Option | Code | Description |
|--------|------|-------------|
| **None** | `""` | No reference injection |
| **Conditional Image is first Main Subject / Landscape and may be followed by People / Objects** | `KI` | First ref = main scene/subject, additional refs = characters/objects to inject |
| **Conditional Images are People / Objects** | `I` | All references are people/objects to inject into scene |

### How It Works

**Mode: KI (Main Subject + Objects)**

```
Reference Images:
  1. landscape.jpg  ← Main subject/scene (K)
  2. person1.jpg    ← Person to inject (I)
  3. object1.jpg    ← Object to inject (I)

Prompt: "A futuristic cityscape with a warrior standing guard"

Result: Cityscape from landscape.jpg as base structure,
        person1.jpg character placed as the warrior,
        object1.jpg added as props
```

**Mode: I (Objects Only)**

```
Reference Images:
  1. character_a.jpg ← Character to inject
  2. character_b.jpg ← Another character
  3. prop.jpg        ← Object to inject

Prompt: "Two friends having coffee in a cafe"

Result: Characters from ref images placed in generated cafe scene
```

### Best Practices

✅ **DO:**
- Use high-quality reference images with clear subjects
- Match lighting/perspective between references when possible
- Use consistent art styles across references
- Place most important reference first (in KI mode)

❌ **DON'T:**
- Mix drastically different art styles (photo + anime)
- Use cluttered backgrounds in reference images (use background removal)
- Provide too many references (3-5 max recommended)

---

## Automatic Removal of Backgrounds

**Feature:** Automatically segment and remove backgrounds from reference images containing people/objects.

### Options

| Value | Label | When to Use |
|-------|-------|-------------|
| `0` | Keep Backgrounds behind all Reference Images | Reference images have matching/compatible backgrounds |
| `1` | Remove Backgrounds only behind People / Objects except main Subject / Landscape | Mixed references: clean landscape + character photos with backgrounds |

### How It Works

**Enabled (1):**
1. First reference image (if `K` mode): Background preserved
2. Additional reference images: Backgrounds automatically segmented and removed
3. Only foreground subjects (people/objects) are injected
4. Generated scene fills in natural background around injected elements

**Use Case Example:**
```
Reference 1 (K): Clean mountain landscape
Reference 2 (I): Photo of person with busy city background
Reference 3 (I): Character art with white background

With background removal = 1:
  → Mountain landscape preserved
  → Person extracted from city photo (city removed)
  → Character extracted from white bg
  → Both placed naturally in mountain scene
```

**Technical:** Uses segmentation model to detect foreground subjects and create alpha masks.

---

## Multi-Line Prompts

Qwen Image Edit supports multi-line prompts with special syntax for batch generation and macro variables.

### Basic Multi-Line Behavior

**Format:**
```
Prompt line 1
Prompt line 2
Prompt line 3
```

**Result:** Each line generates a separate image (when multi-prompt generation mode is enabled).

### Special Line Types

| Prefix | Type | Behavior | Example |
|--------|------|----------|---------|
| (none) | Prompt | Generates image | `A beautiful sunset` |
| `#` | Comment | Ignored, not processed | `# This is a test` |
| `!` | Macro | Variable definition | `! {style}=anime, high quality` |

---

## "! line" Macros (Variable System)

Macros allow you to define reusable variables that can be referenced in subsequent prompts.

### Syntax

```
! {variable_name}=value : {variable_name2}=value2 : {variable_name3}=value3
```

**Rules:**
- Starts with `!` followed by space
- Variable format: `{name}=value`
- Multiple variables separated by `:`
- Variable names wrapped in `{}`

### Usage Example

**Input:**
```
! {style}=anime, high quality, masterpiece : {lighting}=dramatic lighting, golden hour
A beautiful landscape, {style}, {lighting}
A portrait of a warrior, {style}, {lighting}
A castle on a hill, {style}, {lighting}
```

**Expands to:**
```
A beautiful landscape, anime, high quality, masterpiece, dramatic lighting, golden hour
A portrait of a warrior, anime, high quality, masterpiece, dramatic lighting, golden hour
A castle on a hill, anime, high quality, masterpiece, dramatic lighting, golden hour
```

### Multi-Value Variables

Variables can contain multiple options (newline-separated in Prompt Wizard):

**Definition:**
```
! {character}=young woman
old wizard
fierce warrior
```

**Result:** Variable becomes: `"young woman","old wizard","fierce warrior"`

**Use Case:** Random selection or iteration through character types

### Advanced Macro Patterns

**Quality Presets:**
```
! {quality}=masterpiece, best quality, highly detailed : {negative}=blurry, low quality, artifacts
```

**Style Variations:**
```
! {anime}=anime style, cell shaded : {realistic}=photorealistic, ultrarealistic, 8k
```

**Composition Helpers:**
```
! {portrait}=portrait, face focus, upper body : {landscape}=wide shot, scenic, environment
```

---

## Advanced Mode Settings

Advanced Mode reveals additional controls for fine-tuning generation behavior.

### General Tab

| Setting | Range/Options | Description |
|---------|---------------|-------------|
| **Guidance Scale (CFG)** | 1.0 - 20.0 (default: 4.0) | Higher = stronger prompt adherence, lower = more creative freedom |
| **Sample Solver/Scheduler** | `default`, `lightning` | Sampling algorithm (lightning = faster but less quality) |
| **Denoising Strength** | 0.0 - 1.0 (default: 1.0) | Only affects Masked Denoising mode (mode 0) |
| **Negative Prompt** | Text | Elements to avoid in generation |
| **Num of generated videos per prompt** | 1-10+ | Batch size for parallel generation |

### LoRAs Tab

- **LoRA Selection** - Choose character/style/utility LoRAs
- **LoRA Multipliers** - Strength for each LoRA (format: `1.0 0.8 0.5`)
- **LoRA Presets** - Save/load common LoRA combinations

### Post-Processing Tab

- **Upscaling** - Post-generation resolution increase
- **Face Restoration** - Fix/enhance faces in output
- **Color Correction** - Adjust final color balance

### Quality Tab

- **Output Format** - JPG, PNG quality settings
- **Codec Selection** - For video outputs (if applicable)

### Misc Tab

- **Output Filename** - Custom filename templates (see General Documentation)
- **Output Directory** - Save location
- **Metadata Embedding** - Include generation settings in output

---

## Inpainting Methods

All Qwen Image Edit models support multiple inpainting techniques with different quality/speed tradeoffs.

### Available Methods

#### For `qwen_image_edit_20B`:
1. **LanPaint (2 steps)** - ~2x slower, easy tasks (simple object removal)
2. **LanPaint (5 steps)** - ~5x slower, medium tasks (complex object removal)
3. **LanPaint (10 steps)** - ~10x slower, hard tasks (large area inpainting)
4. **LanPaint (15 steps)** - ~15x slower, very hard tasks (complex scene reconstruction)

#### For `qwen_image_edit_plus_20B` and `qwen_image_edit_plus2_20B`:
1. **Lora Inpainting** (mode 1) ⭐ **Default** - Complete replacement, inpainted area independent of masked content
2. **Masked Denoising** (mode 0) - Partial preservation, may reuse some masked content
3. **LanPaint (2/5/10/15 steps)** (modes 2-5) - Same as basic edit model

### Method Selection Guide

| Task | Recommended Method | Reasoning |
|------|-------------------|-----------|
| Object removal (simple) | Lora Inpainting or LanPaint 2 | Fast, clean replacement |
| Object removal (complex background) | LanPaint 10-15 | Better context understanding |
| Content-aware fill | Masked Denoising | Preserves some original texture |
| Complete replacement | Lora Inpainting | No blending with masked area |
| Style-consistent inpainting | Lora Inpainting + Style LoRA | LoRA applies to inpainted region |

### Important Restrictions

⚠️ **LanPaint Modes Override Settings:**
- When using LanPaint (modes 2-5), both **Denoising Strength** and **Masking Strength** are forced to 1.0
- Custom strength values will be ignored

⚠️ **Denoising Strength Only Affects Mode 0:**
- Denoising Strength setting is **ignored** in all modes except Masked Denoising (mode 0)
- Lora Inpainting (mode 1) always uses full denoising

---

## Outpainting Support

Qwen Edit models support outpainting (extending image beyond original boundaries) with intelligent padding removal.

### How to Use Outpainting

1. **Set Outpainting Dimensions** (Advanced > Misc)
   - Define how many pixels to extend (left/right/top/bottom)
2. **Choose Inpainting Method**
   - Recommended: Masked Denoising (mode 0) or LanPaint
3. **Automatic Prompt Injection**
   - When using Masked Denoising + outpainting, system automatically adds:
     > "Remove the red paddings on the sides and show what's behind them."

### Best Practices

✅ **DO:**
- Use symmetric padding when possible (e.g., 256px on all sides)
- Provide detailed prompts about what should appear in extended areas
- Use depth/shape control to maintain perspective consistency

❌ **DON'T:**
- Extend more than 50% of original dimension (quality degrades)
- Mix outpainting with heavy masking (confusing for model)

---

## Tips & Tricks

### Character Consistency Workflow

**Goal:** Same character in multiple scenes

**Steps:**
1. Generate reference image of character (or use existing)
2. Enable "Inject Reference Images" mode `I`
3. Upload character image
4. Enable "Remove Backgrounds" if character has busy background
5. Use varied prompts with consistent style tags
6. Optionally use character LoRA for better consistency

**Example:**
```
Reference: character_portrait.jpg (with background removal=1)
Prompts:
  The character walking through a forest, {style}
  The character sitting in a cafe, {style}
  The character fighting a dragon, {style}
```

### Depth-Preserving Scene Edits

**Goal:** Change scene content while keeping spatial layout

**Steps:**
1. Upload original scene as Control Image
2. Set Control Image Process to "Transfer Depth" (DV)
3. Use detailed prompt describing new content
4. Set Guidance Scale higher (6-8) for strong depth adherence

**Example:**
```
Control Image: modern_office.jpg (depth extracted)
Prompt: A medieval throne room, stone walls, torches, fantasy
Result: Office layout/depth → Applied to medieval setting
```

### Style Transfer with Structure Preservation

**Goal:** Change art style while keeping composition

**Steps:**
1. Upload original image as Control Image
2. Set Control Image Process to "Transfer Shapes" (SV)
3. Add style LoRA or detailed style prompt
4. Adjust CFG to balance structure vs. style freedom

**Example:**
```
Control Image: photo_portrait.jpg
Process: Transfer Shapes
LoRA: anime_style_v3.safetensors (strength: 1.0)
Prompt: Anime character portrait, vibrant colors, cel shaded
```

---

## Common Issues & Solutions

### Issue: Blurry Inpainted Areas

**Causes:**
- Low inference steps
- Masking strength too low
- Insufficient prompt detail

**Solutions:**
- Increase inference steps to 30-50
- Set masking strength to 0.8-1.0
- Add quality tags: "highly detailed, sharp focus"
- Use higher CFG (6-8)

### Issue: Inpainted Area Doesn't Match Surroundings

**Causes:**
- Wrong inpainting method
- Denoising strength too high (mode 0)
- No context in prompt

**Solutions:**
- Switch to Masked Denoising (mode 0) for blending
- Reduce denoising strength to 0.6-0.8
- Describe surroundings in prompt: "seamlessly blended with original background"

### Issue: Reference Character Not Appearing

**Causes:**
- Background removal not enabled
- Prompt doesn't mention character
- CFG too low

**Solutions:**
- Enable background removal for cleaner extraction
- Explicitly describe character in prompt
- Increase CFG to 6-8 for stronger conditioning
- Check that reference image mode is set correctly (I or KI)

### Issue: Control Image Not Affecting Generation

**Causes:**
- Control process set to None
- CFG too low
- Prompt strongly contradicts structure

**Solutions:**
- Verify control process mode is selected (PV/DV/SV/etc.)
- Increase CFG to strengthen control influence
- Align prompt with control structure
- Check that control image uploaded correctly

---

## Prompting Guide

**NOTE:** The comprehensive Prompting Guide for Qwen Image Edit has been moved to a dedicated file for better organization and LLM-friendly formatting.

**See:** [Qwen-ImageEdit-20B-PromptGuide.md](Qwen-ImageEdit-20B-PromptGuide.md)

The Prompting Guide covers:
- Positive Prompt Writing (5 key practices)
- Negative Prompt Writing (5 key practices)
- Control Image Techniques (Pose, Depth, Shape transfer)
- Character and People Editing best practices
- Full example prompts with settings
- Settings Reference table
- Control Image Process Types reference

This separate guide is designed to be fed to LLMs for programmatic prompt generation, while keeping the main technical documentation focused on model configuration and operation.

---

## Code References

**Key Implementation Files:**
- `models/qwen/qwen_handler.py` - Model definitions and configurations
- `models/qwen/qwen_main.py` - Model loading and factory
- `models/qwen/pipeline_qwenimage.py` - Generation pipeline
- `shared/utils/vace_preprocessor.py` - Control image preprocessing
- `wgp.py` (lines 9380-9600) - UI implementation and controls

**Process Type Mappings:**
```python
{
    "P": "pose",      # OpenPose detection
    "D": "depth",     # Depth map extraction
    "S": "scribble",  # Shape/edge detection
    "E": "canny",     # Canny edge detection
    "L": "flow",      # Optical flow
    "C": "gray",      # Grayscale/recolorization
    "M": "inpaint",   # Inpainting mask
    "U": "identity",  # Unprocessed/raw
}
```

---

*Documentation Version: 1.0*  
*Last Updated: 2/8/2026 5:00:00 PM CST*  
*Wan2GP Version: 10.70*
