#!/bin/bash
# bash_wrapper.sh - Bash Wrapper for dtpyutil Menu System
# Provides convenient functions for displaying Textual-based dialogs
# Last Updated: 01/14/2026 12:50:00 PM CDT
#
# CRITICAL INTEGRATION RULES:
# ============================
# 1. Uses file-based IPC to fix command substitution centering issues
# 2. Menu results written to temp file, read after TUI exits
# 3. Allows proper: choice=$(pmenu_menu "Title" "opt1" "Option 1")
# 4. Preserves centering since TUI has exclusive terminal control during execution
#
# See $DIVTOOLS/projects/dtpyutil/docs/BASH-INTEGRATION.md for full details

# Define path to python script & venv
DTPMENU_SCRIPT="$DIVTOOLS/projects/dtpyutil/src/dtpyutil/menu/dtpmenu.py"
DTPMENU_VENV="$DIVTOOLS/scripts/venvs/dtpyutil"
PYTHON_CMD="$DTPMENU_VENV/bin/python"

# Check if dtpyutil environment is ready
check_dtpmenu_deps() {
    if [[ ! -x "$PYTHON_CMD" ]]; then
        echo "ERROR: dtpyutil virtual environment not found at $DTPMENU_VENV" >&2
        echo "Please run the setup script: $DIVTOOLS/projects/dtpyutil/scripts/install_dtpyutil_deps.sh" >&2
        return 1
    fi
    
    if ! "$PYTHON_CMD" -c "import textual" &>/dev/null; then
        echo "ERROR: 'textual' library missing in venv." >&2
        echo "Please run the setup script: $DIVTOOLS/projects/dtpyutil/scripts/install_dtpyutil_deps.sh" >&2
        return 1
    fi
    
    # Check if dtpyutil package is installed
    if ! "$PYTHON_CMD" -c "from dtpyutil.menu import DtpMenuApp" &>/dev/null 2>&1; then
        echo "WARN: dtpyutil package not installed in editable mode (non-critical)" >&2
    fi
    
    return 0
}

# Generic wrapper to call the python script with file-based IPC
# Usage: _dtpmenu_call COMMAND [ARGS...]
# Returns: Exit code from dtpmenu process (0 for success, 1 for cancel/error)
# Output: Prints menu selection or user input (from temp file after TUI exits)
_dtpmenu_call() {
    local cmd="$1"
    shift
    
    # Check if environment flags are set
    local flags=()
    [[ "${DEBUG_MODE:-0}" == "1" ]] && flags+=("--debug")
    [[ "${PMENU_H_CENTER:-0}" == "1" ]] && flags+=("--h-center")
    [[ "${PMENU_V_CENTER:-0}" == "1" ]] && flags+=("--v-center")
    
    check_dtpmenu_deps || return 127

    # Create temp file for output (file-based IPC)
    local output_file="/tmp/pmenu_result_$$_$RANDOM.txt"
    flags+=("--output-file" "$output_file")
    
    # Run the python script using the venv interpreter with unbuffered output
    # PYTHONUNBUFFERED=1 ensures Textual can properly control the terminal for centering
    if [[ "${DEBUG_MODE:-0}" == "1" ]]; then
        echo "DEBUG: Running: PYTHONUNBUFFERED=1 $PYTHON_CMD $DTPMENU_SCRIPT $cmd ${flags[@]} $@" >&2
        echo "DEBUG: Output file: $output_file" >&2
    fi
    
    PYTHONUNBUFFERED=1 "$PYTHON_CMD" "$DTPMENU_SCRIPT" "$cmd" "${flags[@]}" "$@"
    local exit_code=$?
    
    # Read result from file (if exists) and print to stdout
    if [[ -f "$output_file" ]]; then
        cat "$output_file"
        rm -f "$output_file"
    fi
    
    return $exit_code
}

# Display a menu and capture selection via file-based IPC
# Usage: choice=$(pmenu_menu "Title" "Tag1" "Desc1" "Tag2" "Desc2" ...)
# Returns: Selected tag to stdout (can be captured with command substitution)
#          Exit code 0 if user made selection
#          Exit code 1 if user cancelled
# 
# PATTERN 1 - Capture selection (NOW WORKS - uses file-based IPC):
#   choice=$(pmenu_menu "Choose Option" "a" "Apple" "b" "Banana" "c" "Cherry")
#   if [[ $? -eq 0 ]]; then
#       echo "User selected: $choice"
#   fi
#
# PATTERN 2 - Use in conditionals:
#   if pmenu_menu "Choose Option" "a" "Apple" "b" "Banana" >/dev/null; then
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
# Returns: "yes" or "no" to stdout
#          Exit code 0 if user clicked "Yes"
#          Exit code 1 if user clicked "No"
#
# PATTERN - Simple decision:
#   if pmenu_yesno "Confirm" "Delete everything?" >/dev/null; then
#       perform_dangerous_operation
#   else
#       echo "Operation cancelled"
#   fi
#
# PATTERN - Capture result:
#   answer=$(pmenu_yesno "Confirm" "Proceed?")
#   if [[ "$answer" == "yes" ]]; then
#       perform_backup
#   fi
pmenu_yesno() {
    local title="$1"
    local text="$2"
    _dtpmenu_call "yesno" --title "$title" "$text"
}

# Display an input box for user text entry
# Usage: user_input=$(pmenu_inputbox "Title" "Prompt" ["Default Value"])
# Returns: User-entered text to stdout (can be captured with command substitution)
#          Exit code 0 if user clicked "OK"
#          Exit code 1 if user clicked "Cancel"
#
# PATTERN - Capture input (NOW WORKS - uses file-based IPC):
#   hostname=$(pmenu_inputbox "Setup" "Enter hostname:" "localhost")
#   if [[ $? -eq 0 ]]; then
#       echo "Hostname set to: $hostname"
#   else
#       echo "User cancelled input"
#   fi
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
