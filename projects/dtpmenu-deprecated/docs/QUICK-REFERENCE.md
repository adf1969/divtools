# dtpmenu Quick Reference

## Basic Usage

### Direct Execution (Correct ✅)
```bash
#!/bin/bash
source "$DIVTOOLS/scripts/util/dt_pmenu_lib.sh"

# Enable centering
export PMENU_H_CENTER=1
export PMENU_V_CENTER=1

# Menu - appears centered
pmenu_menu "Main Menu" \
    "option1" "First Option" \
    "option2" "Second Option" \
    "exit" "Exit"

# Message box
pmenu_msgbox "Title" "This message is centered"

# Yes/No dialog
pmenu_yesno "Confirm" "Do you want to proceed?"
# Returns: 0 for Yes, 1 for No

# Input box
pmenu_inputbox "Username" "Enter your name:" "DefaultName"
```

## Environment Variables

```bash
export PMENU_H_CENTER=1    # Horizontal centering (required for centering)
export PMENU_V_CENTER=1    # Vertical centering (required for centering)
export DEBUG_MODE=0        # Set to 1 for debug output (optional)
```

## What NOT to Do

```bash
# ❌ WRONG - Breaks centering!
choice=$(pmenu_menu "Title" "tag1" "Option 1")

# ❌ WRONG - Breaks centering!
pmenu_menu "Title" "tag1" "Option 1" > /tmp/result.txt

# ❌ WRONG - Breaks centering!
pmenu_menu "Title" "tag1" "Option 1" | tee /tmp/output.txt
```

## Working Example: demo_menu.sh

```bash
#!/bin/bash
source "$DIVTOOLS/scripts/util/dt_pmenu_lib.sh"
source "$DIVTOOLS/scripts/util/logging.sh"

export PMENU_H_CENTER=1
export PMENU_V_CENTER=1
export DEBUG_MODE=0

# Direct execution with no output capture
pmenu_menu "Main Menu" \
    "msg" "Show Message" \
    "yn" "Ask Question" \
    "input" "Get Input" \
    "exit" "Exit"

# When TUI exits, continue shell script
log "INFO" "Menu completed"
exit 0
```

## Return Values

### pmenu_menu
- Prints selected tag value to stdout
- Can only be captured AFTER TUI exits (not during)

### pmenu_yesno
- Returns: `0` if user clicked Yes
- Returns: `1` if user clicked No

### pmenu_msgbox
- Returns: `0` on success
- Press OK to dismiss

### pmenu_inputbox
- Prints entered text to stdout
- Returns: `0` if user clicked OK
- Returns: `1` if user clicked Cancel

## Features

- ✅ Horizontal and vertical centering
- ✅ Borders and titles
- ✅ Muted color palette
- ✅ Keyboard navigation
- ✅ Mouse support (where supported)
- ✅ Input validation hooks available in dtpmenu.py

## Debugging

### Check if menu appears centered
```bash
cd /home/divix/divtools
bash projects/dtpmenu/demo_menu.sh
```
Menu should appear in center of screen with cyan/grey/white colors.

### Enable debug output
```bash
export DEBUG_MODE=1
bash projects/dtpmenu/demo_menu.sh
```

### Verify environment setup
```bash
echo "PMENU_H_CENTER=$PMENU_H_CENTER"
echo "PMENU_V_CENTER=$PMENU_V_CENTER"
echo "DEBUG_MODE=$DEBUG_MODE"
```

### Check dtpmenu.py directly
```bash
export PMENU_H_CENTER=1 PMENU_V_CENTER=1
$DIVTOOLS/scripts/venvs/dtpmenu/bin/python \
  $DIVTOOLS/projects/dtpmenu/dtpmenu.py \
  menu --h-center --v-center \
  --title "Test" tag1 "Option 1" tag2 "Option 2"
```

## Documentation

- **[BASH-INTEGRATION.md](BASH-INTEGRATION.md)** - Detailed explanation of why command substitution breaks Textual
- **[SOLUTION-SUMMARY.md](SOLUTION-SUMMARY.md)** - How the centering issue was solved
- **[PROJECT-HISTORY.md](PROJECT-HISTORY.md)** - Complete project timeline

## Installation

```bash
# Install dependencies
cd /home/divix/divtools
bash projects/dtpmenu/install_dtpmenu_deps.sh

# Test it works
bash projects/dtpmenu/demo_menu.sh
```
