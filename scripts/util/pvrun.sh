#!/bin/bash
# Generic Python Virtual Environment Runner
# Last Updated: 11/25/2025 7:40:00 PM CST
# 
# Usage: pvrun.sh -v <venv> -p <path> -s <script> [--test] [--debug] [extra args...]
# 
# Options:
#   -v, --venv <venv>        Name of venv in $DIVTOOLS/scripts/venvs/ (required)
#   -p, --path <path>        Working directory to launch from (required)
#   -s, --script <script>    Python script filename to run (required)
#   --test                   Pass --test flag to Python script (test mode)
#   --debug                  Pass --debug flag to Python script (debug mode)
#   [extra args...]          Any other arguments passed directly to Python script
#
# Examples:
#   pvrun.sh -v hass -p scripts/hass -s gen_presence_sensors.py --exclude-labels "christmas,zigrouter"
#   pvrun.sh -v o365_mon -p scripts/office365 -s o365_chk_alerts.py -m andrew@avcorp.biz
#   pvrun.sh -v hass -p scripts/hass -s gen_presence_sensors.py --debug --test

set -e

# Source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/logging.sh"

# Divtools root
DIVTOOLS="${DIVTOOLS:-/opt/divtools}"
VENV_ROOT="$DIVTOOLS/scripts/venvs"

# Initialize variables
VENV_NAME=""
WORK_PATH=""
PYTHON_SCRIPT=""
PY_TEST_FLAG=0
PY_DEBUG_FLAG=0
declare -a PY_ARGS=()

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -v|--venv)
      VENV_NAME="$2"
      shift 2
      ;;
    -p|--path)
      WORK_PATH="$2"
      shift 2
      ;;
    -s|--script)
      PYTHON_SCRIPT="$2"
      shift 2
      ;;
    --test)
      PY_TEST_FLAG=1
      shift
      ;;
    --debug)
      PY_DEBUG_FLAG=1
      shift
      ;;
    *)
      # Collect all other args for the Python script
      PY_ARGS+=("$1")
      shift
      ;;
  esac
done

# Validate required arguments
if [ -z "$VENV_NAME" ]; then
  log ERROR "Missing required argument: -v|--venv <venv>"
  exit 1
fi

if [ -z "$WORK_PATH" ]; then
  log ERROR "Missing required argument: -p|--path <path>"
  exit 1
fi

if [ -z "$PYTHON_SCRIPT" ]; then
  log ERROR "Missing required argument: -s|--script <script>"
  exit 1
fi

# Resolve venv path
VENV_PATH="$VENV_ROOT/$VENV_NAME"

if [ ! -d "$VENV_PATH" ]; then
  log ERROR "Virtual environment not found: $VENV_PATH"
  log ERROR "Available venvs in $VENV_ROOT:"
  if [ -d "$VENV_ROOT" ]; then
    ls -1 "$VENV_ROOT" | sed 's/^/  /' || log ERROR "  (none found)"
  else
    log ERROR "  (venv directory does not exist)"
  fi
  exit 1
fi

if [ ! -f "$VENV_PATH/bin/activate" ]; then
  log ERROR "Invalid virtual environment: $VENV_PATH/bin/activate not found"
  exit 1
fi

# Resolve work directory (relative to DIVTOOLS or absolute)
if [[ "$WORK_PATH" = /* ]]; then
  FULL_WORK_PATH="$WORK_PATH"
else
  FULL_WORK_PATH="$DIVTOOLS/$WORK_PATH"
fi

if [ ! -d "$FULL_WORK_PATH" ]; then
  log ERROR "Working directory not found: $FULL_WORK_PATH"
  exit 1
fi

# Resolve Python script path
FULL_SCRIPT_PATH="$FULL_WORK_PATH/$PYTHON_SCRIPT"

if [ ! -f "$FULL_SCRIPT_PATH" ]; then
  log ERROR "Python script not found: $FULL_SCRIPT_PATH"
  exit 1
fi

if [ ! -x "$FULL_SCRIPT_PATH" ]; then
  log WARN "Python script is not executable: $FULL_SCRIPT_PATH"
fi

# Build Python command
declare -a PY_CMD=("$FULL_SCRIPT_PATH")

# Add test/debug flags first
if [ $PY_TEST_FLAG -eq 1 ]; then
  PY_CMD+=("--test")
fi

if [ $PY_DEBUG_FLAG -eq 1 ]; then
  PY_CMD+=("--debug")
fi

# Add user-provided arguments
if [ ${#PY_ARGS[@]} -gt 0 ]; then
  PY_CMD+=("${PY_ARGS[@]}")
fi

# Log execution details
log INFO "Virtual Environment: $VENV_NAME ($VENV_PATH)"
log INFO "Working Directory: $FULL_WORK_PATH"
log INFO "Python Script: $PYTHON_SCRIPT"
[ $PY_TEST_FLAG -eq 1 ] && log INFO "Test Mode: enabled"
[ $PY_DEBUG_FLAG -eq 1 ] && log INFO "Debug Mode: enabled"
if [ ${#PY_ARGS[@]} -gt 0 ]; then
  log INFO "Additional Arguments: ${PY_ARGS[*]}"
fi

# Activate venv and run script
log INFO "Activating virtual environment..."
source "$VENV_PATH/bin/activate"

log INFO "Executing: ${PY_CMD[*]}"
cd "$FULL_WORK_PATH"

# Run the Python script with all collected arguments
"${PY_CMD[@]}"
SCRIPT_EXIT_CODE=$?

# Deactivate venv
deactivate

if [ $SCRIPT_EXIT_CODE -eq 0 ]; then
  log INFO "Script completed successfully"
else
  log ERROR "Script failed with exit code: $SCRIPT_EXIT_CODE"
fi

exit $SCRIPT_EXIT_CODE
