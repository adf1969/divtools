# HeartMula - Keyword-Driven Music Generation (3B)

## Overview
**Model Type**: `heartmula_oss_3b`  
**Model Identifier**: DeepBeepMeep/TTS/HeartMula  
**Model Family**: TTS (Music Generation)  
**Parameters**: 3 Billion  
**Architecture**: HeartMula Music Generationwith HeartCodec  
**Last Updated**: 2/8/2026

## Model Purpose
HeartMula is a keyword-driven music generation model that creates instrumental music based on keywords and tags rather than lyrics. It excels at generating background music, soundtracks, and instrumental pieces controlled by musical descriptors.

## Key Features
- **Keyword-Driven**: Generate music from tags and keywords
- **No Lyrics Required**: Pure instrumental music generation
- **Genre/Mood Control**: Specify style, instruments, emotions
- **Long-Form Generation**: 30-240 seconds (0.5-4 minutes)
- **Temperature Control**: Adjustable randomness
- **Top-K Sampling**: Configurable sampling strategy
- **Codec Guidance**: Fine control over audio generation quality
- **Early Stop Support**: Can terminate generation early

## Audio Specifications
- **Sample Rate**: 48,000 Hz (48kHz)
- **Output Format**: Instrumental music waveform
- **Audio Only**: Yes (no video output)
- **Codec**: HeartCodec (custom audio codec)
- **Max Audio Length**: 120,000 ms (120 seconds) default

## Model Configuration

### Duration Settings
- **Label**: Duration of the Song (in seconds)
- **Range**: 30-240 seconds
- **Default**: 120 seconds
- **Increment**: 0.1 second
- **Note**: Can configure up to 4 minutes

### Codec Settings (model_def configurable)
- **Codec Guidance Scale**: 1.25 (default)
- **Codec Steps**: 10 (default)
- **Codec Version**: Configurable (empty string default)
- **CFG Scale**: 1.5 (default)
- **Top-K**: 50 (default)
- **Max Audio Length**: 120,000 ms (default)

### Advanced Parameters
- **Temperature**: Configurable (default: 1.0)
- **Guidance Scale**: Configurable (default: 1.5)
- **Top-K**: Configurable (default: 50)
- **Inference Steps**: Not displayed (codec-managed)

## Usage Parameters

### Required Inputs
- **Keywords/Tags (alt_prompt)**: Cannot be empty - must provide musical descriptors

### Keywords/Tags (alt_prompt)
- **Label**: "Keywords / Tags"
- **Placeholder**: "piano,happy,wedding"
- **Lines**: 2
- **Format**: Comma-separated keywords
- **Purpose**: Describe musical characteristics

**Keyword Categories**:
1. **Instruments**: piano, guitar, drums, violin, saxophone, synthesizer, bass, flute
2. **Emotions**: happy, sad, energetic, calm, romantic, dramatic, peaceful, intense
3. **Genres**: jazz, classical, rock, electronic, ambient, folk, pop, orchestral
4. **Occasions**: wedding, celebration, meditation, workout, study, sleep, party
5. **Characteristics**: fast, slow, upbeat, mellow, complex, simple, rhythmic, melodic

**Example Keywords**:
- "piano,happy,wedding"
- "guitar,acoustic,peaceful,folk"
- "electronic,energetic,dance,synthesizer"
- "orchestral,dramatic,cinematic,epic"
- "jazz,smooth,saxophone,romantic"
- "ambient,atmospheric,calm,meditation"

### Audio References
- **No Audio Prompts Supported**: HeartMula does not accept reference audio
- **Error if Provided**: "HeartMula does not support reference audio yet."

### Default Settings
```python
{
    "audio_prompt_type": "",
    "alt_prompt": "piano,happy,wedding",
    "repeat_generation": 1,
    "duration_seconds": 120,
    "video_length": 0,
    "num_inference_steps": 0,
    "negative_prompt": "",
    "temperature": 1.0,
    "guidance_scale": 1.5,
    "top_k": 50,
    "multi_prompts_gen_type": 2
}
```

## Model Files & Dependencies

### Repository
- **Repo ID**: DeepBeepMeep/TTS
- **Source Folder**: HeartMula

### Required Files
**Base Model**:
- `HeartMula/gen_config.json`
- `HeartMula/tokenizer.json`

**Codec** (version-dependent):
- `HeartMula/codec_config.json` (or `codec_config_{version}.json`)
- `HeartMula/HeartMula_codec.safetensors` (or `HeartMula_codec_{version}.safetensors`)

**Note**: Codec files vary based on `heartmula_codec_version` setting.

### Configuration Paths
- **Handler File**: `/opt/wan2gp/Wan2GP/models/TTS/heartmula_handler.py` (Lines 1-213)
- **Pipeline File**: `/opt/wan2gp/Wan2GP/models/TTS/HeartMula/pipeline.py`
- **HeartMula Module**: `/opt/wan2gp/Wan2GP/models/TTS/HeartMula/heartmula/`
- **HeartCodec Module**: `/opt/wan2gp/Wan2GP/models/TTS/HeartMula/heartcodec/`

## Validation Rules
1. **Keywords**: Cannot be empty (alt_prompt required)
2. **No Audio References**: Does not support reference audio

**Error Messages**:
- "Keywords prompt cannot be empty for HeartMuLa."
- "HeartMuLa does not support reference audio yet."

## Best Use Cases
1. **Background Music**: Generate background music for videos, podcasts, streams
2. **Game Soundtracks**: Create adaptive music for games
3. **Video Production**: Quick soundtrack generation for videos
4. **Meditation/Relaxation**: Ambient and calming music
5. **Stock Music**: Generate royalty-free music tracks
6. **Mood Playlists**: Create music matching specific emotions
7. **Commercial Production**: Jingles and commercial music
8. **Film Scoring**: Rough drafts and temp tracks for film
9. **Music Prototyping**: Quick musical ideas and sketches

## Strengths
- **Keyword Control**: Simple, intuitive control via tags
- **No Lyrics Needed**: Pure instrumental generation
- **Long-Form**: Up to 4 minutes per generation
- **High Quality**: 48kHz output
- **Versatile**: Wide range of styles and moods
- **Fast**: No complex lyric processing

## Limitations
- No vocal or singing capability (instrumental only)
- No audio reference support (cannot remix or clone)
- Keywords only (no detailed musical notation)
- Fixed codec settings (unless configured in model_def)
- No negative prompt support

## Model Components

### HeartMuLaPipeline Components
1. **HeartMula Model (mula)**: Main music generation transformer
2. **Decoder**: Music decoding component
3. **Backbone Layers**: Core processing layers
4. **HeartCodec**: Audio encoding/decoding codec

### Co-Tenant Model Structure
HeartMula uses a co-tenant architecture:
```python
pipe = {
    "pipe": {
        "transformer": pipeline.mula,
        "transformer2": pipeline.mula.decoder[0],
        "codec": pipeline.codec,
    },
    "coTenantsMap": {
        "transformer": ["transformer2"],
        "transformer2": ["transformer"],
    },
}
```

**Budget Allocation** (for profiles 2, 4, 5):
- transformer2: 200 MB budget

## LoRA Support
- **LoRA Directory**: `--lora-heart_mula`
- **Default Path**: `{lora_root}/heart_mula`

## Text Prompt Enhancement
Uses the HEARTMULA_LYRIC_PROMPT enhancer (though HeartMula is instrumental-focused).

## Code References

### Model Definition
**File**: `/opt/wan2gp/Wan2GP/models/TTS/heartmula_handler.py` (Lines 9-35)
```python
def _get_heartmula_model_def():
    return {
        "audio_only": True,
        "image_outputs": False,
        "sliding_window": False,
        "guidance_max_phases": 1,
        "no_negative_prompt": True,
        "inference_steps": False,
        "temperature": True,
        "image_prompt_types_allowed": "",
        "supports_early_stop": True,
        "profiles_dir": ["heartmula_oss_3b"],
        "alt_prompt": {
            "label": "Keywords / Tags",
            "placeholder": "piano,happy,wedding",
            "lines": 2,
        },
        "text_prompt_enhancer_instructions": HEARTMULA_LYRIC_PROMPT,
        "duration_slider": {
            "label": "Duration of the Song (in seconds)",
            "min": 30,
            "max": 240,
            "increment": 0.1,
            "default": 120,
        },
        "top_k_slider": True,
        "heartmula_cfg_scale": 1.5,
        "heartmula_topk": 50,
        "heartmula_max_audio_length_ms": 120000,
        "heartmula_codec_guidance_scale": 1.25,
        "heartmula_codec_steps": 10,
        "heartmula_codec_version": "",
        "compile": False,
    }
```

### Pipeline Loading
**File**: `/opt/wan2gp/Wan2GP/models/TTS/heartmula_handler.py` (Lines 103-148)
```python
from .HeartMula.pipeline import HeartMuLaPipeline

pipeline = HeartMuLaPipeline(
    ckpt_root=ckpt_root,
    device=torch.device("cpu"),
    version=HEARTMULA_VERSION,
    VAE_dtype=VAE_dtype,
    heartmula_weights_path=heartmula_weights_path,
    cfg_scale=model_def.get("heartmula_cfg_scale", 1.5),
    topk=model_def.get("heartmula_topk", 50),
    max_audio_length_ms=model_def.get("heartmula_max_audio_length_ms", 120000),
    codec_steps=model_def.get("heartmula_codec_steps", 10),
    codec_guidance_scale=model_def.get("heartmula_codec_guidance_scale", 1.25),
    codec_version=model_def.get("heartmula_codec_version", ""),
)
```

### Validation Function
**File**: `/opt/wan2gp/Wan2GP/models/TTS/heartmula_handler.py` (Lines 193-200)
```python
@staticmethod
def validate_generative_prompt(base_model_type, model_def, inputs, one_prompt):
    alt_prompt = inputs.get("alt_prompt", "")
    if alt_prompt is None or len(str(alt_prompt).strip()) == 0:
        return "Keywords prompt cannot be empty for HeartMuLa."
    if inputs.get("audio_guide") is not None or inputs.get("audio_guide2") is not None:
        return "HeartMuLa does not support reference audio yet."
    return None
```

## Compilation Support
- **Compile**: False (not compiled)
- **Note**: Decoder and backbone layers have `_compile_me = False` set explicitly

## Profile Settings
- **Profiles Directory**: `["heartmula_oss_3b"]`

## Advanced Configuration

### Model Version
- **Current Version**: "3B"
- **Configurable**: Set in HEARTMULA_VERSION constant

### Codec Configuration
Codec behavior can be customized via model_def:
```python
{
    "heartmula_codec_version": "",  # Codec variant
    "heartmula_codec_steps": 10,  # Codec inference steps
    "heartmula_codec_guidance_scale": 1.25,  # Codec CFG scale
    "heartmula_max_audio_length_ms": 120000,  # Max duration
}
```

### Generation Parameters
```python
{
    "heartmula_cfg_scale": 1.5,  # Classifier-free guidance
    "heartmula_topk": 50,  # Top-K sampling
}
```

## Tips for Best Results

### Keyword Selection
1. **Be Specific**: Use precise instrument names
2. **Combine Categories**: Mix instruments, emotions, genres
3. **Comma-Separated**: Use commas between keywords
4. **2-6 Keywords**: Sweet spot for balanced results
5. **Avoid Contradictions**: Don't use conflicting terms

**Good Examples**:
- ✅ "piano,violin,classical,romantic"
- ✅ "electronic,energetic,drums,synthesizer"
- ✅ "acoustic,guitar,calm,folk,peaceful"
- ✅ "orchestral,epic,dramatic,cinematic"

**Poor Examples**:
- ❌ "music" (too vague)
- ❌ "fast slow happy sad" (contradictory)
- ❌ "pianoguitardrums" (needs commas)

### Duration Selection
- **30-60s**: Short clips, loops, intros
- **60-120s**: Standard background music
- **120-180s**: Extended pieces
- **180-240s**: Long-form compositions

### Generation Parameters
1. **Guidance Scale**:
   - 1.0-1.5: Natural, varied (default 1.5)
   - 1.5-2.5: Stronger keyword adherence
   - 2.5+: Very strong adherence (may reduce musicality)

2. **Temperature**:
   - 0.8-0.9: More consistent
   - 1.0: Balanced (default)
   - 1.1-1.2: More variation

3. **Top-K**:
   - 30-50: Balanced (default 50)
   - 50-100: More diversity
   - Lower: More focused, less variation

### Codec Settings
- **Codec Steps**: 10 is optimal for most cases
- **Codec Guidance**: 1.0-1.5 range recommended
- Higher codec values = longer generation time

## Comparison with Other Music Models

| Feature | HeartMula | ACE Step v1 | ACE Step v1.5 | Yue |
|---------|-----------|-------------|---------------|-----|
| Input | Keywords | Lyrics | Lyrics | Lyrics |
| Vocals | ❌ No | ✅ Yes | ✅ Yes | ✅ Yes |
| Instrumental | ✅ Only | ✅ Yes | ✅ Yes | ✅ Yes |
| Duration | 30-240s | 5-240s | 5-240s | Variable |
| Reference Audio | ❌ No | ⚠️ Remix | ⚠️ Timbre | ⚠️ Optional |
| Best For | BG Music | Songs | Fast Songs | Full Songs |
