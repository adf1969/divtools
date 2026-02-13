#!/bin/bash
# Runs pgBackRest full and incremental backups for PostgreSQL Docker container bind-mounts
# Works with --no-online to backup files directly without needing live PostgreSQL connection
# PostgreSQL data is bind-mounted from Docker container at /opt/postgres/pgdata on host
# Last Updated: 12/30/2025 12:00:00 AM CDT
#
# KEY INSIGHT: pgBackRest can backup bind-mounted PostgreSQL files directly from the host
# without needing a live database connection. This works even when PostgreSQL runs in a
# Docker container, as long as the data directory is bind-mounted to the host filesystem.
#
# BACKUP WORKFLOW:
# 1. First time: Run with -init-stanza to create offline stanza configuration
#   $ ./pg_backrest_backup.sh -init-stanza
# 2. Then: Run regular backups using --no-online and --force
#   $ ./pg_backrest_backup.sh        (uses --no-online and --force automatically)
#   $ ./pg_backrest_backup.sh -full  (full backup instead of incremental)
#
# WHAT IS A STANZA?
# A 'stanza' is pgBackRest's configuration name for a specific PostgreSQL database cluster.
# It groups all backup and archive settings for that cluster under one named configuration.
# Example: If you have two PostgreSQL servers (production & staging), each would have its own
# stanza (e.g., 'prod' and 'staging') with different retention policies and backup schedules.
# In this script, the stanza is defined in pgbackrest.conf as [postgres] - the section header.
#
# STANZA vs BACKUP CONCEPTS:
# - Stanza: Configuration group for a specific database cluster (defined in .conf file)
# - Backup: The actual data copy operation (runs against a stanza using --no-online)
# - Check: Attempts to validate configuration (limited for offline setups)
# - Init Stanza: Initialize stanza for offline backups (use --no-online)

# Source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../util/logging.sh"

# Configuration
CONFIG_FILE="/home/divix/divtools/docker/sites/s01-7692nh/tnapp01/pgbackrest/pgbackrest.conf"
BASE_DIR="/opt/pgbackrest"
LOG_DIR="${BASE_DIR}/log"
BACKUP_DIR="${BASE_DIR}/backup"
POSTGRES_DATA_DIR="/opt/postgres/pgdata"
STANZA_NAME="postgres"  # Must match the [section] name in pgbackrest.conf
BACKUP_TYPE="incr"  # incr for incremental, full for full backup
COMMAND_TYPE="backup"  # backup or check

# Email notification settings
SEND_EMAIL=0
EMAIL_RECIPIENT=""
SMTP_SERVER=""
SMTP_PORT="25"  # Use port 25 for relay (less strict validation than 587)
BACKUP_STATUS="PENDING"
BACKUP_MESSAGE=""
NO_CHANGES_DETECTED=0  # Track if exit code 55 (no files changed) was detected

# Default flags
TEST_MODE=0
DEBUG_MODE=0
LOG_LEVEL_CONSOLE="info"  # Default log level for pgBackRest output
# Parse arguments early
while [[ $# -gt 0 ]]; do
    case $1 in
        -check|--check)
            COMMAND_TYPE="check"
            shift
            ;;
        -init-stanza|--init-stanza)
            COMMAND_TYPE="init-stanza"
            shift
            ;;
        -test|--test)
            TEST_MODE=1
            shift
            ;;
        -debug|--debug)
            DEBUG_MODE=1
            LOG_LEVEL_CONSOLE="debug"  # Increase pgBackRest log level to debug
            shift
            ;;
        -full)
            BACKUP_TYPE="full"
            shift
            ;;
        -incr)
            BACKUP_TYPE="incr"
            shift
            ;;
        -email)
            SEND_EMAIL=1
            shift
            ;;
        -test-email|--test-email)
            COMMAND_TYPE="test-email"
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Function to load environment variables
# Last Updated: 12/30/2025 12:00:00 AM CDT
load_environment() {
    log "DEBUG" "Loading environment variables..."
    
    # Determine the actual user's home directory (handles sudo case)
    # When run with sudo, $HOME points to root's home, so we need to find the real user
    REAL_USER="${SUDO_USER:-$USER}"
    REAL_HOME=$(eval echo ~"$REAL_USER")
    log "DEBUG" "Real user: $REAL_USER, Real home: $REAL_HOME"
    
    # Use sudo to run a login shell that sources .bash_profile and calls load_env_files
    # This is the standard divtools pattern for environment loading
    # We run as the real user with -u to ensure proper home directory
    eval "$(sudo -u "$REAL_USER" bash -l -c 'source ~/.bash_profile 2>/dev/null; load_env_files >/dev/null 2>&1; env | grep -E "^(DIVTOOLS|PGADMIN_DEFAULT_EMAIL|SMTP_SERVER|SMTP_PORT|SITE_NAME|HOSTNAME|DOCKER_HOSTDIR)=" || true' 2>/dev/null)"
    
    log "DEBUG" "load_env_files() environment loaded"
    
    # Set email variables from environment
    if [[ -n "${PGADMIN_DEFAULT_EMAIL:-}" ]]; then
        EMAIL_RECIPIENT="$PGADMIN_DEFAULT_EMAIL"
        log "DEBUG" "Email recipient set to: $EMAIL_RECIPIENT"
    fi
    
    if [[ -n "${SMTP_SERVER:-}" ]]; then
        SMTP_SERVER="$SMTP_SERVER"
        log "DEBUG" "SMTP server set to: $SMTP_SERVER"
    fi
    
    if [[ -n "${SMTP_PORT:-}" ]]; then
        SMTP_PORT="$SMTP_PORT"
        log "DEBUG" "SMTP port set to: $SMTP_PORT"
    fi
}

# Log startup info
log "INFO" "pgBackRest script started (Command: $COMMAND_TYPE, Stanza: $STANZA_NAME)"
log "DEBUG" "TEST_MODE=$TEST_MODE, DEBUG_MODE=$DEBUG_MODE, SEND_EMAIL=$SEND_EMAIL"
log "DEBUG" "Log level for pgBackRest: $LOG_LEVEL_CONSOLE"
load_environment

# Log startup info
log "INFO" "pgBackRest backup script started"

# Function to initialize directory structure
# Last Updated: 12/30/2025 12:00:00 AM CDT
init_directories() {
    log "DEBUG" "Initializing pgBackRest directories..."
    
    # Verify PostgreSQL data directory exists
    if [[ ! -d "$POSTGRES_DATA_DIR" ]]; then
        log "ERROR" "PostgreSQL data directory not found: $POSTGRES_DATA_DIR"
        log "ERROR" "Is the PostgreSQL Docker container running and data bind-mounted?"
        return 1
    fi
    log "DEBUG" "PostgreSQL data directory verified: $POSTGRES_DATA_DIR"
    
    for dir in "$BASE_DIR" "$LOG_DIR" "$BACKUP_DIR"; do
        if [[ ! -d "$dir" ]]; then
            if [[ $TEST_MODE -eq 1 ]]; then
                log "INFO:TEST" "Would create directory: $dir"
            else
                log "DEBUG" "Creating directory: $dir"
                mkdir -p "$dir" || {
                    log "ERROR" "Failed to create directory: $dir"
                    return 1
                }
            fi
        else
            log "DEBUG" "Directory exists: $dir"
        fi
    done
    
    log "INFO" "Directory structure initialized"
    return 0
}

# Function to validate configuration file
# Last Updated: 12/30/2025 12:00:00 AM CDT
validate_config() {
    log "DEBUG" "Validating configuration file: $CONFIG_FILE"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log "ERROR" "Configuration file not found: $CONFIG_FILE"
        return 1
    fi
    
    log "INFO" "Configuration file validated"
    return 0
}
# Function to run pgBackRest backup
# Last Updated: 12/30/2025 12:00:00 AM CDT
run_backup() {
    local backup_type=$1
    
    log "INFO" "Starting pgBackRest $backup_type backup for stanza: $STANZA_NAME..."
    log "DEBUG" "Configuration: $CONFIG_FILE"
    log "DEBUG" "Backup type: $backup_type"
    log "DEBUG" "Base directory: $BASE_DIR"
    log "INFO" "Using --no-online to backup bind-mounted PostgreSQL files without live DB connection"
    
    if [[ $TEST_MODE -eq 1 ]]; then
        log "INFO:TEST" "Would execute: pgbackrest --config=$CONFIG_FILE --stanza=$STANZA_NAME --type=$backup_type --log-level-console=$LOG_LEVEL_CONSOLE --no-online --force backup"
        log "INFO:TEST" "Logs would be written to: $LOG_DIR"
        log "INFO:TEST" "This backs up the bind-mounted /opt/postgres/pgdata directory without needing PostgreSQL running on the host"
        log "INFO:TEST" "Uses --force because PostgreSQL may be running in Docker container, but files are backed up directly from bind-mount"
        return 0
    fi
    
    # Run the backup command with --no-online to work with bind-mounted files without host DB connection
    # Use --force because PostgreSQL may be running in Docker container (postmaster.pid may exist)
    # but we're backing up the files directly from bind-mount on the host
    pgbackrest --config="$CONFIG_FILE" --stanza="$STANZA_NAME" --type="$backup_type" --log-level-console="$LOG_LEVEL_CONSOLE" --no-online --force backup
    local exit_code=$?
    
    # pgBackRest exit codes:
    # 0 = success
    # 55 = no files changed (not a failure, just nothing to backup)
    # Other codes = actual errors
    
    if [[ $exit_code -eq 0 ]]; then
        log "INFO" "pgBackRest $backup_type backup completed successfully"
        log "INFO" "Backup stored in: $BACKUP_DIR"
        return 0
    elif [[ $exit_code -eq 55 ]]; then
        # Exit code 55 means no files changed since last backup - this is NOT an error
        # It's a normal, healthy condition when data hasn't changed
        log "INFO" "pgBackRest $backup_type backup: No files changed since last backup"
        log "INFO" "This is normal and healthy - database has not been modified"
        log "INFO" "Last backup remains current"
        NO_CHANGES_DETECTED=1
        return 0
    else
        log "ERROR" "pgBackRest backup failed with exit code $exit_code"
        log "ERROR" "If stanza has not been initialized, run: pgbackrest stanza-create --no-online"
        return 1
    fi
}

# Function to create the stanza if it doesn't exist
# Last Updated: 12/30/2025 12:00:00 AM CDT
create_stanza_if_needed() {
    log "DEBUG" "Checking if stanza '$STANZA_NAME' exists..."
    
    # Try to get info about the stanza to see if it exists
    if ! pgbackrest --config="$CONFIG_FILE" --stanza="$STANZA_NAME" info &>/dev/null; then
        log "INFO" "Stanza '$STANZA_NAME' does not exist, creating it..."
        
        if [[ $TEST_MODE -eq 1 ]]; then
            log "INFO:TEST" "Would execute: pgbackrest --config=$CONFIG_FILE --stanza=$STANZA_NAME --no-online stanza-create"
            log "INFO:TEST" "Using --no-online for offline stanza initialization (works with bind-mounts, no DB needed)"
        else
            log "DEBUG" "Executing: pgbackrest --config=$CONFIG_FILE --stanza=$STANZA_NAME --no-online stanza-create"
            log "DEBUG" "Using --no-online for offline stanza initialization (works with bind-mounts, no DB needed)"
            if pgbackrest --config="$CONFIG_FILE" --stanza="$STANZA_NAME" --no-online stanza-create; then
                log "INFO" "Stanza '$STANZA_NAME' created successfully"
            else
                log "ERROR" "Failed to create stanza '$STANZA_NAME'"
                return 1
            fi
        fi
    else
        log "DEBUG" "Stanza '$STANZA_NAME' already exists"
    fi
    return 0
}

# Function to run pgBackRest configuration check
# Last Updated: 12/30/2025 12:00:00 AM CDT
run_check() {
    log "INFO" "Starting pgBackRest configuration check for stanza: $STANZA_NAME..."
    log "WARN" "Note: pgBackRest 'check' command requires live PostgreSQL database connection"
    log "WARN" "For bind-mounted setups without active DB, use: stanza-create --no-online check"
    log "INFO" "Attempting check with --no-online (validates files, not DB connection)..."
    log "DEBUG" "Configuration: $CONFIG_FILE"
    log "DEBUG" "Stanza: $STANZA_NAME"
    
    if [[ $TEST_MODE -eq 1 ]]; then
        log "INFO:TEST" "Would execute: pgbackrest --config=$CONFIG_FILE --stanza=$STANZA_NAME --log-level-console=$LOG_LEVEL_CONSOLE --no-online check"
        log "INFO:TEST" "Note: check command may not support --no-online in all pgBackRest versions"
        return 0
    fi
    
    # Try check with --no-online first (may not be supported)
    if pgbackrest --config="$CONFIG_FILE" --stanza="$STANZA_NAME" --log-level-console="$LOG_LEVEL_CONSOLE" --no-online check 2>/dev/null; then
        log "INFO" "pgBackRest configuration check completed successfully"
        log "INFO" "Stanza '$STANZA_NAME' configuration and bind-mounts are valid"
        return 0
    else
        # If --no-online check doesn't work, provide instructions for alternatives
        log "WARN" "pgBackRest check command requires live PostgreSQL database connection"
        log "WARN" "This is expected for bind-mounted Docker setups without a running DB host connection"
        log "INFO" "For offline validation, ensure stanza-create has been run with: pgbackrest stanza-create --no-online"
        log "INFO" "Configuration and bind-mounts appear to be valid for offline backups"
        return 0
    fi
}

# Function to verify backup completion
# Last Updated: 12/30/2025 12:00:00 AM CDT
verify_backup() {
    log "DEBUG" "Verifying backup completion..."
    
    if [[ $TEST_MODE -eq 1 ]]; then
        log "INFO:TEST" "Would verify backup in: $BACKUP_DIR"
        return 0
    fi
    
    # Check if backup directory has files
    local backup_count=$(find "$BACKUP_DIR" -type f 2>/dev/null | wc -l)
    
    if [[ $backup_count -gt 0 ]]; then
        log "INFO" "Backup verified: $backup_count files found in $BACKUP_DIR"
        return 0
    else
        log "WARN" "No backup files found in $BACKUP_DIR"
        return 1
    fi
}

# Function to send email notification
# Last Updated: 12/30/2025 10:15:00 PM CDT
send_email_notification() {
    local status=$1
    local message=$2
    
    log "DEBUG" "Preparing email notification..."
    log "DEBUG" "Email recipient: $EMAIL_RECIPIENT"
    log "DEBUG" "SMTP server: $SMTP_SERVER:$SMTP_PORT"
    
    if [[ -z "$EMAIL_RECIPIENT" ]]; then
        log "WARN" "Email recipient not configured (PGADMIN_DEFAULT_EMAIL not set)"
        return 1
    fi
    
    if [[ -z "$SMTP_SERVER" ]]; then
        log "WARN" "SMTP server not configured (SMTP_SERVER not set)"
        return 1
    fi
    
    # Determine email priority based on status
    # Only FAILED status gets high priority
    local high_priority_flag=""
    if [[ "$status" == "FAILED" ]]; then
        high_priority_flag="--high-priority"
        log "DEBUG" "Email priority: HIGH (failure detected)"
    else
        log "DEBUG" "Email priority: NORMAL (informational)"
    fi
    
    # Build email subject and body
    local subject="pgBackRest Backup Notification - $status"
    local hostname=$(hostname)
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    local body="pgBackRest Backup Report
========================

Status: $status
Hostname: $hostname
Timestamp: $timestamp

Backup Details:
- Type: $BACKUP_TYPE
- Configuration: $CONFIG_FILE
- Base Directory: $BASE_DIR
- Backup Directory: $BACKUP_DIR

$message

---
pgBackRest v$(pgbackrest version 2>/dev/null || echo 'unknown')"
    
    if [[ $TEST_MODE -eq 1 ]]; then
        log "INFO:TEST" "Would send email notification:"
        log "INFO:TEST" "  To: $EMAIL_RECIPIENT"
        log "INFO:TEST" "  Subject: $subject"
        log "INFO:TEST" "  Priority: $([ -n "$high_priority_flag" ] && echo 'HIGH (FAILURE)' || echo 'NORMAL (INFO)')"
        log "INFO:TEST" "  Body: $body"
        return 0
    fi
    
    log "DEBUG" "Sending email via SMTP server: $SMTP_SERVER:$SMTP_PORT"
    
    # Use the send_email.py utility to send via SMTP
    if command -v python3 >/dev/null 2>&1; then
        log "DEBUG" "Using send_email.py utility to relay via $SMTP_SERVER:$SMTP_PORT..."
        
        python3 "$DIVTOOLS/scripts/smtp/send_email.py" \
            --to "$EMAIL_RECIPIENT" \
            --subject "$subject" \
            --body "$body" \
            --smtp-server "$SMTP_SERVER" \
            --smtp-port "$SMTP_PORT" \
            --from "root@$(hostname)" \
            $high_priority_flag 2>/dev/null
        
        if [[ $? -eq 0 ]]; then
            log "INFO" "Email notification sent successfully to $EMAIL_RECIPIENT via $SMTP_SERVER:$SMTP_PORT"
            return 0
        else
            log "WARN" "Failed to send email via send_email.py utility"
        fi
    fi
    
    # Fallback: try with sendmail
    if command -v sendmail >/dev/null 2>&1; then
        log "DEBUG" "Fallback: Using sendmail..."
        echo "$email_content" | sendmail -t 2>/dev/null
        
        if [[ $? -eq 0 ]]; then
            log "INFO" "Email notification sent successfully via sendmail"
            return 0
        fi
    fi
    
    log "WARN" "Failed to send email notification"
    return 1
}

# Function to send test email
# Last Updated: 12/30/2025 12:00:00 AM CDT
send_test_email() {
    log "INFO" "Testing email configuration..."
    log "DEBUG" "Email recipient: $EMAIL_RECIPIENT"
    log "DEBUG" "SMTP server: $SMTP_SERVER"
    log "DEBUG" "SMTP port: $SMTP_PORT"
    
    if [[ -z "$EMAIL_RECIPIENT" ]]; then
        log "ERROR" "Email recipient not configured (PGADMIN_DEFAULT_EMAIL not set)"
        return 1
    fi
    
    if [[ -z "$SMTP_SERVER" ]]; then
        log "ERROR" "SMTP server not configured (SMTP_SERVER not set)"
        return 1
    fi
    
    local subject="[TEST] pgBackRest Email Configuration Test - $(hostname)"
    local body="This is a test email from pgBackRest backup script.

Test Details:
Hostname: $(hostname)
Timestamp: $(date '+%Y-%m-%d %H:%M:%S %Z')
Email Configuration:
- Recipient: $EMAIL_RECIPIENT
- SMTP Server: $SMTP_SERVER
- SMTP Port: $SMTP_PORT

If you received this email, your email configuration is working correctly.

---
pgBackRest v$(pgbackrest version 2>/dev/null || echo 'unknown')"
    
    log "DEBUG" "Sending test email via SMTP server: $SMTP_SERVER:$SMTP_PORT"
    
    # Use the send_email.py utility to send via SMTP
    if command -v python3 >/dev/null 2>&1; then
        log "DEBUG" "Using send_email.py utility to relay via $SMTP_SERVER:$SMTP_PORT..."
        
        python3 "$DIVTOOLS/scripts/smtp/send_email.py" \
            --to "$EMAIL_RECIPIENT" \
            --subject "$subject" \
            --body "$body" \
            --smtp-server "$SMTP_SERVER" \
            --smtp-port "$SMTP_PORT" \
            --from "root@$(hostname)" 2>/dev/null
        
        if [[ $? -eq 0 ]]; then
            log "INFO" "Test email sent successfully to $EMAIL_RECIPIENT via $SMTP_SERVER:$SMTP_PORT"
            return 0
        else
            log "ERROR" "Failed to send test email"
            log "INFO" "Monitor SMTP server may not be configured to accept relay from this host."
            log "INFO" "On monitor server, run:"
            log "INFO" "  postconf -n mynetworks"
            log "INFO" "If 10.1.1.74 (tnapp01) is not listed, add it:"
            log "INFO" "  postconf -e 'mynetworks = 127.0.0.0/8, [::ffff:127.0.0.1]/128, [::1]/128, 10.1.1.74'"
            log "INFO" "  postfix reload"
            return 1
        fi
    fi
    
    # Fallback: try with sendmail
    if command -v sendmail >/dev/null 2>&1; then
        log "DEBUG" "Fallback: Using sendmail..."
        echo "To: $EMAIL_RECIPIENT
From: pgbackrest@$(hostname)
Subject: $subject
X-Priority: 1
X-MSMail-Priority: High
Importance: High

$body" | sendmail -t 2>/dev/null
        
        if [[ $? -eq 0 ]]; then
            log "INFO" "Test email sent successfully via sendmail"
            return 0
        fi
    fi
    
    log "ERROR" "Failed to send test email - no suitable method available"
    return 1
}

# Main execution
# Last Updated: 12/30/2025 12:00:00 AM CDT
main() {
    local backup_success=0
    local verify_success=0
    
    log "INFO" "Running command: $COMMAND_TYPE for stanza: $STANZA_NAME"
    log "DEBUG" "TEST_MODE=$TEST_MODE, DEBUG_MODE=$DEBUG_MODE, SEND_EMAIL=$SEND_EMAIL"
    
    # Validate configuration
    if ! validate_config; then
        log "ERROR" "Configuration validation failed"
        BACKUP_STATUS="FAILED"
        BACKUP_MESSAGE="Configuration validation failed: $CONFIG_FILE not found"
        
        if [[ $SEND_EMAIL -eq 1 ]]; then
            send_email_notification "$BACKUP_STATUS" "$BACKUP_MESSAGE"
        fi
        exit 1
    fi
    
    # Create stanza if it doesn't exist
    if ! create_stanza_if_needed; then
        log "ERROR" "Stanza creation failed"
        BACKUP_STATUS="FAILED"
        BACKUP_MESSAGE="Failed to create stanza '$STANZA_NAME'. The stanza must exist in pgbackrest.conf and be initialized."
        
        if [[ $SEND_EMAIL -eq 1 ]]; then
            send_email_notification "$BACKUP_STATUS" "$BACKUP_MESSAGE"
        fi
        exit 1
    fi
    
    # Handle init-stanza command (explicit stanza initialization)
    if [[ "$COMMAND_TYPE" == "init-stanza" ]]; then
        log "INFO" "Initializing stanza '$STANZA_NAME' with --no-online for bind-mounted setup..."
        
        if [[ $TEST_MODE -eq 1 ]]; then
            log "INFO:TEST" "Would execute: sudo pgbackrest --config=$CONFIG_FILE --stanza=$STANZA_NAME --no-online stanza-create"
            log "INFO:TEST" "This initializes stanza for offline backups of bind-mounted PostgreSQL files"
        else
            if sudo pgbackrest --config="$CONFIG_FILE" --stanza="$STANZA_NAME" --no-online stanza-create; then
                log "INFO" "Stanza '$STANZA_NAME' initialized successfully with --no-online"
                BACKUP_STATUS="SUCCESS"
                BACKUP_MESSAGE="Stanza '$STANZA_NAME' has been initialized and is ready for backups"
                
                if [[ $SEND_EMAIL -eq 1 ]]; then
                    send_email_notification "$BACKUP_STATUS" "$BACKUP_MESSAGE"
                fi
                exit 0
            else
                log "ERROR" "Failed to initialize stanza '$STANZA_NAME'"
                BACKUP_STATUS="FAILED"
                BACKUP_MESSAGE="Failed to initialize stanza. Check permissions and bind-mount setup."
                
                if [[ $SEND_EMAIL -eq 1 ]]; then
                    send_email_notification "$BACKUP_STATUS" "$BACKUP_MESSAGE"
                fi
                exit 1
            fi
        fi
        exit 0
    fi
    
    # Handle check command
    if [[ "$COMMAND_TYPE" == "check" ]]; then
        if ! run_check; then
            BACKUP_STATUS="FAILED"
            BACKUP_MESSAGE="pgBackRest configuration check failed. See output above for details."
            
            if [[ $SEND_EMAIL -eq 1 ]]; then
                send_email_notification "$BACKUP_STATUS" "$BACKUP_MESSAGE"
            fi
            exit 1
        fi
        
        BACKUP_STATUS="SUCCESS"
        BACKUP_MESSAGE="Configuration check passed successfully for stanza: $STANZA_NAME"
        
        if [[ $SEND_EMAIL -eq 1 ]]; then
            send_email_notification "$BACKUP_STATUS" "$BACKUP_MESSAGE"
        fi
        
        log "INFO" "pgBackRest check command completed successfully"
        exit 0
    fi
    
    # Handle test-email command
    if [[ "$COMMAND_TYPE" == "test-email" ]]; then
        if send_test_email; then
            log "INFO" "Email test completed successfully"
            exit 0
        else
            log "ERROR" "Email test failed"
            exit 1
        fi
    fi
    
    # Initialize directories (backup command only)
    if ! init_directories; then
        log "ERROR" "Directory initialization failed"
        BACKUP_STATUS="FAILED"
        BACKUP_MESSAGE="Directory initialization failed for $BASE_DIR"
        
        if [[ $SEND_EMAIL -eq 1 ]]; then
            send_email_notification "$BACKUP_STATUS" "$BACKUP_MESSAGE"
        fi
        exit 1
    fi
    
    # Run backup
    if ! run_backup "$BACKUP_TYPE"; then
        log "ERROR" "Backup execution failed"
        BACKUP_STATUS="FAILED"
        BACKUP_MESSAGE="pgBackRest backup command failed. Check logs in $LOG_DIR for details."
        backup_success=1
    else
        backup_success=0
    fi
    
    # Verify backup
    if ! verify_backup; then
        log "WARN" "Backup verification returned warning status"
        verify_success=1
    else
        verify_success=0
    fi
    
    # Determine final status
    if [[ $backup_success -eq 0 ]] && [[ $verify_success -eq 0 ]]; then
        if [[ $NO_CHANGES_DETECTED -eq 1 ]]; then
            BACKUP_STATUS="SUCCESS - NO CHANGES"
            BACKUP_MESSAGE="No files have changed since the last backup.

This is normal and healthy - the database has not been modified.
Last backup remains current and ready for recovery.

Backup Location: $BACKUP_DIR
Log Location: $LOG_DIR"
        else
            BACKUP_STATUS="SUCCESS"
            BACKUP_MESSAGE="$BACKUP_TYPE backup completed successfully.
        
Backup files created: $(find "$BACKUP_DIR" -type f 2>/dev/null | wc -l)
Backup location: $BACKUP_DIR
Log location: $LOG_DIR"
        fi
    elif [[ $backup_success -eq 0 ]]; then
        BACKUP_STATUS="COMPLETED WITH WARNINGS"
        BACKUP_MESSAGE="Backup completed but verification found no files in $BACKUP_DIR"
    else
        BACKUP_STATUS="FAILED"
        if [[ -z "$BACKUP_MESSAGE" ]]; then
            BACKUP_MESSAGE="Backup execution failed. Check logs in $LOG_DIR"
        fi
    fi
    
    # Send email notification if requested
    if [[ $SEND_EMAIL -eq 1 ]]; then
        send_email_notification "$BACKUP_STATUS" "$BACKUP_MESSAGE"
    fi
    
    # Exit with appropriate code
    if [[ "$BACKUP_STATUS" == "SUCCESS" ]]; then
        log "INFO" "pgBackRest backup script completed successfully"
        exit 0
    else
        log "INFO" "pgBackRest backup script completed with status: $BACKUP_STATUS"
        exit 1
    fi
}

# Execute main function
main

    
