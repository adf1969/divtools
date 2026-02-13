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

**✅ CORRECT - Direct execution**
```bash
# Direct execution allows Textual full terminal control for centering
pmenu_menu "Title" "tag1" "Option 1"
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

## Solution: IPC Without Output Capture

Since we cannot capture output during TUI execution, use one of these approaches:

### Option A: Direct Execution (Simplest)
For simple use cases, just let the TUI run and handle user input directly in the TUI:

```bash
#!/bin/bash
source "$DIVTOOLS/scripts/util/dt_pmenu_lib.sh"

export PMENU_H_CENTER=1
export PMENU_V_CENTER=1

# Just run the TUI - user selects, TUI exits
pmenu_menu "Main Menu" \
    "msg" "Message Box" \
    "yn" "Yes/No Dialog" \
    "input" "Input Box" \
    "exit" "Exit"
```

**Pros:**
- Simple, clean code
- Centering works perfectly
- TUI has full terminal control

**Cons:**
- Cannot programmatically react to user selection
- Best for standalone tools where user action is the endpoint

### Option B: Two-Step Process
Separate the menu display from the action handling:

```bash
#!/bin/bash
source "$DIVTOOLS/scripts/util/dt_pmenu_lib.sh"

export PMENU_H_CENTER=1
export PMENU_V_CENTER=1

# Step 1: Show menu (runs standalone, no capture)
pmenu_menu "Main Menu" \
    "msg" "Show Message" \
    "yn" "Yes/No Question" \
    "input" "Enter Data" \
    "exit" "Exit Program"

# Step 2: After menu exits, you can do post-processing
# (but user selection info is already handled by the TUI)
log "INFO" "Menu completed, exiting..."
exit 0
```

### Option C: Write to File AFTER TUI Completes (Advanced)
If you absolutely must capture the result, have **dtpmenu write to a file** itself:

```bash
# Modify dtpmenu.py to accept: --output-file /tmp/result.txt
# Then read the file AFTER the TUI has exited (not during execution)

RESULT_FILE="/tmp/menu_result_$$.txt"
export PMENU_OUTPUT_FILE="$RESULT_FILE"

pmenu_menu "Title" "tag1" "Option 1" "tag2" "Option 2"
# TUI now complete and has full terminal control

# NOW (after TUI exits) read the result
if [[ -f "$RESULT_FILE" ]]; then
    choice=$(cat "$RESULT_FILE")
    rm "$RESULT_FILE"
    # Process the choice...
fi
```

**This requires dtpmenu.py modifications** to support `--output-file` flag.

## Environment Variables for Centering

Always set these in your bash wrapper to enable centering:

```bash
export PMENU_H_CENTER=1    # Enable horizontal centering
export PMENU_V_CENTER=1    # Enable vertical centering
export DEBUG_MODE=0        # Set to 1 for debug output
```

The `dt_pmenu_lib.sh` wrapper automatically passes these as `--h-center` and `--v-center` flags to dtpmenu.py.

## Unbuffered I/O (PYTHONUNBUFFERED)

The `dt_pmenu_lib.sh` wrapper includes this:
```bash
PYTHONUNBUFFERED=1 "$PYTHON_CMD" "$DTPMENU_SCRIPT" ...
```

This ensures Python doesn't buffer output, allowing Textual to respond immediately to terminal events. **However, this alone is not sufficient if you also have output redirection.**

## Testing Your Integration

### ✅ Working Pattern
```bash
#!/bin/bash
source "$DIVTOOLS/scripts/util/dt_pmenu_lib.sh"

export PMENU_H_CENTER=1
export PMENU_V_CENTER=1

# Direct execution - should be centered
pmenu_menu "Test Menu" \
    "opt1" "Option 1" \
    "opt2" "Option 2" \
    "exit" "Exit"

log "INFO" "Menu completed"
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
source "$DIVTOOLS/scripts/util/dt_pmenu_lib.sh"

export PMENU_H_CENTER=1
export PMENU_V_CENTER=1

# Using command substitution - BREAKS centering
choice=$(pmenu_menu "Test Menu" \
    "opt1" "Option 1" \
    "opt2" "Option 2" \
    "exit" "Exit")

log "INFO" "User selected: $choice"
exit 0
```

**Test command:**
```bash
bash your_script.sh
# Menu appears top-left - BROKEN centering!
```

## Real-World Example: demo_menu.sh

The working implementation:

```bash
main_menu() {
    local last_load_time=0
    
    while true; do
        clear
        log "HEAD" "DTPMENU INTERACTIVE DEMO"
        log "DEBUG" "Environment: H_CENTER=$PMENU_H_CENTER, V_CENTER=$PMENU_V_CENTER"
        
        # Direct execution - NO redirection, NO command substitution
        local start_menu=$(get_ms)
        pmenu_menu "Main Demo Menu (H/V Centered)" \
            "msg" "Test Message Box" \
            "yn" "Test Yes/No Dialog" \
            "input" "Test Input Box" \
            "exit" "Exit Demo"
        local end_menu=$(get_ms)
        last_load_time=$((end_menu - start_menu))
        
        # TUI has exited, we're back at shell
        exit 0
    done
}
```

## Debugging Terminal Control Issues

If centering still doesn't work, check:

1. **Verify dtpmenu.py is centered when called directly:**
   ```bash
   export PMENU_H_CENTER=1 PMENU_V_CENTER=1
   $DIVTOOLS/scripts/venvs/dtpmenu/bin/python \
     $DIVTOOLS/projects/dtpmenu/dtpmenu.py \
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
| Direct execution | ✅ YES | Full terminal control |
| Command substitution `$()` | ❌ NO | Pipes stdout, breaks terminal detection |
| Output redirection `>` | ❌ NO | Redirects to file, Textual can't control terminal |
| Pipe `\|` | ❌ NO | Pipes stdout, breaks Textual |
| PYTHONUNBUFFERED=1 | ✅ YES (if no redirection) | Disables output buffering |
| stdbuf utility | ❌ NO | Interferes with Textual's terminal control |

**The bottom line: Textual TUI applications MUST run with unrestricted stdout/stderr to maintain terminal control and proper centering.**
