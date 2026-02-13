# Wan2GP - General Documentation

Version: 10.70
Last Updated: February 8, 2026

This document covers general Wan2GP UI features and functionality.

---

## Output Filename Customization

### Overview
Wan2GP allows you to customize output filenames using template syntax in the **Advanced > Misc** tab under "Output Filename". If left blank, automatic naming is used (format: `{timestamp}_seed{seed}_{prompt}`).

### Complete List of Available Template Variables

| Variable | Aliases | Description | Example Output |
|----------|---------|-------------|----------------|
| `{date}` | - | Timestamp with default format | `2026-02-08-14h30m45s` |
| `{date(FORMAT)}` | - | Date/time with custom format (see below) | `2026-02-08` or `14-30-45` |
| `{seed}` | - | Generation seed value | `42` or `12345` |
| `{resolution}` | - | Video/image resolution | `1280x720` or `1920x1080` |
| `{num_inference_steps}` | `{steps}` | Number of inference steps | `30` or `50` |
| `{prompt}` | - | Full prompt text | `A_cat_walking_in_the_rain` |
| `{prompt(N)}` | - | Prompt truncated to N characters | `{prompt(50)}` → `A_cat_walking...` |
| `{flow_shift}` | - | Flow shift parameter value | `1.0` or `7.5` |
| `{video_length}` | `{frames}` | Video length in frames | `97` or `193` |
| `{guidance_scale}` | `{cfg}` | Guidance scale (CFG) value | `5.0` or `7.5` |

### Date/Time Format Tokens

When using `{date(FORMAT)}`, you can construct custom date/time formats using these tokens:

| Token | Description | Example |
|-------|-------------|---------|
| `YYYY` | 4-digit year | `2026` |
| `YY` | 2-digit year | `26` |
| `MM` | 2-digit month (01-12) | `02` |
| `DD` | 2-digit day (01-31) | `08` |
| `HH` | 2-digit hour, 24-hour format (00-23) | `14` |
| `hh` | 2-digit hour, 12-hour format (01-12) | `02` |
| `mm` | 2-digit minute (00-59) | `30` |
| `ss` | 2-digit second (00-59) | `45` |

**Allowed separators:** `-` `_` `.` `:` `/` space `h`

### Date Format Examples

```
{date(YYYY-MM-DD)}           → 2026-02-08
{date(YYYY/MM/DD)}           → 2026/02/08
{date(DD.MM.YYYY)}           → 08.02.2026
{date(YYYY-MM-DD_HH-mm-ss)}  → 2026-02-08_14-30-45
{date(HHhmm)}                → 14h30
{date(YYYYMMDD)}             → 20260208
{date(HH-mm-ss)}             → 14-30-45
{date(YYYY-MM-DD_HH:mm:ss)}  → 2026-02-08_14:30:45
```

### Complete Template Examples

```
{date}-{prompt(50)}-{seed}
  → 2026-02-08-14h30m45s-A_beautiful_sunset_over_the_ocean-12345

{date(YYYYMMDD)}_{resolution}_{steps}steps
  → 20260208_1280x720_30steps

{date(YYYY-MM-DD_HH-mm-ss)}_{seed}_{cfg}cfg
  → 2026-02-08_14-30-45_42_7.5cfg

{date(DD.MM.YYYY)}_{prompt(30)}_{frames}frames
  → 08.02.2026_A_cat_walking_in_the_rain_97frames

{seed}_{prompt(40)}_{steps}s_{resolution}
  → 12345_Cinematic_sunset_beach_scene_30s_1920x1080
```

### Subdirectory Support

**Answer:** Subdirectories are **NOT supported**. Forward slashes `/` and other unsafe filename characters are automatically removed and replaced with underscores `_`.

**Characters automatically sanitized:**
- `< > : " / \ | ? *`
- Control characters (0x00-0x1F)
- Newlines, carriage returns, tabs

**Example:**
```
Template: {date}/videos/{prompt(30)}
Result:   2026-02-08_videos_A_cat_walking
                    ↑
              Slashes replaced with underscores
```

All output files are saved to the configured output directory (Advanced > Misc > "Output Directory"). The template only controls the **filename**, not the path.

### Multiple Images from Single Prompt

**Answer:** Yes, when generating multiple images (N > 1 via "Num of generated videos per prompt"), an image index is automatically appended:

```
Base filename: sunset_12345.jpg

Generated files:
  sunset_12345.jpg      ← First image (no suffix)
  sunset_12345_1.jpg    ← Second image
  sunset_12345_2.jpg    ← Third image
  ...
```

The index starts at `_1` for the second image. The first image has no index suffix.

### Sliding Window Numbering

**Answer:** Sliding window numbers are **NOT automatically included** in the output filename template variables.

However, window information is tracked internally:
- Window number is visible in the generation queue UI ("Window no X")
- If you use multiple prompts (one per line), each window uses its corresponding prompt, which affects `{prompt}` in the template

**Workaround:** Use multi-line prompts with window-specific identifiers:
```
Prompts:
  Window1: A cat walking in the rain
  Window2: A cat running through puddles  
  Window3: A cat shaking off water

Template: {date}_{prompt(50)}_{seed}

Results:
  2026-02-08_Window1_A_cat_walking_in_the_rain_12345.mp4
  2026-02-08_Window2_A_cat_running_through_puddles_12345.mp4
  2026-02-08_Window3_A_cat_shaking_off_water_12345.mp4
```

---

## LoRA Multiplier Weights and Phases

### Overview

LoRA multipliers allow you to control the strength of each LoRA applied during generation. You can specify different weights across multiple phases (high-noise to low-noise stages) to achieve different effects at different generation stages.

**Field Location:** Advanced Settings → Loras Multiplier (text field)

### Delimiter Options

The `loras_multipliers` field supports multiple delimiters (in priority order):

| Delimiter | Use Case | Example |
|-----------|----------|---------|
| **Newline** (`\n`) | Separate multiplier groups, enables comments | `1.0 0.8` + newline + `0.9 0.5` |
| **Hash** (`#`) | Comments (line start only) | `# High-detail setup` `1.0 0.8` |
| **Pipe** (`\|`) | Separate accelerator LoRAs from regular | `1.0 0.8 \| 0.3 0.2` |
| **Space** | Separate weights for different LoRAs | `1.0 0.8 0.9` (3 LoRAs) |
| **Semicolon** (`;`) | **Phase separator** (main use for high/low phases) | `1.0;0.5` (phase1; phase2) |
| **Comma** (`,`) | Step interpolation within a phase | `0.9,0.8,0.7` (fade effect) |

### Phase System

Wan2GP supports multi-phase generation:
- **Phase 1 (High Noise)**: Early generation steps with strong guidance
- **Phase 2 (Low Noise)**: Refinement steps with lighter guidance
- **Phase 3 (Ultra Low Noise)**: Final refinement (if supported by model)

Phases are separated by **semicolon** (`;`): `phase1_weight;phase2_weight;phase3_weight`

### Pattern 1: Uniform Strength (All LoRAs Same Value, Same Phase)

Single value for each LoRA, same strength across all phases:

```
High LoRA 1: Str 1.0
High LoRA 2: Str 0.8
High LoRA 3: Str 0.9

Multiplier looks like this: 1.0 0.8 0.9

Result:
Phase 1 (High Noise): LoRA1(1.0) + LoRA2(0.8) + LoRA3(0.9)
Phase 2 (Low Noise): LoRA1(1.0) + LoRA2(0.8) + LoRA3(0.9)
```

---

### Pattern 2: 2-Phase (High and Low Noise Different)

Different strength for high-noise (Phase 1) vs low-noise (Phase 2):

```
High LoRA 1: Str 1.0
Low LoRA 1: Str 0.7
High LoRA 2: Str 0.8
Low LoRA 2: Str 1.0

Multiplier looks like this: 1.0;0.7 0.8;1.0
             Space separator ↑  Semicolon (phase separator)

Result:
Phase 1 (High Noise): LoRA1(1.0) + LoRA2(0.8)
Phase 2 (Low Noise): LoRA1(0.7) + LoRA2(1.0)
```

---

### Pattern 3: 4 LoRAs Mixed (Uniform + Phase-Varied)

First 2 LoRAs uniform, last 2 LoRAs phase-varied:

```
High LoRA 1: Str 1.0
Low LoRA 1: Str 1.0
High LoRA 2: Str 1.0
Low LoRA 2: Str 1.0
High LoRA 3: Str 0.9
Low LoRA 3: Str 0.5
High LoRA 4: Str 0.9
Low LoRA 4: Str 0.5

Multiplier looks like this: 1.0;1.0 1.0;1.0 0.9;0.5 0.9;0.5
                    Uniform (both phases same) ↑  ↑ Phase-varied

Result:
Phase 1 (High Noise): LoRA1(1.0) + LoRA2(1.0) + LoRA3(0.9) + LoRA4(0.9)
Phase 2 (Low Noise): LoRA1(1.0) + LoRA2(1.0) + LoRA3(0.5) + LoRA4(0.5)
```

---

### Pattern 4: 6 LoRAs, 2-Phase (Complex Mix)

Varied strength strategy across 6 LoRAs, 2 phases:

```
High LoRA 1: Str 1.0
Low LoRA 1: Str 0.8
High LoRA 2: Str 0.8
Low LoRA 2: Str 1.0
High LoRA 3: Str 0.7
Low LoRA 3: Str 0.9
High LoRA 4: Str 0.9
Low LoRA 4: Str 0.7
High LoRA 5: Str 1.0
Low LoRA 5: Str 0.5
High LoRA 6: Str 1.0
Low LoRA 6: Str 0.5

Multiplier looks like this: 1.0;0.8 0.8;1.0 0.7;0.9 0.9;0.7 1.0;0.5 1.0;0.5

Result:
Phase 1 (High Noise): LoRA1(1.0) + LoRA2(0.8) + LoRA3(0.7) + LoRA4(0.9) + LoRA5(1.0) + LoRA6(1.0)
Phase 2 (Low Noise): LoRA1(0.8) + LoRA2(1.0) + LoRA3(0.9) + LoRA4(0.7) + LoRA5(0.5) + LoRA6(0.5)
```

---

### Pattern 5: 3-Phase (High, Medium, Low Noise)

Three distinct phases with different strengths for each:

```
High LoRA 1: Str 1.0
Medium LoRA 1: Str 0.8
Low LoRA 1: Str 0.5
High LoRA 2: Str 0.8
Medium LoRA 2: Str 1.0
Low LoRA 2: Str 0.9
High LoRA 3: Str 0.6
Medium LoRA 3: Str 0.8
Low LoRA 3: Str 1.0

Multiplier looks like this: 1.0;0.8;0.5 0.8;1.0;0.9 0.6;0.8;1.0
                    Phase 1;Phase 2;Phase 3 separations

Result:
Phase 1 (High Noise): LoRA1(1.0) + LoRA2(0.8) + LoRA3(0.6)
Phase 2 (Medium Noise): LoRA1(0.8) + LoRA2(1.0) + LoRA3(0.8)
Phase 3 (Low Noise): LoRA1(0.5) + LoRA2(0.9) + LoRA3(1.0)
```

---

### Pattern 6: 6 LoRAs, 3-Phase (Full Refinement)

Complex 3-phase with 6 LoRAs, each phase having unique emphasis:

```
High LoRA 1: Str 1.0
Medium LoRA 1: Str 0.8
Low LoRA 1: Str 0.5
High LoRA 2: Str 0.8
Medium LoRA 2: Str 1.0
Low LoRA 2: Str 0.9
High LoRA 3: Str 0.6
Medium LoRA 3: Str 0.8
Low LoRA 3: Str 1.0
High LoRA 4: Str 0.7
Medium LoRA 4: Str 0.9
Low LoRA 4: Str 0.8
High LoRA 5: Str 0.5
Medium LoRA 5: Str 0.8
Low LoRA 5: Str 1.0
High LoRA 6: Str 1.0
Medium LoRA 6: Str 0.9
Low LoRA 6: Str 0.7

Multiplier looks like this: 1.0;0.8;0.5 0.8;1.0;0.9 0.6;0.8;1.0 0.7;0.9;0.8 0.5;0.8;1.0 1.0;0.9;0.7

Result:
Phase 1 (High Noise): LoRA1(1.0) + LoRA2(0.8) + LoRA3(0.6) + LoRA4(0.7) + LoRA5(0.5) + LoRA6(1.0)
Phase 2 (Medium Noise): LoRA1(0.8) + LoRA2(1.0) + LoRA3(0.8) + LoRA4(0.9) + LoRA5(0.8) + LoRA6(0.9)
Phase 3 (Low Noise): LoRA1(0.5) + LoRA2(0.9) + LoRA3(1.0) + LoRA4(0.8) + LoRA5(1.0) + LoRA6(0.7)
```

---

### Pattern 7: With Accelerator LoRAs (Pipe Separator)

Regular LoRAs separated from accelerator LoRAs using pipe `|`:

```
High LoRA 1: Str 1.0
Low LoRA 1: Str 0.8
High LoRA 2: Str 0.9
Low LoRA 2: Str 0.7

High Accelerator 1: Str 0.5
Low Accelerator 1: Str 0.3
High Accelerator 2: Str 0.4
Low Accelerator 2: Str 0.2

Multiplier looks like this: 1.0;0.8 0.9;0.7 | 0.5;0.3 0.4;0.2
                    Regular LoRAs ↑  ↑ Accelerator LoRAs (pipe separator)

Result:
Phase 1 (High Noise): LoRA1(1.0) + LoRA2(0.9) [then] Accel1(0.5) + Accel2(0.4)
Phase 2 (Low Noise): LoRA1(0.8) + LoRA2(0.7) [then] Accel1(0.3) + Accel2(0.2)
```

---

### Pattern 8: With Comments and Newlines

Multi-line format with comments for organization:

```
High LoRA 1: Str 1.0
Low LoRA 1: Str 0.9
High LoRA 2: Str 0.8
Low LoRA 2: Str 1.0
High LoRA 3: Str 0.9
Low LoRA 3: Str 0.7

High Accelerator 1: Str 0.3
Low Accelerator 1: Str 0.2

Multiplier looks like this:
# Character styling set
1.0;0.9 0.8;1.0 0.9;0.7

# Accelerator set
| 0.3;0.2

Processing:
Phase 1 (High Noise): LoRA1(1.0) + LoRA2(0.8) + LoRA3(0.9) [then] Accel1(0.3)
Phase 2 (Low Noise): LoRA1(0.9) + LoRA2(1.0) + LoRA3(0.7) [then] Accel1(0.2)
Comments (lines starting with #) are ignored
Newlines separate logical groups
```

---

### Pattern 9: Step Interpolation with Comma (Fade Effect)

Smooth fade across multiple steps within a phase:

```
High LoRA 1: Str 0.9 (step 1)
High LoRA 1: Str 0.8 (step 2)
High LoRA 1: Str 0.7 (step 3)
Low LoRA 1: Str 1.0 (step 1)
Low LoRA 1: Str 0.9 (step 2)
Low LoRA 1: Str 0.8 (step 3)

High LoRA 2: Str 0.5
Low LoRA 2: Str 0.9

Multiplier looks like this: 0.9,0.8,0.7;1.0,0.9,0.8 0.5;0.9
                    Comma separates steps within phase ↑

Result:
Phase 1 (High Noise):
  Step 1: LoRA1(0.9) + LoRA2(0.5)
  Step 2: LoRA1(0.8) + LoRA2(0.5)
  Step 3: LoRA1(0.7) + LoRA2(0.5)
Phase 2 (Low Noise):
  Step 1: LoRA1(1.0) + LoRA2(0.9)
  Step 2: LoRA1(0.9) + LoRA2(0.9)
  Step 3: LoRA1(0.8) + LoRA2(0.9)
```

---

### Pattern 10: All Accelerators Only

When using only accelerator LoRAs (no regular LoRAs):

```
High Accelerator 1: Str 0.8
Low Accelerator 1: Str 0.5
High Accelerator 2: Str 0.6
Low Accelerator 2: Str 0.4

Multiplier looks like this: | 0.8;0.5 0.6;0.4
                    Pipe at start (no regular LoRAs before)

Result:
Phase 1 (High Noise): Accel1(0.8) + Accel2(0.6)
Phase 2 (Low Noise): Accel1(0.5) + Accel2(0.4)
```

---

### Quick Reference

| Pattern | LoRAs | Field Value | Phases |
|---------|-------|------------|--------|
| Uniform | 3 | `1.0 0.8 0.9` | Single (same for all) |
| 2-Phase Basic | 2 | `1.0;0.7 0.8;1.0` | High; Low |
| 4 LoRAs Mixed | 4 | `1.0;1.0 1.0;1.0 0.9;0.5 0.9;0.5` | High; Low (varies by group) |
| 6 LoRAs 2-Phase | 6 | `1.0;0.8 0.8;1.0 0.7;0.9 0.9;0.7 1.0;0.5 1.0;0.5` | High; Low |
| 3 LoRAs 3-Phase | 3 | `1.0;0.8;0.5 0.8;1.0;0.9 0.6;0.8;1.0` | High; Medium; Low |
| 6 LoRAs 3-Phase | 6 | `1.0;0.8;0.5 0.8;1.0;0.9 0.6;0.8;1.0 0.7;0.9;0.8 0.5;0.8;1.0 1.0;0.9;0.7` | High; Medium; Low |
| With Accelerators | 2+2 | `1.0;0.8 0.9;0.7 \| 0.5;0.3 0.4;0.2` | High; Low (split) |
| With Comments | 3 | `# Set1` + newline + `1.0;0.9 0.8;1.0` | High; Low (organized) |
| Fade Effect | 2 | `0.9,0.8,0.7;1.0,0.9,0.8 0.5;0.9` | High (fade); Low (fade) |
| Accelerators Only | 2 | `\| 0.8;0.5 0.6;0.4` | High; Low (accel only) |

---

### Common Use Cases

**Style-First (Strong early):**
```
High LoRA 1: Str 1.2
Low LoRA 1: Str 0.7
High LoRA 2: Str 0.9
Low LoRA 2: Str 1.0

Field: 1.2;0.7 0.9;1.0
```

**Quality-First (Strong late):**
```
High LoRA 1: Str 0.8
Low LoRA 1: Str 1.0
High LoRA 2: Str 0.6
Low LoRA 2: Str 0.8

Field: 0.8;1.0 0.6;0.8
```

**Balanced Progressive (Gradual increase):**
```
High LoRA 1: Str 0.8
Low LoRA 1: Str 1.0
High LoRA 2: Str 0.7
Low LoRA 2: Str 0.9
High LoRA 3: Str 0.6
Low LoRA 3: Str 0.8

Field: 0.8;1.0 0.7;0.9 0.6;0.8
```

---

*Answered: 2/8/2026 4:30:15 PM CST*
