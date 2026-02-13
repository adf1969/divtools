#!/bin/bash
# Install dependencies for dtpyutil (using venv with editable install)
# Last Updated: 01/14/2026 12:40:00 PM CDT

# Ensure DIVTOOLS is set for absolute path resolution
export DIVTOOLS="${DIVTOOLS:-/opt/divtools}"
source "$DIVTOOLS/scripts/util/logging.sh"

VENV_BASE="$DIVTOOLS/scripts/venvs"
VENV_NAME="dtpyutil"
VENV_PATH="$VENV_BASE/$VENV_NAME"
PYTHON_CMD="$VENV_PATH/bin/python"
PIP_CMD="$VENV_PATH/bin/pip"
DTPYUTIL_PROJECT="$DIVTOOLS/projects/dtpyutil"

check_venv_ready() {
    if [[ -x "$PYTHON_CMD" ]]; then
        # Check if textual is installed in this venv
        if "$PYTHON_CMD" -c "from textual.app import App, ComposeResult" &>/dev/null; then
             local version=$("$PYTHON_CMD" -c "import textual; print(textual.__version__)")
             log "INFO" "dtpyutil environment ready (Textual v$version) at $VENV_PATH"
             
             # Check if dtpyutil is installed in editable mode
             if "$PIP_CMD" show dtpyutil &>/dev/null; then
                 local editable_path=$("$PIP_CMD" show dtpyutil | grep Location | awk '{print $2}')
                 log "INFO" "dtpyutil package installed (editable) from $editable_path"
             else
                 log "WARN" "dtpyutil package not installed yet (will install in editable mode)"
                 return 1
             fi
             return 0
        fi
    fi
    return 1
}

create_venv() {
    log "INFO" "Creating virtual environment at $VENV_PATH..."
    
    # Ensure venv base dir exists
    mkdir -p "$VENV_BASE"
    
    # Check if python3-venv is available
    if ! dpkg -s python3-venv &>/dev/null && [[ -f /etc/debian_version ]]; then
         log "WARN" "python3-venv might be missing."
         read -p "Install python3-venv? [y/N] " -n 1 -r
         echo
         if [[ $REPLY =~ ^[Yy]$ ]]; then
             sudo apt-get update && sudo apt-get install -y python3-venv
         fi
    fi

    # Create venv
    if python3 -m venv "$VENV_PATH"; then
        log "INFO" "Virtual environment created."
    else
        log "ERROR" "Failed to create venv. Check permissions or install python3-venv."
        exit 1
    fi
}

install_packages() {
    log "INFO" "Installing packages into venv..."
    
    # Upgrade pip first
    log "INFO" "Upgrading pip..."
    "$PIP_CMD" install --upgrade pip
    
    # Install core dependencies
    log "INFO" "Installing Textual (TUI framework)..."
    if ! "$PIP_CMD" install textual; then
        log "ERROR" "Failed to install Textual."
        exit 1
    fi
    
    # Install pytest for testing
    log "INFO" "Installing pytest (testing framework)..."
    if ! "$PIP_CMD" install pytest pytest-cov; then
        log "WARN" "Failed to install pytest (non-critical)."
    fi
    
    # Install setuptools if not present (needed for editable install)
    log "INFO" "Ensuring setuptools is available..."
    "$PIP_CMD" install --upgrade setuptools
    
    log "INFO" "Core packages installed successfully."
}

install_dtpyutil_editable() {
    log "INFO" "Installing dtpyutil in editable mode..."
    log "DEBUG" "Project path: $DTPYUTIL_PROJECT"
    
    # Install dtpyutil package in editable mode
    # This allows live editing - changes to src/ take effect immediately
    if "$PIP_CMD" install -e "$DTPYUTIL_PROJECT"; then
        log "INFO" "dtpyutil installed in editable mode."
        log "INFO" "You can now import: from dtpyutil.menu import DtpMenuApp"
        log "INFO" "Changes to $DTPYUTIL_PROJECT/src/ take effect immediately (no reinstall needed)."
    else
        log "ERROR" "Failed to install dtpyutil in editable mode."
        exit 1
    fi
}

create_venv_symlink() {
    # Create symlink from project to venv for convenience
    local symlink_path="$DTPYUTIL_PROJECT/venv"
    if [[ ! -L "$symlink_path" ]]; then
        log "INFO" "Creating symlink: venv -> $VENV_PATH"
        ln -s "$VENV_PATH" "$symlink_path"
    fi
}

main() {
    log "HEAD" "Setting up dtpyutil Environment"
    
    if check_venv_ready; then
        log "INFO" "Environment is already up to date."
        log "INFO" "To force reinstall, delete $VENV_PATH and run again."
    else
        if [[ ! -d "$VENV_PATH" ]]; then
            create_venv
        fi
        
        install_packages
        install_dtpyutil_editable
        create_venv_symlink
        
        if check_venv_ready; then
            log "INFO" "✅ Setup complete!"
            log "INFO" ""
            log "INFO" "Next steps:"
            log "INFO" "  1. Test import: $PYTHON_CMD -c 'from dtpyutil.menu import DtpMenuApp'"
            log "INFO" "  2. Run tests: $PYTHON_CMD -m pytest $DTPYUTIL_PROJECT/test/"
            log "INFO" "  3. Use in other projects: PYTHON_CMD=$PYTHON_CMD"
        else
            log "ERROR" "Setup failed. Environment still not ready."
            exit 1
        fi
    fi
}

main
