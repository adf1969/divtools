# Qwen3 TTS - VoiceDesign (1.7B)

## Overview
**Model Type**: `qwen3_tts_voicedesign`  
**Model Identifier**: Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign  
**Model Family**: TTS (Text-to-Speech)  
**Parameters**: 1.7 Billion  
**Architecture**: Qwen3TTSForConditionalGeneration  
**Last Updated**: 2/8/2026

## Model Purpose
Qwen3 TTS VoiceDesign allows users to create custom voices through natural language descriptions. Instead of selecting pre-defined speakers, users describe the desired voice characteristics, and the model generates speech matching that description.

## Key Features
- **Voice Design via Description**: Create voices using natural language instructions
- **No Pre-defined Speakers**: Generate any voice style on demand
- **Multi-language Support**: 12 languages with auto-detection
- **Style Flexibility**: Describe age, gender, tone, emotion, and speaking style
- **12Hz Speech Tokenization**: High-quality audio encoding
- **Early Stop Support**: Can terminate generation early
- **Temperature Control**: Adjustable randomness in generation
- **Top-K Sampling**: Configurable sampling strategy

## Supported Languages

| Language | Code |
|----------|------|
| Auto-detect | auto (default) |
| Chinese | chinese |
| English | english |
| Japanese | japanese |
| Korean | korean |
| German | german |
| French | french |
| Russian | russian |
| Portuguese | portuguese |
| Spanish | spanish |
| Italian | italian |
| Beijing Dialect | beijing_dialect |
| Sichuan Dialect | sichuan_dialect |

**Note**: Languages are loaded from the config file's `codec_language_id` mapping.

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
- **Voice Instruction**: Description of desired voice characteristics

### Model Modes
- **Label**: "Language"
- **Choices**: All supported languages (formatted with labels)
- **Default**: "auto"

### Voice Instruction (alt_prompt)
- **Label**: "Voice instruction"
- **Placeholder**: "young female, warm tone, clear articulation"
- **Lines**: 2
- **Purpose**: Describe the voice you want to create

**Voice Instruction Examples**:
- "young female, warm tone, clear articulation"
- "middle-aged male, deep voice, authoritative"
- "elderly woman, gentle, storytelling voice"
- "teenage boy, energetic, casual speaking style"
- "professional narrator, neutral, clear pronunciation"

### Default Settings
```python
{
    "audio_prompt_type": "",
    "model_mode": "auto",
    "alt_prompt": "young female, warm tone, clear articulation",
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
- **Repo ID**: Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign
- **Config File**: qwen3_tts_voicedesign.json

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
2. **No Audio References**: Does not support audio prompts

**Error Messages**:
- "Prompt text cannot be empty for Qwen3 VoiceDesign."

## Best Use Cases
1. **Custom Character Voices**: Creating unique voices for characters without predefined speakers
2. **Rapid Prototyping**: Quick voice design iterations using descriptions
3. **Flexible Voice Creation**: When you need specific voice characteristics not available in pre-defined speakers
4. **Multi-language Projects**: Automatic language detection for mixed-language content
5. **Voice Casting**: Testing different voice types before committing to voice cloning
6. **Audiobook Production**: Creating distinct voices for different characters via description
7. **Podcast Generation**: Generating host or guest voices with specific characteristics

## Advantages over CustomVoice
- **Unlimited Voice Styles**: Not limited to 9 pre-defined speakers
- **Natural Language Control**: Describe voice instead of selecting from a list
- **Dynamic Voice Creation**: Create new voices on-the-fly
- **More Flexible**: Better suited for creative projects requiring unique voices

## Limitations
- No audio reference support (cannot clone existing voices)
- Voice quality depends on description clarity
- Less predictable than fixed speaker selection
- No negative prompt support

## Parent Model
- **Parent**: qwen3_tts_base

## LoRA Support
- **LoRA Directory**: `--lora-dir-qwen3-tts`
- **Default Path**: `{lora_root}/qwen3_tts`

## Text Prompt Enhancement
Uses the TTS_MONOLOGUE_PROMPT enhancer for generating speech-optimized text.

## Code References

### Model Definition Function
**File**: `/opt/wan2gp/Wan2GP/models/TTS/qwen3_handler.py` (Lines 154-168)
```python
if base_model_type == "qwen3_tts_voicedesign":
    return {
        **common,
        "model_modes": {
            "choices": get_qwen3_language_choices(base_model_type),
            "default": "auto",
            "label": "Language",
        },
        "alt_prompt": {
            "label": "Voice instruction",
            "placeholder": "young female, warm tone, clear articulation",
            "lines": 2,
        },
    }
```

### Default Settings
**File**: `/opt/wan2gp/Wan2GP/models/TTS/qwen3_handler.py` (Lines 379-398)
```python
if base_model_type == "qwen3_tts_voicedesign":
    ui_defaults.update(
        {
            "audio_prompt_type": "",
            "model_mode": "auto",
            "alt_prompt": "young female, warm tone, clear articulation",
            "duration_seconds": get_qwen3_duration_default(),
            "repeat_generation": 1,
            "video_length": 0,
            "num_inference_steps": 0,
            "negative_prompt": "",
            "temperature": 0.9,
            "top_k": 50,
            "multi_prompts_gen_type": 2,
        }
    )
```

## Compilation Support
- **Compile**: False (not compiled by default)

## Profile Settings
- **Profiles Directory**: `["qwen3_tts_voicedesign"]`

## Tips for Voice Instructions
1. **Be Specific**: Include age, gender, tone, and speaking style
2. **Use Descriptive Adjectives**: warm, bright, deep, clear, husky, gentle, energetic
3. **Specify Emotion**: friendly, authoritative, playful, serious, calm
4. **Mention Speaking Style**: conversational, formal, narrative, storytelling
5. **Keep It Concise**: 2-3 descriptive phrases work best
6. **Avoid Contradictions**: Don't request conflicting characteristics

**Good Examples**:
- ✅ "middle-aged female, professional tone, clear articulation, slightly warm"
- ✅ "young male, energetic, conversational, friendly"
- ✅ "elderly narrator, wise, slow-paced, storytelling voice"

**Poor Examples**:
- ❌ "loud quiet fast slow" (contradictory)
- ❌ "voice" (too vague)
- ❌ "sounds like Morgan Freeman" (use base model for voice cloning instead)
