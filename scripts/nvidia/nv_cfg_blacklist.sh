#!/bin/bash

# Script: nv_cfg_blacklist.sh
# Description: Blacklists Nouveau drivers for NVIDIA GPU passthrough compatibility.
# Last Updated: 10/21/2025 12:15 PM CDT

# Source divtools environment if available
if [ -f "$HOME/.env" ]; then
    . "$HOME/.env"
fi
DIVTOOLS="${DIVTOOLS:-/mnt/tpool/NFS/opt/divtools}"

# Source logging utility
source "$DIVTOOLS/scripts/util/logging.sh"

# Global flags
TEST_MODE=false
DEBUG_MODE=false

# Function: usage
# Description: Displays script usage and flags.
usage() {
    log "ERROR: Usage: $0 [-t|--test] [-d|--debug]"
    log "ERROR:   -t, --test: Test mode - stub permanent actions with logs."
    log "ERROR:   -d, --debug: Debug mode - enable verbose [DEBUG] output."
    exit 1
}

# Function: parse_args
# Description: Parses command-line arguments for flags.
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--test)
                TEST_MODE=true
                shift
                ;;
            -d|--debug)
                DEBUG_MODE=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                log "ERROR: Unknown option: $1"
                usage
                ;;
        esac
    done
}

# Function: confirm_operation
# Description: Prompts user for confirmation before proceeding.
confirm_operation() {
    local prompt="$1"
    read -p "$prompt (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "INFO: Operation cancelled by user."
        exit 0
    fi
}

# Function: check_proxmox_host
# Description: Checks if running on Proxmox host; warns and confirms if not.
check_proxmox_host() {
    if [ -f /etc/pve/.version ] || command -v pveversion &> /dev/null; then
        log "INFO: Running on Proxmox host - proceeding."
        return 0
    else
        log "ERROR: WARNING: This script should ONLY be run on the Proxmox host. Running it elsewhere (e.g., guest VM) may cause system instability or conflicts."
        confirm_operation "Do you still want to proceed? (Strongly not recommended)"
        return 0  # Proceed if confirmed, but user is warned
    fi
}

# Function: blacklist_nouveau
# Description: Creates blacklist files and updates initramfs (stubbed in test mode).
blacklist_nouveau() {
    local blacklist_file="/etc/modprobe.d/blacklist-nouveau.conf"
    local options_file="/etc/modprobe.d/nouveau.conf"

    if $TEST_MODE; then
        log "INFO: [TEST] Would create blacklist file: $blacklist_file with 'blacklist nouveau'"
        log "INFO: [TEST] Would create options file: $options_file with 'options nouveau modeset=0'"
        log "INFO: [TEST] Would run: update-initramfs -u"
        return 0
    fi

    if $DEBUG_MODE; then
        log "DEBUG: Creating blacklist file: $blacklist_file"
    fi
    echo "blacklist nouveau" | sudo tee "$blacklist_file" > /dev/null
    if [ $? -ne 0 ]; then
        log "ERROR: Failed to create $blacklist_file"
        return 1
    fi

    if $DEBUG_MODE; then
        log "DEBUG: Creating options file: $options_file"
    fi
    echo "options nouveau modeset=0" | sudo tee "$options_file" > /dev/null
    if [ $? -ne 0 ]; then
        log "ERROR: Failed to create $options_file"
        return 1
    fi

    if $DEBUG_MODE; then
        log "DEBUG: Updating initramfs..."
    fi
    sudo update-initramfs -u
    if [ $? -ne 0 ]; then
        log "ERROR: Failed to update initramfs"
        return 1
    fi

    log "INFO: Nouveau drivers blacklisted successfully."
    return 0
}

# Main execution
main() {
    parse_args "$@"
    if $DEBUG_MODE; then
        log "DEBUG: Test mode: $TEST_MODE, Debug mode: $DEBUG_MODE"
    fi

    check_proxmox_host

    confirm_operation "This will blacklist Nouveau drivers and update initramfs. A reboot is required afterward."

    if blacklist_nouveau; then
        log "INFO: Script completed successfully."
        echo "REBOOT RECOMMENDED: Please reboot the system to apply changes."
    else
        log "ERROR: Script failed."
        exit 1
    fi
}

# Run main if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi