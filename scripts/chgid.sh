#!/bin/bash

# Function to display usage
usage() {
    echo "Usage: $0 -fid <FROM_ID> -tid <TO_ID> [-fgid <FROM_GID>] [-tgid <TO_GID>] [-p <START_PATH>] [-l] [-y]"
    echo "  -fid <FROM_ID>      The current user ID to search or replace."
    echo "  -tid <TO_ID>        The new user ID to assign."
    echo "  -fgid <FROM_GID>    The current group ID to search or replace."
    echo "  -tgid <TO_GID>      The new group ID to assign."
    echo "  -p <START_PATH>     The starting path to search for files (optional)."
    echo "  -l                  Constrain the search to the current filesystem."
    echo "  -y                  Assume 'yes' to all confirmation prompts."
    echo "  If no -p is provided, a trailing argument is treated as the path."
    echo "  If no path is provided, defaults to the current directory."
    exit 1
} # usage

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
LOG_DIR="/opt/chgid"

# Parse named arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -fid)
            FROM_ID="$2"
            shift 2
            ;;
        -tid)
            TO_ID="$2"
            shift 2
            ;;
        -fgid)
            FROM_GID="$2"
            shift 2
            ;;
        -tgid)
            TO_GID="$2"
            shift 2
            ;;
        -p)
            START_PATH="$2"
            shift 2
            ;;
        -l)
            CONSTRAIN_FS=true
            shift
            ;;
        -y)
            ASSUME_YES=true
            shift
            ;;
        *)
            # Treat trailing argument as START_PATH if -p was not used
            if [ -z "$START_PATH" ]; then
                START_PATH="$1"
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
} # get_name_by_id

FROM_USER_NAME=$(get_name_by_id "user" "$FROM_ID")
TO_USER_NAME=$(get_name_by_id "user" "$TO_ID")
FROM_GROUP_NAME=$(get_name_by_id "group" "$FROM_GID")
TO_GROUP_NAME=$(get_name_by_id "group" "$TO_GID")

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

# Create the log directory if it doesn't exist
mkdir -p "$LOG_DIR" || { echo "Error: Unable to create log directory $LOG_DIR"; exit 1; }

# Prepare log file header
{
    echo "# Change Log"
    echo "# From ID: ${FROM_ID:-N/A}, ${FROM_USER_NAME:-N/A}"
    echo "# To ID: ${TO_ID:-N/A}, ${TO_USER_NAME:-N/A}"
    echo "# From GID: ${FROM_GID:-N/A}, ${FROM_GROUP_NAME:-N/A}"
    echo "# To GID: ${TO_GID:-N/A}, ${TO_GROUP_NAME:-N/A}"
    echo "# Starting Path: $START_PATH"
    echo "# Constrain Filesystem: $CONSTRAIN_FS"
    echo "# Date: $(date)"
    echo "#"
    echo "# Changed Files:"
} > "$LOG_FILE"

# Construct find command for all files
# The find below is NOT redundant. find looks at the link TARGET OWNER when -user
# is specified. By looking for -type l -user <UID>, that looks at the link.
FIND_CMD="find '$START_PATH'"
[ "$CONSTRAIN_FS" = true ] && FIND_CMD="$FIND_CMD -xdev" # Constrain to filesystem
if [ -n "$FROM_ID" ]; then
    FIND_CMD="$FIND_CMD \( -type l -user $FROM_ID -o ! -type l -user $FROM_ID \)"
fi
if [ -n "$FROM_GID" ]; then
    FIND_CMD="$FIND_CMD \( -type l -group $FROM_GID -o ! -type l -group $FROM_GID \)"
fi

# Execute find and process files
echo "Executing: $FIND_CMD -print0"
eval "$FIND_CMD -print0" | while IFS= read -r -d '' file; do
    if [ -n "$TO_ID" ] || [ -n "$TO_GID" ]; then
        CHOWN_CMD="chown"
        [ -h "$file" ] && CHOWN_CMD="chown -h" # Use -h for symbolic links

        if [ -n "$TO_ID" ] && [ -n "$TO_GID" ]; then
            CHOWN_CMD="$CHOWN_CMD $TO_ID:$TO_GID"
        elif [ -n "$TO_ID" ]; then
            CHOWN_CMD="$CHOWN_CMD $TO_ID"
        elif [ -n "$TO_GID" ]; then
            CHOWN_CMD="$CHOWN_CMD :$TO_GID"
        fi

        echo "Executing: $CHOWN_CMD '$file'"
        eval "$CHOWN_CMD '$file'" && echo "$file" >> "$LOG_FILE"
    fi
done

echo "Log saved to $LOG_FILE"
echo "Done."
exit 0
