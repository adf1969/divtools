#!/bin/bash
# Deploy TrueNAS usage correction to TrueNAS server with automatic cron setup
# Last Updated: 11/4/2025 10:15:00 PM CST

# Source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../util/logging.sh" 2>/dev/null || {
    log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$1] ${*:2}"; }
}

# ===== CONFIGURATION SETTINGS =====
# Update interval in minutes (how often the cron job runs)
UPDATE_INTERVAL_MINUTES=30

# Parent dataset to monitor
ZFS_PARENT_DATASET="tpool/FieldsHm"

# Export file location (relative to dataset mountpoint)
EXPORT_FILENAME=".zfs_usage_info"
# =================================

# Default values
TRUENAS_HOST="${TRUENAS_HOST:-NAS1-1}"
TRUENAS_USER="${TRUENAS_USER:-root}"
REMOTE_SCRIPT_DIR="/root/scripts"
TEST_MODE=0
DEBUG_MODE=0
SKIP_CRON=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -test|--test)
            TEST_MODE=1
            log "INFO" "Running in TEST mode"
            shift
            ;;
        -debug|--debug)
            DEBUG_MODE=1
            log "DEBUG" "Debug mode enabled"
            shift
            ;;
        -h|--host)
            TRUENAS_HOST="$2"
            shift 2
            ;;
        -u|--user)
            TRUENAS_USER="$2"
            shift 2
            ;;
        --skip-cron)
            SKIP_CRON=1
            log "INFO" "Will skip cron job setup"
            shift
            ;;
        --help)
            cat <<EOF
Usage: $0 [OPTIONS]

Deploy TrueNAS usage correction scripts to TrueNAS server.

Options:
  -test, --test           Run in test mode (show commands, don't execute)
  -debug, --debug         Enable debug output
  -h, --host HOST         TrueNAS hostname/IP (default: $TRUENAS_HOST)
  -u, --user USER         SSH user (default: $TRUENAS_USER)
  --skip-cron             Skip cron job setup
  --help                  Show this help message

Configuration (edit script to change):
  UPDATE_INTERVAL_MINUTES Current: $UPDATE_INTERVAL_MINUTES minutes
  ZFS_PARENT_DATASET      Current: $ZFS_PARENT_DATASET
  EXPORT_FILENAME         Current: $EXPORT_FILENAME

Environment Variables:
  TRUENAS_HOST           Default TrueNAS hostname
  TRUENAS_USER           Default SSH user

Example:
  $0 -h NAS1-1 -u root
  TRUENAS_HOST=192.168.1.100 $0
EOF
            exit 0
            ;;
        *)
            log "ERROR" "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

log "INFO" "Deployment started"
log "DEBUG" "Target: $TRUENAS_USER@$TRUENAS_HOST:$REMOTE_SCRIPT_DIR"
log "DEBUG" "Update interval: $UPDATE_INTERVAL_MINUTES minutes"
log "DEBUG" "Dataset: $ZFS_PARENT_DATASET"

# Check if we can reach TrueNAS
log "INFO" "Testing connection to $TRUENAS_HOST..."
if [[ $TEST_MODE -eq 1 ]]; then
    log "INFO" "TEST MODE: Would run: ssh $TRUENAS_USER@$TRUENAS_HOST 'echo Connection OK'"
else
    if ! ssh -o ConnectTimeout=5 "$TRUENAS_USER@$TRUENAS_HOST" 'echo Connection OK' &>/dev/null; then
        log "ERROR" "Cannot connect to $TRUENAS_HOST"
        log "ERROR" "Please check:"
        log "ERROR" "  1. Hostname/IP is correct"
        log "ERROR" "  2. SSH is accessible"
        log "ERROR" "  3. SSH keys are configured"
        exit 1
    fi
    log "INFO" "Connection successful"
fi

# Verify ZFS is available on remote system
log "INFO" "Checking for ZFS on remote system..."
if [[ $TEST_MODE -eq 1 ]]; then
    log "INFO" "TEST MODE: Would check for ZFS command"
else
    if ! ssh "$TRUENAS_USER@$TRUENAS_HOST" 'command -v zfs &>/dev/null'; then
        log "ERROR" "ZFS command not found on $TRUENAS_HOST"
        log "ERROR" "This script requires a ZFS-capable system (TrueNAS, FreeBSD, Linux with ZFS)"
        exit 1
    fi
    log "INFO" "ZFS found"
fi

# Check if target dataset exists
log "INFO" "Verifying dataset '$ZFS_PARENT_DATASET' exists..."
if [[ $TEST_MODE -eq 1 ]]; then
    log "INFO" "TEST MODE: Would verify dataset exists"
else
    if ! ssh "$TRUENAS_USER@$TRUENAS_HOST" "zfs list '$ZFS_PARENT_DATASET' &>/dev/null"; then
        log "ERROR" "Dataset '$ZFS_PARENT_DATASET' not found on $TRUENAS_HOST"
        log "ERROR" "Available datasets:"
        ssh "$TRUENAS_USER@$TRUENAS_HOST" "zfs list -o name | head -20"
        log "ERROR" "Please update ZFS_PARENT_DATASET in this script"
        exit 1
    fi
    log "INFO" "Dataset verified"
    
    # Get and display mountpoint
    mountpoint=$(ssh "$TRUENAS_USER@$TRUENAS_HOST" "zfs list -H -o mountpoint '$ZFS_PARENT_DATASET'")
    log "DEBUG" "Dataset mountpoint: $mountpoint"
fi

# Detect system type
log "INFO" "Detecting system type..."
if [[ $TEST_MODE -eq 1 ]]; then
    log "INFO" "TEST MODE: Would detect system type"
    system_type="TEST"
else
    system_info=$(ssh "$TRUENAS_USER@$TRUENAS_HOST" 'uname -s; cat /etc/*release 2>/dev/null | grep -i truenas | head -1')
    if echo "$system_info" | grep -qi truenas; then
        system_type="TrueNAS"
        log "INFO" "System identified as TrueNAS"
    elif echo "$system_info" | grep -qi freebsd; then
        system_type="FreeBSD"
        log "INFO" "System identified as FreeBSD with ZFS"
    elif echo "$system_info" | grep -qi linux; then
        system_type="Linux"
        log "INFO" "System identified as Linux with ZFS"
    else
        system_type="Unknown"
        log "WARN" "Could not identify system type, but ZFS is present"
    fi
    log "DEBUG" "System type: $system_type"
fi

# Create remote directory structure
log "INFO" "Creating remote directories..."
if [[ $TEST_MODE -eq 1 ]]; then
    log "INFO" "TEST MODE: Would create $REMOTE_SCRIPT_DIR and $REMOTE_SCRIPT_DIR/util"
else
    ssh "$TRUENAS_USER@$TRUENAS_HOST" "mkdir -p $REMOTE_SCRIPT_DIR/util"
    log "INFO" "Directories created"
fi

# Copy scripts
log "INFO" "Copying tns_upd_size.sh..."
if [[ $TEST_MODE -eq 1 ]]; then
    log "INFO" "TEST MODE: Would copy $SCRIPT_DIR/tns_upd_size.sh"
else
    if scp "$SCRIPT_DIR/tns_upd_size.sh" "$TRUENAS_USER@$TRUENAS_HOST:$REMOTE_SCRIPT_DIR/"; then
        log "INFO" "tns_upd_size.sh copied successfully"
    else
        log "ERROR" "Failed to copy tns_upd_size.sh"
        exit 1
    fi
fi

log "INFO" "Copying logging utilities..."
if [[ $TEST_MODE -eq 1 ]]; then
    log "INFO" "TEST MODE: Would copy $SCRIPT_DIR/../util/logging.sh"
else
    if scp "$SCRIPT_DIR/../util/logging.sh" "$TRUENAS_USER@$TRUENAS_HOST:$REMOTE_SCRIPT_DIR/util/"; then
        log "INFO" "logging.sh copied successfully"
    else
        log "WARN" "Failed to copy logging.sh (script will work without it)"
    fi
fi

# Set permissions
log "INFO" "Setting permissions..."
if [[ $TEST_MODE -eq 1 ]]; then
    log "INFO" "TEST MODE: Would set permissions on remote scripts"
else
    ssh "$TRUENAS_USER@$TRUENAS_HOST" "chmod +x $REMOTE_SCRIPT_DIR/tns_upd_size.sh"
    log "INFO" "Permissions set"
fi

# Test the script
log "INFO" "Testing script on TrueNAS..."
if [[ $TEST_MODE -eq 1 ]]; then
    log "INFO" "TEST MODE: Would run test on TrueNAS"
else
    log "INFO" "Running: $REMOTE_SCRIPT_DIR/tns_upd_size.sh -test"
    if ssh "$TRUENAS_USER@$TRUENAS_HOST" "$REMOTE_SCRIPT_DIR/tns_upd_size.sh -test -d '$ZFS_PARENT_DATASET'" 2>&1; then
        log "INFO" "Test run successful"
    else
        log "ERROR" "Test run failed - check output above"
        exit 1
    fi
fi

# Add to crontab if requested
if [[ $SKIP_CRON -eq 0 ]]; then
    log "INFO" "Setting up cron job..."
    
    # Calculate cron schedule from UPDATE_INTERVAL_MINUTES
    if [[ $UPDATE_INTERVAL_MINUTES -lt 60 ]]; then
        # Minutes-based schedule
        cron_schedule="*/$UPDATE_INTERVAL_MINUTES * * * *"
    else
        # Hour-based schedule
        hours=$((UPDATE_INTERVAL_MINUTES / 60))
        cron_schedule="0 */$hours * * *"
    fi
    
    log "DEBUG" "Cron schedule: $cron_schedule"
    
    # Build the cron command
    cron_command="$REMOTE_SCRIPT_DIR/tns_upd_size.sh -d '$ZFS_PARENT_DATASET'"
    cron_entry="$cron_schedule $cron_command >> /var/log/zfs_usage.log 2>&1"
    
    if [[ $TEST_MODE -eq 1 ]]; then
        log "INFO" "TEST MODE: Would add cron entry:"
        log "INFO:raw" "  $cron_entry"
    else
        # Check if cron entry already exists
        log "DEBUG" "Checking for existing cron entry..."
        existing_cron=$(ssh "$TRUENAS_USER@$TRUENAS_HOST" "crontab -l 2>/dev/null | grep -F 'tns_upd_size.sh'" || true)
        
        if [[ -n "$existing_cron" ]]; then
            log "WARN" "Cron entry already exists:"
            log "WARN:raw" "  $existing_cron"
            log "INFO" "Checking if update is needed..."
            
            # Check if the existing entry matches our desired entry
            if echo "$existing_cron" | grep -qF "$cron_command"; then
                log "INFO" "Existing cron entry is current, no update needed"
            else
                log "WARN" "Existing cron entry differs from desired configuration"
                log "INFO" "To update manually, run on $TRUENAS_HOST:"
                log "INFO:raw" "  crontab -e"
                log "INFO:raw" "  # Replace old entry with:"
                log "INFO:raw" "  $cron_entry"
            fi
        else
            log "INFO" "Adding cron entry..."
            # Add new cron entry
            ssh "$TRUENAS_USER@$TRUENAS_HOST" "(crontab -l 2>/dev/null; echo '$cron_entry') | crontab -"
            
            # Verify it was added
            if ssh "$TRUENAS_USER@$TRUENAS_HOST" "crontab -l 2>/dev/null | grep -qF 'tns_upd_size.sh'"; then
                log "INFO" "Cron entry added successfully"
                log "INFO:raw" "  Schedule: Every $UPDATE_INTERVAL_MINUTES minutes"
                log "INFO:raw" "  Command: $cron_command"
            else
                log "ERROR" "Failed to add cron entry"
                exit 1
            fi
        fi
    fi
else
    log "INFO" "Skipping cron job setup (--skip-cron specified)"
fi

# Offer to add cron job
log "INFO" "Deployment complete!"
echo ""
echo "========================================="
echo "Deployment Summary"
echo "========================================="
echo "System Type:     $system_type"
echo "Dataset:         $ZFS_PARENT_DATASET"
echo "Update Interval: $UPDATE_INTERVAL_MINUTES minutes"
echo "Script Location: $REMOTE_SCRIPT_DIR/tns_upd_size.sh"

if [[ $SKIP_CRON -eq 0 && $TEST_MODE -eq 0 ]]; then
    echo "Cron Job:        Configured ✓"
else
    echo "Cron Job:        Not configured"
fi
echo "========================================="
echo ""

echo "Next steps:"
echo "1. Run the script manually to create initial file:"
echo "   ssh $TRUENAS_USER@$TRUENAS_HOST '$REMOTE_SCRIPT_DIR/tns_upd_size.sh -d \"$ZFS_PARENT_DATASET\"'"
echo ""
echo "2. Verify the output file is created:"
mountpoint=$(ssh "$TRUENAS_USER@$TRUENAS_HOST" "zfs list -H -o mountpoint '$ZFS_PARENT_DATASET' 2>/dev/null" || echo "/mnt/$ZFS_PARENT_DATASET")
echo "   ssh $TRUENAS_USER@$TRUENAS_HOST 'cat $mountpoint/$EXPORT_FILENAME'"
echo ""
echo "3. On your client systems:"
echo "   source ~/.bash_profile"
echo "   dfc -debug"
echo ""

if [[ $SKIP_CRON -eq 1 ]]; then
    echo "4. To manually add cron job, run on $TRUENAS_HOST:"
    echo "   crontab -e"
    echo "   # Add this line:"
    cron_schedule="*/$UPDATE_INTERVAL_MINUTES * * * *"
    echo "   $cron_schedule $REMOTE_SCRIPT_DIR/tns_upd_size.sh -d '$ZFS_PARENT_DATASET' >> /var/log/zfs_usage.log 2>&1"
    echo ""
fi

log "INFO" "Deployment finished successfully"
