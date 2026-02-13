#!/bin/bash
# PGAdmin User Management Utility - Unlock users, list users, and view login statistics
# Last Updated: 2/13/2026 12:00:00 PM CDT
#
# Initial Creation Instructions:
# PGAdmin doesn't have ANY way to view locked users or even unlock them via the UI.
# Therefore, this script handles that.
#
# Features:
#  -test mode that will run to test operations (include -t|--test)
#  -debug mode, that will output debug information about the script's operations (include -d|--debug)
#  -unlock <user>, that will run -unlock|--unlock to unlock all locked users (include -u|--unlock)
#  -list, that will run list all users and indicate if they are locked (include -l|--list), 
#    It should also other useful information that may not be availble in PGAdmin UI, such as last login time, failed login attempts, etc.
#  -list-locked, will list only locked users (include -ll|--list-locked)
#
# The pgadmin database is stored at: /opt/pgadmin/pgadmin4.db
# It is using sqlite, so we can use the sqlite3 command line tool to query it.
# The script checks if sqlite3 is installed, and if not, it outputs an error message and 
# installation instructions for the user to install it.

source "$(dirname "$0")/../util/logging.sh"

# Database path
PGADMIN_DB="/opt/pgadmin/pgadmin4.db"

# Script flags
TEST_MODE=0
DEBUG_MODE=0

# Function to check if sqlite3 is installed
check_sqlite3() {
    if ! command -v sqlite3 &>/dev/null; then
        log "ERROR" "sqlite3 is not installed."
        log "INFO" "Install sqlite3 with: sudo apt-get install sqlite3"
        exit 1
    fi
}

# Function to check if pgadmin database exists
check_pgadmin_db() {
    if [[ ! -f "$PGADMIN_DB" ]]; then
        log "ERROR" "PGAdmin database not found at $PGADMIN_DB"
        log "INFO" "Try running with sudo: sudo $0 $@"
        exit 1
    fi
    
    # Check if we have read permission
    if [[ ! -r "$PGADMIN_DB" ]]; then
        log "ERROR" "No read permission for $PGADMIN_DB"
        log "INFO" "Try running with sudo: sudo $0 $@"
        exit 1
    fi
}

# Function to list all users
list_all_users() {
    log "INFO" "Listing all PGAdmin users..."
    
    if [ "$TEST_MODE" -eq 1 ]; then
        log "INFO" "TEST MODE: Would query all users from $PGADMIN_DB"
        return
    fi
    
    # Query user table for user information
    sqlite3 "$PGADMIN_DB" <<EOF
.mode column
.headers on
SELECT 
    id,
    username,
    email,
    active,
    locked,
    CASE WHEN locked = 1 THEN 'LOCKED' ELSE 'UNLOCKED' END as status,
    login_attempts,
    auth_source
FROM "user"
ORDER BY username;
EOF
    
    if [ $? -ne 0 ]; then
        log "ERROR" "Failed to query PGAdmin database"
        return 1
    fi
}

# Function to list only locked users
list_locked_users() {
    log "INFO" "Listing locked PGAdmin users..."
    
    if [ "$TEST_MODE" -eq 1 ]; then
        log "INFO" "TEST MODE: Would query locked users from $PGADMIN_DB"
        return
    fi
    
    # Query for locked users
    sqlite3 "$PGADMIN_DB" <<EOF
.mode column
.headers on
SELECT 
    id,
    username,
    email,
    active,
    locked,
    'LOCKED' as status,
    login_attempts,
    auth_source
FROM "user"
WHERE locked = 1
ORDER BY username;
EOF
    
    if [ $? -ne 0 ]; then
        log "ERROR" "Failed to query PGAdmin database for locked users"
        return 1
    fi
}

# Function to unlock a specific user
unlock_user() {
    local username="$1"
    
    if [[ -z "$username" ]]; then
        log "ERROR" "Please provide a username to unlock"
        log "INFO" "Usage: $0 --unlock <username>"
        return 1
    fi
    
    log "INFO" "Unlocking user: $username"
    
    if [ "$TEST_MODE" -eq 1 ]; then
        log "INFO" "TEST MODE: Would unlock user '$username' in $PGADMIN_DB"
        return
    fi
    
    # Update the locked status for the user
    sqlite3 "$PGADMIN_DB" <<EOF
UPDATE "user"
SET locked = 0,
    login_attempts = 0
WHERE username = '$username';
EOF
    
    if [ $? -ne 0 ]; then
        log "ERROR" "Failed to unlock user $username"
        return 1
    fi
    
    log "INFO" "Successfully unlocked user: $username"
}

# Function to unlock all locked users
unlock_all_users() {
    log "INFO" "Unlocking all locked users..."
    
    if [ "$TEST_MODE" -eq 1 ]; then
        log "INFO" "TEST MODE: Would unlock all locked users in $PGADMIN_DB"
        return
    fi
    
    # Update all locked users
    sqlite3 "$PGADMIN_DB" <<EOF
UPDATE "user"
SET locked = 0,
    login_attempts = 0
WHERE locked = 1;
EOF
    
    if [ $? -ne 0 ]; then
        log "ERROR" "Failed to unlock users"
        return 1
    fi
    
    log "INFO" "Successfully unlocked all locked users"
}

# Function to display usage
usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

OPTIONS:
    -l, --list              List all PGAdmin users with status and login info
    -ll, --list-locked      List only locked PGAdmin users
    -u, --unlock [USER]     Unlock a specific user (or all if no user specified)
    -t, --test              Run in test mode (no permanent changes)
    -d, --debug             Enable debug output
    -h, --help              Display this help message

EXAMPLES:
    $0 --list                  # List all users
    $0 --list-locked           # List locked users only
    $0 --unlock admin          # Unlock the 'admin' user
    $0 --unlock                # Unlock all locked users
    $0 --list --test           # Test: preview user list
    $0 --unlock admin --test   # Test: preview unlock of 'admin'

EOF
}

# Main function
main() {
    # Check dependencies
    check_sqlite3
    check_pgadmin_db
    
    # Parse arguments
    local action=""
    local target_user=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -t|--test)
                TEST_MODE=1
                log "INFO" "Test mode enabled - no changes will be made"
                shift
                ;;
            -d|--debug)
                DEBUG_MODE=1
                log "DEBUG" "Debug mode enabled"
                shift
                ;;
            -l|--list)
                action="list_all"
                shift
                ;;
            -ll|--list-locked)
                action="list_locked"
                shift
                ;;
            -u|--unlock)
                action="unlock"
                shift
                # Check if next argument is a username (doesn't start with -)
                if [[ -n "$1" && ! "$1" =~ ^- ]]; then
                    target_user="$1"
                    shift
                fi
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log "ERROR" "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Execute the specified action
    case "$action" in
        list_all)
            list_all_users
            ;;
        list_locked)
            list_locked_users
            ;;
        unlock)
            if [[ -n "$target_user" ]]; then
                unlock_user "$target_user"
            else
                unlock_all_users
            fi
            ;;
        *)
            log "ERROR" "No action specified"
            usage
            exit 1
            ;;
    esac
}

# Script entry point
main "$@"
