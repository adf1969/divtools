#!/bin/bash
# Installs Miniconda3 (lightweight conda distribution)
# Last Updated: 02/06/2026 10:00:00 AM CDT

# Source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../util/logging.sh"

# Default flags
TEST_MODE=0
DEBUG_MODE=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--test|-test)
            TEST_MODE=1
            log "INFO" "Running in TEST mode"
            shift
            ;;
        -d|--debug|-debug)
            DEBUG_MODE=1
            log "DEBUG" "Debug mode enabled"
            shift
            ;;
        -h|--help|-help|-u|--usage|-usage)
            cat << EOF
Usage: $(basename "$0") [OPTIONS]

OPTIONS:
  -t, --test, -test      Run in test mode (no permanent changes)
  -d, --debug, -debug    Enable debug mode
  -h, --help             Show this help message

This script installs Miniconda3, a lightweight conda distribution.
It will:
  1. Download the latest Miniconda3 installer
  2. Run the installer
  3. Initialize conda for bash
  4. Clean up the installer

EXAMPLE:
  $(basename "$0")
  $(basename "$0") --debug
EOF
            exit 0
            ;;
        *)
            log "ERROR" "Unknown option: $1"
            exit 1
            ;;
    esac
done

log "INFO" "Starting Miniconda3 installation"
log "DEBUG" "TEST_MODE=$TEST_MODE, DEBUG_MODE=$DEBUG_MODE"

# Check if conda is already installed
if command -v conda &> /dev/null; then
    log "WARN" "Conda is already installed"
    conda --version
    exit 0
fi

# Detect OS and architecture
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if [[ $(uname -m) == "x86_64" ]]; then
        INSTALLER="Miniconda3-latest-Linux-x86_64.sh"
        log "DEBUG" "Detected Linux x86_64"
    elif [[ $(uname -m) == "aarch64" ]]; then
        INSTALLER="Miniconda3-latest-Linux-aarch64.sh"
        log "DEBUG" "Detected Linux ARM64"
    else
        log "ERROR" "Unsupported architecture: $(uname -m)"
        exit 1
    fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
    if [[ $(uname -m) == "x86_64" ]]; then
        INSTALLER="Miniconda3-latest-MacOSX-x86_64.sh"
        log "DEBUG" "Detected macOS x86_64"
    elif [[ $(uname -m) == "arm64" ]]; then
        INSTALLER="Miniconda3-latest-MacOSX-arm64.sh"
        log "DEBUG" "Detected macOS ARM64"
    else
        log "ERROR" "Unsupported architecture: $(uname -m)"
        exit 1
    fi
else
    log "ERROR" "Unsupported OS: $OSTYPE"
    exit 1
fi

# Download directory
DOWNLOAD_DIR="/tmp"
INSTALLER_PATH="$DOWNLOAD_DIR/$INSTALLER"
DOWNLOAD_URL="https://repo.anaconda.com/miniconda/$INSTALLER"

log "INFO" "Downloading Miniconda3 installer"
log "DEBUG" "URL: $DOWNLOAD_URL"

if [[ $TEST_MODE -eq 1 ]]; then
    log "INFO:!ts" "[TEST] Would download: $DOWNLOAD_URL"
    log "INFO:!ts" "[TEST] Would install to: /opt/conda"
    exit 0
fi

# Download the installer
if ! wget -q "$DOWNLOAD_URL" -O "$INSTALLER_PATH"; then
    log "ERROR" "Failed to download Miniconda3 installer"
    exit 1
fi

log "INFO" "Downloaded installer to $INSTALLER_PATH"

# Run the installer (requires sudo for /opt)
log "INFO" "Running Miniconda3 installer to /opt/conda"
sudo bash "$INSTALLER_PATH" -b -p /opt/conda

if [[ $? -ne 0 ]]; then
    log "ERROR" "Miniconda3 installation failed"
    rm -f "$INSTALLER_PATH"
    exit 1
fi

log "INFO" "Miniconda3 installation completed successfully"

# Initialize conda for bash
log "INFO" "Initializing conda for bash shell"
sudo /opt/conda/bin/conda init bash

# Fix permissions so user can use conda
log "INFO" "Setting ownership of /opt/conda to current user"
sudo chown -R "$USER:$USER" /opt/conda

# Clean up installer
rm -f "$INSTALLER_PATH"
log "DEBUG" "Removed installer: $INSTALLER_PATH"

log "INFO" "Installation complete!"
log "INFO" "Conda installed to: /opt/conda"
log "INFO" "Please run: source ~/.bashrc"
log "INFO" "Then verify with: conda --version"
