#!/bin/bash

# Script to add an NFS mount to /etc/fstab and manage dependencies
# Usage: add_nfs_mount.sh -mp <mount-point-dir> -nfs-host <nfs-host> -nfs-path <nfs-mount-path> [-test]

# Source divtools environment if available
if [ -f "$HOME/.env" ]; then
    . "$HOME/.env"
fi
DIVTOOLS="${DIVTOOLS:-/mnt/tpool/NFS/opt/divtools}"

# Source divtools functions if available
if [ -f "$DIVTOOLS/dotfiles/.bash_aliases" ]; then
    . "$DIVTOOLS/dotfiles/.bash_aliases"
fi
if [ -f "$DIVTOOLS/divtools_install.sh" ]; then
    . "$DIVTOOLS/divtools_install.sh"
fi

# Default variables
MOUNT_POINT=""
NFS_HOST=""
NFS_PATH=""
TEST_MODE=false

# Function to output in red text (from divtools_install.sh)
echo_red() {
    echo -e "\033[0;31m$1\033[0m"
}

# Function to output in green text (from divtools_install.sh)
echo_green() {
    echo -e "\033[0;32m$1\033[0m"
}

# Check if a command is available (from divtools_install.sh)
is_installed() {
    command -v "$1" >/dev/null 2>&1
}

# Check if the script is run as root or a non-root user (from divtools_install.sh)
run_cmd() {
    if [[ $EUID -ne 0 ]]; then
        sudo "$@"
    else
        "$@"
    fi
}

# Function to display usage
usage() {
    echo "Usage: $0 -mp <mount-point-dir> -nfs-host <nfs-host> -nfs-path <nfs-mount-path> [-test]"
    echo "  -mp <mount-point-dir>  : Local directory to mount NFS share (e.g., /mnt/nfs/divtools)"
    echo "  -nfs-host <nfs-host>   : NFS server hostname or IP (e.g., 10.1.1.71)"
    echo "  -nfs-path <nfs-path>   : NFS export path on server (e.g., /mnt/tpool/sys/u-shared)"
    echo "  -test                  : Dry-run mode, outputs actions without executing"
    exit 1
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -mp)
            MOUNT_POINT="$2"
            shift 2
            ;;
        -nfs-host)
            NFS_HOST="$2"
            shift 2
            ;;
        -nfs-path)
            NFS_PATH="$2"
            shift 2
            ;;
        -test)
            TEST_MODE=true
            shift
            ;;
        *)
            echo_red "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate arguments
if [[ -z "$MOUNT_POINT" || -z "$NFS_HOST" || -z "$NFS_PATH" ]]; then
    echo_red "Missing required arguments"
    usage
fi

# Ensure NFS client is installed
check_nfs_client() {
    if is_installed mount.nfs; then
        echo_green "NFS client (nfs-common) is installed."
        return 0
    else
        echo_red "NFS client (nfs-common) is not installed."
        read -p "Do you want to install nfs-common now? (y/n): " install_nfs
        if [[ "$install_nfs" == "y" || "$install_nfs" == "Y" ]]; then
            if [[ "$TEST_MODE" == true ]]; then
                echo "TEST: Would run 'sudo apt update && sudo apt install nfs-common'"
            else
                run_cmd apt update
                run_cmd apt install -y nfs-common
                if is_installed mount.nfs; then
                    echo_green "Successfully installed nfs-common."
                else
                    echo_red "Failed to install nfs-common. Exiting."
                    exit 1
                fi
            fi
        else
            echo_red "NFS client installation declined. Exiting."
            exit 1
        fi
    fi
}

# Create mount point directory if it doesn't exist
create_mount_point() {
    if [[ -d "$MOUNT_POINT" ]]; then
        echo_green "Mount point $MOUNT_POINT already exists."
    else
        if [[ "$TEST_MODE" == true ]]; then
            echo "TEST: Would create directory $MOUNT_POINT"
        else
            run_cmd mkdir -p "$MOUNT_POINT"
            if [[ $? -eq 0 ]]; then
                echo_green "Created mount point $MOUNT_POINT."
            else
                echo_red "Failed to create mount point $MOUNT_POINT."
                exit 1
            fi
        fi
    fi
}

# Add NFS entry to /etc/fstab
add_fstab_entry() {
    #local fstab_entry="$NFS_HOST:$NFS_PATH $MOUNT_POINT nfs defaults,nofail,x-systemd.automount 0 0"
    local fstab_entry="$NFS_HOST:$NFS_PATH $MOUNT_POINT nfs vers=4.2,sec=sys,soft,intr,timeo=300,rsize=131072,wsize=131072,nofail,x-systemd.automount 0 0"
    
    # Check if entry already exists
    if grep -Fx "$fstab_entry" /etc/fstab >/dev/null; then
        echo_green "NFS mount entry already exists in /etc/fstab."
    else
        if [[ "$TEST_MODE" == true ]]; then
            echo "TEST: Would append to /etc/fstab: $fstab_entry"
        else
            run_cmd tee -a /etc/fstab <<< "$fstab_entry" >/dev/null
            if [[ $? -eq 0 ]]; then
                echo_green "Added NFS mount entry to /etc/fstab."
            else
                echo_red "Failed to add NFS mount entry to /etc/fstab."
                exit 1
            fi
        fi
    fi
}

# Reload systemd daemon
reload_systemd() {
    if [[ "$TEST_MODE" == true ]]; then
        echo "TEST: Would run 'systemctl daemon-reload'"
    else
        run_cmd systemctl daemon-reload
        if [[ $? -eq 0 ]]; then
            echo_green "Systemd daemon reloaded."
        else
            echo_red "Failed to reload systemd daemon."
            exit 1
        fi
    fi
}

# Output mount command
output_mount_command() {
    local mount_cmd="mount $MOUNT_POINT"
    echo_green "To mount the NFS share, run:"
    echo "$mount_cmd"
    if [[ "$TEST_MODE" == true ]]; then
        echo "TEST: Would output mount command: $mount_cmd"
    fi
}

# Main execution
main() {
    check_nfs_client
    create_mount_point
    add_fstab_entry
    reload_systemd
    output_mount_command
}

# Run the script
main