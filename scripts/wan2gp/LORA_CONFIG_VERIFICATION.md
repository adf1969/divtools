# Wan2GP LoRA Directory Configuration - Verification & Logging

## Problem Summary

The `run_wan2gp.sh` script was not consistently logging which LoRA directories were being configured and passed to the Wan2GP application. Additionally, all `WAN2GP_LORA_DIR_*` environment variables are now properly initialized and monitored.

## What Was Fixed

### 1. **Variable Initialization**
All LoRA directory environment variables are now explicitly initialized in the script, even if not configured in `.env.wan2gp`. This ensures consistent behavior and prevents undefined variable errors.

**Initialized Variables:**
- `WAN2GP_LORA_DIR`
- `WAN2GP_LORA_DIR_WAN_5B`
- `WAN2GP_LORA_DIR_WAN_1_3B`
- `WAN2GP_LORA_DIR_I2V`
- `WAN2GP_LORA_DIR_WAN_I2V`
- `WAN2GP_LORA_DIR_HUNYUAN`
- `WAN2GP_LORA_DIR_HUNYUAN_I2V`
- `WAN2GP_LORA_DIR_LTXV` ✅ (LTX now properly tracked)
- `WAN2GP_LORA_DIR_FLUX`
- `WAN2GP_LORA_DIR_FLUX2`
- `WAN2GP_LORA_DIR_QWEN`
- `WAN2GP_LORA_DIR_Z_IMAGE`
- `WAN2GP_LORA_DIR_TTS`

Plus all corresponding `WAN2GP_ADDITIONAL_LORA_DIR_*` variables.

### 2. **Enhanced Logging Function**
The `add_lora_arg()` function now includes a 4th parameter for debug output:

```bash
add_lora_arg "--lora-dir-ltxv" "$WAN2GP_LORA_DIR_LTXV" "$WAN2GP_ADDITIONAL_LORA_DIR_LTXV" "LTX Video (--lora-dir-ltxv)"
```

This function now logs:
- **Debug Level 1+**: Which LoRA configs are being added to the command
- **Debug Level 2+**: The actual paths being used for each LoRA directory

### 3. **Configuration Startup Logging**
At startup (Debug Level 1+), the script now displays all configured LoRA environment variables:

```
=== Configured LoRA Environment Variables ===
WAN2GP_LORA_DIR_LTXV=/opt/nfs_test/nsfw/sd_models/loras/links-ltx
WAN2GP_LORA_DIR_QWEN=/opt/nfs_test/nsfw/sd_models/loras/links-qwen
WAN2GP_LORA_DIR_Z_IMAGE=/opt/nfs_test/nsfw/sd_models/loras/links-zit
```

### 4. **Command Building Logging**
At startup (Debug Level 1+), the script now shows which LoRA arguments are being added to the Wan2GP command:

```
=== Configuring LoRA Directories ===
Added LoRA config: LTX Video (--lora-dir-ltxv) -> --lora-dir-ltxv
Added LoRA config: Qwen (--lora-dir-qwen) -> --lora-dir-qwen
Added LoRA config: Z-Image (--lora-dir-z-image) -> --lora-dir-z-image
```

With Debug Level 2+, it also shows the expanded paths:

```
Added LoRA config: LTX Video (--lora-dir-ltxv) -> --lora-dir-ltxv
  Paths: /opt/nfs_test/nsfw/sd_models/loras/links-ltx
```

## Verified LoRA Configurations

The following LoRA directories are now properly handled:

| Model Type | Env Variable | CLI Flag | Status |
|---|---|---|---|
| Wan t2v | `WAN2GP_LORA_DIR` | `--lora-dir` | ✅ Verified |
| Wan 5B | `WAN2GP_LORA_DIR_WAN_5B` | `--lora-dir-wan-5b` | ✅ Verified |
| Wan 1.3B | `WAN2GP_LORA_DIR_WAN_1_3B` | `--lora-dir-wan-1-3b` | ✅ Verified |
| Wan i2v | `WAN2GP_LORA_DIR_I2V` | `--lora-dir-i2v` | ✅ Verified |
| Wan i2v (alt) | `WAN2GP_LORA_DIR_WAN_I2V` | `--lora-dir-i2v` | ✅ Verified |
| Hunyuan t2v | `WAN2GP_LORA_DIR_HUNYUAN` | `--lora-dir-hunyuan` | ✅ Verified |
| Hunyuan i2v | `WAN2GP_LORA_DIR_HUNYUAN_I2V` | `--lora-dir-hunyuan-i2v` | ✅ Verified |
| **LTX Video** | **`WAN2GP_LORA_DIR_LTXV`** | **`--lora-dir-ltxv`** | **✅ Now Fixed** |
| Flux | `WAN2GP_LORA_DIR_FLUX` | `--lora-dir-flux` | ✅ Verified |
| Flux2 | `WAN2GP_LORA_DIR_FLUX2` | `--lora-dir-flux2` | ✅ Verified |
| Qwen | `WAN2GP_LORA_DIR_QWEN` | `--lora-dir-qwen` | ✅ Verified |
| Z-Image | `WAN2GP_LORA_DIR_Z_IMAGE` | `--lora-dir-z-image` | ✅ Verified |
| TTS | `WAN2GP_LORA_DIR_TTS` | `--lora-dir-tts` | ✅ Verified |

## Log Output Examples

### Debug Level 1 Output

Shows which LoRA directories are configured and which commands are being built:

```
[2026-02-07 14:30:00] [DEBUG] === Configured LoRA Environment Variables ===
[2026-02-07 14:30:00] [DEBUG] WAN2GP_LORA_DIR_LTXV=/opt/nfs_test/nsfw/sd_models/loras/links-ltx
[2026-02-07 14:30:00] [DEBUG] WAN2GP_LORA_DIR_QWEN=/opt/nfs_test/nsfw/sd_models/loras/links-qwen
[2026-02-07 14:30:00] [DEBUG] WAN2GP_LORA_DIR_Z_IMAGE=/opt/nfs_test/nsfw/sd_models/loras/links-zit
[2026-02-07 14:30:00] [DEBUG] === Configuring LoRA Directories ===
[2026-02-07 14:30:01] [DEBUG] Added LoRA config: LTX Video (--lora-dir-ltxv) -> --lora-dir-ltxv
[2026-02-07 14:30:01] [DEBUG] Added LoRA config: Qwen (--lora-dir-qwen) -> --lora-dir-qwen
[2026-02-07 14:30:01] [DEBUG] Added LoRA config: Z-Image (--lora-dir-z-image) -> --lora-dir-z-image
```

### Debug Level 2 Output

Includes the expanded paths:

```
[2026-02-07 14:30:01] [DEBUG] Added LoRA config: LTX Video (--lora-dir-ltxv) -> --lora-dir-ltxv
[2026-02-07 14:30:01] [DEBUG:!ts]   Paths: /opt/nfs_test/nsfw/sd_models/loras/links-ltx
[2026-02-07 14:30:01] [DEBUG] Added LoRA config: Qwen (--lora-dir-qwen) -> --lora-dir-qwen
[2026-02-07 14:30:01] [DEBUG:!ts]   Paths: /opt/nfs_test/nsfw/sd_models/loras/links-qwen
```

## Configuration in .env.wan2gp

All LoRA directory variables are available in the `.env.wan2gp` configuration file. Simply uncomment and set the paths you need:

```bash
# LTX Video LoRAs
WAN2GP_LORA_DIR_LTXV=/opt/nfs_test/nsfw/sd_models/loras/links-ltx

# Flux LoRAs
#WAN2GP_LORA_DIR_FLUX=/opt/ai_models/sd_models/loras/flux
#WAN2GP_LORA_DIR_FLUX2=/opt/ai_models/sd_models/loras/flux2

# Qwen LoRAs
WAN2GP_LORA_DIR_QWEN=/opt/nfs_test/nsfw/sd_models/loras/links-qwen

# Z-Image LoRAs
WAN2GP_LORA_DIR_Z_IMAGE=/opt/nfs_test/nsfw/sd_models/loras/links-zit
```

## Verification Steps

1. **View current configuration:**
   ```bash
   WAN2GP_DEBUG_LEVEL=1 /home/divix/divtools/scripts/wan2gp/run_wan2gp.sh
   ```

2. **See expanded paths:**
   ```bash
   WAN2GP_DEBUG_LEVEL=2 /home/divix/divtools/scripts/wan2gp/run_wan2gp.sh
   ```

3. **Check service logs:**
   ```bash
   journalctl -u wan2gp -f
   ```

All `WAN2GP_LORA_DIR_*` variables will now be visible in the logs, confirming they are being read and used correctly.

## Key Improvements

✅ **Complete Variable Coverage**: All 13 model-specific LoRA directory variables are now tracked  
✅ **Enhanced Logging**: Clear indication of which LoRA configs are being added  
✅ **Path Visibility**: Debug level 2+ shows the actual paths being passed  
✅ **LTX Video Fixed**: LTX LoRA directory setting now properly logged and applied  
✅ **Service Logging**: Debug output appears in systemd journal logs  
✅ **Debugging Support**: Multiple debug levels for different troubleshooting needs
