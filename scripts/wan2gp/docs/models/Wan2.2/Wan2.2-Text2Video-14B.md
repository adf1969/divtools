# Wan2.2 Text2Video 14B

**Parameter Count:** 14 Billion  
**Model Type:** `t2v_2_2`  
**Release:** Wan 2.2 series (2025)

## Overview

Wan2.2 Text2Video 14B is the pure text-to-video generation model in the Wan 2.2 family. It creates high-quality videos directly from text prompts without requiring input images.

## Best Use Cases

- **Concept Visualization** - Generate videos from text descriptions
- **Creative Exploration** - Experiment with ideas quickly
- **Scene Generation** - Create backgrounds and environments
- **B-Roll Content** - Generate stock footage from descriptions
- **Animation From Scratch** - Create videos without source imagery

## Key Features

- **Dual Model Architecture** - High-noise and low-noise models for quality
- **Sliding Window Support** - Generate long-form videos
- **Video-to-Video Enhancement** - Refine existing videos with text guidance
- **Motion Control** - Adjust movement dynamics
- **V2I Switch** - Can switch to image mode if needed

## Quick Reference

For complete technical details, see: [Wan2.2-ALL-MODELS-CATALOG.md](Wan2.2-ALL-MODELS-CATALOG.md)

**Default Settings:**
- Guidance Scale: 4.0 (phase 1), 3.0 (phase 2)
- Flow Shift: 12.0
- FPS: 16

**Video Prompt Modes:**
- Text Prompt Only (default)
- `GUV` - Video-to-Video guided by text
- `GVA` - Video-to-Video with mask restriction

**Supported Prompts:**
- Natural language descriptions
- Cinematic terminology
- Style descriptors
- Motion keywords

**LoRA Categories:**
- Character: 150-200+ LoRAs available
- Style: 100-150+ LoRAs available
- Camera/Util: 50-75+ LoRAs available

---

*Text2Video 14B is ideal for pure generative workflows without requiring input images.*
