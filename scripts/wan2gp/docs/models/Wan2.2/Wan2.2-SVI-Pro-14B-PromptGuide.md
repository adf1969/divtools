# Wan2.2 SVI Pro - Prompting Guide
# Last Updated: 2/8/2026 10:00:00 AM CST

**Model:** Wan2.2 Image2Video 14B SVI 2 Pro  
**Purpose:** Guide for writing effective prompts for video generation  
**Target Audience:** LLMs, users generating prompts programmatically

---

## Quick Reference

**Template for Effective Prompts:**

```
Positive Prompt:
[Scene description], [subject details], [action], 
[visual style indicators], (at X seconds:[timed actions])

LoRA: [style_lora_name] (scale: 1.0-1.5)

Negative Prompt:
[quality issues], [motion artifacts], [unwanted elements], [style conflicts]

Settings:
- NAG enabled with scale 5.0-7.0 if using LoRA
- Guidance scale 5.0-8.0 for strong prompt adherence
- Steps: 30-50 for quality, 20-30 for speed
```

---

## Positive Prompt Writing

**Purpose:** Describe what you want to appear and happen in your video.

**5 Key Practices:**

1. **Be Descriptive but Concise**
   - Include key visual details: subjects, actions, environment, lighting
   - Example: "A serene forest with morning mist, birds singing, sunlight filtering through trees"
   - Avoid excessive length; prioritize important elements

2. **Use Action Verbs**
   - Specify clear movements and changes
   - Example: "A person walks slowly across a garden, pauses to smell flowers, then continues"
   - Actions help guide the model's motion generation

3. **Include Scene Context**
   - Set the environment and mood
   - Example: "Indoor coffee shop, warm lighting, medium temperature (comfortable)"
   - Context helps maintain visual coherence

4. **Leverage Timed Prompts for Sequences**
   - Break complex actions into timed segments
   - Combine descriptive text with `(at X seconds:action)` syntax
   - Example: "A chef preparing food. (at 2 seconds:starts chopping vegetables) (at 4 seconds:moves pan to stove)"

5. **Specify Important Visual Properties**
   - Quality descriptors: "high quality, detailed, 4K"
   - Style: "cinematic, professional, realistic"
   - Camera movement: "smooth pan, slow zoom, static camera"

---

## Negative Prompt Writing

**Purpose:** Specify what you want to avoid in the generated video.

**5 Key Practices:**

1. **Avoid Common Artifacts**
   - "blur, distortion, pixelation, noise"
   - "jittery motion, jerky movement, unstable camera"
   - "flickering, glitching, artifacts"

2. **Specify Unwanted Elements**
   - "no text, no watermarks"
   - "no hands (if hands are problematic), no visible joints"
   - "no sudden transitions, no fast cuts"

3. **Avoid Quality Issues**
   - "low quality, low resolution, compression artifacts"
   - "oversaturated colors, poor lighting, dark shadows"
   - "unusual proportions, deformed bodies, distorted faces"

4. **Keep It Relevant**
   - Don't list everything undesirable; focus on likely failure modes for your prompt
   - Example: If requesting smooth camera motion, add "no jitter, no jumpiness"
   - If generating realistic humans, consider "no uncanny expressions, no poorly rendered hands"

5. **Common Effective Phrases**
   - "worst quality, low quality, low resolution, blurry, artifacting, jagged edges"
   - "distorted motion, jittery, unstable, shaky camera, jerky movement"

---

## LoRA Usage

**What are LoRAs:** Low-Rank Adaptation modules fine-tune the base model for specific styles, subjects, or behaviors without full retraining.

**5 Key Practices:**

1. **Choose Single, Complementary LoRAs**
   - Use 1-3 LoRAs maximum; too many can create conflicts
   - Example: "photography_style" + "specific_person" is good
   - Avoid: "photography" + "painting" + "sketch" together (contradictory)

2. **Adjust LoRA Strength Appropriately**
   - Start with default scale (typically 1.0)
   - Increase to 1.5-2.0 for strong style influence
   - Decrease to 0.5-0.7 if style overpowers content
   - Test iteratively; LoRA strength is model-dependent

3. **Mention LoRA Content in Prompts**
   - If using a style LoRA, describe that style in your positive prompt
   - Example: If using "cinematic_photography" LoRA, include "cinematic, professional photograph" in your prompt
   - Alignment between LoRA and prompt yields better results

4. **Combine with NAG Guidance**
   - LoRAs work well with NAG (Negative-prompt Attention Guidance) enabled
   - Keep `nag_scale` reasonable (5.0-7.0) when using LoRAs to avoid overconstraint
   - Monitor whether LoRA + NAG creates desired style balance

5. **Testing Strategy**
   - Test base model + positive/negative prompts first
   - Add LoRA with default strength second
   - Fine-tune LoRA strength last
   - This approach isolates which factor affects results

---

## Timed Prompts

**Syntax:** `(at X seconds:prompt text describing action)`

**Key Point:** Times are **relative to each sliding window**, not the entire video sequence.

### Time Reference: Window-Relative vs. Absolute

If you want an action to occur 3 seconds into the 2nd sliding window (which translates to 8 seconds from the beginning of the full video), specify:

```
(at 3 seconds:do action)
```

NOT `(at 8 seconds:do action)` for the 2nd window's prompt. Each prompt's time markers are interpreted relative to that window's 5-second duration.

### Practical Example

For a 15-second video with 3 sliding windows:

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

---

## Camera Guidance Prompts

Use these terms to control how the camera moves through your scene.

**Camera Movement Terms:**
- `"smooth camera pan left"` / `"pan right"` - Horizontal panning
- `"slow zoom in"` / `"zoom out"` - Approach or retreat
- `"camera dolly back"` - Backward tracking
- `"gentle camera drift"` - Subtle, floating motion
- `"static camera"` - Fixed camera position
- `"handheld camera"` - Subtle organic shaking
- `"crane shot lifting up"` - Vertical upward motion
- `"Dutch angle tilt"` - Tilted/canted horizon
- `"push in"` - Forward tracking
- `"rotate around subject"` - Orbital motion

**Camera Perspective Terms:**
- `"wide shot"` - Full scene visible
- `"mid-shot"` - Waist-up framing
- `"close-up"` - Detailed facial or object
- `"overhead view"` - Looking down from above
- `"low angle"` - Camera below subject
- `"first-person POV"` - Subjective camera
- `"establishing shot"` - Wide scene introduction

---

## Character and Person Movement Guidance

Direct movement of people and characters in your video.

**Movement Types:**
- `"walks slowly toward camera"` - Approach motion
- `"runs left to right"` - Linear directional movement
- `"turns to face camera"` - Rotational body movement
- `"sits down gracefully"` - Downward transition
- `"stands up from chair"` - Upward transition
- `"gestures expressively with arms"` - Hand/arm choreography
- `"nods head"` - Head movement
- `"looks over shoulder"` - Eye direction
- `"reaches toward object"` - Extension movement
- `"bends down to pick something up"` - Crouching/bending
- `"twists torso"` - Core rotation
- `"walks in circle"` - Repeating circular path

**Movement Quality Descriptors:**
- `"moves with confidence"` - Assured, purposeful
- `"hesitant movements"` - Uncertain, cautious
- `"graceful motion"` - Fluid, elegant
- `"stumbles slightly"` - Awkward, imperfect
- `"walks in slow motion"` - Extended duration
- `"moves rapidly"` - Quick, energetic

**Combination Examples:**
- `"character walks across frame (at 2 seconds:pauses to look at camera) (at 4 seconds:continues walking)"`
- `"person sits at desk (at 1 second:reaches for coffee cup) (at 3 seconds:takes a sip)"`
- `"dancer moves through space with graceful arm gestures, camera slowly zooms in on their face"`

**Pro Tips:**
1. Combine with timed prompts using `(at X seconds:)` to sequence movements
2. Be specific about direction: `left`, `right`, `toward camera`, `away`
3. Use quality descriptors to define movement feel (graceful, awkward, confident)
4. Sync camera movement with character movement for coherent motion
5. Avoid simultaneous contradictory motions in the same window

---

## Example Full Prompt

```
Positive: "A silhouette figure standing on a cliff overlooking an ocean at sunset, 
warm orange light, breeze moving their hair, cinematic, professional photography, 
(at 3 seconds:camera slowly zooms in), (at 4.5 seconds:figure raises arm and looks up)"

LoRA: "cinematic_photography" (1.2)

Negative: "blur, distortion, jittery motion, low quality, oversaturated, poorly rendered hands"

Settings: guidance_scale=7.0, nag_scale=6.0, steps=40
```

---

## Settings Reference

| Setting | Range | Purpose |
|---------|-------|---------|
| guidance_scale | 5.0-8.0 | Strength of prompt adherence (higher = more literal) |
| nag_scale | 5.0-7.0 | Negative prompt attention (with NAG enabled) |
| steps | 20-50 | Generation quality (more steps = higher quality, slower) |
| LoRA scale | 0.5-2.0 | LoRA influence strength |

---

*This guide is designed for feeding to LLMs to generate effective prompts for Wan2.2 SVI Pro video generation.*
