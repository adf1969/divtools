# Qwen3 TTS - Base (1.7B)

## Overview
**Model Type**: `qwen3_tts_base`  
**Model Identifier**: Qwen/Qwen3-TTS-12Hz-1.7B-Base  
**Model Family**: TTS (Text-to-Speech)  
**Parameters**: 1.7 Billion  
**Architecture**: Qwen3TTSForConditionalGeneration  
**Last Updated**: 2/8/2026

## Model Purpose
Qwen3 TTS Base is a voice cloning model that can replicate a voice from a reference audio sample. It generates speech in the style and timbre of the provided reference voice, making it ideal for voice cloning applications.

## Key Features
- **Voice Cloning**: Clone any voice from a reference audio sample
- **Reference Audio Required**: Uses audio prompts for voice characteristics
- **Optional Reference Transcript**: Can provide transcript of reference audio for better quality
- **Multi-language Support**: 12 languages with auto-detection
- **12Hz Speech Tokenization**: High-quality audio encoding
- **Early Stop Support**: Can terminate generation early
- **Temperature Control**: Adjustable randomness in generation
- **Top-K Sampling**: Configurable sampling strategy
- **Audio Prompt Support**: Accepts reference audio for voice cloning

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
1. **Prompt**: Text to synthesize (cannot be empty)
2. **Reference Audio**: Audio file with the voice to clone (required)

### Model Modes
- **Label**: "Language"
- **Choices**: All supported languages
- **Default**: "auto"

### Reference Voice Settings
- **Audio Guide Label**: "Reference voice"
- **Audio Prompt Type**: "A" (reference audio)
- **Any Audio Prompt**: Supported

### Reference Transcript (alt_prompt)
- **Label**: "Reference transcript (optional)"
- **Placeholder**: "Okay. Yeah. I respect you, but you blew it."
- **Lines**: 3
- **Purpose**: Provide the transcript of the reference audio for improved quality
- **Optional**: Can be left empty

**Reference Transcript Tips**:
- Transcribe the exact words spoken in the reference audio
- Include natural speech patterns and fillers ("Okay", "Yeah", "Um")
- Helps the model understand speaking style better
- Improves voice cloning accuracy

### Default Settings
```python
{
    "audio_prompt_type": "A",  # Reference audio enabled
    "model_mode": "auto",
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
- **Repo ID**: Qwen/Qwen3-TTS-12Hz-1.7B-Base
- **Config File**: qwen3_tts_base.json

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
2. **Reference Audio**: Must be provided (required for voice cloning)

**Error Messages**:
- "Prompt text cannot be empty for Qwen3 Base voice clone."
- "Qwen3 Base requires a reference audio clip."

## Voice Cloning Workflow

### Step 1: Prepare Reference Audio
- **Format**: Any audio format supported by the system
- **Quality**: Higher quality reference = better cloning results
- **Duration**: 3-10 seconds recommended
- **Content**: Clean speech without background noise preferred
- **Speaker**: Should contain only the voice you want to clone

### Step 2: (Optional) Transcribe Reference Audio
- Write down exactly what is said in the reference audio
- Include natural speech patterns
- Enter in the "Reference transcript" field

### Step 3: Generate Cloned Speech
- Enter the text you want synthesized
- Set language (or use "auto")
- Adjust temperature and top_k if needed
- Generate

## Best Use Cases
1. **Voice Cloning**: Replicating a specific person's voice
2. **Personalized TTS**: Creating custom voices from audio samples
3. **Character Voice Matching**: Matching a character's voice from a sample
4. **Accessibility**: Creating TTS for individuals who have lost their voice
5. **Audiobook Narration**: Cloning a narrator's voice for consistency
6. **Content Localization**: Cloning a voice for multi-language content
7. **Voice Preservation**: Archiving and reproducing historical voices

## Advantages over Other Variants
- **Voice Cloning Capability**: Only Qwen3 variant that supports reference audio
- **Custom Voice Creation**: Create any voice from a sample (no pre-defined limits)
- **Natural Voice Replication**: More natural than VoiceDesign for specific voices
- **Transcript Enhancement**: Optional transcript improves quality

## Limitations
- Requires reference audio (cannot work without it)
- Quality depends on reference audio quality
- May not perfectly replicate highly unique voices
- No negative prompt support
- Cannot blend multiple voices

## Parent Model
- **Parent**: qwen3_tts_base (is the parent for other variants)

## LoRA Support
- **LoRA Directory**: `--lora-dir-qwen3-tts`
- **Default Path**: `{lora_root}/qwen3_tts`

## Text Prompt Enhancement
Uses the TTS_MONOLOGUE_PROMPT enhancer for generating speech-optimized text.

## Code References

### Model Definition Function
**File**: `/opt/wan2gp/Wan2GP/models/TTS/qwen3_handler.py` (Lines 169-185)
```python
if base_model_type == "qwen3_tts_base":
    return {
        **common,
        "model_modes": {
            "choices": get_qwen3_language_choices(base_model_type),
            "default": "auto",
            "label": "Language",
        },
        "alt_prompt": {
            "label": "Reference transcript (optional)",
            "placeholder": "Okay. Yeah. I respect you, but you blew it.",
            "lines": 3,
        },
        "any_audio_prompt": True,
        "audio_guide_label": "Reference voice",
    }
```

### Default Settings
**File**: `/opt/wan2gp/Wan2GP/models/TTS/qwen3_handler.py` (Lines 399-418)
```python
if base_model_type == "qwen3_tts_base":
    ui_defaults.update(
        {
            "audio_prompt_type": "A",
            "model_mode": "auto",
            "alt_prompt": "",
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

### Validation Function
**File**: `/opt/wan2gp/Wan2GP/models/TTS/qwen3_handler.py` (Lines 445-450)
```python
if base_model_type == "qwen3_tts_base":
    if one_prompt is None or len(str(one_prompt).strip()) == 0:
        return "Prompt text cannot be empty for Qwen3 Base voice clone."
    if inputs.get("audio_guide") is None:
        return "Qwen3 Base requires a reference audio clip."
    return None
```

## Compilation Support
- **Compile**: False (not compiled by default)

## Profile Settings
- **Profiles Directory**: `["qwen3_tts_base"]`

## Tips for Best Results
1. **Reference Audio Quality**:
   - Use clean, clear audio
   - Avoid background noise
   - 3-10 seconds of continuous speech works best
   - Higher sample rate = better results

2. **Reference Transcript**:
   - Helps improve accuracy
   - Include exact words and natural speech patterns
   - Not required but recommended

3. **Language Selection**:
   - Use "auto" for mixed-language content
   - Specify language if known for better results

4. **Temperature**:
   - Lower (0.7-0.8) for more consistent cloning
   - Higher (0.9-1.0) for more variation

5. **Generated Text**:
   - Keep prompts natural and conversational
   - Use proper punctuation for pauses
   - Match the style of the reference audio

## Comparison with Other Qwen3 Variants

| Feature | Base | CustomVoice | VoiceDesign |
|---------|------|-------------|-------------|
| Voice Cloning | ✅ Yes | ❌ No | ❌ No |
| Pre-defined Speakers | ❌ No | ✅ 9 speakers | ❌ No |
| Voice Description | ❌ No | ⚠️  Limited | ✅ Yes |
| Reference Audio Required | ✅ Yes | ❌ No | ❌ No |
| Custom Voices | ✅ Unlimited | ❌ Fixed | ✅ Unlimited |
| Best For | Voice cloning | Consistent characters | Creative voice design |
