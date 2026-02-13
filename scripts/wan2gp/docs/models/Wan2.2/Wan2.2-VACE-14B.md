# Wan2.2 VACE 14B

**Full Name:** Video Adaptive ControlNet Edit 14B  
**Parameter Count:** 14 Billion  
**Model Type:** `vace_14B_2_2`  
**Release:** Wan 2.2 series (2025)

## Overview

VACE (Video Adaptive ControlNet) 14B is Wan2GP's most advanced video editing and control model, featuring 14 different control preprocessing modes for precise structural guidance. It combines the power of ControlNet-style conditioning with Wan2.2's high-quality video generation.

## Best Use Cases

- **Precise Video Editing** - Frame-by-frame control using depth, pose, edges
- **Animation Transfer** - Transfer motion/structure from one video to another
- **Multi-Modal Control** - Combine multiple control types (pose + depth + flow)
- **Video Stylization** - Apply artistic styles while preserving structure
- **Architecture Visualization** - Control spatial arrangement with depth maps

## Key Features

- **14 Control Preprocessing Modes** including pose, depth, canny edges, scribble, flow
- **Video-to-Video Editing** with structural preservation
- **Sliding Window Support** for long-form video
- **Black Frame Tolerance** for clean transitions
- **Color Correction** for temporal coherence
- **Motion Amplitude Control**

## Quick Reference

For complete technical details, see: [Wan2.2-ALL-MODELS-CATALOG.md](Wan2.2-ALL-MODELS-CATALOG.md)

**Default Settings:**
- Guidance Scale: 4.0
- Flow Shift: 7.0
- Sliding Window: Enabled
- FPS: 16

**LoRA Categories:**
- Character: 150-200+ LoRAs available
- Style: 100-150+ LoRAs available
- Camera/Util: 50-75+ LoRAs available

---

*For detailed control mode documentation and advanced settings, refer to the complete model catalog.*
