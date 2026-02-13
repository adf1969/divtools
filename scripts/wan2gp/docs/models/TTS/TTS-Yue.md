# Yue - Two-Stage Lyrics-to-Music Generation

## Overview
**Model Type**: `yue`  
**Model Identifier**: m-a-p/YuE  
**Model Family**: TTS (Music Generation)  
**Architecture**: Two-Stage Generation (Stage 1: LLM, Stage 2: Audio Synthesis)  
**Stage 1 Models**: YuE-s1-7B-anneal-en-cot (default) or YuE-s1-7B-anneal-en-icl (with audio prompt)  
**Stage 2 Model**: YuE-s2-1B-general  
**Last Updated**: 2/8/2026

## Model Purpose
Yue is a two-stage lyrics-to-music generation system that creates complete songs from lyrics and genre tags. It uses a two-stage architecture: Stage 1 generates musical codes from text, and Stage 2 synthesizes high-quality audio. Optionally supports audio prompts for style guidance.

## Key Features
- **Two-Stage Architecture**: Separate stages for musical planning and audio synthesis
- **Lyrics-to-Song**: Generate complete songs from lyrics
- **Genre/Tag Control**: Specify musical style and characteristics
- **Optional Audio Prompts**: Support for vocal and instrumental reference (ICL variant)
- **Segmented Generation**: Generates music in segments for better quality
- **XCodec Integration**: Advanced neural audio codec
- **Dual Vocoder**: Separate vocoders for vocal and instrumental tracks

## Audio Specifications
- **Sample Rate**: 44,100 Hz (44.1kHz)
- **Output Format**: Complete song with vocals and instrumentals
- **Audio Only**: Yes (no video output)
- **Codec**: XCodec Mini (xcodec_mini_infer)
- **Internal Sample Rate**: 16,000 Hz (codec) → upsampled to 44.1kHz

## Model Variants

Yue has two operational modes based on audio prompt support:

| Mode | Stage 1 Model | Audio Prompt Support | Use Case |
|------|---------------|---------------------|----------|
| **COT (Chain-of-Thought)** | YuE-s1-7B-anneal-en-cot | ❌ No | Pure lyrics-to-music (default) |
| **ICL (In-Context Learning)** | YuE-s1-7B-anneal-en-icl | ✅ Yes | Style/voice guidance via audio |

**Selection**: Set `yue_audio_prompt` in model_def to enable ICL mode.

## Model Configuration

### Generation Settings
- **Max New Tokens**: 3000 (default, configurable via `yue_max_new_tokens`)
- **Run N Segments**: 2 (default, configurable via `yue_run_n_segments`)
- **Stage 2 Batch Size**: 4 (default, configurable via `yue_stage2_batch_size`)
- **Segment Duration**: 6 seconds (default, configurable via `yue_segment_duration`)

### Audio Prompt Settings (ICL Mode Only)
- **Prompt Start Time**: 0.0 seconds (default, configurable)
- **Prompt End Time**: 30.0 seconds (default, configurable)
- **Max Prompt Duration**: 30 seconds

### Advanced Parameters
- **Temperature**: Configurable (default: 1.0)
- **Guidance Scale**: Not used (no_negative_prompt: true)
- **Inference Steps**: Not configurable

## Usage Parameters

### Required Inputs
1. **Lyrics Prompt**: Cannot be empty - song lyrics
2. **Genres/Tags (alt_prompt)**: Cannot be empty - musical style descriptors

### Genres/Tags (alt_prompt)
- **Label**: "Genres / Tags"
- **Placeholder**: "pop, dreamy, warm vocal, female, nostalgic"
- **Lines**: 2
- **Format**: Comma-separated descriptors

**Genre/Tag Categories**:
1. **Genres**: pop, rock, jazz, electronic, folk, country, hip-hop, classical, R&B
2. **Mood**: dreamy, energetic, melancholic, uplifting, dark, bright, nostalgic
3. **Vocal Style**: warm vocal, powerful vocal, soft vocal, husky, clear, breathy
4. **Gender**: male, female, mixed
5. **Characteristics**: lo-fi, acoustic, electronic, orchestral, minimal, complex

**Example Tags**:
- "pop, dreamy, warm vocal, female, nostalgic"
- "rock, energetic, powerful vocal, male, electric guitar"
- "jazz, smooth, sultry vocal, female, saxophone"
- "folk, acoustic, soft vocal, storytelling, guitar"

### Audio Prompt Modes (ICL Mode Only)

**Audio Prompt Type Sources**:
- **"" (Empty)**: Lyrics only (no audio reference)
- **"A"**: Mixed audio prompt (vocal + instrumental combined)
- **"AB"**: Vocal + Instrumental prompts (separate samples)

### Audio Guides (ICL Mode Only)
1. **Vocal Prompt (audio_guide)**:
   - **Label**: "Vocal prompt"
   - **Purpose**: Reference for vocal style
   - **Required**: When audio_prompt_type is "A" or "AB"

2. **Instrumental Prompt (audio_guide2)**:
   - **Label**: "Instrumental prompt"
   - **Purpose**: Reference for instrumental style
   - **Required**: When audio_prompt_type is "AB"

### Prompt Time Range (ICL Mode Only)
- **Start Time**: Beginning of audio segment to use
- **End Time**: End of audio segment to use
- **Default**: 0.0 - 30.0 seconds
- **Max Duration**: 30 seconds
- **Purpose**: Extract specific portion of reference audio

### Default Settings
```python
{
    "audio_prompt_type": "",
    "alt_prompt": "pop, dreamy, warm vocal, female, nostalgic",
    "repeat_generation": 1,
    "video_length": 0,
    "num_inference_steps": 0,
    "negative_prompt": "",
    "temperature": 1.0,
    "multi_prompts_gen_type": 2
}
```

## Model Files & Dependencies

### Repositories
Multiple repositories required:
1. **m-a-p/YuE-s1-7B-anneal-en-cot** (or m-a-p/YuE-s1-7B-anneal-en-icl)
2. **m-a-p/YuE-s2-1B-general**
3. **m-a-p/xcodec_mini_infer**

### Required Files

**Stage 1 Model** (YuE-s1):
- `config.json`

**Stage 2 Model** (YuE-s2):
- `config.json`

**MM Tokenizer**:
- `mm_tokenizer_v0.2_hf/tokenizer.model`

**XCodec** (xcodec_mini_infer):
- `vocoder.py`
- `post_process_audio.py`
- `final_ckpt/config.yaml`
- `final_ckpt/ckpt_00360000.pth`
- `decoders/config.yaml`
- `decoders/decoder_131000.pth`
- `decoders/decoder_151000.pth`
- `semantic_ckpts/hf_1_325000/` (directory)

### Configuration Paths
- **Handler File**: `/opt/wan2gp/Wan2GP/models/TTS/yue_handler.py` (Lines 1-269)
- **Pipeline File**: `/opt/wan2gp/Wan2GP/models/TTS/yue/pipeline.py`
- **Codec Manipulator**: `/opt/wan2gp/Wan2GP/models/TTS/yue/codecmanipulator.py`
- **MM Tokenizer**: `/opt/wan2gp/Wan2GP/models/TTS/yue/mmtokenizer.py`
- **Generation Utils**: `/opt/wan2gp/Wan2GP/models/TTS/yue/generation_utils.py`
- **Llama Patched**: `/opt/wan2gp/Wan2GP/models/TTS/yue/llama_patched.py`

## Validation Rules

### General Validation
1. **Lyrics**: Cannot be empty
2. **Genres**: Cannot be empty (alt_prompt required)

### ICL Mode Validation
3. **Audio Prompt A**: Must provide vocal or mixed audio when "A" selected
4. **Audio Prompt B**: Must provide instrumental when "AB" selected
5. **Time Range**: Start time must be less than end time
6. **Duration**: Prompt duration cannot exceed 30 seconds
7. **Type Mismatch**: If audio provided, must select appropriate audio_prompt_type

**Error Messages**:
- "Lyrics prompt cannot be empty for Yue."
- "Genres prompt cannot be empty for Yue."
- "You must provide a vocal or mixed audio prompt for Yue ICL."
- "You must provide an instrumental prompt for Yue ICL."
- "Audio prompt start time must be less than end time."
- "Audio prompt duration should not exceed 30 seconds."
- "Select an audio prompt type for Yue ICL or clear audio prompts."
- "Yue base model does not support audio prompts. Please use Yue ICL."

## Two-Stage Architecture

### Stage 1: Musical Code Generation
- **Model**: 7B parameter LLM (YuE-s1)
- **Input**: Lyrics + Genre Tags (+ optional audio prompts)
- **Output**: Semantic musical codes
- **Purpose**: Plan musical structure, melody, rhythm
- **Max Tokens**: 3000 codes generated

### Stage 2: Audio Synthesis
- **Model**: 1B parameter synthesis model (YuE-s2)
- **Input**: Musical codes from Stage 1
- **Output**: High-quality audio waveform
- **Batch Size**: 4 (processes codes in batches)
- **Segment Duration**: 6 seconds per segment
- **Run N Segments**: 2 (generates 2 segments)

### XCodec Integration
- **Codec Model**: Neural audio codec for encoding/decoding
- **Vocoder Vocal**: Converts codes to vocal audio (44.1kHz)
- **Vocoder Inst**: Converts codes to instrumental audio (44.1kHz)
- **Sample Rate**: 16kHz internal, 44.1kHz output

## Best Use Cases
1. **Original Song Creation**: Generate complete songs from lyrics
2. **Music Composition**: Quick song generation for composers
3. **Demo Production**: Create demos from lyric ideas
4. **Style Transfer (ICL)**: Apply vocal/instrumental style from reference
5. **Genre Exploration**: Experiment with different genres on same lyrics
6. **Songwriting Tool**: Hear how lyrics sound with different styles
7. **Music Education**: Learn song structure and composition
8. **Content Creation**: Background music with vocals for content

## Strengths
- **Complete Songs**: Generates vocals + instrumentals together
- **Two-Stage Quality**: Separate planning and synthesis for better results
- **High Audio Quality**: 44.1kHz output (CD quality)
- **Vocal Capabilities**: Actually generates singing voices
- **Flexible**: Works with or without audio prompts
- **Dual Vocoder**: Separate processing for vocals and instruments

## Limitations
- Complex setup (multiple models, Stage 1 + Stage 2)
- Slower (two-stage processing)
- Requires both lyrics AND genres (both mandatory)
- ICL mode time limit (30 seconds max for prompts)
- Fixed segment generation (not continuously controllable)
- COT mode doesn't support audio prompts
- Higher memory usage (multiple large models)

## Model Components

### YuePipeline Components
1. **Stage 1 Model**: 7B LLM for musical code generation
2. **Stage 2 Model**: 1B synthesis model
3. **Codec Model**: XCodec for audio encoding
4. **Vocoder Vocal**: Vocal track synthesis
5. **Vocoder Inst**: Instrumental track synthesis
6. **MM Tokenizer**: Multi-modal tokenizer

### Co-Tenant Structure
```python
pipe = {
    "transformer": pipeline.model_stage1,
    "transformer2": pipeline.model_stage2,
    "codec_model": pipeline.codec_model,
    "vocoder_vocal": pipeline.vocoder_vocal,
    "vocoder_inst": pipeline.vocoder_inst,
}
```

## LoRA Support
- **LoRA Directory**: `--lora-dir-tts`
- **Default Path**: `{lora_root}/tts`
- **Note**: Generic TTS LoRA directory (shared)

## Code References

### Model Definition
**File**: `/opt/wan2gp/Wan2GP/models/TTS/yue_handler.py` (Lines 24-76)
```python
def _get_yue_model_def(model_def):
    use_audio_prompt = bool(model_def.get("yue_audio_prompt", False))
    yue_def = {
        "audio_only": True,
        "image_outputs": False,
        "sliding_window": False,
        "guidance_max_phases": 0,
        "no_negative_prompt": True,
        "inference_steps": False,
        "temperature": True,
        "image_prompt_types_allowed": "",
        "profiles_dir": ["yue"],
        "alt_prompt": {
            "label": "Genres / Tags",
            "placeholder": "pop, dreamy, warm vocal, female, nostalgic",
            "lines": 2,
        },
        "yue_max_new_tokens": 3000,
        "yue_run_n_segments": 2,
        "yue_stage2_batch_size": 4,
        "yue_segment_duration": 6,
        "yue_prompt_start_time": 0.0,
        "yue_prompt_end_time": 30.0,
    }
    if use_audio_prompt:
        # ICL mode audio prompt settings
        yue_def.update({ ... })
    return yue_def
```

### Pipeline Loading
**File**: `/opt/wan2gp/Wan2GP/models/TTS/yue_handler.py` (Lines 169-190)
```python
from .yue.pipeline import YuePipeline

pipeline = YuePipeline(
    stage1_weights_path=stage1_weights,
    stage2_weights_path=stage2_weights,
    use_audio_prompt=bool(model_def.get("yue_audio_prompt", False)),
    max_new_tokens=model_def.get("yue_max_new_tokens", 200),
    run_n_segments=model_def.get("yue_run_n_segments", 1),
    stage2_batch_size=model_def.get("yue_stage2_batch_size", 10),
    segment_duration=model_def.get("yue_segment_duration", 6),
    prompt_start_time=model_def.get("yue_prompt_start_time", 0.0),
    prompt_end_time=model_def.get("yue_prompt_end_time", 30.0),
)
```

### Validation Function
**File**: `/opt/wan2gp/Wan2GP/models/TTS/yue_handler.py** (Lines 218-269)
```python
@staticmethod
def validate_generative_prompt(base_model_type, model_def, inputs, one_prompt):
    if one_prompt is None or len(str(one_prompt).strip()) == 0:
        return "Lyrics prompt cannot be empty for Yue."
    alt_prompt = inputs.get("alt_prompt", "")
    if alt_prompt is None or len(str(alt_prompt).strip()) == 0:
        return "Genres prompt cannot be empty for Yue."
    
    audio_prompt_type = inputs.get("audio_prompt_type", "") or ""
    if model_def.get("yue_audio_prompt", False):
        # ICL mode validations
        if "A" in audio_prompt_type:
            if inputs.get("audio_guide") is None:
                return "You must provide a vocal or mixed audio prompt for Yue ICL."
            # Time range validations...
        # Additional ICL validations...
    else:
        # COT mode validation
        if inputs.get("audio_guide") is not None or inputs.get("audio_guide2") is not None:
            return "Yue base model does not support audio prompts. Please use Yue ICL."
    return None
```

## Compilation Support
- **Compile**: No (not compiled)

## Profile Settings
- **Profiles Directory**: `["yue"]`

## Advanced Configuration

### Enable ICL Mode (Audio Prompts)
Set in model_def:
```python
"yue_audio_prompt": True
```

### Generation Parameters
```python
{
    "yue_max_new_tokens": 3000,  # Stage 1 token generation limit
    "yue_run_n_segments": 2,  # Number of segments to generate
    "yue_stage2_batch_size": 4,  # Stage 2 batch processing size
    "yue_segment_duration": 6,  # Duration of each segment (seconds)
}
```

### Audio Prompt Time Range
```python
{
    "yue_prompt_start_time": 0.0,  # Start extracting from reference
    "yue_prompt_end_time": 30.0,  # End extraction (max 30 seconds)
}
```

## Tips for Best Results

### Lyrics Format
- Natural song structure (verses, chorus, etc.)
- Short, singable lines
- Clear rhyme scheme (optional but helps)
- Avoid overly complex vocabulary

**Good Lyrics Example**:
```
[Verse]
Walking down the city streets at night
Neon signs reflecting in your eyes
Every moment with you feels so right
Dancing underneath the starlit skies

[Chorus]
Hold me close, don't let me go
In this moment, time moves slow
Our hearts beat as one tonight
Everything just feels so right
```

### Genre/Tag Selection
1. **Be Specific**: Include genre, mood, vocal style, instruments
2. **Vocal Characteristics**: Specify gender and style
3. **2-6 Tags**: Optimal range
4. **Coherent**: Don't mix drastically different genres

**Good Examples**:
- ✅ "pop, uplifting, female vocal, synth, dreamy"
- ✅ "rock, energetic, male vocal, electric guitar, drums"
- ✅ "jazz, smooth, sultry vocal, saxophone, piano"

**Poor Examples**:
- ❌ "music, song" (too vague)
- ❌ "metal death metal punk jazz classical" (incoherent)

### COT vs ICL Mode
**Use COT (default)** when:
- Pure lyrics-to-music generation
- Exploring different interpretations
- No specific vocal/style reference
- Faster generation needed

**Use ICL (audio prompts)** when:
- Want specific vocal timbre
- Have instrumental style reference
- Need consistent voice across generations
- Style matching is critical

### Audio Prompt Selection (ICL)
- **Vocal Prompt**: 5-30 seconds of clear vocals
- **Instrumental Prompt**: 5-30 seconds of instruments only
- **Quality**: High quality, low noise
- **Relevance**: Match the desired output style

### Generation Speed
- Stage 1: Slower (LLM generation)
- Stage 2: Faster (batched synthesis)
- Total time depends on max_tokens and run_n_segments
- More segments = longer generation but potentially better quality

## Comparison with Other Music Models

| Feature | Yue | ACE Step v1.5 | HeartMula |
|---------|-----|---------------|-----------|
| Architecture | Two-Stage (LLM + Synth) | Single-Stage | Single-Stage |
| Vocals | ✅ Yes | ✅ Yes | ❌ No |
| Input | Lyrics + Genres | Lyrics + Tags | Keywords Only |
| Audio Prompts | ⚠️ ICL Only | ✅ Yes | ❌ No |
| Output Quality | 44.1kHz | 48kHz | 48kHz |
| Speed | Slower (2 stages) |Fast | Medium |
| Complexity | High | Medium | Low |
| Best For | Complete songs | Fast songs | BG music |
