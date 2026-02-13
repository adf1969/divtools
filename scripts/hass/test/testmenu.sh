#!/bin/bash
# Interactive Pytest Menu for Home Assistant scripts (areas/labels & presence sensors)
# Last Updated: 11/25/2025 7:25:00 PM CST
# Provides a menu (whiptail/dialog/text fallback) to run test suites:
# - All tests
# - Individual test files
# - Individual test functions (auto-discovered)
# Supports verbose (-vv), print outputs (-s), and coverage runs.

# Set whiptail/newt colors to dark blue theme (named colors - hex not supported)
export NEWT_COLORS='
root=white,blue
window=white,blue
border=white,blue
textbox=white,blue
title=white,blue
button=black,white
compactbutton=white,blue
checkbox=white,blue
actcheckbox=white,red
entry=white,blue
label=white,blue
listbox=white,blue
actlistbox=white,cyan
actsellistbox=black,white
sellistbox=white,blue
'

# Menu dimensions (easily adjustable)
MENU_HEIGHT=30
MENU_WIDTH=90
MENU_LIST_HEIGHT=20

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)" # scripts/hass
TEST_DIR="${SCRIPT_DIR}"                       # scripts/hass/test
UTIL_LOGGING="$(cd "${PROJECT_ROOT}/../util" && pwd)/logging.sh"

if [ -f "$UTIL_LOGGING" ]; then
  # shellcheck disable=SC1090
  source "$UTIL_LOGGING"
else
  # Fallback simple logging if util not found
  log() { printf '%s [%s] %s\n' "$(date +'%H:%M:%S')" "$1" "$2"; }
fi

# Detect dialog tool
detect_dialog_tool() {
  if command -v whiptail &>/dev/null; then echo "whiptail"; 
  elif command -v dialog &>/dev/null; then echo "dialog"; 
  elif command -v yad &>/dev/null; then echo "yad"; 
  else echo "none"; fi
}
DIALOG_TOOL="$(detect_dialog_tool)"

# Flags
TEST_MODE=0
DEBUG_MODE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -test|--test)
      TEST_MODE=1
      log INFO "Running in TEST mode - commands will not execute"
      shift
      ;;
    -debug|--debug)
      DEBUG_MODE=1
      log INFO "Debug mode enabled"
      shift
      ;;
    *)
      log ERROR "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Collect test files
mapfile -t TEST_FILES < <(find "$TEST_DIR" -maxdepth 1 -type f -name 'test_*.py' -printf '%f\n' | sort)

# Discover test functions for a file
# Uses pytest collection (-q) and filters nodeids belonging to the file
discover_tests_for_file() {
  local file="$1"
  (cd "$TEST_DIR" || return 1; pytest -q --collect-only "$file" 2>/dev/null | awk '/<Function test_/ {print $2}' )
}

# Run pytest with chosen modifiers
run_pytest() {
  local target="$1"; shift
  local mode="$1"; shift
  local extra="$*"

  local base_cmd=(pytest "$target")
  case "$mode" in
    verbose) base_cmd+=( -vv -s ) ;;
    print)   base_cmd+=( -vv -s ) ;;
    quiet)   base_cmd+=( -q ) ;;
    coverage) base_cmd+=( -vv -s --cov=hass_util --cov=gen_presence_sensors --cov-report=term-missing ) ;;
    *) base_cmd+=( -vv -s ) ;;
  esac
  if [ -n "$extra" ]; then
    # shellcheck disable=SC2206
    base_cmd+=( $extra )
  fi
  log INFO "Running: ${base_cmd[*]}"
  if [ "$TEST_MODE" -eq 1 ]; then
    log INFO "[TEST MODE] Skipping execution"
    return 0
  fi
  (cd "$TEST_DIR" || return 1; "${base_cmd[@]}")
  local ec=$?
  if [ $ec -eq 0 ]; then
    log INFO "Test(s) passed"
  else
    log ERROR "Test(s) failed with exit code $ec"
  fi
  return $ec
}

show_whiptail_menu() {
  local options=()
  options+=("ALL" "Run All Tests" "OFF")
  for f in "${TEST_FILES[@]}"; do
    options+=("FILE_${f}" "File: ${f}" "OFF")
  done
  options+=("COV" "Coverage (all)" "OFF")
  
  local choices
  choices=$(whiptail --title "HA Scripts Test Menu" --checklist "Select tests to run (SPACE to select, ENTER to confirm):" "$MENU_HEIGHT" "$MENU_WIDTH" "$MENU_LIST_HEIGHT" "${options[@]}" 3>&1 1>&2 2>&3)
  
  if [ $? -ne 0 ]; then
    log INFO "Test execution cancelled"
    exit 0
  fi
  
  # Remove quotes from choices
  choices=$(echo "$choices" | tr -d '"')
  
  # Check if nothing selected
  if [ -z "$choices" ]; then
    log INFO "No tests selected"
    return 0
  fi
  
  local failed=0
  for choice in $choices; do
    case "$choice" in
      ALL) run_pytest "$TEST_DIR" verbose || ((failed++)) ;; 
      COV) run_pytest "$TEST_DIR" coverage || ((failed++)) ;;
      FILE_*)
        local file="${choice#FILE_}"
        run_pytest "$file" verbose || ((failed++))
        ;;
    esac
  done
  
  echo ""
  if [ $failed -eq 0 ]; then
    log INFO "All selected tests passed"
  else
    log ERROR "$failed test(s) failed"
  fi
}

show_text_menu() {
  echo ""; echo "=============================="; echo " Home Assistant Test Menu"; echo "=============================="; echo "";
  echo "[1] Run All Tests"
  local idx=2
  for f in "${TEST_FILES[@]}"; do
    echo "[$idx] File: $f"; idx=$((idx+1))
  done
  echo "[C] Coverage (all)"
  echo "[Q] Quit"
  echo ""; read -rp "Select option: " choice
  case "$choice" in
    1) run_pytest "$TEST_DIR" verbose ;;
    [2-9])
      local sel=$((choice-2))
      if [ $sel -ge 0 ] && [ $sel -lt ${#TEST_FILES[@]} ]; then
        run_pytest "${TEST_FILES[$sel]}" verbose
      else
        log ERROR "Invalid selection"
      fi
      ;;
    [Cc]) run_pytest "$TEST_DIR" coverage ;;
    [Qq]) log INFO "Exiting"; exit 0 ;;
    *) log ERROR "Unknown option" ;;
  esac
}

main() {
  log INFO "Discovered test files: ${TEST_FILES[*]}"
  [ "$DEBUG_MODE" -eq 1 ] && log INFO "SCRIPT_DIR=$SCRIPT_DIR TEST_DIR=$TEST_DIR PROJECT_ROOT=$PROJECT_ROOT UTIL_LOGGING=$UTIL_LOGGING"
  case "$DIALOG_TOOL" in
    whiptail) show_whiptail_menu ;;
    dialog|yad) log INFO "Dialog tool ($DIALOG_TOOL) not fully implemented, falling back to whiptail/text"; [ "$DIALOG_TOOL" = dialog ] && show_whiptail_menu || show_text_menu ;;
    none) show_text_menu ;;
  esac
}

main "$@"
