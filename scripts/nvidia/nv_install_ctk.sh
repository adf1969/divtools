#!/bin/bash

# Script: nv_install_ctk.sh
# Description: Installs NVIDIA Container Toolkit for GPU access in Docker.
# Last Updated: 10/21/2025 12:45 PM CDT

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

# Function: check_vm_environment
# Description: Checks if running in Ubuntu VM guest; warns and confirms if on Proxmox host.
check_vm_environment() {
    if [ -f /etc/pve/.version ] || command -v pveversion &> /dev/null; then
        log "ERROR: WARNING: This script should ONLY be run in the Ubuntu VM guest. Running it on the Proxmox host may cause Docker conflicts or instability."
        confirm_operation "Do you still want to proceed? (Strongly not recommended)"
        return 0  # Proceed if confirmed, but user is warned
    else
        log "INFO: Running in VM guest environment - proceeding."
        return 0
    fi
}

# Function: install_nvidia_ctk
# Description: Adds GPG key, repo, installs toolkit, configures runtime, restarts Docker (stubbed in test mode).
install_nvidia_ctk() {
    local keyring_path="/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg"
    local repo_list_path="/etc/apt/sources.list.d/nvidia-container-toolkit.list"

    if $TEST_MODE; then
        log "INFO: [TEST] Would download GPG key to $keyring_path"
        log "INFO: [TEST] Would add repo to $repo_list_path"
        log "INFO: [TEST] Would run: sudo apt update && sudo apt install nvidia-container-toolkit -y"
        log "INFO: [TEST] Would run: sudo nvidia-ctk runtime configure --runtime=docker"
        log "INFO: [TEST] Would run: sudo systemctl restart docker"
        return 0
    fi

    if $DEBUG_MODE; then
        log "DEBUG: Downloading GPG key..."
    fi
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o "$keyring_path"
    if [ $? -ne 0 ]; then
        log "ERROR: Failed to download GPG key"
        return 1
    fi

    if $DEBUG_MODE; then
        log "DEBUG: Setting up repo list..."
    fi
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
        sed 's#deb https://#deb [signed-by='"$keyring_path"'] https://#g' | \
        sudo tee "$repo_list_path" > /dev/null
    if [ $? -ne 0 ]; then
        log "ERROR: Failed to add repo"
        return 1
    fi

    if $DEBUG_MODE; then
        log "DEBUG: Updating apt and installing toolkit..."
    fi
    sudo apt update
    sudo apt install nvidia-container-toolkit -y
    if [ $? -ne 0 ]; then
        log "ERROR: Failed to install nvidia-container-toolkit"
        return 1
    fi

    if $DEBUG_MODE; then
        log "DEBUG: Configuring Docker runtime..."
    fi
    sudo nvidia-ctk runtime configure --runtime=docker
    if [ $? -ne 0 ]; then
        log "ERROR: Failed to configure runtime"
        return 1
    fi

    if $DEBUG_MODE; then
        log "DEBUG: Restarting Docker..."
    fi
    sudo systemctl restart docker
    if [ $? -ne 0 ]; then
        log "ERROR: Failed to restart Docker"
        return 1
    fi

    log "INFO: NVIDIA Container Toolkit installed and configured successfully."
    return 0
}

# Main execution
main() {
    parse_args "$@"
    if $DEBUG_MODE; then
        log "DEBUG: Test mode: $TEST_MODE, Debug mode: $DEBUG_MODE"
    fi

    check_vm_environment

    confirm_operation "This will install NVIDIA Container Toolkit and restart Docker services."

    if install_nvidia_ctk; then
        log "INFO: Script completed successfully."
        echo "No reboot required; Docker has been restarted."
    else
        log "ERROR: Script failed."
        exit 1
    fi
}

# Run main if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi