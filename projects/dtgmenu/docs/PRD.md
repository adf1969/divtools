# PRD: dtmenu - Custom TUI Menu Tool

## 1. Overview
`dtmenu` is a custom Go-based CLI utility designed to provide a robust, visually consistent, "boxed" menu system for Bash scripts in the Divtools environment. It replaces unstable usage of general-purpose tools like `gum choose` or `whiptail` by being purpose-built to render a centered, bordered menu that accepts interaction and returns simple tag values.

## 2. Requirements

### 2.1 Functional Requirements
- **Interactive Menu:**
    - Display a list of selectable items.
    - Navigate using Up/Down arrows.
    - Select using Enter.
    - Exit/Cancel using Esc or Ctrl+C.
    - Returns the "Tag" (value) of the selected item to Stdout.
    - Returns proper Exit Codes (0 = Success, 1 = Cancel/Error).
- **Visual Presentation:**
    - **Boxed Interface:** The entire UI must be wrapped in a styling border (Double or Rounded).
    - **Header/Title:** Display a title at the top of the box.
    - **Color Support:** 
        - Must render usage of ANSI color codes passed in descriptions.
        - Support styling of the title and border.
- **Input Format:**
    - Arguments passed as pairs: `Tag` `Description`.
    - Example: `dtmenu --title="My Menu" "opt1" "Install Docker" "opt2" "Exit"`

### 2.2 Technical Requirements
- **Language:** Go (Golang).
- **Libraries:**
    - `bubbletea` (TUI runtime)
    - `bubbles` (Components like lists)
    - `lipgloss` (Styling)
    - `termenv` (Color profiles)
- **Deployment:** Compiled binary placed in `$DIVTOOLS/bin/dtmenu`.

## 3. Implementation Plan

### Phase 1: Prototype
- Basic Bubble Tea program.
- Uses `bubbles/list` for the menu.
- Uses `lipgloss` to wrap the list in a border.
- Parses command line args (Title then pairs of Tag/Desc).

### Phase 2: Refinement
- Handle ANSI colors in descriptions.
- Add customization flags (e.g., `--border-color`).
- Ensure robust terminal resizing support.

### Phase 3: Integration
- Create `scripts/util/dt_menu_lib.sh` (or `tui_lib.sh`) wrapper function.
- Replace `gum_util.sh` usage in main scripts.

## 4. Usage Example
```bash
# Bash Script
choice=$(dtmenu --title "Main Menu" \
    "1" "System Setup" \
    "2" "Docker Management" \
    "3"  $'\033[31mExit\033[0m') # ANSI Red "Exit"

if [[ $? -eq 0 ]]; then
    echo "User selected: $choice"
else
    echo "Menu cancelled"
fi
```
