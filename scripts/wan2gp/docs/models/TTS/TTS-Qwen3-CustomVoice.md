# Qwen3 TTS - CustomVoice (1.7B)

## Overview
**Model Type**: `qwen3_tts_customvoice`  
**Model Identifier**: Qwen/Qwen3-TTS-12Hz-1.7B-CustomVoice  
**Model Family**: TTS (Text-to-Speech)  
**Parameters**: 1.7 Billion  
**Architecture**: Qwen3TTSForConditionalGeneration  
**Last Updated**: 2/8/2026

## Model Purpose
Qwen3 TTS CustomVoice is a multi-speaker text-to-speech model that provides pre-defined voices with specific characteristics and language support. It allows users to select from a curated set of speaker voices with defined styles and emotional qualities.

## Key Features
- **Pre-defined Speaker Selection**: Choose from 9 distinct speaker voices
- **Multi-language Support**: 12 languages including dialects
- **Style Instructions**: Optional voice style customization per speaker
- **12Hz Speech Tokenization**: High-quality audio encoding
- **Early Stop Support**: Can terminate generation early
- **Temperature Control**: Adjustable randomness in generation
- **Top-K Sampling**: Configurable sampling strategy

## Supported Languages

| Language | Code | ID |
|----------|------|-----|
| Chinese | chinese | 2055 |
| English | english | 2050 |
| Japanese | japanese | 2058 |
| Korean | korean | 2064 |
| German | german | 2053 |
| French | french | 2061 |
| Russian | russian | 2069 |
| Portuguese | portuguese | 2071 |
| Spanish | spanish | 2054 |
| Italian | italian | 2070 |
| Beijing Dialect | beijing_dialect | 2074 |
| Sichuan Dialect | sichuan_dialect | 2062 |

**Auto-detection**: Set language to "auto" for automatic language detection.

## Available Speakers

### Speaker: Serena (ID: 3066)
- **Style**: Warm, gentle young female voice
- **Language**: Chinese
- **Dialect**: No

### Speaker: Vivian (ID: 3065)
- **Style**: Bright, slightly edgy young female voice
- **Language**: Chinese
- **Dialect**: No

### Speaker: Uncle Fu (ID: 3010)
- **Style**: Seasoned male voice with a low, mellow timbre
- **Language**: Chinese
- **Dialect**: No

### Speaker: Ryan (ID: 3061)
- **Style**: Dynamic male voice with strong rhythmic drive
- **Language**: English
- **Dialect**: No

### Speaker: Aiden (ID: 2861)
- **Style**: Sunny American male voice with a clear midrange
- **Language**: English
- **Dialect**: No

### Speaker: Ono Anna (ID: 2873)
- **Style**: Playful Japanese female voice with a light, nimble timbre
- **Language**: Japanese
- **Dialect**: No

### Speaker: Sohee (ID: 2864)
- **Style**: Warm Korean female voice with rich emotion
- **Language**: Korean
- **Dialect**: No

### Speaker: Eric (ID: 2875)
- **Style**: Lively Chengdu male voice with a slightly husky brightness
- **Language**: Chinese (Sichuan Dialect)
- **Dialect**: sichuan_dialect

### Speaker: Dylan (ID: 2878)
- **Style**: Youthful Beijing male voice with a clear, natural timbre
- **Language**: Chinese (Beijing Dialect)
- **Dialect**: beijing_dialect

## Audio Specifications
- **Sample Rate**: 24,000 Hz (24kHz)
- **Output Format**: Audio waveform
- **Tokenization**: 12Hz speech tokens (qwen3_tts_tokenizer_12hz)
- **Audio Only**: Yes (no video output)

## Model Configuration

### Duration Settings
- **Label**: Max duration (seconds)
- **Range**: 1-240 seconds
- **Default**: 20 seconds
- **Increment**: 1 second

### Advanced Parameters
- **Temperature**: Adjustable (default: 0.9)
- **Top-K**: Configurable (default: 50)
- **Guidance Scale**: Not used (no_negative_prompt: true)
- **Inference Steps**: Not configurable (inference_steps: false)

## Usage Parameters

### Required Inputs
- **Prompt**: Text to synthesize (cannot be empty)
- **Speaker**: Must select one of the 9 available speakers
- **Model Mode**: Speaker selection dropdown

### Optional Inputs
- **Instruction (alt_prompt)**: Voice style instructions
  - **Label**: "Instruction (optional)"
  - **Placeholder**: "calm, friendly, slightly husky"
  - **Lines**: 2
  - **Example**: Describe desired voice characteristics, emotion, or speaking style

### Default Settings
```python
{
    "audio_prompt_type": "",
    "model_mode": "serena",  # Default speaker
    "alt_prompt": "",
    "duration_seconds": 20,
    "repeat_generation": 1,
    "video_length": 0,
    "num_inference_steps": 0,
    "negative_prompt": "",
    "temperature": 0.9,
    "top_k": 50,
    "multi_prompts_gen_type": 2
}
```

## Model Files & Dependencies

### Repository
- **Repo ID**: Qwen/Qwen3-TTS-12Hz-1.7B-CustomVoice
- **Config File**: qwen3_tts_customvoice.json

### Required Files
**Text Tokenizer** (from DeepBeepMeep/TTS):
- `qwen3_tts_text_tokenizer/merges.txt`
- `qwen3_tts_text_tokenizer/vocab.json`
- `qwen3_tts_text_tokenizer/tokenizer_config.json`
- `qwen3_tts_text_tokenizer/preprocessor_config.json`

**Speech Tokenizer** (from DeepBeepMeep/TTS):
- `qwen3_tts_tokenizer_12hz/config.json`
- `qwen3_tts_tokenizer_12hz/configuration.json`
- `qwen3_tts_tokenizer_12hz/preprocessor_config.json`
- `qwen3_tts_tokenizer_12hz/qwen3_tts_tokenizer_12hz.safetensors`

### Configuration Paths
- **Config Directory**: `/opt/wan2gp/Wan2GP/models/TTS/qwen3/configs/`
- **Handler File**: `/opt/wan2gp/Wan2GP/models/TTS/qwen3_handler.py` (Lines 1-471)
- **Pipeline File**: `/opt/wan2gp/Wan2GP/models/TTS/qwen3/pipeline.py`

## Validation Rules
1. **Prompt**: Cannot be empty
2. **Speaker**: Must be selected from available speakers
3. **Speaker Validation**: Selected speaker must be in the supported list

**Error Messages**:
- "Prompt text cannot be empty for Qwen3 CustomVoice."
- "Please select a speaker for Qwen3 CustomVoice."
- "Unsupported speaker '{speaker}'."

## Best Use Cases
1. **Multilingual Content**: Projects requiring multiple language support
2. **Character Voices**: Defined character personas in audiobooks or games
3. **Consistent Voiceovers**: Projects needing reliable, reproducible voice characteristics
4. **Asian Language TTS**: Particularly strong in Chinese, Japanese, and Korean
5. **Dialect-Specific Content**: Beijing and Sichuan dialect Chinese content
6. **Style-Customized Speech**: When voice style instructions are needed

## Limitations
- No audio reference/cloning support (unlike Base variant)
- Fixed speaker set (cannot create custom voices)
- No negative prompt support
- Speaker emotions limited to style instructions

## Parent Model
- **Parent**: qwen3_tts_base

## LoRA Support
- **LoRA Directory**: `--lora-dir-qwen3-tts`
- **Default Path**: `{lora_root}/qwen3_tts`

## Text Prompt Enhancement
Uses the TTS_MONOLOGUE_PROMPT enhancer for generating speech-optimized text.

**Enhancement Instructions**:
> "You are a speechwriting assistant. Generate a single-speaker monologue for a text-to-speech model based on the user prompt. Output only the monologue text. Do not include explanations, bullet lists, or stage directions. Keep a consistent tone and point of view. Use natural, spoken sentences with clear punctuation for pauses. Aim for a short monologue (4-8 sentences) unless the prompt asks for a different length."

## Code References

### Handler Registration
**File**: `/opt/wan2gp/Wan2GP/models/TTS/__init__.py`
```python
from . import qwen3_handler
```

### Model Definition Function
**File**: `/opt/wan2gp/Wan2GP/models/TTS/qwen3_handler.py` (Lines 127-153)
```python
def get_qwen3_model_def(base_model_type: str) -> dict:
    if base_model_type == "qwen3_tts_customvoice":
        speakers = get_qwen3_speakers(base_model_type)
        default_speaker = speakers[0] if speakers else ""
        return {
            **common,
            "model_modes": {
                "choices": get_qwen3_speaker_choices(base_model_type),
                "default": default_speaker,
                "label": "Speaker",
            },
            "alt_prompt": {
                "label": "Instruction (optional)",
                "placeholder": "calm, friendly, slightly husky",
                "lines": 2,
            },
        }
```

### Speaker Metadata
**File**: `/opt/wan2gp/Wan2GP/models/TTS/qwen3_handler.py` (Lines 60-96)
```python
QWEN3_TTS_SPEAKER_META = {
    "vivian": {
        "style": "Bright, slightly edgy young female voice",
        "language": "Chinese",
    },
    "serena": {
        "style": "Warm, gentle young female voice",
        "language": "Chinese",
    },
    # ... (additional speakers)
}
```

## Compilation Support
- **Compile**: False (not compiled by default)

## Profile Settings
- **Profiles Directory**: `["qwen3_tts_customvoice"]`
