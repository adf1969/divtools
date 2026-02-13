# LoRA Multipliers Parsing - Wan2GP Technical Reference

## Overview
LoRA multipliers in Wan2GP control the strength and timing of LoRA effects during video generation. The parsing system supports simple scalar multipliers, time-based variations, and phase-based multipliers for multi-stage generation models.

## Source Files
- **Main Parsing Module**: `/opt/wan2gp/Wan2GP/shared/utils/loras_mutipliers.py` (note: typo in filename)
- **Usage in**: `/opt/wan2gp/Wan2GP/wgp.py`
- **Model Handler**: `/opt/wan2gp/Wan2GP/models/wan/wan_handler.py`
- **Documentation**: `/opt/wan2gp/Wan2GP/docs/LORAS.md`

## Field Name
- **JSON Field**: `loras_multipliers` (string)
- **Default Value**: `""` (empty string)
- **Configuration Location**: `models/_settings.json`

## Delimiter Characters

### Primary Delimiters (Token Separators)

| Delimiter | Purpose | Usage | Notes |
|-----------|---------|-------|-------|
| **Space** | Separate multipliers for different LoRAs | `1.2 0.8 0.5` | Default separator |
| **Newline** (`\n`) | Separate multipliers for different LoRAs | Multi-line input | Comments supported (#) |
| **Pipe** (`\|`) | Separate LoRA accelerators from regular LoRAs | `1 0.5 \| 0.3` | Only ONE pipe allowed |
| **Semicolon** (`;`) | Separate phase-based multipliers | `1.0;0.5;0.2` | For multi-phase models |
| **Comma** (`,`) | Separate time-based (step) multipliers | `0.9,0.8,0.7` | Interpolates across steps |
| **Hash** (`#`) | Comment marker (only at line start) | `# This is a comment` | Skipped during parsing |

### Delimiter Priority/Hierarchy
```
1. Newline/Carriage Return - splits lines and enables comments
2. Hash (#) - marks comment lines  
3. Pipe (|) - separates BEFORE and AFTER LoRA sets
4. Space - separates individual multiplier tokens
5. Semicolon (;) - separates PHASES within a multiplier
6. Comma (,) - separates TIME-STEPS within a phase
```

## Parsing Functions

### 1. `preparse_loras_multipliers(loras_multipliers)`

**Purpose**: Initial preprocessing to normalize input format and extract tokens

**Input**:
- String or List of multiplier specifications
- Can include newlines, pipes, spaces, and comments

**Output**: List of token strings (one per LoRA)

**Process**:
```python
1. If input is list: strip whitespace from each element
2. If input is string:
   a. Remove trailing \r, \n
   b. Split by newlines
   c. Remove empty lines and comment lines (starting with #)
   d. Join remaining lines with spaces
   e. Replace all "|" with spaces (pipe becomes separator)
   f. Split by spaces
```

**Example**:
```python
Input:  "1.2 0.8\n0.5 # comment\n| 0.3"
Output: ["1.2", "0.8", "0.5", "0.3"]
```

### 2. `parse_loras_multipliers(loras_multipliers, nb_loras, num_inference_steps, ...)`

**Purpose**: Parse preprocessed multipliers and expand them for all inference steps

**Key Parameters**:
- `loras_multipliers`: String or list of multiplier specifications
- `nb_loras`: Number of LoRAs in activated_loras
- `num_inference_steps`: Total denoising steps
- `nb_phases`: Number of guidance phases (default: 2)
- `model_switch_step`: Step where model phase changes (for Wan 2.2 High/Low noise)
- `model_switch_step2`: Step for second phase transition
- `model_switch_phase`: Which phase to switch on (1 or 2)
- `merge_slist`: Previous multiplier lists to merge with

**Return Value**: Tuple of `(loras_list_mult_choices_nums, slists_dict, errors)`
- `loras_list_mult_choices_nums`: List of multiplier arrays (one per LoRA)
- `slists_dict`: Dictionary with phase1, phase2, phase3, shared phases
- `errors`: Error message if parsing failed

**Process Flow**:

1. **Preprocessing**: Call `preparse_loras_multipliers()` to normalize
2. **Token Extraction**: For each multiplier token up to `nb_loras`
3. **Phase Parsing**: Split by `;` (semicolon)
4. **Step Interpolation**: Split by `,` (comma) for time-based values
5. **Validation**: Ensure correct count of phases and valid float values
6. **Expansion**: Interpolate time-based multipliers across inference steps

## Multiplier Syntax Patterns

### Pattern 1: Simple Scalar (No phases, no time variation)
```
1.2 0.8 0.5
```
- Each space-separated value is one LoRA's multiplier
- Same value used for all steps and all phases
- `shared[i] = True` (uniform across model)

### Pattern 2: Time-Based (Comma-separated values within one phase)
```
0.9,0.8,0.7
1.2,1.1,1.0
```
- Comma separates values for time-based interpolation
- Values are distributed across `num_inference_steps`
- First value used for steps 0 to n/3
- Second value used for steps n/3 to 2n/3
- Third value used for steps 2n/3 to n
- Works across all phases equally
- `shared[i] = True`

**Step Calculation**:
```python
inc = len(slist) / num_inference_steps
pos = 0
for i in range(num_inference_steps):
    multiplier[i] = slist[int(pos)]
    pos += inc
```

### Pattern 3: Phase-Based (Semicolon-separated values)
```
1.0;0.5;0.2
0;1
```
- Semicolon separates multipliers for different phases
- **Wan 2.2 Two Models**: 
  - Phase 1: High Noise model multiplier
  - Phase 2+: Low Noise model multiplier
- **Guidance Phases (up to 3)**:
  - Phase 1: CFG 3.5 (highest)
  - Phase 2: CFG 1.5 (medium)
  - Phase 3: CFG 1 (lowest)
- Must match `nb_phases` parameter or have <= 1 part (non-phased)
- `shared[i] = False`

**Phase Alignment**:
- If `model_switch_phase == 2`: Insert phase before beginning: `[phase_mult[0]] + phase_mult`
- If `model_switch_phase == 1`: Append last phase at end: `phase_mult + [phase_mult[-1]]`

### Pattern 4: Combined (Time-based AND Phase-based)
```
0.9,0.8;1.2,1.1,1
0.5;0,0.7
```
- Semicolon separates phases
- Within each phase, comma separates time steps
- First LoRA: 
  - Phase 1: 0.9 → 0.8 over steps
  - Phase 2: 1.2 → 1.1 → 1 over steps
- Second LoRA:
  - Phase 1: 0.5 (constant)
  - Phase 2: 0 → 0.7 over steps
- Time-based multipliers are interpolated independently per phase

### Pattern 5: Pipe-Separated (LoRA Accelerators vs Regular)
```
1 0.5 | 0.3
0.9,0.8;1.2,1.1 | 0.5;0.8
```
- **Before pipe** (`|`): LoRA Accelerator multipliers
- **After pipe**: Regular LoRA multipliers
- Maximum ONE pipe allowed
- Tokens before pipe are counted and LoRAs after that position use after-pipe multipliers
- If more LoRAs than tokens: extras are appended to selected side

## Validation Rules

### Constraint 1: Single Pipe Maximum
```
Error: "There can be only one '|' character in Loras Multipliers Sequence"
```

### Constraint 2: Phase Count Match
If semicolon-separated (phased multiplier):
- Must have 1 part (non-phased), OR
- Must have exactly `nb_phases` parts

```
Error: f"if the ';' syntax is used for one Lora multiplier, 
        there should be at most {nb_phases} phases"
```

### Constraint 3: Valid Float Values
All multiplier values must be parseable as float:
```
Error: f"Lora sub value no {i+1} ({smult}) in Multiplier definition 
        '{multlist}' is invalid in Phase {phase_no+1}"
```

OR

```
Error: f"Lora Multiplier no {i+1} ({mult}) is invalid"
```

### Constraint 4: Phase Mismatch Rules
- If ANY LoRA uses semicolon syntax with multiple phases, others must either:
  - Also use semicolon with same phase count, OR
  - Use non-phased syntax (will be shared across all phases)
- Pure time-based (comma only, no semicolon) ignores phases

## Phase System Details

### Default Phases
```python
phase1 = [1.0] * nb_loras  # Phase 1 multipliers
phase2 = [1.0] * nb_loras  # Phase 2 multipliers
phase3 = [1.0] * nb_loras  # Phase 3 multipliers
shared = [False] * nb_loras # True if same multiplier for all phases
```

### Phase Switch Configuration
- `model_switch_step`: Inference step when model switches (default: num_inference_steps)
- `model_switch_step2`: Step for 3rd phase transition (default: num_inference_steps)
- `model_switch_phase`: Which phase triggers model switch (1 or 2)

### Real-world Example (Wan 2.2)
```
Model Configuration:
- 2 LoRAs
- 30 inference steps total
- Guidance Phases: 3
- Model Transition: Phase 2→3 at step 20
- model_switch_phase = 1

Multipliers: "0.9,0.8;1.2,1.1,1" "0.5;0,0.7"
Results:
  LoRA 1:
    - Phase 1 (High noise, steps 0-20): 0.9 → 0.8 interpolated
    - Phase 2 (steps 20-25): transitions
    - Phase 3 (Low noise, steps 25-30): 1.2 → 1.1 → 1 interpolated
  LoRA 2:
    - Phase 1: 0.5 (constant)
    - Phase 2: transitions
    - Phase 3: 0 → 0.7 interpolated
```

## Allowed Character Set
```python
_ALWD = set(":;,.0123456789")
```
Valid token characters: digits 0-9, comma, period, semicolon, colon

## Comment Support
- Lines starting with `#` are removed during preprocessing
- Comments must start at beginning of line (after stripping whitespace)
- Cannot have inline comments

**Example**:
```
1.2 0.8
# This is a comment - this entire line is ignored
0.5
```

## Merging Multipliers
Function: `merge_loras_settings(loras_old, mult_old, loras_new, mult_new, mode)`

**Purpose**: Merge new LoRA settings with existing ones while preserving:
- Formatting and comments
- Correct handling of pipe-separated LoRAs
- Deduplication by path

**Modes**:
- `"merge before"`: Keep BEFORE side of pipe, replace AFTER
- `"merge after"`: Keep AFTER side of pipe, replace BEFORE

## Extraction Functions

### `extract_loras_side(loras, mult, which)`
Extract only the "before" or "after" side of pipe-separated multipliers

**Parameters**:
- `loras`: List of LoRA paths
- `mult`: Multiplier string with optional pipe
- `which`: "before" or "after"

**Returns**: Tuple of (loras_subset, mult_subset)

## Code Example Usage

```python
from shared.utils.loras_mutipliers import preparse_loras_multipliers, parse_loras_multipliers

# Simple case
loras_multipliers = "1.2 0.8 0.5"
nb_loras = 3
num_inference_steps = 30
nb_phases = 2

mult_choices, slists_dict, errors = parse_loras_multipliers(
    loras_multipliers, 
    nb_loras, 
    num_inference_steps, 
    nb_phases=nb_phases
)

if len(errors) > 0:
    print(f"Error: {errors}")
else:
    print(f"LoRA 1 multipliers: {mult_choices[0]}")  # scalar or list
    print(f"LoRA 2 multipliers: {mult_choices[1]}")
    print(f"LoRA 3 multipliers: {mult_choices[2]}")

# With phases
loras_multipliers_phased = "0.9,0.8;1.2,1.1 0.5;0"
mult_choices2, slists_dict2, errors2 = parse_loras_multipliers(
    loras_multipliers_phased,
    nb_loras=2,
    num_inference_steps=30,
    nb_phases=2
)
```

## User Interface Representation

From wgp.py (web interface):
```
Each LoRA shown as: [LoRA Name] x[multiplier]
Timeline support: time-based multipliers expand to per-step values
Validation: Errors shown as: "Error parsing Loras Multipliers: {error_message}"
```

## Summary Table: Syntaxes

| Syntax | Example | LoRAs | Phases | Time-Based | Use Case |
|--------|---------|-------|--------|-----------|----------|
| Scalar | `1.2 0.8` | Y | N | N | Static strength |
| Time | `0.9,0.8,0.7` | Y | N | Y | Fade effect |
| Phase | `1.0;0.5` | Y | Y | N | Different phases |
| Combined | `0.9,0.8;1.2,1.1` | Y | Y | Y | Dynamic phased |
| Pipe | `1 0.5 \| 0.3` | Y | N | N | Accelerators |
| Comments | `1.2 # comment` | Y | N | N | Documentation |

## Implementation Notes

1. **Typo in Module Name**: The module is named `loras_mutipliers.py` not `loras_multipliers.py` (missing 'l' in multipliers)

2. **Token Matching**: Tokens from `preparse_loras_multipliers()` are matched 1:1 with LoRAs up to the count of activated_loras

3. **Extra LoRAs**: If more LoRAs than multiplier tokens, remaining LoRAs get multiplier = 1.0 (default)

4. **Performance**: Time-based multipliers don't use extra VRAM - interpolation happens during inference

5. **String Handling**: Input accepts strings, lists, or mixed. Newlines and pipes become space delimiters in preprocessing.

6. **Error Recovery**: If any validation fails, entire parse returns empty lists and error message

