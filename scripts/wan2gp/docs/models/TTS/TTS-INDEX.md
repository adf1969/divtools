# Wan2GP TTS Models - Complete Index

## Overview
This document provides a comprehensive index and comparison of all Text-to-Speech (TTS) and Music Generation models supported by Wan2GP. There are **10 total TTS model variants** across **7 model families**.

**Last Updated**: 2/8/2026

---

## Quick Model Selection Guide

### For Voice/Speech Generation
- **Pre-defined Voices** → [Qwen3 CustomVoice](#qwen3-tts-customvoice)
- **Custom Voice Descriptions** → [Qwen3 VoiceDesign](#qwen3-tts-voicedesign)
- **Voice Cloning (Single Language)** → [Qwen3 Base](#qwen3-tts-base)
- **Multi-Language Voice Cloning** → [Chatterbox](#chatterbox)
- **Dialogue/Multi-Speaker** → [KugelAudio](#kugelaudio)

### For Music Generation
- **Lyrics to Music (Fast)** → [ACE Step v1.5](#ace-step-v15)
- **Lyrics to Music (High Quality)** → [ACE Step v1](#ace-step-v1)
- **Complete Songs with Vocals** → [Yue](#yue)
- **Instrumental/Background Music** → [HeartMula](#heartmula)

---

## TTS Model Families

### Voice/Speech Models (6 variants)
1. **Qwen3 TTS** - 3 variants
   - CustomVoice (9 pre-defined speakers)
   - VoiceDesign (custom voice descriptions)
   - Base (voice cloning)
2. **Chatterbox** - Multi-language voice cloning (23 languages)
3. **KugelAudio** - Advanced zero-shot voice cloning with dialogue support

### Music Generation Models (4 variants)
4. **ACE Step** - 2 versions
   - v1 (60-step high quality)
   - v1.5 (8-step ultra-fast, 6 transformer variants)
5. **HeartMula** - Keyword-driven instrumental music
6. **Yue** - Two-stage lyrics-to-complete-song (with/without audio prompts)

---

## Complete Model Comparison Table

| Model | Type | Parameters | Languages | Voice Cloning | Multi-Speaker | Sample Rate | Audio Prompts | Best For |
|-------|------|------------|-----------|---------------|---------------|-------------|---------------|----------|
| **Qwen3 CustomVoice** | Speech | 1.7B | 12 | ❌ No | ❌ No | 24kHz | ❌ No | Consistent character voices |
| **Qwen3 VoiceDesign** | Speech | 1.7B | 12 | ⚠️ Describe | ❌ No | 24kHz | ❌ No | Creative voice design |
| **Qwen3 Base** | Speech | 1.7B | 12 | ✅ Yes | ❌ No | 24kHz | ✅ Required | Voice cloning |
| **Chatterbox** | Speech | - | 23 | ✅ Yes | ❌ No | Variable | ✅ Required | Multi-language cloning |
| **KugelAudio** | Speech | 1.5B/7B | Auto | ✅ Yes | ✅ 2 speakers | 24kHz | ⚠️ Optional | Dialogue, long-form |
| **ACE Step v1** | Music | - | - | ❌ No | - | 48kHz | ⚠️ Remix | Lyric-based music |
| **ACE Step v1.5** | Music | - | - | ⚠️ Timbre | - | 48kHz | ⚠️ Dual refs | Fast music generation |
| **HeartMula** | Music | 3B | - | ❌ No | - | 48kHz | ❌ No | Instrumental BG music |
| **Yue COT** | Music | 7B+1B | - | ❌ No | - | 44.1kHz | ❌ No | Complete songs |
| **Yue ICL** | Music | 7B+1B | - | ⚠️ Style | - | 44.1kHz | ✅ Optional | Style-guided songs |

---

## Detailed Model Summaries

### Qwen3 TTS CustomVoice
**Model Type**: `qwen3_tts_customvoice`  
**Documentation**: [TTS-Qwen3-CustomVoice.md](TTS-Qwen3-CustomVoice.md)

**Key Features**:
- 9 pre-defined speakers with distinct characteristics
- 12 language support (including dialects)
- Optional voice style instructions
- 1-240 second generation
- 12Hz speech tokenization

**Speakers**:
- **Chinese**: Serena, Vivian, Uncle Fu, Eric (Sichuan), Dylan (Beijing)
- **English**: Ryan, Aiden
- **Japanese**: Ono Anna
- **Korean**: Sohee

**When to Use**: Need reliable, consistent voices with defined characteristics.

**Default Settings**:
```python
temperature: 0.9
top_k: 50
duration: 20s
```

---

### Qwen3 TTS VoiceDesign
**Model Type**: `qwen3_tts_voicedesign`  
**Documentation**: [TTS-Qwen3-VoiceDesign.md](TTS-Qwen3-VoiceDesign.md)

**Key Features**:
- Create voices via natural language descriptions
- No speaker limits
- 12 language support with auto-detection
- Dynamic voice creation
- Same architecture as CustomVoice

**Voice Instruction Examples**:
- "young female, warm tone, clear articulation"
- "middle-aged male, deep voice, authoritative"
- "elderly narrator, wise, slow-paced"

**When to Use**: Need unique voices not available in pre-defined sets.

**Advantages over CustomVoice**: Unlimited voice styles, natural language control.

---

### Qwen3 TTS Base
**Model Type**: `qwen3_tts_base`  
**Documentation**: [TTS-Qwen3-Base.md](TTS-Qwen3-Base.md)

**Key Features**:
- Voice cloning from reference audio
- Required reference audio input
- Optional reference transcript
- 12 language support
- Parent model for other Qwen3 variants

**Requirements**:
- Reference audio sample (3-10 seconds recommended)
- Text to synthesize
- Optional: Transcript of reference audio

**When to Use**: Need to clone a specific voice or create personalized TTS.

**Tips**: Provide reference transcript for better quality.

---

### Chatterbox
**Model Type**: `chatterbox`  
**Documentation**: [TTS-Chatterbox.md](TTS-Chatterbox.md)

**Key Features**:
- 23 language support
- Cross-language voice cloning
- Prosody controls (exaggeration, pace, temperature)
- Emotion control
- No pre-training required

**Supported Languages**:
Arabic, Chinese, Danish, Dutch, English, Finnish, French, German, Greek, Hebrew, Hindi, Italian, Japanese, Korean, Malay, Norwegian, Polish, Portuguese, Russian, Spanish, Swedish, Swahili, Turkish

**Prosody Controls**:
- **Exaggeration**: 0.0-1.0 (emotional intensity)
- **Pace**: 0.0-1.0 (speaking speed)
- **Temperature**: 0.0-1.0 (variation)

**When to Use**: Multi-language projects requiring same voice across languages.

**Limit**: 300 character recommended maximum per prompt.

---

### KugelAudio
**Model Type**: `kugelaudio_0_open`  
**Documentation**: [TTS-KugelAudio.md](TTS-KugelAudio.md)

**Key Features**:
- Zero-shot voice cloning
- Multi-speaker dialogue (2 speakers)
- Long-form support (up to 600 seconds)
- Pause control between sentences
- 1.5B or 7B parameter variants

**Voice Modes**:
- **Text Only**: Default voice
- **1 Reference Audio**: Clone single voice
- **2 Reference Audios**: Multi-speaker dialogue

**Multi-Speaker Format**:
```
Speaker 0: First speaker's dialogue
Speaker 1: Second speaker's dialogue
Speaker 0: First speaker continues
```

**When to Use**: Dialogue generation, long-form audiobooks, podcasts.

**Strengths**: Long-form (10 min), multi-speaker, pause control.

---

### ACE Step v1
**Model Type**: `ace_step_v1`  
**Documentation**: [TTS-ACE-Step-v1.md](TTS-ACE-Step-v1.md)

**Key Features**:
- Lyrics-to-music generation
- Genre/tag control
- Audio remix capability
- 60 inference steps (high quality)
- 5-240 second generation

**Input Format**:
```
[Verse]
Lyric lines here
[Chorus]
Chorus lyrics
```

**Modes**:
- **No Source Audio**: Pure generation
- **Remix Mode**: Remix with source audio + original lyrics

**When to Use**: High-quality music generation, need maximum quality.

**Inference**: 60 steps (slower but higher quality).

---

### ACE Step v1.5
**Model Type**: `ace_step_v1_5`  
**Documentation**: [TTS-ACE-Step-v1.5.md](TTS-ACE-Step-v1.5.md)

**Key Features**:
- **7.5x faster** than v1 (8 steps vs 60)
- Temperature control
- Dual reference audio (vocal + timbre)
- 6 transformer variants
- Optional Language Model integration

**Reference Modes**:
- **No Reference**: Pure generation
- **Reference Audio**: Style transfer with lyrics
- **Reference Timbre**: Voice cloning without lyrics
- **Combined**: Both audio + timbre references

**Transformer Variants**:
- base, sft, turbo, turbo_shift1, turbo_shift3, turbo_continuous

**When to Use**: Fast music generation, need quick iterations.

**Advantages over v1**: Speed, temperature control, timbre cloning.

---

### HeartMula
**Model Type**: `heartmula_oss_3b`  
**Documentation**: [TTS-HeartMula.md](TTS-HeartMula.md)

**Key Features**:
- Keyword-driven instrumental music
- No lyrics required
- 3 billion parameters
- 30-240 second generation
- Top-K and temperature control

**Input Format**: Comma-separated keywords
```
piano,happy,wedding
electronic,energetic,drums,synthesizer
orchestral,epic,dramatic,cinematic
```

**Keyword Categories**:
- Instruments: piano, guitar, drums, violin, saxophone
- Emotions: happy, sad, energetic, calm, romantic
- Genres: jazz, classical, rock, electronic, orchestral
- Occasions: wedding, celebration, meditation, workout

**When to Use**: Background music, soundtracks, instrumental compositions.

**Limitation**: No vocals (instrumental only).

---

### Yue
**Model Type**: `yue`  
**Documentation**: [TTS-Yue.md](TTS-Yue.md)

**Key Features**:
- Two-stage architecture (LLM + Synthesis)
- Complete song generation (vocals + instrumentals)
- Two modes: COT (default) and ICL (with audio prompts)
- 44.1kHz output (CD quality)
- Dual vocoder (vocal + instrumental)

**Required Inputs**:
- Lyrics
- Genres/Tags (both mandatory)

**Modes**:
- **COT (Chain-of-Thought)**: Pure lyrics-to-music (default)
- **ICL (In-Context Learning)**: Style guidance via audio prompts

**Audio Prompt Types (ICL Only)**:
- Mixed audio prompt
- Separate vocal + instrumental prompts
- 30 second max duration

**When to Use**: Complete song generation with vocals and instrumentals.

**Architecture**: Stage 1 (7B LLM) → Musical codes → Stage 2 (1B Synth) → Audio

---

## Feature Comparison Matrix

### Audio Quality

| Model | Sample Rate | Format | Duration Range |
|-------|-------------|--------|----------------|
| Qwen3 (all) | 24kHz | Speech | 1-240s |
| Chatterbox | Variable | Speech | - |
| KugelAudio | 24kHz | Speech | 1-600s |
| ACE Step v1 | 48kHz | Music | 5-240s |
| ACE Step v1.5 | 48kHz | Music | 5-240s |
| HeartMula | 48kHz | Music | 30-240s |
| Yue | 44.1kHz | Music | Variable |

### Control Features

| Model | Temperature | Top-K | Guidance | Inference Steps | Early Stop |
|-------|-------------|-------|----------|-----------------|------------|
| Qwen3 CustomVoice | ✅ Yes | ✅ Yes | ❌ No | ❌ No | ✅ Yes |
| Qwen3 VoiceDesign | ✅ Yes | ✅ Yes | ❌ No | ❌ No | ✅ Yes |
| Qwen3 Base | ✅ Yes | ✅ Yes | ❌ No | ❌ No | ✅ Yes |
| Chatterbox | ✅ Yes | ❌ No | ⚠️ Fixed | ❌ No | ❌ No |
| KugelAudio | ✅ Yes | ❌ No | ✅ Yes | ❌ No | ✅ Yes |
| ACE Step v1 | ❌ No | ❌ No | ✅ Yes | ✅ 60 | ❌ No |
| ACE Step v1.5 | ✅ Yes | ❌ No | ✅ Yes | ✅ 8 | ❌ No |
| HeartMula | ✅ Yes | ✅ Yes | ✅ Yes | ❌ No | ✅ Yes |
| Yue | ✅ Yes | ❌ No | ❌ No | ❌ No | ❌ No |

### Input/Output Capabilities

| Model | Lyrics | Keywords | Description | Audio Reference | Multi-Speaker |
|-------|--------|----------|-------------|-----------------|---------------|
| Qwen3 CustomVoice | ❌ | ❌ | ⚠️ Style | ❌ | ❌ |
| Qwen3 VoiceDesign | ❌ | ❌ | ✅ Voice | ❌ | ❌ |
| Qwen3 Base | ❌ | ❌ | ⚠️ Transcript | ✅ Required | ❌ |
| Chatterbox | ❌ | ❌ | ❌ | ✅ Required | ❌ |
| KugelAudio | ❌ | ❌ | ❌ | ⚠️ Optional | ✅ 2 |
| ACE Step v1 | ✅ | ⚠️ Tags | ❌ | ⚠️ Remix | ❌ |
| ACE Step v1.5 | ✅ | ⚠️ Tags | ❌ | ⚠️ Dual | ❌ |
| HeartMula | ❌ | ✅ Only | ❌ | ❌ | ❌ |
| Yue COT | ✅ | ⚠️ Genres | ❌ | ❌ | ❌ |
| Yue ICL | ✅ | ⚠️ Genres | ❌ | ⚠️ Optional | ❌ |

---

## File Locations

### Handler Files
All TTS handler files are located in:
```
/opt/wan2gp/Wan2GP/models/TTS/
```

| Model Family | Handler File |
|--------------|--------------|
| Qwen3 (all variants) | `qwen3_handler.py` (471 lines) |
| ACE Step (v1 & v1.5) | `ace_step_handler.py` (472 lines) |
| Chatterbox | `chatterbox_handler.py` (198 lines) |
| KugelAudio | `kugelaudio_handler.py` (212 lines) |
| HeartMula | `heartmula_handler.py` (213 lines) |
| Yue | `yue_handler.py` (269 lines) |

### Model Directories

```
/opt/wan2gp/Wan2GP/models/TTS/
├── ace_step/              # ACE Step v1 implementation
├── ace_step15/            # ACE Step v1.5 implementation
├── chatterbox/            # Chatterbox implementation
├── HeartMula/             # HeartMula implementation
├── kugelaudio/            # KugelAudio implementation
├── qwen3/                 # Qwen3 TTS implementation
│   ├── configs/           # Qwen3 configuration files
│   ├── core/              # Core models and tokenizers
│   └── inference/         # Inference modules
├── yue/                   # Yue implementation
├── prompt_enhancers.py    # Shared prompt enhancement utilities
└── __init__.py            # TTS module initialization
```

---

## Configuration Files

### Qwen3 Configs
**Location**: `/opt/wan2gp/Wan2GP/models/TTS/qwen3/configs/`
- `qwen3_tts_customvoice.json`
- `qwen3_tts_voicedesign.json`
- `qwen3_tts_base.json`
- `qwen3_tts_generation_config.json`

### ACE Step 1.5 Configs
**Location**: `/opt/wan2gp/Wan2GP/models/TTS/ace_step15/configs/`
- `ace_step_v1_5_transformer_config_base.json`
- `ace_step_v1_5_transformer_config_sft.json`
- `ace_step_v1_5_transformer_config_turbo.json`
- `ace_step_v1_5_transformer_config_turbo_shift1.json`
- `ace_step_v1_5_transformer_config_turbo_shift3.json`
- `ace_step_v1_5_transformer_config_turbo_continuous.json`
- `ace_step_v1_5_audio_vae_config.json`

### KugelAudio Configs
**Location**: `/opt/wan2gp/Wan2GP/models/TTS/kugelaudio/configs/`
- `kugelaudio_1.5b.json`
- `kugelaudio_7b.json`
- `kugelaudio/config.json`
- `kugelaudio/generation_config.json`

---

## LoRA Support Summary

| Model Family | LoRA Argument | Default Path |
|--------------|---------------|--------------|
| Qwen3 (all) | `--lora-dir-qwen3-tts` | `{lora_root}/qwen3_tts` |
| ACE Step v1 | `--lora-dir-ace-step` | `{lora_root}/ace_step` |
| ACE Step v1.5 | `--lora-dir-ace-step15` | `{lora_root}/ace_step_v1_5` |
| Chatterbox | `--lora-dir-chatterbox` | `{lora_root}/chatterbox` |
| KugelAudio | `--lora-dir-kugelaudio` | `{lora_root}/kugelaudio` |
| HeartMula | `--lora-heart_mula` | `{lora_root}/heart_mula` |
| Yue | `--lora-dir-tts` | `{lora_root}/tts` |

---

## Prompt Enhancement

All TTS models use prompt enhancement for better speech/music generation:

### Enhancement Prompts

**TTS_MONOLOGUE_PROMPT** (Used by: Qwen3 all, Chatterbox):
> Generate a single-speaker monologue for a text-to-speech model. Output only the monologue text. Do not include explanations, bullet lists, or stage directions. Use natural, spoken sentences with clear punctuation for pauses. (4-8 sentences)

**TTS_MONOLOGUE_OR_DIALOGUE_PROMPT** (Used by: KugelAudio):
> Generate either a single-speaker monologue or a multi-speaker dialogue. If user asks for dialogue/conversation, use "Speaker 0:" and "Speaker 1:" format. Otherwise output a monologue.

**HEARTMULA_LYRIC_PROMPT** (Used by: ACE Step v1, v1.5, HeartMula):
> Generate a clean song lyric prompt for a text-to-song model. Output only the lyric text with optional section headers in square brackets ([Verse], [Chorus], [Bridge]). Keep a consistent theme, POV, and rhyme or rhythm where natural. Use short lines that are easy to sing.

**File**: `/opt/wan2gp/Wan2GP/models/TTS/prompt_enhancers.py`

---

## Download Repositories

### HuggingFace Model Repositories

**Speech Models**:
- `Qwen/Qwen3-TTS-12Hz-1.7B-CustomVoice`
- `Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign`
- `Qwen/Qwen3-TTS-12Hz-1.7B-Base`
- `ResembleAI/chatterbox`

**Music Models**:
- `m-a-p/YuE-s1-7B-anneal-en-cot`
- `m-a-p/YuE-s1-7B-anneal-en-icl`
- `m-a-p/YuE-s2-1B-general`
- `m-a-p/xcodec_mini_infer`

**Shared Repository** (Multiple models):
- `DeepBeepMeep/TTS` - Contains:
  - Qwen3 tokenizers (text + speech)
  - ACE Step v1 models and configs
  - ACE Step v1.5 models and configs
  - KugelAudio models
  - HeartMula models

---

## Quick Reference: Model Selection Decision Tree

```
Need TTS/Music?
│
├─ Speech/Voice
│  │
│  ├─ Pre-defined speakers? → Qwen3 CustomVoice
│  ├─ Describe voice? → Qwen3 VoiceDesign
│  ├─ Clone voice? 
│  │  ├─ Single language → Qwen3 Base
│  │  └─ Multi-language → Chatterbox
│  └─ Dialogue/Multi-speaker? → KugelAudio
│
└─ Music
   │
   ├─ With Lyrics?
   │  ├─ Fast (8 steps) → ACE Step v1.5
   │  ├─ Quality (60 steps) → ACE Step v1
   │  └─ Complete songs → Yue
   │
   └─ Keywords only (no lyrics) → HeartMula
```

---

## Performance Characteristics

### Speed (Relative)
**Fastest to Slowest**:
1. ACE Step v1.5 (8 steps) - ⚡⚡⚡⚡⚡
2. Qwen3 models - ⚡⚡⚡⚡
3. KugelAudio - ⚡⚡⚡
4. Chatterbox - ⚡⚡⚡
5. HeartMula - ⚡⚡⚡
6. ACE Step v1 (60 steps) - ⚡⚡
7. Yue (two-stage) - ⚡

### Memory Requirements (Relative)
**Lowest to Highest**:
1. Chatterbox - 💾
2. Qwen3 models (1.7B) - 💾💾
3. KugelAudio 1.5B - 💾💾
4. HeartMula (3B) - 💾💾💾
5. ACE Step models - 💾💾💾
6. KugelAudio 7B - 💾💾💾💾
7. Yue (7B + 1B) - 💾💾💾💾💾

### Quality (Relative)
**All models provide high quality output appropriate for their use case**:
- **Speech**: Qwen3 Base = Chatterbox > KugelAudio > Qwen3 CustomVoice > Qwen3 VoiceDesign
- **Music**: Yue ≥ ACE Step v1 ≥ ACE Step v1.5 > HeartMula (instrumental only)

---

## Common Error Messages

### Qwen3 Models
- "Prompt text cannot be empty for Qwen3 {variant}."
- "Please select a speaker for Qwen3 CustomVoice."
- "Qwen3 Base requires a reference audio clip."

### Chatterbox
- Prompt > 300 chars warning

### KugelAudio
- "Prompt text cannot be empty for KugelAudio."
- "Multi-speaker prompts require two reference voice audio samples."
- "Two-voice cloning requires two reference audio files."
- "Two-voice cloning requires prompt lines with Speaker 0: and Speaker 1:."

### ACE Step
- "Lyrics prompt cannot be empty for ACE-Step."
- "Reference audio is required for Only Lyrics or Remix modes."

### HeartMula
- "Keywords prompt cannot be empty for HeartMuLa."
- "HeartMuLa does not support reference audio yet."

### Yue
- "Lyrics prompt cannot be empty for Yue."
- "Genres prompt cannot be empty for Yue."
- "Audio prompt duration should not exceed 30 seconds."
- "Yue base model does not support audio prompts. Please use Yue ICL."

---

## Integration with Video Models

Several TTS models can be integrated with Wan2GP's video models for audio+video generation:

**Compatible Pairings**:
- Qwen3 + any video model → Narrated videos
- Chatterbox + any video model → Multi-language narration
- ACE Step + video model → Music videos
- Yue + video model → Complete music videos with vocals
- HeartMula + video model → Videosshould with instrumental soundtracks

---

## Additional Resources

### Individual Model Documentation
- [Qwen3 CustomVoice Details](TTS-Qwen3-CustomVoice.md)
- [Qwen3 VoiceDesign Details](TTS-Qwen3-VoiceDesign.md)
- [Qwen3 Base Details](TTS-Qwen3-Base.md)
- [Chatterbox Details](TTS-Chatterbox.md)
- [KugelAudio Details](TTS-KugelAudio.md)
- [ACE Step v1 Details](TTS-ACE-Step-v1.md)
- [ACE Step v1.5 Details](TTS-ACE-Step-v1.5.md)
- [HeartMula Details](TTS-HeartMula.md)
- [Yue Details](TTS-Yue.md)

### Related Documentation
- [Wan2GP Main README](../WAN2GP_README.md)
- [Wan2GP Utilities](../WAN2GP_UTIL_README.md)
- [Debug Options](../DEBUG_OPTIONS.md)
- [All Models Catalog](Wan2.2-ALL-MODELS-CATALOG.md)

---

## Summary Statistics

**Total TTS Model Variants**: 10
- Speech/Voice: 6 variants (Qwen3 x3, Chatterbox, KugelAudio)
- Music Generation: 4 variants (ACE Step x2, HeartMula, Yue)

**Total Model Families**: 7
- Qwen3 TTS (3 variants)
- Chatterbox (1 variant)
- KugelAudio (1 variant)
- ACE Step (2 versions)
- HeartMula (1 variant)
- Yue (2 modes: COT/ICL)

**Language Coverage**:
- Qwen3: 12 languages
- Chatterbox: 23 languages
- KugelAudio: Auto-detection
- Music models: Language-agnostic

**Sample Rate Range**: 24kHz - 48kHz
**Duration Range**: 1 second - 600 seconds (10 minutes)
**Parameter Range**: 1.5B - 7B parameters

---

*For questions or issues with TTS models, refer to individual model documentation or consult the Wan2GP main documentation.*
