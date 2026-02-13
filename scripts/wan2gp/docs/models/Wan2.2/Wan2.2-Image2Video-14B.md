# Wan2.2 Image2Video 14B

**Parameter Count:** 14 Billion  
**Model Type:** `i2v_2_2`  
**Release:** Wan 2.2 series (2025)

## Overview

Wan2.2 Image2Video 14B is the standard image-to-video generation model in the Wan 2.2 family. It excels at creating smooth, high-quality videos from static images with precise motion control.

## Best Use Cases

- **Photo Animation** - Bring still images to life
- **Scene Extension** - Create video sequences from concept art
- **Character Animation** - Animate character portraits
- **Product Visualization** - Create product demo videos from images
- **Storyboard to Video** - Convert static storyboards to animated sequences

## Key Features

- **Dual Model Architecture** - Separate high-noise and low-noise models for quality
- **Video-to-Video Support** - Extend or modify existing videos
- **Sliding Window** - Generate long-form videos with 1-frame overlap
- **Motion Amplitude Control** - Fine-tune movement intensity (0.0 - 2.0)
- **Color Correction** - Maintain color coherence across frames

## Quick Reference

For complete technical details, see: [Wan2.2-ALL-MODELS-CATALOG.md](Wan2.2-ALL-MODELS-CATALOG.md)

**Default Settings:**
- Guidance Scale: 3.5 (phase 1 & 2)
- Masking Strength: 0.1
- Denoising Strength: 0.9
- Flow Shift: 5.0
- FPS: 16

**Video Prompt Modes:**
- Text & Image Only
- `GUV` - Video-to-Video guided by text/image
- `GVA` - Video-to-Video with mask restriction

**LoRA Categories:**
- Character: 150-200+ LoRAs available
- Style: 100-150+ LoRAs available
- Camera/Util: 50-75+ LoRAs available

---

*For advanced features like anchor images and sliding window configuration, see the SVI 2 Pro variant documentation: [Wan2.2-SVI-Pro-14B.md](Wan2.2-SVI-Pro-14B.md)*
