#!/bin/bash
# Setup script for PostgreSQL/pgAdmin user and group
# Last Updated: 11/8/2025 6:45:00 PM CST

# Source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../util/logging.sh"

# Default flags
TEST_MODE=0
DEBUG_MODE=0

# pgAdmin user/group configuration
PGADMIN_USER="pgadmin"
PGADMIN_UID=5050
PGADMIN_GID=5050

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
            log "INFO" "Usage: $0 [-test|--test] [-debug|--debug]"
            exit 1
            ;;
    esac
done

log "INFO" "Starting PostgreSQL/pgAdmin user and group setup"
log "DEBUG" "TEST_MODE=$TEST_MODE, DEBUG_MODE=$DEBUG_MODE"

# Check if running as root
if [[ $EUID -ne 0 ]] && [[ $TEST_MODE -eq 0 ]]; then
    log "ERROR" "This script must be run as root (use sudo)"
    exit 1
fi

# Check if group exists
if getent group "$PGADMIN_USER" >/dev/null 2>&1; then
    EXISTING_GID=$(getent group "$PGADMIN_USER" | cut -d: -f3)
    log "INFO" "Group '$PGADMIN_USER' already exists with GID: $EXISTING_GID"
    
    if [[ "$EXISTING_GID" != "$PGADMIN_GID" ]]; then
        log "WARN" "Existing GID ($EXISTING_GID) does not match expected GID ($PGADMIN_GID)"
        log "INFO" "You may need to modify the group manually: sudo groupmod -g $PGADMIN_GID $PGADMIN_USER"
    else
        log "DEBUG" "Group GID matches expected value"
    fi
else
    log "INFO" "Creating group '$PGADMIN_USER' with GID: $PGADMIN_GID"
    if [[ $TEST_MODE -eq 0 ]]; then
        if groupadd -g "$PGADMIN_GID" "$PGADMIN_USER"; then
            log "INFO" "Successfully created group '$PGADMIN_USER'"
        else
            log "ERROR" "Failed to create group '$PGADMIN_USER'"
            exit 1
        fi
    else
        log "INFO:!ts" "  [TEST] Would run: groupadd -g $PGADMIN_GID $PGADMIN_USER"
    fi
fi

# Check if user exists
if id "$PGADMIN_USER" >/dev/null 2>&1; then
    EXISTING_UID=$(id -u "$PGADMIN_USER")
    EXISTING_USER_GID=$(id -g "$PGADMIN_USER")
    log "INFO" "User '$PGADMIN_USER' already exists with UID: $EXISTING_UID, GID: $EXISTING_USER_GID"
    
    if [[ "$EXISTING_UID" != "$PGADMIN_UID" ]]; then
        log "WARN" "Existing UID ($EXISTING_UID) does not match expected UID ($PGADMIN_UID)"
        log "INFO" "You may need to modify the user manually: sudo usermod -u $PGADMIN_UID $PGADMIN_USER"
    else
        log "DEBUG" "User UID matches expected value"
    fi
    
    if [[ "$EXISTING_USER_GID" != "$PGADMIN_GID" ]]; then
        log "WARN" "User's primary GID ($EXISTING_USER_GID) does not match expected GID ($PGADMIN_GID)"
        log "INFO" "You may need to modify the user manually: sudo usermod -g $PGADMIN_GID $PGADMIN_USER"
    else
        log "DEBUG" "User GID matches expected value"
    fi
else
    log "INFO" "Creating user '$PGADMIN_USER' with UID: $PGADMIN_UID, GID: $PGADMIN_GID"
    if [[ $TEST_MODE -eq 0 ]]; then
        if useradd -u "$PGADMIN_UID" -g "$PGADMIN_GID" -M -s /usr/sbin/nologin -c "pgAdmin System User" "$PGADMIN_USER"; then
            log "INFO" "Successfully created user '$PGADMIN_USER'"
        else
            log "ERROR" "Failed to create user '$PGADMIN_USER'"
            exit 1
        fi
    else
        log "INFO:!ts" "  [TEST] Would run: useradd -u $PGADMIN_UID -g $PGADMIN_GID -M -s /usr/sbin/nologin -c \"pgAdmin System User\" $PGADMIN_USER"
    fi
fi

# Create pgAdmin data directories if they don't exist
PGADMIN_CONFIG_DIR="/opt/divtools/docker/sites/s01-7692nh/tnapp01/pgadmin/config"
PGADMIN_DATA_DIR="/opt/pgadmin"

log "INFO" "Checking pgAdmin directories"
log "DEBUG" "Config dir: $PGADMIN_CONFIG_DIR"
log "DEBUG" "Data dir: $PGADMIN_DATA_DIR"

for DIR in "$PGADMIN_CONFIG_DIR" "$PGADMIN_DATA_DIR"; do
    if [[ ! -d "$DIR" ]]; then
        log "INFO" "Creating directory: $DIR"
        if [[ $TEST_MODE -eq 0 ]]; then
            if mkdir -p "$DIR"; then
                log "INFO" "Successfully created directory: $DIR"
            else
                log "ERROR" "Failed to create directory: $DIR"
                exit 1
            fi
        else
            log "INFO:!ts" "  [TEST] Would run: mkdir -p $DIR"
        fi
    else
        log "DEBUG" "Directory already exists: $DIR"
    fi
    
    # Set ownership
    log "INFO" "Setting ownership of $DIR to $PGADMIN_USER:$PGADMIN_USER"
    if [[ $TEST_MODE -eq 0 ]]; then
        if chown -R "$PGADMIN_USER:$PGADMIN_USER" "$DIR"; then
            log "INFO" "Successfully set ownership"
        else
            log "ERROR" "Failed to set ownership"
            exit 1
        fi
    else
        log "INFO:!ts" "  [TEST] Would run: chown -R $PGADMIN_USER:$PGADMIN_USER $DIR"
    fi
    
    # Set permissions
    log "INFO" "Setting permissions on $DIR to 755"
    if [[ $TEST_MODE -eq 0 ]]; then
        if chmod -R 755 "$DIR"; then
            log "INFO" "Successfully set permissions"
        else
            log "ERROR" "Failed to set permissions"
            exit 1
        fi
    else
        log "INFO:!ts" "  [TEST] Would run: chmod -R 755 $DIR"
    fi
done

# Add divix user to pgadmin group
DIVIX_USER="divix"
if id "$DIVIX_USER" >/dev/null 2>&1; then
    log "INFO" "Adding user '$DIVIX_USER' to group '$PGADMIN_USER'"
    if [[ $TEST_MODE -eq 0 ]]; then
        if usermod -aG "$PGADMIN_USER" "$DIVIX_USER"; then
            log "INFO" "Successfully added '$DIVIX_USER' to group '$PGADMIN_USER'"
        else
            log "ERROR" "Failed to add '$DIVIX_USER' to group '$PGADMIN_USER'"
            exit 1
        fi
    else
        log "INFO:!ts" "  [TEST] Would run: usermod -aG $PGADMIN_USER $DIVIX_USER"
    fi
else
    log "WARN" "User '$DIVIX_USER' does not exist, skipping group membership"
fi

# Summary
log "INFO" "PostgreSQL/pgAdmin setup completed successfully"
log "INFO" "Summary:"
log "INFO:!ts" "  User: $PGADMIN_USER (UID: $PGADMIN_UID)"
log "INFO:!ts" "  Group: $PGADMIN_USER (GID: $PGADMIN_GID)"
log "INFO:!ts" "  Additional Members: $DIVIX_USER"
log "INFO:!ts" "  Config Dir: $PGADMIN_CONFIG_DIR"
log "INFO:!ts" "  Data Dir: $PGADMIN_DATA_DIR"

exit 0
