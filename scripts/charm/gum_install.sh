#!/bin/bash
# Installs Charm's gum CLI tool to /usr/local/bin
# Last Updated: 01/12/2026 11:30:00 AM CDT

# Source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../util/logging.sh"

# Default flags
TEST_MODE=0
DEBUG_MODE=0
GUM_VERSION="0.17.0"
INSTALL_PATH="/usr/local/bin"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -test|--test)
            TEST_MODE=1
            log "INFO" "Running in TEST mode - no permanent changes will be made"
            shift
            ;;
        -debug|--debug)
            DEBUG_MODE=1
            log "DEBUG" "Debug mode enabled"
            shift
            ;;
        -v|--version)
            GUM_VERSION="$2"
            log "DEBUG" "Custom gum version specified: $GUM_VERSION"
            shift 2
            ;;
        -h|--help)
            cat << 'EOF'
Usage: gum_install.sh [OPTIONS]

Install Charm's gum CLI tool to /usr/local/bin

Options:
  -test, --test         Run in test mode (no changes made)
  -debug, --debug       Enable debug output
  -v, --version VER     Install specific version (default: 0.14.1)
  -h, --help            Show this help message

Examples:
  gum_install.sh                    # Install latest tested version (0.17.0)
  gum_install.sh -v 0.15.0          # Install specific version
  gum_install.sh -test              # Test run, show what would happen
  gum_install.sh -debug             # Enable debug logging

EOF
            exit 0
            ;;
        *)
            log "ERROR" "Unknown option: $1"
            exit 1
            ;;
    esac
done

log "INFO" "Gum Installer - Version $GUM_VERSION"
log "DEBUG" "TEST_MODE=$TEST_MODE, DEBUG_MODE=$DEBUG_MODE"

# Detect system architecture
detect_arch() {
    local arch=$(uname -m)
    case "$arch" in
        x86_64)
            echo "x86_64"
            ;;
        aarch64|arm64)
            echo "arm64"
            ;;
        armv7l)
            echo "armv7"
            ;;
        *)
            log "ERROR" "Unsupported architecture: $arch"
            return 1
            ;;
    esac
}

# Main installation
main() {
    log "INFO" "========== Starting Gum Installation =========="
    
    # Get architecture
    ARCH=$(detect_arch)
    if [[ $? -ne 0 ]]; then
        log "ERROR" "Failed to detect system architecture"
        return 1
    fi
    log "DEBUG" "Detected architecture: $ARCH"
    
    # Check if gum is already installed
    if command -v gum &> /dev/null; then
        CURRENT_VERSION=$(gum --version | awk '{print $NF}')
        log "INFO" "Gum is already installed: $CURRENT_VERSION"
        
        if [[ "$CURRENT_VERSION" == "$GUM_VERSION" ]]; then
            log "INFO" "✓ Correct version already installed. Nothing to do."
            return 0
        else
            log "INFO" "Installing version $GUM_VERSION (currently have $CURRENT_VERSION)"
        fi
    fi
    
    # Build download URL - use proper GitHub release asset format
    local download_url="https://github.com/charmbracelet/gum/releases/download/v${GUM_VERSION}/gum_${GUM_VERSION}_linux_${ARCH}.tar.gz"
    log "DEBUG" "Download URL: $download_url"
    
    # Create temporary directory
    local temp_dir="/tmp/gum-install-$$"
    mkdir -p "$temp_dir"
    local temp_file="$temp_dir/gum_${GUM_VERSION}_linux_${ARCH}.tar.gz"
    log "DEBUG" "Temporary file: $temp_file"
    
    # Download gum
    log "INFO" "Downloading gum v${GUM_VERSION} for ${ARCH}..."
    
    if [[ $TEST_MODE -eq 1 ]]; then
        log "TEST" "Would download from: $download_url"
        log "TEST" "Would save to: $temp_file"
        log "TEST" "Would extract and install to: $INSTALL_PATH/gum"
        log "INFO" "Test mode: Installation would succeed"
        return 0
    fi
    
    # Download with curl
    if ! curl -sSL "$download_url" -o "$temp_file" 2>/dev/null; then
        log "ERROR" "Failed to download gum from: $download_url"
        log "ERROR" "Check your internet connection and verify the version exists"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Extract tar.gz
    log "DEBUG" "Extracting tar.gz..."
    if ! tar -xzf "$temp_file" -C "$temp_dir"; then
        log "ERROR" "Failed to extract gum archive"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Find the gum binary in extracted files
    local gum_binary=$(find "$temp_dir" -name "gum" -type f 2>/dev/null | head -1)
    if [[ -z "$gum_binary" ]]; then
        log "ERROR" "Could not find gum binary in extracted archive"
        log "DEBUG" "Contents of $temp_dir:"
        ls -la "$temp_dir"
        rm -rf "$temp_dir"
        return 1
    fi
    
    temp_file="$gum_binary"
    log "DEBUG" "Found binary at: $temp_file"
    
    log "DEBUG" "Downloaded successfully, file size: $(stat -f%z "$temp_file" 2>/dev/null || stat -c%s "$temp_file")"
    
    # Make executable
    chmod +x "$temp_file"
    log "DEBUG" "Set executable bit"
    
    # Verify it's a valid binary
    if ! file "$temp_file" | grep -q "ELF\|executable"; then
        log "ERROR" "Downloaded file is not a valid executable"
        log "DEBUG" "File type: $(file "$temp_file")"
        rm -rf "$temp_dir"
        return 1
    fi
    log "DEBUG" "✓ Downloaded file verified as valid executable"
    
    # Install to /usr/local/bin
    log "INFO" "Installing gum to $INSTALL_PATH/..."
    
    if ! sudo cp "$temp_file" "$INSTALL_PATH/gum"; then
        log "ERROR" "Failed to copy gum to $INSTALL_PATH/gum"
        log "ERROR" "You may need to enter your sudo password"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Make sure it's executable
    sudo chmod +x "$INSTALL_PATH/gum"
    log "INFO" "✓ Installed to $INSTALL_PATH/gum"
    
    # Clean up temp directory
    rm -rf "$temp_dir"
    
    # Verify installation
    log "INFO" "Verifying installation..."
    if ! command -v gum &> /dev/null; then
        log "ERROR" "Installation verification failed - gum not found in PATH"
        return 1
    fi
    
    local installed_version=$(gum --version 2>/dev/null | awk '{print $NF}')
    log "INFO" "✓ Gum successfully installed: $installed_version"
    
    # Show basic info
    log "INFO" "========== Installation Complete =========="
    log "INFO" "Gum is ready to use!"
    log "INFO" "Try: gum choose \"Option 1\" \"Option 2\" \"Option 3\""
    
    return 0
}

# Run main function
main
exit_code=$?

if [[ $exit_code -eq 0 ]]; then
    log "INFO" "Gum installation completed successfully"
else
    log "ERROR" "Gum installation failed with exit code $exit_code"
fi

exit $exit_code
