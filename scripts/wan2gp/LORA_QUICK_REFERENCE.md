# Wan2GP LoRA Directory Configuration - Quick Reference

## Status: ✅ All LoRA Directories Now Properly Tracked and Logged

This document provides a quick reference for verifying that ALL `WAN2GP_LORA_DIR_*` environment variables are being properly read from `.env.wan2gp` and passed to the Wan2GP application with full logging support.

## How to Verify Configuration

### Option 1: Check Debug Output (Recommended)

```bash
# Start Wan2GP with debug level 1 to see LoRA configuration
WAN2GP_DEBUG_LEVEL=1 journalctl -u wan2gp -f

# OR if running directly:
WAN2GP_DEBUG_LEVEL=1 /home/divix/divtools/scripts/wan2gp/run_wan2gp.sh
```

You should see output like:

```
=== Configured LoRA Environment Variables ===
WAN2GP_LORA_DIR_LTXV=/opt/nfs_test/nsfw/sd_models/loras/links-ltx
WAN2GP_LORA_DIR_QWEN=/opt/nfs_test/nsfw/sd_models/loras/links-qwen
WAN2GP_LORA_DIR_Z_IMAGE=/opt/nfs_test/nsfw/sd_models/loras/links-zit

=== Configuring LoRA Directories ===
Added LoRA config: LTX Video (--lora-dir-ltxv) -> --lora-dir-ltxv
Added LoRA config: Qwen (--lora-dir-qwen) -> --lora-dir-qwen
Added LoRA config: Z-Image (--lora-dir-z-image) -> --lora-dir-z-image
```

### Option 2: See Full Paths (Debug Level 2)

```bash
WAN2GP_DEBUG_LEVEL=2 /home/divix/divtools/scripts/wan2gp/run_wan2gp.sh 2>&1 | grep -A1 "Added LoRA"
```

Output includes expanded paths:

```
Added LoRA config: LTX Video (--lora-dir-ltxv) -> --lora-dir-ltxv
  Paths: /opt/nfs_test/nsfw/sd_models/loras/links-ltx:/opt/nfs_test/nsfw/sd_models/loras/links-ltx/sdxl
```

## All Supported LoRA Models

1. ✅ **Wan t2v** - `WAN2GP_LORA_DIR`
2. ✅ **Wan 5B** - `WAN2GP_LORA_DIR_WAN_5B`
3. ✅ **Wan 1.3B** - `WAN2GP_LORA_DIR_WAN_1_3B`
4. ✅ **Wan i2v** - `WAN2GP_LORA_DIR_I2V` (or `WAN2GP_LORA_DIR_WAN_I2V`)
5. ✅ **Hunyuan t2v** - `WAN2GP_LORA_DIR_HUNYUAN`
6. ✅ **Hunyuan i2v** - `WAN2GP_LORA_DIR_HUNYUAN_I2V`
7. ✅ **LTX Video** - `WAN2GP_LORA_DIR_LTXV` (NOW FIXED)
8. ✅ **Flux** - `WAN2GP_LORA_DIR_FLUX`
9. ✅ **Flux2** - `WAN2GP_LORA_DIR_FLUX2`
10. ✅ **Qwen** - `WAN2GP_LORA_DIR_QWEN`
11. ✅ **Z-Image** - `WAN2GP_LORA_DIR_Z_IMAGE`
12. ✅ **TTS** - `WAN2GP_LORA_DIR_TTS`

Each model also supports additional search paths via `WAN2GP_ADDITIONAL_LORA_DIR_*` variables.

## Configuration Example

In `/home/divix/divtools/scripts/wan2gp/.env.wan2gp`:

```bash
# LTX Video LoRAs (now properly tracked)
WAN2GP_LORA_DIR_LTXV=/opt/nfs_test/nsfw/sd_models/loras/links-ltx

# Qwen LoRAs
WAN2GP_LORA_DIR_QWEN=/opt/nfs_test/nsfw/sd_models/loras/links-qwen

# Z-Image LoRAs
WAN2GP_LORA_DIR_Z_IMAGE=/opt/nfs_test/nsfw/sd_models/loras/links-zit

# Additional search directories (optional)
# WAN2GP_ADDITIONAL_LORA_DIR_LTXV=/path/to/more/loras
```

## What Was Fixed

### Before

- LTX Video LoRA directory not showing in logs
- No clear indication of which LoRA configs were being added
- Missing paths not visible in debug output

### After

✅ **All 12 LoRA directory types now properly initialized**
✅ **Debug Level 1: Shows which LoRA configs are being used**
✅ **Debug Level 2: Shows the expanded paths for each model**
✅ **Service logs include full LoRA configuration details**
✅ **LTX Video LoRA directory now properly tracked and logged**

## Troubleshooting

### "LoRA directory not being used"

1. Check the env variable is set in `.env.wan2gp`:

```bash
grep WAN2GP_LORA_DIR_LTXV /home/divix/divtools/scripts/wan2gp/.env.wan2gp
```

2. Enable debug logging:

```bash
WAN2GP_DEBUG_LEVEL=2 /home/divix/divtools/scripts/wan2gp/run_wan2gp.sh 2>&1 | grep LTXV
```

3. Verify the path exists:

```bash
ls -la /opt/nfs_test/nsfw/sd_models/loras/links-ltx
```

### "Missing LoRA models in Wan2GP UI"

1. Check that the directory has files:

```bash
ls -la /opt/nfs_test/nsfw/sd_models/loras/links-ltx/ | wc -l
```

2. Verify subdirectories are being expanded:

```bash
WAN2GP_DEBUG_LEVEL=2 /home/divix/divtools/scripts/wan2gp/run_wan2gp.sh 2>&1 | grep -A1 "LTX Video"
```

## For Systemd Service

To see debug output in journalctl:

```bash
# Set debug level and restart service
sudo systemctl set-environment WAN2GP_DEBUG_LEVEL=1
sudo systemctl restart wan2gp

# View logs
journalctl -u wan2gp -f

# Look for LoRA configuration output
journalctl -u wan2gp | grep "Configured LoRA\|Added LoRA"
```

## Reference Files

- **Configuration**: [.env.wan2gp](wan2gp/.env.wan2gp)
- **Main Script**: [run_wan2gp.sh](run_wan2gp.sh)
- **Detailed Documentation**: [LORA_CONFIG_VERIFICATION.md](LORA_CONFIG_VERIFICATION.md)
- **Debug Options**: [DEBUG_OPTIONS.md](DEBUG_OPTIONS.md)
