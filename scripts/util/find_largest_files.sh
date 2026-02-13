#!/bin/bash

# Logging function for colored output
# Last Updated: 9/12/2025 10:14:45 AM CDT
log_message() {
    local level="$1"
    local message="$2"
    local color

    case "$level" in
        "DEBUG") color="\033[1;37m" ;; # White
        "INFO")  color="\033[1;36m" ;; # Cyan
        "WARN")  color="\033[1;33m" ;; # Yellow
        "ERROR") color="\033[1;31m" ;; # Red
        *)       color="\033[0m"    ;; # Default (no color)
    esac

    echo -e "${color}[${level}] ${message}\033[0m"
}

# Parse command-line arguments
# Last Updated: 9/12/2025 10:14:45 AM CDT
parse_args() {
    COUNT=20 # Default number of files to return
    TEST_MODE=false
    DEBUG_MODE=false
    FOLDER="."

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--number)
                COUNT="$2"
                shift 2
                ;;
            -t|--test)
                TEST_MODE=true
                shift
                ;;
            -d|--debug)
                DEBUG_MODE=true
                shift
                ;;
            *)
                FOLDER="$1"
                shift
                ;;
        esac
    done

    if [[ ! -d "$FOLDER" ]]; then
        log_message "ERROR" "Directory '$FOLDER' does not exist."
        exit 1
    fi

    if ! [[ "$COUNT" =~ ^[0-9]+$ ]] || [ "$COUNT" -lt 1 ]; then
        log_message "ERROR" "Invalid number of files: '$COUNT'. Must be a positive integer."
        exit 1
    fi

    $DEBUG_MODE && log_message "DEBUG" "Folder: $FOLDER, Count: $COUNT, Test Mode: $TEST_MODE, Debug Mode: $DEBUG_MODE"
}

# Find and display largest files
# Last Updated: 9/12/2025 10:21:00 AM CDT
find_largest_files() {
    if $TEST_MODE; then
        log_message "INFO" "Running in test mode, simulating file search in '$FOLDER'."
        log_message "INFO" "Would return top $COUNT largest files."
        return
    fi

    log_message "INFO" "Searching for the $COUNT largest files in '$FOLDER'..."

    # Use find to locate files, du to get sizes in bytes, convert to GB, sort, and head to get top N
    find "$FOLDER" -type f -exec du -s {} + 2>/dev/null | sort -nr | head -n "$COUNT" | while read -r size file; do
        # Convert size (in KB from du -s) to GB with 2 decimal places using awk
        size_in_gb=$(awk -v size="$size" 'BEGIN { printf "%.2f", size / 1048576 }')
        # Format output with fixed-width column (10 chars for size_in_gb)
        printf "%-10s | %s\n" "${size_in_gb} GB" "$file"
        $DEBUG_MODE && log_message "DEBUG" "Processing file: $file with size $size KB (${size_in_gb} GB)"
    done

    if [ $? -ne 0 ]; then
        log_message "ERROR" "An error occurred while searching for files."
        exit 1
    fi
}


# Main execution
# Last Updated: 9/12/2025 10:14:45 AM CDT
main() {
    parse_args "$@"
    find_largest_files
}

main "$@"