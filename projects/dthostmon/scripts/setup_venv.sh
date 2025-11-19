#!/bin/bash
# setup_venv.sh
# Creates and configures the dthostmon virtual environment in the centralized location
# Last Updated: 11/18/2025 10:30:00 PM CST

# Source logging utilities from divtools scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DIVTOOLS="${DIVTOOLS:-/home/divix/divtools}"

# Try to source divtools logging, fallback to basic logging
if [[ -f "$DIVTOOLS/scripts/util/logging.sh" ]]; then
    source "$DIVTOOLS/scripts/util/logging.sh"
else
    # Fallback logging functions
    log() {
        local level="$1"
        shift
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*"
    }
fi

VENV_NAME="dthostmon"
VENV_DIR="$DIVTOOLS/scripts/venvs/$VENV_NAME"

log "INFO" "Setting up virtual environment for dthostmon"
log "INFO" "Target location: $VENV_DIR"

# Check if python3-venv is installed
if ! python3 -m venv --help &>/dev/null; then
    log "ERROR" "python3-venv is not installed on this system"
    log "INFO" "You have two options:"
    log "INFO" ""
    log "INFO" "Option 1: Install python3-venv (recommended)"
    log "INFO" "  sudo apt install python3-venv"
    log "INFO" "  Then re-run this script"
    log "INFO" ""
    log "INFO" "Option 2: Use the python_venv_create function"
    log "INFO" "  python_venv_create $VENV_NAME"
    log "INFO" "  OR"
    log "INFO" "  pvcr $VENV_NAME"
    log "INFO" "  Then manually install requirements:"
    log "INFO" "  pvact $VENV_NAME"
    log "INFO" "  pip install -r $PROJECT_ROOT/requirements.txt"
    log "INFO" "  pip install -r $PROJECT_ROOT/requirements-dev.txt"
    exit 1
fi

# Check if venv already exists
if [[ -d "$VENV_DIR" ]]; then
    log "WARN" "Virtual environment already exists at: $VENV_DIR"
    read -r -p "Do you want to delete and recreate it? [y/N] " response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        log "INFO" "Deleting existing venv"
        rm -rf "$VENV_DIR"
    else
        log "INFO" "Keeping existing venv - will attempt to install/update requirements"
    fi
fi

# Create venv if it doesn't exist
if [[ ! -d "$VENV_DIR" ]]; then
    log "INFO" "Creating virtual environment: $VENV_NAME"
    python3 -m venv "$VENV_DIR"
    
    if [[ $? -ne 0 ]]; then
        log "ERROR" "Failed to create virtual environment"
        log "INFO" "Try using: python_venv_create $VENV_NAME"
        exit 1
    fi
    
    log "INFO" "Virtual environment created successfully"
fi

# Activate the venv
log "INFO" "Activating virtual environment"
source "$VENV_DIR/bin/activate"

if [[ $? -ne 0 ]]; then
    log "ERROR" "Failed to activate virtual environment"
    exit 1
fi

# Upgrade pip
log "INFO" "Upgrading pip"
pip install --upgrade pip

# Install requirements
if [[ -f "$PROJECT_ROOT/requirements.txt" ]]; then
    log "INFO" "Installing requirements from requirements.txt"
    pip install -r "$PROJECT_ROOT/requirements.txt"
    
    if [[ $? -ne 0 ]]; then
        log "ERROR" "Failed to install requirements"
        exit 1
    fi
else
    log "WARN" "requirements.txt not found at $PROJECT_ROOT/requirements.txt"
fi

# Install dev requirements if they exist
if [[ -f "$PROJECT_ROOT/requirements-dev.txt" ]]; then
    log "INFO" "Installing dev requirements from requirements-dev.txt"
    pip install -r "$PROJECT_ROOT/requirements-dev.txt"
    
    if [[ $? -ne 0 ]]; then
        log "WARN" "Failed to install dev requirements"
    fi
fi

log "INFO" "Setup complete!"
log "INFO" ""
log "INFO" "To activate this venv in the future, use:"
log "INFO" "  python_venv_activate $VENV_NAME"
log "INFO" "  OR"
log "INFO" "  pvact $VENV_NAME"
log "INFO" ""
log "INFO" "To list all available venvs:"
log "INFO" "  python_venv_ls"
log "INFO" "  OR"
log "INFO" "  pvls"
