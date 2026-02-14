#!/bin/bash

# 9/4/2025 9:37:00 PM
#

# Script to mount/unmount Proxmox LXC container filesystem volumes
# Usage: mount_lxc_vol.sh vmid [-mp <mnt-point-folder>] [-mount | -unmount] [-test] [-debug]
# Default mount location is /mnt/lxc/<vmid> if -mp is not specified

# Default variables
VMID=""
MNT_POINT="/mnt/lxc"  # Default mount point
MODE=""               # mount or unmount
TEST_MODE=false
DEBUG_MODE=false

# Function to output in red text
echo_red() {
    echo -e "\033[0;31m$1\033[0m"
}

# Function to output in green text
echo_green() {
    echo -e "\033[0;32m$1\033[0m"
}

# Debug output function with timestamp
debug() {
    if [[ "$DEBUG_MODE" == true ]]; then
        echo "[DEBUG] $(date '+%Y-%m-%d %H:%M:%S %Z') $1"
    fi
}

# Check if the script is run as root or a non-root user
run_cmd() {
    if [[ $EUID -ne 0 ]]; then
        sudo "$@"
    else
        "$@"
    fi
}

# Function to display usage
usage() {
    debug "Enter usage"
    echo "Usage: $0 vmid [-mp <mnt-point-folder>] [-mount | -unmount] [-test] [-debug]"
    echo "  vmid: The VMID of the LXC container to mount/unmount"
    echo "  -mp <mnt-point-folder>: The base folder to mount drives (default: /mnt/lxc/<vmid>)"
    echo "  -mount: Mount the drives"
    echo "  -unmount: Unmount the drives"
    echo "  -test: Dry-run mode, outputs actions without executing"
    echo "  -debug: Verbose debug output"
    debug "Exit usage"
    exit 1
}

# Parse command-line arguments
parse_args() {
    debug "Enter parse_args"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -mp)
                MNT_POINT="$2"
                shift 2
                ;;
            -mount)
                MODE="mount"
                shift
                ;;
            -unmount)
                MODE="unmount"
                shift
                ;;
            -test)
                TEST_MODE=true
                shift
                ;;
            -debug)
                DEBUG_MODE=true
                shift
                ;;
            *)
                VMID="$1"
                shift
                ;;
        esac
    done
    debug "Exit parse_args with VMID=$VMID, MNT_POINT=$MNT_POINT, MODE=$MODE, TEST_MODE=$TEST_MODE, DEBUG_MODE=$DEBUG_MODE"
}

# Validate arguments
validate_args() {
    debug "Enter validate_args"
    if [[ -z "$VMID" || -z "$MODE" ]]; then
        echo_red "Missing required arguments"
        usage
    fi
    debug "Exit validate_args"
}

# Construct the base mount point with VMID
construct_mount_point() {
    debug "Enter construct_mount_point"
    BASE_MNT_POINT="${MNT_POINT}/${VMID}"
    debug "BASE_MNT_POINT: $BASE_MNT_POINT"
    debug "Exit construct_mount_point"
}

# Define config files
define_config_files() {
    debug "Enter define_config_files"
    LXC_CONF="/etc/pve/lxc/${VMID}.conf"
    STORAGE_CONF="/etc/pve/storage.cfg"
    debug "LXC_CONF: $LXC_CONF, STORAGE_CONF: $STORAGE_CONF"
    debug "Exit define_config_files"
}

# Check if config file is readable
check_config_readable() {
    debug "Enter check_config_readable"
    if [[ ! -r "$LXC_CONF" ]]; then
        echo_red "Cannot read LXC config file: $LXC_CONF"
        exit 1
    fi
    debug "Exit check_config_readable"
}

# Function to parse LXC conf for rootfs and mp# (skip snapshots)
parse_lxc_drives() {
    debug "Enter parse_lxc_drives"
    drives=()
    section_active=false
    line_count=0
    max_lines=1000  # Safety limit to prevent infinite loop
    while IFS= read -r line || [[ -n "$line" ]]; do
        ((line_count++))
        debug "Processing line $line_count: '$line'"
        if [[ $line_count -gt $max_lines ]]; then
            debug "Exceeded max lines ($max_lines), forcing exit"
            break
        fi
        if [[ $line = \[* ]]; then
            section_active=false
            if [[ $line != "\[Before-Update-UIDs\]"* ]]; then
                section_active=true
            fi
            continue
        fi
        if [[ $section_active == true ]]; then
            if [[ $line =~ ^rootfs:[[:space:]]*(.+) ]]; then
                storage_id=$(echo "$line" | sed 's/^rootfs:[[:space:]]*//;s/,.*//')
                drives+=("rootfs:$storage_id")
                debug "Added rootfs:$storage_id"
            elif [[ $line =~ ^mp[0-9]:[[:space:]]*(.+) ]]; then
                mp_num=$(echo "$line" | cut -d ':' -f 1)
                storage_id=$(echo "$line" | sed 's/^mp[0-9]:[[:space:]]*//;s/,.*//')
                # Skip host paths (e.g., /mnt/NAS1-1/u-shared)
                if [[ ! $storage_id = /* ]]; then
                    drives+=("$mp_num:$storage_id")
                    debug "Added $mp_num:$storage_id"
                else
                    debug "Skipped $mp_num (host path: $storage_id)"
                fi
            fi
        fi
    done < "$LXC_CONF"
    debug "Found drives: ${drives[*]}"
    debug "Exit parse_lxc_drives"
    echo "${drives[*]}"
}

# Function to parse storage.conf for drive paths and determine type
get_drive_path() {
    debug "Enter get_drive_path"
    storage_id="$1"
    vmid_disk="$2"  # e.g., subvol-903-disk-0 for ZFS, vm-103-disk-0.raw for raw

    path=""
    type="unknown"
    while read -r line; do
        if [[ $line = "$storage_id {" ]]; then
            while read -r storage_line; do
                if [[ $storage_line = path* ]]; then
                    path=$(echo "$storage_line" | cut -d ' ' -f 2)
                elif [[ $storage_line = content* ]]; then
                    if [[ $storage_line = *rootdir* ]]; then
                        type="zfs"  # ZFS subvolume
                    elif [[ $storage_line = *images* ]]; then
                        type="raw"  # Raw disk image
                    fi
                fi
                if [[ -n "$path" && -n "$type" ]]; then
                    break
                fi
            done
        fi
    done < "$STORAGE_CONF"
    debug "Initial path for $storage_id: $path, Type: $type"
    if [[ "$type" == "zfs" ]]; then
        # Check if the subvolume exists under the mountpoint
        full_path="${path}/${vmid_disk}"
        debug "Checking full path: $full_path"
        if [[ -e "$full_path" ]]; then
            echo "$full_path"
        else
            # Try adjusting for ZFS dataset naming
            dataset="${path}/${vmid_disk}"
            if zfs list -H "$dataset" >/dev/null 2>&1; then
                mountpoint=$(zfs get -H -o value mountpoint "$dataset")
                if [[ "$mountpoint" != "none" && -d "$mountpoint" ]]; then
                    echo "$mountpoint"
                fi
            fi
        fi
    elif [[ "$type" == "raw" ]]; then
        echo "$path/images/$VMID/$vmid_disk"  # Raw image path
    fi
    debug "Exit get_drive_path with resolved path=$path"
}

# Function to check if container is running
is_running() {
    debug "Enter is_running"
    pct status "$VMID" | grep -q "running"
    debug "Exit is_running"
    return $?
}

# Function to stop container if running (skip in test mode)
stop_container() {
    debug "Enter stop_container"
    if is_running; then
        if [[ "$TEST_MODE" == true ]]; then
            echo_green "TEST: Container $VMID is running (would prompt to stop in normal mode)"
        else
            echo_red "Container $VMID is running."
            read -p "Do you want to stop it? (y/n): " stop_confirm
            if [[ "$stop_confirm" == "y" || "$stop_confirm" == "Y" ]]; then
                run_cmd pct stop "$VMID"
                echo_green "Container $VMID stopped."
            else
                echo_red "Cannot mount while container is running. Exiting."
                exit 1
            fi
        fi
    fi
    debug "Exit stop_container"
}

# Function to get list of drives
get_drives() {
    debug "Enter get_drives"
    mapfile -t drives < <(parse_lxc_drives)  # Use mapfile to capture output safely
    drive_paths=()
    for drive in "${drives[@]}"; do
        type=$(echo "$drive" | cut -d ':' -f 1)
        storage_id=$(echo "$drive" | cut -d ':' -f 2)
        if [[ $type = rootfs ]]; then
            vmid_disk="subvol-${VMID}-disk-0"  # ZFS subvolume naming
        else
            mp_num=$(echo "$type" | cut -d 'p' -f 2)
            vmid_disk="subvol-${VMID}-disk-${mp_num}"  # e.g., mp0 -> subvol-903-disk-1
        fi
        path=$(get_drive_path "$storage_id" "$vmid_disk")
        debug "Checking drive $type with storage_id $storage_id, vmid_disk $vmid_disk, resolved path $path"
        if [[ -n "$path" && -e "$path" ]]; then
            drive_paths+=("$type:$path")
        else
            debug "No valid path found for $type:$storage_id (path: $path)"
        fi
    done
    debug "Collected drive paths: ${drive_paths[*]}"
    debug "Exit get_drives"
    echo "${drive_paths[@]}"
}

# Function to check if a path is mounted
is_mounted() {
    debug "Enter is_mounted"
    path="$1"
    mount | grep -q "$path"
    debug "Exit is_mounted"
    return $?
}

# Function to perform mount/unmount with ZFS vs. raw handling
perform_operation() {
    debug "Enter perform_operation"
    drives=($(get_drives))
    action_list=()
    for drive in "${drives[@]}"; do
        type=$(echo "$drive" | cut -d ':' -f 1)
        path=$(echo "$drive" | cut -d ':' -f 2-)
        target_dir="$BASE_MNT_POINT/$type"
        if [[ "$MODE" == "mount" ]]; then
            if is_mounted "$target_dir"; then
                action_list+=("$target_dir already mounted")
            else
                if [[ -f "$path" ]]; then  # Raw disk image
                    action_list+=("Mount $path to $target_dir (loop device)")
                elif [[ -d "$path" ]]; then  # ZFS subvolume
                    action_list+=("Create softlink from $path to $target_dir")
                fi
            fi
        elif [[ "$MODE" == "unmount" ]]; then
            if is_mounted "$target_dir"; then
                action_list+=("Unmount $target_dir")
            else
                action_list+=("$target_dir not mounted")
            fi
        fi
    done

    echo_green "The following operations will be performed:"
    for action in "${action_list[@]}" ; do
        echo "$action"
    done
    if [[ "$TEST_MODE" == false ]]; then
        read -p "Confirm? (y/n): " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            echo_red "Operation cancelled."
            exit 1
        fi
    fi

    for drive in "${drives[@]}"; do
        type=$(echo "$drive" | cut -d ':' -f 1)
        path=$(echo "$drive" | cut -d ':' -f 2-)
        target_dir="$BASE_MNT_POINT/$type"
        if [[ "$MODE" == "mount" ]]; then
            if [[ "$TEST_MODE" == true ]]; then
                if [[ -f "$path" ]]; then
                    echo "TEST: Would create $target_dir if not exist"
                    echo "TEST: Would mount $path to $target_dir (loop device)"
                elif [[ -d "$path" ]]; then
                    echo "TEST: Would create softlink from $path to $target_dir"
                fi
            else
                run_cmd mkdir -p "$target_dir"
                if [[ -f "$path" ]]; then  # Mount raw disk image
                    run_cmd mount -o loop "$path" "$target_dir"
                    echo_green "Mounted $path to $target_dir (loop device)"
                elif [[ -d "$path" ]]; then  # Create softlink for ZFS
                    run_cmd ln -sfn "$path" "$target_dir"
                    echo_green "Created softlink from $path to $target_dir"
                fi
            fi
        elif [[ "$MODE" == "unmount" ]]; then
            if [[ "$TEST_MODE" == true ]]; then
                echo "TEST: Would unmount $target_dir"
            else
                run_cmd umount "$target_dir"
                echo_green "Unmounted $target_dir"
            fi
        fi
    done
    debug "Exit perform_operation"
}

# Main execution
main() {
    debug "Enter main"
    debug "VMID: $VMID"
    debug "MNT_POINT: $MNT_POINT"
    debug "BASE_MNT_POINT: $BASE_MNT_POINT"
    debug "MODE: $MODE"
    debug "TEST_MODE: $TEST_MODE"
    debug "DEBUG_MODE: $DEBUG_MODE"

    if [[ "$MODE" == "mount" ]]; then
        stop_container
    fi

    perform_operation
    debug "Exit main"
}

# Run the script
main