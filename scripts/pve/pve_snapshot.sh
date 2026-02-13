#!/bin/bash

# Script: pve_snapshot.sh
# Description: Manages ZFS snapshots for Proxmox VMs (create, list, rollback, delete).
# Last Updated: 10/21/2025 8:00:00 PM CDT

# Source divtools environment if available
if [ -f "$HOME/.env" ]; then
    . "$HOME/.env"
fi
DIVTOOLS="${DIVTOOLS:-/mnt/tpool/NFS/opt/divtools}"

# Source logging utility
source "$DIVTOOLS/scripts/util/logging.sh"

# Global flags
TEST_MODE=""
DEBUG_MODE=""
VERBOSE_MODE=""
VMID=""
OPERATION=""
SNAPNAME=""

# Function: usage
# Description: Displays script usage and flags.
usage() { # usage
    log "ERROR:!ts" "Usage: $0 <VMID> [-t|--test] [-d|--debug] [-v|--verbose] [-create|-c <snapname>] [-ls] [-list-mounts|-lsm] [-rollback|-r <snapname>] [-del|-d <snapname>]"
    log "ERROR:!ts" "  <VMID>: Required VM ID (e.g., 297) - can be first or after flags."
    log "ERROR:!ts" "  -t, --test: Test mode - stub permanent actions with logs."
    log "ERROR:!ts" "  -d, --debug: Debug mode - enable verbose [DEBUG] output."
    log "ERROR:!ts" "  -v, --verbose: Verbose mode - with -ls, lists full disks per snapshot."
    log "ERROR:!ts" "  If only VMID: Lists snapshots for VM."
    log "ERROR:!ts" "  -create|-c <snapname>: Creates snapshot on current disks."
    log "ERROR:!ts" "  -ls: Lists all snapshots with disk counts."
    log "ERROR:!ts" "  -list-mounts|-lsm: Lists guest OS mountpoints for VM."
    log "ERROR:!ts" "  -rollback|-r <snapname>: Rolls back to snapshot (destructive)."
    log "ERROR:!ts" "  -del|-d <snapname>: Deletes snapshot."
    exit 1
} # usage

# Function: parse_args
# Description: Parses command-line arguments for flags and params.
parse_args() { # parse_args
    local pos_args=()
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--test)
                TEST_MODE="1"
                shift
                ;;
            -d|--debug)
                DEBUG_MODE="1"
                shift
                ;;
            -v|--verbose)
                VERBOSE_MODE="1"
                shift
                ;;
            -h|--help)
                usage
                ;;
            -create|-c)
                OPERATION="create"
                SNAPNAME="$2"
                shift 2
                ;;
            -ls)
                OPERATION="ls"
                shift
                ;;
            -list-mounts|-lsm)
                OPERATION="list-mounts"
                shift
                ;;
            -rollback|-r)
                OPERATION="rollback"
                SNAPNAME="$2"
                shift 2
                ;;
            -del|-d)
                OPERATION="del"
                SNAPNAME="$2"
                shift 2
                ;;
            *)
                pos_args+=("$1")
                shift
                ;;
        esac
    done

    # Extract VMID from first numeric positional
    for arg in "${pos_args[@]}"; do
        if [[ $arg =~ ^[0-9]+$ ]]; then
            VMID="$arg"
            break
        fi
    done

    # Error on extra non-numeric pos args
    for arg in "${pos_args[@]}"; do
        if [[ $arg != "$VMID" && ! $arg =~ ^[0-9]+$ ]]; then
            log "ERROR:!ts" "Unknown extra arg: $arg"
            usage
        fi
    done

    if [[ -z "$VMID" ]]; then
        log "ERROR:!ts" "VMID is required."
        usage
    fi

    if [[ "$OPERATION" == "create" || "$OPERATION" == "rollback" || "$OPERATION" == "del" ]]; then
        if [[ -z "$SNAPNAME" ]]; then
            log "ERROR:!ts" "Snapshot name required for $OPERATION."
            usage
        fi
    fi

    if [ "$DEBUG_MODE" = "1" ]; then
        log "DEBUG" "VMID=$VMID, OPERATION=$OPERATION, SNAPNAME=$SNAPNAME, Test=$TEST_MODE, Debug=$DEBUG_MODE, Verbose=$VERBOSE_MODE"
    fi
} # parse_args

# Function: confirm_operation
# Description: Prompts user for confirmation before proceeding.
confirm_operation() { # confirm_operation
    local prompt="$1"
    read -p "$prompt (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "INFO:!ts" "Operation cancelled by user."
        exit 0
    fi
} # confirm_operation

# Function: check_proxmox_host
# Description: Checks if running on Proxmox host; warns and confirms if not.
check_proxmox_host() { # check_proxmox_host
    if [ -f /etc/pve/.version ] || command -v pveversion &> /dev/null; then
        log "INFO:!ts" "Running on Proxmox host - proceeding."
        return 0
    else
        log "ERROR:!ts" "WARNING: This script should ONLY be run on the Proxmox host."
        confirm_operation "Do you still want to proceed? (Strongly not recommended)"
        return 0
    fi
} # check_proxmox_host

# Function: get_current_disks
# Description: Parses VM conf for current (non-snapshot) ZFS disks, resolving full dataset paths via zfs list.
# Last Updated: 10/21/2025 7:45:00 PM CDT
get_current_disks() { # get_current_disks
    local conf_file="/etc/pve/qemu-server/${VMID}.conf"
    if [[ ! -f "$conf_file" ]]; then
        log "ERROR:!ts" "VM config not found: $conf_file"
        exit 1
    fi

    local disks=()
    local disk_nums=()  # Track to avoid duplicates
    local match_count=0
    local parsing_current=true
    while IFS= read -r line; do
        # Stop at first snapshot section
        if [[ $line =~ ^\[.*\]$ ]] && [ "$parsing_current" = true ]; then
            parsing_current=false
            if [ "$DEBUG_MODE" = "1" ]; then
                log "DEBUG" "Stopped parsing at snapshot section: $line"
            fi
            continue
        fi

        # Skip empty lines or non-current sections
        [[ -z "$line" ]] && continue
        [[ "$parsing_current" != true ]] && continue

        if [[ $line =~ ^(scsi|ide|virtio)[0-9]+:[[:space:]]*local-zfs:vm-${VMID}-disk-[0-9]+ ]]; then
            ((match_count++))
            if [ "$DEBUG_MODE" = "1" ]; then
                log "DEBUG" "Processing matching line: '$line'"
            fi
            # Extract disk_num from "disk-<num>"
            if [[ $line =~ vm-${VMID}-disk-([0-9]+) ]]; then
                local disk_num="${BASH_REMATCH[1]}"
                # Skip if already added (avoids duplicates)
                if [[ " ${disk_nums[*]} " =~ " $disk_num " ]]; then
                    if [ "$DEBUG_MODE" = "1" ]; then
                        log "DEBUG" "Skipped duplicate disk_num: $disk_num"
                    fi
                    continue
                fi
                disk_nums+=("$disk_num")
                # Query zfs for full dataset path matching "vm-${VMID}-disk-${disk_num}"
                if [ "$DEBUG_MODE" = "1" ]; then
                    log "DEBUG" "DEBUG: About to run: zfs list -o name -H | grep 'vm-${VMID}-disk-${disk_num}\$'"
                fi
                local full_dataset=$(zfs list -o name -H | grep "vm-${VMID}-disk-${disk_num}$" | head -1)
                if [[ -z "$full_dataset" ]]; then
                    log "WARN:!ts" "No ZFS dataset found for disk-${disk_num} in VM $VMID - skipping."
                    continue
                fi
                disks+=("$full_dataset")
                if [ "$DEBUG_MODE" = "1" ]; then
                    log "DEBUG" "Added full dataset: $full_dataset (from disk-${disk_num})"
                fi
            fi
        fi
    done < "$conf_file"

    if [ "$DEBUG_MODE" = "1" ]; then
        log "DEBUG" "Total matching lines processed: $match_count"
        log "DEBUG" "Current disks: ${disks[*]}"
        if [[ ${#disks[@]} -eq 0 && $match_count -gt 0 ]]; then
            log "DEBUG" "No valid datasets added. Sample local-zfs lines in conf:"
            grep 'local-zfs' "$conf_file" | head -4 | while read -r sample; do
                log "DEBUG" "  $sample"
            done
            log "DEBUG" "DEBUG: About to run: zfs list | grep vm-${VMID}"
            zfs list | grep "vm-${VMID}"
        fi
    fi

    printf '%s\n' "${disks[@]}"
} # get_current_disks

# Function: list_snapshots
# Description: Lists all snapshots for VM or specific if SNAPNAME set.
# Last Updated: 10/21/2025 8:15:00 PM CDT
list_snapshots() { # list_snapshots
    local vm_pattern="vm-${VMID}"
    local snaps=$(zfs list -t snapshot -H -o name | grep "$vm_pattern" || true)

    if [[ -z "$snaps" ]]; then
        log "INFO:!ts" "No snapshots found for VM $VMID."
        return 0
    fi

    declare -A snap_datasets
    while IFS= read -r snap; do
        if [[ $snap =~ @([^\@]+)$ ]]; then
            local name="${BASH_REMATCH[1]}"
            snap_datasets["$name"]+="$snap"$'\n'
        fi
    done <<< "$snaps"

    for name in "${!snap_datasets[@]}"; do
        # Count non-empty lines (trim trailing newline)
        local count=$(echo -n "${snap_datasets[$name]}" | grep -c '^rpool/' || echo 0)
        log "INFO:!ts" "$name: $count disks"
        if [ "$VERBOSE_MODE" = "1" ]; then
            echo -n "${snap_datasets[$name]}" | while IFS= read -r dataset || [ -n "$dataset" ]; do
                if [[ -n "$dataset" ]]; then
                    echo "> $dataset"
                fi
            done
        fi
    done
} # list_snapshots

# Function: get_guest_mounts
# Description: Queries guest mountpoints via qm guest exec (fallback to SSH).
# Last Updated: 10/21/2025 9:15:00 PM CDT
get_guest_mounts() { # get_guest_mounts
    local ssh_user="${SSH_USER:-divix}"  # Default root; override in .env if needed
    local ssh_port="${SSH_PORT:-22}"
    local vm_ip=$(qm config "$VMID" | grep "ipconfig0: ip=dhcp" | awk '{print $3}' || echo "unknown")  # Extract IP if configured

    if [ "$TEST_MODE" = "1" ]; then
        log "INFO:!ts" "[TEST] Would run: qm guest exec $VMID -- 'lsblk -o NAME,MOUNTPOINT,SIZE,TYPE,FSTYPE | grep -E \"sda|sdb\" && zfs list -o name,mountpoint -t filesystem | grep -v -E \"(ROOT|USERDATA|home|snap|var)\"'"
        log "INFO:!ts" "[TEST] Fallback SSH: ssh $ssh_user@$vm_ip 'lsblk -o NAME,MOUNTPOINT,SIZE,TYPE,FSTYPE | grep -E \"sda|sdb\" && zfs list -o name,mountpoint -t filesystem | grep -v -E \"(ROOT|USERDATA|home|snap|var)\"'"
        return 0
    fi

    # Try qm guest exec first (requires agent)
    if [ "$DEBUG_MODE" = "1" ]; then
        log "DEBUG" "DEBUG: About to run: qm guest exec $VMID -- 'lsblk -o NAME,MOUNTPOINT,SIZE,TYPE,FSTYPE | grep -E \"sda|sdb\" && zfs list -o name,mountpoint -t filesystem | grep -v -E \"(ROOT|USERDATA|home|snap|var)\"'"
    fi
    local guest_output=$(qm guest exec "$VMID" -- "lsblk -o NAME,MOUNTPOINT,SIZE,TYPE,FSTYPE | grep -E 'sda|sdb' && zfs list -o name,mountpoint -t filesystem | grep -v -E '(ROOT|USERDATA|home|snap|var)'" 2>/dev/null)
    local exit_code=$?

    if [[ $exit_code -eq 0 && -n "$guest_output" ]]; then
        log "INFO:!ts" "Guest device/mount mapping (via agent):"
        echo "$guest_output"
        return 0
    else
        log "WARN:!ts" "Agent failed; falling back to SSH."
        # SSH fallback (same command)
        if [[ -z "$vm_ip" || "$vm_ip" == "unknown" ]]; then
            log "ERROR:!ts" "No VM IP for SSH fallback."
            return 1
        fi
        if [ "$DEBUG_MODE" = "1" ]; then
            log "DEBUG" "DEBUG: About to run: ssh -p $ssh_port $ssh_user@$vm_ip 'lsblk -o NAME,MOUNTPOINT,SIZE,TYPE,FSTYPE | grep -E \"sda|sdb\" && zfs list -o name,mountpoint -t filesystem | grep -v -E \"(ROOT|USERDATA|home|snap|var)\"'"
        fi
        local ssh_output=$(ssh -p "$ssh_port" -o ConnectTimeout=5 "$ssh_user@$vm_ip" "lsblk -o NAME,MOUNTPOINT,SIZE,TYPE,FSTYPE | grep -E 'sda|sdb' && zfs list -o name,mountpoint -t filesystem | grep -v -E '(ROOT|USERDATA|home|snap|var)'" 2>/dev/null)
        local ssh_code=$?
        if [[ $ssh_code -eq 0 && -n "$ssh_output" ]]; then
            log "INFO:!ts" "Guest device/mount mapping (via SSH):"
            echo "$ssh_output"
            return 0
        else
            log "ERROR:!ts" "SSH fallback failed (exit $ssh_code)."
            return 1
        fi
    fi
} # get_guest_mounts


# Function: create_snapshot
# Description: Creates ZFS snapshot on current disks.
create_snapshot() { # create_snapshot
    local disks=($(get_current_disks))
    local num_disks=${#disks[@]}

    if [[ $num_disks -eq 0 ]]; then
        log "ERROR:!ts" "No current disks found for VM $VMID. Check conf format or VMID."
        if [ "$DEBUG_MODE" = "1" ]; then
            log "DEBUG" "DEBUG: About to run: zfs list | grep vm-${VMID}"
            zfs list | grep "vm-${VMID}" || log "DEBUG" "No matching datasets found."
        fi
        return 1
    fi

    if [ "$TEST_MODE" = "1" ]; then
        log "INFO:!ts" "[TEST] Would create snapshot '$SNAPNAME' on $num_disks disks:"
        for dataset in "${disks[@]}"; do
            echo "> $dataset"
        done
        return 0
    fi

    local success=0
    for dataset in "${disks[@]}"; do
        # Check dataset exists
        if [ "$DEBUG_MODE" = "1" ]; then
            log "DEBUG" "DEBUG: About to run: zfs list $dataset"
        fi
        if ! zfs list "$dataset" &> /dev/null; then
            log "ERROR:!ts" "Dataset $dataset does not exist - skipping."
            if [ "$DEBUG_MODE" = "1" ]; then
                log "DEBUG" "DEBUG output from failed zfs list $dataset:"
                zfs list "$dataset" 2>&1 | while IFS= read -r line; do
                    log "DEBUG" "  $line"
                done
            fi
            continue
        fi
        if [ "$DEBUG_MODE" = "1" ]; then
            log "DEBUG" "DEBUG: About to run: zfs snapshot ${dataset}@$SNAPNAME"
        fi
        zfs snapshot "${dataset}@$SNAPNAME"
        if [[ $? -eq 0 ]]; then
            ((success++))
        else
            log "ERROR:!ts" "Failed to create snapshot on $dataset"
            if [ "$DEBUG_MODE" = "1" ]; then
                log "DEBUG" "DEBUG output from failed zfs snapshot ${dataset}@$SNAPNAME:"
                zfs snapshot "${dataset}@$SNAPNAME" 2>&1 | while IFS= read -r line; do
                    log "DEBUG" "  $line"
                done
            fi
        fi
    done

    if [[ $success -eq $num_disks ]]; then
        log "INFO:!ts" "Snapshot '$SNAPNAME' created on $success disks."
        return 0
    else
        log "ERROR:!ts" "Partial failure: $success/$num_disks disks snapshotted."
        if [ "$DEBUG_MODE" = "1" ]; then
            log "DEBUG" "DEBUG: About to run: zfs list | grep vm-${VMID}"
            zfs list | grep "vm-${VMID}" || log "DEBUG" "No matching datasets found."
        fi
        return 1
    fi
} # create_snapshot

# Function: snapshot_exists
# Description: Checks if snapshot exists on all current disks.
snapshot_exists() { # snapshot_exists
    local disks=($(get_current_disks))
    local exists=true

    for dataset in "${disks[@]}"; do
        if ! zfs list -t snapshot "${dataset}@$SNAPNAME" &> /dev/null; then
            exists=false
            break
        fi
    done

    if [ "$DEBUG_MODE" = "1" ]; then
        log "DEBUG" "Snapshot '$SNAPNAME' exists: $exists"
    fi

    $exists
} # snapshot_exists

# Function: rollback_snapshot
# Description: Rolls back to snapshot on all disks.
rollback_snapshot() { # rollback_snapshot
    local disks=($(get_current_disks))
    local num_disks=${#disks[@]}

    if [[ $num_disks -eq 0 ]]; then
        log "ERROR:!ts" "No current disks found for VM $VMID."
        return 1
    fi

    if ! snapshot_exists; then
        log "ERROR:!ts" "Snapshot '$SNAPNAME' does not exist on all disks."
        return 1
    fi

    if [ "$TEST_MODE" = "1" ]; then
        log "INFO:!ts" "[TEST] Would rollback to '$SNAPNAME' on $num_disks disks:"
        for dataset in "${disks[@]}"; do
            echo "> $dataset"
        done
        log "WARN:!ts" "[TEST] WARNING: Rollback is destructive - would overwrite changes."
        return 0
    fi

    local action_msg="Rollback to snapshot '$SNAPNAME' on VM $VMID disks:"
    for dataset in "${disks[@]}"; do
        action_msg+=" > $dataset"
    done
    action_msg+=" This will OVERWRITE all changes since snapshot!"
    confirm_operation "$action_msg WARNING: This is destructive and cannot be undone."

    local success=0
    for dataset in "${disks[@]}"; do
        if [ "$DEBUG_MODE" = "1" ]; then
            log "DEBUG" "DEBUG: About to run: zfs rollback ${dataset}@$SNAPNAME"
        fi
        zfs rollback "${dataset}@$SNAPNAME"
        if [[ $? -eq 0 ]]; then
            ((success++))
        else
            log "ERROR:!ts" "Failed to rollback $dataset"
        fi
    done

    if [[ $success -eq $num_disks ]]; then
        log "INFO:!ts" "Rollback to '$SNAPNAME' completed on $num_disks disks."
        return 0
    else
        log "ERROR:!ts" "Partial failure: $success/$num_disks disks rolled back."
        return 1
    fi
} # rollback_snapshot

# Function: delete_snapshot
# Description: Deletes snapshot on all disks.
delete_snapshot() { # delete_snapshot
    local disks=($(get_current_disks))
    local num_disks=${#disks[@]}

    if [[ $num_disks -eq 0 ]]; then
        log "ERROR:!ts" "No current disks found for VM $VMID."
        return 1
    fi

    if ! snapshot_exists; then
        log "ERROR:!ts" "Snapshot '$SNAPNAME' does not exist on all disks."
        return 1
    fi

    if [ "$TEST_MODE" = "1" ]; then
        log "INFO:!ts" "[TEST] Would delete snapshot '$SNAPNAME' on $num_disks disks:"
        for dataset in "${disks[@]}"; do
            echo "> $dataset@$SNAPNAME"
        done
        log "WARN:!ts" "[TEST] WARNING: Deletion is permanent."
        return 0
    fi

    local action_msg="Delete snapshot '$SNAPNAME' on VM $VMID disks:"
    for dataset in "${disks[@]}"; do
        action_msg+=" > $dataset@$SNAPNAME"
    done
    action_msg+=" This will PERMANENTLY remove the snapshots!"
    confirm_operation "$action_msg WARNING: This cannot be undone."

    local success=0
    for dataset in "${disks[@]}"; do
        if [ "$DEBUG_MODE" = "1" ]; then
            log "DEBUG" "DEBUG: About to run: zfs destroy ${dataset}@$SNAPNAME"
        fi
        zfs destroy "${dataset}@$SNAPNAME"
        if [[ $? -eq 0 ]]; then
            ((success++))
        else
            log "ERROR:!ts" "Failed to delete $dataset@$SNAPNAME"
        fi
    done

    if [[ $success -eq $num_disks ]]; then
        log "INFO:!ts" "Snapshot '$SNAPNAME' deleted from $num_disks disks."
        return 0
    else
        log "ERROR:!ts" "Partial failure: $success/$num_disks disks deleted."
        return 1
    fi
} # delete_snapshot

# Main execution
main() { # main
    parse_args "$@"

    check_proxmox_host

    if [[ -z "$OPERATION" ]]; then
        # Default: List snapshots
        log "INFO:!ts" "Listing snapshots for VM $VMID..."
        list_snapshots
    elif [[ "$OPERATION" == "ls" ]]; then
        log "INFO:!ts" "Listing all snapshots for VM $VMID..."
        list_snapshots
    elif [[ "$OPERATION" == "list-mounts" ]]; then
        confirm_operation "Retrieve mountpoints for VM $VMID guest OS?"
        get_guest_mounts        
    elif [[ "$OPERATION" == "create" ]]; then
        confirm_operation "Create snapshot '$SNAPNAME' on current disks of VM $VMID?"
        create_snapshot
    elif [[ "$OPERATION" == "rollback" ]]; then
        rollback_snapshot
    elif [[ "$OPERATION" == "del" ]]; then
        delete_snapshot
    else
        log "ERROR:!ts" "Invalid operation: $OPERATION"
        usage
    fi

    if [[ $? -eq 0 ]]; then
        log "INFO:!ts" "Script completed successfully."
    else
        log "ERROR:!ts" "Script failed."
        exit 1
    fi
} # main

# Run main if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi