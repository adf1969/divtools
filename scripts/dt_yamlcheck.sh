#!/bin/bash
# dt_yamlcheck.sh - Script to validate YAML files using yamllint
# v19: 2024-11-25: Fixed color for indicators in validation results and summary.

# Global Variables
SCRIPT_VERSION="v19"
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
RESET="\033[0m" # Resets color formatting
SHOW_ALL=0
SHOW_ERRORS=0
SHOW_WARNINGS=0
SHOW_FULL_PATHS=0
DEBUG=0

# Function to check dependencies
check_dependencies() {
  if ! command -v yamllint &> /dev/null; then
    echo "Error: yamllint is not installed. Please install it and try again."
    echo "install with: sudo apt install yamllint"
    exit 1
  fi
} # check_dependencies

# Function to process a YAML file
process_file() {
  local file="$1"
  local config_file="$BASE_DIR/.yamllint" # Path to potential .yamllint config
  local config_option=""

  # Use the .yamllint file if it exists
  if [[ -f "$config_file" ]]; then
    config_option="--config-file $config_file"
  fi

  local relative_path="${file#$BASE_DIR/}" # Make path relative to BASE_DIR
  local command=("yamllint" $config_option "$file") # Create command array
  local output

  # Debug output for the yamllint command
  if [[ $DEBUG -eq 1 ]]; then
    echo -e "${YELLOW}Executing: ${command[*]}${RESET}"
  fi

  # Execute yamllint and capture output
  output=$("${command[@]}" 2>&1)
  local exit_code=$?

  # Adjust path output based on -p flag
  local display_path="$relative_path"
  [[ $SHOW_FULL_PATHS -eq 1 ]] && display_path="$file"

  # Determine whether to show the yamllint output
  local has_error=0
  local has_warning=0
  echo "$output" | grep -q 'error' && has_error=1
  echo "$output" | grep -q 'warning' && has_warning=1

  # Show yamllint output header and content if applicable
  if [[ $SHOW_ALL -eq 1 || ($SHOW_ERRORS -eq 1 && $has_error -eq 1) || ($SHOW_WARNINGS -eq 1 && $has_warning -eq 1) ]]; then
    if [[ $has_error -eq 1 ]]; then
      echo -e "\n${RED}Output from yamllint for: $display_path${RESET}"
    elif [[ $has_warning -eq 1 ]]; then
      echo -e "\n${YELLOW}Output from yamllint for: $display_path${RESET}"
    fi
    echo "$output"
    echo
  fi

  # Handle file status
  if [[ $DEBUG -eq 1 ]]; then
    if [[ $exit_code -eq 0 ]]; then
      echo -e "[${GREEN}✔${RESET}] $display_path"
    elif [[ $has_error -eq 1 ]]; then
      echo -e "[${RED}✘${RESET}] $display_path"
    else
      echo -e "[${YELLOW}?${RESET}] $display_path"
    fi
  fi

  # Track failed files
  if [[ $has_error -eq 1 ]]; then
    FAILED_FILES+=("$file")
  fi
  if [[ $has_warning -eq 1 && $has_error -eq 0 ]]; then
    WARNED_FILES+=("$file")
  fi
} # process_file

# Function to parse includes from the YAML file
parse_includes() {
  local file="$1"
  included_files=()

  # Extract lines in the include section and process them
  while IFS= read -r line; do
    # Skip lines that are commented out or blank
    [[ "$line" =~ ^\s*# ]] && continue
    [[ -z "$line" ]] && continue

    # Match only YAML include file paths (ignoring `-` as part of the syntax)
    if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*(.+) ]]; then
      included_file="${BASH_REMATCH[1]}" # Extract the file path
      included_file=$(echo "$included_file" | sed -E 's/#.*//' | xargs) # Remove comments and trim
      included_file=$(eval echo "$included_file") # Expand variables

      # Resolve the file path relative to the main YAML file
      included_file="$BASE_DIR/$included_file"

      # Add the file to the list if it's not empty
      if [[ -n "$included_file" ]]; then
        included_files+=("$included_file")
      fi
    fi
  done < <(awk '/include:/ {flag=1; next} /^[^[:space:]]/ {flag=0} flag' "$file")
} # parse_includes

main() {
  # Initialize variables
  local args=()
  local main_file=""

  # Parse all arguments, flags can appear anywhere
  for arg in "$@"; do
    case "$arg" in
      -show-all) SHOW_ALL=1 ;;
      -show-errors) SHOW_ERRORS=1 ;;
      -show-warnings) SHOW_WARNINGS=1 ;;
      -p) SHOW_FULL_PATHS=1 ;;
      -debug) DEBUG=1 ;;
      *)
        # Assume non-flag arguments are file paths
        args+=("$arg")
        ;;
    esac
  done

  # Validate that at least one file argument is provided
  if [[ ${#args[@]} -eq 0 ]]; then
    echo "Usage: $0 [-show-all] [-show-errors] [-show-warnings] [-p] [-debug] <main_yaml_file>"
    exit 1
  fi

  main_file="${args[0]}" # First non-flag argument is the main YAML file

  # Check if the main YAML file exists
  if [[ ! -f "$main_file" ]]; then
    echo "Error: File $main_file not found."
    exit 1
  fi

  BASE_DIR=$(dirname "$main_file") # Base directory for relative paths
  check_dependencies

  # Arrays to store file statuses
  FAILED_FILES=()
  WARNED_FILES=()
  included_files=()

  # Process main YAML file
  process_file "$main_file"

  # Parse and process included files
  parse_includes "$main_file"
  for included_file in "${included_files[@]}"; do
    if [[ -f "$included_file" ]]; then
      process_file "$included_file"
    else
      if [[ $DEBUG -eq 1 ]]; then
        echo -e "[${RED}✘${RESET}] Include file not found: ${included_file#$BASE_DIR/}"
      fi
      FAILED_FILES+=("$included_file")
    fi
  done

  # Summary
  echo "Validation Results:"
  for file in "$main_file" "${included_files[@]}"; do
    local display_path="${file#$BASE_DIR/}"
    [[ $SHOW_FULL_PATHS -eq 1 ]] && display_path="$file"

    if grep -qF "$file" <(printf "%s\n" "${FAILED_FILES[@]}"); then
      echo -e "[${RED}✘${RESET}] ${RED}$display_path${RESET}"
    elif grep -qF "$file" <(printf "%s\n" "${WARNED_FILES[@]}"); then
      echo -e "[${YELLOW}?${RESET}] ${YELLOW}$display_path${RESET}"
    else
      echo -e "[${GREEN}✔${RESET}] $display_path"
    fi
  done

  if [[ ${#FAILED_FILES[@]} -eq 0 ]]; then
    echo -e "[${GREEN}✔${RESET}] ${GREEN}All files validated successfully.${RESET}"
  else
    echo -e "[${RED}✘${RESET}] ${RED}Some files failed validation.${RESET}"
    exit 1
  fi
} # main


# Script Entry Point
main "$@"
