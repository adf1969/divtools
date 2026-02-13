# Qwen Image Edit - Prompting Guide
# Last Updated: 2/8/2026 10:00:00 AM CST

**Model:** Qwen Image Edit 20B  
**Purpose:** Guide for writing effective prompts for image editing and generation  
**Target Audience:** LLMs, users generating prompts programmatically

---

## Quick Reference

**Template for Effective Prompts:**

```
Positive Prompt:
[Main edit action], [subject/object description], [style/quality descriptors],
[environmental context], [specific visual properties]

Control Image Process:
[None / Pose Transfer / Depth Transfer / Recolorize / etc.]

Negative Prompt:
[quality issues], [unwanted artifacts], [things to avoid], [visual problems]

Settings:
- guidance_scale: 6.0-8.0 (higher = more control adherence)
- steps: 30-50 (more steps = better quality)
- control strength: 0.7-1.0 (if using control process)
```

---

## Positive Prompt Writing

**Purpose:** Describe what you want to appear in the edited/generated image.

**5 Key Practices:**

1. **Be Specific About Edits**
   - Specify what should change: `"replace the background with a beach at sunset"`
   - Describe the replacement content clearly: `"sandy beach, sea, warm orange sky, golden light"`
   - Example: `"replace the person's shirt with a professional business suit, navy blue, crisp white collar"`
   - Avoid vague edits; clarity improves results

2. **Include Visual Details**
   - Subject appearance: `"a person with long curly hair, warm smile, light brown eyes"`
   - Clothing: `"wearing a vintage denim jacket, red scarf"`
   - Style: `"cinematic lighting, professional photography, sharp details"`
   - Atmosphere: `"natural outdoor setting, diffused sunlight, soft shadows"`

3. **Use Reference Image Context**
   - When using "Conditional Image is first Main Subject": `"keep the person's face, change background to garden"`
   - When using "Conditional Images are People/Objects": `"add the person from reference into a busy city street scene"`
   - Alignment between reference image and prompt yields better results

4. **Describe Editing Operations**
   - Inpainting: `"inpaint the masked area with a blue door frame"`
   - Recoloring: `"recolor the object to a deep burgundy red while maintaining texture"`
   - Depth transfer: `"apply depth map to preserve 3D structure"`
   - Pose transfer: `"transfer human pose to standing position with arms raised"`

5. **Specify Quality and Style**
   - Quality: `"high quality, detailed, 4K, award-winning photography"`
   - Style: `"photorealistic, artistic, contemporary, vintage film"`
   - Technical: `"sharp focus, proper lighting, well-composed"`

---

## Negative Prompt Writing

**Purpose:** Specify what you want to avoid or prevent in the edited image.

**5 Key Practices:**

1. **Avoid Common Artifacts**
   - `"blur, distortion, pixelation, artifacts"`
   - `"weird hands, deformed fingers, extra limbs"`
   - `"unnatural skin texture, uncanny valley"`
   - `"visible seams, discontinuities at mask boundaries"`

2. **Prevent Unwanted Changes**
   - `"don't change the background"`
   - `"keep original colors intact"`
   - `"preserve facial features"`
   - `"maintain body proportions"`

3. **Avoid Quality Issues**
   - `"low quality, low resolution, compressed"`
   - `"oversaturated, undersaturated, color noise"`
   - `"poor lighting, harsh shadows, unnatural"`
   - `"blotchy, inconsistent textures"`

4. **Control Unwanted Content**
   - `"no text, no watermarks"`
   - `"no extra people, no unwanted objects"`
   - `"no visible mask edges"`
   - `"no oversimplified or cartoon-like appearance"`

5. **Common Effective Phrases**
   - `"worst quality, low quality, blurry, distorted, artifacts, weird hands, ugly, deformed faces"`
   - `"visible seams, discontinuities, color bleeding, inconsistent lighting"`

---

## Control Image Techniques

**When Using Pose Transfer:**
- Describe the desired pose: `"standing with hands on hips, confident pose"`
- Reference the original: `"transfer pose from reference, change clothing"`
- Combine with appearance: `"change to athletic wear, match the new pose style"`

**When Using Depth Transfer:**
- Prompt should complement structure: `"maintain 3D depth, realistic lighting based on depth map"`
- Describe surface properties: `"metallic finish, matte texture, glass-like transparency"`
- Consider shadows: `"natural shadows matching 3D structure"`

**When Using Shape/Edge Transfer:**
- Follow structural outline: `"fill shape with detailed architectural elements"`
- Add style details: `"ornate, baroque, minimalist"` (depending on desired style)
- Example: `"shape outline of building: fill with Victorian mansion, ornate details, stone facade"`

---

## Character and People Editing

**Best Practices for Person Editing:**

1. **Describe Appearance Changes**
   - `"change hairstyle to wavy shoulder-length, darker brown color"`
   - `"add glasses, round frames, subtle style"`
   - `"change age appearance to look younger/older"`
   - `"adjust smile intensity, make it more genuine"`

2. **Clothing Edits**
   - `"replace current outfit with elegant evening gown, flowing fabric, gold accents"`
   - `"change to professional business attire, navy blazer, white shirt"`
   - `"add accessories: matching belt, leather shoes, watch"`

3. **Environmental Integration**
   - `"place person in a busy marketplace, realistic lighting from surroundings"`
   - `"integrate into a nature scene, ensure shadows match sunlight direction"`
   - `"add person to indoor setting with correct perspective overlap"`

4. **Maintaining Consistency**
   - `"keep facial features recognizable, only change styling elements"`
   - `"preserve natural skin tone while adjusting makeup"`
   - `"maintain body proportions during clothing changes"`

---

## Example Full Prompts

**Example 1 - Person Clothing Edit:**
```
Positive: "Replace person's clothing with elegant professional black suit, white dress shirt, 
burgundy tie, maintain same pose and facial features, photorealistic style, natural professional lighting"

Control Process: None

Negative: "weird hands, distorted body, blurry fabric, unnatural proportions, 
visible seams where clothing meets skin"

Settings: guidance_scale=7.0, steps=40
```

**Example 2 - Background Edit with Person:**
```
Positive: "Keep person's appearance and pose, change background to a modern office, 
large windows with city view, professional lighting, realistic integration of person into office space"

Control Process: Depth (to preserve 3D structure)

Negative: "floating person, incorrect shadow direction, person not grounded, 
blurry office details, inconsistent lighting, visible cutting edges"

Settings: guidance_scale=7.5, steps=45
```

**Example 3 - Pose + Clothing Transfer:**
```
Positive: "Transfer pose from reference image, change clothing to casual summer outfit 
with white t-shirt and denim shorts, maintain facial features, outdoor bright daylight setting"

Control Process: Pose Transfer + Transfer Depth

Negative: "unnatural pose, distorted limbs, weird joints, inconsistent lighting with pose, 
artificial appearance, color bleeding at edges"

Settings: guidance_scale=7.0, steps=40
```

---

## Settings Reference

| Setting | Range | Purpose |
|---------|-------|---------|
| guidance_scale | 6.0-8.0 | Strength of prompt adherence (higher = more literal) |
| steps | 30-50 | Generation quality (more steps = higher quality, slower) |
| control_strength | 0.7-1.0 | Control image influence (if applicable) |
| cfg_scale | 6.0-8.0 | Additional guidance control |

---

## Control Image Process Types

| Abbreviation | Process | Usage |
|--------------|---------|-------|
| P | Pose Transfer | Transfer human pose from reference |
| D | Depth Transfer | Preserve 3D structure/depth |
| S | Scribble/Shape | Transfer shape or edge structure |
| E | Canny Edge | Edge-based control |
| L | Optical Flow | Motion/flow control |
| C | Grayscale/Recolor | Color and tone control |
| M | Inpainting Mask | Mask-based inpainting |
| U | Unprocessed/Raw | Use reference image as-is |

---

## Multi-Angle Prompt Helper

**Type:** Built-in Wan2GP Plugin  
**Purpose:** Generate multi-angle camera prompts with precise degree and distance specifications  
**Best For:** Creating multi-view compositions, 360-degree views, character sheets, product showcase

### What It Does

The Multi-Angle Prompt Helper is a Wan2GP plugin that generates structured prompts with specific camera angles and distances for the Qwen Image Edit model. It includes a UI panel under the LoRA multiplier with Builder, Presets, and Batch modes.

**Trigger Token:** `<sks>`

**Fixed Parameters:**
- **8 Azimuth angles:** 0° (front), 45°, 90° (right), 135°, 180° (back), 225°, 270° (left), 315°
- **4 Elevation levels:** -30° (low-angle), 0° (eye-level), 30° (elevated), 60° (high-angle)
- **3 Distance scales:** ×0.6 (close-up), ×1.0 (medium), ×1.8 (wide)
- **Total combinations:** 96 possible poses

### Syntax

```
<sks> [azimuth angle] [elevation angle] [distance scale]
```

**Examples:**
- `<sks> front view (0°) eye-level shot (0°) medium shot (×1.0)` - Reference pose
- `<sks> right side view (90°) elevated shot (30°) wide shot (×1.8)` - Right side, elevated, wide
- `<sks> back view (180°) high-angle shot (60°) close-up (×0.6)` - Back view, high angle, close

### Using the Helper in Wan2GP

**Access:** Look for "Multi-Angle Prompt Helper" accordion panel under LoRA multipliers

**Three Modes:**

1. **Builder Tab**
   - Select Azimuth, Elevation, and Distance from dropdowns
   - Instantly generates single prompt
   - Perfect for trying specific angles

2. **Presets Tab (96)**
   - Browse all 96 possible angle combinations
   - Filter by typing in the dropdown
   - Reference pose: `<sks> front view (0°) eye-level shot (0°) medium shot (×1.0)`

3. **Batch Tab**
   - Generate multiple prompts at once
   - Modes:
     - **8-view sweep** - All azimuth angles at same elevation + distance
     - **4-elevation sweep** - All elevation levels at same azimuth + distance
     - **3-distance sweep** - All distances at same azimuth + elevation
     - **All 96 prompts** - Generate all possible combinations
   - Set base azimuth, elevation, distance for sweep operations

**Additional Options:**
- **Include `<sks>` trigger token** - Toggle whether to include the trigger token
- **Apply mode** - Append new prompts or Replace existing prompts
- **Blank lines between** - Control spacing between multiple prompts (1-3 lines)

### Integration with Prompts

**Recommended Workflow:**

1. Open Multi-Angle Prompt Helper accordion
2. Choose Builder, Presets, or Batch mode
3. Generate prompts
4. Click "Apply to Prompts box" to insert into main prompt field

**Example: 8-View Character Showcase**
```
Builder base: azimuth=front view (0°), elevation=eye-level (0°), distance=medium (×1.0)
Batch mode: 8-view sweep
Result: 8 lines, one for each azimuth angle at eye-level medium distance
Each line applied to a separate prompt/window
```

### Practical Examples

**Example 1: Single Angle Prompt**
```
Positive: "A red ceramic vase, detailed texture, product photography style"

Using Multi-Angle Helper:
<sks> front view (0°) eye-level shot (0°) medium shot (×1.0)

Combined: "A red ceramic vase, detailed texture, product photography style
<sks> front view (0°) eye-level shot (0°) medium shot (×1.0)"

Control Process: None

Negative: "distorted shape, blurry details, poor lighting"

Settings: guidance_scale=7.0, steps=40
```

**Example 2: 8-View Product Sweep**
```
Positive: "Professional product photography of a luxury watch, 
detailed craftsmanship, studio lighting, white background"

Using Multi-Angle Helper:
Batch mode: 8-view sweep
Base: front view (0°), eye-level (0°), medium (×1.0)

Result creates 8 separate prompts (one per line):
<sks> front view (0°) eye-level shot (0°) medium shot (×1.0)
<sks> front-right quarter view (45°) eye-level shot (0°) medium shot (×1.0)
<sks> right side view (90°) eye-level shot (0°) medium shot (×1.0)
... (5 more angles)

Apply as multi-window generation with each line = one window
```

**Example 3: Character Multi-Elevation**
```
Positive: "Anime character in school uniform, full body view, 
character design sheet, clear background"

Using Multi-Angle Helper:
Batch mode: 4-elevation sweep
Base: front view (0°), eye-level (0°), medium (×1.0)

Result creates 4 prompts showing same character from 4 heights:
<sks> front view (0°) low-angle shot (-30°) medium shot (×1.0)
<sks> front view (0°) eye-level shot (0°) medium shot (×1.0)
<sks> front view (0°) elevated shot (30°) medium shot (×1.0)
<sks> front view (0°) high-angle shot (60°) medium shot (×1.0)

Each line = separate window for different viewing height
```

### Best Practices

1. **Use with Multi-Window Generation**
   - Each generated prompt line = separate sliding window
   - Allows same subject from different angles across windows
   - Maintains consistency through control processes (Depth transfer recommended)

2. **Pair with Control Processes**
   - **Depth Transfer** - Maintains 3D structure across angles
   - **Pose Transfer** - Keeps character pose consistent while changing angle
   - Improves consistency between different viewpoints

3. **Combine with Main Prompt**
   - Keep base description in main positive prompt
   - Multi-angle helper provides camera instructions
   - Both together = complete generation instruction

4. **Use Reference Images**
   - Upload reference of your subject
   - Multi-angle helper controls how it's viewed
   - Reference consistency applied across all angles

5. **Choose Appropriate Sweeps**
   - **8-view** - Full rotation around subject (360°)
   - **4-elevation** - Vertical height variation
   - **3-distance** - Zoom/scale variation
   - **All 96** - Complete exploration (use for experimentation)

### Limitations and Notes

- Fixed angle increments (no custom degrees)
- Distance scale is multiplicative (×0.6 to ×1.8 range)
- Elevation limited to 4 predefined levels
- 96-combination maximum per batch
- Works best with Qwen Image Edit model
- Requires prompt to be properly structured for multi-window use

### Troubleshooting

**Issue: Angles not applying correctly**
- Verify `<sks>` trigger token is included (check checkbox)
- Ensure prompt ends up in correct prompt field
- Check control process isn't overriding camera angles

**Issue: Angles merged or inconsistent**
- Use Depth Transfer control to maintain 3D consistency
- Increase guidance scale (7.5-8.0)
- Add consistency keywords to main prompt: "same subject, consistent object"

**Issue: Need custom angles**
- Multi-Angle Helper provides fixed 8×4×3 grid only
- For custom degrees, edit generated prompt manually
- Copy preset output and modify angle values

---

## Camera Angle LoRA

**Alternative Approach:** For more flexible camera angle control, use the external Camera Angle LoRA  
**LoRA Name:** Qwen Edit Angles - Multiple Angles LoRA  
**Repository:** https://civitai.com/models/2099912/qwen-edit-angles-multiple-angles-lora  
**Best For:** Custom angles, style-based camera control, LoRA strength modulation

### When to Use Camera Angle LoRA vs Multi-Angle Prompt Helper

| Aspect | Multi-Angle Helper | Camera Angle LoRA |
|--------|-------------------|-------------------|
| Access | Built-in plugin | External LoRA |
| Angle Precision | 8 fixed azimuths, 4 elevations | Custom angle specification |
| Ease of Use | UI-driven, dropdown selection | Text-based specifications |
| Flexibility | Limited to 96 combinations | Unlimited custom angles |
| LoRA Strength Control | N/A | Adjustable (0.8-1.5+) |
| Best For | Quick preset generation | Fine-tuned angle control |

### Camera Angle LoRA: How It Works

The Camera Angle LoRA allows you to specify camera angles, elevation, and distance through text prompts with full flexibility. Unlike the helper, you define angles directly in your prompt.

**General Syntax:**
```
[Subject description] [camera angle degrees] [elevation] [distance/scale]
```

**Examples:**
- `"A ceramic vase, 45 degree angle, medium distance, professional lighting"`
- `"Product photography, 90 degree side view, elevated shot, close-up"` 
- `"Character design, front view (0 degrees), eye level, wide shot"`

### Using Camera Angle LoRA: Best Practices

**1. Basic Camera Angle Specification**

```
Positive: "A red ceramic vase, detailed craftsmanship, product photography style"

LoRA: "qwen_edit_angles" (1.0-1.2)

Camera angle instruction: "front view (0 degrees), eye-level shot, medium distance"

Combined: "A red ceramic vase, detailed craftsmanship, product photography style. 
Front view (0 degrees), eye-level shot, medium distance"

Control Process: None

Negative: "distorted shape, blurry details, poor lighting, deformation"

Settings: guidance_scale=7.0, steps=40
```

**2. Custom Angle with Full Details**

```
Positive: "Luxury wristwatch, intricate details, studio lighting, 
white background, product showcase"

LoRA: "qwen_edit_angles" (1.1)

Camera specification: "45 degree angle, elevated to 30 degrees, close-up (×0.7)"

Combined: "Luxury wristwatch, intricate details, studio lighting, white background, product showcase.
45 degree angle, elevated to 30 degrees, close-up (×0.7)"

Control Process: Depth Transfer (maintain 3D structure)

Negative: "blurry, distorted, poor quality, unnatural geometry"

Settings: guidance_scale=7.5, steps=45
```

**3. Character From Custom Angle**

```
Positive: "Anime character in fantasy outfit, full body pose, 
high quality character art, clean background"

LoRA: "qwen_edit_angles" (1.2)

Camera instruction: "135 degree angle (front-left quarter), 
elevated 20 degrees, medium distance"

Combined: "Anime character in fantasy outfit, full body pose, high quality character art, 
clean background. 135 degree angle (front-left quarter), elevated 20 degrees, medium distance"

Control Process: Pose Transfer (maintain character posture)

Negative: "distorted proportions, poor anatomy, blurry, low quality"

Settings: guidance_scale=7.5, steps=45
```

### LoRA Strength Recommendations

| Strength | Camera Control | Best For | Notes |
|----------|----------------|----------|-------|
| 0.8-1.0 | Subtle angle influence | Soft camera effects | Gentle angle shifts |
| 1.0-1.2 | **Recommended range** | Standard camera angles | Good balance of control |
| 1.2-1.5 | Strong angle emphasis | Dramatic perspective shifts | More pronounced camera movement |
| 1.5+ | Very strong control | Experimental, extreme angles | May reduce image realism |

### Angle Specification Guide

**Azimuth (Horizontal Rotation):**
- `0° / front view` - Facing camera
- `45° / front-right quarter` - Slightly rotated right
- `90° / right side` - Full right profile
- `135° / back-right quarter` - Back-right angle
- `180° / back view` - Facing away
- `225°+` / Back-left progressions
- `270° / left side` - Full left profile
- `315° / front-left quarter` - Front-left angle

*Tip: Specify exact degrees (e.g., "73 degree angle") for custom angles between fixed points*

**Elevation (Vertical Angle):**
- `-30° / low-angle shot` - Looking up from below
- `0° / eye-level` - Direct horizontal view
- `30° / elevated shot` - Slightly looking down
- `45°+ / high-angle` - Dramatically looking down

*Tip: Combines with azimuth for 3D camera positioning*

**Distance/Scale (Zoom/Framing):**
- `×0.5-0.7 / close-up` - Tight framing
- `×1.0 / medium distance` - Standard framing
- `×1.5-1.8 / wide shot` - Expansive framing
- `×2.0+ / extreme wide` - Very expansive view

### Combining Angles Across Multiple Prompts

For multi-window generation, specify different angles per window:

```
Window 1 Prompt:
"Product shown from front view (0°), eye-level, medium distance"

Window 2 Prompt:
"Same product shown from 45 degree angle, elevated, medium distance"

Window 3 Prompt:
"Same product shown from right side view (90°), eye-level, wide distance"
```

Each window's camera angle instruction is independent, allowing product 360-degree rotation.

### Combining Camera Angle LoRA with Other LoRAs

**Works well with:**
- Style LoRAs (art style + camera angles)
- Quality LoRAs (detailed rendering + camera control)
- Lighting LoRAs (studio lighting + camera angles)

**Potential conflicts with:**
- Other camera/angle LoRAs (competing direction instructions)
- Some pose-specific LoRAs (may conflict with elevation/angle)

**Best practice:** Use Camera Angle LoRA as the primary angle control, combine with quality/style LoRAs as secondary enhancements.

### Common Issues and Solutions

**Issue: Angles not appearing or ignored**
- Explicitly include degree symbols or numeric values: "45 degree angle"
- Include both azimuth AND elevation for best control
- Verify LoRA is actually loaded (check LoRA list)
- Increase LoRA strength (try 1.1-1.2)

**Issue: Angles distort the subject**
- Use Depth Transfer or Pose Transfer control to maintain structure
- Reduce LoRA strength (try 0.9-1.0)
- Add consistency keywords: "maintains proportions, consistent geometry"
- Ensure subject description is clear and detailed

**Issue: Multiple angles merge or conflict**
- If using multiple prompts, separate them clearly (line breaks)
- Use unique angles in each prompt (avoid identical angles)
- Ensure each prompt specifies a different degree for azimuth
- Use control processes to maintain object consistency

**Issue: Quality degrades with strong camera angles**
- Balance LoRA strength with guidance scale
- Try: LoRA 1.0, guidance 7.5 before trying LoRA 1.5, guidance 8.0
- Increase steps (45-50) for complex angles
- Combine with quality LoRA for better detail preservation

### Prompt Templates for Camera Angle LoRA

**Template 1: Product Photography**
```
[Product name/description], [material/texture details], [lighting type]
[Azimuth angle], [elevation angle], [distance specification]
Settings: guidance_scale=7.0-7.5, LoRA strength=1.0-1.2, steps=40-45
```

**Template 2: Character Design**
```
[Character description + outfit], [art style], [quality level]
[Camera angle degree], [elevation level], [distance/framing]
Settings: guidance_scale=7.5, LoRA strength=1.1-1.2, steps=45, + Pose Transfer control
```

**Template 3: Architectural View**
```
[Building/space description], [material details], [lighting/time of day]
[Isometric/oblique angle], [elevation viewpoint], [wide/establishing distance]
Settings: guidance_scale=7.5, LoRA strength=1.2, steps=50
```

---

## Choosing Between Helper and LoRA

**Use Multi-Angle Prompt Helper when:**
- You want quick, preset angle generation
- You need consistent 96-combination catalog
- You prefer UI-based angle selection
- Fastest workflow for batch generation

**Use Camera Angle LoRA when:**
- You need custom, non-standard angles
- You want fine-grained LoRA strength control
- You prefer text-based angle specification
- You're combining with many other LoRAs
- You need unlimited angle flexibility

**Use Both when:**
- Starting with Helper presets, then refining with LoRA
- Using Helper for reference, manually adjusting with LoRA
- Exploring different approaches within same project

---

*This guide is designed for feeding to LLMs to generate effective prompts for Qwen Image Edit operations.*
