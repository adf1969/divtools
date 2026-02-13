# ACE Step v1 - Text-to-Music Generation

## Overview
**Model Type**: `ace_step_v1`  
**Model Identifier**: DeepBeepMeep/TTS/ace_step  
**Model Family**: TTS (Text-to-Speech / Music Generation)  
**Architecture**: ACE Step Transformer with Music DCAE  
**Last Updated**: 2/8/2026

## Model Purpose
ACE Step v1 is a text-to-music generation model that creates music from lyrics and genre/style tags. It can also remix existing audio by providing source audio with original lyrics.

## Key Features
- **Lyrics-to-Music Generation**: Create songs from lyrical text
- **Genre/Tag Control**: Specify music style, instruments, mood
- **Audio Remix Capability**: Remix existing audio with new generation
- **Prompt Audio Strength Control**: Adjustable influence of source audio
- **CFG Guidance**: Classifier-free guidance for better quality
- **Configurable Inference Steps**: Control generation quality vs. speed
- **Audio-only Output**: Generates music without video

## Audio Specifications
- **Sample Rate**: 48,000 Hz (48kHz)
- **Output Format**: Music audio waveform
- **Audio Only**: Yes (no video output)
- **Codec**: Music DCAE (Discrete Cosine Auto-Encoder)

## Model Configuration

### Duration Settings
- **Label**: Duration (seconds)
- **Range**: 5-240 seconds
- **Default**: 60 seconds
- **Increment**: 1 second

### Inference Settings
- **Inference Steps**: Configurable (default: 60)
- **Temperature**: Fixed at 1.0 (not adjustable)
- **Guidance Scale**: Configurable (default: 7.0)
- **Scheduler**: Euler scheduler

## Usage Parameters

### Required Inputs
- **Prompt (Lyrics)**: Cannot be empty - must provide song lyrics
- **Genres/Tags (alt_prompt)**: Musical style and characteristics

### Audio Prompt Modes
**Source Audio Mode** (audio_prompt_type_sources):
- **"" (Empty)**: No Source Audio - Generate new music from scratch
- **"A"**: Remix Audio - Remix existing audio (requires original lyrics and audio prompt strength)

**Audio Guide**:
- **Label**: "Source Audio"
- **Purpose**: Reference audio for remix mode
- **Required**: Only when audio_prompt_type = "A"

**Audio Scale**:
- **Label**: "Prompt Audio Strength"
- **Purpose**: Controls how much the source audio influences the output
- **Default**: 0.5

### Genres/Tags (alt_prompt)
- **Label**: "Genres / Tags"
- **Placeholder**: "disco"
- **Lines**: 2
- **Purpose**: Describe musical style, instruments, mood, genre

**Genre/Tag Examples**:
- "disco"
- "dreamy synth-pop, shimmering pads, soft vocals"
- "rock, electric guitar, energetic drums"
- "jazz, smooth saxophone, upright bass"
- "electronic, ambient, atmospheric pads"

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
    "num_inference_steps": 60,
    "negative_prompt": "",
    "temperature": 1.0,
    "guidance_scale": 7.0,
    "multi_prompts_gen_type": 2,
    "audio_scale": 0.5
}
```

## Model Files & Dependencies

### Repository
- **Repo ID**: DeepBeepMeep/TTS
- **Source Folder**: ace_step

### Required Files
**Base Components**:
- `ace_step/ace_step_v1_transformer_config.json`
- `ace_step/ace_step_v1_music_dcae_f8c8_bf16.safetensors`
- `ace_step/ace_step_v1_dcae_config.json`
- `ace_step/ace_step_v1_music_vocoder_bf16.safetensors`
- `ace_step/ace_step_v1_vocoder_config.json`

**Text Encoder** (umt5_base):
- `umt5_base/umt5_base_bf16.safetensors`
- `umt5_base/config.json`
- `umt5_base/tokenizer.json`
- `umt5_base/tokenizer_config.json`
- `umt5_base/special_tokens_map.json`

### Configuration Paths
- **Handler File**: `/opt/wan2gp/Wan2GP/models/TTS/ace_step_handler.py` (Lines 1-472)
- **Pipeline File**: `/opt/wan2gp/Wan2GP/models/TTS/ace_step/pipeline_ace_step.py`

## Lyric Format

### Structure Tags (Optional but Recommended)
- `[Verse]` - Verse sections
- `[Chorus]` - Chorus sections
- `[Bridge]` - Bridge sections
- `[Intro]` - Introduction
- `[Outro]` - Ending

### Example Lyric Prompt
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
2. **Audio Prompt**: If "A" mode is selected, must provide source audio
3. **Original Lyrics Required**: When using remix mode, need original lyrics

**Error Messages**:
- "Lyrics prompt cannot be empty for ACE-Step."
- "Reference audio is required for Only Lyrics or Remix modes."

## Generation Modes

### Mode 1: Pure Generation (No Source Audio)
- Set `audio_prompt_type` to ""
- Provide lyrics and genres/tags
- Model generates entirely new music

### Mode 2: Remix Mode
- Set `audio_prompt_type` to "A"
- Provide source audio
- Provide original lyrics of source audio
- Set audio_scale (strength)
- Model remixes the audio with new generation

## Best Use Cases
1. **Original Song Creation**: Generate music from scratch with lyrics
2. **Music Remixing**: Create remixes of existing songs
3. **Demo Production**: Quick song demos for composers
4. **Lyric Testing**: Hear how lyrics sound with different musical styles
5. **Style Transfer**: Apply different genres to existing lyrics
6. **Background Music**: Generate instrumental-focused tracks
7. **Experimental Music**: Create unique musical compositions

## Strengths
- High-quality music generation
- Good genre/style adherence
- Remix capability
- Lyric-aware generation
- Long-form music support (up to 240 seconds)

## Limitations
- Fixed temperature (no temperature control)
- Slower inference (60 steps default vs. v1.5's 8)
- BFloat16 precision only
- Requires well-formatted lyrics for best results
- No vocal separation control

## Model Components

### ACEStepPipeline Components
1. **ACE Step Transformer**: Main generation model
2. **Text Encoder**: UMT5 base model for text understanding
3. **Music DCAE**: Discrete Cosine Auto-Encoder for audio encoding
4. **Vocoder**: Converts latent representations to audio

## LoRA Support
- **LoRA Directory**: `--lora-dir-ace-step`
- **Default Path**: `{lora_root}/ace_step`
- **Enabled Audio LoRA**: Yes

## Text Prompt Enhancement
Uses the HEARTMULA_LYRIC_PROMPT enhancer for lyric generation.

**Enhancement Instructions**:
> "You are a lyric-writing assistant. Generate a clean song lyric prompt for a text-to-song model. Output only the lyric text with optional section headers in square brackets (e.g., [Verse], [Chorus], [Bridge], [Intro], [Outro]). Do not include explanations, bullet lists, or tags. Keep a consistent theme, POV, and rhyme or rhythm where natural. Use short lines that are easy to sing."

## Code References

### Model Definition Function
**File**: `/opt/wan2gp/Wan2GP/models/TTS/ace_step_handler.py` (Lines 133-180)
```python
return {
    "audio_only": True,
    "image_outputs": False,
    "sliding_window": False,
    "guidance_max_phases": 1,
    "no_negative_prompt": True,
    "image_prompt_types_allowed": "",
    "profiles_dir": ["ace_step_v1"],
    "text_encoder_URLs": [ACE_STEP_TEXT_ENCODER_URL],
    "text_encoder_folder": ACE_STEP_TEXT_ENCODER_FOLDER,
    "inference_steps": True,
    "temperature": False,
    "any_audio_prompt": True,
    "audio_guide_label": "Source Audio",
    "audio_scale_name": "Prompt Audio Strength",
    "audio_prompt_choices": True,
    "enabled_audio_lora": True,
    # ... additional settings
}
```

### Pipeline Loading
**File**: `/opt/wan2gp/Wan2GP/models/TTS/ace_step_handler.py` (Lines 328-368)
```python
from .ace_step.pipeline_ace_step import ACEStepPipeline

pipeline = ACEStepPipeline(
    transformer_weights_path=transformer_weights,
    transformer_config_path=transformer_config,
    dcae_weights_path=dcae_weights,
    dcae_config_path=dcae_config,
    vocoder_weights_path=vocoder_weights,
    vocoder_config_path=vocoder_config,
    text_encoder_weights_path=text_encoder_weights,
    text_encoder_tokenizer_dir=tokenizer_dir,
    dtype=dtype or torch.bfloat16,
)
```

## Compilation Support
- **Compile**: No (not compiled)

## Profile Settings
- **Profiles Directory**: `["ace_step_v1"]`

## Comparison: ACE Step v1 vs. v1.5

| Feature | v1 | v1.5 |
|---------|----|----- |
| Inference Steps | 60 (slower) | 8 (faster) |
| Temperature Control | ❌ No | ✅ Yes |
| Reference Timbre | ❌ No | ✅ Yes |
| Vocal/Instrumental | Combined | Separate control |
| LM Integration | ❌ No | ✅ Optional |
| Speed | Slower | Much faster |
| Quality | High | High (comparable) |

## Advanced Settings

### Guidance Scale
- Controls adherence to text prompt
- Higher values = stronger text influence
- Default: 7.0
- Recommended range: 5.0-12.0

### Audio Scale (Remix Mode)
- Controls influence of source audio
- 0.0 = Ignore source audio
- 1.0 = Maximum source audio influence
- Default: 0.5

### Scheduler
- Type: Euler
- Fixed (not configurable)

## Tips for Best Results
1. **Lyric Structure**: Use section tags for better song structure
2. **Genre Tags**: Be specific about musical style
3. **Short Lines**: Keep lyric lines concise and singable
4. **Remix Mode**: Provide accurate original lyrics for best remix results
5. **Inference Steps**: Higher steps (60-100) = better quality but slower
6. **Guidance Scale**: Increase for stronger genre adherence
