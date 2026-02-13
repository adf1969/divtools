#!/bin/bash
# Bash wrapper for dt_ads_native.py
# Last Updated: 01/14/2026 5:40:00 PM CST
#
# This script simply calls the Python version using the dtpyutil venv.
# All functionality has been moved to the Python implementation.

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Find DIVTOOLS
if [[ -z "$DIVTOOLS" ]]; then
    DIVTOOLS="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

# Path to Python in dtpyutil venv
PYTHON_CMD="$DIVTOOLS/scripts/venvs/dtpyutil/bin/python3"
PYTHON_SCRIPT="$SCRIPT_DIR/dt_ads_native.py"

# Check if Python exists
if [[ ! -f "$PYTHON_CMD" ]]; then
    echo "ERROR: dtpyutil Python environment not found at:"
    echo "  $PYTHON_CMD"
    echo ""
    echo "Please install dtpyutil dependencies first:"
    echo "  cd $DIVTOOLS/projects/dtpyutil"
    echo "  bash scripts/install_dtpyutil_deps.sh"
    exit 1
fi

# Check if Python script exists
if [[ ! -f "$PYTHON_SCRIPT" ]]; then
    echo "ERROR: Python script not found at:"
    echo "  $PYTHON_SCRIPT"
    exit 1
fi

# Call the Python script with all arguments, ensuring DIVTOOLS is exported
export DIVTOOLS
"$PYTHON_CMD" "$PYTHON_SCRIPT" "$@"
