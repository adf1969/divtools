#!/bin/bash
# Debug script for testing inputbox mode
# Last Updated: 01/14/2026 11:30:00 AM CDT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "$DIVTOOLS" ] && export DIVTOOLS="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$DIVTOOLS/scripts/util/dt_pmenu_lib.sh"
source "$DIVTOOLS/scripts/util/logging.sh"

export PMENU_H_CENTER=1
export PMENU_V_CENTER=1

log "HEAD" "INPUT BOX DEBUG TEST"
log "INFO" "Testing inputbox mode with direct execution"
log "INFO" ""
log "INFO" "Instructions:"
log "INFO" "1. A dialog should appear on your screen"
log "INFO" "2. Clear the default text if you want"
log "INFO" "3. Enter some text"
log "INFO" "4. Click OK or press Enter"
log "INFO" ""

read -p "Press Enter to show the inputbox..."
clear

log "DEBUG" "About to call pmenu_inputbox..."
pmenu_inputbox "User Input Test" "What is your name?" "Guest"
result=$?

clear
log "HEAD" "INPUT BOX RESULT"
log "INFO" "Exit Code: $result"

if [[ $result -eq 0 ]]; then
    log "SUCCESS" "✅ User entered text and clicked OK (exit code 0)"
else
    log "INFO" "ℹ️  User cancelled (exit code 1)"
fi

log "INFO" ""
log "INFO" "This test proves that pmenu_inputbox can be called from bash"
log "INFO" "and returns the proper exit code."
