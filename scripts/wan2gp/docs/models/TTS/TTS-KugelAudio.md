# KugelAudio - Advanced Voice Cloning TTS

## Overview
**Model Type**: `kugelaudio_0_open`  
**Model Identifier**: KugelAudio (from HuggingFace)  
**Model Family**: TTS (Text-to-Speech)  
**Parameters**: 1.5B or 7B (variant-dependent)  
**Architecture**: KugelAudio Transformer  
**Last Updated**: 2/8/2026

## Model Purpose
KugelAudio is an advanced zero-shot voice cloning model that can generate high-quality speech from text using one or two reference audio samples. It supports both single-speaker and multi-speaker (dialogue) generation with natural prosody and emotion.

## Key Features
- **Zero-Shot Voice Cloning**: Clone voices with 1-2 reference samples
- **Multi-Speaker Dialogue**: Generate conversations with 2 distinct voices
- **Pause Control**: Configurable inter-sentence pauses
- **Long-Form Generation**: Up to 600 seconds (10 minutes)
- **Early Stop Support**: Can terminate generation early
- **Temperature Control**: Adjustable randomness
- **Guidance Scale**: CFG for better quality
- **Natural Prosody**: Maintains natural speech patterns

## Audio Specifications
- **Sample Rate**: 24,000 Hz (24kHz)
- **Output Format**: Audio waveform
- **Audio Only**: Yes (no video output)
- **Tokenizer**: KugelAudio text tokenizer

## Model Variants

KugelAudio is available in two sizes:

| Variant | Parameters | Config File |
|---------|------------|-------------|
| **1.5B** | 1.5 Billion | kugelaudio_1.5b.json |
| **7B** | 7 Billion | kugelaudio_7b.json |

**Note**: Larger model provides better quality but requires more resources.

## Model Configuration

### Duration Settings
- **Label**: Max duration (seconds)
- **Range**: 1-600 seconds
- **Default**: 60 seconds
- **Increment**: 1 second
- **Note**: Supports up to 10 minutes of continuous speech

### Pause Settings
- **Label**: Pause between sentences (seconds)
- **Range**: 0.0-several seconds
- **Default**: 0.5 seconds
- **Purpose**: Control natural pauses in speech

### Advanced Parameters
- **Temperature**: Adjustable (default: 1.0)
- **Guidance Scale**: Configurable (default: 3.0)
- **Inference Steps**: Not configurable
- **Early Stop**: Supported

## Usage Parameters

### Voice Cloning Modes
**Audio Prompt Type Sources**:
- **"" (Empty)**: Text only (no voice cloning)
- **"A"**: Voice cloning (1 reference audio)
- **"AB"**: Voice cloning (2 reference audios for multi-speaker)

### Audio Guides
1. **Reference Voice (audio_guide)** (Optional):
   - **Label**: "Reference voice (optional)"
   - **Purpose**: Primary reference voice
   - **Required**: When audio_prompt_type is "A" or "AB"

2. **Second Reference Voice (audio_guide2)** (Optional):
   - **Purpose**: Second voice for multi-speaker dialogue
   - **Required**: Only when audio_prompt_type is "AB"

### Multi-Speaker Dialogue
For multi-speaker generation:
1. Set `audio_prompt_type` to "AB"
2. Provide two reference audio samples
3. Use "Speaker 0:" and "Speaker 1:" tags in prompt

**Multi-Speaker Prompt Format**:
```
Speaker 0: Hello, how are you doing today?
Speaker 1: I'm doing great, thanks for asking!
Speaker 0: That's wonderful to hear.
```

### Default Settings
```python
{
    "audio_prompt_type": "",
    "prompt": "Hello! This is KugelAudio speaking in a clear, friendly voice.",
    "repeat_generation": 1,
    "duration_seconds": 60,
    "pause_seconds": 0.5,
    "video_length": 0,
    "num_inference_steps": 0,
    "negative_prompt": "",
    "temperature": 1.0,
    "guidance_scale": 3.0,
    "multi_prompts_gen_type": 2
}
```

## Model Files & Dependencies

### Repository
- **Repo ID**: DeepBeepMeep/TTS
- **Source Folder**: kugelaudio

### Required Files
**Text Tokenizer** (from DeepBeepMeep/TTS):
- `kugelaudio_text_tokenizer/merges.txt`
- `kugelaudio_text_tokenizer/tokenizer.json`
- `kugelaudio_text_tokenizer/tokenizer_config.json`
- `kugelaudio_text_tokenizer/vocab.json`
- `kugelaudio_text_tokenizer/preprocessor_config.json`

**Model Configuration**:
- `kugelaudio/config.json`
- `kugelaudio/generation_config.json`

### Configuration Paths
- **Handler File**: `/opt/wan2gp/Wan2GP/models/TTS/kugelaudio_handler.py` (Lines 1-212)
- **Pipeline File**: `/opt/wan2gp/Wan2GP/models/TTS/kugelaudio/pipeline.py`
- **Model Inference**: `/opt/wan2gp/Wan2GP/models/TTS/kugelaudio/models/kugelaudio_inference.py`
- **Audio Processor**: `/opt/wan2gp/Wan2GP/models/TTS/kugelaudio/processors/audio_processor.py`
- **Config Directory**: `/opt/wan2gp/Wan2GP/models/TTS/kugelaudio/configs/`

## Validation Rules

### General Validation
1. **Prompt**: Cannot be empty

### Multi-Speaker Validation
1. **Speaker Tags**: If prompt contains "Speaker" or "speaker" tags:
   - Must provide audio samples OR remove speaker tags
   - Error: "Multi-speaker prompts require two reference voice audio samples. Provide a voice sample or remove Speaker tags."

2. **Two-Voice Cloning** (audio_prompt_type = "AB"):
   - Must provide two reference audio files
   - Must include "Speaker 0:" and "Speaker 1:" in prompt
   - Error: "Two-voice cloning requires two reference audio files."
   - Error: "Two-voice cloning requires prompt lines with Speaker 0: and Speaker 1:."

**Error Messages**:
- "Prompt text cannot be empty for KugelAudio."
- "Multi-speaker prompts require two reference voice audio samples. Provide a voice sample or remove Speaker tags."
- "Two-voice cloning requires two reference audio files."
- "Two-voice cloning requires prompt lines with Speaker 0: and Speaker 1:."

## Generation Modes

### Mode 1: Text-Only (No Voice Cloning)
- Set `audio_prompt_type` to ""
- No reference audio needed
- Uses default voice
- Simple monologue generation

### Mode 2: Single-Voice Cloning
- Set `audio_prompt_type` to "A"
- Provide one reference audio
- Clones the reference voice
- All text spoken in cloned voice

### Mode 3: Multi-Speaker Dialogue
- Set `audio_prompt_type` to "AB"
- Provide two reference audios (Speaker 0 and Speaker 1)
- Use speaker tags in prompt
- Generates natural dialogue with distinct voices

## Best Use Cases
1. **Audiobook Narration**: High-quality voice cloning for long-form content
2. **Podcast Creation**: Generate podcast episodes with host voice
3. **Character Dialogue**: Create conversations with distinct character voices
4. **Voice Preservation**: Archive and replicate voices
5. **Content Localization**: Clone voices for different language content
6. **Interactive Stories**: Multi-character narration
7. **Educational Content**: Natural-sounding educational materials
8. **Accessibility**: Custom TTS voices for assistive technology

## Strengths
- **Long-Form Support**: Up to 10 minutes continuous
- **Multi-Speaker**: Natural dialogue generation
- **High Quality**: Excellent voice cloning accuracy
- **Flexible**: 1 or 2 reference voices
- **Pause Control**: Natural speech pacing
- **Early Stop**: Efficient generation

## Limitations
- No explicit language selection (language detection may be automatic)
- Multi-speaker limited to 2 speakers
- Requires reference audio for voice cloning
- No negative prompt support

## Model Components

### KugelAudioPipeline Components
1. **KugelAudio Model**: Main transformer for generation
2. **Audio Processor**: Processes reference audio
3. **Text Tokenizer**: Tokenizes input text
4. **Watermarking**: Optional audio watermarking (disabled in current implementation)

## LoRA Support
- **LoRA Directory**: `--lora-dir-kugelaudio`
- **Default Path**: `{lora_root}/kugelaudio`

## Text Prompt Enhancement
Uses the TTS_MONOLOGUE_OR_DIALOGUE_PROMPT enhancer.

**Enhancement Instructions**:
> "You are a speechwriting assistant. Generate either a single-speaker monologue or a multi-speaker dialogue for a text-to-speech model based on the user prompt. Decide which form best fits the user's instructions. If the user explicitly asks for a dialogue, conversation, interview, debate, or multiple speakers, output a dialogue. Otherwise output a monologue."

## Code References

### Model Definition
**File**: `/opt/wan2gp/Wan2GP/models/TTS/kugelaudio_handler.py` (Lines 23-57)
```python
def _get_kugelaudio_model_def():
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
        "profiles_dir": ["kugelaudio_0_open"],
        "duration_slider": dict(KUGELAUDIO_DURATION_SLIDER),
        "pause_between_sentences": True,
        "any_audio_prompt": True,
        "audio_guide_label": "Reference voice (optional)",
        "audio_prompt_choices": True,
        "audio_prompt_type_sources": {
            "selection": ["", "A", "AB"],
            "labels": {
                "": "Text only",
                "A": "Voice cloning (1 reference audio)",
                "AB": "Voice cloning (2 reference audios)",
            },
            "letters_filter": "AB",
            "default": "",
        },
        "text_prompt_enhancer_instructions": TTS_MONOLOGUE_OR_DIALOGUE_PROMPT,
        "compile": False,
    }
```

### Validation Function
**File**: `/opt/wan2gp/Wan2GP/models/TTS/kugelaudio_handler.py` (Lines 184-212)
```python
@staticmethod
def validate_generative_prompt(base_model_type, model_def, inputs, one_prompt):
    audio_prompt_type = inputs.get("audio_prompt_type", "") or ""
    if one_prompt is None or len(str(one_prompt).strip()) == 0:
        return "Prompt text cannot be empty for KugelAudio."
    text = str(one_prompt)
    if "Speaker" in text or "speaker" in text:
        if "A" not in audio_prompt_type or "B" not in audio_prompt_type:
            return "Multi-speaker prompts require two reference voice audio " \
                   "samples. Provide a voice sample or remove Speaker tags."
    if "B" in audio_prompt_type:
        if inputs.get("audio_guide") is None or inputs.get("audio_guide2") is None:
            return "Two-voice cloning requires two reference audio files."
        if "Speaker 1:" not in text and "speaker 1:" not in text:
            return "Two-voice cloning requires prompt lines with Speaker 0: " \
                   "and Speaker 1:."
    return None
```

## Compilation Support
- **Compile**: False (not compiled by default)

## Profile Settings
- **Profiles Directory**: `["kugelaudio_0_open"]`

## Tips for Best Results

### Reference Audio
- **Duration**: 5-15 seconds ideal
- **Quality**: High quality, low noise
- **Content**: Clear speech, consistent tone
- **Speaker**: Single speaker only per reference

### Single-Voice Cloning
- Use natural, conversational text
- Proper punctuation for pauses
- Keep consistent tone throughout

### Multi-Speaker Dialogue
- Always use "Speaker 0:" and "Speaker 1:" tags
- Alternate speakers naturally
- Keep dialogue lines conversational
- Each speaker should have 2-3+ lines

**Good Multi-Speaker Example**:
```
Speaker 0: Good morning! How can I help you today?
Speaker 1: I'm looking for information about your services.
Speaker 0: I'd be happy to explain. We offer three main packages.
Speaker 1: That sounds interesting. Can you tell me more about the first one?
```

### Duration and Pacing
- **Short Prompts**: 10-30 seconds for quick messages
- **Medium Prompts**: 30-120 seconds for narration
- **Long Prompts**: 120-600 seconds for audiobooks/podcasts
- **Pause**: 0.3-0.7 seconds for natural pacing

### Guidance Scale
- **2.0-3.0**: Natural, balanced (recommended)
- **3.0-5.0**: Stronger text adherence
- **5.0+**: Very strong adherence (may reduce naturalness)

### Temperature
- **0.7-0.9**: Consistent, predictable
- **1.0**: Balanced (default)
- **1.1-1.3**: More variation and natural randomness
