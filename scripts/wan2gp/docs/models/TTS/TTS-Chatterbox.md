# Chatterbox - Multi-Language Voice Cloning TTS

## Overview
**Model Type**: `chatterbox`  
**Model Identifier**: ResembleAI/chatterbox  
**Model Family**: TTS (Text-to-Speech)  
**Architecture**: Chatterbox Multi-Language TTS  
**Last Updated**: 2/8/2026

## Model Purpose
Chatterbox is a multi-language text-to-speech model with voice cloning capabilities, supporting 23 languages. It excels at replicating voices from reference audio across different languages while maintaining natural prosody and emotion control.

## Key Features
- **23 Language Support**: Wide language coverage including European, Asian, and Middle Eastern languages
- **Voice Cloning**: Clone any voice from reference audio
- **Cross-Language Cloning**: Clone a voice and speak in different languages
- **Prosody Control**: Adjustable pace, exaggeration, and temperature
- **Emotion Control**: Natural emotion and expression in generated speech
- **No Pre-training Required**: Works out of the box with any reference audio

## Supported Languages

| Code | Language | Code | Language |
|------|----------|------|----------|
| ar | Arabic | he | Hebrew |
| da | Danish | hi | Hindi |
| de | German | it | Italian |
| el | Greek | ja | Japanese |
| en | English | ko | Korean |
| es | Spanish | ms | Malay |
| fi | Finnish | nl | Dutch |
| fr | French | no | Norwegian |
| pl | Polish | tr | Turkish |
| pt | Portuguese | zh | Chinese |
| ru | Russian | | |
| sv | Swedish | | |
| sw | Swahili | | |

**Default Language**: English (en)

## Audio Specifications
- **Sample Rate**: Variable (model-dependent)
- **Output Format**: Audio waveform
- **Audio Only**: Yes (no video output)

## Model Configuration

### Prosody Controls
Chatterbox provides unique prosody control parameters:

1. **Exaggeration** (default: 0.5)
   - Controls emotional intensity and expressiveness
   - Range: 0.0 (flat) to 1.0 (highly expressive)
   - Higher = more dramatic speech

2. **Temperature** (default: 0.8)
   - Controls randomness and variation
   - Range: typically 0.0-1.0
   - Higher = more variation in delivery

3. **Pace** (default: 0.5)
   - Controls speaking speed
   - Range: 0.0 (slow) to 1.0 (fast)
   - 0.5 = normal speaking pace

### Advanced Parameters
- **Guidance Scale**: Fixed at 1.0
- **Inference Steps**: Not configurable (model-dependent)

## Usage Parameters

### Required Inputs
- **Prompt**: Text to synthesize (max 300 characters recommended)
- **Reference Audio (audio_guide)**: Voice to replicate (required)
- **Language**: Select target language

### Model Modes
- **Label**: "Language"
- **Choices**: All 23 supported languages with codes
- **Default**: "en" (English)
- **Format**: "Language Name (Code)"

### Audio Prompt
- **Audio Prompt Type**: "A" (required for voice cloning)
- **Audio Guide Label**: "Voice to Replicate"
- **Any Audio Prompt**: Supported

### Default Settings
```python
{
    "audio_prompt_type": "A",  # Voice cloning enabled
    "model_mode": "en",
    "repeat_generation": 1,
    "video_length": 0,
    "num_inference_steps": 0,
    "negative_prompt": "",
    "exaggeration": 0.5,
    "temperature": 0.8,
    "pace": 0.5,
    "guid_scale": 1.0,
    "multi_prompts_gen_type": 2
}
```

## Model Files & Dependencies

### Repository
- **Repo ID**: ResembleAI/chatterbox
- **Target Folder**: chatterbox

### Required Files
- `ve.safetensors` - Voice encoder
- `t3_mtl23ls_v2.safetensors` - Multi-language TTS model
- `s3gen.pt` - Speech generator
- `grapheme_mtl_merged_expanded_v1.json` - Text processing
- `conds.pt` - Conditioning model
- `Cangjie5_TC.json` - Chinese character support

### Configuration Paths
- **Handler File**: `/opt/wan2gp/Wan2GP/models/TTS/chatterbox_handler.py` (Lines 1-198)
- **Pipeline File**: `/opt/wan2gp/Wan2GP/models/TTS/chatterbox/pipeline.py`
- **TTS Module**: `/opt/wan2gp/Wan2GP/models/TTS/chatterbox/tts.py`
- **MTL TTS Module**: `/opt/wan2gp/Wan2GP/models/TTS/chatterbox/mtl_tts.py`

## Prompt Length Recommendation
- **Maximum**: 300 characters
- **Recommendation**: Keep prompts under 300 characters for best results
- **Warning**: Longer prompts may produce unexpected results

**System Info Message**:
> "It is recommended to use a prompt that has less than 300 characters, otherwise you may get unexpected results."

## Voice Cloning Workflow

### Step 1: Prepare Reference Audio
- **Quality**: High-quality audio preferred
- **Duration**: 3-10 seconds recommended
- **Content**: Clear speech, single speaker
- **Background**: Minimal noise

### Step 2: Select Language
- Choose target language from 23 options
- Can differ from reference audio language
- Model handles cross-language cloning

### Step 3: Adjust Prosody
- **Exaggeration**: Match desired emotional intensity
- **Pace**: Adjust speaking speed
- **Temperature**: Control variation

### Step 4: Generate
- Enter text to synthesize (under 300 chars)
- Generate audio

## Best Use Cases
1. **Multi-Language Content**: Projects requiring multiple languages
2. **Voice Consistency**: Same voice across different languages
3. **Audiobook Narration**: Multi-language audiobooks with consistent narrator
4. **Language Learning**: Native-sounding pronunciation in target language
5. **Localization**: Maintaining brand voice across languages
6. **Character Voices**: Consistent character voices in different languages
7. **Accessibility**: Multi-language accessibility tools
8. **Podcast Production**: Multi-language podcast creation

## Strengths
- **Language Coverage**: 23 languages is extensive
- **Cross-Language**: Clone voice to speak different languages
- **Prosody Control**: Fine-grained control over delivery
- **No Fine-tuning**: Works with any reference audio
- **Natural**: High-quality, natural-sounding output

## Limitations
- **Prompt Length**: 300 character soft limit
- **Fixed Guidance**: Cannot adjust guidance scale
- **No Inference Steps Control**: Fixed inference
- **Reference Required**: Cannot generate without voice reference
- **No Speaker Mixing**: Single voice per generation

## Model Components

### ChatterboxPipeline Components
1. **Voice Encoder (ve)**: Extracts voice characteristics
2. **T3 MTL Model**: Multi-task learning TTS model
3. **S3Gen**: Speech synthesis generator
4. **Conds**: Conditioning model for control
5. **Grapheme Processor**: Text normalization

## LoRA Support
- **LoRA Directory**: `--lora-dir-chatterbox`
- **Default Path**: `{lora_root}/chatterbox`

## Text Prompt Enhancement
Uses the TTS_MONOLOGUE_PROMPT enhancer for generating speech-optimized text.

## Code References

### Supported Languages
**File**: `/opt/wan2gp/Wan2GP/models/TTS/chatterbox_handler.py` (Lines 10-38)
```python
_FALLBACK_SUPPORTED_LANGUAGES = {
    "ar": "Arabic",
    "da": "Danish",
    "de": "German",
    "el": "Greek",
    "en": "English",
    "es": "Spanish",
    "fi": "Finnish",
    "fr": "French",
    "he": "Hebrew",
    "hi": "Hindi",
    "it": "Italian",
    "ja": "Japanese",
    "ko": "Korean",
    "ms": "Malay",
    "nl": "Dutch",
    "no": "Norwegian",
    "pl": "Polish",
    "pt": "Portuguese",
    "ru": "Russian",
    "sv": "Swedish",
    "sw": "Swahili",
    "tr": "Turkish",
    "zh": "Chinese",
}
```

### Model Definition
**File**: `/opt/wan2gp/Wan2GP/models/TTS/chatterbox_handler.py` (Lines 48-68)
```python
def _get_chatterbox_model_def():
    return {
        "audio_only": True,
        "image_outputs": False,
        "sliding_window": False,
        "guidance_max_phases": 0,
        "no_negative_prompt": True,
        "inference_steps": False,
        "temperature": True,
        "image_prompt_types_allowed": "",
        "profiles_dir": ["chatterbox"],
        "audio_guide_label": "Voice to Replicate",
        "model_modes": {
            "choices": _get_language_choices(),
            "default": "en",
            "label": "Language",
        },
        "any_audio_prompt": True,
        "chatterbox_controls": True,
        "text_prompt_enhancer_instructions": TTS_MONOLOGUE_PROMPT,
    }
```

### Default Settings
**File**: `/opt/wan2gp/Wan2GP/models/TTS/chatterbox_handler.py` (Lines 157-173)
```python
@staticmethod
def update_default_settings(base_model_type, model_def, ui_defaults):
    ui_defaults.update(
        {
            "audio_prompt_type": "A",
            "model_mode": "en",
            "repeat_generation": 1,
            "video_length": 0,
            "num_inference_steps": 0,
            "negative_prompt": "",
            "exaggeration": 0.5,
            "temperature": 0.8,
            "pace": 0.5,
            "guidance_scale": 1.0,
            "multi_prompts_gen_type": 2,
        }
    )
```

### Validation
**File**: `/opt/wan2gp/Wan2GP/models/TTS/chatterbox_handler.py` (Lines 175-182)
```python
@staticmethod
def validate_generative_prompt(base_model_type, model_def, inputs, one_prompt):
    if len(one_prompt) > 300:
        gr.Info(
            "It is recommended to use a prompt that has less than 300 characters,"
            " otherwise you may get unexpected results."
        )
```

## Compilation Support
- **Compile**: No (not compiled)

## Profile Settings
- **Profiles Directory**: `["chatterbox"]`

## Tips for Best Results

### Prosody Settings
1. **Exaggeration**:
   - 0.2-0.4: Neutral, informational speech
   - 0.5: Balanced, natural conversation
   - 0.6-0.8: Expressive, storytelling
   - 0.9-1.0: Highly dramatic, emotional

2. **Pace**:
   - 0.3-0.4: Slow, deliberate (good for learning)
   - 0.5: Normal conversational pace
   - 0.6-0.7: Faster, energetic
   - 0.8-1.0: Very fast (may reduce clarity)

3. **Temperature**:
   - 0.6-0.7: Consistent, predictable
   - 0.8: Natural variation (default)
   - 0.9-1.0: More variation, creative

### Reference Audio
- Use clean, clear audio
- 5-10 seconds is ideal
- Single speaker only
- Match language if possible (but not required)

### Text Prompts
- Keep under 300 characters
- Use proper punctuation
- Natural, conversational text works best
- Avoid special characters or formatting
