#!/bin/bash
# Create softlinks for all folders from source to destination
# Last Updated: 12/15/2025 9:55:00 PM CST
#
# FUNCTIONALITY:
# - Accepts source and destination paths as arguments
# - Creates softlinks in destination for EVERY folder in source
# - If destination folder already exists, moves it to <folder-name>.orig
# - If softlink already exists, recreates it to ensure correctness
# - Supports -debug and -test flags for testing/debugging
# - Displays INFO messages for source/dest paths
# - Provides help output when run without arguments
# - Last 2 positional args default to source and dest if --source/--dest not used
#
# USAGE:
#   mklink.sh [--source <path>] [--dest <path>] [-test] [-debug]
#   mklink.sh <source-path> <dest-path> [-test] [-debug]

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)

# Source logging utilities
if [[ -f "$REPO_ROOT/scripts/util/logging.sh" ]]; then
    source "$REPO_ROOT/scripts/util/logging.sh"
fi

# Defaults
SOURCE=""
DEST=""
TEST_MODE=0
DEBUG_MODE=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --source)
            SOURCE="$2"
            shift 2
            ;;
        --dest)
            DEST="$2"
            shift 2
            ;;
        -test|--test)
            TEST_MODE=1
            shift
            ;;
        -debug|--debug)
            DEBUG_MODE=1
            shift
            ;;
        -h|--help)
            cat <<EOF
Usage: $(basename "$0") [OPTIONS] [source] [dest]

Create softlinks in destination directory for all folders in source directory.

OPTIONS:
  --source PATH      Path containing folders to link
  --dest PATH        Destination path where softlinks will be created
  -test              Test mode (dry-run, no changes)
  -debug             Debug mode (verbose output)
  -h, --help         Show this help message

POSITIONAL ARGUMENTS:
  If --source and --dest are not provided, the last two positional arguments
  are treated as source and dest respectively.

BEHAVIOR:
  - Creates softlinks in DEST for every folder in SOURCE
  - If a folder already exists in DEST, moves it to <folder-name>.orig
  - If a softlink already exists, recreates it
  - Shows INFO messages for source/dest paths

EXAMPLES:
  $(basename "$0") --source /data/models --dest /opt/comfy/models
  $(basename "$0") /data/models /opt/comfy/models
  $(basename "$0") /data/models /opt/comfy/models -test -debug
EOF
            exit 0
            ;;
        *)
            # Treat remaining args as positional (source and dest)
            if [[ -z "$SOURCE" ]]; then
                SOURCE="$1"
            elif [[ -z "$DEST" ]]; then
                DEST="$1"
            fi
            shift
            ;;
    esac
done

# Helper for debug output
dbg() {
    if [[ $DEBUG_MODE -eq 1 ]]; then
        echo "[DEBUG] $*" >&2
    fi
}

# Validate arguments
if [[ -z "$SOURCE" || -z "$DEST" ]]; then
    log_msg "ERROR" "Source and destination paths are required"
    echo ""
    # Show help
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] [source] [dest]

Create softlinks in destination directory for all folders in source directory.

OPTIONS:
  --source PATH      Path containing folders to link
  --dest PATH        Destination path where softlinks will be created
  -test              Test mode (dry-run, no changes)
  -debug             Debug mode (verbose output)
  -h, --help         Show this help message

POSITIONAL ARGUMENTS:
  If --source and --dest are not provided, the last two positional arguments
  are treated as source and dest respectively.

BEHAVIOR:
  - Creates softlinks in DEST for every folder in SOURCE
  - If a folder already exists in DEST, moves it to <folder-name>.orig
  - If a softlink already exists, recreates it
  - Shows INFO messages for source/dest paths

EXAMPLES:
  mklink.sh --source /data/models --dest /opt/comfy/models
  mklink.sh /data/models /opt/comfy/models
  mklink.sh /data/models /opt/comfy/models -test -debug
EOF
    exit 1
fi

# Show configuration
log_msg "INFO" "Source: $SOURCE"
log_msg "INFO" "Dest:   $DEST"
[[ $TEST_MODE -eq 1 ]] && log_msg "INFO" "TEST_MODE enabled (dry-run)"
[[ $DEBUG_MODE -eq 1 ]] && log_msg "INFO" "DEBUG_MODE enabled"

# Validate source exists
if [[ ! -d "$SOURCE" ]]; then
    log_msg "ERROR" "Source path does not exist: $SOURCE"
    exit 2
fi

# Create destination if it doesn't exist
if [[ ! -d "$DEST" ]]; then
    log_msg "INFO" "Creating destination directory: $DEST"
    if [[ $TEST_MODE -eq 1 ]]; then
        dbg "TEST_MODE: would create $DEST"
    else
        mkdir -p "$DEST" || {
            log_msg "ERROR" "Failed to create destination: $DEST"
            exit 3
        }
    fi
fi

# Helper function to find next available .orig number
get_next_backup_name() {
    local base_path="$1"
    local num=1
    while [[ -e "${base_path}.orig.${num}" ]]; do
        num=$((num + 1))
    done
    echo "${base_path}.orig.${num}"
}

# Counter for statistics
total=0
created=0
moved=0
recreated=0

# Process each folder in source
dbg "Scanning source directory: $SOURCE"
while IFS= read -r -d '' folder; do
    # Get folder name without path
    folder_name=$(basename "$folder")
    dest_path="$DEST/$folder_name"
    
    dbg "Processing: $folder_name"
    total=$((total + 1))
    
    # Check if dest already has this folder (as a real directory, not a softlink)
    if [[ -d "$dest_path" && ! -L "$dest_path" ]]; then
        # It's a real folder - move it to .orig.<num>
        backup_name=$(get_next_backup_name "$dest_path")
        log_msg "INFO" "Moving existing folder to backup: $folder_name -> $(basename "$backup_name")"
        if [[ $TEST_MODE -eq 1 ]]; then
            dbg "TEST_MODE: would move $dest_path to $backup_name"
        else
            mv "$dest_path" "$backup_name" || {
                log_msg "ERROR" "Failed to move existing folder: $folder_name"
                continue
            }
            moved=$((moved + 1))
        fi
    fi
    
    # Check if softlink already exists
    if [[ -L "$dest_path" ]]; then
        log_msg "INFO" "Recreating softlink: $folder_name"
        dbg "Removing existing softlink: $dest_path"
        if [[ $TEST_MODE -eq 1 ]]; then
            dbg "TEST_MODE: would remove $dest_path and create new link"
        else
            rm "$dest_path" || {
                log_msg "ERROR" "Failed to remove existing softlink: $folder_name"
                continue
            }
            ln -s "$folder" "$dest_path" || {
                log_msg "ERROR" "Failed to create softlink: $folder_name"
                continue
            }
            recreated=$((recreated + 1))
        fi
    elif [[ ! -e "$dest_path" ]]; then
        # Create new softlink
        log_msg "INFO" "Creating softlink: $folder_name"
        if [[ $TEST_MODE -eq 1 ]]; then
            dbg "TEST_MODE: would create softlink $dest_path -> $folder"
        else
            ln -s "$folder" "$dest_path" || {
                log_msg "ERROR" "Failed to create softlink: $folder_name"
                continue
            }
            created=$((created + 1))
        fi
    fi
done < <(find "$SOURCE" -maxdepth 1 -type d ! -name "$(basename "$SOURCE")" -print0)

# Summary
log_msg "INFO" "Summary: Total=$total, Created=$created, Moved=$moved, Recreated=$recreated"

if [[ $TEST_MODE -eq 1 ]]; then
    log_msg "INFO" "TEST_MODE: no changes were made"
    exit 0
fi

exit 0

