#!/bin/bash
# dt_yamlcheck.sh - Script to validate YAML files and report environment variables and volumes
# Last Updated: 11/6/2025 2:30:00 PM CST
# v23: 2025-11-06: Added volume checking functionality with -show-vol/-sv flag

# Global Variables
SCRIPT_VERSION="v23"
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
CYAN="\033[0;36m"
WHITE="\033[0;37m"
RESET="\033[0m" # Resets color formatting
SHOW_ALL=0
SHOW_ERRORS=0  # Default to NOT showing yamllint errors (minimal output)
SHOW_WARNINGS=0
SHOW_FULL_PATHS=0
DEBUG_MODE=0
TEST_MODE=0
SHOW_ENV_TABLE=0  # When 0, only shows missing vars; when 1, shows all vars
SHOW_VOL_TABLE=0  # When 1, shows volume mount table
HIDE_COMMENTED=0  # When 1, hide commented-out variables
CHECK_PORTS_MODE=0  # 0=off, 1=all, 2=dupes-only
CHECK_PORTS_SORT="name"  # name|num
CHECK_PORTS_FILTER=""  # optional filter string
CHECK_PORTS_LOCAL_ONLY=0  # when 1, only show ports referenced in local YAML files
HIDE_YAML_PROC=0  # when 1, hide YAML processing output
HIDE_YAML_RESULTS=0  # when 1, hide YAML validation results output

# Column Width Settings for Environment Variable Table
# You can adjust these values to customize the table display
COL_WIDTH_YAML_FILE=35      # Width of YAML File column
COL_WIDTH_VARIABLE=40       # Width of Variable Name column
COL_WIDTH_VALUE=50          # Width of Value column (increased from 30)
COL_WIDTH_SOURCE=25         # Width of Source .env File column

# Column Width Settings for Volume Table
COL_WIDTH_VOL_HOST=35       # Width of HOST column (raw)
COL_WIDTH_VOL_GUEST=35      # Width of GUEST column (raw)
COL_WIDTH_VOL_HOST_ACT=50   # Width of HOST Actual column (expanded)
COL_WIDTH_VOL_GUEST_ACT=30  # Width of GUEST Actual column (expanded)
COL_WIDTH_VOL_DATA=25       # Width of HOST Data column (ownership/perms)

# Associative arrays to track environment variables
declare -A ENV_VAR_VALUES      # var_name -> current_value
declare -A ENV_VAR_SOURCES     # var_name -> source_file
declare -A ENV_VAR_YAML_FILES  # "var_name|yaml_file" -> 1 (tracks all occurrences)
declare -A ENV_VAR_LINE_NUMS   # "var_name|yaml_file" -> line_number (first occurrence)
declare -A ENV_VAR_COMMENTED   # "var_name|yaml_file" -> 1 if commented, 0 if not
declare -a ALL_YAML_VARS       # Array to store all "var_name|yaml_file" combinations in order
declare -a PORT_ROWS           # Array to store port rows for reporting

# Associative arrays to track volumes
declare -A VOL_HOST_RAW        # "yaml_file|idx" -> raw host path
declare -A VOL_GUEST_RAW       # "yaml_file|idx" -> raw guest path
declare -A VOL_HOST_ACTUAL     # "yaml_file|idx" -> expanded host path
declare -A VOL_GUEST_ACTUAL    # "yaml_file|idx" -> expanded guest path
declare -A VOL_LINE_NUMS       # "yaml_file|idx" -> line number
declare -a ALL_VOLUMES         # Array to store all "yaml_file|idx" combinations in order

# Logging function with color-coded output
log() {
    local level="$1"
    local message="$2"
    local color

    # Default colors for logging
    case "$level" in
        DEBUG) color="\e[37m" ;; # White
        INFO)  color="\e[36m" ;; # Cyan
        WARN)  color="\e[33m" ;; # Yellow
        ERROR) color="\e[31m" ;; # Red
        *)     color="\e[37m" ;; # Default to white
    esac

    # Don't show DEBUG messages unless DEBUG_MODE is on
    if [[ "$level" == "DEBUG" && "$DEBUG_MODE" -ne 1 ]]; then
        return
    fi

    echo -e "${color}[${level}] ${message}\e[m"
} # log

# Function to display script usage
# Last Updated: 1/19/2026 10:00:00 AM CST
usage() {
    log "INFO" "Usage: $0 [options] [main_yaml_file]"
    log "INFO" ""
    log "INFO" "Options:"
    log "INFO" "  -show-all, --show-all, -sa          : Show all yamllint output"
    log "INFO" "  -show-errors, --show-errors, -err   : Show yamllint error output (line length, syntax errors, etc.)"
    log "INFO" "  -show-warnings, --show-warnings, -warn : Show yamllint warning output"
    log "INFO" "  -show-env, --show-env, -se          : Display full environment variable table (all vars, not just missing)"
    log "INFO" "  -show-vol, --show-vol, -sv          : Display volume mount table with host/guest paths and ownership"
    log "INFO" "  -hide-commented, --hide-commented, -hc : Hide commented-out environment variables from output"
    log "INFO" "  -check-ports, -list-ports           : List all PORT-related env vars (sorted by name)"
    log "INFO" "  -check-ports-num                    : List PORT-related env vars sorted by port number"
    log "INFO" "  -check-ports-dupes                  : Only list duplicate port numbers"
    log "INFO" "  -local                              : With -check-ports* only show ports referenced in local YAML"
    log "INFO" "  -hide-yaml-proc, -hide-yp           : Hide YAML processing output"
    log "INFO" "  -hide-yaml-vr, -hide-yv             : Hide YAML validation results output"
    log "INFO" "  -p, --show-full-paths               : Show full file paths instead of relative"
    log "INFO" "  -debug, --debug                     : Enable debug mode"
    log "INFO" "  -test, --test                       : Run in test mode (no permanent changes)"
    log "INFO" "  -usage, -help                       : Show this help text"
    log "INFO" ""
    log "INFO" "Notes:"
    log "INFO" "  -check-ports* accepts an optional filter string after the flag (case-insensitive)."
    log "INFO" "    Example: $0 -check-ports web"
    log "INFO" ""
} # usage

# Source .bash_profile to get load_env_files() and related functions
# Last Updated: 11/5/2025 3:15:00 PM CST
source_bash_profile() {
    local bash_profile="$DIVTOOLS/dotfiles/.bash_profile"

    if [ -f "$bash_profile" ]; then
        source "$bash_profile"
        log "DEBUG" "Sourced .bash_profile for required functions."
    else
        log "ERROR" ".bash_profile not found at $bash_profile."
        exit 1
    fi
} # source_bash_profile

# Function to track environment variables from loaded .env files
track_env_vars_from_file() {
    local env_file="$1"
    local short_name=$(basename "$env_file")
    
    log "DEBUG" "Tracking env vars from: $env_file"
    
    if [ ! -f "$env_file" ]; then
        log "WARN" "Env file not found: $env_file"
        return
    fi
    
    # Read the env file and track exported variables
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$line" ]] && continue
        
        # Match export VAR_NAME=value patterns
        if [[ "$line" =~ ^[[:space:]]*export[[:space:]]+([A-Za-z_][A-Za-z0-9_]*)= ]]; then
            local var_name="${BASH_REMATCH[1]}"
            
            # Get the current value of this variable
            local var_value="${!var_name}"
            
            # Track this variable
            ENV_VAR_SOURCES["$var_name"]="$short_name"
            ENV_VAR_VALUES["$var_name"]="$var_value"
            
            log "DEBUG" "Tracked: $var_name=${var_value} from $short_name"
        fi
    done < "$env_file"
} # track_env_vars_from_file

# Function to track all loaded environment variables
track_loaded_env_vars() {
    # Last Updated: 1/19/2026 10:00:00 AM CST
    log "INFO" "Tracking environment variables from loaded .env files..."
    
    local docker_dir="${DOCKERDIR:-/opt/divtools/docker}"
    local site_name="${SITE_NAME:-default}"
    local shared_dir="${docker_dir}/sites/s00-shared"
    local site_dir="${docker_dir}/sites/${site_name}"
    local host_dir="${site_dir}/${HOSTNAME}"
    
    if [[ "$CFG_MODE" == "1" ]]; then
        # V1 Mode
        log "DEBUG" "Tracking V1 .env files"
        
        if [ -f "${docker_dir}/.env" ]; then
            track_env_vars_from_file "${docker_dir}/.env"
        fi
        
        local v1_host_env
        v1_host_env=$(find_file_case_insensitive "${docker_dir}/secrets/env" ".env." "$HOSTNAME" "")
        if [ -n "$v1_host_env" ]; then
            track_env_vars_from_file "$v1_host_env"
        fi
        
    elif [[ "$CFG_MODE" == "2" ]]; then
        # V2 Mode
        log "DEBUG" "Tracking V2 .env files"
        
        local shared_env_file site_env_file host_env_file
        
        shared_env_file=$(find_file_case_insensitive "${shared_dir}" ".env." "s00-shared" "")
        if [ -n "$shared_env_file" ]; then
            track_env_vars_from_file "$shared_env_file"
        fi
        
        site_env_file=$(find_file_case_insensitive "${site_dir}" ".env." "$site_name" "")
        if [ -n "$site_env_file" ]; then
            track_env_vars_from_file "$site_env_file"
        fi
        
        host_env_file=$(find_file_case_insensitive "${host_dir}" ".env." "$HOSTNAME" "")
        if [ -n "$host_env_file" ]; then
            track_env_vars_from_file "$host_env_file"
        fi
    fi
    
    # Track common system variables that may not be in .env files
    # These are set by load_env_files() or the system or init_env_vars()
    for var in HOSTNAME DIVTOOLS DOCKERDIR DOCKERDATADIR SITE_NAME CFG_MODE DOCKER_SHAREDDIR DOCKER_SITEDIR DOCKER_HOSTDIR; do
        if [ -n "${!var}" ]; then
            if [ -z "${ENV_VAR_SOURCES[$var]}" ]; then
                ENV_VAR_SOURCES["$var"]="<system/profile>"
                ENV_VAR_VALUES["$var"]="${!var}"
                log "DEBUG" "Tracked system var: $var=${!var}"
            fi
        fi
    done
    
    # Capture any remaining environment variables not tracked from .env files
    while IFS='=' read -r env_name env_value; do
        if [[ -n "$env_name" && -z "${ENV_VAR_SOURCES[$env_name]}" ]]; then
            ENV_VAR_SOURCES["$env_name"]="<system/profile>"
            ENV_VAR_VALUES["$env_name"]="$env_value"
        fi
    done < <(env)

    log "INFO" "Tracked ${#ENV_VAR_SOURCES[@]} environment variables from .env files and system."
} # track_loaded_env_vars

# Function to determine if a port is active (listening)
# Last Updated: 1/19/2026 10:00:00 AM CST
is_port_active() {
    local port="$1"

    if [[ -z "$port" || ! "$port" =~ ^[0-9]+$ ]]; then
        echo "NO"
        return 0
    fi

    if command -v ss >/dev/null 2>&1; then
        if ss -ltnH 2>/dev/null | awk '{print $4}' | awk -F: '{print $NF}' | grep -qx "$port"; then
            echo "YES"
            return 0
        fi
    elif command -v netstat >/dev/null 2>&1; then
        if netstat -ltn 2>/dev/null | awk 'NR>2 {print $4}' | awk -F: '{print $NF}' | grep -qx "$port"; then
            echo "YES"
            return 0
        fi
    fi

    echo "NO"
    return 0
} # is_port_active

# Function to build a list of PORT-related env vars
# Last Updated: 1/19/2026 10:00:00 AM CST
collect_port_vars() {
    PORT_ROWS=()

    local filter_lower=""
    if [[ -n "$CHECK_PORTS_FILTER" ]]; then
        filter_lower=$(echo "$CHECK_PORTS_FILTER" | tr '[:upper:]' '[:lower:]')
    fi

    declare -A YAML_VAR_SET=()
    if [[ $CHECK_PORTS_LOCAL_ONLY -eq 1 ]]; then
        for key in "${ALL_YAML_VARS[@]}"; do
            local key_without_suffix="${key%|uncommented}"
            key_without_suffix="${key_without_suffix%|commented}"
            local key_var="${key_without_suffix%%|*}"
            YAML_VAR_SET["$key_var"]=1
        done
    fi

    for var in "${!ENV_VAR_VALUES[@]}"; do
        if [[ "$var" != *PORT* ]]; then
            continue
        fi

        if [[ $CHECK_PORTS_LOCAL_ONLY -eq 1 && -z "${YAML_VAR_SET[$var]}" ]]; then
            continue
        fi

        local value="${ENV_VAR_VALUES[$var]}"
        local source="${ENV_VAR_SOURCES[$var]}"

        if [[ -n "$filter_lower" ]]; then
            local haystack="${var} ${value}"
            local haystack_lower
            haystack_lower=$(echo "$haystack" | tr '[:upper:]' '[:lower:]')
            if [[ "$haystack_lower" != *"$filter_lower"* ]]; then
                continue
            fi
        fi

        local port_num=""
        if [[ "$value" =~ ^[0-9]+$ ]]; then
            port_num="$value"
        fi

        local active
        active=$(is_port_active "$port_num")

        PORT_ROWS+=("${var}|${value}|${source}|${active}|${port_num}")
    done
} # collect_port_vars

# Function to display PORT-related env vars in a table
# Last Updated: 1/19/2026 10:00:00 AM CST
display_ports_table() {
    local -a filtered_rows=()
    local -a duplicates_rows=()

    collect_port_vars

    if [[ ${#PORT_ROWS[@]} -eq 0 ]]; then
        log "WARN" "No PORT-related environment variables found."
        return
    fi

    declare -A PORT_COUNTS=()
    for row in "${PORT_ROWS[@]}"; do
        local port_num="${row##*|}"
        if [[ -n "$port_num" ]]; then
            PORT_COUNTS["$port_num"]=$((PORT_COUNTS["$port_num"] + 1))
        fi
    done

    for row in "${PORT_ROWS[@]}"; do
        local port_num="${row##*|}"
        local count=0
        if [[ -n "$port_num" ]]; then
            count="${PORT_COUNTS[$port_num]}"
        fi

        if [[ $CHECK_PORTS_MODE -eq 2 ]]; then
            if [[ -n "$port_num" && $count -gt 1 ]]; then
                duplicates_rows+=("$row")
            fi
        else
            filtered_rows+=("$row")
        fi
    done

    if [[ $CHECK_PORTS_MODE -eq 2 ]]; then
        if [[ ${#duplicates_rows[@]} -eq 0 ]]; then
            log "INFO" "No duplicate PORT numbers found."
            return
        fi
        filtered_rows=("${duplicates_rows[@]}")
    fi

    if [[ "$CHECK_PORTS_SORT" == "num" ]]; then
        IFS=$'\n' filtered_rows=($(printf '%s\n' "${filtered_rows[@]}" | sort -t'|' -k5,5n -k1,1))
        unset IFS
    else
        IFS=$'\n' filtered_rows=($(printf '%s\n' "${filtered_rows[@]}" | sort -t'|' -k1,1))
        unset IFS
    fi

    log "INFO" "\n=========================================="
    log "INFO" "Port Environment Variable Report"
    log "INFO" "=========================================="

    local sep_yaml=$(printf '%*s' "$COL_WIDTH_YAML_FILE" | tr ' ' '-')
    local sep_variable=$(printf '%*s' "$COL_WIDTH_VARIABLE" | tr ' ' '-')
    local sep_value=$(printf '%*s' "$COL_WIDTH_VALUE" | tr ' ' '-')
    local sep_source=$(printf '%*s' "$COL_WIDTH_SOURCE" | tr ' ' '-')
    local sep_active=$(printf '%*s' 8 | tr ' ' '-')

    printf "\n${CYAN}%-${COL_WIDTH_YAML_FILE}s %-${COL_WIDTH_VARIABLE}s %-${COL_WIDTH_VALUE}s %-${COL_WIDTH_SOURCE}s %-8s${RESET}\n" "YAML File" "Variable Name" "Value" "Source .env File" "Active"
    printf "${CYAN}%-${COL_WIDTH_YAML_FILE}s %-${COL_WIDTH_VARIABLE}s %-${COL_WIDTH_VALUE}s %-${COL_WIDTH_SOURCE}s %-8s${RESET}\n" "$sep_yaml" "$sep_variable" "$sep_value" "$sep_source" "$sep_active"

    declare -A FIRST_YAML_REF=()
    declare -A FIRST_YAML_LINE=()
    for key in "${ALL_YAML_VARS[@]}"; do
        local key_without_suffix="${key%|uncommented}"
        key_without_suffix="${key_without_suffix%|commented}"
        local key_var="${key_without_suffix%%|*}"
        local key_yaml="${key_without_suffix#*|}"
        if [[ -z "${FIRST_YAML_REF[$key_var]}" ]]; then
            FIRST_YAML_REF["$key_var"]="$key_yaml"
            FIRST_YAML_LINE["$key_var"]="${ENV_VAR_LINE_NUMS[$key]}"
        fi
    done

    for row in "${filtered_rows[@]}"; do
        local var_name="${row%%|*}"
        local rest="${row#*|}"
        local value="${rest%%|*}"
        rest="${rest#*|}"
        local source="${rest%%|*}"
        rest="${rest#*|}"
        local active="${rest%%|*}"
        local port_num="${row##*|}"

        local yaml_file="${FIRST_YAML_REF[$var_name]:-<system/profile>}"
        local line_num="${FIRST_YAML_LINE[$var_name]}"
        if [[ -n "$line_num" ]]; then
            local base_filename="${yaml_file##*/}"
            yaml_file="${base_filename}:${line_num}"
        fi

        local display_value="$value"
        local max_value_len=$((COL_WIDTH_VALUE - 2))
        if [ ${#display_value} -gt $max_value_len ]; then
            display_value="${display_value:0:$((max_value_len - 3))}..."
        fi

        local is_dupe=0
        if [[ -n "$port_num" && "${PORT_COUNTS[$port_num]}" -gt 1 ]]; then
            is_dupe=1
        fi

        if [[ $is_dupe -eq 1 ]]; then
            printf "${RED}  %-$((COL_WIDTH_YAML_FILE - 2))s %-${COL_WIDTH_VARIABLE}s %-${COL_WIDTH_VALUE}s %-${COL_WIDTH_SOURCE}s %-8s${RESET}\n" "$yaml_file" "$var_name" "$display_value" "${source:-N/A}" "$active"
        else
            printf "  %-$((COL_WIDTH_YAML_FILE - 2))s %-${COL_WIDTH_VARIABLE}s %-${COL_WIDTH_VALUE}s %-${COL_WIDTH_SOURCE}s %-8s\n" "$yaml_file" "$var_name" "$display_value" "${source:-N/A}" "$active"
        fi
    done

    printf "\n"
    log "INFO" "=========================================="
    log "INFO" "Total PORT variables found: ${#filtered_rows[@]}"
    local dup_count=0
    for port in "${!PORT_COUNTS[@]}"; do
        if [[ "${PORT_COUNTS[$port]}" -gt 1 ]]; then
            ((dup_count++))
        fi
    done
    if [[ $dup_count -gt 0 ]]; then
        log "WARN" "Duplicate port numbers found: $dup_count"
    else
        log "INFO" "Duplicate port numbers found: 0"
    fi
    log "INFO" "=========================================="
} # display_ports_table

# Function to extract environment variables from YAML file
extract_env_vars_from_yaml() {
    local yaml_file="$1"
    
    # Always calculate path relative to sites folder for consistency
    local relative_path
    
    # Check if it's in s00-shared (shared files)
    if [[ "$yaml_file" == *"/sites/s00-shared/"* ]]; then
        # Extract path after sites/ and prefix with ./
        relative_path="./$(echo "$yaml_file" | sed 's|.*/sites/||')"
    elif [[ "$yaml_file" == *"/sites/${SITE_NAME}/"* ]]; then
        # Extract path after sites/ and prefix with ./
        relative_path="./$(echo "$yaml_file" | sed 's|.*/sites/||')"
    else
        # Fallback to just the filename if not in sites structure
        relative_path="$(basename "$yaml_file")"
    fi
    
    log "DEBUG" "Extracting env vars from: $relative_path (full: $yaml_file)"
    
    if [ ! -f "$yaml_file" ]; then
        log "WARN" "YAML file not found: $yaml_file"
        return
    fi
    
    # Extract environment variable references with line numbers
    # Use grep -n to get line numbers, then extract var names
    while IFS=: read -r line_num line_content; do
        # Check if this line is commented out (starts with # after optional whitespace)
        local is_commented=0
        if [[ "$line_content" =~ ^[[:space:]]*# ]]; then
            is_commented=1
        fi
        
        # Extract all variables from this line
        local vars_in_line=$(echo "$line_content" | grep -oE '\$\{?[A-Za-z_][A-Za-z0-9_]*\}?' | sed 's/[${}]//g' | sort -u)
        
        for var in $vars_in_line; do
            # Create keys for both commented and non-commented versions
            local key="${var}|${relative_path}"
            
            # Check if we've already tracked this var in this file
            if [[ -z "${ENV_VAR_YAML_FILES[$key]}" ]]; then
                # First time seeing this var in this file
                ENV_VAR_YAML_FILES["$key"]=1
                ENV_VAR_LINE_NUMS["$key"]=$line_num
                ENV_VAR_COMMENTED["$key"]=$is_commented
                ALL_YAML_VARS+=("$key")
                log "DEBUG" "Tracked: $var at line $line_num in $relative_path (commented: $is_commented)"
            elif [[ $is_commented -eq 0 && "${ENV_VAR_COMMENTED[$key]}" -eq 1 ]]; then
                # We've seen this var before as commented, but now it's uncommented
                # Add a new entry for the uncommented version with a different key
                local uncommented_key="${var}|${relative_path}|uncommented"
                if [[ -z "${ENV_VAR_YAML_FILES[$uncommented_key]}" ]]; then
                    ENV_VAR_YAML_FILES["$uncommented_key"]=1
                    ENV_VAR_LINE_NUMS["$uncommented_key"]=$line_num
                    ENV_VAR_COMMENTED["$uncommented_key"]=0
                    ALL_YAML_VARS+=("$uncommented_key")
                    log "DEBUG" "Tracked uncommented version: $var at line $line_num in $relative_path"
                fi
            elif [[ $is_commented -eq 1 && "${ENV_VAR_COMMENTED[$key]}" -eq 0 ]]; then
                # We've seen this var before as uncommented, but now found a commented version
                # Add a new entry for the commented version with a different key
                local commented_key="${var}|${relative_path}|commented"
                if [[ -z "${ENV_VAR_YAML_FILES[$commented_key]}" ]]; then
                    ENV_VAR_YAML_FILES["$commented_key"]=1
                    ENV_VAR_LINE_NUMS["$commented_key"]=$line_num
                    ENV_VAR_COMMENTED["$commented_key"]=1
                    ALL_YAML_VARS+=("$commented_key")
                    log "DEBUG" "Tracked commented version: $var at line $line_num in $relative_path"
                fi
            fi
        done
    done < <(grep -n '\$' "$yaml_file")
} # extract_env_vars_from_yaml

# Function to expand environment variables in a string
# Expands variables like $VAR or ${VAR}
expand_env_vars() {
    local input="$1"
    local output="$input"
    
    # Use eval to expand variables, but be careful with special characters
    # First, escape any backticks and other dangerous characters
    output=$(echo "$output" | sed 's/`/\\`/g')
    
    # Now use eval to expand the variables
    output=$(eval echo "$output" 2>/dev/null || echo "$input")
    
    echo "$output"
} # expand_env_vars

# Function to extract volume mounts from YAML file
extract_volumes_from_yaml() {
    local yaml_file="$1"
    
    # Always calculate path relative to sites folder for consistency
    local relative_path
    
    # Check if it's in s00-shared (shared files)
    if [[ "$yaml_file" == *"/sites/s00-shared/"* ]]; then
        relative_path="./$(echo "$yaml_file" | sed 's|.*/sites/||')"
    elif [[ "$yaml_file" == *"/sites/${SITE_NAME}/"* ]]; then
        relative_path="./$(echo "$yaml_file" | sed 's|.*/sites/||')"
    else
        relative_path="$(basename "$yaml_file")"
    fi
    
    log "DEBUG" "Extracting volumes from: $relative_path (full: $yaml_file)"
    
    if [ ! -f "$yaml_file" ]; then
        log "WARN" "YAML file not found: $yaml_file"
        return
    fi
    
    local in_volumes_section=0
    local current_service=""
    local volume_idx=0
    local base_indent=0
    
    # Read the file line by line with line numbers
    # Use a different approach to avoid colon splitting issues
    local line_num=0
    while IFS= read -r line_content; do
        ((line_num++))
        
        # Skip empty lines
        [[ -z "$line_content" ]] && continue
        
        # Skip comment-only lines
        if [[ "$line_content" =~ ^[[:space:]]*#.*$ ]]; then
            continue
        fi
        
        # Detect service name (under services:)
        if [[ "$line_content" =~ ^[[:space:]]+([a-zA-Z0-9_-]+):[[:space:]]*$ ]]; then
            current_service="${BASH_REMATCH[1]}"
            in_volumes_section=0
            log "DEBUG" "Found service: $current_service at line $line_num"
        fi
        
        # Detect volumes: section
        if [[ "$line_content" =~ ^([[:space:]]+)volumes:[[:space:]]*$ ]]; then
            in_volumes_section=1
            # Calculate base indentation level
            base_indent=${#BASH_REMATCH[1]}
            log "DEBUG" "Entering volumes section at line $line_num (indent: $base_indent)"
            continue
        fi
        
        # Exit volumes section if we hit another key at the same or lower indentation
        if [[ $in_volumes_section -eq 1 ]]; then
            # Check if line is a key (ends with :) at same or less indentation than volumes:
            if [[ "$line_content" =~ ^([[:space:]]+)[a-zA-Z_-]+:[[:space:]]*$ ]]; then
                local current_indent=${#BASH_REMATCH[1]}
                if [[ $current_indent -le $base_indent ]]; then
                    in_volumes_section=0
                    log "DEBUG" "Exiting volumes section at line $line_num"
                fi
            fi
        fi
        
        # Extract volume mounts (lines starting with - in volumes section)
        if [[ $in_volumes_section -eq 1 ]]; then
            # Match volume mount format: - host:guest or - host:guest:ro etc.
            # More flexible regex to handle various formats
            if [[ "$line_content" =~ ^[[:space:]]*-[[:space:]]+(.+)$ ]]; then
                local volume_def="${BASH_REMATCH[1]}"
                
                # Remove any comments from the volume definition
                volume_def=$(echo "$volume_def" | sed 's/#.*//')
                
                # Split by : to get host and guest parts
                # Handle cases like: /path/to/host:/path/to/guest or /path/to/host:/path/to/guest:ro
                if [[ "$volume_def" =~ ^([^:]+):([^:]+)(:[a-z,]+)?[[:space:]]*$ ]]; then
                    local host_raw="${BASH_REMATCH[1]}"
                    local guest_raw="${BASH_REMATCH[2]}"
                    
                    # Trim whitespace
                    host_raw=$(echo "$host_raw" | xargs)
                    guest_raw=$(echo "$guest_raw" | xargs)
                    
                    # Create a unique key for this volume
                    local key="${relative_path}|${volume_idx}"
                    
                    # Store raw values
                    VOL_HOST_RAW["$key"]="$host_raw"
                    VOL_GUEST_RAW["$key"]="$guest_raw"
                    VOL_LINE_NUMS["$key"]=$line_num
                    
                    # Expand environment variables to get actual paths
                    local host_actual=$(expand_env_vars "$host_raw")
                    local guest_actual=$(expand_env_vars "$guest_raw")
                    
                    VOL_HOST_ACTUAL["$key"]="$host_actual"
                    VOL_GUEST_ACTUAL["$key"]="$guest_actual"
                    
                    # Add to the ordered list
                    ALL_VOLUMES+=("$key")
                    
                    log "DEBUG" "Tracked volume: $host_raw -> $guest_raw (expanded: $host_actual -> $guest_actual) at line $line_num"
                    
                    ((volume_idx++))
                fi
            fi
        fi
    done < "$yaml_file"
    
    log "DEBUG" "Found $volume_idx volume mount(s) in $relative_path"
} # extract_volumes_from_yaml

# Function to get file ownership and permissions
get_host_data() {
    local path="$1"
    
    if [ ! -e "$path" ]; then
        echo "NOT FOUND"
        return 1
    fi
    
    # Get ownership (user:group)
    local owner=$(stat -c "%U:%G" "$path" 2>/dev/null)
    if [ -z "$owner" ]; then
        # If stat fails, try ls -ld
        owner=$(ls -ld "$path" 2>/dev/null | awk '{print $3":"$4}')
    fi
    
    # Get permissions in octal format
    local perms=$(stat -c "%a" "$path" 2>/dev/null)
    if [ -z "$perms" ]; then
        echo "ERROR"
        return 1
    fi
    
    echo "$owner, $perms"
    return 0
} # get_host_data

# Function to display volume table
display_volume_table() {
    log "INFO" "\n=========================================="
    log "INFO" "Volume Mount Report"
    log "INFO" "=========================================="
    
    if [ ${#ALL_VOLUMES[@]} -eq 0 ]; then
        log "WARN" "No volume mounts found in YAML files."
        return
    fi
    
    log "INFO" "Found ${#ALL_VOLUMES[@]} volume mount(s)"
    
    # Build separator lines dynamically based on column widths
    local sep_host=$(printf '%*s' "$COL_WIDTH_VOL_HOST" | tr ' ' '-')
    local sep_guest=$(printf '%*s' "$COL_WIDTH_VOL_GUEST" | tr ' ' '-')
    local sep_host_act=$(printf '%*s' "$COL_WIDTH_VOL_HOST_ACT" | tr ' ' '-')
    local sep_guest_act=$(printf '%*s' "$COL_WIDTH_VOL_GUEST_ACT" | tr ' ' '-')
    local sep_data=$(printf '%*s' "$COL_WIDTH_VOL_DATA" | tr ' ' '-')
    
    # Print header
    printf "\n${CYAN}%-${COL_WIDTH_VOL_HOST}s %-${COL_WIDTH_VOL_GUEST}s %-${COL_WIDTH_VOL_HOST_ACT}s %-${COL_WIDTH_VOL_GUEST_ACT}s %-${COL_WIDTH_VOL_DATA}s${RESET}\n" "HOST" "GUEST" "HOST Actual" "GUEST Actual" "HOST Data"
    printf "${CYAN}%-${COL_WIDTH_VOL_HOST}s %-${COL_WIDTH_VOL_GUEST}s %-${COL_WIDTH_VOL_HOST_ACT}s %-${COL_WIDTH_VOL_GUEST_ACT}s %-${COL_WIDTH_VOL_DATA}s${RESET}\n" "$sep_host" "$sep_guest" "$sep_host_act" "$sep_guest_act" "$sep_data"
    
    local current_yaml=""
    local missing_count=0
    
    # Process all volumes in the order they were found
    for key in "${ALL_VOLUMES[@]}"; do
        # Split the key into yaml_file and idx
        local yaml_file="${key%|*}"
        
        local host_raw="${VOL_HOST_RAW[$key]}"
        local guest_raw="${VOL_GUEST_RAW[$key]}"
        local host_actual="${VOL_HOST_ACTUAL[$key]}"
        local guest_actual="${VOL_GUEST_ACTUAL[$key]}"
        local line_num="${VOL_LINE_NUMS[$key]}"
        
        # Get the base filename for display
        local base_filename="${yaml_file##*/}"
        local display_filename="${base_filename}:${line_num}"
        
        # Check if we've moved to a new YAML file
        if [[ "$yaml_file" != "$current_yaml" ]]; then
            current_yaml="$yaml_file"
            # Print the full path header in GREEN
            printf "\n${GREEN}%-${COL_WIDTH_VOL_HOST}s${RESET}\n" "$yaml_file"
        fi
        
        # Truncate long values if needed
        local disp_host_raw="$host_raw"
        local disp_guest_raw="$guest_raw"
        local disp_host_act="$host_actual"
        local disp_guest_act="$guest_actual"
        
        if [ ${#disp_host_raw} -gt $((COL_WIDTH_VOL_HOST - 2)) ]; then
            disp_host_raw="${disp_host_raw:0:$((COL_WIDTH_VOL_HOST - 5))}..."
        fi
        if [ ${#disp_guest_raw} -gt $((COL_WIDTH_VOL_GUEST - 2)) ]; then
            disp_guest_raw="${disp_guest_raw:0:$((COL_WIDTH_VOL_GUEST - 5))}..."
        fi
        if [ ${#disp_host_act} -gt $((COL_WIDTH_VOL_HOST_ACT - 2)) ]; then
            disp_host_act="${disp_host_act:0:$((COL_WIDTH_VOL_HOST_ACT - 5))}..."
        fi
        if [ ${#disp_guest_act} -gt $((COL_WIDTH_VOL_GUEST_ACT - 2)) ]; then
            disp_guest_act="${disp_guest_act:0:$((COL_WIDTH_VOL_GUEST_ACT - 5))}..."
        fi
        
        # Get host data (ownership and permissions)
        local host_data=$(get_host_data "$host_actual")
        local host_exists=$?
        
        if [ $host_exists -ne 0 ]; then
            # Host path doesn't exist - display in RED
            # Only indent the first column (under the YAML file header)
            printf "${RED}  %-$((COL_WIDTH_VOL_HOST - 2))s %-${COL_WIDTH_VOL_GUEST}s %-${COL_WIDTH_VOL_HOST_ACT}s %-${COL_WIDTH_VOL_GUEST_ACT}s %-${COL_WIDTH_VOL_DATA}s${RESET}\n" "$disp_host_raw" "$disp_guest_raw" "$disp_host_act" "$disp_guest_act" "$host_data"
            ((missing_count++))
        else
            # Host path exists - display normally
            # Only indent the first column (under the YAML file header)
            printf "  %-$((COL_WIDTH_VOL_HOST - 2))s %-${COL_WIDTH_VOL_GUEST}s %-${COL_WIDTH_VOL_HOST_ACT}s %-${COL_WIDTH_VOL_GUEST_ACT}s %-${COL_WIDTH_VOL_DATA}s\n" "$disp_host_raw" "$disp_guest_raw" "$disp_host_act" "$disp_guest_act" "$host_data"
        fi
    done
    
    # Summary
    printf "\n"
    log "INFO" "=========================================="
    log "INFO" "Total volume mounts found: ${#ALL_VOLUMES[@]}"
    if [ $missing_count -gt 0 ]; then
        log "ERROR" "Missing host paths: $missing_count"
    else
        log "INFO" "All host paths exist"
    fi
    log "INFO" "=========================================="
} # display_volume_table

# Function to display environment variable table
display_env_table() {
    log "INFO" "\n=========================================="
    log "INFO" "Environment Variable Report"
    log "INFO" "=========================================="
    
    if [ ${#ALL_YAML_VARS[@]} -eq 0 ]; then
        log "WARN" "No environment variables found in YAML files."
        return
    fi
    
    local missing_count=0
    local current_yaml=""
    local show_header=0
    
    # First pass: count missing vars
    for key in "${ALL_YAML_VARS[@]}"; do
        local var="${key%%|*}"
        local value="${ENV_VAR_VALUES[$var]}"
        local source="${ENV_VAR_SOURCES[$var]}"
        
        if [ -z "$value" ] && [ -z "$source" ]; then
            ((missing_count++))
        fi
    done
    
    # If no missing vars and not showing all, just report success
    if [[ $missing_count -eq 0 && $SHOW_ENV_TABLE -eq 0 ]]; then
        log "INFO" "All environment variables are set (${#ALL_YAML_VARS[@]} total checked)"
        return
    fi
    
    # If showing only missing vars (default), print a note
    if [[ $SHOW_ENV_TABLE -eq 0 && $missing_count -gt 0 ]]; then
        log "WARN" "Showing ONLY missing variables (use -show-env to see all)"
    fi
    
    # Print header only when we have something to show
    # Build separator lines dynamically based on column widths
    local sep_yaml=$(printf '%*s' "$COL_WIDTH_YAML_FILE" | tr ' ' '-')
    local sep_variable=$(printf '%*s' "$COL_WIDTH_VARIABLE" | tr ' ' '-')
    local sep_value=$(printf '%*s' "$COL_WIDTH_VALUE" | tr ' ' '-')
    local sep_source=$(printf '%*s' "$COL_WIDTH_SOURCE" | tr ' ' '-')
    
    printf "\n${CYAN}%-${COL_WIDTH_YAML_FILE}s %-${COL_WIDTH_VARIABLE}s %-${COL_WIDTH_VALUE}s %-${COL_WIDTH_SOURCE}s${RESET}\n" "YAML File" "Variable Name" "Value" "Source .env File"
    printf "${CYAN}%-${COL_WIDTH_YAML_FILE}s %-${COL_WIDTH_VARIABLE}s %-${COL_WIDTH_VALUE}s %-${COL_WIDTH_SOURCE}s${RESET}\n" "$sep_yaml" "$sep_variable" "$sep_value" "$sep_source"
    
    current_yaml=""
    
    # Process all var|yaml combinations in the order they were found
    for key in "${ALL_YAML_VARS[@]}"; do
        # Handle keys with |uncommented or |commented suffix
        local original_key="$key"
        local key_without_suffix="${key%|uncommented}"
        key_without_suffix="${key_without_suffix%|commented}"
        
        # Split the key into var_name and yaml_file
        local var="${key_without_suffix%%|*}"
        local yaml_file="${key_without_suffix#*|}"
        
        # Check if this variable is commented
        local is_commented="${ENV_VAR_COMMENTED[$original_key]}"
        
        # Skip commented vars if HIDE_COMMENTED is set
        if [[ $HIDE_COMMENTED -eq 1 && $is_commented -eq 1 ]]; then
            log "DEBUG" "Skipping commented var: $var at line ${ENV_VAR_LINE_NUMS[$original_key]}"
            continue
        fi
        
        # Get the base filename and line number for display
        local base_filename="${yaml_file##*/}"
        local line_num="${ENV_VAR_LINE_NUMS[$original_key]}"
        local display_filename="${base_filename}:${line_num}"
        
        local value="${ENV_VAR_VALUES[$var]}"
        local source="${ENV_VAR_SOURCES[$var]}"
        
        # Check if variable is set
        local is_missing=0
        if [ -z "$value" ] && [ -z "$source" ]; then
            is_missing=1
        fi
        
        # Skip non-missing vars if not showing all
        # Only show: missing vars (always) OR all vars when SHOW_ENV_TABLE=1
        if [[ $SHOW_ENV_TABLE -eq 0 && $is_missing -eq 0 ]]; then
            continue
        fi
        
        # Check if we've moved to a new YAML file
        if [[ "$yaml_file" != "$current_yaml" ]]; then
            current_yaml="$yaml_file"
            # Print the full path header in GREEN
            printf "${GREEN}%-${COL_WIDTH_YAML_FILE}s${RESET}\n" "$yaml_file"
        fi
        
        # Truncate long values based on column width
        local display_value="$value"
        local max_value_len=$((COL_WIDTH_VALUE - 2))  # Leave room for spacing
        if [ ${#display_value} -gt $max_value_len ]; then
            display_value="${display_value:0:$((max_value_len - 3))}..."
        fi
        
        # Prefix variable name with # if it's commented
        local display_var="$var"
        if [[ $is_commented -eq 1 ]]; then
            display_var="# $var"
        fi
        
        if [[ $is_missing -eq 1 ]]; then
            # Variable is NOT set - display in RED
            printf "${RED}  %-$((COL_WIDTH_YAML_FILE - 2))s %-${COL_WIDTH_VARIABLE}s %-${COL_WIDTH_VALUE}s %-${COL_WIDTH_SOURCE}s${RESET}\n" "$display_filename" "$display_var" "*** NOT SET ***" "*** MISSING ***"
        else
            # Variable is set - display normally with indent
            printf "  %-$((COL_WIDTH_YAML_FILE - 2))s %-${COL_WIDTH_VARIABLE}s %-${COL_WIDTH_VALUE}s %-${COL_WIDTH_SOURCE}s\n" "$display_filename" "$display_var" "$display_value" "${source:-N/A}"
        fi
    done
    
    # Summary
    printf "\n"
    log "INFO" "=========================================="
    log "INFO" "Total variable references found: ${#ALL_YAML_VARS[@]}"
    if [ $missing_count -gt 0 ]; then
        log "ERROR" "Missing variables: $missing_count"
    else
        log "INFO" "Missing variables: 0"
    fi
    log "INFO" "=========================================="
} # display_env_table

# Function to check dependencies
check_dependencies() {
    if ! command -v yamllint &> /dev/null; then
        log "ERROR" "yamllint is not installed. Please install it and try again."
        log "INFO" "Install with: sudo apt install yamllint"
        exit 1
    fi
} # check_dependencies

# Function to process a YAML file
process_file() {
    local file="$1"
    local config_option=""

    # Check for .yamllint in multiple locations (in order of preference)
    local config_locations=(
        "$BASE_DIR/.yamllint"           # Same directory as main YAML file
        "$DOCKERDIR/.yamllint"          # Docker directory root
        "$HOME/.yamllint"               # User home directory
        "$HOME/.config/yamllint/config" # XDG config location
    )

    for config_file in "${config_locations[@]}"; do
        if [[ -f "$config_file" ]]; then
            config_option="--config-file $config_file"
            log "DEBUG" "Using yamllint config: $config_file"
            break
        fi
    done

    if [[ -z "$config_option" ]]; then
        log "DEBUG" "No .yamllint config found, using yamllint defaults"
    fi

    local relative_path="${file#$BASE_DIR/}" # Make path relative to BASE_DIR
    local command=("yamllint" $config_option "$file") # Create command array
    local output

    # Debug output for the yamllint command
    if [[ $DEBUG_MODE -eq 1 ]]; then
        log "DEBUG" "Executing: ${command[*]}"
    fi

    if [ "$TEST_MODE" -eq 1 ]; then
        if [[ $HIDE_YAML_PROC -eq 0 ]]; then
            log "INFO" "TEST MODE: Would run yamllint on $file"
        fi
        # Still extract env vars and volumes even in test mode
        extract_env_vars_from_yaml "$file"
        extract_volumes_from_yaml "$file"
        return
    fi

    # Extract environment variables from this YAML file
    extract_env_vars_from_yaml "$file"
    
    # Extract volume mounts from this YAML file
    extract_volumes_from_yaml "$file"

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

    # Function to colorize yamllint output
    colorize_yamllint() {
        local line="$1"
        # Color lines with "error" in red
        if [[ "$line" =~ error ]]; then
            echo -e "${RED}${line}${RESET}"
        # Color lines with "warning" in yellow
        elif [[ "$line" =~ warning ]]; then
            echo -e "${YELLOW}${line}${RESET}"
        else
            # Keep file path and other lines uncolored
            echo "$line"
        fi
    }

    # Show yamllint output header and content if applicable
    if [[ $HIDE_YAML_PROC -eq 0 && ($SHOW_ALL -eq 1 || ($SHOW_ERRORS -eq 1 && $has_error -eq 1) || ($SHOW_WARNINGS -eq 1 && $has_warning -eq 1)) ]]; then
        if [[ $has_error -eq 1 ]]; then
            log "ERROR" "Output from yamllint for: $display_path"
        elif [[ $has_warning -eq 1 ]]; then
            log "WARN" "Output from yamllint for: $display_path"
        fi
        # Print colorized output line by line
        while IFS= read -r line; do
            colorize_yamllint "$line"
        done <<< "$output"
        echo "" # Add blank line after output
    elif [[ $HIDE_YAML_PROC -eq 0 ]]; then
        # Minimal output mode - just show checkmarks/status
        if [[ $exit_code -eq 0 ]]; then
            echo -e "[${GREEN}✔${RESET}] $display_path"
        elif [[ $has_error -eq 1 ]]; then
            echo -e "[${RED}✘${RESET}] $display_path (has errors - use -show-errors to see details)"
        else
            echo -e "[${YELLOW}?${RESET}] $display_path (has warnings)"
        fi
    fi

    # Handle file status for DEBUG mode
    if [[ $DEBUG_MODE -eq 1 && $HIDE_YAML_PROC -eq 0 ]]; then
        if [[ $exit_code -eq 0 ]]; then
            log "INFO" "[${GREEN}✔${RESET}] $display_path"
        elif [[ $has_error -eq 1 ]]; then
            log "ERROR" "[${RED}✘${RESET}] $display_path"
        else
            log "WARN" "[${YELLOW}?${RESET}] $display_path"
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

    if [ "$TEST_MODE" -eq 1 ]; then
        log "INFO" "TEST MODE: Would parse includes from $file"
        return
    fi

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

            # If path is not absolute after variable expansion, make it relative to BASE_DIR
            if [[ "$included_file" != /* ]]; then
                included_file="$BASE_DIR/$included_file"
            fi

            # Add the file to the list if it's not empty
            if [[ -n "$included_file" ]]; then
                included_files+=("$included_file")
            fi
        fi
    done < <(awk '/include:/ {flag=1; next} /^[^[:space:]]/ {flag=0} flag' "$file")
} # parse_includes

main() {
    # Last Updated: 1/19/2026 10:00:00 AM CST
    # Initialize variables
    local args=()
    local main_file=""

    # Parse all arguments, flags can appear anywhere
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -show-all|--show-all|-sa) SHOW_ALL=1 ;;
            -show-errors|--show-errors|-err) SHOW_ERRORS=1 ;;
            -show-warnings|--show-warnings|-warn) SHOW_WARNINGS=1 ;;
            -show-env|--show-env|-se) SHOW_ENV_TABLE=1 ;;
            -show-vol|--show-vol|-sv) SHOW_VOL_TABLE=1 ;;
            -hide-commented|--hide-commented|-hc) HIDE_COMMENTED=1 ;;
            -check-ports|-list-ports)
                CHECK_PORTS_MODE=1
                CHECK_PORTS_SORT="name"
                if [[ -n "$2" && "$2" != -* ]]; then
                    CHECK_PORTS_FILTER="$2"
                    shift
                fi
                ;;
            -check-ports-num)
                CHECK_PORTS_MODE=1
                CHECK_PORTS_SORT="num"
                if [[ -n "$2" && "$2" != -* ]]; then
                    CHECK_PORTS_FILTER="$2"
                    shift
                fi
                ;;
            -check-ports-dupes)
                CHECK_PORTS_MODE=2
                CHECK_PORTS_SORT="name"
                if [[ -n "$2" && "$2" != -* ]]; then
                    CHECK_PORTS_FILTER="$2"
                    shift
                fi
                ;;
            -local)
                CHECK_PORTS_LOCAL_ONLY=1
                ;;
            -hide-yaml-proc|-hide-yp)
                HIDE_YAML_PROC=1
                ;;
            -hide-yaml-vr|-hide-yv)
                HIDE_YAML_RESULTS=1
                ;;
            -p|--show-full-paths) SHOW_FULL_PATHS=1 ;;
            -debug|--debug) DEBUG_MODE=1 ;;
            -test|--test) TEST_MODE=1 ;;
            -usage|-help)
                usage
                exit 0
                ;;
            *)
                # Assume non-flag arguments are file paths
                args+=("$1")
                ;;
        esac
        shift
    done

    # Source .bash_profile to get functions
    source_bash_profile

    # Call load_env_files() - same function that dcrun uses
    # This loads .env files AND sets DOCKER_SHAREDDIR, DOCKER_SITEDIR, DOCKER_HOSTDIR
    if ! declare -f load_env_files >/dev/null; then
        log "ERROR" "load_env_files function not found after sourcing .bash_profile."
        exit 1
    fi
    if ! load_env_files 2>/dev/null; then
        log "ERROR" "Environment setup failed. Please run: \$DIVTOOLS/scripts/dt_host_setup.sh"
        exit 1
    fi
    log "INFO" "Environment variables loaded using load_env_files() (CFG_MODE=$CFG_MODE)."

    # Track all loaded environment variables
    track_loaded_env_vars

    # If no file specified, use the default docker compose file (same as dcrun)
    if [[ ${#args[@]} -eq 0 ]]; then
        # Get the default compose file using the same function as dcrun
        if declare -f get_docker_compose_file > /dev/null; then
            main_file=$(get_docker_compose_file)
            if [ -z "$main_file" ] || [ ! -f "$main_file" ]; then
                log "ERROR" "No docker compose file argument provided and unable to find default compose file."
                usage
                exit 1
            fi
            if [[ $HIDE_YAML_PROC -eq 0 ]]; then
                log "INFO" "Using default docker compose file: $main_file"
            fi
        else
            log "ERROR" "get_docker_compose_file function not available."
            exit 1
        fi
    else
        main_file="${args[0]}" # First non-flag argument is the main YAML file
    fi

    # Check if the main YAML file exists
    if [[ ! -f "$main_file" ]]; then
        log "ERROR" "File $main_file not found."
        exit 1
    fi

    BASE_DIR=$(dirname "$main_file") # Base directory for relative paths
    check_dependencies

    # Arrays to store file statuses
    FAILED_FILES=()
    WARNED_FILES=()
    included_files=()

    # Process main YAML file
    if [[ $HIDE_YAML_PROC -eq 0 ]]; then
        log "INFO" "Processing main YAML file: $main_file"
    fi
    process_file "$main_file"

    # Parse and process included files
    parse_includes "$main_file"
    for included_file in "${included_files[@]}"; do
        if [[ -f "$included_file" ]]; then
            if [[ $HIDE_YAML_PROC -eq 0 ]]; then
                log "INFO" "Processing included file: ${included_file#$BASE_DIR/}"
            fi
            process_file "$included_file"
        else
            if [[ $DEBUG_MODE -eq 1 ]]; then
                log "ERROR" "[${RED}✘${RESET}] Include file not found: ${included_file#$BASE_DIR/}"
            fi
            FAILED_FILES+=("$included_file")
        fi
    done

    # Summary
    if [[ $HIDE_YAML_RESULTS -eq 0 ]]; then
        log "INFO" "\n=========================================="
        log "INFO" "YAML Validation Results:"
        log "INFO" "=========================================="
        for file in "$main_file" "${included_files[@]}"; do
            local display_path="${file#$BASE_DIR/}"
            [[ $SHOW_FULL_PATHS -eq 1 ]] && display_path="$file"

            if grep -qF "$file" <(printf "%s\n" "${FAILED_FILES[@]}"); then
                log "ERROR" "[${RED}✘${RESET}] $display_path"
            elif grep -qF "$file" <(printf "%s\n" "${WARNED_FILES[@]}"); then
                log "WARN" "[${YELLOW}?${RESET}] $display_path"
            else
                log "INFO" "[${GREEN}✔${RESET}] $display_path"
            fi
        done
    fi

    # Display environment variable table if requested or if there are missing vars
    if [[ $SHOW_ENV_TABLE -eq 1 ]] || [[ ${#ALL_YAML_VARS[@]} -gt 0 ]]; then
        display_env_table
    fi

    # Display port table if requested
    if [[ $CHECK_PORTS_MODE -ne 0 ]]; then
        display_ports_table
    fi
    
    # Display volume table if requested
    if [[ $SHOW_VOL_TABLE -eq 1 ]]; then
        display_volume_table
    fi

    # Final status
    if [[ ${#FAILED_FILES[@]} -eq 0 ]]; then
        log "INFO" "\n[${GREEN}✔${RESET}] All YAML files validated successfully."
        
        # Check for missing env vars by checking each key in ALL_YAML_VARS
        local missing_vars=0
        for key in "${ALL_YAML_VARS[@]}"; do
            local var="${key%%|*}"
            if [ -z "${ENV_VAR_VALUES[$var]}" ] && [ -z "${ENV_VAR_SOURCES[$var]}" ]; then
                ((missing_vars++))
            fi
        done
        
        if [ $missing_vars -gt 0 ]; then
            log "WARN" "Warning: $missing_vars environment variable reference(s) are not set in .env files."
            exit 2
        fi
        
        exit 0
    else
        log "ERROR" "\n[${RED}✘${RESET}] Some files failed validation."
        exit 1
    fi
} # main

# Script Entry Point
main "$@"