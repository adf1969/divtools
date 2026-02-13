#!/bin/bash
# fg_media_rev.sh - Script to investigate Frigate media folder (/opt/frigate/media), focusing on clips subfolder.
# Supports listing unique camera prefixes from snapshot filenames (*.jpg and *.png), with optional counts, sizes, oldest/newest dates.
# Last Updated: 9/26/2025 3:45:00 PM CDT

# Global Variables
DEFAULT_MEDIA_ROOT="/opt/frigate/media"
MEDIA_ROOT="$DEFAULT_MEDIA_ROOT"
CLIPS_DIR="${MEDIA_ROOT}/clips"
DEBUG_MODE=0
TEST_MODE=0
VERBOSE_MODE=0
CLIP_LS_MODE=0
WITH_COUNT=0
WITH_SIZE=0
WITH_OLDEST=0
WITH_NEWEST=0

# Import logging function
source "$DIVTOOLS/scripts/util/logging.sh" 2>/dev/null || {
    echo "ERROR: Could not source logging.sh from $DIVTOOLS/scripts/util/logging.sh" >&2
    exit 1
}

# Function: parse_arguments
# Parses command-line arguments for flags like -debug, -test, -v, -clip-ls, -count, -size, -oldest, -newest, -media <dir>.
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -debug)
                DEBUG_MODE=1
                shift
                ;;
            -test)
                TEST_MODE=1
                shift
                ;;
            -v)
                VERBOSE_MODE=1
                shift
                ;;
            -clip-ls)
                CLIP_LS_MODE=1
                shift
                ;;
            -count)
                WITH_COUNT=1
                shift
                ;;
            -size)
                WITH_SIZE=1
                shift
                ;;
            -oldest)
                WITH_OLDEST=1
                shift
                ;;
            -newest)
                WITH_NEWEST=1
                shift
                ;;
            -media)
                if [[ $# -lt 2 ]]; then
                    log "ERROR" "-media requires a directory argument"
                    show_usage
                    exit 1
                fi
                MEDIA_ROOT="$2"
                CLIPS_DIR="${MEDIA_ROOT}/clips"
                shift 2
                ;;
            *)
                log "ERROR" "Unknown argument: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    if [[ $DEBUG_MODE -eq 1 ]]; then
        log "DEBUG" "Parsed args: CLIP_LS_MODE=$CLIP_LS_MODE, WITH_COUNT=$WITH_COUNT, WITH_SIZE=$WITH_SIZE, WITH_OLDEST=$WITH_OLDEST, WITH_NEWEST=$WITH_NEWEST, MEDIA_ROOT=$MEDIA_ROOT, VERBOSE_MODE=$VERBOSE_MODE"
    fi
}

# Function: show_usage
# Displays usage information and exits.
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
  -clip-ls              List all unique camera prefixes from clips/*.jpg and *.png (sorted, 1 per line)
  -count                (with -clip-ls) Add file count per camera
  -size                 (with -clip-ls) Add total size (human-readable) per camera
  -oldest               (with -clip-ls) Add oldest file date per camera
  -newest               (with -clip-ls) Add newest file date per camera
  -media <dir>          Override default Frigate media root (default: /opt/frigate/media)
  -v                    Enable verbose progress output (shows current camera being processed)
  -debug                Enable debug output
  -test                 Dry-run mode (log actions without executing)

Examples:
  $0 -clip-ls                    # List unique cameras
  $0 -clip-ls -count             # Table with counts
  $0 -clip-ls -count -size       # Table with counts and sizes
  $0 -clip-ls -oldest -newest    # Table with oldest and newest dates
  $0 -clip-ls -media /custom/path  # Use custom media directory
EOF
}

# Function: validate_paths
# Checks if required directories exist; exits on error in non-test mode.
validate_paths() {
    if [[ ! -d "$CLIPS_DIR" ]]; then
        log "ERROR" "Clips directory not found: $CLIPS_DIR"
        exit 1
    fi

    if [[ $TEST_MODE -eq 1 ]]; then
        log "INFO:TEST" "Would validate paths (dry-run)."
    fi

    if [[ $DEBUG_MODE -eq 1 ]]; then
        log "DEBUG" "Validated paths: MEDIA_ROOT=$MEDIA_ROOT, CLIPS_DIR=$CLIPS_DIR"
        if [[ "$MEDIA_ROOT" != "$DEFAULT_MEDIA_ROOT" ]]; then
            log "DEBUG" "Media root overridden from default ($DEFAULT_MEDIA_ROOT) to $MEDIA_ROOT"
        fi
    fi
}

# Function: list_clip_prefixes
# Lists unique camera prefixes from clips/*.jpg and *.png filenames (prefix before first '-').
# Outputs sorted list, 1 per line; optionally with count/size/oldest/newest or in table format.
list_clip_prefixes() {
    if [[ $TEST_MODE -eq 1 ]]; then
        log "INFO:TEST" "Would list clip prefixes from $CLIPS_DIR/*.jpg and *.png (dry-run)."
        return 0
    fi

    # Extract unique prefixes (camera names before first '-'), sort them
    local prefixes=$(find "$CLIPS_DIR" -maxdepth 1 \( -name '*.jpg' -o -name '*.png' \) 2>/dev/null | sed 's|.*/||' | cut -d'-' -f1 | sort -u)

    if [[ -z "$prefixes" ]]; then
        log "WARN" "No .jpg or .png files found in $CLIPS_DIR"
        return 0
    fi

    local any_with=$(( WITH_COUNT + WITH_SIZE + WITH_OLDEST + WITH_NEWEST ))

    if [[ $any_with -eq 0 ]]; then
        # Simple list, 1 per line
        echo "$prefixes" | while read -r prefix; do
            log "INFO:raw" "$prefix"
        done
    else
        # Collect data for table (associative arrays for count/size/min_epoch/max_epoch per prefix)
        declare -A prefix_counts
        declare -A prefix_sizes
        declare -A prefix_min_epochs
        declare -A prefix_max_epochs

        # Loop over each unique prefix and process its files
        for prefix in $(echo "$prefixes"); do
            if [[ $VERBOSE_MODE -eq 1 ]]; then
                log "INFO" "Processing camera: $prefix"
            fi

            local count=0
            local total_size=0
            local min_epoch=$(date +%s)  # Current time as initial high value
            local max_epoch=0

            while IFS= read -r full_path; do
                ((count++))

                if [[ $WITH_SIZE -eq 1 ]]; then
                    local size=$(stat -c%s "$full_path" 2>/dev/null || echo "0")
                    ((total_size += size))
                fi

                if [[ $WITH_OLDEST -eq 1 || $WITH_NEWEST -eq 1 ]]; then
                    local epoch=$(stat -c%Y "$full_path" 2>/dev/null || echo "0")
                    if [[ $epoch -lt $min_epoch && $epoch -ne 0 ]]; then
                        min_epoch=$epoch
                    fi
                    if [[ $epoch -gt $max_epoch ]]; then
                        max_epoch=$epoch
                    fi
                fi
            done < <(find "$CLIPS_DIR" -maxdepth 1 \( -name "$prefix-*.jpg" -o -name "$prefix-*.png" \) 2>/dev/null)

            prefix_counts["$prefix"]=$count
            prefix_sizes["$prefix"]=$total_size
            prefix_min_epochs["$prefix"]=$min_epoch
            prefix_max_epochs["$prefix"]=$max_epoch
        done

        if [[ $DEBUG_MODE -eq 1 ]]; then
            log "DEBUG" "Collected data for ${#prefix_counts[@]} prefixes"
        fi

        # Build dynamic header and divider
        local header_format="%-30s"
        local header_values=("Camera")
        local divider_values=("------")

        if [[ $WITH_COUNT -eq 1 ]]; then
            header_format+=" %12s"
            header_values+=("Count")
            divider_values+=("-----")
        fi
        if [[ $WITH_SIZE -eq 1 ]]; then
            header_format+=" %12s"
            header_values+=("Size (Human)")
            divider_values+=("----------")
        fi
        if [[ $WITH_OLDEST -eq 1 ]]; then
            header_format+=" %20s"
            header_values+=("Oldest Date")
            divider_values+=("-----------")
        fi
        if [[ $WITH_NEWEST -eq 1 ]]; then
            header_format+=" %20s"
            header_values+=("Newest Date")
            divider_values+=("-----------")
        fi

        # Output header and divider
        printf "$header_format\n" "${header_values[@]}"
        printf "$header_format\n" "${divider_values[@]}"

        # Output sorted prefixes with data
        for prefix in $(printf "%s\n" "${!prefix_counts[@]}" | sort); do
            local count="${prefix_counts[$prefix]}"
            local total_bytes="${prefix_sizes[$prefix]}"
            local human_size=$(numfmt --to=iec-i --suffix=B --padding=12 "$total_bytes" 2>/dev/null || echo "${total_bytes}B")
            local min_epoch="${prefix_min_epochs[$prefix]}"
            local max_epoch="${prefix_max_epochs[$prefix]}"
            local oldest_date="N/A"
            local newest_date="N/A"

            if [[ $WITH_OLDEST -eq 1 && $min_epoch -ne $(date +%s) ]]; then
                oldest_date=$(date '+%Y-%m-%d %H:%M:%S' -d @"$min_epoch")
            fi
            if [[ $WITH_NEWEST -eq 1 && $max_epoch -ne 0 ]]; then
                newest_date=$(date '+%Y-%m-%d %H:%M:%S' -d @"$max_epoch")
            fi

            local output_values=("$prefix")
            if [[ $WITH_COUNT -eq 1 ]]; then output_values+=("$count"); fi
            if [[ $WITH_SIZE -eq 1 ]]; then output_values+=("$human_size"); fi
            if [[ $WITH_OLDEST -eq 1 ]]; then output_values+=("$oldest_date"); fi
            if [[ $WITH_NEWEST -eq 1 ]]; then output_values+=("$newest_date"); fi

            printf "$header_format\n" "${output_values[@]}"
        done
    fi

    if [[ $DEBUG_MODE -eq 1 ]]; then
        log "DEBUG" "Listed $(echo "$prefixes" | wc -l) unique prefixes"
    fi
}

# Main execution
main() {
    parse_arguments "$@"
    validate_paths

    if [[ $CLIP_LS_MODE -eq 0 ]]; then
        log "WARN" "No action specified. Use -clip-ls for clips investigation."
        show_usage
        exit 1
    fi

    local with_str=""
    [[ $WITH_COUNT -eq 1 ]] && with_str+="count "
    [[ $WITH_SIZE -eq 1 ]] && with_str+="size "
    [[ $WITH_OLDEST -eq 1 ]] && with_str+="oldest "
    [[ $WITH_NEWEST -eq 1 ]] && with_str+="newest "
    if [[ -n "$with_str" ]]; then
        log "INFO:raw" "Running clip-ls with ${with_str}"
    else
        log "INFO:raw" "Running clip-ls (simple list)"
    fi

    list_clip_prefixes
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi