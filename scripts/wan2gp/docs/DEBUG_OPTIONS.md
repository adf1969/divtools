# Wan2GP Debug and Verbosity Options

## Overview

You can now control debug output at two levels:

1. **WAN2GP_DEBUG_LEVEL** - Controls startup logging from the `run_wan2gp.sh` script
2. **WAN2GP_VERBOSE** - Controls runtime verbosity from the Wan2GP application itself

## Configuration

Edit `/home/divix/divtools/scripts/wan2gp/.env.wan2gp` to enable debug output:

```bash
# Startup script debug level (0-3)
WAN2GP_DEBUG_LEVEL=2

# Wan2GP application verbosity (0-2)
WAN2GP_VERBOSE=1
```

## WAN2GP_DEBUG_LEVEL (Script Startup)

Controls how much information the `run_wan2gp.sh` startup script logs.

### Levels:

**Level 0 - Minimal**
- Only critical errors
- No configuration details
- Minimal startup information

**Level 1 - Standard (Default)**
- INFO and ERROR messages
- Basic DEBUG messages
- LoRA and core configuration paths
- Recommended for normal operation

**Level 2 - Enhanced**
- Everything from Level 1
- Plus: Conda environment, working directory
- Verbose level setting
- Performance parameters (profile, attention, etc.)
- Good for troubleshooting startup issues

**Level 3 - Maximum**
- Everything from Level 2
- Plus: Full command array line-by-line
- Environment paths (CONDA_DIR, REPO_ROOT, SCRIPT_DIR)
- Very detailed for deep debugging

### Usage:

```bash
# Standard debugging
WAN2GP_DEBUG_LEVEL=1

# Enhanced debugging
WAN2GP_DEBUG_LEVEL=2

# Complete debugging
WAN2GP_DEBUG_LEVEL=3
```

## WAN2GP_VERBOSE (Wan2GP Application)

Controls verbosity level from the Wan2GP application runtime.

### Levels:

**Level 0 - Quiet**
- Minimal logging
- Only essential application messages

**Level 1 - Verbose**
- Standard information
- Model loading information
- Basic operation flow

**Level 2 - Very Verbose**
- Detailed debugging information
- Complete operation flow
- Memory and performance details

### Usage:

```bash
# Standard Wan2GP verbosity
WAN2GP_VERBOSE=1

# Maximum Wan2GP verbosity
WAN2GP_VERBOSE=2
```

## Recommended Configurations

### For Normal Operation
```bash
WAN2GP_DEBUG_LEVEL=1
WAN2GP_VERBOSE=0
```

### For Troubleshooting Startup Issues
```bash
WAN2GP_DEBUG_LEVEL=2
WAN2GP_VERBOSE=0
```

### For Full Debugging
```bash
WAN2GP_DEBUG_LEVEL=2
WAN2GP_VERBOSE=1
```

### For Deep Technical Analysis
```bash
WAN2GP_DEBUG_LEVEL=3
WAN2GP_VERBOSE=2
```

## Example Output

### Debug Level 1 Output
```
[2026-02-07 12:00:01] [INFO] Starting Wan2GP from /opt/wan2gp/Wan2GP
[2026-02-07 12:00:01] [DEBUG] Server: 0.0.0.0:7860
[2026-02-07 12:00:01] [DEBUG] Debug level: 1
[2026-02-07 12:00:01] [DEBUG] Wan t2v LoRAs: /opt/nfs_test/nsfw/sd_models/loras
```

### Debug Level 2 Output
```
[2026-02-07 12:00:01] [INFO] Starting Wan2GP from /opt/wan2gp/Wan2GP
[2026-02-07 12:00:01] [DEBUG] Server: 0.0.0.0:7860
[2026-02-07 12:00:01] [DEBUG] Debug level: 2
[2026-02-07 12:00:01] [DEBUG] === Enhanced Debug Information ===
[2026-02-07 12:00:01] [DEBUG] Conda environment: /opt/conda/wan2gp
[2026-02-07 12:00:01] [DEBUG] Workdir: /opt/wan2gp/Wan2GP
[2026-02-07 12:00:01] [DEBUG] Wan2GP verbose level: not set
[2026-02-07 12:00:01] [DEBUG] Profile: 4
[2026-02-07 12:00:01] [DEBUG] Attention: sage2
```

### Debug Level 3 Output
```
[2026-02-07 12:00:01] [DEBUG] === Maximum Debug Information ===
[2026-02-07 12:00:01] [DEBUG] Full command array:
[2026-02-07 12:00:01] [DEBUG]   CMD[0]=/opt/wan2gp/Wan2GP/wgp.py
[2026-02-07 12:00:01] [DEBUG]   CMD[1]=--server-name
[2026-02-07 12:00:01] [DEBUG]   CMD[2]=0.0.0.0
[2026-02-07 12:00:01] [DEBUG]   CMD[3]=--server-port
[2026-02-07 12:00:01] [DEBUG]   CMD[4]=7860
[2026-02-07 12:00:01] [DEBUG] Environment paths:
[2026-02-07 12:00:01] [DEBUG]   CONDA_DIR=/opt/conda
[2026-02-07 12:00:01] [DEBUG]   REPO_ROOT=/home/divix/divtools
[2026-02-07 12:00:01] [DEBUG]   SCRIPT_DIR=/home/divix/divtools/scripts/wan2gp
```

## Workflow

1. Set your debug levels in `.env.wan2gp`
2. Save the file
3. Run or restart Wan2GP
4. Review the startup logs for detailed information
5. Adjust levels based on what you need to debug

## Notes

- Debug output goes to the same log file as the main application
- Higher debug levels generate more output but may impact performance slightly
- Debug settings are read from `.env.wan2gp` on every startup
- You can change debug levels without restarting the entire system
- The script applies defaults if variables are not set
