#!/bin/bash
# Logging function with color support and tag-based coloring
# Last Updated: 11/11/2025 5:50:00 PM CST
#
# IMPORTANT: Sync Notes
# ═══════════════════════════════════════════════════════════════════════════
# This file contains BOTH a log_msg() wrapper and a log() fallback function.
#
# To maintain cross-compatibility and ease of maintenance:
# 1. PRIMARY implementation: /home/divix/divtools/dotfiles/.bash_profile (log_msg)
# 2. FALLBACK implementation: /home/divix/divtools/scripts/util/logging.sh (log)
# 3. When adding new sections or colors, update BOTH files to stay in sync
# 4. This script will use .bash_profile's log_msg() if available, otherwise log()
#
# BEHAVIOR:
# - If .bash_profile is already sourced: Uses log_msg() from there
# - If not sourced: Uses log() fallback from this file
# - Both functions accept: log_msg "SECTION" "message"
# ═══════════════════════════════════════════════════════════════════════════

# Check if log_msg is already defined (from .bash_profile)
# If not, we'll define our own version that uses the log() function
if ! declare -f log_msg >/dev/null 2>&1; then
    # log_msg is not defined yet, so define our version that calls log()
    log_msg() {
        local section="$1"
        local message="$2"
        # Delegate to log() function below
        log "$section" "$message"
    }
fi

# Fallback log() function - Used when log_msg() is not available
# Keep in sync with log_msg() in .bash_profile for cross-compatibility
# IMPORTANT SYNC NOTE: Update both implementations when adding new sections/colors
log() {
    local level="$1"
    local message="$2"
    local prefix=""
    local tag=""
    local color_tag=""
    local no_timestamp=0
    local no_tag=0
    local color=""

    # Parse level by splitting on :
    IFS=':' read -r -a parts <<< "$level"
    prefix="${parts[0]}"
    color_tag="$prefix"  # Default to prefix for color
    tag="$prefix"        # Default

    # Process additional parts as tags or suffixes
    for (( i=1; i<${#parts[@]}; i++ )); do
        local part="${parts[i]}"
        local part_lower="${part,,}"
        if [[ "$part_lower" == "!ts" ]]; then
            no_timestamp=1
        elif [[ "$part_lower" == "raw" ]]; then
            no_timestamp=1
            no_tag=1
        else
            tag="$part"
            color_tag="$part"
        fi
    done

    # Suppress DEBUG output unless DEBUG_MODE=1
    if [[ "$prefix" == "DEBUG" && "$DEBUG_MODE" != "1" ]]; then
        return
    fi

    # Define colors based on color_tag (keep in sync with .bash_profile log_msg())
    case "$color_tag" in
        DEBUG|WHITE) color="\033[37m" ;; # White
        INFO) color="\033[36m" ;;  # Cyan
        WARN|WARNING) color="\033[33m" ;;  # Yellow
        ERROR) color="\033[31m" ;; # Red
        HEAD) color="\033[32m" ;;  # Green
        GREEN) color="\033[32m" ;; # Green
        BLUE) color="\033[34m" ;;  # Blue
        RED) color="\033[31m" ;;   # Red
        MAGENTA) color="\033[35m" ;; # Magenta
        PURPLE) color="\033[35m" ;; # Purple (same as Magenta for simplicity)
        ORANGE|YELLOW) color="\033[33m" ;; # Orange (same as Yellow for simplicity)
        SAMBA) color="\033[38;5;123m" ;; # Light blue (match .bash_profile)
        STAR) color="\033[33m" ;;  # Yellow (match .bash_profile)
        TMUX) color="\033[36m" ;;  # Cyan (match .bash_profile)
        *) color="\033[0m" ;;      # Default (no color)
    esac

    # Reset color
    local reset="\033[0m"

    # Build output
    local timestamp=""
    if [[ $no_timestamp -eq 0 ]]; then
        timestamp="[$(date '+%Y-%m-%d %H:%M:%S')] "
    fi
    local prefix_str=""
    if [[ $no_tag -eq 0 ]]; then
        prefix_str="[$prefix] "
    fi
    local output="${timestamp}${prefix_str}${message}"

    # Output to stderr for DEBUG and WARN, stdout for others
    if [[ "$prefix" == "DEBUG" || "$prefix" == "WARN" ]]; then
        echo -e "${color}${output}${reset}" >&2
    else
        echo -e "${color}${output}${reset}"
    fi
}