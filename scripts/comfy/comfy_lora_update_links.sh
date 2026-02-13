#!/usr/bin/env bash
# update-lora-links.sh
# Creates a flat symlink directory for ComfyUI LoRA discovery
# without flattening or renaming the original files.
# Last Updated: 02/07/2026 10:28:18 AM CST

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../util/logging.sh"

# Note: Removing 'set -euo pipefail' to allow graceful handling of missing directories

# ================= CONFIG =================
SOURCE_ROOT="/opt/comfy/models/loras/organized"          # ← root of your real hierarchy
LINKS_FOLDER="/opt/comfy/models/loras/links"             # ← flat symlink container (will be created if missing)
EXTENSIONS=("safetensors" "gguf" "ckpt")                 # file extensions to consider (lowercase)
CLEANUP_DEAD=true                                        # remove broken symlinks? (true/false)
VERBOSE=true                                             # print every link action
# ==========================================

# Default flags
TEST_MODE=0
DEBUG_MODE=0
SHOW_DUPES=0
ADD_PATH_PREFIX=0
REBUILD_MODE=0
PREFIX_DEPTH=""  # empty = full path, positive = head N levels, negative = tail N levels
LINK_PREFIX=""   # optional static prefix added to every link

# Function to display usage
show_usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] [SOURCE_DIR] [LINKS_DIR]

Creates a flat symlink directory for ComfyUI LoRA discovery without flattening the original files.

ARGUMENTS:
    SOURCE_DIR      Source lora directory to scan (default: $SOURCE_ROOT)
    LINKS_DIR       Destination directory for symlinks (default: $LINKS_FOLDER)

OPTIONS:
    -d, --debug              Enable debug output
    -t, --test               Test mode - simulate operations without making changes
    -r, --rebuild, -rebuild  Rebuild mode - remove ALL existing symlinks first, then rebuild
                             This allows *.json settings files to stay intact while links are refreshed
    -sd, --show-dupes        Show only duplicate files found (conflicts)
    -app, --add-path-prefix  Add path prefix to symlink names (optional depth)
                             Depth: positive=head levels, negative=tail levels
    --link-prefix <name>     Add a static prefix to all symlink names
    -u, --usage              Show this help message

EXAMPLES:
    $(basename "$0")                                    # Use default directories
    $(basename "$0") -d /path/to/loras /path/to/links    # Debug mode with custom paths
    $(basename "$0") -t /opt/loras ./links               # Test mode
    $(basename "$0") --usage                             # Show help

CONFIGURATION:
    Edit the CONFIG section at the top of this script to change defaults:
    - SOURCE_ROOT: Default source directory
    - LINKS_FOLDER: Default links directory
    - EXTENSIONS: File extensions to process
    - CLEANUP_DEAD: Remove broken symlinks
    - VERBOSE: Print every link action

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|-test|--test)
            TEST_MODE=1
            log "INFO" "Running in TEST mode - no changes will be made"
            shift
            ;;
        -d|-debug|--debug)
            DEBUG_MODE=1
            export DEBUG_MODE
            log "DEBUG" "Debug mode enabled"
            shift
            ;;
        -r|-rebuild|--rebuild)
            REBUILD_MODE=1
            log "INFO" "Running in REBUILD mode - will remove all existing symlinks first"
            shift
            ;;
        -sd|-show-dupes|--show-dupes)
            SHOW_DUPES=1
            log "INFO" "Showing duplicates only"
            shift
            ;;
        -app|-add-path-prefix|--add-path-prefix)
            ADD_PATH_PREFIX=1
            shift
            # Check if next argument is a number (depth)
            if [[ $# -gt 0 && "$1" =~ ^-?[0-9]+$ ]]; then
                PREFIX_DEPTH="$1"
                log "INFO" "Adding path prefix with depth: $PREFIX_DEPTH"
                shift
            else
                log "INFO" "Adding path prefix with full path depth"
            fi
            ;;
        --link-prefix|-lp)
            if [[ $# -lt 2 ]]; then
                log "ERROR" "--link-prefix requires an argument"
                show_usage
                exit 1
            fi
            shift
            LINK_PREFIX="$1"
            log "INFO" "Setting link prefix: $LINK_PREFIX"
            shift
            ;;
        -u|-usage|--usage)
            show_usage
            exit 0
            ;;
        -*)
            log "ERROR" "Unknown option: $1"
            show_usage
            exit 1
            ;;
        *)
            # Positional arguments
            if [[ -z "${SOURCE_ARG:-}" ]]; then
                SOURCE_ARG="$1"
            elif [[ -z "${LINKS_ARG:-}" ]]; then
                LINKS_ARG="$1"
            else
                log "ERROR" "Too many arguments. Expected at most 2 positional arguments."
                show_usage
                exit 1
            fi
            shift
            ;;
    esac
done

# Override defaults with arguments if provided
[[ -n "${SOURCE_ARG:-}" ]] && SOURCE_ROOT="$SOURCE_ARG"
[[ -n "${LINKS_ARG:-}" ]] && LINKS_FOLDER="$LINKS_ARG"

# Validate directories
if [[ ! -d "$SOURCE_ROOT" ]]; then
    log "ERROR" "Source directory does not exist: $SOURCE_ROOT"
    exit 1
fi

log "INFO" "Script execution started"
log "DEBUG" "TEST_MODE=$TEST_MODE, DEBUG_MODE=$DEBUG_MODE, REBUILD_MODE=$REBUILD_MODE, SHOW_DUPES=$SHOW_DUPES, ADD_PATH_PREFIX=$ADD_PATH_PREFIX, PREFIX_DEPTH=$PREFIX_DEPTH, LINK_PREFIX=$LINK_PREFIX"
log "DEBUG" "SOURCE_ROOT=$SOURCE_ROOT, LINKS_FOLDER=$LINKS_FOLDER"

# Create links folder if it doesn't exist
if [[ $TEST_MODE -eq 0 ]]; then
    mkdir -p "$LINKS_FOLDER"
else
    log "INFO" "TEST MODE: Would create directory: $LINKS_FOLDER"
fi

created=0
skipped=0
removed=0

# ──────────────────────────────────────────
# Function to generate prefixed symlink name
# ──────────────────────────────────────────
generate_link_name() {
    local src_file="$1"
    local source_root="$2"
    local add_prefix="$3"
    local prefix_depth="$4"
    local link_prefix="$5"
    
    local filename
    filename=$(basename "$src_file")
    
    # Start with filename
    local result="$filename"
    
    if [[ $add_prefix -eq 1 ]]; then
        # Get relative path from source root to the file's parent directory
        local file_dir
        file_dir=$(dirname "$src_file")
        local relative_path
        relative_path=$(python3 -c "import os.path; print(os.path.relpath('$file_dir', '$source_root'))" 2>/dev/null) || return 1
        
        # If relative_path is NOT ".", add path prefix
        if [[ "$relative_path" != "." ]]; then
            # Split relative path into array
            IFS='/' read -ra path_parts <<< "$relative_path"
            local selected_parts=()
            
            if [[ -z "$prefix_depth" ]]; then
                # No depth specified: use all parts
                selected_parts=("${path_parts[@]}")
            elif [[ $prefix_depth -ge 0 ]]; then
                # Positive depth: take first N parts
                for ((i=0; i<prefix_depth && i<${#path_parts[@]}; i++)); do
                    selected_parts+=("${path_parts[$i]}")
                done
            else
                # Negative depth: take last N parts from the end
                local depth_count=$((-prefix_depth))
                local start_idx=$((${#path_parts[@]} - depth_count))
                if [[ $start_idx -lt 0 ]]; then
                    start_idx=0
                fi
                for ((i=start_idx; i<${#path_parts[@]}; i++)); do
                    selected_parts+=("${path_parts[$i]}")
                done
            fi
            
            # Build the prefix from selected parts
            if [[ ${#selected_parts[@]} -gt 0 ]]; then
                local path_prefix
                path_prefix=$(IFS='_'; echo "${selected_parts[*]}")
                result="${path_prefix}_${filename}"
            fi
        fi
    fi
    
    # Add static link prefix if specified
    if [[ -n "$link_prefix" ]]; then
        result="${link_prefix}_${result}"
    fi
    
    echo "$result"
}

echo "Starting LoRA symlink update..."
echo "Source root:  $SOURCE_ROOT"
echo "Links folder: $LINKS_FOLDER"
echo ""

# ──────────────────────────────────────────
# Cleanup symlinks (rebuild mode or dead symlinks)
# ──────────────────────────────────────────
if [[ -d "$LINKS_FOLDER" ]]; then
    if [[ $REBUILD_MODE -eq 1 ]]; then
        # Rebuild mode: remove ALL symlinks
        echo "Rebuild mode: Removing ALL existing symlinks..."
        while IFS= read -r -d '' link; do
            if [[ -L "$link" ]]; then
                if [[ $TEST_MODE -eq 0 ]]; then
                    rm -f "$link"
                else
                    log "INFO" "TEST MODE: Would remove symlink: $(basename "$link")"
                fi
                ((removed++))
                [[ "$VERBOSE" == true ]] && echo "Removed: $(basename "$link")"
            fi
        done < <(find "$LINKS_FOLDER" -type l -print0 2>/dev/null || true)
        echo "Removed $removed symlinks in rebuild mode"
        echo ""
    elif [[ "$CLEANUP_DEAD" == true ]]; then
        # Normal mode: only remove broken symlinks
        echo "Cleaning up broken symlinks..."
        while IFS= read -r -d '' link; do
            if [[ -L "$link" && ! -e "$link" ]]; then
                if [[ $TEST_MODE -eq 0 ]]; then
                    rm -f "$link"
                else
                    log "INFO" "TEST MODE: Would remove dead symlink: $(basename "$link")"
                fi
                ((removed++))
                [[ "$VERBOSE" == true ]] && echo "Removed dead: $(basename "$link")"
            fi
        done < <(find "$LINKS_FOLDER" -type l -print0 2>/dev/null || true)
        echo "Removed $removed dead symlinks"
        echo ""
    fi
fi

# ──────────────────────────────────────────
# First pass: collect all files and find duplicates by link name
# ──────────────────────────────────────────
echo "Scanning for files..."
declare -A file_paths  # Maps link_name -> list of source paths
while IFS= read -r -d '' src_file; do
    link_name=$(generate_link_name "$src_file" "$SOURCE_ROOT" "$ADD_PATH_PREFIX" "$PREFIX_DEPTH" "$LINK_PREFIX")
    if [[ -z "${file_paths[$link_name]:-}" ]]; then
        file_paths[$link_name]="$src_file"
    else
        file_paths[$link_name]="${file_paths[$link_name]}"$'\n'"$src_file"
    fi
done < <(find "$SOURCE_ROOT" -type f \( \
    -iname "*.${EXTENSIONS[0]}" \
    -o -iname "*.${EXTENSIONS[1]}" \
    -o -iname "*.${EXTENSIONS[2]}" \
    \) -print0)

# ──────────────────────────────────────────
# Identify which files are true duplicates (same name, different paths)
# ──────────────────────────────────────────
declare -A duplicates  # Only for files that have > 1 source
for filename in "${!file_paths[@]}"; do
    path_count=$(echo -n "${file_paths[$filename]}" | grep -c '')
    if [[ $path_count -gt 1 ]]; then
        duplicates[$filename]="${file_paths[$filename]}"
    fi
done

echo "Found ${#file_paths[@]} unique filenames, ${#duplicates[@]} with duplicates"
echo ""

# ──────────────────────────────────────────
# Walk source tree and create symlinks
# ──────────────────────────────────────────
echo "Creating/updating symlinks..."

while IFS= read -r -d '' src_file; do
    # Generate link name based on prefix settings
    link_name=$(generate_link_name "$src_file" "$SOURCE_ROOT" "$ADD_PATH_PREFIX" "$PREFIX_DEPTH" "$LINK_PREFIX")
    dst="$LINKS_FOLDER/$link_name"

    # Check if symlink already exists
    if [[ -L "$dst" ]]; then
        # Get what it currently points to
        current_target=$(readlink -f "$dst")
        
        # If it points to the same file, skip it
        if [[ "$current_target" == "$src_file" ]]; then
            ((skipped++))
            continue
        fi
        
        # If it points to a DIFFERENT file, that's a conflict
        # But only show warning if this file actually has duplicates
        if [[ -n "${duplicates[$link_name]:-}" ]]; then
            # Only show warning if not in show-dupes-only mode
            if [[ $SHOW_DUPES -eq 0 ]]; then
                conflict_msg="⚠️  CONFLICT: $link_name exists in multiple locations!"
                conflict_msg="$conflict_msg\n   Current: $current_target"
                conflict_msg="$conflict_msg\n   Found:   $src_file"
                conflict_msg="$conflict_msg\n   → Keeping existing, skipping new one"
                
                # Output in yellow
                echo -e "\033[33m$conflict_msg\033[0m"
            fi
        fi
        ((skipped++))
        continue
    fi

    # Create the symlink (absolute target is safer)
    if [[ $TEST_MODE -eq 0 ]]; then
        ln -sf "$src_file" "$dst"
    else
        log "INFO" "TEST MODE: Would create symlink: $dst -> $src_file"
    fi
    ((created++))

    [[ "$VERBOSE" == true ]] && echo "Linked: $link_name  →  $src_file"

done < <(find "$SOURCE_ROOT" -type f \( \
    -iname "*.${EXTENSIONS[0]}" \
    -o -iname "*.${EXTENSIONS[1]}" \
    -o -iname "*.${EXTENSIONS[2]}" \
    \) -print0)

echo ""
echo "Done."
echo "Created:    $created"
echo "Skipped:    $skipped"
echo "Removed:    $removed"
echo "Total symlinks now: $(find "$LINKS_FOLDER" -type l | wc -l)"
echo ""

# Show duplicates if --show-dupes was used or if there are duplicates in normal mode
if [[ ${#duplicates[@]} -gt 0 ]]; then
    if [[ $SHOW_DUPES -eq 1 ]]; then
        echo "════════════════════════════════════════════════════════════"
        echo "DUPLICATE FILES FOUND:"
        echo "════════════════════════════════════════════════════════════"
        for dup_name in "${!duplicates[@]}"; do
            echo ""
            echo "Existing File: $dup_name"
            first=true
            while IFS= read -r path; do
                if [[ -n "$path" ]]; then
                    if [[ $first == true ]]; then
                        echo "  Current Path: $path"
                        first=false
                    else
                        echo "  Duplicate Found: $path"
                    fi
                fi
            done <<< "${duplicates[$dup_name]}"
        done
        echo ""
        echo "════════════════════════════════════════════════════════════"
    fi
fi
echo "Add this path to extra_model_paths.yaml using multiline format:"
echo "loras: |"
echo "  models/loras/links"

log "INFO" "Script execution completed"