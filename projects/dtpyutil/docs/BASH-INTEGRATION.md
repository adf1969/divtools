# dtpmenu Bash Integration Guide

## TL;DR - Critical Rule for Bash Wrappers

**⚠️ CRITICAL: Never capture TUI output using command substitution or output redirection.**

Any of these WILL BREAK centering and TUI display:
```bash
# ❌ BROKEN - Command substitution
choice=$(pmenu_menu "Title" "tag1" "Option 1")

# ❌ BROKEN - Output redirection
pmenu_menu "Title" "tag1" "Option 1" > /tmp/result.txt

# ❌ BROKEN - Pipe redirection  
pmenu_menu "Title" "tag1" "Option 1" | tee /tmp/result.txt
```

**✅ CORRECT - File-based IPC (after --output-file is implemented)**
```bash
# TUI writes result to file on exit, bash reads file afterward
pmenu_menu --output-file /tmp/result.txt "Title" "tag1" "Option 1"
choice=$(cat /tmp/result.txt)
rm /tmp/result.txt
```

## Why This Happens

Textual (the Python TUI framework) needs **exclusive control of the terminal** to:
1. Detect screen dimensions correctly
2. Position the dialog centered on-screen
3. Manage cursor movement and rendering
4. Handle ANSI escape sequences

When you use command substitution `$()` or output redirection `>`, Python's stdout is redirected to a pipe or buffer. This causes:
- Textual's terminal detection to fail
- Screen size detection to return incorrect dimensions (usually pipe/buffer size)
- The dialog to render at the top-left instead of centered
- Partial or missing UI rendering

## Problem Scenario

**Original demo_menu.sh approach (BROKEN):**
```bash
choice=$(pmenu_menu "Main Menu" \
    "msg" "Message Box" \
    "yn" "Yes/No" \
    "exit" "Exit")

case "$choice" in
    msg) pmenu_msgbox "Result" "User chose message" ;;
    exit) exit 0 ;;
esac
```

**Result**: Menu appears top-left, not centered. Dialog rendering incomplete.

## Solution: File-Based IPC

### Implementation Plan

**Step 1**: Add `--output-file` support to dtpmenu.py

```python
# In dtpmenu.py argument parser
parser.add_argument('--output-file', type=str,
                   help='Write selection/input to this file instead of stdout')

# In DtpMenuApp.on_mount() or exit handler
def write_output_file(self, value):
    output_file = self.args.output_file or os.getenv('PMENU_OUTPUT_FILE')
    if output_file:
        try:
            with open(output_file, 'w') as f:
                f.write(value)
        except IOError as e:
            # Log error but don't break TUI
            pass
```

**Step 2**: Update bash wrapper to use files

```bash
pmenu_menu() {
    local title="$1"
    shift
    local args=("$@")
    
    # Create temp file for result
    local result_file="/tmp/pmenu_result_$$.txt"
    
    # Run TUI with --output-file (NO command substitution)
    export PMENU_H_CENTER=1
    export PMENU_V_CENTER=1
    PYTHONUNBUFFERED=1 "$PYTHON_CMD" "$DTPMENU_SCRIPT" \
        menu --h-center --v-center \
        --output-file "$result_file" \
        --title "$title" "${args[@]}"
    
    local exit_code=$?
    
    # Read result from file AFTER TUI exits
    if [[ -f "$result_file" ]]; then
        cat "$result_file"
        rm "$result_file"
    fi
    
    return $exit_code
}
```

**Step 3**: Use in bash scripts

```bash
#!/bin/bash
source "$DIVTOOLS/projects/dtpyutil/src/menu/bash_wrapper.sh"

# Now this works AND centers properly
choice=$(pmenu_menu "Main Menu" \
    "opt1" "Option 1" \
    "opt2" "Option 2" \
    "exit" "Exit")

case "$choice" in
    opt1) echo "Selected option 1" ;;
    opt2) echo "Selected option 2" ;;
    exit) exit 0 ;;
esac
```

## Environment Variables for Centering

Always set these in your bash wrapper to enable centering:

```bash
export PMENU_H_CENTER=1    # Enable horizontal centering
export PMENU_V_CENTER=1    # Enable vertical centering
export DEBUG_MODE=0        # Set to 1 for debug output
```

The `bash_wrapper.sh` automatically passes these as `--h-center` and `--v-center` flags to dtpmenu.py.

## Unbuffered I/O (PYTHONUNBUFFERED)

The bash wrapper includes this:
```bash
PYTHONUNBUFFERED=1 "$PYTHON_CMD" "$DTPMENU_SCRIPT" ...
```

This ensures Python doesn't buffer output, allowing Textual to respond immediately to terminal events. **However, this alone is not sufficient if you also have output redirection.**

## Testing Your Integration

### ✅ Working Pattern (After --output-file Implemented)
```bash
#!/bin/bash
source "$DIVTOOLS/projects/dtpyutil/src/menu/bash_wrapper.sh"

# File-based IPC - should be centered
choice=$(pmenu_menu "Test Menu" \
    "opt1" "Option 1" \
    "opt2" "Option 2" \
    "exit" "Exit")

echo "User selected: $choice"
exit 0
```

**Test command:**
```bash
bash your_script.sh
# Menu should appear perfectly centered on screen
```

### ❌ Broken Pattern  
```bash
#!/bin/bash
source "$DIVTOOLS/projects/dtpyutil/src/menu/bash_wrapper.sh"

# BROKEN - This will NEVER work, even with proper wrapper
choice=$(python3 dtpmenu.py menu --title "Test" opt1 "Option 1")

# BROKEN - Direct command substitution bypasses wrapper's file handling
choice=$(pmenu_menu "Test Menu" \
    "opt1" "Option 1" \
    "opt2" "Option 2" \
    "exit" "Exit")

# Menu appears top-left - BROKEN centering!
```

## Debugging Terminal Control Issues

If centering still doesn't work, check:

1. **Verify dtpmenu.py is centered when called directly:**
   ```bash
   export PMENU_H_CENTER=1 PMENU_V_CENTER=1
   $DIVTOOLS/scripts/venvs/dtpyutil/bin/python \
     $DIVTOOLS/projects/dtpyutil/src/menu/dtpmenu.py \
     menu --h-center --v-center \
     --title "Test" tag1 "Option 1" tag2 "Option 2"
   ```
   Should show centered menu. If yes, dtpmenu.py is fine.

2. **Check for output redirection in the call chain:**
   ```bash
   # Trace the command to ensure no redirections
   set -x
   bash your_wrapper_script.sh
   set +x
   ```

3. **Verify environment variables:**
   ```bash
   echo "PMENU_H_CENTER=$PMENU_H_CENTER"
   echo "PMENU_V_CENTER=$PMENU_V_CENTER"
   echo "DEBUG_MODE=$DEBUG_MODE"
   ```

4. **Check stdbuf is not being used:**
   Textual doesn't like being run through `stdbuf`. Remove any:
   ```bash
   # ❌ Bad
   stdbuf -oL -eL python dtpmenu.py ...
   
   # ✅ Good
   PYTHONUNBUFFERED=1 python dtpmenu.py ...
   ```

## Summary: Terminal Control Best Practices

| Pattern | Works | Why |
|---------|-------|-----|
| File-based IPC (--output-file) | ✅ YES | TUI has full terminal control, file written after exit |
| Direct execution (no capture) | ✅ YES | Full terminal control, but can't get return value |
| Command substitution `$()` | ❌ NO | Pipes stdout, breaks terminal detection |
| Output redirection `>` | ❌ NO | Redirects to file, Textual can't control terminal |
| Pipe `\|` | ❌ NO | Pipes stdout, breaks Textual |
| PYTHONUNBUFFERED=1 | ✅ YES (if no redirection) | Disables output buffering |
| stdbuf utility | ❌ NO | Interferes with Textual's terminal control |

**The bottom line: Textual TUI applications MUST run with unrestricted stdout/stderr to maintain terminal control and proper centering. Use `--output-file` to write results to a file AFTER the TUI exits.**

## Migration Status

### Current Status (Jan 14, 2026)

- **--output-file Support**: ❌ Not yet implemented in dtpmenu.py
- **bash_wrapper.sh**: ❌ Not yet updated to use file-based IPC
- **demo_menu.sh**: ❌ Still uses command substitution (broken centering)

### Implementation Checklist

- [ ] Add `--output-file` argument to dtpmenu.py
- [ ] Add `PMENU_OUTPUT_FILE` environment variable support
- [ ] Implement file writing in all dialog modes (menu, msgbox, yesno, inputbox)
- [ ] Update bash_wrapper.sh to use temp files
- [ ] Update demo_menu.sh to demonstrate file-based IPC
- [ ] Test centering with file-based approach
- [ ] Document examples in this file

### After Implementation

Once `--output-file` is implemented, this will be the standard pattern:

```bash
# Wrapper handles temp file creation/cleanup internally
choice=$(pmenu_menu "Title" "opt1" "Option 1")  # Works AND centers
```

Internally, the wrapper does:
```bash
pmenu_menu() {
    local temp_file="/tmp/pmenu_$$_$RANDOM.txt"
    python dtpmenu.py --output-file "$temp_file" "$@"  # No stdout capture
    cat "$temp_file"  # Read result after TUI exits
    rm "$temp_file"
}
```

This preserves the bash ergonomics while fixing the terminal control issue.

## Historical Context

This document was created during the dtpmenu project (Jan 13-14, 2026) after discovering that command substitution fundamentally breaks Textual TUI centering. This realization led to:

1. Creation of this documentation
2. Decision to implement `--output-file` support
3. Migration to dtpyutil architecture with proper file-based IPC

The lessons learned here are CRITICAL for any future Python TUI development in divtools.
