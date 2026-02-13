#!/bin/bash
# dt_menu_lib.sh - Bash Wrapper for dtmenu Go binary
# Last Updated: 01/13/2026 11:47:00 AM CDT

# Define path to binary
DTMENU_BIN="$DIVTOOLS/bin/dtgmenu"

# Function to show menu
# Usage: dt_menu "Title" "Tag1" "Desc1" "Tag2" "Desc2" ...
# Returns selected tag on stdout
dt_gmenu() {
    local title="$1"
    shift
    
    # Check if binary exists
    if [[ ! -x "$DTMENU_BIN" ]]; then
        echo "ERROR: dtmenu binary not found at $DTMENU_BIN" >&2
        echo "Please build it: cd $DIVTOOLS/projects/dtgmenu && go build -o $DIVTOOLS/bin/dtmenu main.go" >&2
        return 1
    fi

    # Run the binary
    "$DTMENU_BIN" --title "$title" "$@"
    local exit_code=$?
    
    return $exit_code
}

# Compatibility alias for PRD spec
tui_menu() {
    dt_gmenu "$@"
}
