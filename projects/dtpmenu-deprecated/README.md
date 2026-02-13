# dtpmenu - Divtools Python Menu Library

`dtpmenu` is a "Superior" TUI menu system built with Python and the [Textual](https://textual.textualize.io/) framework. It serves as a modern replacement for `gum` in the Divtools ecosystem.

## ⚠️ CRITICAL: Read This First

**DO NOT use command substitution to capture dtpmenu output:**

```bash
# ❌ BROKEN - This breaks centering!
choice=$(pmenu_menu "Title" "tag1" "Option 1")

# ✅ CORRECT - Direct execution
pmenu_menu "Title" "tag1" "Option 1"
# Dialog appears centered, user interacts
```

**YOU CAN capture exit codes:**

```bash
pmenu_yesno "Confirm?" "Proceed?"
if [[ $? -eq 0 ]]; then echo "User said yes"; fi
```

**Full explanation:** See [BASH-INTEGRATION.md](docs/BASH-INTEGRATION.md) and [RETURN-VALUES.md](docs/RETURN-VALUES.md)

## Quick Start

### Installation

```bash
cd /home/divix/divtools
bash projects/dtpmenu/install_dtpmenu_deps.sh
```

### Basic Usage

```bash
#!/bin/bash
source "$DIVTOOLS/scripts/util/dt_pmenu_lib.sh"

# Enable centering (REQUIRED for centered dialogs)
export PMENU_H_CENTER=1
export PMENU_V_CENTER=1

# Show menu (no output capture - direct execution)
pmenu_menu "Main Menu" \
    "create" "Create New Item" \
    "edit" "Edit Item" \
    "delete" "Delete Item" \
    "exit" "Exit"

echo "Dialog has closed"
```

### Testing

```bash
cd /home/divix/divtools
bash projects/dtpmenu/demo_menu.sh
```

The menu should appear **perfectly centered** on your screen with muted colors (cyan, grey, white).

## Documentation

| Document | Purpose |
|----------|---------|
| **[BASH-INTEGRATION.md](docs/BASH-INTEGRATION.md)** | **START HERE** - Complete guide on bash wrapper patterns, why command substitution breaks Textual, and proper integration approaches |
| **[RETURN-VALUES.md](docs/RETURN-VALUES.md)** | Exit codes, how to check results, chaining dialogs, real-world examples |
| **[QUICK-REFERENCE.md](docs/QUICK-REFERENCE.md)** | Quick lookup - copy-paste code samples |
| **[SOLUTION-SUMMARY.md](docs/SOLUTION-SUMMARY.md)** | How the centering issue was solved (for reference) |
| **[PROJECT-HISTORY.md](docs/PROJECT-HISTORY.md)** | Development timeline and architectural decisions |

**NEW USERS:** Read [BASH-INTEGRATION.md](docs/BASH-INTEGRATION.md) first! It explains everything you need to know.

## Testing & Examples

### Comprehensive Demo Menu

Interactive demo showing all dtpmenu capabilities:

```bash
cd /home/divix/divtools
bash projects/dtpmenu/demo_menu.sh
```

This demo tests each mode sequentially:
1. **Menu Mode** - Shows fruit selection menu
2. **Message Box** - Displays informational message
3. **Yes/No Dialog** - Demonstrates confirmation with proper exit codes
4. **Input Box** - Tests user text entry with proper return values

Each test shows instructions, runs the dialog, then displays the result with the exit code. ✅ **Input box now works correctly!** See [INPUT-BOX-FIX.md](docs/INPUT-BOX-FIX.md) for details on the fix.


### Automated Return Value Tests

Verify that dtpmenu properly returns exit codes for all modes:

```bash
bash projects/dtpmenu/test_dtpmenu_returns.sh
```

This interactive test suite verifies:

- ✅ Yes/No dialogs return 0 for Yes, 1 for No
- ✅ Message boxes return 0 on confirmation
- ✅ Menu selections return 0 when option chosen, 1 when cancelled
- ✅ Input boxes return proper exit codes
- ✅ Chained dialogs work correctly in sequence

### Real-World Usage Examples

Practical bash patterns for using dtpmenu:

```bash
bash projects/dtpmenu/example_real_world_usage.sh
```

Demonstrates 8 real-world patterns:

1. Simple user confirmation
2. Selection with branching
3. Destructive operations with double-confirmation
4. Multi-step configuration wizard
5. Error handling with retry
6. Conditional branching
7. Menu loops
8. Batch operations with confirmation

## Features

- ✅ **Perfectly Centered** - Dialogs appear centered both horizontally and vertically
- ✅ **Professional Colors** - Muted cyan/grey/white palette (not garish bright colors)
- ✅ **Keyboard Support** - Full keyboard navigation with mouse support
- ✅ **Multiple Modes** - Menu, MessageBox, Yes/No, Input
- ✅ **Bash-Friendly** - Simple wrapper library with sensible defaults
- ✅ **No Output Capture Needed** - Direct terminal execution for proper rendering
- ✅ **Tested Return Values** - All modes properly return exit codes for bash integration

## Environment Variables

Control the appearance and behavior of dialogs using these environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `PMENU_H_CENTER` | Enable horizontal centering (1=Yes, 0=No) | 0 |
| `PMENU_V_CENTER` | Enable vertical centering (1=Yes, 0=No) | 0 |
| `DEBUG_MODE` | Enable debug output (1=Yes, 0=No) | 0 |

## Bash Functions

Source the library in your script:

```bash
source "$DIVTOOLS/scripts/util/dt_pmenu_lib.sh"

export PMENU_H_CENTER=1
export PMENU_V_CENTER=1
```

### 1. pmenu_menu

Displays a selection menu with tag/description pairs.

**Usage:**

```bash
pmenu_menu "Menu Title" "tag1" "Description 1" "tag2" "Description 2" ...
```

**Exit Code:**

- `0` - User selected an option
- `1` - User cancelled

**Output:** Selected tag is printed to stdout when OK clicked

**Pattern (Correct):**

```bash
pmenu_menu "Choose" "a" "Apple" "b" "Banana"
if [[ $? -eq 0 ]]; then
    echo "User selected something"
fi
```

### 2. pmenu_msgbox

Displays an informational message box with an "OK" button.

**Usage:**

```bash
pmenu_msgbox "Alert Title" "Message text with \\\\n for newlines"
```

**Exit Code:**

- `0` - OK button clicked
- `1` - Dialog closed without action

**Output:** None

**Pattern:**

```bash
pmenu_msgbox "Success" "Operation completed"
```

### 3. pmenu_yesno

Displays a confirmation dialog with Yes/No buttons. Result is determined by exit code.

**Usage:**

```bash
pmenu_yesno "Confirm Title" "Question text?"
```

**Exit Code:**

- `0` - User clicked "Yes"
- `1` - User clicked "No"

**Output:** None

**Pattern:**

```bash
if pmenu_yesno "Confirm" "Delete this file?"; then
    rm /path/to/file
    pmenu_msgbox "Success" "File deleted"
else
    pmenu_msgbox "Cancelled" "File kept"
fi
```

### 4. pmenu_inputbox

Displays an input field for user text entry.

**Usage:**

```bash
pmenu_inputbox "Dialog Title" "Prompt text" ["Default value"]
```

**Exit Code:**

- `0` - User clicked OK
- `1` - User clicked Cancel

**Output:** User input is printed to stdout, visible on screen during typing

**Pattern:**

```bash
pmenu_inputbox "Configuration" "Enter hostname:" "localhost"
if [[ $? -eq 0 ]]; then
    pmenu_msgbox "Saved" "Hostname saved"
else
    pmenu_msgbox "Cancelled" "Not saved"
fi
```

## Common Patterns

### Inline Yes/No Decision

```bash
if pmenu_yesno "Confirm" "Are you sure?"; then
    perform_action
fi
```

### Store Decision for Later

```bash
pmenu_yesno "Question" "Proceed?"
user_choice=$?

# Do other work...

if [[ $user_choice -eq 0 ]]; then
    perform_action
fi
```

### Chain Multiple Dialogs

```bash
pmenu_menu "Main Menu" "a" "Option A" "b" "Option B"
if [[ $? -eq 0 ]]; then
    pmenu_yesno "Confirm" "Proceed with selection?"
    if [[ $? -eq 0 ]]; then
        pmenu_msgbox "Success" "Done!"
    fi
fi
```

## Python API (Advanced)

For direct Python usage without the bash wrapper:

```bash
# Source the docstring:
/home/divix/divtools/scripts/venvs/dtpmenu/bin/python \
    /home/divix/divtools/projects/dtpmenu/dtpmenu.py --help
```

Or read the comprehensive docstring in `dtpmenu.py` (300+ lines of usage documentation).

## Troubleshooting

### Dialog Appears Top-Left Instead of Centered

**Problem:** You used command substitution or output redirection.

**Solution:** Use direct execution (no `$()` or `>`).

```bash
# ❌ Wrong
choice=$(pmenu_menu "Title" "a" "A")

# ✅ Correct
pmenu_menu "Title" "a" "A"
```

**Explanation:** See [BASH-INTEGRATION.md](docs/BASH-INTEGRATION.md)

### Menu Doesn't Appear at All

**Problem:** Dependencies not installed or Textual library missing.

**Solution:**

```bash
cd /home/divix/divtools
bash projects/dtpmenu/install_dtpmenu_deps.sh
```

Then test:

```bash
bash projects/dtpmenu/demo_menu.sh
```

### Can't Capture User Input Programmatically

**Current Behavior:** User input appears on screen in the TUI as they type, but cannot be captured by bash command substitution without breaking centering.

**Workaround:** Use `--output-file` flag if dtpmenu.py is extended to support it (future enhancement).

**Current Best Practice:** Use exit codes to determine if user confirmed input, then handle accordingly.

## Development

Tests are in the `test/` folder. Run with:

```bash
cd /home/divix/divtools/projects/dtpmenu
python -m pytest test/
```

## Architecture

- **dtpmenu.py**: Main Textual application (300+ line docstring included)
- **dt_pmenu_lib.sh**: Bash wrapper functions with detailed usage comments
- **demo_menu.sh**: Interactive demo showing all modes
- **CSS-based centering**: No widget containers, pure CSS alignment

## Developer Notes

### Virtual Environment

This tool runs in a dedicated virtual environment at `$DIVTOOLS/scripts/venvs/dtpmenu`.

**Why call the binary directly?**
The library calls the Python binary inside the venv directly (`$VENV/bin/python`) instead of requiring the user to "activate" it. This is the **standard for automated scripts** because:

1. It is **Non-Destructive**: It doesn't modify your current shell's `$PATH` or environment.
2. It is **Reliable**: It works perfectly in non-interactive shells, cron jobs, and background tasks.
3. It is **Explicit**: It ensures the correct library versions are used regardless of the system's global Python settings.

### Centering Mechanism

Centering is handled by the `Screen.styles.align` property. For this to work, the dialog container has `width: auto`, which causes it to "shrink-wrap" its content. If you specify a fixed width via `--width`, it will still center as long as that width is less than the terminal width.
