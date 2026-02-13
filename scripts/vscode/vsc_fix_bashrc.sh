#!/bin/bash
# Adds VSCode terminal compatibility fix to ~/.bashrc
# This ensures divtools .bash_profile loads in VSCode terminals (non-login shells)
# Last Updated: 11/11/2025 9:45:00 PM CDT

# Source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../util/logging.sh"

# Default flags
TEST_MODE=0
DEBUG_MODE=0

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
        *)
            log "ERROR" "Unknown option: $1"
            exit 1
            ;;
    esac
done

log "INFO" "VSCode .bashrc fix script started"
log "DEBUG" "TEST_MODE=$TEST_MODE, DEBUG_MODE=$DEBUG_MODE"

# Define the target file
BASHRC_FILE="$HOME/.bashrc"

# Check if .bashrc exists
if [ ! -f "$BASHRC_FILE" ]; then
    log "ERROR" ".bashrc not found at $BASHRC_FILE"
    exit 1
fi

log "INFO" "Found .bashrc at $BASHRC_FILE"

# Check if the fix is already installed
if grep -q "## VSCODE-FIX-START ##" "$BASHRC_FILE"; then
    log "WARN" "VSCode fix is already installed in $BASHRC_FILE"
    log "INFO" "No changes needed. Exiting."
    exit 0
fi

log "INFO" "VSCode fix not found. Installing..."

# Define the fix code block
read -r -d '' VSCODE_FIX << 'EOF'

## VSCODE-FIX-START ##
# VSCode terminal compatibility fix
# VSCode integrated terminal runs as non-login shell (bash -i) which only sources .bashrc
# Regular SSH/console login runs as login shell (bash --login) which sources /etc/profile
# /etc/profile sources the centralized divtools .bash_profile
# This check ensures divtools .bash_profile loads in VSCode WITHOUT double-loading in regular shells
# Last Updated: 11/11/2025 9:45:00 PM CDT
if [ -z "$BASH_PROFILE_LOADED" ] && [ -f "/opt/divtools/dotfiles/.bash_profile" ]; then
    export BASH_PROFILE_LOADED=1
    source "/opt/divtools/dotfiles/.bash_profile"
fi
## VSCODE-FIX-END ##
EOF

# Create backup
BACKUP_FILE="${BASHRC_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

if [ $TEST_MODE -eq 1 ]; then
    log "INFO:!ts" "[TEST MODE] Would create backup: $BACKUP_FILE"
    log "INFO:!ts" "[TEST MODE] Would insert VSCode fix after the first non-comment, non-blank line"
    log "DEBUG" "Fix code block:"
    echo "$VSCODE_FIX"
    exit 0
fi

# Create backup
cp "$BASHRC_FILE" "$BACKUP_FILE"
log "INFO" "Created backup at $BACKUP_FILE"

# Insert the fix after the first non-comment, non-blank line (typically after the shebang or first comment)
# This ensures it runs early but after any initial setup
awk -v fix="$VSCODE_FIX" '
BEGIN { inserted = 0 }
{
    print $0
    # Insert after the first non-comment, non-blank line
    if (!inserted && NF > 0 && $0 !~ /^[[:space:]]*#/ && $0 !~ /^[[:space:]]*$/) {
        print fix
        inserted = 1
    }
}
# If we never found a good spot (file is all comments), append at end
END {
    if (!inserted) {
        print fix
    }
}' "$BASHRC_FILE" > "${BASHRC_FILE}.tmp"

# Replace original with modified version
mv "${BASHRC_FILE}.tmp" "$BASHRC_FILE"

log "INFO" "VSCode fix successfully installed in $BASHRC_FILE"
log "INFO" "Backup saved at $BACKUP_FILE"
log "HEAD" "✓ VSCode terminal fix applied successfully!"
log "INFO" "To activate: Open a new VSCode terminal or run: source ~/.bashrc"

exit 0
