# ⚠️ DEPRECATED PROJECT - DO NOT USE

**This project has been deprecated and replaced by `dtpyutil`.**

## Why Was This Deprecated?

During development of `dtpmenu`, we discovered a fundamental incompatibility between:
- **Bash command substitution** (`choice=$(...)`)
- **Python Textual TUI** terminal detection and centering

### The Problem

```bash
# ❌ BROKEN - Command substitution pipes stdout to buffer, breaks centering
choice=$(dtpmenu.py menu --title "Choose" tag1 "Option 1")
# Result: Menu appears at top-left instead of centered
```

When bash uses command substitution, it redirects Python's stdout to a pipe/buffer. Textual's terminal detection receives the pipe dimensions (typically 4KB × 0 lines) instead of the actual screen dimensions, causing dialogs to render incorrectly at the top-left.

### The Solution

The `dtpyutil` project solves this by:

1. **File-Based IPC**: Menu results are written to a temp file AFTER the TUI exits
2. **Shared Venv**: Single Python environment for all divtools utilities
3. **Editable Install**: Changes to source code take effect immediately
4. **Proper Integration**: Bash wrapper handles file creation/cleanup internally

```bash
# ✅ WORKS - Uses file-based IPC internally
source "$DIVTOOLS/projects/dtpyutil/src/menu/bash_wrapper.sh"
choice=$(pmenu_menu "Choose" tag1 "Option 1")  # Centers properly!
```

## Migration Path

**Old (dtpmenu - DEPRECATED):**
```bash
source "$DIVTOOLS/scripts/util/dt_pmenu_lib.sh"
# Command substitution breaks centering
```

**New (dtpyutil - USE THIS):**
```bash
source "$DIVTOOLS/projects/dtpyutil/src/menu/bash_wrapper.sh"
# File-based IPC fixes centering
choice=$(pmenu_menu "Title" "tag1" "Option 1")  # ✅ Works!
```

## Installation

**DO NOT install dtpmenu.** Use dtpyutil instead:

```bash
cd $DIVTOOLS/projects/dtpyutil
bash scripts/install_dtpyutil_deps.sh
```

## Documentation

For historical reference, the critical lessons learned are documented in:
- `/home/divix/divtools/projects/dtpyutil/docs/BASH-INTEGRATION.md`
- `/home/divix/divtools/projects/dtpyutil/docs/PROJECT-HISTORY.md`

These documents explain:
- Why command substitution breaks Textual
- How file-based IPC solves the problem
- Development timeline and decisions
- Terminal control best practices

## New Project Location

**`/home/divix/divtools/projects/dtpyutil/`**

Contains:
- `src/menu/dtpmenu.py` - Main TUI app (with --output-file support)
- `src/menu/bash_wrapper.sh` - Bash integration with file-based IPC
- `scripts/install_dtpyutil_deps.sh` - Venv setup script
- `docs/` - Full documentation
- `examples/` - Example usage

## Why Keep This Folder?

This folder is preserved for:
- **Historical reference** - Development timeline and lessons learned
- **Archive purposes** - Complete record of the dtpmenu experiment
- **Documentation** - Critical insights about Textual + Bash integration

It may be moved to an archive folder in the future.

## Summary

**DO NOT USE FILES FROM THIS FOLDER.**

Use `dtpyutil` instead:
```bash
cd $DIVTOOLS/projects/dtpyutil
bash scripts/install_dtpyutil_deps.sh
source src/menu/bash_wrapper.sh
```

---

**Deprecated Date**: January 14, 2026  
**Replaced By**: dtpyutil  
**Reason**: Command substitution incompatibility with Textual TUI  
**Solution**: File-based IPC in dtpyutil
