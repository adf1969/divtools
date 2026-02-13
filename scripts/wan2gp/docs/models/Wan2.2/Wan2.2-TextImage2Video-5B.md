# Wan2.2 TextImage2Video 5B

**Parameter Count:** 5 Billion  
**Model Type:** `ti2v_2_2`  
**Release:** Wan 2.2 series (2025)

## Overview

Wan2.2 TextImage2Video 5B is a hybrid generation model that combines text and image inputs for video creation. It offers a middle ground between pure text-to-video and image-to-video workflows.

## Best Use Cases

- **Guided Generation** - Text description + reference image
- **Style Transfer Videos** - Image style + text motion description
- **Character Consistency** - Reference character + text actions
- **Concept Refinement** - Rough image + detailed text description
- **Efficient Workflows** - Faster than 14B models with dual inputs

## Key Features

- **Hybrid Input** - Accepts both text prompts and images
- **Efficient 5B Architecture** - Faster generation than 14B models
- **Flexible Image Integration** - Use images as style/content reference
- **Lower VRAM Requirements** - Suitable for mid-range GPUs
- **Sliding Window Support** - Generate longer videos

## Quick Reference

For complete technical details, see: [Wan2.2-ALL-MODELS-CATALOG.md](Wan2.2-ALL-MODELS-CATALOG.md)

**Default Settings:**
- Guidance Scale: 4.0
- Flow Shift: 7.0
- FPS: 16

**Input Modes:**
- Text only (degraded quality)
- Image only (limited control)
- Text + Image (optimal)

**VRAM Requirements:**
- 8-12GB VRAM (typical)
- 16GB+ VRAM (recommended for longer videos)

**LoRA Categories:**
- Character: 150-200+ LoRAs available
- Style: 100-150+ LoRAs available
- Camera/Util: 50-75+ LoRAs available

---

*TextImage2Video provides the flexibility of dual inputs with the efficiency of a 5B model.*
