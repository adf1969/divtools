# Wan2GP Utility Script - Usage Guide

## Overview

The `wan2gp_util.sh` script provides utilities for managing Wan2GP folder relocations and symlink creation. This allows you to redirect model downloads and loras to custom locations.

## Configuration

The script reads settings from: `/home/divix/divtools/scripts/wan2gp/.env.wan2gp`

### Available Configuration Variables

```bash
# Checkpoint relocation destination
WAN2GP_CKPTS_DEST=/opt/ai_models/sd_models/checkpoints

# LoRAs relocation destination  
WAN2GP_LORAS_DEST=/opt/ai_models/sd_models/loras
```

Edit `.env.wan2gp` to set your desired destinations, then use the utility script to perform the relocations.

## Commands and Flags

### Flag Formats

Every command supports three flag variants:
- **Long format**: `--flag-name` (e.g., `--relocate-ckpts`)
- **Short format**: `-flag-name` (e.g., `-relocate-ckpts`)
- **Ultra-short**: `-XX` (e.g., `-rc` for relocate-ckpts)

### Global Options

```bash
-test, --test, -t          # Run in TEST mode (dry run, no changes)
-debug, --debug, -d        # Enable DEBUG mode (verbose output)
-h, --help                 # Show help message
```

## Actions

### Relocate Checkpoints (ckpts)

**Flags**: `-relocate-ckpts`, `--relocate-ckpts`, `-rc`

Relocates the Wan2GP checkpoints folder to the destination specified in `WAN2GP_CKPTS_DEST`.

**Process**:
1. Creates destination directory if it doesn't exist
2. Compares contents of source and destination
3. Copies any missing or different files from source to destination
4. Backs up original folder to `ckpts.ORIG`
5. Creates symlink: `ckpts` → destination

**Examples**:

```bash
# Dry run to see what would happen
wan2gp_util.sh -test -relocate-ckpts

# Actually perform the relocation with debug output
wan2gp_util.sh -debug -relocate-ckpts

# Using short flags
wan2gp_util.sh -t -rc
```

### Relocate LoRAs

**Flags**: `-relocate-loras`, `--relocate-loras`, `-rl`

Relocates the Wan2GP loras folder to the destination specified in `WAN2GP_LORAS_DEST`.

**Process**: Same as checkpoint relocation

**Examples**:

```bash
# Dry run
wan2gp_util.sh -test -relocate-loras

# Perform relocation  
wan2gp_util.sh -relocate-loras

# Short version
wan2gp_util.sh -rl
```

## Practical Workflow

### Step 1: Configure Destinations

Edit `/home/divix/divtools/scripts/wan2gp/.env.wan2gp` and set your desired paths:

```bash
WAN2GP_CKPTS_DEST=/opt/ai_models/sd_models/checkpoints
WAN2GP_LORAS_DEST=/opt/ai_models/sd_models/loras
```

### Step 2: Test the Changes

Run a dry-run to see what would happen:

```bash
cd /home/divix/divtools/scripts/wan2gp
./wan2gp_util.sh -test -debug -relocate-ckpts
./wan2gp_util.sh -test -debug -relocate-loras
```

### Step 3: Apply Changes

Once you're satisfied with the test output, run the actual relocation:

```bash
./wan2gp_util.sh -debug -relocate-ckpts
./wan2gp_util.sh -debug -relocate-loras
```

### Step 4: Verify Results

After relocation, you should have:
- Original folder backed up: `ckpts.ORIG` or `loras.ORIG`
- Symlink that points to your desired location
- All models at the new location

```bash
# Check the symlink
ls -la /opt/wan2gp/Wan2GP/ckpts
ls -la /opt/wan2gp/Wan2GP/loras

# Should show something like:
# lrwxrwxrwx ... ckpts -> /opt/ai_models/sd_models/checkpoints
```

## Backup and Recovery

The script creates backups of original folders before creating symlinks:

- Original checkpoints backup: `/opt/wan2gp/Wan2GP/ckpts.ORIG`
- Original loras backup: `/opt/wan2gp/Wan2GP/loras.ORIG`

If you need to revert:

```bash
# Remove symlink and restore from backup
rm /opt/wan2gp/Wan2GP/ckpts
mv /opt/wan2gp/Wan2GP/ckpts.ORIG /opt/wan2gp/Wan2GP/ckpts
```

## Important Notes

- **Permissions**: The script respects existing permissions and directory ownership
- **Symlink Only**: This script only creates symlinks; it does NOT move existing installations
- **Content Verification**: The script checks if destination already contains the same files before copying
- **Test Mode**: Always run with `-test` first to see the expected changes
- **Service Integration**: The `run_wan2gp.sh` service script assumes symlinks are already in place. Run this utility BEFORE starting Wan2GP as a service.

## Troubleshooting

### "Source directory does not exist"
The script expects folders to exist at:
- `/opt/wan2gp/Wan2GP/ckpts`
- `/opt/wan2gp/Wan2GP/loras`

If these don't exist, Wan2GP hasn't created them yet. Run Wan2GP once to generate these folders, then run the utility script.

### Symlink already exists
If a symlink already exists pointing to a different location, the script will report a warning and skip the relocation. If you need to change it, manually remove the old symlink first:

```bash
rm /opt/wan2gp/Wan2GP/ckpts
./wan2gp_util.sh -relocate-ckpts
```

### Permission denied errors
The script needs write permissions in `/opt/wan2gp/Wan2GP/`. If you get permission errors, check the directory permissions:

```bash
ls -la /opt/wan2gp/
```

## Environment Variables

The script sources the following from `.env.wan2gp`:

- `WAN2GP_CKPTS_DEST` - Destination for checkpoints relocation
- `WAN2GP_LORAS_DEST` - Destination for loras relocation

Defaults are used if these variables are not set:
- `WAN2GP_CKPTS_DEST` defaults to `/opt/ai_models/sd_models/checkpoints`
- `WAN2GP_LORAS_DEST` defaults to `/opt/ai_models/sd_models/loras`
