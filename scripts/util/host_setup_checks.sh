#!/bin/bash
# host_setup_checks.sh - Interactive host setup verification and execution
# Checks if required host setups have been completed and prompts user to run them
# Last Updated: 11/11/2025 8:30:00 PM CDT
#
# Supports flags for testing:
#   -test, --test    Run in test mode (dry-run, no actual execution)
#   -debug, --debug  Enable debug output
#
# This function should be sourced and called from .bash_profile in interactive shells
# It displays a whiptail menu of available setups that can be configured

# Prevent double-sourcing
if [ -n "$HOST_SETUP_CHECKS_SOURCED" ]; then
    return 0
fi
export HOST_SETUP_CHECKS_SOURCED=1

# Initialize TEST_MODE and DEBUG_MODE from environment if not already set
# This allows flags to be set via environment variables OR command-line args
TEST_MODE=${TEST_MODE:-0}
DEBUG_MODE=${DEBUG_MODE:-0}

# Parse command-line flags (if provided)
while [[ $# -gt 0 ]]; do
    case $1 in
        -test|--test)
            TEST_MODE=1
            shift
            ;;
        -debug|--debug)
            DEBUG_MODE=1
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Debug logging function
debug_log() {
    if [[ $DEBUG_MODE -eq 1 ]]; then
        echo -e "\033[37m[DEBUG] $*\033[0m" >&2
    fi
}

debug_log "host_setup_checks.sh sourced (TEST_MODE=$TEST_MODE, DEBUG_MODE=$DEBUG_MODE)"

# Timed prompt function - asks user if they want to see setup options
# Returns 0 if YES (proceed), 1 if NO/timeout (skip)
# Last Updated: 11/11/2025 10:10:00 PM CDT
timed_setup_prompt() {
    local timeout=10
    local response
    
    echo ""
    echo -e "\033[33m════════════════════════════════════════════════════════════════\033[0m"
    echo -e "\033[33m⚠️  Incomplete Host Setup Tasks Detected\033[0m"
    echo -e "\033[33m════════════════════════════════════════════════════════════════\033[0m"
    echo ""
    echo -e "\033[36mWould you like to review and configure these setups now?\033[0m"
    echo ""
    echo -e "\033[37m[Y/n]\033[0m"
    echo ""
    
    # Start countdown in background
    local countdown_running=1
    (
        for ((i=timeout; i>0; i--)); do
            if [ $countdown_running -eq 0 ]; then
                break
            fi
            # Print countdown with progress bar
            local bar_length=40
            local filled=$((bar_length * (timeout - i + 1) / timeout))
            local empty=$((bar_length - filled))
            
            # Build progress bar
            local bar="["
            for ((j=0; j<filled; j++)); do bar+="="; done
            for ((j=0; j<empty; j++)); do bar+=" "; done
            bar+="]"
            
            # Print countdown line (overwrite previous)
            printf "\r\033[33m%s\033[0m \033[37mAuto-selecting 'No' in \033[33m%2d\033[37m seconds...\033[0m" "$bar" "$i"
            sleep 1
        done
        
        # Clear the countdown line if timeout completes
        if [ $countdown_running -eq 1 ]; then
            printf "\r\033[K"  # Clear line
        fi
    ) &
    local countdown_pid=$!
    
    # Read with timeout (non-blocking check for input)
    if read -t $timeout -n 1 -r response; then
        # User provided input - stop countdown
        countdown_running=0
        kill $countdown_pid 2>/dev/null
        wait $countdown_pid 2>/dev/null
        printf "\r\033[K"  # Clear countdown line
        echo ""  # New line after input
        
        case "$response" in
            [Yy])
                debug_log "User answered YES to setup prompt"
                return 0  # Proceed with whiptail menu
                ;;
            *)
                debug_log "User answered NO to setup prompt"
                echo -e "\033[36m[INFO] Setup skipped by user.\033[0m"
                echo ""
                return 1  # Skip setup
                ;;
        esac
    else
        # Timeout occurred - countdown already finished
        wait $countdown_pid 2>/dev/null
        echo ""  # New line after timeout
        debug_log "Timed prompt expired - auto-selecting NO"
        echo -e "\033[36m[INFO] No response - setup skipped (auto-timeout).\033[0m"
        echo ""
        return 1  # Skip setup
    fi
}

# Set whiptail colors matching dt_host_setup.sh
set_whiptail_colors_setup() {
    export NEWT_COLORS='
        root=,black
        window=,black
        border=white,black
        textbox=white,black
        button=black,white
        actbutton=white,blue
        compactbutton=black,white
        title=cyan,black
        label=cyan,black
        entry=white,black
        checkbox=cyan,black
        actcheckbox=black,cyan
        listbox=white,black
        actlistbox=black,cyan
        sellistbox=black,cyan
        actsellistbox=white,blue
    '
}

# Get the path to the divtools directory
get_divtools_path() {
    # Try common locations
    if [ -d "/opt/divtools" ]; then
        echo "/opt/divtools"
    elif [ -d "$HOME/divtools" ]; then
        echo "$HOME/divtools"
    elif [ -n "$DIVTOOLS" ] && [ -d "$DIVTOOLS" ]; then
        echo "$DIVTOOLS"
    else
        # Default fallback
        echo "/opt/divtools"
    fi
}

# Check if dt_host_setup has been run
check_host_setup_status() {
    local dt_home=$(get_divtools_path)
    
    debug_log "Checking dt_host_setup status..."
    debug_log "  Looking for ~/.env file"
    
    # Check if ~/.env exists and contains SITE_NAME (basic indicator of dt_host_setup completion)
    if [ -f ~/.env ]; then
        debug_log "  ~/.env exists"
        if grep -q "SITE_NAME=" ~/.env; then
            debug_log "  SITE_NAME found in ~/.env - setup is COMPLETE"
            return 0  # Setup appears to be completed
        else
            debug_log "  SITE_NAME NOT found in ~/.env - setup is INCOMPLETE"
            return 1  # Setup not completed
        fi
    else
        debug_log "  ~/.env does not exist - setup is INCOMPLETE"
        return 1  # Setup not completed
    fi
}

# Check if host_change_log setup has been run
check_host_change_log_status() {
    local dt_home=$(get_divtools_path)
    local log_dir="${DT_LOG_DIR:-/var/log/divtools/monitor}"
    
    debug_log "Checking host_change_log status..."
    debug_log "  Looking for manifest at: ${log_dir}/monitoring_manifest.json"
    
    # Check if monitoring manifest exists (indicates host_change_log setup completion)
    if [ -f "${log_dir}/monitoring_manifest.json" ]; then
        debug_log "  Manifest found - setup is COMPLETE"
        return 0  # Setup appears to be completed
    else
        debug_log "  Manifest NOT found - setup is INCOMPLETE"
        return 1  # Setup not completed
    fi
}

# Run dt_host_setup.sh
run_host_setup() {
    local dt_home=$(get_divtools_path)
    local setup_script="$dt_home/scripts/dt_host_setup.sh"
    
    debug_log "Running dt_host_setup..."
    debug_log "  Script path: $setup_script"
    
    if [ -f "$setup_script" ]; then
        echo ""
        echo -e "\033[36m[INFO] Running dt_host_setup.sh...\033[0m"
        echo ""
        
        if [ $TEST_MODE -eq 1 ]; then
            echo -e "\033[33m[TEST MODE] Would execute: sudo $setup_script\033[0m"
            debug_log "TEST_MODE: skipping actual execution"
            return 0
        else
            sudo "$setup_script"
            local exit_code=$?
        fi
        
        echo ""
        if [ $exit_code -eq 0 ]; then
            echo -e "\033[32m[SUCCESS] dt_host_setup.sh completed successfully.\033[0m"
        else
            echo -e "\033[31m[ERROR] dt_host_setup.sh failed with exit code $exit_code.\033[0m"
        fi
        return $exit_code
    else
        echo -e "\033[31m[ERROR] dt_host_setup.sh not found at: $setup_script\033[0m"
        debug_log "ERROR: Setup script not found at $setup_script"
        return 1
    fi
}

# Run host_change_log.sh setup
run_host_change_log_setup() {
    local dt_home=$(get_divtools_path)
    local setup_script="$dt_home/scripts/util/host_chg_mon/host_change_log.sh"
    
    debug_log "Running host_change_log setup..."
    debug_log "  Script path: $setup_script"
    
    if [ -f "$setup_script" ]; then
        echo ""
        echo -e "\033[36m[INFO] Running host_change_log.sh setup...\033[0m"
        echo ""
        
        if [ $TEST_MODE -eq 1 ]; then
            echo -e "\033[33m[TEST MODE] Would execute: sudo $setup_script setup\033[0m"
            debug_log "TEST_MODE: skipping actual execution"
            return 0
        else
            sudo "$setup_script" setup
            local exit_code=$?
        fi
        
        echo ""
        if [ $exit_code -eq 0 ]; then
            echo -e "\033[32m[SUCCESS] host_change_log.sh setup completed successfully.\033[0m"
        else
            echo -e "\033[31m[ERROR] host_change_log.sh setup failed with exit code $exit_code.\033[0m"
        fi
        return $exit_code
    else
        echo -e "\033[31m[ERROR] host_change_log.sh not found at: $setup_script\033[0m"
        debug_log "ERROR: Setup script not found at $setup_script"
        return 1
    fi
}

# Main host setup checks function
# Call this from .bash_profile in the interactive shell section, as the LAST thing
host_setup_checks() {
    # Only run in interactive shells
    if [[ ! $- == *i* ]]; then
        debug_log "Not in interactive shell, skipping checks"
        return 0
    fi
    
    debug_log "host_setup_checks() started"
    
    # Load shared .env file if DT_INCLUDE_* variables aren't already set
    # This ensures we have the configuration even if load_env_files failed due to missing SITE_NAME
    # Last Updated: 11/11/2025 9:10:00 PM CDT
    if [ -z "$DT_INCLUDE_HOST_SETUP" ] || [ -z "$DT_INCLUDE_HOST_CHANGE_LOG" ]; then
        debug_log "DT_INCLUDE_* variables not set, attempting to load shared .env"
        local dt_path=$(get_divtools_path)
        local shared_env="${dt_path}/docker/sites/s00-shared/.env.s00-shared"
        
        if [ -f "$shared_env" ]; then
            debug_log "Sourcing shared .env: $shared_env"
            source "$shared_env"
            debug_log "After sourcing shared .env:"
            debug_log "  DT_INCLUDE_HOST_SETUP=${DT_INCLUDE_HOST_SETUP:-not set}"
            debug_log "  DT_INCLUDE_HOST_CHANGE_LOG=${DT_INCLUDE_HOST_CHANGE_LOG:-not set}"
        else
            debug_log "Shared .env not found at: $shared_env"
        fi
    else
        debug_log "DT_INCLUDE_* variables already set"
    fi
    
    debug_log "TEST_MODE=$TEST_MODE, DEBUG_MODE=$DEBUG_MODE"
    debug_log "DT_INCLUDE_HOST_SETUP=${DT_INCLUDE_HOST_SETUP:-not set}"
    debug_log "DT_INCLUDE_HOST_CHANGE_LOG=${DT_INCLUDE_HOST_CHANGE_LOG:-not set}"
    debug_log "DIVTOOLS_SKIP_CHECKS=${DIVTOOLS_SKIP_CHECKS:-not set}"
    
    # Don't show menus if DIVTOOLS_SKIP_CHECKS is set (for automation/scripting)
    if [ "${DIVTOOLS_SKIP_CHECKS:-0}" == "1" ]; then
        debug_log "DIVTOOLS_SKIP_CHECKS is set, skipping all checks"
        return 0
    fi
    
    # Array to track which setups need attention
    local setups_to_show=()
    local setup_descriptions=()
    
    debug_log "Checking DT_INCLUDE_HOST_SETUP..."
    # Check DT_INCLUDE_HOST_SETUP
    if [ "${DT_INCLUDE_HOST_SETUP:-0}" == "1" ] || [ "${DT_INCLUDE_HOST_SETUP:-0}" == "true" ]; then
        debug_log "DT_INCLUDE_HOST_SETUP is enabled, checking status..."
        if ! check_host_setup_status; then
            debug_log "dt_host_setup is NOT complete, adding to menu"
            setups_to_show+=("dt_host_setup")
            setup_descriptions+=("Host Setup (Environment & Variables)")
        else
            debug_log "dt_host_setup is already complete"
        fi
    else
        debug_log "DT_INCLUDE_HOST_SETUP is disabled or not set"
    fi
    
    debug_log "Checking DT_INCLUDE_HOST_CHANGE_LOG..."
    # Check DT_INCLUDE_HOST_CHANGE_LOG
    if [ "${DT_INCLUDE_HOST_CHANGE_LOG:-0}" == "1" ] || [ "${DT_INCLUDE_HOST_CHANGE_LOG:-0}" == "true" ]; then
        debug_log "DT_INCLUDE_HOST_CHANGE_LOG is enabled, checking status..."
        if ! check_host_change_log_status; then
            debug_log "host_change_log is NOT complete, adding to menu"
            setups_to_show+=("host_change_log")
            setup_descriptions+=("Host Change Log Monitoring")
        else
            debug_log "host_change_log is already complete"
        fi
    else
        debug_log "DT_INCLUDE_HOST_CHANGE_LOG is disabled or not set"
    fi
    
    # If no setups need attention, exit silently
    if [ ${#setups_to_show[@]} -eq 0 ]; then
        debug_log "No incomplete setups found, exiting"
        return 0
    fi
    
    debug_log "Found ${#setups_to_show[@]} incomplete setup(s)"
    
    # Show timed prompt BEFORE displaying whiptail menu
    # This prevents whiptail from hanging VSCode if a sudo prompt is in the background
    # User has 10 seconds to respond, otherwise auto-skips
    # Last Updated: 11/11/2025 10:00:00 PM CDT
    if ! timed_setup_prompt; then
        debug_log "User declined or timed out on setup prompt - exiting"
        return 0
    fi
    
    # Display details about pending setups
    echo ""
    echo -e "\033[36mIncomplete Setup Tasks:\033[0m"
    for i in "${!setups_to_show[@]}"; do
        echo -e "\033[36m  • ${setup_descriptions[$i]}\033[0m"
    done
    echo ""
    
    # Only show whiptail menu if we have the tool and are actually in an interactive terminal
    if command -v whiptail >/dev/null 2>&1 && [ -t 0 ]; then
        set_whiptail_colors_setup
        
        # Build whiptail checklist
        local checklist_items=()
        for i in "${!setups_to_show[@]}"; do
            # ON by default for each uncompleted setup
            checklist_items+=("${setups_to_show[$i]}" "${setup_descriptions[$i]}" "ON")
        done
        
        # Show whiptail menu
        local selected_setups
        selected_setups=$(whiptail --fb \
            --title "Host Setup Configuration" \
            --checklist "Select which host setups to run:" \
            20 70 10 \
            "${checklist_items[@]}" \
            3>&1 1>&2 2>&3)
        
        local whiptail_exit=$?
        
        # Handle user cancellation
        if [ $whiptail_exit -ne 0 ]; then
            echo -e "\033[33m[INFO] Setup skipped by user.\033[0m"
            echo ""
            return 0
        fi
        
        # Parse selected setups (whiptail returns quoted strings separated by spaces)
        local -a selected_array=()
        while IFS= read -r item; do
            # Remove quotes if present
            item="${item%\"}"
            item="${item#\"}"
            if [ -n "$item" ]; then
                selected_array+=("$item")
            fi
        done <<< "$(echo "$selected_setups" | tr ' ' '\n')"
        
        # Run each selected setup in sequence
        if [ ${#selected_array[@]} -gt 0 ]; then
            echo ""
            echo -e "\033[36m[INFO] Starting selected host setups...\033[0m"
            
            for setup in "${selected_array[@]}"; do
                case "$setup" in
                    "dt_host_setup")
                        run_host_setup
                        ;;
                    "host_change_log")
                        run_host_change_log_setup
                        ;;
                esac
            done
            
            echo ""
            echo -e "\033[32m[SUCCESS] Host setup tasks completed.\033[0m"
            echo ""
        else
            echo -e "\033[33m[INFO] No setups selected.\033[0m"
            echo ""
        fi
    else
        # Fallback to simple yes/no prompts if whiptail not available
        debug_log "Whiptail not available or not in interactive terminal, using fallback prompts"
        
        for i in "${!setups_to_show[@]}"; do
            echo -n -e "\033[36mRun ${setup_descriptions[$i]}? (y/n): \033[0m"
            read -r response
            
            if [[ "$response" =~ ^[Yy]$ ]]; then
                case "${setups_to_show[$i]}" in
                    "dt_host_setup")
                        run_host_setup
                        ;;
                    "host_change_log")
                        run_host_change_log_setup
                        ;;
                esac
            fi
        done
        echo ""
    fi
    
    debug_log "host_setup_checks() completed"
}

# If this script is executed directly (not sourced), show usage info
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    cat <<EOF
host_setup_checks.sh - Interactive Host Setup Verification

This script is designed to be sourced and called from .bash_profile,
not executed directly.

Usage in .bash_profile:
  source \$DIVTOOLS/scripts/util/host_setup_checks.sh
  host_setup_checks

Environment Variables:
  DT_INCLUDE_HOST_SETUP       - Set to 1 or true to enable dt_host_setup checks
  DT_INCLUDE_HOST_CHANGE_LOG  - Set to 1 or true to enable host_change_log checks
  DIVTOOLS_SKIP_CHECKS        - Set to 1 to skip all setup checks (useful for automation)

Configuration:
  Set these variables at:
    - Shared level: docker/sites/s00-shared/.env.s00-shared
    - Site level:   docker/sites/<site-name>/.env.<site-name>
    - Host level:   docker/sites/<site-name>/<hostname>/.env.<hostname>
    - User level:   ~/.env

Examples:
  # Enable both checks at site level
  echo "export DT_INCLUDE_HOST_SETUP=1" >> docker/sites/mysite/.env.mysite
  echo "export DT_INCLUDE_HOST_CHANGE_LOG=1" >> docker/sites/mysite/.env.mysite

  # Skip checks for automated deployments
  export DIVTOOLS_SKIP_CHECKS=1 && source /etc/profile

EOF
fi
