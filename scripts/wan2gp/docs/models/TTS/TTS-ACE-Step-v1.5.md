# ACE Step v1.5 - Advanced Text-to-Music Generation

## Overview
**Model Type**: `ace_step_v1_5`  
**Model Identifier**: DeepBeepMeep/TTS/ace_step15  
**Model Family**: TTS (Text-to-Speech / Music Generation)  
**Architecture**: ACE Step 1.5 Transformer with Audio VAE  
**Last Updated**: 2/8/2026

## Model Purpose
ACE Step v1.5 is an advanced text-to-music generation model with significantly improved speed (8 inference steps vs. v1's 60 steps) and new features including separate vocal/instrumental reference audio, optional Language Model integration, and multiple transformer variants for different use cases.

## Key Features
- **Ultra-Fast Generation**: 8 inference steps (vs 60 in v1)
- **Lyrics-to-Music Creation**: Generate music from lyrical text
- **Dual Reference Audio**: Separate vocal and instrumental prompts
- **Reference Timbre Control**: Clone voice timbre without lyrics
- **Genre/Tag Control**: Specify music style, instruments, mood
- **Temperature Control**: Adjustable randomness (unlike v1)
- **Optional LM Integration**: Language Model for text understanding
- **Multiple Transformer Variants**: Base, SFT, Turbo, and Turbo variations
- **Audio VAE**: Advanced audio encoding/decoding

## Audio Specifications
- **Sample Rate**: 48,000 Hz (48kHz)
- **Output Format**: Music audio waveform
- **Audio Only**: Yes (no video output)
- **Codec**: Audio VAE (Variational Auto-Encoder)

## Transformer Variants

ACE Step v1.5 supports 6 different transformer configurations:

| Variant | Config File | Use Case |
|---------|-------------|----------|
| **base** | `ace_step_v1_5_transformer_config_base.json` | Standard generation |
| **sft** | `ace_step_v1_5_transformer_config_sft.json` | Supervised fine-tuned |
| **turbo** | `ace_step_v1_5_transformer_config_turbo.json` | Fast generation |
| **turbo_shift1** | `ace_step_v1_5_transformer_config_turbo_shift1.json` | Turbo with shift=1 |
| **turbo_shift3** | `ace_step_v1_5_transformer_config_turbo_shift3.json` | Turbo with shift=3 |
| **turbo_continuous** | `ace_step_v1_5_transformer_config_turbo_continuous.json` | Continuous turbo |

**Default**: Base variant

## Model Configuration

### Duration Settings
- **Label**: Duration (seconds)
- **Range**: 5-240 seconds
- **Default**: 60 seconds
- **Increment**: 1 second

### Inference Settings
- **Inference Steps**: Configurable (default: 8) - Much faster than v1
- **Temperature**: Configurable (default: 1.0)
- **Guidance Scale**: Configurable (default: 1.0)
- **Scheduler**: Euler scheduler

## Usage Parameters

### Required Inputs
- **Prompt (Lyrics)**: Cannot be empty - must provide song lyrics
- **Genres/Tags (alt_prompt)**: Musical style and characteristics

### Reference Audio Modes
**Reference Sources** (audio_prompt_type_sources):
- **"" (Empty)**: No Reference Audio / No Reference Timbre
- **"A"**: Reference Audio (need to provide original lyrics and set Reference Audio Strength)
- **"B"**: Reference Timbre (clone voice characteristics only)
- **"AB"**: Reference Audio + Timbre (both vocal and timbre references)

### Audio Guides
1. **Reference Audio (audio_guide)**:
   - **Label**: "Reference Audio"
   - **Purpose**: Reference audio with lyrics for remix/style transfer
   - **Required**: When "A" or "AB" mode selected

2. **Reference Timbre (audio_guide2)**:
   - **Label**: "Reference Timbre"
   - **Purpose**: Reference for voice/timbre characteristics
   - **Required**: When "B" or "AB" mode selected

### Audio Scale
- **Label**: "Reference Audio Strength"
- **Purpose**: Controls influence of reference audio
- **Default**: 0.5
- **Range**: 0.0-1.0

### Genres/Tags (alt_prompt)
- **Label**: "Genres / Tags"
- **Placeholder**: "disco"
- **Lines**: 2
- **Purpose**: Describe musical style, instruments, mood, genre

**Example Tags**:
- "dreamy synth-pop, shimmering pads, soft vocals"
- "rock, distorted guitar, powerful drums, male vocals"
- "lo-fi hip hop, vinyl crackle, mellow beats"
- "orchestral, cinematic, strings, epic"

### Default Settings
```python
{
    "audio_prompt_type": "",
    "prompt": "[Verse]\\nNeon rain on the city line\\n"
              "You hum the tune and I fall in time\\n"
              "[Chorus]\\nHold me close and keep the time",
    "alt_prompt": "dreamy synth-pop, shimmering pads, soft vocals",
    "scheduler_type": "euler",
    "duration_seconds": 60,
    "repeat_generation": 1,
    "video_length": 0,
    "num_inference_steps": 8,
    "negative_prompt": "",
    "temperature": 1.0,
    "guidance_scale": 1.0,
    "multi_prompts_gen_type": 2,
    "audio_scale": 0.5
}
```

## Language Model (LM) Integration

ACE Step v1.5 supports optional Language Model integration for enhanced text understanding.

### LM Configuration
- **Enable LM**: Set `ace_step15_enable_lm` to `True` in model_def
- **LM Folder**: `acestep-5Hz-lm-1.7B` (default)
- **LM Files Required**:
  - `config.json`
  - `tokenizer.json`
  - `tokenizer_config.json`
  - `special_tokens_map.json`
  - `added_tokens.json`
  - `merges.txt`
  - `vocab.json`
  - `chat_template.jinja`
  - `{lm_folder}_bf16.safetensors` (weights)

### When to Enable LM
- Better lyric understanding
- Improved genre/tag interpretation
- Enhanced coherence in long-form generation
- Trade-off: Slightly slower, more memory

## Model Files & Dependencies

### Repository
- **Repo ID**: DeepBeepMeep/TTS
- **Source Folder**: ace_step15

### Required Files (Base)
- `ace_step15/ace_step_v1_5_audio_vae_bf16.safetensors`
- `ace_step15/silence_latent.pt`

**Text Encoder 2** (Qwen3-Embedding-0.6B):
- `Qwen3-Embedding-0.6B/model.safetensors`
- `Qwen3-Embedding-0.6B/config.json`
- `Qwen3-Embedding-0.6B/tokenizer.json`
- `Qwen3-Embedding-0.6B/tokenizer_config.json`
- `Qwen3-Embedding-0.6B/special_tokens_map.json`

### Optional LM Files
If `ace_step15_enable_lm` is enabled:
- Language Model weights and tokenizer from `acestep-5Hz-lm-1.7B/`

### Configuration Paths
- **Handler File**: `/opt/wan2gp/Wan2GP/models/TTS/ace_step_handler.py` (Lines 1-472)
- **Pipeline File**: `/opt/wan2gp/Wan2GP/models/TTS/ace_step15/pipeline_ace_step15.py`
- **Config Directory**: `/opt/wan2gp/Wan2GP/models/TTS/ace_step15/configs/`

## Lyric Format

### Structure Tags
- `[Verse]` - Verse sections
- `[Chorus]` - Chorus sections
- `[Bridge]` - Bridge sections
- `[Intro]` - Introduction
- `[Outro]` - Ending

### Example Lyric
```
[Verse]
Neon rain on the city line
You hum the tune and I fall in time

[Chorus]
Hold me close and keep the time
Dance with me until the sunrise
```

## Validation Rules
1. **Lyrics**: Cannot be empty
2. **Reference Audio**: Required when "A" mode is selected
3. **Original Lyrics**: Required when using reference audio mode

**Error Messages**:
- "Lyrics prompt cannot be empty for ACE-Step."
- "Reference audio is required for Only Lyrics or Remix modes."

## Reference Audio Modes Explained

### Mode 1: No Reference (Default)
- `audio_prompt_type = ""`
- Pure text-to-music generation
- No audio reference needed
- Fastest generation

### Mode 2: Reference Audio Only
- `audio_prompt_type = "A"`
- Provide reference audio + original lyrics
- Model learns style and continues/remixes
- Set audio_scale for strength control

### Mode 3: Reference Timbre Only
- `audio_prompt_type = "B"`
- Provide reference audio (no lyrics needed)
- Model clones voice/timbre characteristics
- Applies timbre to new lyrics

### Mode 4: Combined Reference
- `audio_prompt_type = "AB"`
- Provide both reference audio and timbre sample
- Maximum control over output
- Best for complex voice cloning + style transfer

## Best Use Cases
1. **Fast Song Generation**: 7.5x faster than v1 (8 steps vs 60)
2. **Voice Timbre Cloning**: Replicate vocal characteristics
3. **Music Remixing**: Remix with separate vocal/instrumental control
4. **Style Transfer**: Apply new styles to existing vocals
5. **Rapid Prototyping**: Quick iterations for music producers
6. **Vocal Separation**: Work with vocals and instrumentals separately
7. **Character Singing**: Create singing voices for characters
8. **AI Covers**: Generate covers with specific vocal timbres

## Advantages over ACE Step v1
- **7.5x Faster**: 8 steps vs 60 steps
- **Temperature Control**: Adjustable randomness
- **Dual Audio References**: Separate vocal and instrumental
- **Timbre Cloning**: Clone voice without lyrics
- **LM Integration**: Optional language model
- **Multiple Variants**: 6 transformer configurations
- **Better Audio Quality**: Advanced VAE architecture

## Limitations
- More complex setup (more components)
- Higher memory usage (especially with LM)
- Requires understanding of reference modes
- Multiple transformer variants can be confusing

## Model Components

### ACEStep15Pipeline Components
1. **ACE Step Transformer**: Main generation model (v1.5)
2. **Text Encoder 2**: Qwen3-Embedding for text understanding
3. **Audio VAE**: Variational auto-encoder for audio encoding
4. **Optional LM Model**: Language model for enhanced text processing
5. **Silence Latent**: Pre-computed silence representation

## LoRA Support
- **LoRA Directory**: `--lora-dir-ace-step15`
- **Default Path**: `{lora_root}/ace_step_v1_5`

## Text Prompt Enhancement
Uses the HEARTMULA_LYRIC_PROMPT enhancer for lyric generation.

## Code References

### Model Definition Function
**File**: `/opt/wan2gp/Wan2GP/models/TTS/ace_step_handler.py` (Lines 115-159)
```python
if _is_ace_step15(base_model_type):
    return {
        "audio_only": True,
        "image_outputs": False,
        "sliding_window": False,
        "guidance_max_phases": 1,
        "no_negative_prompt": True,
        "image_prompt_types_allowed": "",
        "profiles_dir": ["ace_step_v1_5"],
        "text_encoder_folder": _get_model_path(model_def, 
            "text_encoder_folder", ACE_STEP15_LM_FOLDER),
        "inference_steps": True,
        "temperature": True,
        "any_audio_prompt": True,
        "audio_guide_label": "Reference Audio",
        "audio_guide2_label": "Reference Timbre",
        "audio_scale_name": "Reference Audio Strength",
        "audio_prompt_choices": True,
        "enabled_audio_lora": False,
        "audio_prompt_type_sources": {
            "selection": ["", "A", "B", "AB"],
            "labels": {
                "": "No Reference Audio / No Reference Timbre",
                "A": "Reference Audio (need to provide original lyrics "
                     "and set a Reference Audio Strength)",
                "B": "Reference Timbre",
                "AB": "Reference Audio + Timbre",
            },
            "default": "",
            "label": "Reference Sources",
            "letters_filter": "AB",
        },
        # ... additional settings
    }
```

### Pipeline Loading
**File**: `/opt/wan2gp/Wan2GP/models/TTS/ace_step_handler.py` (Lines 259-313)
```python
from .ace_step15.pipeline_ace_step15 import ACEStep15Pipeline

pipeline = ACEStep15Pipeline(
    transformer_weights_path=transformer_weights,
    transformer_config_path=transformer_config,
    vae_weights_path=vae_weights,
    vae_config_path=vae_config,
    text_encoder_2_weights_path=text_encoder_2_weights,
    text_encoder_2_tokenizer_dir=pre_text_tokenizer_dir,
    lm_weights_path=lm_weights,
    lm_tokenizer_dir=lm_tokenizer_dir,
    silence_latent_path=silence_latent,
    enable_lm=enable_lm,
    dtype=dtype or torch.bfloat16,
)
```

## Compilation Support
- **Compile**: No (not compiled)

## Profile Settings
- **Profiles Directory**: `["ace_step_v1_5"]`

## Advanced Configuration Options

### Transformer Variant Selection
Set in model_def:
```python
"ace_step15_transformer_variant": "turbo"  # or "base", "sft", etc.
```

### Enable Language Model
```python
"ace_step15_enable_lm": True
```

### Custom Paths
```python
"ace_step15_transformer_config": "/path/to/config.json"
"ace_step15_vae_weights": "/path/to/vae.safetensors"
"ace_step15_text_encoder_2_weights": "/path/to/encoder.safetensors"
```

## Tips for Best Results
1. **Inference Steps**: 8 steps is optimal; increasing may not improve much
2. **Temperature**: 1.0 is default; lower for consistency, higher for variation
3. **Guidance Scale**: 1.0 works well; adjust if needed for stronger/weaker adherence
4. **Reference Audio Mode**: Start with "B" for simple timbre cloning
5. **Audio Strength**: 0.3-0.7 range usually works best
6. **LM Integration**: Enable for complex lyrics or better genre understanding
7. **Transformer Variant**: Use "turbo" variants for fastest generation

## Comparison Table: ACE Step v1 vs v1.5

| Feature | v1 | v1.5 |
|---------|----|----- |
| Inference Steps | 60 | 8 |
| Speed | 1x | ~7.5x faster |
| Temperature | Fixed (1.0) | Adjustable |
| Reference Audio | Single | Dual (Audio + Timbre) |
| Timbre Cloning | ❌ No | ✅ Yes |
| LM Integration | ❌ No | ✅ Optional |
| Transformer Variants | 1 | 6 |
| Audio Codec | Music DCAE | Audio VAE |
| Audio LoRA | ✅ Yes | ❌ No |
| Complexity | Simple | Advanced |
