#!/bin/bash
# Test script for timed prompt in host_setup_checks.sh
# Last Updated: 11/11/2025 10:10:00 PM CDT

echo "Testing timed prompt functionality..."
echo ""
echo "This will simulate the timed prompt in host_setup_checks.sh"
echo "You have 10 seconds to press 'Y' or it will auto-select 'No'"
echo ""

# Enable debug mode
export DEBUG_MODE=1
export TEST_MODE=1

# Define debug_log function (needed by host_setup_checks.sh)
debug_log() {
    if [[ $DEBUG_MODE -eq 1 ]]; then
        echo -e "\033[37m[DEBUG] $*\033[0m" >&2
    fi
}

# Source ONLY the timed_setup_prompt function
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source <(sed -n '/^timed_setup_prompt()/,/^}/p' "$SCRIPT_DIR/../host_setup_checks.sh")

# Call the timed prompt function directly
if timed_setup_prompt; then
    echo "✅ User said YES - would proceed to whiptail menu"
else
    echo "❌ User said NO or timed out - setup skipped"
fi
