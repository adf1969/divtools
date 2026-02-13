#!/bin/bash
# Test script for dtpmenu
# Last Updated: 01/13/2026 15:20:00 PM CDT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Ensure DIVTOOLS is set, or try to deduce it
if [[ -z "$DIVTOOLS" ]]; then
    export DIVTOOLS="$(dirname "$(dirname "$SCRIPT_DIR")")"
fi

# Source the library which handles the venv path
source "$DIVTOOLS/scripts/util/dt_pmenu_lib.sh"

echo "Testing dtpmenu integration (via library)..."

# Test Msgbox
echo "--- Testing MsgBox ---"
pmenu_msgbox "Test Msgbox" "This is a test message.\nLine 2.\nLine 3."
if [[ $? -eq 0 ]]; then echo "Msgbox OK"; else echo "Msgbox FAILED"; fi
sleep 1

# Test YesNo
echo "--- Testing YesNo ---"
echo "Press ENTER to select Default (No) or TAB to setup Yes"
pmenu_yesno "Test YesNo" "Do you like Python?"
res=$?
if [[ $res -eq 0 ]]; then echo "You said YES";
elif [[ $res -eq 1 ]]; then echo "You said NO";
else echo "Failed/Cancelled ($res)"; fi
sleep 1

# Test Menu
echo "--- Testing Menu ---"
echo "Launching Menu..."
pmenu_menu "Test Menu" "opt1" "Option One" "opt2" "Option Two" "opt3" "Option Three"
res=$?
echo "Menu Result: $res"
# Note: Menu returns exit code 0 if successful, but we need to capture stdout for the selected tag?
# The original python script prints the choice to stdout.
# The wrapper _dtpmenu_call runs the command. 
# So $(pmenu_menu ...) should capture the output.
