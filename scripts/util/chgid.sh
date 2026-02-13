#!/bin/bash

# V: 9/2/2025 10:18 PM
#
# PURPOSE: Recursively change the ownership (UID/GID) of files and directories
# that match a given list of UIDs/GIDs (numeric), with support for single values.
# Optionally excludes specific paths and read-only filesystems (/proc, /sysfs, /devtmpfs, /tmpfs, /run, /sys/devices/system/cpu) unless specified.

# Function to display usage
usage() {
    echo "Usage: $0 -fid <FROM_ID> -tid <TO_ID> [-fgid <FROM_GID>] [-tgid <TO_GID>] [-p <START_PATH>] [-l] [-y] [-ro] [-run] [-t] [-debug]"
    echo "  -fid <FROM_ID>      The current user ID to search or replace."
    echo "  -tid <TO_ID>        The new user ID to assign."
    echo "  -fgid <FROM_GID>    The current group ID to search or replace."
    echo "  -tgid <TO_GID>      The new group ID to assign."
    echo "  -p <START_PATH>     The starting path to search for files (optional)."
    echo "  -l                  Constrain the search to the current filesystem."
    echo "  -y                  Assume 'yes' to all confirmation prompts."
    echo "  -ro                 Include read-only filesystems (default: exclude proc, sysfs, devtmpfs, tmpfs, /sys/devices/system/cpu)."
    echo "  -run                Include /run filesystem (default: exclude /run as tmpfs)."
    echo "  -t                  Test mode: print find command without executing."
    echo "  -debug              Enable debug output for troubleshooting."
    echo "  If no -p is provided, a trailing argument is treated as the path."
    echo "  If no path is provided, defaults to the current directory."
    exit 1
}

# Check for root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root."
    exit 1
fi

# Initialize variables
FROM_ID=""
TO_ID=""
FROM_GID=""
TO_GID=""
START_PATH=""
CONSTRAIN_FS=false
ASSUME_YES=false
INCLUDE_RO=false
INCLUDE_RUN=false
TEST_MODE=false
DEBUG=false
LOG_DIR="/opt/chgid"

# Parse named arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -fid)
            FROM_ID="$2"
            $DEBUG && echo "[DEBUG] FROM_ID: '$FROM_ID'" >&2
            shift 2
            ;;
        -tid)
            TO_ID="$2"
            $DEBUG && echo "[DEBUG] TO_ID: '$TO_ID'" >&2
            shift 2
            ;;
        -fgid)
            FROM_GID="$2"
            $DEBUG && echo "[DEBUG] FROM_GID: '$FROM_GID'" >&2
            shift 2
            ;;
        -tgid)
            TO_GID="$2"
            $DEBUG && echo "[DEBUG] TO_GID: '$TO_GID'" >&2
            shift 2
            ;;
        -p)
            START_PATH="$2"
            $DEBUG && echo "[DEBUG] START_PATH: '$START_PATH'" >&2
            shift 2
            ;;
        -l)
            CONSTRAIN_FS=true
            $DEBUG && echo "[DEBUG] Constrain filesystem: true" >&2
            shift
            ;;
        -y)
            ASSUME_YES=true
            $DEBUG && echo "[DEBUG] Assume yes: true" >&2
            shift
            ;;
        -ro)
            INCLUDE_RO=true
            $DEBUG && echo "[DEBUG] Include read-only filesystems: true" >&2
            shift
            ;;
        -run)
            INCLUDE_RUN=true
            $DEBUG && echo "[DEBUG] Include /run filesystem: true" >&2
            shift
            ;;
        -t)
            TEST_MODE=true
            $DEBUG && echo "[DEBUG] Test mode enabled" >&2
            shift
            ;;
        -debug)
            DEBUG=true
            $DEBUG && echo "[DEBUG] Debug mode enabled" >&2
            shift
            ;;
        *)
            # Treat trailing argument as START_PATH if -p was not used
            if [ -z "$START_PATH" ]; then
                START_PATH="$1"
                $DEBUG && echo "[DEBUG] Trailing start path: '$START_PATH'" >&2
            else
                echo "Error: Unknown argument '$1'"
                usage
            fi
            shift
            ;;
    esac
done

# Default to the current directory if no starting path is provided
if [ -z "$START_PATH" ]; then
    START_PATH="."
    $DEBUG && echo "[DEBUG] No path provided, defaulting to: '$START_PATH'" >&2
    if [ "$ASSUME_YES" = false ]; then
        read -p "No path provided. Use the current directory ($START_PATH)? [y/N] " confirm
        [[ "$confirm" =~ ^[Yy]$ ]] || exit 1
    fi
fi

# Resolve the absolute path for the starting path using pwd -P
if ! cd "$START_PATH" 2>/dev/null; then
    echo "Error: Invalid starting path provided."
    exit 1
fi
START_PATH=$(pwd -P)
$DEBUG && echo "[DEBUG] Resolved start path: '$START_PATH'" >&2

# Validate that at least one ID is provided
if [[ -z "$FROM_ID" && -z "$TO_ID" && -z "$FROM_GID" && -z "$TO_GID" ]]; then
    echo "Error: At least one of -fid, -tid, -fgid, or -tgid must be provided."
    usage
fi

# Get user/group names for logging
get_name_by_id() {
    local id_type=$1
    local id_value=$2
    if [ "$id_type" == "user" ]; then
        getent passwd "$id_value" | cut -d: -f1 2>/dev/null || echo "unknown"
    elif [ "$id_type" == "group" ]; then
        getent group "$id_value" | cut -d: -f1 2>/dev/null || echo "unknown"
    fi
}

FROM_USER_NAME=$(get_name_by_id "user" "$FROM_ID")
TO_USER_NAME=$(get_name_by_id "user" "$TO_ID")
FROM_GROUP_NAME=$(get_name_by_id "group" "$FROM_GID")
TO_GROUP_NAME=$(get_name_by_id "group" "$TO_GID")
$DEBUG && echo "[DEBUG] FROM_USER_NAME: '$FROM_USER_NAME', TO_USER_NAME: '$TO_USER_NAME'" >&2
$DEBUG && echo "[DEBUG] FROM_GROUP_NAME: '$FROM_GROUP_NAME', TO_GROUP_NAME: '$TO_GROUP_NAME'" >&2

# Generate dynamic log file name components
DATE=$(date +%Y%m%d)
LOG_FILE_PREFIX="chgid"
if [ -n "$FROM_ID" ]; then
    LOG_FILE_PREFIX="${LOG_FILE_PREFIX}-${FROM_ID}"
fi
if [ -n "$FROM_GID" ]; then
    LOG_FILE_PREFIX="${LOG_FILE_PREFIX}-${FROM_GID}g"
fi
if [ -n "$TO_ID" ]; then
    LOG_FILE_PREFIX="${LOG_FILE_PREFIX}-${TO_ID}"
fi
if [ -n "$TO_GID" ]; then
    LOG_FILE_PREFIX="${LOG_FILE_PREFIX}-${TO_GID}g"
fi
LOG_FILE_PREFIX="${LOG_FILE_PREFIX}-${DATE}"

# Generate unique log file name
LOG_FILE="$LOG_DIR/${LOG_FILE_PREFIX}.txt"
COUNTER=1
while [ -e "$LOG_FILE" ]; do
    LOG_FILE="$LOG_DIR/${LOG_FILE_PREFIX}-$(printf '%02d' "$COUNTER").txt"
    COUNTER=$((COUNTER + 1))
done
$DEBUG && echo "[DEBUG] Log file: '$LOG_FILE'" >&2

# Create the log directory if it doesn't exist
mkdir -p "$LOG_DIR" || { echo "Error: Unable to create log directory $LOG_DIR"; exit 1; }
$DEBUG && echo "[DEBUG] Created log directory: '$LOG_DIR'" >&2

# Prepare log file header
{
    echo "# Change Log"
    echo "# From ID: ${FROM_ID:-N/A}, ${FROM_USER_NAME:-N/A}"
    echo "# To ID: ${TO_ID:-N/A}, ${TO_USER_NAME:-N/A}"
    echo "# From GID: ${FROM_GID:-N/A}, ${FROM_GROUP_NAME:-N/A}"
    echo "# To GID: ${TO_GID:-N/A}, ${TO_GROUP_NAME:-N/A}"
    echo "# Starting Path: $START_PATH"
    echo "# Constrain Filesystem: $CONSTRAIN_FS"
    echo "# Include Read-Only Filesystems: $INCLUDE_RO"
    echo "# Include /run Filesystem: $INCLUDE_RUN"
    echo "# Test Mode: $TEST_MODE"
    echo "# Date: $(date)"
    echo "#"
    echo "# Changed Files:"
} > "$LOG_FILE"
$DEBUG && echo "[DEBUG] Log file header written" >&2

# Construct find command
FIND_CMD=(find "$START_PATH")
$DEBUG && echo "[DEBUG] Base find command: ${FIND_CMD[*]}" >&2

$CONSTRAIN_FS && FIND_CMD+=(-xdev)
$DEBUG && $CONSTRAIN_FS && echo "[DEBUG] Added -xdev for filesystem constraint" >&2

# Exclude read-only filesystems unless -ro is specified
if ! $INCLUDE_RO; then
    FIND_CMD+=("!" "(" -fstype proc -o -fstype sysfs -o -fstype devtmpfs -o -fstype tmpfs ")")
    $DEBUG && echo "[DEBUG] Excluding read-only filesystems: proc, sysfs, devtmpfs, tmpfs" >&2
fi

# Exclude /run and /sys/devices/system/cpu unless -ro or -run is specified
if ! $INCLUDE_RO && ! $INCLUDE_RUN; then
    run_path=$(realpath /run 2>/dev/null || echo /run)
    FIND_CMD+=("!" -path "$run_path/*")
    $DEBUG && echo "[DEBUG] Excluding /run filesystem at: $run_path" >&2
fi
if ! $INCLUDE_RO; then
    cpu_path="/sys/devices/system/cpu"
    FIND_CMD+=("!" -path "$cpu_path/*")
    $DEBUG && echo "[DEBUG] Excluding /sys/devices/system/cpu at: $cpu_path" >&2
fi

# Add user and group filters
if [ -n "$FROM_ID" ]; then
    FIND_CMD+=("(" -type l -user "$FROM_ID" -o ! -type l -user "$FROM_ID" ")")
    $DEBUG && echo "[DEBUG] Added user filter: -user $FROM_ID" >&2
fi
if [ -n "$FROM_GID" ]; then
    FIND_CMD+=("(" -type l -group "$FROM_GID" -o ! -type l -group "$FROM_GID" ")")
    $DEBUG && echo "[DEBUG] Added group filter: -group $FROM_GID" >&2
fi

# Add -print0 to FIND_CMD
FIND_CMD+=(-print0)
$DEBUG && echo "[DEBUG] Final find command: ${FIND_CMD[*]}" >&2

# Test mode: print command and exit
if $TEST_MODE; then
    echo "Test mode: ${FIND_CMD[*]}"
    exit 0
fi

# Execute find and process files
echo "Executing: ${FIND_CMD[*]}"
if $INCLUDE_RO; then
    echo "Note: Including read-only filesystems (proc, sysfs, devtmpfs, tmpfs, /sys/devices/system/cpu)"
elif $INCLUDE_RUN; then
    echo "Note: Including /run filesystem"
fi

"${FIND_CMD[@]}" | while IFS= read -r -d '' file; do
    if [ -n "$TO_ID" ] || [ -n "$TO_GID" ]; then
        CHOWN_CMD=(chown)
        [ -h "$file" ] && CHOWN_CMD+=(-h)
        $DEBUG && [ -h "$file" ] && echo "[DEBUG] Using chown -h for symlink: $file" >&2

        if [ -n "$TO_ID" ] && [ -n "$TO_GID" ]; then
            CHOWN_CMD+=("$TO_ID:$TO_GID")
        elif [ -n "$TO_ID" ]; then
            CHOWN_CMD+=("$TO_ID")
        elif [ -n "$TO_GID" ]; then
            CHOWN_CMD+=(":$TO_GID")
        fi
        CHOWN_CMD+=("$file")

        $DEBUG && echo "[DEBUG] Executing: ${CHOWN_CMD[*]}" >&2
        echo "Executing: ${CHOWN_CMD[*]}"
        "${CHOWN_CMD[@]}" && echo "$file" >> "$LOG_FILE"
    fi
done

echo "Log saved to $LOG_FILE"
echo "Done."
exit 0