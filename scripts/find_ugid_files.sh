#!/bin/bash

# Function to display usage
usage() {
    echo "Usage: $0 [-u <uids>] [-g <gids>] [-p <path>] [-l] [-x <exclude_paths>] [<trailing_path>]"
    echo "  -u <uids>           Comma-separated list of UIDs or usernames to search for."
    echo "  -g <gids>           Comma-separated list of GIDs or group names to search for."
    echo "  -p <path>           Path to start searching in. If not provided, a trailing argument is treated as the path."
    echo "  -l                  Constrain search to the local filesystem."
    echo "  -x <exclude_paths>  Comma-separated list of paths to exclude from the search."
    exit 1
}

# Initialize variables
UIDS=""
GIDS=""
START_PATH=""
CONSTRAIN_FS=false
EXCLUDE_PATHS=""

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -u)
            UIDS="$2"
            shift 2
            ;;
        -g)
            GIDS="$2"
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
        -x)
            EXCLUDE_PATHS="$2"
            shift 2
            ;;
        *)
            # Treat trailing argument as the path if -p is not specified
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

# Validate start path
if [ -z "$START_PATH" ]; then
    START_PATH="."
fi
if ! [ -d "$START_PATH" ]; then
    echo "Error: Invalid path '$START_PATH'"
    exit 1
fi
START_PATH=$(cd "$START_PATH" && pwd -P)

# Convert usernames to UIDs and group names to GIDs
convert_to_ids() {
    local input="$1"
    local type="$2"
    local ids=()
    IFS=',' read -ra items <<< "$input"
    for item in "${items[@]}"; do
        if [[ "$item" =~ ^[0-9]+$ ]]; then
            # Numeric input; treat as valid UID/GID
            ids+=("$item")
        else
            # Non-numeric input; resolve to UID/GID
            if [ "$type" == "user" ]; then
                id=$(getent passwd "$item" | cut -d: -f3 2>/dev/null)
            elif [ "$type" == "group" ]; then
                id=$(getent group "$item" | cut -d: -f3 2>/dev/null)
            fi
            if [ -n "$id" ]; then
                ids+=("$id")
            else
                echo "Warning: Invalid $type '$item' ignored." >&2
            fi
        fi
    done
    echo "${ids[@]}"
}

# Process UIDs and GIDs
if [ -n "$UIDS" ]; then
    UIDS=$(convert_to_ids "$UIDS" "user")
fi
if [ -n "$GIDS" ]; then
    GIDS=$(convert_to_ids "$GIDS" "group")
fi

# Build the find command
FIND_CMD="find '$START_PATH'"
CONDITIONS=""
EXCLUDE_CONDITIONS=""

if [ -n "$UIDS" ]; then
    for uid in $UIDS; do
        CONDITIONS="$CONDITIONS -user $uid -o"
    done
fi

if [ -n "$GIDS" ]; then
    for gid in $GIDS; do
        CONDITIONS="$CONDITIONS -group $gid -o"
    done
fi

# Remove trailing -o and append conditions to FIND_CMD
if [ -n "$CONDITIONS" ]; then
    CONDITIONS="${CONDITIONS::-3}" # Remove trailing -o
    FIND_CMD="$FIND_CMD \( $CONDITIONS \)"
else
    echo "Error: No valid UIDs or GIDs provided for filtering."
    exit 1
fi

# Add exclusion paths using -prune
if [ -n "$EXCLUDE_PATHS" ]; then
    IFS=',' read -ra EXCLUDES <<< "$EXCLUDE_PATHS"
    for path in "${EXCLUDES[@]}"; do
        EXCLUDE_CONDITIONS="$EXCLUDE_CONDITIONS -path '$path' -prune -o"
    done
    # Combine exclusions with the main conditions
    FIND_CMD="find '$START_PATH' \( $EXCLUDE_CONDITIONS \( $CONDITIONS \) \)"
else
    FIND_CMD="find '$START_PATH' \( $CONDITIONS \)"
fi


# Constrain to the local filesystem if -l is specified
if [ "$CONSTRAIN_FS" = true ]; then
    FIND_CMD="$FIND_CMD -xdev"
fi

# Debug and execute the find command
echo "Executing: $FIND_CMD"
sleep 2
eval "$FIND_CMD"
