#!/bin/bash
# dt_pmenu_lib.sh - Bash Wrapper for dtpmenu Python Library
# Provides convenient functions for displaying Textual-based dialogs
# Last Updated: 01/14/2026 03:45:00 AM CDT
#
# CRITICAL INTEGRATION RULES:
# ============================
# 1. DO NOT capture stdout during TUI execution: choice=$(pmenu_menu ...)
# 2. DO NOT redirect output: pmenu_menu ... > /tmp/file.txt
# 3. DO allow direct terminal control for centering to work
# 4. YOU CAN capture exit codes: pmenu_yesno ...; if [[ $? -eq 0 ]]; then ...
# 5. YOU CAN capture exit codes from multi-value returns (see examples below)
#
# See $DIVTOOLS/projects/dtpmenu/dtpmenu.py for full documentation
# See $DIVTOOLS/projects/dtpmenu/docs/BASH-INTEGRATION.md for patterns

# Define path to python script & venv
DTPMENU_SCRIPT="$DIVTOOLS/projects/dtpmenu/dtpmenu.py"
DTPMENU_VENV="$DIVTOOLS/scripts/venvs/dtpmenu"
PYTHON_CMD="$DTPMENU_VENV/bin/python"

# Check if dtpmenu environment is ready
check_dtpmenu_deps() {
    if [[ ! -x "$PYTHON_CMD" ]]; then
        echo "ERROR: dtpmenu virtual environment not found at $DTPMENU_VENV" >&2
        echo "Please run the setup script: $DIVTOOLS/projects/dtpmenu/install_dtpmenu_deps.sh" >&2
        return 1
    fi
    
    if ! "$PYTHON_CMD" -c "import textual" &>/dev/null; then
        echo "ERROR: 'textual' library missing in venv." >&2
        echo "Please run the setup script: $DIVTOOLS/projects/dtpmenu/install_dtpmenu_deps.sh" >&2
        return 1
    fi
    return 0
}

# Generic wrapper to call the python script
# Usage: _dtpmenu_call COMMAND [ARGS...]
# Returns: Exit code from dtpmenu process (0 for success, 1 for cancel/error)
# Output: Prints menu selection or user input (if applicable to mode)
_dtpmenu_call() {
    local cmd="$1"
    shift
    
    # Check if environment flags are set
    local flags=()
    [[ "${DEBUG_MODE:-0}" == "1" ]] && flags+=("--debug")
    [[ "${PMENU_H_CENTER:-0}" == "1" ]] && flags+=("--h-center")
    [[ "${PMENU_V_CENTER:-0}" == "1" ]] && flags+=("--v-center")
    
    check_dtpmenu_deps || return 127

    # Run the python script using the venv interpreter with unbuffered output
    # PYTHONUNBUFFERED=1 ensures Textual can properly control the terminal for centering
    if [[ "${DEBUG_MODE:-0}" == "1" ]]; then
        echo "DEBUG: Running: PYTHONUNBUFFERED=1 $PYTHON_CMD $DTPMENU_SCRIPT $cmd ${flags[@]} $@" >&2
    fi
    PYTHONUNBUFFERED=1 "$PYTHON_CMD" "$DTPMENU_SCRIPT" "$cmd" "${flags[@]}" "$@"
}

# Display a menu and run directly on terminal (no output capture)
# Usage: pmenu_menu "Title" "Tag1" "Desc1" "Tag2" "Desc2" ...
# Returns: Nothing during execution (dialog appears centered on screen)
#          Exit code 0 if user made selection
#          Exit code 1 if user cancelled
# 
# PATTERN 1 - Direct execution (simplest, recommended):
#   pmenu_menu "Choose Option" "a" "Apple" "b" "Banana" "c" "Cherry"
#   # User selects, dialog closes, script continues
#
# PATTERN 2 - Check if selection was made:
#   pmenu_menu "Choose Option" "a" "Apple" "b" "Banana"
#   if [[ $? -eq 0 ]]; then
#       echo "User made a selection"
#   else
#       echo "User cancelled"
#   fi
pmenu_menu() {
    local title="$1"
    shift
    _dtpmenu_call "menu" --title "$title" "$@"
}

# Display a message box
# Usage: pmenu_msgbox "Title" "Message Text with \\\\n for newlines"
# Returns: Exit code 0 on success
# Output: None (informational only)
#
# PATTERN:
#   pmenu_msgbox "Operation Complete" "File saved successfully"
pmenu_msgbox() {
    local title="$1"
    local text="$2"
    _dtpmenu_call "msgbox" --title "$title" "$text"
}

# Display a Yes/No dialog with standard button responses
# Usage: pmenu_yesno "Title" "Question Text"
# Returns: Exit code 0 if user clicked "Yes"
#          Exit code 1 if user clicked "No"
# Output: None (result determined by exit code)
#
# PATTERN - Simple decision:
#   if pmenu_yesno "Confirm" "Delete everything?"; then
#       perform_dangerous_operation
#   else
#       echo "Operation cancelled"
#   fi
#
# PATTERN - Store result for later use:
#   pmenu_yesno "Confirm" "Proceed with backup?"
#   result=$?
#   # Do other work here...
#   if [[ $result -eq 0 ]]; then
#       perform_backup
#   fi
pmenu_yesno() {
    local title="$1"
    local text="$2"
    _dtpmenu_call "yesno" --title "$title" "$text"
}

# Display an input box for user text entry
# Usage: pmenu_inputbox "Title" "Prompt" ["Default Value"]
# Returns: Exit code 0 if user clicked "OK"
#          Exit code 1 if user clicked "Cancel"
# Output: User-entered text is printed to stdout (when OK is clicked)
#
# PATTERN 1 - Direct execution (user input goes to stdout during execution):
#   pmenu_inputbox "Setup" "Enter hostname:" "localhost"
#   # User types and clicks OK, dialog closes
#
# PATTERN 2 - Capture input after TUI execution:
#   Note: This requires the output to be captured AFTER the dialog closes.
#   Standard bash command substitution doesn't work during execution.
#   For now, user input is shown on screen as they type.
#   To capture input programmatically, dtpmenu.py would need to support
#   --output-file flag to write results to a file.
pmenu_inputbox() {
    local title="$1"
    local text="$2"
    local default="${3:-}"
    
    local args=(--title "$title" "$text")
    if [[ -n "$default" ]]; then
        args+=(--default "$default")
    fi
    
    _dtpmenu_call "inputbox" "${args[@]}"
}
