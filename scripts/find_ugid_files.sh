#!/bin/bash

# V: 9/2/2025 10:02 PM
#
usage() {
    echo "Usage: $0 [-u <uids>] [-g <gids>] [-x <exclude_paths>] [-p <path>] [-l] [-q] [-ro] [-run] [-upshift] [-debug] [<trailing_path>]"
    echo "  -u <uids>   Comma-separated list or ranges of UIDs (e.g., 1000,1005-1010)."
    echo "  -g <gids>   Comma-separated list or ranges of GIDs (e.g., 1000,1005-1010)."
    echo "  -x <paths>  Comma-separated list of paths to exclude from search."
    echo "  -p <path>   Starting path for search."
    echo "  -l          Restrict search to local filesystem only."
    echo "  -q          Quiet mode: suppress find command error messages (e.g., Permission denied)."
    echo "  -ro         Include read-only filesystems (default: exclude proc, sysfs, devtmpfs, tmpfs)."
    echo "  -run        Include /run filesystem (default: exclude /run as tmpfs)."
    echo "  -upshift    Generate chgid.sh commands to upshift UIDs/GIDs by 100000."
    echo "  -debug      Enable debug output for troubleshooting."
    exit 1
}

UIDS=""
GIDS=""
EXCLUDE_PATHS=""
START_PATH=""
LOCAL_FS_ONLY=false
QUIET=false
INCLUDE_RO=false
INCLUDE_RUN=false
UPSHIFT=false
DEBUG=false

# Function to find the common prefix of a list of paths
get_common_prefix() {
    local paths=("$@")
    if [ ${#paths[@]} -eq 0 ]; then
        echo ""
        return
    fi
    local prefix="${paths[0]}"
    for path in "${paths[@]:1}"; do
        while [ -n "$prefix" ] && [[ ! "$path" =~ ^$prefix ]]; do
            prefix="${prefix%/*}"
        done
    done
    # Ensure prefix is a directory
    while [ -n "$prefix" ] && [ ! -d "$prefix" ]; do
        prefix="${prefix%/*}"
    done
    [ -z "$prefix" ] && prefix="/"
    echo "$prefix"
}

validate_ids() {
    local input="$1"
    local type="$2"
    local ids=()

    $DEBUG && echo "[DEBUG] Validating $type input: '$input'" >&2

    IFS=',' read -ra parts <<< "$input"
    for part in "${parts[@]}"; do
        $DEBUG && echo "[DEBUG] Processing $type part: '$part'" >&2
        if [[ "$part" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            start=${BASH_REMATCH[1]}
            end=${BASH_REMATCH[2]}
            $DEBUG && echo "[DEBUG] Range detected: start=$start, end=$end" >&2
            if (( start > end )); then
                echo "Warning: Invalid $type range '$part' ignored (start > end)." >&2
                continue
            fi
            if (( start >= 0 && end <= 4294967295 )); then
                ids+=("range:$start:$end")
                $DEBUG && echo "[DEBUG] Valid $type range added: $start-$end" >&2
            else
                echo "Warning: Invalid $type range '$part' ignored (out of valid range 0-4294967295)." >&2
            fi
        elif [[ "$part" =~ ^[0-9]+$ ]]; then
            if (( part >= 0 && part <= 4294967295 )); then
                ids+=("single:$part")
                $DEBUG && echo "[DEBUG] Valid $type single ID added: $part" >&2
            else
                echo "Warning: Invalid $type '$part' ignored (out of valid range 0-4294967295)." >&2
            fi
        else
            echo "Warning: Invalid $type '$part' ignored." >&2
            $DEBUG && echo "[DEBUG] $type '$part' is not numeric or a valid range." >&2
        fi
    done

    if [ "${#ids[@]}" -eq 0 ]; then
        $DEBUG && echo "[DEBUG] No valid $type IDs after validation." >&2
        echo ""
    else
        $DEBUG && echo "[DEBUG] Validated $type IDs: ${ids[*]}" >&2
        echo "${ids[*]}"
    fi
}

# Argument parsing
while [[ $# -gt 0 ]]; do
    case "$1" in
        -u)
            UIDS=$(validate_ids "$2" "user")
            $DEBUG && echo "[DEBUG] UIDS after validation: '$UIDS'" >&2
            shift 2
            ;;
        -g)
            GIDS=$(validate_ids "$2" "group")
            $DEBUG && echo "[DEBUG] GIDS after validation: '$GIDS'" >&2
            shift 2
            ;;
        -x)
            EXCLUDE_PATHS="$2"
            $DEBUG && echo "[DEBUG] Exclude paths: '$EXCLUDE_PATHS'" >&2
            shift 2
            ;;
        -p)
            START_PATH="$2"
            $DEBUG && echo "[DEBUG] Start path: '$START_PATH'" >&2
            shift 2
            ;;
        -l)
            LOCAL_FS_ONLY=true
            $DEBUG && echo "[DEBUG] Local filesystem only: true" >&2
            shift
            ;;
        -q)
            QUIET=true
            $DEBUG && echo "[DEBUG] Quiet mode enabled" >&2
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
        -upshift)
            UPSHIFT=true
            $DEBUG && echo "[DEBUG] Upshift mode enabled" >&2
            shift
            ;;
        -debug)
            DEBUG=true
            $DEBUG && echo "[DEBUG] Debug mode enabled" >&2
            shift
            ;;
        -*)
            echo "Error: Unknown option $1"
            usage
            ;;
        *)
            [ -z "$START_PATH" ] && START_PATH="$1"
            $DEBUG && echo "[DEBUG] Trailing start path: '$START_PATH'" >&2
            shift
            ;;
    esac
done

[ -z "$START_PATH" ] && START_PATH="."
$DEBUG && echo "[DEBUG] Final start path: '$START_PATH'" >&2
[ ! -d "$START_PATH" ] && { echo "Error: Invalid path '$START_PATH'"; exit 1; }
START_PATH=$(cd "$START_PATH" && pwd -P)
$DEBUG && echo "[DEBUG] Resolved start path: '$START_PATH'" >&2

# Start building find command
FIND_CMD=(find "$START_PATH")
$DEBUG && echo "[DEBUG] Base find command: ${FIND_CMD[*]}" >&2

$LOCAL_FS_ONLY && FIND_CMD+=(-xdev)
$DEBUG && $LOCAL_FS_ONLY && echo "[DEBUG] Added -xdev for local filesystem restriction" >&2

# Build expression for exclusions
EXPRESSION=()
if ! $INCLUDE_RO; then
    EXPRESSION+=("!" "(" -fstype proc -o -fstype sysfs -o -fstype devtmpfs -o -fstype tmpfs ")")
    $DEBUG && echo "[DEBUG] Excluding read-only filesystems: proc, sysfs, devtmpfs, tmpfs" >&2
fi

# Exclude /run and user-specified paths unless -run or -ro is specified
if ! $INCLUDE_RO && ! $INCLUDE_RUN; then
    run_path=$(realpath /run 2>/dev/null || echo /run)
    EXPRESSION+=("!" -path "$run_path/*")
    $DEBUG && echo "[DEBUG] Excluding /run filesystem at: $run_path" >&2
fi

if [ -n "$EXCLUDE_PATHS" ]; then
    IFS=',' read -ra PRUNES <<< "$EXCLUDE_PATHS"
    for path in "${PRUNES[@]}"; do
        [ -d "$path" ] || { $DEBUG && echo "[DEBUG] Exclude path '$path' is not a directory, skipping" >&2; continue; }
        abs_path=$(cd "$path" && pwd -P 2>/dev/null) || { $DEBUG && echo "[DEBUG] Exclude path '$path' inaccessible, skipping" >&2; continue; }
        EXPRESSION+=("!" -path "$abs_path/*")
        $DEBUG && echo "[DEBUG] Excluding path: '$abs_path'" >&2
    done
fi

# Build awk filter for UID/GID ranges
AWK_EXPR=""
if [ -n "$UIDS" ]; then
    IFS=' ' read -ra uid_list <<< "$UIDS"
    $DEBUG && echo "[DEBUG] UID list for matching: ${uid_list[*]}" >&2
    for uid in "${uid_list[@]}"; do
        if [[ "$uid" =~ ^range:([0-9]+):([0-9]+)$ ]]; then
            start=${BASH_REMATCH[1]}
            end=${BASH_REMATCH[2]}
            AWK_EXPR+=" \$1 >= $start && \$1 <= $end ||"
            $DEBUG && echo "[DEBUG] Added UID range filter: \$1 >= $start && \$1 <= $end" >&2
        elif [[ "$uid" =~ ^single:([0-9]+)$ ]]; then
            AWK_EXPR+=" \$1 == ${BASH_REMATCH[1]} ||"
            $DEBUG && echo "[DEBUG] Added single UID filter: \$1 == ${BASH_REMATCH[1]}" >&2
        fi
    done
fi
if [ -n "$GIDS" ]; then
    IFS=' ' read -ra gid_list <<< "$GIDS"
    $DEBUG && echo "[DEBUG] GID list for matching: ${gid_list[*]}" >&2
    for gid in "${gid_list[@]}"; do
        if [[ "$gid" =~ ^range:([0-9]+):([0-9]+)$ ]]; then
            start=${BASH_REMATCH[1]}
            end=${BASH_REMATCH[2]}
            AWK_EXPR+=" \$2 >= $start && \$2 <= $end ||"
            $DEBUG && echo "[DEBUG] Added GID range filter: \$2 >= $start && \$2 <= $end" >&2
        elif [[ "$gid" =~ ^single:([0-9]+)$ ]]; then
            AWK_EXPR+=" \$2 == ${BASH_REMATCH[1]} ||"
            $DEBUG && echo "[DEBUG] Added single GID filter: \$2 == ${BASH_REMATCH[1]}" >&2
        fi
    done
fi

if [ -z "$AWK_EXPR" ]; then
    echo "Error: No valid UIDs or GIDs provided for filtering."
    $DEBUG && echo "[DEBUG] AWK_EXPR is empty, exiting" >&2
    exit 1
fi

AWK_EXPR="${AWK_EXPR::-2}"  # Remove trailing ||
$DEBUG && echo "[DEBUG] Final awk expression: '$AWK_EXPR'" >&2

# Build awk command with upshift support
if $UPSHIFT; then
    AWK_CMD=(awk -F: "$AWK_EXPR {print \$1 \":\" \$2 \":\" \$3 \":\" \$4 \":\" \$5; paths[\$1 \":\" \$2][length(paths[\$1 \":\" \$2])] = \$5} END {for (key in paths) {split(key, ids, \":\"); printf \"chgid.sh -fid %d -tid %d -fgid %d -tgid %d %s\n\", ids[1], ids[1]+100000, ids[2], ids[2]+100000, paths[key][0]}}")
else
    AWK_CMD=(awk -F: "$AWK_EXPR {print \$1 \" \" \$2 \" \" \$3 \" \" \$4 \" \" \$5}")
fi
$DEBUG && echo "[DEBUG] Awk command: ${AWK_CMD[*]}" >&2

# Combine all expressions with AND
if [ ${#EXPRESSION[@]} -gt 0 ]; then
    FIND_CMD+=("(" "${EXPRESSION[@]}" -a -printf '%U:%G:%u:%g:%p\n' ")")
else
    FIND_CMD+=(-printf '%U:%G:%u:%g:%p\n')
fi
$DEBUG && echo "[DEBUG] Final find command: ${FIND_CMD[*]}" >&2

# Run the command
if $QUIET; then
    echo "Executing: ${FIND_CMD[*]} | ${AWK_CMD[*]} (quiet mode)"
    if $UPSHIFT; then
        echo "Found matches, run the following chgid to upshift the values:"
        "${FIND_CMD[@]}" 2>/dev/null | "${AWK_CMD[@]}" | tee /dev/stderr | grep '^chgid.sh' > /tmp/chgid.sh
        chmod +x /tmp/chgid.sh
        $DEBUG && echo "[DEBUG] Generated chgid.sh commands saved to /tmp/chgid.sh" >&2
    else
        "${FIND_CMD[@]}" 2>/dev/null | "${AWK_CMD[@]}"
    fi
else
    echo "Executing: ${FIND_CMD[*]} | ${AWK_CMD[*]}"
    if $UPSHIFT; then
        echo "Found matches, run the following chgid to upshift the values:"
        "${FIND_CMD[@]}" | "${AWK_CMD[@]}" | tee /dev/stderr | grep '^chgid.sh' > /tmp/chgid.sh
        chmod +x /tmp/chgid.sh
        $DEBUG && echo "[DEBUG] Generated chgid.sh commands saved to /tmp/chgid.sh" >&2
    else
        "${FIND_CMD[@]}" | "${AWK_CMD[@]}"
    fi
fi

# Post-process upshift commands to find common root paths
if $UPSHIFT; then
    declare -A path_map
    while IFS=: read -r uid gid user group path; do
        key="$uid:$gid"
        path_map["$key"]+="$path "
    done < <("${FIND_CMD[@]}" 2>/dev/null | awk -F: "$AWK_EXPR {print \$1 \":\" \$2 \":\" \$3 \":\" \$4 \":\" \$5}")

    $DEBUG && echo "[DEBUG] Processing upshift paths for common prefixes" >&2
    echo "Found matches, run the following chgid to upshift the values:"
    for key in "${!path_map[@]}"; do
        IFS=' ' read -ra paths <<< "${path_map[$key]}"
        common_prefix=$(get_common_prefix "${paths[@]}")
        IFS=':' read -r uid gid <<< "$key"
        $DEBUG && echo "[DEBUG] UID:GID=$key, Common prefix=$common_prefix" >&2
        printf "chgid.sh -fid %d -tid %d -fgid %d -tgid %d %s\n" "$uid" "$((uid+100000))" "$gid" "$((gid+100000))" "$common_prefix"
    done | sort -u > /tmp/chgid.sh
    chmod +x /tmp/chgid.sh
    cat /tmp/chgid.sh
fi