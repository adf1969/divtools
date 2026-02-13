#!/bin/bash
# Install dependencies for dtpmenu (using venv)
# Last Updated: 01/13/2026 14:05:00 PM CDT

source "$(dirname "$0")/../../scripts/util/logging.sh"

VENV_BASE="$DIVTOOLS/scripts/venvs"
VENV_NAME="dtpmenu"
VENV_PATH="$VENV_BASE/$VENV_NAME"
PYTHON_CMD="$VENV_PATH/bin/python"
PIP_CMD="$VENV_PATH/bin/pip"

check_venv_ready() {
    if [[ -x "$PYTHON_CMD" ]]; then
        # Check if textual is installed in this venv with modern features
        if "$PYTHON_CMD" -c "from textual.app import App, ComposeResult" &>/dev/null; then
             local version=$("$PYTHON_CMD" -c "import textual; print(textual.__version__)")
             log "INFO" "dtpmenu environment ready (v$version) at $VENV_PATH"
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
    log "INFO" "Installing Textual into venv..."
    
    # Install textual in the venv
    if "$PIP_CMD" install --upgrade textual; then
        log "INFO" "Textual installed successfully."
    else
        log "ERROR" "Failed to install packages."
        exit 1
    fi
}

main() {
    log "HEAD" "Setting up dtpmenu Environment"
    
    if check_venv_ready; then
        log "INFO" "Environment is already up to date."
        # Optional: Ask to force update?
    else
        if [[ ! -d "$VENV_PATH" ]]; then
            create_venv
        fi
        install_packages
        
        if check_venv_ready; then
            log "INFO" "Setup complete!"
        else
            log "ERROR" "Setup failed. Textual still not detected."
            exit 1
        fi
    fi
}

main
