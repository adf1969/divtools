#!/bin/bash
# Test Suite for dtpmenu
# Tests initialization and mounting of TUI widgets
# Last Updated: 01/13/2026 15:50:00 PM CDT

# Setup environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
[ -z "$DIVTOOLS" ] && export DIVTOOLS="$PROJECT_ROOT"
LIB_PATH="$DIVTOOLS/scripts/util/dt_pmenu_lib.sh"

source "$DIVTOOLS/scripts/util/logging.sh"
source "$LIB_PATH"

log "HEAD" "Starting dtpmenu Test Suite"

FAILED=0

# Helper function to test a mode
test_mode() {
    local name="$1"
    local run_cmd="$2"
    
    log "INFO" "Testing mode: $name"
    
    # We expect the command to hang (waiting for input) if successful.
    output=$(timeout 2s bash -c "source $LIB_PATH; $run_cmd" 2>&1)
    status=$?
    
    # Check for keywords indicating a Python crash or Textual error screen
    if echo "$output" | grep -iE "Traceback|MountError|ImportError|Exception" > /dev/null; then
        log "RED" "[FAIL] $name crashed or showed error (status $status)"
        log "ERROR" "Output:\n$output"
        FAILED=1
        return
    fi

    if [[ $status -eq 124 ]]; then
        log "BLUE" "[PASS] $name launched successfully (timed out as expected)"
    elif [[ $status -eq 0 ]]; then
        log "WARN" "[WARN] $name exited with 0 (unexpected for interactive tool)"
        log "DEBUG" "Output: $output"
    else
        log "RED" "[FAIL] $name crashed with status $status"
        log "ERROR" "Output:\n$output"
        FAILED=1
    fi
}

# 1. Test MSGBOX
test_mode "MsgBox" 'pmenu_msgbox "Test" "Hello World"'

# 2. Test YESNO
test_mode "YesNo" 'pmenu_yesno "Test" "Yes or No?"'

# 3. Test MENU
test_mode "Menu" 'pmenu_menu "Test" "opt1" "Choice 1" "opt2" "Choice 2"'

# 4. Test INPUTBOX
test_mode "InputBox" 'pmenu_inputbox "Test" "Enter something:" "Default"'

if [[ $FAILED -eq 0 ]]; then
    log "HEAD" "All tests PASSED"
    exit 0
else
    log "RED" "Some tests FAILED. See log above."
    exit 1
fi
