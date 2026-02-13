#!/bin/bash
# Exports TrueNAS ZFS dataset usage information to a file for remote clients
# Last Updated: 11/4/2025 9:30:00 PM CST

# Source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../util/logging.sh" 2>/dev/null || {
    # Fallback if logging.sh not available
    log() {
        local level="$1"
        shift
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*"
    }
}

# Default flags
TEST_MODE=0
DEBUG_MODE=0

# Configuration
EXPORT_FILE="/mnt/tpool/FieldsHm/.zfs_usage_info"
PARENT_DATASET="tpool/FieldsHm"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -test|--test)
            TEST_MODE=1
            log "INFO" "Running in TEST mode - no permanent changes will be made"
            shift
            ;;
        -debug|--debug)
            DEBUG_MODE=1
            log "DEBUG" "Debug mode enabled"
            shift
            ;;
        -f|--file)
            EXPORT_FILE="$2"
            shift 2
            ;;
        -d|--dataset)
            PARENT_DATASET="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [-test] [-debug] [-f /path/to/export/file] [-d parent/dataset]"
            echo ""
            echo "Options:"
            echo "  -test, --test       Run in test mode (no file writes)"
            echo "  -debug, --debug     Enable debug output"
            echo "  -f, --file FILE     Export file path (default: $EXPORT_FILE)"
            echo "  -d, --dataset DS    Parent dataset (default: $PARENT_DATASET)"
            echo "  -h, --help          Show this help message"
            exit 0
            ;;
        *)
            log "ERROR" "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

log "INFO" "Script execution started"
log "DEBUG" "TEST_MODE=$TEST_MODE, DEBUG_MODE=$DEBUG_MODE"
log "DEBUG" "EXPORT_FILE=$EXPORT_FILE, PARENT_DATASET=$PARENT_DATASET"

# Check if running on TrueNAS/FreeBSD
if ! command -v zfs &> /dev/null; then
    log "ERROR" "zfs command not found. This script must run on a TrueNAS/ZFS system."
    exit 1
fi

# Verify parent dataset exists
if ! zfs list "$PARENT_DATASET" &> /dev/null; then
    log "ERROR" "Dataset '$PARENT_DATASET' not found"
    exit 1
fi

log "INFO" "Gathering ZFS dataset usage information for $PARENT_DATASET"

# Get dataset information
# Format: dataset, used, available, refer (referenced), mountpoint
declare -A DATASET_INFO

# Get all child datasets under parent
while IFS=$'\t' read -r name used avail refer mountpoint; do
    # Skip the parent dataset itself, only get children
    if [[ "$name" == "$PARENT_DATASET" ]]; then
        continue
    fi
    
    if [[ "$name" == "$PARENT_DATASET/"* ]]; then
        # Remove parent prefix for cleaner names
        short_name="${name#$PARENT_DATASET/}"
        
        log "DEBUG" "Found dataset: $short_name (used: $used, avail: $avail)"
        
        # Store in associative array
        DATASET_INFO["$short_name"]="$used|$avail|$refer|$mountpoint"
    fi
done < <(zfs list -H -o name,used,available,referenced,mountpoint -r "$PARENT_DATASET")

# Get parent dataset totals
read -r parent_used parent_avail parent_mountpoint < <(zfs list -H -o used,available,mountpoint "$PARENT_DATASET")

log "INFO" "Found ${#DATASET_INFO[@]} child datasets"
log "DEBUG" "Parent dataset - Used: $parent_used, Available: $parent_avail"

# Build output content
output="# ZFS Dataset Usage Information"
output+="\n# Generated: $(date '+%Y-%m-%d %H:%M:%S')"
output+="\n# Parent Dataset: $PARENT_DATASET"
output+="\n# Format: dataset|used|available|referenced|mountpoint"
output+="\n"
output+="\n[PARENT]"
output+="\nname=$PARENT_DATASET"
output+="\nused=$parent_used"
output+="\navailable=$parent_avail"
output+="\nmountpoint=$parent_mountpoint"
output+="\n"

# Add child datasets
for dataset in "${!DATASET_INFO[@]}"; do
    IFS='|' read -r used avail refer mountpoint <<< "${DATASET_INFO[$dataset]}"
    output+="\n[DATASET:$dataset]"
    output+="\nused=$used"
    output+="\navailable=$avail"
    output+="\nreferenced=$refer"
    output+="\nmountpoint=$mountpoint"
    output+="\n"
done

# Write to file
if [[ $TEST_MODE -eq 1 ]]; then
    log "INFO" "TEST MODE: Would write to $EXPORT_FILE"
    log "INFO:raw" "--- BEGIN FILE CONTENT ---"
    echo -e "$output"
    log "INFO:raw" "--- END FILE CONTENT ---"
else
    if echo -e "$output" > "$EXPORT_FILE"; then
        log "INFO" "Successfully wrote usage information to $EXPORT_FILE"
        chmod 644 "$EXPORT_FILE"
        log "DEBUG" "File permissions set to 644"
    else
        log "ERROR" "Failed to write to $EXPORT_FILE"
        exit 1
    fi
fi

log "INFO" "Script execution completed successfully"
