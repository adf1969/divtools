#!/bin/bash
# Wan2GP utility script for managing folder relocations and symlink creation
# Last Updated: 02/06/2026 1:15:00 PM CST

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WAN2GP_APP_DIR="/opt/wan2gp/Wan2GP"

# Source logging utilities
if [[ -f "$REPO_ROOT/scripts/util/logging.sh" ]]; then
    # shellcheck source=/dev/null
    source "$REPO_ROOT/scripts/util/logging.sh"
fi

# Default flags
TEST_MODE=0
DEBUG_MODE=0
ACTION=""

# Load .env.wan2gp if it exists
ENV_FILE="$SCRIPT_DIR/.env.wan2gp"
if [[ -f "$ENV_FILE" ]]; then
    # shellcheck source=/dev/null
    set -a; source "$ENV_FILE"; set +a
    log "DEBUG" "Loaded configuration from $ENV_FILE"
fi

# ============================================================================
# Helper Functions
# ============================================================================

# Function to display usage information
show_usage() {
    cat << 'EOF'
Wan2GP Utility Script - Manage folder relocations and symlinks

USAGE: wan2gp_util.sh [OPTIONS] [ACTION]

GLOBAL OPTIONS:
  -test, --test, -t          Run in TEST mode (show what would happen, no changes)
  -debug, --debug, -d        Enable DEBUG mode (verbose output)
  -h, --help                 Show this help message

ACTIONS:
  -relocate-ckpts, --relocate-ckpts, -rc
    Relocate the checkpoints (ckpts) folder to the destination specified in
    WAN2GP_CKPTS_DEST (from .env.wan2gp). Creates symlink from ckpts to destination.
    
    Process:
    1. Creates destination if it doesn't exist
    2. Compares contents of ckpts with destination
    3. Copies ckpts contents to destination if different
    4. Renames ckpts to ckpts.ORIG (backup)
    5. Creates symlink: ckpts -> destination
    
    Default destination (if not set): /opt/ai_models/sd_models/checkpoints

  -relocate-loras, --relocate-loras, -rl
    Relocate the loras folder to the destination specified in
    WAN2GP_LORAS_DEST (from .env.wan2gp). Creates symlink from loras to destination.
    
    Process: Same as -relocate-ckpts
    
    Default destination (if not set): /opt/ai_models/sd_models/loras

EXAMPLES:
  # Dry run to see what would happen
  wan2gp_util.sh -test -relocate-ckpts
  
  # Actually perform the relocation with debug output
  wan2gp_util.sh -debug -relocate-ckpts
  
  # Relocate loras folder
  wan2gp_util.sh -relocate-loras
  
  # Dry run with short flags
  wan2gp_util.sh -t -rl

EOF
}

# Function to check if two directories have the same contents (by hash)
dirs_have_same_content() {
    local dir1="$1"
    local dir2="$2"
    
    if [[ ! -d "$dir1" ]]; then
        log "DEBUG" "dirs_have_same_content: dir1 does not exist: $dir1"
        return 1
    fi
    
    if [[ ! -d "$dir2" ]]; then
        log "DEBUG" "dirs_have_same_content: dir2 does not exist: $dir2"
        return 1
    fi
    
    # Simple content check: compare file listings and sizes
    local hash1 hash2
    hash1=$(find "$dir1" -type f -exec ls -l {} \; 2>/dev/null | sha256sum | awk '{print $1}')
    hash2=$(find "$dir2" -type f -exec ls -l {} \; 2>/dev/null | sha256sum | awk '{print $1}')
    
    [[ "$hash1" == "$hash2" ]]
}

# Function to relocate a folder
relocate_folder() {
    local folder_name="$1"      # e.g., "ckpts" or "loras"
    local source_dir="$2"       # e.g., /opt/wan2gp/Wan2GP/ckpts
    local dest_dir="$3"         # e.g., /opt/ai_models/sd_models/checkpoints
    
    log "INFO" "Starting relocation of $folder_name folder"
    log "DEBUG" "Source: $source_dir"
    log "DEBUG" "Destination: $dest_dir"
    
    # Validate source exists
    if [[ ! -d "$source_dir" ]]; then
        log "ERROR" "Source directory does not exist: $source_dir"
        return 1
    fi
    
    # Check if source is already a symlink
    if [[ -L "$source_dir" ]]; then
        log "WARN" "Source is already a symlink: $source_dir"
        log "INFO" "Current target: $(readlink "$source_dir")"
        return 0
    fi
    
    # Create destination directory if it doesn't exist
    if [[ ! -d "$dest_dir" ]]; then
        log "INFO" "Creating destination directory: $dest_dir"
        if [[ $TEST_MODE -eq 0 ]]; then
            mkdir -p "$dest_dir" || {
                log "ERROR" "Failed to create destination directory: $dest_dir"
                return 1
            }
        else
            log "DEBUG:!ts" "[TEST] Would create: $dest_dir"
        fi
    fi
    
    # Check if destination has existing content
    local dest_has_content=0
    if [[ -d "$dest_dir" ]]; then
        local file_count
        file_count=$(find "$dest_dir" -type f 2>/dev/null | wc -l)
        if [[ $file_count -gt 0 ]]; then
            dest_has_content=1
            log "DEBUG" "Destination already contains $file_count files"
        fi
    fi
    
    # Check source content
    local source_file_count
    source_file_count=$(find "$source_dir" -type f 2>/dev/null | wc -l)
    log "DEBUG" "Source contains $source_file_count files"
    
    # If source has content, copy to destination
    if [[ $source_file_count -gt 0 ]]; then
        if [[ $dest_has_content -eq 0 ]] || ! dirs_have_same_content "$source_dir" "$dest_dir"; then
            log "INFO" "Copying $folder_name content from $source_dir to $dest_dir"
            if [[ $TEST_MODE -eq 0 ]]; then
                cp -r "$source_dir"/* "$dest_dir/" 2>/dev/null || {
                    log "ERROR" "Failed to copy content to destination"
                    return 1
                }
            else
                log "DEBUG:!ts" "[TEST] Would copy content from $source_dir to $dest_dir"
            fi
        else
            log "INFO" "Destination already contains the same content, skipping copy"
        fi
    fi
    
    # Backup original folder
    local backup_dir="${source_dir}.ORIG"
    if [[ -d "$backup_dir" ]]; then
        log "WARN" "Backup already exists: $backup_dir"
    else
        log "INFO" "Backing up original folder to: $backup_dir"
        if [[ $TEST_MODE -eq 0 ]]; then
            mv "$source_dir" "$backup_dir" || {
                log "ERROR" "Failed to rename source directory to backup"
                return 1
            }
        else
            log "DEBUG:!ts" "[TEST] Would rename $source_dir to $backup_dir"
        fi
    fi
    
    # Create symlink
    log "INFO" "Creating symlink: $source_dir -> $dest_dir"
    if [[ $TEST_MODE -eq 0 ]]; then
        ln -s "$dest_dir" "$source_dir" || {
            log "ERROR" "Failed to create symlink"
            # Try to restore the original directory on failure
            if [[ -d "$backup_dir" ]]; then
                log "WARN" "Attempting to restore original directory from backup"
                mv "$backup_dir" "$source_dir"
            fi
            return 1
        }
    else
        log "DEBUG:!ts" "[TEST] Would create symlink: $source_dir -> $dest_dir"
    fi
    
    log "INFO" "✓ Successfully relocated $folder_name folder"
    return 0
}

# ============================================================================
# Parse Arguments
# ============================================================================

# Parse global flags and action
while [[ $# -gt 0 ]]; do
    case "$1" in
        -test|--test|-t)
            TEST_MODE=1
            log "INFO" "Running in TEST mode - no permanent changes will be made"
            shift
            ;;
        -debug|--debug|-d)
            DEBUG_MODE=1
            log "DEBUG" "Debug mode enabled"
            shift
            ;;
        -h|--help|-\?)
            show_usage
            exit 0
            ;;
        -relocate-ckpts|--relocate-ckpts|-rc)
            ACTION="relocate_ckpts"
            shift
            ;;
        -relocate-loras|--relocate-loras|-rl)
            ACTION="relocate_loras"
            shift
            ;;
        *)
            log "ERROR" "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# ============================================================================
# Execute Action
# ============================================================================

if [[ -z "$ACTION" ]]; then
    log "ERROR" "No action specified"
    show_usage
    exit 1
fi

case "$ACTION" in
    relocate_ckpts)
        # Set defaults if not configured
        WAN2GP_CKPTS_DEST="${WAN2GP_CKPTS_DEST:-/opt/ai_models/sd_models/checkpoints}"
        
        log "INFO" "Relocating checkpoints (ckpts) folder"
        log "DEBUG" "Destination from .env.wan2gp: $WAN2GP_CKPTS_DEST"
        
        if relocate_folder "checkpoints (ckpts)" "$WAN2GP_APP_DIR/ckpts" "$WAN2GP_CKPTS_DEST"; then
            exit 0
        else
            exit 1
        fi
        ;;
    relocate_loras)
        # Set defaults if not configured
        WAN2GP_LORAS_DEST="${WAN2GP_LORAS_DEST:-/opt/ai_models/sd_models/loras}"
        
        log "INFO" "Relocating loras folder"
        log "DEBUG" "Destination from .env.wan2gp: $WAN2GP_LORAS_DEST"
        
        if relocate_folder "loras" "$WAN2GP_APP_DIR/loras" "$WAN2GP_LORAS_DEST"; then
            exit 0
        else
            exit 1
        fi
        ;;
    *)
        log "ERROR" "Unknown action: $ACTION"
        show_usage
        exit 1
        ;;
esac
