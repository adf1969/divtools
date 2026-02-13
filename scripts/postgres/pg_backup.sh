#!/bin/bash
# PostgreSQL logical backups using pg_dump and pg_dumpall via Docker exec
# Supports backing up all databases or specific database
# Supports multiple backup types with retention management
# Last Updated: 12/30/2025 1:00:00 AM CDT

# Source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../util/logging.sh"

# Configuration
CONTAINER_NAME="postgres"
BASE_BACKUP_DIR="/opt/pgbackup"
BACKUP_DIR="${BASE_BACKUP_DIR}/backups"
LOG_DIR="${BASE_BACKUP_DIR}/logs"
RETENTION_DAYS=7
RETENTION_COUNT=0  # 0 = disabled, only use RETENTION_DAYS; >0 = keep last N backups
MAX_BACKUP_SIZE_MB=0  # 0 = unlimited, >0 = delete oldest until total size < this limit
COMPRESS=1
BACKUP_ALL_DBS=0
BACKUP_TYPE="pg_dump"  # pg_dump or pg_dumpall
SERVER_NAME="localhost"
SERVER_PORT="5432"
DATABASE_NAME=""
BACKUP_USER="postgres"
DIVTOOLS="${DIVTOOLS:-/opt/divtools}"

# Email notification settings
SEND_EMAIL=0
EMAIL_RECIPIENT=""
SMTP_SERVER=""
SMTP_PORT="25"
BACKUP_STATUS="PENDING"
BACKUP_MESSAGE=""
BACKUP_EXIT_CODE=0

# Default flags
TEST_MODE=0
DEBUG_MODE=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -test|--test)
            TEST_MODE=1
            shift
            ;;
        -debug|--debug)
            DEBUG_MODE=1
            shift
            ;;
        -server)
            SERVER_NAME="$2"
            shift 2
            ;;
        -port)
            SERVER_PORT="$2"
            shift 2
            ;;
        -db)
            DATABASE_NAME="$2"
            BACKUP_ALL_DBS=0
            shift 2
            ;;
        -all)
            BACKUP_ALL_DBS=1
            DATABASE_NAME=""
            shift
            ;;
        -type)
            BACKUP_TYPE="$2"
            shift 2
            ;;
        -backupdir)
            BACKUP_DIR="$2"
            shift 2
            ;;
        -logdir)
            LOG_DIR="$2"
            shift 2
            ;;
        -retention)
            RETENTION_DAYS="$2"
            shift 2
            ;;
        -retention-count)
            RETENTION_COUNT="$2"
            shift 2
            ;;
        -max-size)
            MAX_BACKUP_SIZE_MB="$2"
            shift 2
            ;;
        -compress)
            COMPRESS=1
            shift
            ;;
        -nocompress)
            COMPRESS=0
            shift
            ;;
        -email)
            SEND_EMAIL=1
            shift
            ;;
        *)
            log "ERROR" "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Function to load environment variables
# Last Updated: 12/30/2025 1:00:00 AM CDT
load_environment() {
    log "DEBUG" "Loading environment variables..."
    
    # Try to source .bash_profile if load_env_files is not yet available
    if ! declare -f load_env_files >/dev/null 2>&1; then
        if [[ -f "$HOME/.bash_profile" ]]; then
            log "DEBUG" "Sourcing .bash_profile to load environment..."
            source "$HOME/.bash_profile" 2>/dev/null || true
        fi
    fi
    
    # Call the standard divtools environment loader if available
    if declare -f load_env_files >/dev/null 2>&1; then
        log "DEBUG" "Calling load_env_files() to load environment..."
        load_env_files
        log "DEBUG" "Environment loaded successfully"
    else
        log "DEBUG" "load_env_files not available, using direct environment"
    fi
    
    # Extract DIVTOOLS, SMTP variables, and EMAIL from environment
    # This ensures variables are available even in sudo context
    if [[ -z "$DIVTOOLS" ]]; then
        DIVTOOLS="${DIVTOOLS:-/opt/divtools}"
        log "DEBUG" "DIVTOOLS set to: $DIVTOOLS"
    fi
    
    if [[ -n "${PGADMIN_DEFAULT_EMAIL:-}" ]]; then
        EMAIL_RECIPIENT="$PGADMIN_DEFAULT_EMAIL"
        log "DEBUG" "Email recipient set to: $EMAIL_RECIPIENT"
    fi
    
    if [[ -n "${SMTP_SERVER:-}" ]]; then
        SMTP_SERVER="${SMTP_SERVER}"
        log "DEBUG" "SMTP server set to: $SMTP_SERVER"
    fi
    
    if [[ -n "${SMTP_PORT:-}" ]]; then
        SMTP_PORT="${SMTP_PORT}"
        log "DEBUG" "SMTP port set to: $SMTP_PORT"
    fi
}

# Load environment variables early
load_environment

# Log startup info
log "INFO" "PostgreSQL backup script started"
log "DEBUG" "TEST_MODE=$TEST_MODE, DEBUG_MODE=$DEBUG_MODE, SEND_EMAIL=$SEND_EMAIL"

# Function to initialize directory structure
# Last Updated: 12/30/2025 1:00:00 AM CDT
init_directories() {
    log "DEBUG" "Initializing backup directories..."
    
    for dir in "$BASE_BACKUP_DIR" "$LOG_DIR" "$BACKUP_DIR"; do
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

# Function to verify PostgreSQL container is running
# Last Updated: 12/30/2025 1:00:00 AM CDT
verify_container() {
    log "DEBUG" "Verifying PostgreSQL container is running..."
    
    if ! docker ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        log "ERROR" "PostgreSQL container '$CONTAINER_NAME' is not running"
        return 1
    fi
    
    log "INFO" "PostgreSQL container verified: $CONTAINER_NAME"
    return 0
}

# Function to run pg_dump or pg_dumpall
# Last Updated: 12/30/2025 1:00:00 AM CDT
run_backup() {
    local backup_type=$1
    local timestamp=$(date '+%Y%m%d-%H%M%S')
    local compression_flag=""
    
    if [[ $COMPRESS -eq 1 ]]; then
        compression_flag="-F c"  # Custom format (compressed)
    fi
    
    log "INFO" "Starting PostgreSQL $backup_type backup..."
    log "DEBUG" "Backup type: $backup_type"
    log "DEBUG" "Compression: $([[ $COMPRESS -eq 1 ]] && echo 'enabled' || echo 'disabled')"
    
    if [[ $backup_type == "pg_dumpall" ]]; then
        local backup_file="${BACKUP_DIR}/pgdumpall-${timestamp}.sql"
        if [[ $COMPRESS -eq 1 ]]; then
            backup_file="${backup_file}.gz"
        fi
        
        log "DEBUG" "Backup file: $backup_file"
        
        if [[ $TEST_MODE -eq 1 ]]; then
            log "INFO:TEST" "Would execute: docker exec $CONTAINER_NAME pg_dumpall -U $BACKUP_USER"
            if [[ $COMPRESS -eq 1 ]]; then
                log "INFO:TEST" "Would compress output to: $backup_file"
            else
                log "INFO:TEST" "Would save to: $backup_file"
            fi
            return 0
        fi
        
        if [[ $COMPRESS -eq 1 ]]; then
            docker exec "$CONTAINER_NAME" pg_dumpall -U "$BACKUP_USER" | gzip > "$backup_file" 2>>"${LOG_DIR}/pg_dumpall-${timestamp}.log"
        else
            docker exec "$CONTAINER_NAME" pg_dumpall -U "$BACKUP_USER" > "$backup_file" 2>>"${LOG_DIR}/pg_dumpall-${timestamp}.log"
        fi
        
        if [[ $? -eq 0 ]]; then
            log "INFO" "pg_dumpall backup completed: $backup_file"
            return 0
        else
            log "ERROR" "pg_dumpall backup failed"
            return 1
        fi
        
    elif [[ $backup_type == "pg_dump" ]]; then
        if [[ -z "$DATABASE_NAME" ]]; then
            log "ERROR" "Database name required for pg_dump"
            return 1
        fi
        
        local backup_file="${BACKUP_DIR}/pgdump-${DATABASE_NAME}-${timestamp}.sql"
        if [[ $COMPRESS -eq 1 ]]; then
            backup_file="${backup_file}.gz"
        fi
        
        log "DEBUG" "Backup file: $backup_file"
        
        if [[ $TEST_MODE -eq 1 ]]; then
            log "INFO:TEST" "Would execute: docker exec $CONTAINER_NAME pg_dump -U $BACKUP_USER $DATABASE_NAME"
            if [[ $COMPRESS -eq 1 ]]; then
                log "INFO:TEST" "Would compress output to: $backup_file"
            else
                log "INFO:TEST" "Would save to: $backup_file"
            fi
            return 0
        fi
        
        if [[ $COMPRESS -eq 1 ]]; then
            docker exec "$CONTAINER_NAME" pg_dump -U "$BACKUP_USER" "$DATABASE_NAME" | gzip > "$backup_file" 2>>"${LOG_DIR}/pg_dump-${DATABASE_NAME}-${timestamp}.log"
        else
            docker exec "$CONTAINER_NAME" pg_dump -U "$BACKUP_USER" "$DATABASE_NAME" > "$backup_file" 2>>"${LOG_DIR}/pg_dump-${DATABASE_NAME}-${timestamp}.log"
        fi
        
        if [[ $? -eq 0 ]]; then
            log "INFO" "pg_dump backup completed: $backup_file"
            return 0
        else
            log "ERROR" "pg_dump backup failed"
            return 1
        fi
    fi
}

# Function to clean up old backups
# Last Updated: 12/30/2025 1:00:00 AM CDT
cleanup_old_backups() {
    log "DEBUG" "Cleaning up old backups..."
    
    local files_deleted=0
    local space_freed=0
    
    if [[ $TEST_MODE -eq 1 ]]; then
        # Test mode: show what would be deleted
        local old_files=$(find "$BACKUP_DIR" -type f -mtime +$RETENTION_DAYS 2>/dev/null)
        
        if [[ -n "$old_files" ]]; then
            log "INFO:TEST" "Would delete files older than $RETENTION_DAYS days:"
            echo "$old_files" | while read file; do
                local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
                log "INFO:TEST" "  $(basename "$file") ($(numfmt --to=iec-i --suffix=B --format=%.2f $size 2>/dev/null || echo "$((size/1024/1024)) MB"))"
            done
        else
            log "INFO:TEST" "No files older than $RETENTION_DAYS days found"
        fi
        
        # Test mode: show count-based cleanup
        if [[ $RETENTION_COUNT -gt 0 ]]; then
            local total_files=$(find "$BACKUP_DIR" -type f | wc -l)
            if [[ $total_files -gt $RETENTION_COUNT ]]; then
                log "INFO:TEST" "Would also delete oldest files to maintain max count of $RETENTION_COUNT (currently have $total_files)"
            fi
        fi
        return 0
    fi
    
    # Delete files older than RETENTION_DAYS
    if [[ $RETENTION_DAYS -gt 0 ]]; then
        log "DEBUG" "Deleting backups older than $RETENTION_DAYS days"
        find "$BACKUP_DIR" -type f -mtime +$RETENTION_DAYS -delete 2>/dev/null
    fi
    
    # Delete older files if we exceed RETENTION_COUNT
    if [[ $RETENTION_COUNT -gt 0 ]]; then
        local total_files=$(find "$BACKUP_DIR" -type f | wc -l)
        if [[ $total_files -gt $RETENTION_COUNT ]]; then
            log "DEBUG" "Backup count ($total_files) exceeds retention limit ($RETENTION_COUNT), removing oldest backups"
            # Get oldest files and delete until we're at retention count
            local excess=$((total_files - RETENTION_COUNT))
            find "$BACKUP_DIR" -type f -printf '%T@:%p\n' | sort -n | head -n $excess | cut -d ':' -f2 | xargs rm -f 2>/dev/null
        fi
    fi
    
    log "INFO" "Backup cleanup completed"
    return 0
}

# Function to send email notification
# Last Updated: 12/30/2025 1:00:00 AM CDT
send_email_notification() {
    local status=$1
    local message=$2
    
    log "DEBUG" "Preparing email notification..."
    log "DEBUG" "Email recipient: $EMAIL_RECIPIENT"
    
    if [[ -z "$EMAIL_RECIPIENT" ]]; then
        log "WARN" "Email recipient not configured (PGADMIN_DEFAULT_EMAIL not set)"
        return 1
    fi
    
    if [[ -z "$SMTP_SERVER" ]]; then
        log "WARN" "SMTP server not configured (SMTP_SERVER not set)"
        return 1
    fi
    
    # Build email subject and body
    local subject="PostgreSQL Backup Notification - $status"
    local hostname=$(hostname)
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    local body="PostgreSQL Backup Report
========================

Status: $status
Hostname: $hostname
Timestamp: $timestamp

Backup Details:
- Backup Type: $BACKUP_TYPE
- Database: ${DATABASE_NAME:-All Databases}
- Backup Directory: $BACKUP_DIR
- Log Directory: $LOG_DIR
- Compression: $([[ $COMPRESS -eq 1 ]] && echo 'Enabled' || echo 'Disabled')
- Retention: $RETENTION_DAYS days

$message"
    
    if [[ $TEST_MODE -eq 1 ]]; then
        log "INFO:TEST" "Would send email notification:"
        log "INFO:TEST" "  To: $EMAIL_RECIPIENT"
        log "INFO:TEST" "  Subject: $subject"
        log "INFO:TEST" "  Via: $SMTP_SERVER:${SMTP_PORT:-25}"
        return 0
    fi
    
    # Use the standard divtools email utility
    if [[ -f "$DIVTOOLS/scripts/smtp/send_email.py" ]]; then
        log "DEBUG" "Sending email via send_email.py utility..."
        
        # Determine if we should mark as high priority (only for failures)
        local priority_flag=""
        if [[ "$status" == "FAILED" ]]; then
            priority_flag="--high-priority"
        fi
        
        python3 "$DIVTOOLS/scripts/smtp/send_email.py" \
            --to "$EMAIL_RECIPIENT" \
            --subject "$subject" \
            --body "$body" \
            --smtp-server "$SMTP_SERVER" \
            --smtp-port "${SMTP_PORT:-25}" \
            --from "root@$(hostname)" \
            $priority_flag 2>&1 | while read line; do
            log "DEBUG" "Email: $line"
        done
        
        if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
            log "INFO" "Email notification sent successfully to $EMAIL_RECIPIENT via $SMTP_SERVER:${SMTP_PORT:-25}"
            return 0
        else
            log "ERROR" "Failed to send email notification"
            return 1
        fi
    else
        log "ERROR" "Email utility not found at $DIVTOOLS/scripts/smtp/send_email.py"
        return 1
    fi
}

# Main execution
# Last Updated: 12/30/2025 1:00:00 AM CDT
main() {
    local backup_success=0
    
    log "INFO" "PostgreSQL backup script started"
    log "DEBUG" "Container: $CONTAINER_NAME, Backup type: $BACKUP_TYPE"
    log "DEBUG" "Retention: Days=$RETENTION_DAYS, Count=$RETENTION_COUNT, MaxSize=${MAX_BACKUP_SIZE_MB}MB"
    
    # Initialize directories
    if ! init_directories; then
        log "ERROR" "Directory initialization failed"
        BACKUP_STATUS="FAILED"
        BACKUP_MESSAGE="Directory initialization failed"
        BACKUP_EXIT_CODE=1
        [[ $SEND_EMAIL -eq 1 ]] && send_email_notification "$BACKUP_STATUS" "$BACKUP_MESSAGE"
        exit 1
    fi
    
    # Verify container is running
    if ! verify_container; then
        log "ERROR" "PostgreSQL container verification failed"
        BACKUP_STATUS="FAILED"
        BACKUP_MESSAGE="PostgreSQL container '$CONTAINER_NAME' is not running"
        BACKUP_EXIT_CODE=1
        [[ $SEND_EMAIL -eq 1 ]] && send_email_notification "$BACKUP_STATUS" "$BACKUP_MESSAGE"
        exit 1
    fi
    
    # Determine backup type
    if [[ $BACKUP_ALL_DBS -eq 1 ]]; then
        if ! run_backup "pg_dumpall"; then
            log "ERROR" "Backup execution failed"
            BACKUP_STATUS="FAILED"
            BACKUP_MESSAGE="pg_dumpall backup failed - check logs for details"
            BACKUP_EXIT_CODE=1
            backup_success=1
        else
            backup_success=0
        fi
    else
        if ! run_backup "pg_dump"; then
            log "ERROR" "Backup execution failed"
            BACKUP_STATUS="FAILED"
            BACKUP_MESSAGE="pg_dump backup failed for database: $DATABASE_NAME - check logs for details"
            BACKUP_EXIT_CODE=1
            backup_success=1
        else
            backup_success=0
        fi
    fi
    
    # Clean up old backups
    if ! cleanup_old_backups; then
        log "WARN" "Cleanup had issues but backup succeeded"
    fi
    
    # Determine final status and create summary
    if [[ $backup_success -eq 0 ]]; then
        BACKUP_STATUS="SUCCESS"
        BACKUP_EXIT_CODE=0
        local file_count=$(find "$BACKUP_DIR" -type f 2>/dev/null | wc -l)
        local total_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
        BACKUP_MESSAGE="Backup completed successfully.

Backup Summary:
- Total files: $file_count
- Total size: $total_size
- Backup location: $BACKUP_DIR
- Log location: $LOG_DIR
- Retention: $RETENTION_DAYS days"
        if [[ $RETENTION_COUNT -gt 0 ]]; then
            BACKUP_MESSAGE="$BACKUP_MESSAGE
- Max files: $RETENTION_COUNT"
        fi
    fi
    
    # Send email notification if requested
    if [[ $SEND_EMAIL -eq 1 ]]; then
        send_email_notification "$BACKUP_STATUS" "$BACKUP_MESSAGE"
    fi
    
    # Exit with appropriate code
    if [[ $BACKUP_EXIT_CODE -eq 0 ]]; then
        log "INFO" "PostgreSQL backup script completed successfully"
        exit 0
    else
        log "ERROR" "PostgreSQL backup script failed"
        exit 1
    fi
}

# Execute main function
main
