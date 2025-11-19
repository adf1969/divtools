# DivTools Verbosity Control System

## Overview

The DivTools verbosity control system allows you to manage the amount of output displayed when sourcing your bash profile and related files. This is useful for reducing clutter during initialization while maintaining the ability to see detailed information when needed.

## How It Works

- **Global Verbosity Level** (`DT_VERBOSE`): Controls the overall verbosity (0-4)
- **Section-Level Thresholds** (`DT_VERBOSITY_LEVELS`): Defines when specific sections output messages
- Messages only display if `DT_VERBOSE >= section_threshold`

## Global Verbosity Levels

| Level | Name | Description |
|-------|------|-------------|
| 0 | Silent | Only critical errors (rarely used) |
| 1 | Minimal | Errors + warnings only |
| 2 | Normal | Errors + warnings + key operations (default) |
| 3 | Verbose | All of above + debug information |
| 4 | Debug | Everything, including low-level details |

## Section Thresholds

Default section verbosity thresholds (defined in `.bash_profile`):

```bash
declare -gxA DT_VERBOSITY_LEVELS=(
    ["STAR"]=2           # Starship build messages
    ["SAMBA"]=2          # Samba-related messages
    ["INFO"]=2           # General info messages
    ["WARN"]=1           # Warning messages
    ["ERROR"]=0          # Error messages (always show)
    ["DEBUG"]=3          # Debug messages
)
```

## Basic Usage

### Default Behavior (Normal verbosity)
```bash
source /etc/profile
sep         # Using alias
```

### Silent Mode (No clutter)
```bash
export DT_VERBOSE=0 && source /etc/profile
export DT_VERBOSE=0 && sep
```

### Verbose Mode (See more details)
```bash
export DT_VERBOSE=3 && source /etc/profile
export DT_VERBOSE=3 && sep
```

### Debug Mode (Everything)
```bash
export DT_VERBOSE=4 && source /etc/profile
export DT_VERBOSE=4 && sep
```

## Advanced Usage

### Silence Specific Sections

Add to `~/.env` or your site/host `.env.hostname` file:

```bash
# Silence all Starship output (set threshold impossibly high)
declare -gxA DT_VERBOSITY_LEVELS=(["STAR"]=999)

# Or only show Starship at verbose level 4
declare -gxA DT_VERBOSITY_LEVELS=(["STAR"]=4)
```

### Custom Per-Section Settings

Override specific sections while keeping others normal:

```bash
# In ~/.env:
declare -gxA DT_VERBOSITY_LEVELS=(
    ["STAR"]=999         # Never show Starship messages
    ["SAMBA"]=3          # Only show Samba at verbose level 3+
    ["INFO"]=1           # Show info even at minimal verbosity
    ["ERROR"]=0          # Always show errors (default)
    ["DEBUG"]=4          # Debug only at highest verbosity
)
```

### Per-Host Settings

Set different verbosity for different hosts by placing in their env file:

```bash
# In /opt/divtools/docker/sites/s00-shared/.env.s00-shared
# (or site-specific or host-specific env files)

export DT_VERBOSE=1        # Minimal verbosity on this site
declare -gxA DT_VERBOSITY_LEVELS=(["STAR"]=999)  # Never show Starship
```

## The `sep` Alias

The `sep` (Source Everything in Profile) alias sources `/etc/profile` and is frequently used to reload your shell environment. You can now control its verbosity:

```bash
# Normal output
sep

# Quiet
export DT_VERBOSE=0 && sep

# Verbose
export DT_VERBOSE=3 && sep
```

## Examples

### Example 1: Quiet Daily Use
Most of the time you want minimal output, only showing errors and warnings:

```bash
# Add to ~/.env:
export DT_VERBOSE=1
```

Then use `sep` normally without the clutter of Starship build messages.

### Example 2: Troubleshooting
When debugging profile issues, temporarily enable verbose output:

```bash
export DT_VERBOSE=3 && sep
```

This shows all info messages, warnings, and errors, plus debug details.

### Example 3: Silent Initialization
When you just want to source everything without any output (except errors):

```bash
export DT_VERBOSE=0 && sep
```

### Example 4: Production Server
Set high thresholds for noisy sections but keep errors visible:

```bash
# In prod server's .env file:
export DT_VERBOSE=0
declare -gxA DT_VERBOSITY_LEVELS=(["ERROR"]=0)  # Only errors
```

## Adding New Sections

When adding new output to the profile:

1. Use `log_msg "SECTIONNAME" "message"` in your code
2. Add a threshold to `DT_VERBOSITY_LEVELS` in `.bash_profile`:
   ```bash
   ["SECTIONNAME"]=2   # Your desired threshold
   ```
3. The message will automatically respect the verbosity system

## Troubleshooting

### Messages still appear after setting DT_VERBOSE=0

- Check that your section has a low enough threshold in `DT_VERBOSITY_LEVELS`
- Remember: `DT_VERBOSE` must be >= section threshold for output to display
- Check for env files overriding your settings (they load after `.bash_profile`)

### Setting DT_VERBOSE doesn't work

- Make sure you `export` it: `export DT_VERBOSE=0`
- Set it BEFORE sourcing the profile: `export DT_VERBOSE=0 && source /etc/profile`
- Check that it's not being overridden in `~/.env` or other env files

### Can't silence a specific section

Set its threshold to a very high number:
```bash
declare -gxA DT_VERBOSITY_LEVELS=(["STAR"]=999)
```

## Reference

- See `.bash_profile` lines with `DT_VERBOSE` comments for implementation details
- The `log_msg()` function in `.bash_profile` controls the verbosity filtering
- Default thresholds are defined at the top of `.bash_profile` in the `DT_VERBOSITY_LEVELS` array
