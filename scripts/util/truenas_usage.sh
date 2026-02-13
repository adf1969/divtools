#!/bin/bash
# Helper functions to read ZFS usage data from TrueNAS exports
# Last Updated: 11/4/2025 9:35:00 PM CST

# Function to read TrueNAS ZFS usage file and return corrected values
# Usage: get_truenas_usage "/mount/point" "/path/to/.zfs_usage_info"
# Returns: "used|available|total" or empty string if not found
get_truenas_usage() {
    local mountpoint="$1"
    local usage_file="$2"
    local debug="${3:-0}"
    
    # Check if usage file exists and is readable
    if [[ ! -r "$usage_file" ]]; then
        [[ $debug -eq 1 ]] && echo "[DEBUG] Usage file not found or not readable: $usage_file" >&2
        return 1
    fi
    
    [[ $debug -eq 1 ]] && echo "[DEBUG] Reading usage file: $usage_file" >&2
    
    # Read parent dataset info
    local parent_used parent_avail parent_total
    local in_parent=0
    
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
        
        # Check for parent section
        if [[ "$line" == "[PARENT]" ]]; then
            in_parent=1
            continue
        fi
        
        # Check for dataset section (exits parent)
        if [[ "$line" =~ ^\[DATASET:.+\]$ ]]; then
            in_parent=0
            continue
        fi
        
        # Parse parent data
        if [[ $in_parent -eq 1 ]]; then
            if [[ "$line" =~ ^used=(.+)$ ]]; then
                parent_used="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^available=(.+)$ ]]; then
                parent_avail="${BASH_REMATCH[1]}"
            fi
        fi
    done < "$usage_file"
    
    # Calculate total (used + available)
    if [[ -n "$parent_used" && -n "$parent_avail" ]]; then
        # Convert to bytes for calculation
        local used_bytes avail_bytes total_bytes
        used_bytes=$(numfmt --from=iec "$parent_used" 2>/dev/null) || used_bytes=0
        avail_bytes=$(numfmt --from=iec "$parent_avail" 2>/dev/null) || avail_bytes=0
        total_bytes=$((used_bytes + avail_bytes))
        
        # Convert back to human readable
        parent_total=$(numfmt --to=iec --suffix=B "$total_bytes" 2>/dev/null) || parent_total="$parent_used"
        
        [[ $debug -eq 1 ]] && echo "[DEBUG] TrueNAS usage found: used=$parent_used, avail=$parent_avail, total=$parent_total" >&2
        echo "$parent_used|$parent_avail|$parent_total"
        return 0
    fi
    
    [[ $debug -eq 1 ]] && echo "[DEBUG] No parent dataset info found in usage file" >&2
    return 1
}

# Function to check if a mountpoint is a remote NFS/SMB share
# Returns 0 if remote, 1 if local
is_remote_mount() {
    local mountpoint="$1"
    local fs_type
    
    # Get filesystem type for this mountpoint
    fs_type=$(df -T "$mountpoint" 2>/dev/null | tail -n 1 | awk '{print $2}')
    
    # Check if it's a network filesystem
    case "$fs_type" in
        nfs|nfs4|cifs|smb|smbfs)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Function to get the usage file path from a mountpoint
# Checks common locations for .zfs_usage_info file
get_usage_file_for_mount() {
    local mountpoint="$1"
    local usage_file="$mountpoint/.zfs_usage_info"
    
    if [[ -r "$usage_file" ]]; then
        echo "$usage_file"
        return 0
    fi
    
    return 1
}
