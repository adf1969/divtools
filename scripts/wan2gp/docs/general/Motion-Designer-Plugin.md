# Motion Designer Plugin - Comprehensive Technical Documentation

**Last Updated:** 2/8/2026 12:30:00 PM CST

## Table of Contents
1. [Overview](#overview)
2. [What is Motion Designer?](#what-is-motion-designer)
3. [Model Compatibility](#model-compatibility)
4. [Why Use Motion Designer?](#why-use-motion-designer)
5. [Core Features](#core-features)
6. [Operating Modes](#operating-modes)
7. [User Workflow](#user-workflow)
8. [UI Controls and Options](#ui-controls-and-options)
9. [Technical Architecture](#technical-architecture)
10. [Export Formats](#export-formats)

---

## Overview

Motion Designer is a sophisticated visual editor plugin for Wan2GP that enables users to create complex object animations through an intuitive canvas-based interface. It allows users to cut objects from images, design motion trajectories, preview animations in real-time, and export directly to the WanGP video generation pipeline.

**Plugin Information:**
- **Name:** Motion Designer
- **Version:** 1.0.0
- **Type:** WAN2GP Plugin
- **Location:** `/opt/wan2gp/Wan2GP/plugins/wan2gp-motion-designer/`
- **Interface:** Embedded iframe with JavaScript-based canvas editor

---

## What is Motion Designer?

Motion Designer is a **comprehensive animation design tool** that bridges the gap between static images and AI-generated video. Instead of relying solely on text prompts or simple image uploads, Motion Designer gives users precise control over:

- **Object Selection**: Define exactly which parts of an image should move
- **Motion Paths**: Draw custom trajectories for objects to follow
- **Animation Parameters**: Control scale, rotation, speed, and timing
- **Real-time Preview**: See animations play out before generating video
- **Direct Integration**: Export motion masks and trajectories directly to WanGP models

The plugin operates as a **visual motion control layer** that sits between the user's creative intent and the AI video generation models, providing granular control that would be difficult or impossible to achieve through text prompts alone.

---

## Model Compatibility

Motion Designer is **NOT model-specific** — it's designed as a **universal motion authoring tool** that adapts to different model architectures. The plugin automatically switches modes based on the active model:

### Supported Model Types and Modes

| Model Type | Mode | Description |
|------------|------|-------------|
| **i2v (I2V/TTM)** | Cut & Drag | Models supporting separate mask and guide videos |
| **Vace** | Classic | Vision-Aware Contour-Editing models using guide videos |
| **Wan-Move (i2v_trajectory)** | Trajectory | Models using trajectory points (.npy format) |

### Model Detection Logic

The plugin queries the active model definition to determine mode:
- `model_def.get("i2v_v2v")` → Cut & Drag mode
- `model_def.get("vace_class")` → Classic mode  
- `model_def.get("i2v_trajectory")` → Trajectory mode

This **adaptive architecture** means Motion Designer works across the entire WanGP model ecosystem, automatically adjusting its interface and output format to match the selected model's requirements.

---

## Why Use Motion Designer?

### Problems It Solves

1. **Precise Motion Control**
   - Text prompts alone can't specify exact trajectories
   - Motion Designer provides pixel-perfect path definition
   - Users can preview and refine before committing to expensive generation

2. **Complex Multi-Object Animation**
   - Control multiple objects independently
   - Different start/end frames for each object
   - Individual scale, rotation, and speed profiles per object

3. **Workflow Efficiency**
   - Integrated preview eliminates guesswork
   - Direct export to WanGP models (no manual file handling)
   - Saves iteration time by getting motion right before generation

4. **Background Inpainting**
   - Automatically fills areas where objects are removed
   - Supports custom background replacement
   - Creates clean motion masks for video generation

5. **Speed and Easing Control**
   - Advanced speed profiles (accelerate/decelerate)
   - Spline tension controls for smooth curves
   - Frame-accurate timing control

---

## Core Features

### 1. Canvas-Based Visual Editor
- **Resolution Control**: Set output dimensions (128-4096px)
- **Fit Modes**: Cover (scale & crop) or Contain (fit & pad)
- **Multi-layer Support**: Work with multiple objects simultaneously
- **Real-time Rendering**: See changes instantly on canvas

### 2. Object Shape Definition
Three shape tools available:
- **Rectangle**: Click and drag to define rectangular objects
- **Polygon**: Click to place vertices, create arbitrary shapes
- **Circle**: Click and drag to create circular objects

### 3. Trajectory System
- **Path Drawing**: Click to place trajectory waypoints
- **Spline Interpolation**: Smooth curves between points with adjustable tension
- **Speed Profiles**: 5 motion acceleration modes
  - None (constant velocity)
  - Accelerate
  - Decelerate
  - Accelerate → Decelerate
  - Decelerate → Accelerate
- **Speed Ratio**: 1x-100x acceleration factor

### 4. Transform Controls
Per-object animation of:
- **Scale**: Start and end scale values (0.1x - 3x)
- **Rotation**: Start and end rotation (-360° to +360°)
- **Frame Range**: Specify when objects appear/disappear
- **Hide Outside Range**: Automatically hide objects outside their frame range

### 5. Timeline and Playback
- **Scrubbing**: Timeline slider for frame-by-frame navigation
- **Play/Pause**: Preview animation at specified FPS
- **Loop Toggle**: Continuous playback for refinement
- **FPS Control**: 1-120 FPS rendering
- **Frame Count**: 1-2000 frames per animation

### 6. Background Management
- **Auto-Inpainting**: Intelligent fill where objects are cut out
- **Custom Background**: Upload replacement background image
- **Preview Toggle**: Show/hide patched background while editing

### 7. Export Capabilities
- **Send to WanGP**: Direct integration with video generator
- **Download Options**: Save mask videos and background images
- **Definition Save/Load**: Export entire scene as JSON for later editing

---

## Operating Modes

### Mode 1: Cut & Drag (i2v/TTM Models)

**Purpose:** Create motion masks and guide videos for models expecting separate video inputs.

**Workflow:**
1. Upload scene image
2. Draw polygon around object to animate
3. Define trajectory path for object motion
4. Set animation parameters (scale, rotation, speed)
5. Preview animation
6. Export **two videos**:
   - **Mask Video**: Alpha/binary mask showing object region per frame
   - **Guide Video**: Motion visualization for model guidance

**Output Format:**
- Mask: WebM video (VP9/VP8), transcoded to constant frame rate
- Guide: WebM video showing trajectory visualization
- Background: PNG image with objects removed (inpainted)
- Metadata: JSON with FPS, expected frame count, render mode

**Technical Details:**
```python
ui_settings["video_mask"] = "/path/to/mask.webm"
ui_settings["video_guide"] = "/path/to/guide.webm"  
ui_settings["image_start"] = [background_image]
ui_settings["video_mask_meta"] = {"fps": 16, "expectedFrames": 81}
```

---

### Mode 2: Classic (Vace Models)

**Purpose:** Generate guide videos for vision-aware contour-editing models.

**Workflow:**
1. Upload scene image
2. Draw polygon defining object contour
3. Define trajectory for contour motion
4. Adjust **Contour Width** slider (0.5px - 10px)
5. Preview contour animation
6. Export **guide video** showing animated contour

**Output Format:**
- Guide: WebM video of animated contour outline
- Background: Set as first image reference for model
- Metadata: includes contour width and FPS

**Key Difference from Cut & Drag:**
- No separate mask video
- Uses outline/edge visualization instead of filled objects
- Contour width control specific to this mode

**Technical Details:**
```python
ui_settings["video_guide"] = "/path/to/guide.webm"
ui_settings["image_refs"][0] = background_image  # First ref is background
ui_settings["video_guide_meta"] = {"fps": 16, "expectedFrames": 81}
```

---

### Mode 3: Trajectory (Wan-Move Models)

**Purpose:** Export pure trajectory data as numpy arrays for trajectory-based models.

**Workflow:**
1. Upload scene image
2. Click to place trajectory points (no shapes/polygons needed)
3. Repeat for multiple trajectories
4. Set frame ranges per trajectory
5. Export **trajectory array**

**Output Format:**
- Trajectory: `.npy` file containing numpy array [T, N, 2]
  - T = number of frames
  - N = number of trajectories
  - 2 = (x, y) coordinates normalized to [0, 1]
- Background: PNG image set as `image_start`
- Coordinates outside active range: [-1, -1]

**Key Differences:**
- No shape definition required (points only)
- No scale/rotation controls (hidden in UI)
- Coordinates normalized to [0,1] range
- Missing frames filled with [-1, -1]

**Technical Details:**
```python
trajectory_array = np.array(trajectories, dtype=np.float32)  # Shape: [T, N, 2]
np.save(file_path, trajectory_array)
ui_settings["custom_guide"] = "/path/to/trajectory.npy"
ui_settings["image_start"] = [background_image]
```

**Example Trajectory Data:**
```python
# Frame 0: Two trajectories at (0.4, 0.3) and (0.6, 0.5)
# Frame 1: Same trajectories moved
# Frame 2: First trajectory hidden (outside range)
[
    [[0.4, 0.3], [0.6, 0.5]],  # Frame 0
    [[0.42, 0.32], [0.61, 0.51]],  # Frame 1
    [[-1.0, -1.0], [0.62, 0.52]]  # Frame 2
]
```

---

## User Workflow

### General Workflow (All Modes)

```
1. Scene Setup
   ├─ Upload image/video frame
   ├─ Set resolution (width × height)
   ├─ Choose fit mode (cover/contain)
   ├─ Set FPS and total frames
   └─ Mode auto-selected based on active model

2. Object Definition (Skip in Trajectory mode)
   ├─ Choose shape type (rectangle/polygon/circle)
   ├─ Draw shape on canvas
   │  ├─ Rectangle: Click & drag
   │  ├─ Polygon: Click vertices, right-click to close
   │  └─ Circle: Click & drag
   └─ Object automatically cut from image

3. Trajectory Creation
   ├─ Click to place waypoints on canvas
   ├─ Right-click to lock trajectory
   ├─ Adjust tension slider for curve smoothness
   └─ Trajectory shown as colored path with nodes

4. Animation Parameters
   ├─ Set start/end frames for object
   ├─ Adjust scale start/end values
   ├─ Set rotation start/end angles
   ├─ Choose speed profile (none/accel/decel)
   ├─ Adjust speed ratio (1x-100x)
   └─ Toggle "hide outside range"

5. Preview & Refine
   ├─ Scrub timeline to check positions
   ├─ Press Play to see full animation
   ├─ Toggle "Preview Mask" to see render output
   ├─ Adjust parameters and re-preview
   └─ Toggle background visibility as needed

6. Multi-Object Scenes (Optional)
   ├─ Add another object (new layer created)
   ├─ Repeat steps 2-4 for each object
   ├─ Each object gets unique color for identification
   └─ Objects can overlap and have different timings

7. Export
   ├─ Click "Send to Video Generator"
   ├─ Plugin renders videos/data in background
   ├─ Progress bar shows export status
   ├─ Automatically transfers to WanGP UI
   └─ Switches to Video Generator tab
```

### Mode-Specific Nuances

**Cut & Drag Mode:**
- Must define both shape AND trajectory
- Exports two videos (mask + guide)
- Background auto-inpainted where objects removed

**Classic Mode:**
- Contour Width slider appears in Scene Settings
- Single guide video export (outline-based)
- Background becomes first image reference

**Trajectory Mode:**
- Skip shape definition entirely
- Just place trajectory points
- Scale/rotation controls hidden
- Export button reads "Export Trajectories"

---

## UI Controls and Options

### Scene Settings Panel

| Control | Type | Range/Options | Description |
|---------|------|---------------|-------------|
| **Image/Video Frame** | File Upload | image/*, video/* | Source scene to work with |
| **Width** | Number | 128-4096 | Output width in pixels |
| **Height** | Number | 128-4096 | Output height in pixels |
| **Update** | Button | - | Apply resolution changes |
| **Fit Mode** | Select | cover, contain | How image fills canvas |
| **FPS** | Number | 1-120 | Frames per second for output |
| **Total Frames** | Number | 1-2000 | Animation duration in frames |
| **Contour Width** | Slider | 0.5-10 px | Outline thickness (Classic mode only) |

### Object Animation Panel

| Control | Type | Range/Options | Description |
|---------|------|---------------|-------------|
| **Start Frame** | Number | 0 - total | When object appears |
| **End Frame** | Number | 0 - total | When object disappears |
| **Hide Outside Range** | Checkbox | on/off | Auto-hide when outside frame range |
| **Scale Start** | Number | 0.1 - 3.0 | Initial object scale |
| **Scale End** | Number | 0.1 - 3.0 | Final object scale |
| **Rotation Start** | Number | -360 to 360° | Initial rotation angle |
| **Rotation End** | Number | -360 to 360° | Final rotation angle |
| **Trajectory Tension** | Slider | 0.0 - 1.0 | Curve smoothness (0=straight, 1=very curved) |
| **Speed Profile** | Select | 5 options | Motion acceleration type |
| **Acceleration Factor** | Slider | 1x - 100x | Speed multiplier for chosen profile |

### Canvas Toolbar

| Control | Description |
|---------|-------------|
| **Timeline Slider** | Scrub through animation frames |
| **Preview Mask** | Toggle between edit view and render preview |
| **Play/Pause** | Start/stop animation playback |
| **Loop** | Continuous playback when enabled |

### Canvas Footer - Object Controls

| Control | Description |
|---------|-------------|
| **Active Object No** | Shows currently selected object number |
| **Shape Selector** | Choose rectangle/polygon/circle (hidden in Trajectory mode) |
| **Delete** | Remove active object entirely |
| **Reset** | Clear polygon or trajectory for active object |
| **Undo** | Remove last point added |

### Canvas Footer - Export Actions

| Button | Description |
|--------|-------------|
| **Send to Video Generator** | Export and transfer to WanGP |
| **Set Default Background** | Upload custom background image |
| **Save Definition** | Export scene as JSON file |
| **Load Definition** | Import previously saved scene |
| **Dark Mode / Light Mode** | Toggle UI theme |
| **Unload** | Clear scene and reset all objects |

---

## Technical Architecture

### Client-Server Communication

```
┌─────────────────────┐
│  Gradio UI (Python) │
│  ┌───────────────┐  │
│  │ Motion Designer│──┼──┐
│  │   Tab         │  │  │
│  └───────────────┘  │  │
└─────────────────────┘  │
                         │ postMessage API
                         │
┌────────────────────────▼────────────────────┐
│  Iframe (JavaScript Application)            │
│  ┌──────────────────────────────────────┐  │
│  │  Canvas Editor (app.js)               │  │
│  │  • State Management                   │  │
│  │  • Rendering Engine                   │  │
│  │  • Event Handlers                     │  │
│  │  • Export Logic                       │  │
│  └──────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
```

### Data Flow for Export

#### Cut & Drag / Classic Mode:
```
1. User clicks "Send to WanGP"
2. JavaScript renders frame-by-frame to canvas
3. MediaRecorder captures canvas as WebM video
4. Video chunks accumulated in memory
5. Blob converted to base64 string
6. postMessage sends to parent window:
   {
     type: "WAN2GP_MOTION_DESIGNER",
     payload: "<base64_video>",
     metadata: {fps: 16, expectedFrames: 81, renderMode: "cut_drag"},
     backgroundImage: "<base64_png>",
     guidePayload: "<base64_guide_video>",
     guideMetadata: {...}
   }
7. Python plugin receives via window.addEventListener
8. Base64 decoded to bytes
9. Saved to mask_outputs/ directory
10. FFmpeg transcodes for constant frame rate
11. Paths set in ui_settings dictionary
12. update_video_prompt_type() called
13. UI switches to Video Generator tab
```

#### Trajectory Mode:
```
1. User clicks "Export Trajectories"
2. JavaScript computes trajectories array [T, N, 2]
3. Coordinates normalized to [0, 1]
4. postMessage sends:
   {
     type: "WAN2GP_MOTION_DESIGNER",
     isTrajectoryExport: true,
     trajectoryData: [[...], [...], ...],
     metadata: {fps: 16, totalFrames: 81},
     backgroundImage: "<base64_png>"
   }
5. Python converts to numpy array
6. Saved as .npy file
7. Path set as ui_settings["custom_guide"]
8. Background set as ui_settings["image_start"]
```

### File Structure

```
/opt/wan2gp/Wan2GP/plugins/wan2gp-motion-designer/
├── __init__.py                    # Plugin registration
├── plugin.py                      # Main plugin class (760 lines)
│   ├── MotionDesignerPlugin class
│   ├── setup_ui()                 # Tab and component registration
│   ├── _build_ui()                # Gradio UI construction
│   ├── _apply_mask()              # Handle mask video export
│   ├── _apply_trajectory()        # Handle trajectory export
│   ├── _transcode_video()         # FFmpeg video processing
│   └── _js_bridge()               # JavaScript bridge code
└── assets/
    ├── app.js                     # Main editor logic (3911 lines)
    │   ├── State management
    │   ├── Canvas rendering
    │   ├── Shape/trajectory tools
    │   ├── Animation engine
    │   ├── Export logic
    │   └── Video recording
    ├── style.css                  # UI styling
    └── motion_designer_iframe_template.html  # HTML shell
```

### Key Python Functions

**`_apply_mask(state, encoded_video, metadata_json, background_image_data, guide_video_data, guide_metadata_json)`**
- Decodes base64 video and guide payloads
- Saves WebM files to `mask_outputs/` directory
- Transcodes videos with FFmpeg for constant frame rate
- Updates `ui_settings` with file paths and metadata
- Calls `update_video_prompt_type()` to set prompt state
- Returns timestamp triggering UI refresh

**`_apply_trajectory(state, trajectory_json, metadata_json, background_data_url)`**
- Parses trajectory JSON array
- Converts to numpy array [T, N, 2]
- Validates shape and dtype
- Saves as `.npy` file
- Sets `custom_guide` path in UI settings
- Decodes and sets background image

**`_transcode_video(source_path, fps)`**
- Uses ffmpeg-python library
- Stream copies video with constant frame rate
- Parameters: `-c copy -r {fps} -vsync cfr -fps_mode cfr`
- Handles errors gracefully with logging
- Returns original path (now transcoded)

### Key JavaScript Functions

**`startExport(mode, variant)`**
- Initializes video export process
- Creates offscreen canvas for rendering
- Configures MediaRecorder with best available codec
- Renders each frame sequentially at specified FPS
- Accumulates video chunks in state.export.chunks

**`computeTrajectoryPosition(layer, progress)`**
- Interpolates position along trajectory path
- Applies spline tension for curve smoothness
- Implements speed profile modifications
- Returns {x, y} coordinates for given progress [0, 1]

**`renderFrame(frameIndex)`**
- Main rendering pipeline for each frame
- Clears canvas and draws background
- For each layer:
  - Checks if visible at current frame
  - Computes trajectory position
  - Applies scale/rotation transforms
  - Renders object or trajectory visualization

**`exportTrajectoryData()`**
- Builds [T, N, 2] array from all trajectory layers
- Normalizes coordinates to [0, 1] range
- Marks hidden frames as [-1, -1]
- Packages with metadata and sends via postMessage

---

## Export Formats

### Mask Video (Cut & Drag Mode)

**Format:** WebM (VP9 or VP8 codec)
**Content:** Binary/alpha mask showing object regions per frame
- White (255) where objects exist
- Black (0) for background/empty areas
- Frame rate stamped into container metadata
- Constant frame rate enforced via FFmpeg transcode

**File Naming:** `motion_designer_mask_YYYYMMDD_HHMMSS.webm`

**Metadata JSON:**
```json
{
  "fps": 16,
  "expectedFrames": 81,
  "renderMode": "cut_drag"
}
```

### Guide Video (Cut & Drag / Classic Modes)

**Format:** WebM (VP9 or VP8 codec)
**Content:** Visual representation of trajectories/contours
- Cut & Drag: Shows object movement visualization
- Classic: Shows animated contour outlines
- Color-coded by object
- Same frame rate as mask video

**File Naming:** `motion_designer_guide_YYYYMMDD_HHMMSS.webm`

### Trajectory Data (Trajectory Mode)

**Format:** NumPy binary (.npy)
**Content:** 3D float32 array [T, N, 2]
- T: Number of frames (e.g., 81)
- N: Number of trajectories (e.g., 3 objects = 3 trajectories)
- 2: (x, y) coordinates normalized to [0.0, 1.0]

**Special Values:**
- `[-1.0, -1.0]` indicates trajectory not visible at this frame
- Coordinates outside [0, 1] are clipped during normalization

**File Naming:** `motion_designer_trajectory_YYYYMMDD_HHMMSS.npy`

**Example Loading:**
```python
import numpy as np
trajectories = np.load("motion_designer_trajectory_20260208_123045.npy")
print(trajectories.shape)  # (81, 3, 2) for 81 frames, 3 trajectories
```

### Background Image (All Modes)

**Format:** PNG
**Content:** Source image with objects removed and inpainted
- Areas where polygons existed are filled intelligently
- Diffusion-based inpainting algorithm (8 passes)
- Feathering at edges (2 passes)
- Alternative: Custom background image if uploaded

**Usage:**
- Cut & Drag: Set as `image_start`
- Classic: Set as first entry in `image_refs` array
- Trajectory: Set as `image_start`

### Definition File (Save/Load Feature)

**Format:** JSON
**Purpose:** Save entire scene for later editing
**Content:**
```json
{
  "version": "1.0",
  "scene": {
    "fps": 16,
    "totalFrames": 81,
    "resolution": {"width": 832, "height": 480},
    "fitMode": "cover"
  },
  "renderMode": "cut_drag",
  "baseImage": "<base64_png>",
  "altBackground": "<base64_png_optional>",
  "layers": [
    {
      "id": "uuid-string",
      "name": "Object 1",
      "color": "#4cc2ff",
      "polygon": [[x, y], [x, y], ...],
      "path": [[x, y], [x, y], ...],
      "startFrame": 0,
      "endFrame": 81,
      "scaleStart": 1.0,
      "scaleEnd": 1.2,
      "rotationStart": 0,
      "rotationEnd": 45,
      "tension": 0.5,
      "speedMode": "accelerate",
      "speedRatio": 2.0,
      "shapeType": "polygon"
    }
  ]
}
```

**Use Cases:**
- Save work in progress
- Share scenes with collaborators
- Template creation for similar scenes
- Backup before major changes

---

## Advanced Features

### Background Inpainting Algorithm

The plugin includes a sophisticated inpainting system for filling areas where objects are cut out:

**Algorithm Steps:**
1. Create binary mask from all closed polygons
2. Feather edges (2 passes) to smooth boundaries
3. Run diffusion-based fill (8 passes)
4. Blend with original image at boundaries
5. Optional: Blend with custom background image

**Code Reference:** `inpaintImageData()` in app.js

### Speed Profile Mathematics

Speed profiles modify trajectory progress using curve functions:

| Profile | Formula | Effect |
|---------|---------|--------|
| None | `progress` | Constant velocity |
| Accelerate | `progress^(1+ratio)` | Slow → fast |
| Decelerate | `1 - (1-progress)^(1+ratio)` | Fast → slow |
| Accel-Decel | Combination of both curves | Slow → fast → slow |
| Decel-Accel | Inverted combination | Fast → slow → fast |

**Ratio Range:** 1x (subtle) to 100x (extreme)

### Spline Interpolation

Cardinal spline algorithm with adjustable tension:
- **Tension = 0**: Straight lines between points (Catmull-Rom)
- **Tension = 1**: Very curved, smooth paths
- **Algorithm:** Cardinal spline with tension parameter
- **Interpolation:** Cubic between each pair of control points

### Video Recording Technology

Uses browser MediaRecorder API:
- **Codec Selection:** Tries VP9 → VP8 → generic WebM
- **Frame-by-frame Rendering:** Controlled timing for accurate FPS
- **Chunk Accumulation:** Handles browser-specific blob chunking
- **Base64 Encoding:** For postMessage transfer to Python

---

## Troubleshooting

### Common Issues

**Issue:** "No mask video received from Motion Designer"
- **Cause:** Export was cancelled or failed to render
- **Solution:** Check browser console, try reducing frame count or resolution

**Issue:** Frame count mismatch warnings in console
- **Cause:** Browser MediaRecorder produced different frame count than expected
- **Solution:** FFmpeg transcoding should fix this; check final video properties

**Issue:** Objects disappear during playback
- **Cause:** "Hide outside range" enabled and object outside frame range
- **Solution:** Check start/end frame values, disable hide toggle if needed

**Issue:** Trajectory looks jerky or discontinuous
- **Cause:** Not enough waypoints or tension too low
- **Solution:** Add more trajectory points, increase tension slider

**Issue:** Export hangs or takes very long
- **Cause:** High resolution + high frame count + many objects
- **Solution:** Reduce resolution, frame count, or export in batches

### Performance Tips

- Keep resolution under 1920×1080 for smooth editing
- Limit frame count to <200 for large scenes
- Use fewer polygon vertices when possible
- Close unused browser tabs during export
- Use "cover" fit mode for better performance than "contain"

---

## Keyboard Shortcuts

While no official shortcuts are documented, the UI responds to standard mouse interactions:

- **Left Click:** Place points, draw shapes, select objects
- **Right Click:** Close polygons, lock trajectories, cancel operations
- **Double Click:** Split polygon edges (add vertex between points)
- **Click & Drag:** Create rectangles/circles, scrub timeline

---

## Integration with WanGP Models

### Cut & Drag → i2v/TTM Models

**Model Input:**
- `video_mask`: Binary mask video showing object regions
- `video_guide`: Trajectory visualization for motion guidance
- `image_start`: Background with objects removed

**Generation Process:**
1. Model uses mask to identify object regions
2. Guide video provides motion direction hints
3. Background image establishes scene context
4. Model inpaints and animates based on combined inputs

### Classic → Vace Models

**Model Input:**
- `video_guide`: Animated contour/outline video
- `image_refs[0]`: Original image as reference

**Generation Process:**
1. Model interprets contour movement
2. Reference image provides visual context
3. Vision-aware processing applies edits
4. Contour width affects edge detection

### Trajectory → Wan-Move Models

**Model Input:**
- `custom_guide`: Trajectory .npy array [T, N, 2]
- `image_start`: Source image

**Generation Process:**
1. Model reads trajectory coordinates
2. Identifies objects at trajectory endpoints
3. Animates objects along specified paths
4. [-1, -1] coordinates signal object absence

---

## Future Enhancement Possibilities

Based on the architecture, potential expansions could include:

- **Onion Skinning:** Show previous/next frames during editing
- **Bezier Handles:** Direct manipulation of curve control points
- **Layer Groups:** Organize multiple objects hierarchically
- **Preset Motions:** Library of common trajectory patterns
- **Keyframe Editor:** Timeline-based property animation
- **Multi-Track Audio:** Sync motion to audio cues
- **3D Camera Paths:** Define camera movements separate from object motion
- **Export Templates:** Batch export multiple variations

---

## Summary

Motion Designer is a **powerful, mode-adaptive animation tool** that transforms static images into precise motion control data for AI video generation. Its three operating modes (Cut & Drag, Classic, Trajectory) ensure compatibility across diverse model architectures while maintaining an intuitive visual editing workflow.

**Key Strengths:**
- Visual, what-you-see-is-what-you-get interface
- Multi-object support with independent controls
- Real-time preview and refinement
- Direct WanGP integration (no manual file handling)
- Advanced animation features (speed profiles, splines, rotation/scale)

**Primary Use Cases:**
- Precise object animation with custom trajectories
- Complex multi-object scenes with different timings
- Background replacement and inpainting
- Rapid prototyping before expensive video generation
- Iterative refinement with immediate visual feedback

Motion Designer bridges the gap between user intent and AI video generation, providing the control and precision needed for professional animation workflows.

---

**Plugin Location:** `/opt/wan2gp/Wan2GP/plugins/wan2gp-motion-designer/`  
**Documentation Version:** 1.0  
**Last Updated:** February 8, 2026
