# DivTools Verbosity Control Implementation Summary

## What Was Done

Implemented a comprehensive verbosity control system for your DivTools `.bash_profile` that allows you to silence clutter (especially `[STAR]` messages from Starship builds) while maintaining the ability to see important information when needed.

## Changes Made

### 1. `.bash_profile` - Added Verbosity System
- **Lines 8-47**: Added comprehensive documentation and configuration block for the verbosity system
- **New Environment Variable**: `DT_VERBOSE` (default: 2)
  - Level 0: Silent (errors only)
  - Level 1: Minimal (errors + warnings)
  - Level 2: Normal (errors + warnings + info/key ops) ← **DEFAULT**
  - Level 3: Verbose (all of above + debug)
  - Level 4: Debug (everything)

- **New Associative Array**: `DT_VERBOSITY_LEVELS`
  - Maps each section (STAR, SAMBA, INFO, etc.) to its minimum verbosity threshold
  - Default thresholds prevent clutter while showing critical information

- **Updated `log_msg()` Function**: Now respects verbosity levels
  - Checks if `DT_VERBOSE >= section_threshold` before outputting
  - Messages that don't meet the threshold are silently skipped

### 2. `.bash_aliases` - Updated `sep` Alias Documentation
- Added comment explaining how to override verbosity:
  ```bash
  alias sep='source /etc/profile'  # Can override with: export DT_VERBOSE=0 && sep
  ```

### 3. New Files Created
- **`VERBOSITY_CONTROL.md`**: Comprehensive user guide with examples and troubleshooting
- **`test_verbosity_demo.sh`**: Demonstration script showing the system in action

## How to Use

### Basic Usage

**Default (Normal verbosity):**
```bash
sep              # Shows normal output
source /etc/profile
```

**Silent Mode (No Starship/Samba output):**
```bash
export DT_VERBOSE=0 && sep
export DT_VERBOSE=0 && source /etc/profile
```

**Verbose Mode (More details):**
```bash
export DT_VERBOSE=3 && sep
```

### Site-Specific Configuration

Add to your site or host `.env` file to set defaults for that site/host:

```bash
# In ~/.env or /opt/divtools/docker/sites/s00-shared/.env.s00-shared
# Silent mode by default on this host
export DT_VERBOSE=0

# Or customize per section
declare -gxA DT_VERBOSITY_LEVELS=(
    ["STAR"]=999         # Never show Starship messages
    ["SAMBA"]=2          # Show Samba at normal verbosity
    ["ERROR"]=0          # Always show errors
)
```

## Key Features

✅ **Silent Starship Builds**: Set `DT_VERBOSE=0` to suppress `[STAR]` output
✅ **Fine-Grained Control**: Each section (STAR, SAMBA, etc.) has its own threshold
✅ **Backward Compatible**: Default behavior (level 2) matches previous output levels
✅ **Flexible**: Override globally or per-site/host via env files
✅ **Easy Syntax**: Simple `export DT_VERBOSE=X && sep` usage
✅ **Error Messages Always Show**: Critical errors always visible (threshold=0)
✅ **Extensible**: New sections automatically work with the system

## Verbosity Level Reference

| Level | Purpose | Shows |
|-------|---------|-------|
| 0 | Silent production | Errors only |
| 1 | Minimal | Errors + Warnings |
| 2 | Normal (default) | Errors + Warnings + Info + Key Operations |
| 3 | Verbose | All of above + Debug messages |
| 4 | Debug | Everything, including low-level details |

## Default Section Thresholds

| Section | Threshold | Meaning |
|---------|-----------|---------|
| STAR | 2 | Show Starship messages at normal/verbose (not silent) |
| SAMBA | 2 | Show Samba messages at normal/verbose |
| INFO | 2 | Show info messages at normal/verbose |
| WARN | 1 | Show warnings at minimal/normal/verbose (not silent) |
| ERROR | 0 | Always show errors |
| DEBUG | 3 | Show debug only at verbose level 3+ |

## Examples

### Example 1: Quiet Daily Use
```bash
# Add to ~/.env:
export DT_VERBOSE=1

# Then 'sep' shows only errors and warnings, no Starship clutter
```

### Example 2: Troubleshooting
```bash
# When debugging profile issues:
export DT_VERBOSE=3 && sep
```

### Example 3: Never Show Starship Again
```bash
# Add to ~/.env:
declare -gxA DT_VERBOSITY_LEVELS=(["STAR"]=999)
```

### Example 4: Only Show Errors
```bash
export DT_VERBOSE=0 && sep
```

## Testing

Run the demo to see it in action:
```bash
bash /home/divix/divtools/dotfiles/test_verbosity_demo.sh
```

This shows all 5 test scenarios with different verbosity levels.

## Files Modified

1. `/home/divix/divtools/dotfiles/.bash_profile`
   - Added verbosity configuration block (lines 8-47)
   - Updated `log_msg()` function to respect verbosity levels

2. `/home/divix/divtools/dotfiles/.bash_aliases`
   - Added documentation for `sep` alias

## Files Created

1. `/home/divix/divtools/dotfiles/VERBOSITY_CONTROL.md` - Complete documentation
2. `/home/divix/divtools/dotfiles/test_verbosity_demo.sh` - Interactive demo script

## Backward Compatibility

✅ **Fully backward compatible!** The default behavior is unchanged because:
- Default `DT_VERBOSE=2` (Normal) matches previous verbose output levels
- All existing calls to `log_msg()` work exactly as before
- You only benefit from silence if you explicitly set `DT_VERBOSE=0` or override thresholds

## Future Enhancements

Consider adding to your env files to customize per-site:
```bash
# Production servers: silent mode
export DT_VERBOSE=0

# Development servers: verbose mode
export DT_VERBOSE=3

# Staging servers: normal with custom Starship threshold
export DT_VERBOSE=2
declare -gxA DT_VERBOSITY_LEVELS=(["STAR"]=3)
```

---

**Documentation**: See `VERBOSITY_CONTROL.md` for detailed guide with troubleshooting
**Demo**: Run `test_verbosity_demo.sh` to see all verbosity levels in action
