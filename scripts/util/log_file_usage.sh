#!/bin/bash
# Folder Usage Logging Script
# Logs disk usage of folders and subfolders with timestamps
# Last Updated: 10/1/2025 10:30:00 AM CDT

# Source the logging utility
source "$DIVTOOLS/scripts/util/logging.sh"

# Default values
MAX_DEPTH=3
STAY_ON_FS=0
DEBUG_MODE=0
TEST_MODE=0
QUIET_MODE=0

usage() {
    cat << EOF
Usage: $(basename "$0") [options] [path]

Options:
    -o <file>        Output file (optional, defaults to stdout)
    -d <depth>       Maximum depth to traverse (default: 3)
    -x               Stay on one filesystem
    -debug           Enable debug output
    -test           Run in test mode (no actual writes)
    -h, --help      Show this help message

The path argument can be specified with -path or as the last argument
EOF
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -o)
            OUTPUT_FILE="$2"
            QUIET_MODE=1
            shift 2
            ;;
        -d)
            MAX_DEPTH="$2"
            shift 2
            ;;
        -x)
            STAY_ON_FS=1
            shift
            ;;
        -debug)
            DEBUG_MODE=1
            shift
            ;;
        -test)
            TEST_MODE=1
            shift
            ;;
        -h|--help)
            usage
            ;;
        -path)
            TARGET_PATH="$2"
            shift 2
            ;;
        *)
            if [[ -z "$TARGET_PATH" ]]; then
                TARGET_PATH="$1"
            else
                log "ERROR" "Unknown option: $1"
                usage
            fi
            shift
            ;;
    esac
done

# Validate required arguments
if [[ -z "$TARGET_PATH" ]]; then
    log "ERROR" "Target path is required"
    usage
fi

# Convert target path to absolute path
TARGET_PATH=$(readlink -f "$TARGET_PATH")

# Function to format size in human-readable format
format_size() {
    local size=$1
    local units=("B" "KB" "MB" "GB" "TB")
    local unit=0
    local divider=1
    local float_size=$size

    # Find appropriate unit
    while ((float_size >= 1024 && unit < ${#units[@]}-1)); do
        float_size=$((float_size / 1024))
        ((unit++))
        divider=$((divider * 1024))
    done

    # Calculate with 2 decimal precision
    local decimal=$(( (size * 100) / divider ))
    printf "%d.%02d %s" $((decimal / 100)) $((decimal % 100)) "${units[$unit]}"
}

# Function to log folder usage
log_folder_usage() {
    local path="$1"
    local depth="$2"
    local du_opts="-b"

    [[ $STAY_ON_FS -eq 1 ]] && du_opts+=" -x"
    
    # Skip if path is not readable
    if [[ ! -r "$path" ]]; then
        log "DEBUG" "Skipping unreadable path: $path"
        return
    fi

    # Get folder size in bytes
    local size
    size=$(du $du_opts -s "$path" 2>/dev/null | cut -f1)
    
    if [[ -n "$size" ]]; then
        local human_size
        human_size=$(format_size "$size")
        local timestamp
        timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        
        # Create JSON-structured log entry
        local log_entry
        log_entry=$(cat << EOF
{"timestamp":"$timestamp","path":"$path","size_bytes":$size,"size_human":"$human_size","depth":$depth}
EOF
)
        
        if [[ -n "$OUTPUT_FILE" ]]; then
            if [[ $TEST_MODE -eq 1 ]]; then
                log "TEST" "Would write to $OUTPUT_FILE: $log_entry"
            else
                echo "$log_entry" >> "$OUTPUT_FILE"
            fi
        fi
        
        # Only output to console if no output file is specified
        if [[ -z "$OUTPUT_FILE" ]]; then
            log "INFO" "$path: $size bytes ($human_size)"
        fi
    fi

    # Process subdirectories if not at max depth
    if [[ $depth -lt $MAX_DEPTH ]]; then
        while IFS= read -r subdir; do
            log_folder_usage "$subdir" $((depth + 1))
        done < <(find "$path" -maxdepth 1 -mindepth 1 -type d 2>/dev/null)
    fi
}

# Main execution
if [[ $QUIET_MODE -eq 0 ]]; then
    log "HEAD" "Starting folder usage analysis for: $TARGET_PATH"
    [[ $DEBUG_MODE -eq 1 ]] && log "DEBUG" "Max depth: $MAX_DEPTH, Stay on FS: $STAY_ON_FS"
fi

if [[ $TEST_MODE -eq 1 ]]; then
    log "TEST" "Running in test mode"
fi

# Initialize output file if specified
if [[ -n "$OUTPUT_FILE" ]]; then
    if [[ $TEST_MODE -eq 1 ]]; then
        log "TEST" "Would create/append to output file: $OUTPUT_FILE"
    else
        touch "$OUTPUT_FILE" 2>/dev/null || {
            log "ERROR" "Cannot write to output file: $OUTPUT_FILE"
            exit 1
        }
    fi
fi

# Start the recursive folder analysis
log_folder_usage "$TARGET_PATH" 0

[[ $QUIET_MODE -eq 0 ]] && log "HEAD" "Analysis complete"