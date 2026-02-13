#!/bin/bash
# Samba Active Directory Domain Controller Setup Script
# Last Updated: 12/6/2025 10:00:00 PM CST
#
# This script provides an interactive whiptail-based menu for:
# - ADS Setup: Creates folder structure, deploys compose files
# - ADS Container Start: Starts the samba-ads container
# - ADS Status Check: Runs verification tests
# - Configure DNS on Host: Updates host DNS settings
#
# Environment variables are managed in sites/$SITE_NAME/$HOSTNAME/.env.$HOSTNAME
# with markers for easy updates (like dt_host_setup.sh does)
#
# Logging:
# - All activity logged to /opt/ads-setup/logs/dt_ads_setup-TIMESTAMP.log
# - Log level based on --debug flag (DEBUG vs INFO)
# - Fully timestamped with local timezone
# - Menu selections clearly identified

# Source logging and whiptail utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../util/logging.sh"
source "$SCRIPT_DIR/../util/whiptail.sh"

# Default flags
TEST_MODE=0
DEBUG_MODE=0
LOG_DIR="/opt/ads-setup/logs"
LOG_FILE=""

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
        *)
            echo "ERROR: Unknown option: $1"
            exit 1
            ;;
    esac
done

# Initialize logging
init_logging() {
    # Create log directory
    mkdir -p "$LOG_DIR"
    
    # Generate log filename with timestamp
    local timestamp=$(date '+%Y%m%d-%H%M%S')
    LOG_FILE="$LOG_DIR/dt_ads_setup-${timestamp}.log"
    
    # Redirect stdout and stderr to log file while also displaying
    # Use process substitution to tee output
    exec 1> >(tee -a "$LOG_FILE")
    exec 2> >(tee -a "$LOG_FILE" >&2)
    
    # Log initialization info
    log "HEAD" "================================"
    log "HEAD" "ADS Setup Script Started"
    log "HEAD" "================================"
    log "INFO" "Log file: $LOG_FILE"
    log "DEBUG" "Test Mode: $TEST_MODE"
    log "DEBUG" "Debug Mode: $DEBUG_MODE"
    log "DEBUG" "Current Directory: $(pwd)"
    log "DEBUG" "User: $(whoami)"
    log "INFO" "Script execution started"
}

# Initialize logging first
init_logging

log "INFO" "TEST_MODE=$TEST_MODE, DEBUG_MODE=$DEBUG_MODE"

################################################################################
# Environment Variable Management - MUST BE EARLY (before first use)
################################################################################

# Load environment files using .bash_profile function
# Last Updated: 01/09/2026 10:30:00 AM CDT
# This ensures consistent environment variable management across all divtools scripts
load_environment() {
    # Try to source .bash_profile if load_env_files is not yet available
    if ! declare -f load_env_files >/dev/null 2>&1; then
        log "DEBUG" "load_env_files not found, sourcing .bash_profile..."
        if [[ -f "$HOME/.bash_profile" ]]; then
            source "$HOME/.bash_profile" 2>/dev/null
        fi
    fi
    
    # Also try $DIVTOOLS/dotfiles/.bash_profile if still not found
    if ! declare -f load_env_files >/dev/null 2>&1 && [[ -n "$DIVTOOLS" ]]; then
        log "DEBUG" "Attempting to source $DIVTOOLS/dotfiles/.bash_profile for load_env_files..."
        if [[ -f "$DIVTOOLS/dotfiles/.bash_profile" ]]; then
            source "$DIVTOOLS/dotfiles/.bash_profile" 2>/dev/null
        fi
    fi
    
    # Call the standard divtools environment loader
    if declare -f load_env_files >/dev/null 2>&1; then
        log "DEBUG" "Calling load_env_files() to load environment..."
        load_env_files
        log "DEBUG" "Environment loaded: SITE_NAME=$SITE_NAME, HOSTNAME=$HOSTNAME"
    else
        log "WARN" "load_env_files function not found - environment may be incomplete"
        return 1
    fi
}

# Load environment variables early - before any menus or functions
log "DEBUG" "Loading divtools environment at script startup..."
load_environment

# Configuration
PROJECT_ROOT="/home/divix/divtools"
PHASE1_CONFIGS="$PROJECT_ROOT/projects/ads/phase1-configs"
SITE_NAME="${SITE_NAME:-s01-7692nw}"
HOSTNAME="${HOSTNAME:-ads1-98}"
HOST_DIR="$PROJECT_ROOT/docker/sites/$SITE_NAME/$HOSTNAME"
SAMBA_DIR="$HOST_DIR/samba"
ENV_FILE="$HOST_DIR/.env.$HOSTNAME"
DATA_DIR="/opt/samba"

# Environment variable markers (like dt_host_setup.sh)
ENV_MARKER_START="# >>> DT_ADS_SETUP AUTO-MANAGED - DO NOT EDIT MANUALLY <<<"
ENV_MARKER_END="# <<< DT_ADS_SETUP AUTO-MANAGED <<<"

################################################################################
# File Backup Helper
################################################################################

# Function to backup a file before overwriting
# Last Updated: 01/09/2026 8:50:00 PM CDT
backup_file() {
    local file_path="$1"
    
    if [[ ! -f "$file_path" ]]; then
        log "DEBUG" "File $file_path does not exist - no backup needed"
        return 0
    fi
    
    local backup_date=$(date +%Y-%m-%d)
    local backup_path="${file_path}.${backup_date}"
    
    # If backup already exists for today, append timestamp
    if [[ -f "$backup_path" ]]; then
        backup_date=$(date +%Y-%m-%d-%H%M%S)
        backup_path="${file_path}.${backup_date}"
    fi
    
    log "DEBUG" "Creating backup: $backup_path"
    if cp "$file_path" "$backup_path"; then
        log "INFO" "Backed up existing file to: $(basename $backup_path)"
        echo "$backup_path"  # Return the backup path for caller reference
        return 0
    else
        log "ERROR" "Failed to create backup of $file_path"
        return 1
    fi
}

################################################################################
# Whiptail Color Configuration
################################################################################

# Function to set whiptail colors
# Last Updated: 12/7/2025 12:00:00 AM CDT
set_whiptail_colors() {
    # Set whiptail color environment variables for high-contrast theme with clear button selection
    export NEWT_COLORS='
        root=,black
        window=,black
        border=white,black
        textbox=white,black
        button=black,white
        actbutton=white,blue
        compactbutton=black,white
        title=cyan,black
        label=cyan,black
        entry=white,black
        checkbox=cyan,black
        actcheckbox=black,cyan
        listbox=white,black
        actlistbox=black,cyan
        sellistbox=black,cyan
        actsellistbox=white,blue
    '
    log "DEBUG" "Applied custom whiptail color scheme with enhanced button highlighting."
} # set_whiptail_colors

# Initialize whiptail colors at script start
set_whiptail_colors

################################################################################
# Environment Variable Management
################################################################################

# load_environment() is defined earlier at script startup (before first use)

# Load environment variables with defaults for ADS-specific variables
load_env_vars() {
    # Use the standard divtools environment loader
    load_environment
}

# Save environment variables with markers (divtools style)
save_env_vars() {
    local domain="$1"
    local realm="$2"
    local workgroup="$3"
    local admin_pass="$4"
    local host_ip="$5"
    local dns_forwarder="$6"
    
    log "INFO" "Saving ADS environment variables to $ENV_FILE"
    
    # Create directory if it doesn't exist
    mkdir -p "$(dirname "$ENV_FILE")"
    
    # Remove old auto-managed section if it exists
    if [[ -f "$ENV_FILE" ]] && grep -q "$ENV_MARKER_START" "$ENV_FILE"; then
        sed -i "/$ENV_MARKER_START/,/$ENV_MARKER_END/d" "$ENV_FILE"
    fi
    
    # Append new section
    cat >> "$ENV_FILE" <<EOF

$ENV_MARKER_START
# Samba AD DC Configuration
# Last Updated: $(date '+%m/%d/%Y %I:%M:%S %p %Z')
export ADS_DOMAIN="$domain"
export ADS_REALM="$realm"
export ADS_WORKGROUP="$workgroup"
export ADS_ADMIN_PASSWORD="$admin_pass"
export ADS_HOST_IP="$host_ip"
export ADS_DNS_FORWARDER="$dns_forwarder"
export ADS_SERVER_ROLE="dc"
export ADS_DOMAIN_LEVEL="2008_R2"
export ADS_LOG_LEVEL="1"
export SITE_NAME="$SITE_NAME"
export HOSTNAME="$HOSTNAME"
$ENV_MARKER_END
EOF
    
    log "INFO:!ts" "ADS environment variables saved successfully"
}

# Helper: Collect environment variables from user (PHASE 1 only - no confirmation display)
# Last Updated: 01/09/2026 9:15:00 PM CDT
collect_env_vars() {
    log "DEBUG" "Collecting environment variables..."
    
    # Prompt for each variable with existing value as default
    local domain
    domain=$(wt_inputbox "Domain Name" "Enter domain name (e.g., avctn.lan)" "${ADS_DOMAIN:-avctn.lan}")
    [[ $? -ne 0 ]] && { log "DEBUG" "User cancelled at domain prompt"; return 1; }
    
    local realm
    realm=$(wt_inputbox "Realm" "Enter realm in uppercase (e.g., AVCTN.LAN)" "${ADS_REALM:-AVCTN.LAN}")
    [[ $? -ne 0 ]] && { log "DEBUG" "User cancelled at realm prompt"; return 1; }
    
    local workgroup
    workgroup=$(wt_inputbox "Workgroup" "Enter NetBIOS workgroup name (e.g., AVCTN)" "${ADS_WORKGROUP:-AVCTN}")
    [[ $? -ne 0 ]] && { log "DEBUG" "User cancelled at workgroup prompt"; return 1; }
    
    local admin_pass
    admin_pass=$(wt_passwordbox "Administrator Password" "Enter administrator password")
    [[ $? -ne 0 ]] && { log "DEBUG" "User cancelled at password prompt"; return 1; }
    
    local host_ip
    host_ip=$(wt_inputbox "Host IP Address" "Enter the server's IP address (e.g., 10.1.1.98)\n\n" "${ADS_HOST_IP:-10.1.1.98}")
    [[ $? -ne 0 ]] && { log "DEBUG" "User cancelled at host IP prompt"; return 1; }
    
    local dns_forwarder
    dns_forwarder=$(wt_inputbox "DNS Forwarder" "Enter DNS forwarder IPs (space-separated)" "${ADS_DNS_FORWARDER:-10.1.1.111 8.8.8.8 8.8.4.4}")
    [[ $? -ne 0 ]] && { log "DEBUG" "User cancelled at DNS forwarder prompt"; return 1; }
    
    # Export collected values to global environment for use in ads_setup comprehensive confirmation
    export ADS_DOMAIN="$domain"
    export ADS_REALM="$realm"
    export ADS_WORKGROUP="$workgroup"
    export ADS_ADMIN_PASSWORD="$admin_pass"
    export ADS_HOST_IP="$host_ip"
    export ADS_DNS_FORWARDER="$dns_forwarder"
    
    # Echo pipe-delimited values for parsing by prompt_env_vars()
    echo "$domain|$realm|$workgroup|$admin_pass|$host_ip|$dns_forwarder"
    log "DEBUG" "Environment variables collected successfully"
    return 0
}

# Helper: Display environment variables summary for review
# Last Updated: 01/09/2026 8:30:00 PM CDT
display_env_vars_summary() {
    local domain=$1
    local realm=$2
    local workgroup=$3
    local admin_pass=$4
    local host_ip=$5
    local dns_forwarder=$6
    
    # Shorten path for display (use relative path from sites)
    local env_file_display="${ENV_FILE##*/docker/sites/}"
    
    # Build summary as array - ONE LINE PER ARRAY ELEMENT for accurate counting
    local -a summary_lines=(
        "═════════════════════════════════════════════════════════════════════"
        "ENVIRONMENT VARIABLES - REVIEW BEFORE SAVING"
        "═════════════════════════════════════════════════════════════════════"
        ""
        "Domain Name:              $domain"
        "Realm:                    $realm"
        "Workgroup:                $workgroup"
        "Administrator Password:   [${#admin_pass} characters]"
        "Host IP Address:          $host_ip"
        "DNS Forwarders:           $dns_forwarder"
        ""
        "═════════════════════════════════════════════════════════════════════"
        "These variables will be saved to:"
        "./sites/$env_file_display"
        ""
        "Press OK to proceed to confirmation, or Cancel to abort."
    )
    
    # Print array as multi-line output
    printf '%s\n' "${summary_lines[@]}"
    
    # Return the array length for height calculation
    echo "${#summary_lines[@]}"
}

# Helper: Execute environment variable saving (only called after user confirms)
# Last Updated: 01/09/2026 8:30:00 PM CDT
execute_env_vars_save() {
    local domain=$1
    local realm=$2
    local workgroup=$3
    local admin_pass=$4
    local host_ip=$5
    local dns_forwarder=$6
    
    log "DEBUG" "Executing environment variable save..."
    save_env_vars "$domain" "$realm" "$workgroup" "$admin_pass" "$host_ip" "$dns_forwarder"
    
    # Export for current session
    export ADS_DOMAIN="$domain"
    export ADS_REALM="$realm"
    export ADS_WORKGROUP="$workgroup"
    export ADS_ADMIN_PASSWORD="$admin_pass"
    export ADS_HOST_IP="$host_ip"
    export ADS_DNS_FORWARDER="$dns_forwarder"
    
    log "INFO:!ts" "Environment variables saved successfully"
}

# Prompt for environment variables (with Collect-Display-Confirm pattern)
# Last Updated: 01/09/2026 8:30:00 PM CDT
prompt_env_vars() {
    load_env_vars
    
    log "HEAD" "=== Edit Environment Variables ==="
    log "INFO" "[MENU SELECTION] Environment Variables configuration initiated"
    
    # Show intro message with cancel option
    if ! wt_yesno "Configure Environment Variables" "Configure ADS Environment Variables\n\nYou will be prompted for each required variable.\n\nPress ESC or Cancel at any prompt to return to menu.\n\nContinue?"; then
        log "DEBUG" "User cancelled environment variable configuration intro"
        return 1
    fi
    
    # PHASE 1: COLLECT
    log "DEBUG" "PHASE 1: Collecting environment variables..."
    local collected_data
    collected_data=$(collect_env_vars)
    [[ $? -ne 0 ]] && return 1  # User cancelled during input
    
    # Parse collected data
    local domain=$(echo "$collected_data" | cut -d'|' -f1)
    # PHASE 2: DISPLAY
    log "DEBUG" "PHASE 2: Displaying environment variables for review..."
    # Build summary array and display it
    local domain=$(echo "$collected_data" | cut -d'|' -f1)
    local realm=$(echo "$collected_data" | cut -d'|' -f2)
    local workgroup=$(echo "$collected_data" | cut -d'|' -f3)
    local admin_pass=$(echo "$collected_data" | cut -d'|' -f4)
    local host_ip=$(echo "$collected_data" | cut -d'|' -f5)
    local dns_forwarder=$(echo "$collected_data" | cut -d'|' -f6)
    
    # Shorten path for display (use relative path from sites)
    local env_file_display="${ENV_FILE##*/docker/sites/}"
    
    # Build summary as array - ONE LINE PER ARRAY ELEMENT for accurate counting
    local -a summary_lines=(
        "═════════════════════════════════════════════════════════════════════"
        "ENVIRONMENT VARIABLES - REVIEW BEFORE SAVING"
        "═════════════════════════════════════════════════════════════════════"
        ""
        "Domain Name:              $domain"
        "Realm:                    $realm"
        "Workgroup:                $workgroup"
        "Administrator Password:   [${#admin_pass} characters]"
        "Host IP Address:          $host_ip"
        "DNS Forwarders:           $dns_forwarder"
        ""
        "═════════════════════════════════════════════════════════════════════"
        "These variables will be saved to:"
        "./sites/$env_file_display"
        ""
        "Press OK to proceed to confirmation, or Cancel to abort."
    )
    
    # Build summary string from array
    local env_summary
    printf -v env_summary '%s\n' "${summary_lines[@]}"
    
    # Count array length directly for accurate height
    local env_lines=${#summary_lines[@]}
    log "DEBUG" "Environment summary has $env_lines lines of content"
    
    # Height = content lines + padding for borders/buttons (12 lines to ensure ALL content visible including filename line)
    local env_height=$((env_lines + 12))
    [[ $env_height -gt 34 ]] && env_height=34
    
    log "DEBUG" "Dialog height: $env_height (content: $env_lines + padding: 12)"
    if ! wt_yesno "Update Env File: .env.ads1-98" "$env_summary"; then
        log "DEBUG" "User cancelled at environment variables review"
        return 0
    fi
    
    # PHASE 4: EXECUTE (skip redundant PHASE 3 confirmation)
    
    # PHASE 4: EXECUTE
    log "DEBUG" "PHASE 4: Executing environment variable save..."
    execute_env_vars_save "$domain" "$realm" "$workgroup" "$admin_pass" "$host_ip" "$dns_forwarder"
    
    # No success msgbox - just return (Issue #1 fix: waste of time)
}

################################################################################
# Pre-flight Check Functions
################################################################################

check_systemd_resolved() {
    # Last Updated: 01/09/2026 10:30:00 AM CDT
    log "INFO" "Checking for systemd-resolved on port 53..."
    
    # Check if systemd-resolved is running
    if ! systemctl is-active --quiet systemd-resolved; then
        log "INFO:!ts" "✓ systemd-resolved is not running"
        return 0
    fi
    
    log "WARN" "systemd-resolved is currently running and listening on port 53"
    log "WARN" "Samba AD DC requires exclusive access to port 53 for DNS"
    log "WARN" "systemd-resolved will be stopped ONLY when you configure host DNS (atomic transaction)"
    
    # Inform user but DO NOT offer to stop it here
    whiptail --fb --msgbox "⚠️  IMPORTANT: systemd-resolved is running\n\nYou MUST configure host DNS (menu option 5) to properly\ndisable systemd-resolved with replacement DNS.\n\nDo NOT manually stop systemd-resolved without configuring\nreplacement DNS or the system will break!" 14 70
    
    log "INFO" "systemd-resolved check complete - will be handled during DNS configuration"
    return 0
}

################################################################################
# ADS Setup Functions
################################################################################

setup_folders() {
    log "INFO" "Creating folder structure..."
    
    if [[ $TEST_MODE -eq 1 ]]; then
        log "INFO" "[TEST] Would create: $SAMBA_DIR"
        log "INFO" "[TEST] Would create: $DATA_DIR/data"
        log "INFO" "[TEST] Would create: $DATA_DIR/config"
        log "INFO" "[TEST] Would create: $DATA_DIR/logs"
        return 0
    fi
    
    # Create sites directory structure
    mkdir -p "$SAMBA_DIR"
    log "INFO:!ts" "✓ Created folder: $SAMBA_DIR"
    
    # Create system directories for persisted data
    sudo mkdir -p "$DATA_DIR"/{data,config,logs}
    log "INFO:!ts" "✓ Created folders: $DATA_DIR/{data,config,logs}"
    
    # Set ownership
    sudo chown -R "$(whoami):$(whoami)" "$HOST_DIR"
    sudo chown -R root:root "$DATA_DIR"
    
    # Set permissions
    sudo chmod 755 "$DATA_DIR"
    sudo chmod 700 "$DATA_DIR/data"  # Sensitive data
    sudo chmod 755 "$DATA_DIR/config"
    sudo chmod 755 "$DATA_DIR/logs"
    
    log "INFO:!ts" "Folder structure created and configured successfully"
}

check_folders() {
    log "INFO" "Checking folder structure..."
    
    local all_good=1
    
    # Check sites directories
    if [[ ! -d "$SAMBA_DIR" ]]; then
        log "WARN" "Missing: $SAMBA_DIR"
        all_good=0
    fi
    
    # Check system directories
    for dir in "$DATA_DIR" "$DATA_DIR/data" "$DATA_DIR/config" "$DATA_DIR/logs"; do
        if [[ ! -d "$dir" ]]; then
            log "WARN" "Missing: $dir"
            all_good=0
        fi
    done
    
    # Check permissions on data directory
    if [[ -d "$DATA_DIR/data" ]]; then
        local perms=$(stat -c "%a" "$DATA_DIR/data")
        if [[ "$perms" != "700" ]]; then
            log "WARN" "Incorrect permissions on $DATA_DIR/data: $perms (expected 700)"
            all_good=0
        fi
    fi
    
    if [[ $all_good -eq 1 ]]; then
        log "INFO:!ts" "✓ All folders exist with correct permissions"
    else
        log "WARN:!ts" "✗ Some folders are missing or have incorrect permissions"
    fi
    
    return $((1 - all_good))
}

deploy_compose_files() {
    # Last Updated: 01/09/2026 8:40:00 PM CDT
    # REFACTORED: Collect file replacement preferences only, no execution
    log "INFO" "Collecting file deployment preferences..."
    
    load_env_vars
    
    # Check which files exist
    local dci_exists=0
    local dc_exists=0
    local entrypoint_exists=0
    local env_samba_exists=0
    
    [[ -f "$SAMBA_DIR/dci-samba.yml" ]] && dci_exists=1
    [[ -f "$HOST_DIR/dc-$HOSTNAME.yml" ]] && dc_exists=1
    [[ -f "$SAMBA_DIR/entrypoint.sh" ]] && entrypoint_exists=1
    [[ -f "$SAMBA_DIR/.env.samba" ]] && env_samba_exists=1
    
    # Handle each file individually
    local deploy_dci=0
    local deploy_dc=0
    local deploy_entrypoint=0
    local deploy_env_samba=0
    
    # dci-samba.yml
    if [[ $dci_exists -eq 1 ]]; then
        if wt_yesno "File Exists: dci-samba.yml" "$SAMBA_DIR/dci-samba.yml already exists.\n\nReplace it?"; then
            deploy_dci=1
        else
            [[ $? -eq 1 ]] && { log "DEBUG" "User pressed ESC - cancelling file deployment"; return 1; }
        fi
    else
        deploy_dci=1  # File missing, always deploy
    fi
    
    # dc-$HOSTNAME.yml
    if [[ $dc_exists -eq 1 ]]; then
        if wt_yesno "File Exists" "dc-$HOSTNAME.yml exists. Replace it?"; then
            deploy_dc=1
        else
            [[ $? -eq 1 ]] && { log "DEBUG" "User pressed ESC - cancelling file deployment"; return 1; }
        fi
    else
        deploy_dc=1  # File missing, always deploy
    fi
    
    # entrypoint.sh
    if [[ $entrypoint_exists -eq 1 ]]; then
        if wt_yesno "File Exists" "entrypoint.sh exists. Replace it?"; then
            deploy_entrypoint=1
        else
            [[ $? -eq 1 ]] && { log "DEBUG" "User pressed ESC - cancelling file deployment"; return 1; }
        fi
    else
        deploy_entrypoint=1  # File missing, always deploy
    fi
    
    # .env.samba - only create if vars are NOT in .env.$HOSTNAME
    if [[ $env_samba_exists -eq 1 ]]; then
        if wt_yesno "File Exists" ".env.samba exists. Replace it?"; then
            deploy_env_samba=1
        else
            [[ $? -eq 1 ]] && { log "DEBUG" "User pressed ESC - cancelling file deployment"; return 1; }
        fi
    else
        # Check if ADS vars exist in .env.$HOSTNAME
        if [[ -f "$ENV_FILE" ]] && grep -q "ADS_DOMAIN" "$ENV_FILE"; then
            log "INFO" "ADS variables found in $ENV_FILE, skipping .env.samba creation"
            deploy_env_samba=0
        else
            if wt_yesno "Create Environment File" "Create .env.samba override file?\n\n(Only needed if divtools env vars not used)"; then
                deploy_env_samba=1
            else
                [[ $? -eq 1 ]] && { log "DEBUG" "User pressed ESC - cancelling file deployment"; return 1; }
            fi
        fi
    fi
    
    # Execute deployments with collected flags
    execute_deploy_compose_files "$deploy_dci" "$deploy_dc" "$deploy_entrypoint" "$deploy_env_samba"
}

# Helper: Execute file deployment after user confirms settings
# Last Updated: 01/09/2026 8:40:00 PM CDT
execute_deploy_compose_files() {
    local deploy_dci=$1
    local deploy_dc=$2
    local deploy_entrypoint=$3
    local deploy_env_samba=$4
    
    log "INFO" "Deploying docker-compose files..."
    
    if [[ $TEST_MODE -eq 1 ]]; then
        [[ $deploy_dci -eq 1 ]] && log "INFO" "[TEST] Would backup and copy: dci-samba.yml → $SAMBA_DIR/dci-samba.yml"
        [[ $deploy_dc -eq 1 ]] && log "INFO" "[TEST] Would backup and copy: dc-$HOSTNAME.yml → $HOST_DIR/dc-$HOSTNAME.yml"
        [[ $deploy_entrypoint -eq 1 ]] && log "INFO" "[TEST] Would backup and copy: entrypoint.sh → $SAMBA_DIR/entrypoint.sh"
        [[ $deploy_env_samba -eq 1 ]] && log "INFO" "[TEST] Would create: .env.samba → $SAMBA_DIR/.env.samba"
        return 0
    fi
    
    # Copy files with backup and full path logging (Issue #2 fix)
    if [[ $deploy_dci -eq 1 ]]; then
        # Only backup and copy if files are different
        if [[ ! -f "$SAMBA_DIR/dci-samba.yml" ]] || ! cmp -s "$PHASE1_CONFIGS/docker-compose/dci-samba.yml" "$SAMBA_DIR/dci-samba.yml"; then
            backup_file "$SAMBA_DIR/dci-samba.yml"  # Backup before overwriting
            cp "$PHASE1_CONFIGS/docker-compose/dci-samba.yml" "$SAMBA_DIR/"
            log "INFO:!ts" "✓ Deployed dci-samba.yml → $SAMBA_DIR/dci-samba.yml"
        else
            log "INFO" "dci-samba.yml - File unchanged, skipping copy"
        fi
    fi
    
    if [[ $deploy_dc -eq 1 ]]; then
        # Only backup and copy if files are different (check source file, not including our append section)
        if [[ ! -f "$HOST_DIR/dc-$HOSTNAME.yml" ]] || ! cmp -s "$PHASE1_CONFIGS/docker-compose/dc-$HOSTNAME.yml" "$HOST_DIR/dc-$HOSTNAME.yml"; then
            backup_file "$HOST_DIR/dc-$HOSTNAME.yml"  # Backup before overwriting
            cp "$PHASE1_CONFIGS/docker-compose/dc-$HOSTNAME.yml" "$HOST_DIR/"
            log "INFO:!ts" "✓ Deployed dc-$HOSTNAME.yml → $HOST_DIR/dc-$HOSTNAME.yml"
        else
            log "INFO" "dc-$HOSTNAME.yml - File unchanged, skipping copy"
        fi
        
        # Append samba include with markers for future updates (always check first)
        if ! grep -q "DT_ADS_SETUP AUTO-MANAGED" "$HOST_DIR/dc-$HOSTNAME.yml"; then
            cat >> "$HOST_DIR/dc-$HOSTNAME.yml" <<'EOF'

  # >>> DT_ADS_SETUP AUTO-MANAGED - DO NOT EDIT MANUALLY <<<
  # Samba Active Directory Domain Controller
  - $DOCKER_HOSTDIR/samba/dci-samba.yml
  # <<< DT_ADS_SETUP AUTO-MANAGED <<<
EOF
            log "INFO:!ts" "✓ Added samba include section to dc-$HOSTNAME.yml"
        else
            log "INFO" "Samba include section already present, skipping append"
        fi
    fi
    
    if [[ $deploy_entrypoint -eq 1 ]]; then
        # Only backup and copy if files are different
        if [[ ! -f "$SAMBA_DIR/entrypoint.sh" ]] || ! cmp -s "$PHASE1_CONFIGS/scripts/entrypoint.sh" "$SAMBA_DIR/entrypoint.sh"; then
            backup_file "$SAMBA_DIR/entrypoint.sh"  # Backup before overwriting
            cp "$PHASE1_CONFIGS/scripts/entrypoint.sh" "$SAMBA_DIR/"
            chmod +x "$SAMBA_DIR/entrypoint.sh"
            log "INFO:!ts" "✓ Deployed entrypoint.sh → $SAMBA_DIR/entrypoint.sh"
        else
            log "INFO" "entrypoint.sh - File unchanged, skipping copy"
        fi
    fi
    
    # Create .env.samba from variables (only if requested) - with full path logging
    if [[ $deploy_env_samba -eq 1 ]]; then
        # Generate temp file to check if content would be different
        local temp_env=$(mktemp)
        cat > "$temp_env" <<EOF
# Samba AD DC Environment Variables Override
# Last Updated: $(date '+%m/%d/%Y %I:%M:%S %p %Z')
# NOTE: If using divtools, set these in $ENV_FILE instead
#       This file is only for systems without divtools

# Basic Configuration
ADS_DOMAIN=${ADS_DOMAIN:-avctn.lan}
ADS_REALM=${ADS_REALM:-AVCTN.LAN}
ADS_WORKGROUP=${ADS_WORKGROUP:-AVCTN}
ADS_ADMIN_PASSWORD=${ADS_ADMIN_PASSWORD}
ADS_HOST_IP=${ADS_HOST_IP:-10.1.1.98}
ADS_DNS_FORWARDER=${ADS_DNS_FORWARDER:-10.1.1.111 8.8.8.8 8.8.4.4}

# Advanced Configuration
ADS_SERVER_ROLE=dc
ADS_DOMAIN_LEVEL=2008_R2
ADS_LOG_LEVEL=1

# Site Configuration
SITE_NAME=${SITE_NAME}
HOSTNAME=${HOSTNAME}
EOF
        
        # Only backup and copy if files are different
        if [[ ! -f "$SAMBA_DIR/.env.samba" ]] || ! cmp -s "$temp_env" "$SAMBA_DIR/.env.samba"; then
            backup_file "$SAMBA_DIR/.env.samba"  # Backup before overwriting
            cp "$temp_env" "$SAMBA_DIR/.env.samba"
            log "INFO:!ts" "✓ Created .env.samba → $SAMBA_DIR/.env.samba"
        else
            log "INFO" ".env.samba - File unchanged, skipping copy"
        fi
        
        rm -f "$temp_env"  # Clean up temp file
    fi
    
    log "INFO:!ts" "Docker compose file deployment completed"
}

check_compose_files() {
    log "INFO" "Checking docker-compose files..."
    
    local all_good=1
    
    # Check required files
    local files=(
        "$SAMBA_DIR/dci-samba.yml"
        "$HOST_DIR/dc-$HOSTNAME.yml"
        "$SAMBA_DIR/entrypoint.sh"
        "$SAMBA_DIR/.env.samba"
    )
    
    for file in "${files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log "WARN" "Missing: $file"
            all_good=0
        fi
    done
    
    # Check entrypoint is executable
    if [[ -f "$SAMBA_DIR/entrypoint.sh" ]]; then
        if [[ ! -x "$SAMBA_DIR/entrypoint.sh" ]]; then
            log "WARN" "Not executable: $SAMBA_DIR/entrypoint.sh"
            all_good=0
        fi
    fi
    
    # Validate include directive in dc-*.yml
    if [[ -f "$HOST_DIR/dc-$HOSTNAME.yml" ]]; then
        if ! grep -q "include:" "$HOST_DIR/dc-$HOSTNAME.yml"; then
            log "WARN" "Missing 'include:' directive in dc-$HOSTNAME.yml"
            all_good=0
        fi
    fi
    
    if [[ $all_good -eq 1 ]]; then
        log "INFO:!ts" "✓ All compose files exist and are valid"
    else
        log "WARN:!ts" "✗ Some compose files are missing or invalid"
    fi
    
    return $((1 - all_good))
}

ads_setup() {
    # Last Updated: 01/09/2026 9:05:00 PM CDT
    # REFACTORED: Proper Collect-Display-Confirm pattern (Issue #3 fix)
    log "HEAD" "=== ADS Setup ==="
    log "INFO" "[MENU SELECTION] ADS Setup initiated"
    
    # Pre-check: DNS must be configured first
    if systemctl is-active --quiet systemd-resolved; then
        log "WARN" "systemd-resolved is still running - DNS not configured yet"
        if ! wt_yesno "DNS Not Configured" "systemd-resolved is still active!\n\nYou should configure DNS first (menu option 1)\nbefore running ADS Setup.\n\nContinue anyway?"; then
            log "INFO" "Setup cancelled - user will configure DNS first"
            return 0
        fi
    fi
    
    # PHASE 1: SETUP
    log "DEBUG" "PHASE 1: Loading ADS setup settings..."
    
    # Load existing environment variables (user should edit via Option 2 if needed)
    load_env_vars
    log "DEBUG" "Environment variables loaded for deployment"
    
    local dci_exists=0
    local dc_exists=0
    local entrypoint_exists=0
    local env_samba_exists=0
    
    [[ -f "$SAMBA_DIR/dci-samba.yml" ]] && dci_exists=1
    [[ -f "$HOST_DIR/dc-$HOSTNAME.yml" ]] && dc_exists=1
    [[ -f "$SAMBA_DIR/entrypoint.sh" ]] && entrypoint_exists=1
    [[ -f "$SAMBA_DIR/.env.samba" ]] && env_samba_exists=1
    
    # All files will be deployed (except .env.samba - check if vars already in .env.$HOSTNAME)
    local deploy_dci=1
    local deploy_dc=1
    local deploy_entrypoint=1
    
    # Determine if .env.samba should be deployed
    local deploy_env_samba=1
    if [[ -f "$ENV_FILE" ]] && grep -q "ADS_DOMAIN" "$ENV_FILE"; then
        log "DEBUG" "ADS variables already exist in $ENV_FILE - will not create .env.samba"
        deploy_env_samba=0
    fi
    
    # PHASE 2: DISPLAY COMPREHENSIVE CONFIRMATION
    log "DEBUG" "PHASE 2: Displaying comprehensive setup confirmation..."
    
    # Shorten paths for display
    local samba_display="${SAMBA_DIR##*/docker/sites/}"
    local host_display="${HOST_DIR##*/docker/sites/}"
    local env_file_short="$host_display/.env.$HOSTNAME"
    
    # Build confirmation array
    local -a confirm_lines=(
        "═════════════════════════════════════════════════════════"
        "ADS SETUP - COMPREHENSIVE CONFIRMATION"
        "═════════════════════════════════════════════════════════"
        ""
        "ENVIRONMENT VARIABLES:"
    )
    
    confirm_lines+=("  Status:            USING EXISTING VALUES")
    
    confirm_lines+=(
        "  Domain:            $ADS_DOMAIN"
        "  Realm:             $ADS_REALM"
        "  Workgroup:         $ADS_WORKGROUP"
        "  Host IP:           $ADS_HOST_IP"
        "  DNS Forwarders:    $ADS_DNS_FORWARDER"
        ""
        "FOLDER STRUCTURE:"
        "  Create: ./sites/$samba_display"
        "  Create: ./sites/$host_display"
        ""
        "FILES TO DEPLOY:"
    )
    
    # Use printf for fixed-width columns (file:action alignment)
    # dc-$HOSTNAME.yml - FIRST (main file that includes others)
    if [[ $dc_exists -eq 1 ]]; then
        confirm_lines+=("$(printf '  %-20s %-45s' "dc-$HOSTNAME.yml:" 'APPEND (backup created)')")
    else
        confirm_lines+=("$(printf '  %-20s %-45s' "dc-$HOSTNAME.yml:" 'CREATE NEW')")
    fi
    
    # dci-samba.yml - SECOND
    if [[ $dci_exists -eq 1 ]]; then
        confirm_lines+=("$(printf '  %-20s %-45s' 'dci-samba.yml:' 'OVERWRITE (backup created)')")
    else
        confirm_lines+=("$(printf '  %-20s %-45s' 'dci-samba.yml:' 'CREATE NEW')")
    fi
    
    # entrypoint.sh
    if [[ $entrypoint_exists -eq 1 ]]; then
        confirm_lines+=("$(printf '  %-20s %-45s' 'entrypoint.sh:' 'OVERWRITE (backup created)')")
    else
        confirm_lines+=("$(printf '  %-20s %-45s' 'entrypoint.sh:' 'CREATE NEW')")
    fi
    
    # .env.samba - only if variables don't exist in .env.$HOSTNAME
    if [[ $deploy_env_samba -eq 1 ]]; then
        if [[ $env_samba_exists -eq 1 ]]; then
            confirm_lines+=("$(printf '  %-20s %-45s' '.env.samba:' 'OVERWRITE (backup created)')")
        else
            confirm_lines+=("$(printf '  %-20s %-45s' '.env.samba:' 'CREATE NEW')")
        fi
    else
        confirm_lines+=("$(printf '  %-20s %-45s' '.env.samba:' 'WILL NOT BE CREATED')")
        confirm_lines+=("  Note: Vars already in $env_file_short")
    fi
    
    confirm_lines+=(
        ""
        "═════════════════════════════════════════════════════════"
        "Proceed with these actions?"
    )
    
    # Build confirmation string from array
    local confirm_message
    printf -v confirm_message '%s\n' "${confirm_lines[@]}"
    
    # Count array length for accurate height
    local confirm_lines_count=${#confirm_lines[@]}
    local confirm_height=$((confirm_lines_count + 8))
    [[ $confirm_height -gt 35 ]] && confirm_height=35
    
    log "DEBUG" "Confirmation dialog: $confirm_lines_count lines + 8 padding = height $confirm_height"
    
    if ! wt_yesno "ADS Setup - Confirm All Actions" "$confirm_message"; then
        log "DEBUG" "User cancelled at comprehensive confirmation"
        return 0
    fi
    
    # PHASE 3: EXECUTE ALL ACTIONS
    log "DEBUG" "PHASE 3: Executing all confirmed actions..."
    
    # Create folders
    log "INFO" "Creating folder structure..."
    setup_folders
    check_folders
    
    # Deploy compose files (with automatic backups)
    log "INFO" "Deploying docker-compose files..."
    execute_deploy_compose_files "$deploy_dci" "$deploy_dc" "$deploy_entrypoint" "$deploy_env_samba"
    check_compose_files
    
    # PHASE 4: DISPLAY STATUS SUMMARY
    log "DEBUG" "PHASE 4: Displaying status summary..."
    
    # Build status array
    local -a status_lines=(
        "═════════════════════════════════════════════════════════"
        "ADS SETUP - STATUS SUMMARY"
        "═════════════════════════════════════════════════════════"
        ""
        "COMPLETED ACTIONS:"
        ""
    )
    
    # Environment variables status - split into two lines to avoid wrapping
    status_lines+=("✓ Used existing environment variables from:")
    status_lines+=("  $env_file_short")
    
    status_lines+=(
        ""
        "✓ Folder structure created:"
        "  ./sites/$samba_display"
        "  ./sites/$host_display"
        ""
        "✓ Files deployed:"
    )
    
    # File deployment status with backup notes (in same order as confirmation)
    if [[ $dc_exists -eq 1 ]]; then
        status_lines+=("  dc-$HOSTNAME.yml (backup created + samba include appended)")
    else
        status_lines+=("  dc-$HOSTNAME.yml (new file + samba include added)")
    fi
    
    if [[ $dci_exists -eq 1 ]]; then
        status_lines+=("  dci-samba.yml (backup created)")
    else
        status_lines+=("  dci-samba.yml (new file)")
    fi
    
    if [[ $entrypoint_exists -eq 1 ]]; then
        status_lines+=("  entrypoint.sh (backup created)")
    else
        status_lines+=("  entrypoint.sh (new file)")
    fi
    
    if [[ $deploy_env_samba -eq 1 ]]; then
        if [[ $env_samba_exists -eq 1 ]]; then
            status_lines+=("  .env.samba (backup created)")
        else
            status_lines+=("  .env.samba (new file)")
        fi
    else
        status_lines+=("  .env.samba (NOT CREATED)")
        status_lines+=("    Vars already in: $env_file_short")
    fi
    
    status_lines+=("")
    
    # Docker network status
    if [[ $create_network -eq 1 ]]; then
        status_lines+=("✓ Docker network created: $network_name")
    else
        status_lines+=("✓ Docker network verified: $network_name")
    fi
    
    status_lines+=(
        ""
        "═════════════════════════════════════════════════════════"
        "Next steps:"
        "1. Review configuration files"
        "2. Start the container from the main menu"
    )
    
    # Build status string from array
    local status_message
    printf -v status_message '%s\n' "${status_lines[@]}"
    
    # Count array length for accurate height
    local status_lines_count=${#status_lines[@]}
    local status_height=$((status_lines_count + 8))
    [[ $status_height -gt 35 ]] && status_height=35
    
    log "INFO:!ts" "ADS Setup completed successfully"
    wt_msgbox "ADS Setup Complete" "$status_message"
}

################################################################################
# Container Management
################################################################################

start_container() {
    log "HEAD" "=== Start Samba Container ==="
    log "INFO" "[MENU SELECTION] Container Start initiated"
    
    # Check if container is already running
    if docker ps | grep -q "samba-ads"; then
        log "WARN" "Container 'samba-ads' is already running"
        if ! whiptail --fb --yesno "Container is already running. Restart it?" 10 60; then
            log "DEBUG" "User declined container restart"
            return 0
        fi
        
        log "DEBUG" "User confirmed container restart"
        if [[ $TEST_MODE -eq 1 ]]; then
            log "INFO" "[TEST] Would restart container"
            return 0
        fi
        
        log "INFO" "Restarting container 'samba-ads'..."
        docker restart samba-ads
        log "INFO:!ts" "✓ Container restarted"
        return 0
    fi
    
    log "DEBUG" "Container 'samba-ads' is not running, will start it"
    
    if [[ $TEST_MODE -eq 1 ]]; then
        log "INFO" "[TEST] Would start container with: docker compose -f $HOST_DIR/dc-$HOSTNAME.yml up -d"
        return 0
    fi
    
    # Start container
    log "INFO" "Starting container with docker compose..."
    cd "$HOST_DIR" || return 1
    docker compose -f "dc-$HOSTNAME.yml" up -d
    
    if [[ $? -eq 0 ]]; then
        log "INFO:!ts" "✓ Container started successfully"
    else
        log "ERROR" "Failed to start container"
        return 1
    fi
    
    # Show logs
    if whiptail --fb --yesno "Container started. Watch logs?" 10 60; then
        log "INFO" "User requested to watch logs (Ctrl+C to stop)"
        sleep 2
        docker logs -f samba-ads
    else
        log "DEBUG" "User declined to watch logs"
    fi
}

stop_container() {
    log "HEAD" "=== Stop Samba Container ==="
    log "INFO" "[MENU SELECTION] Container Stop initiated"
    
    if ! docker ps | grep -q "samba-ads"; then
        log "WARN" "Container 'samba-ads' is not running"
        whiptail --fb --msgbox "Container 'samba-ads' is not currently running." 8 60
        return 1
    fi
    
    if ! whiptail --fb --yesno "Stop the samba-ads container?" 10 60; then
        log "DEBUG" "User declined to stop container"
        return 0
    fi
    
    log "DEBUG" "User confirmed container stop"
    
    if [[ $TEST_MODE -eq 1 ]]; then
        log "INFO" "[TEST] Would stop container"
        return 0
    fi
    
    log "INFO" "Stopping container 'samba-ads'..."
    docker stop samba-ads
    log "INFO:!ts" "✓ Container stopped"
}

################################################################################
# Bash Aliases Management (Quality-of-Life Enhancement)
################################################################################

install_bash_aliases() {
    # Last Updated: 01/10/2026 4:00:00 PM CDT
    log "HEAD" "=== Install Samba Bash Aliases ==="
    log "INFO" "[MENU SELECTION] Bash Aliases Installation initiated"

    local source_file="$PROJECT_ROOT/projects/ads/samba-aliases.sh"
    local dotfiles_dir="$PROJECT_ROOT/dotfiles"
    local dotfiles_aliases="$dotfiles_dir/samba-aliases.sh"
    local user_bash_aliases="$HOME/.bash_aliases"
    local divtools_bash_aliases="$dotfiles_dir/.bash_aliases"

    # Check if source file exists
    if [[ ! -f "$source_file" ]]; then
        log "ERROR" "Source aliases file not found: $source_file"
        whiptail --fb --msgbox "ERROR: samba-aliases.sh not found at:\\n\\n$source_file" 10 60
        return 1
    fi

    # Helper function to create/update softlink
    create_softlink() {
        local link_target="$dotfiles_aliases"
        local link_source="../projects/ads/samba-aliases.sh"

        log "DEBUG" "Creating/updating softlink: $link_target -> $link_source"

        if [[ $TEST_MODE -eq 1 ]]; then
            log "INFO" "[TEST] Would create softlink: ln -sf $link_source $link_target"
            return 0
        fi

        # Create the softlink (relative path from dotfiles to projects/ads)
        if ln -sf "$link_source" "$link_target"; then
            log "INFO:!ts" "✓ Created/updated softlink: $link_target -> $link_source"
            return 0
        else
            log "ERROR" "Failed to create softlink: $link_target -> $link_source"
            return 1
        fi
    }

    # Helper function to add include to file
    add_include_to_file() {
        local target_file="$1"
        local include_line="source \"\$DIVTOOLS/dotfiles/samba-aliases.sh\""

        log "DEBUG" "Adding include to: $target_file"

        # Check if include already exists
        if [[ -f "$target_file" ]] && grep -q "source.*samba-aliases.sh" "$target_file"; then
            log "WARN" "Include for samba-aliases.sh already exists in $target_file"
            if ! whiptail --fb --yesno "Include already exists in:\\n\\n$target_file\\n\\nAdd it anyway (might cause duplicates)?" 10 60; then
                log "DEBUG" "User cancelled due to existing include"
                return 0
            fi
        fi

        if [[ $TEST_MODE -eq 1 ]]; then
            log "INFO" "[TEST] Would append '$include_line' to $target_file"
            return 0
        fi

        # Add the include at the end of the file
        echo -e "\n# Samba AD DC Bash Aliases\n$include_line" >> "$target_file"
        log "INFO:!ts" "✓ Added include to $target_file"
        return 0
    }

    # Show user options
    local choice=$(whiptail --fb --title "Bash Aliases Installation" --menu \
        "Choose how to install Samba bash aliases:" 20 80 4 \
        "1" "Create softlink in dotfiles + include in ~/.bash_aliases" \
        "2" "Create softlink in dotfiles + include in dotfiles/.bash_aliases" \
        "3" "Create softlink in dotfiles only" \
        "4" "Cancel" \
        3>&1 1>&2 2>&3)

    case $choice in
        1)
            log "INFO" "User chose: Create softlink + include in ~/.bash_aliases"

            # Create softlink first
            if ! create_softlink; then
                whiptail --fb --msgbox "Failed to create softlink.\\n\\nCheck logs for details." 10 60
                return 1
            fi

            # Add include to user's ~/.bash_aliases
            if ! add_include_to_file "$user_bash_aliases"; then
                whiptail --fb --msgbox "Failed to add include to ~/.bash_aliases.\\n\\nCheck logs for details." 10 60
                return 1
            fi

            whiptail --fb --msgbox "Installation Complete!\\n\\n✓ Softlink created: dotfiles/samba-aliases.sh\\n✓ Include added to ~/.bash_aliases\\n\\nRun 'source ~/.bash_aliases' to activate." 12 60
            ;;

        2)
            log "INFO" "User chose: Create softlink + include in dotfiles/.bash_aliases"

            # Create softlink first
            if ! create_softlink; then
                whiptail --fb --msgbox "Failed to create softlink.\\n\\nCheck logs for details." 10 60
                return 1
            fi

            # Add include to divtools .bash_aliases
            if ! add_include_to_file "$divtools_bash_aliases"; then
                whiptail --fb --msgbox "Failed to add include to dotfiles/.bash_aliases.\\n\\nCheck logs for details." 10 60
                return 1
            fi

            whiptail --fb --msgbox "Installation Complete!\\n\\n✓ Softlink created: dotfiles/samba-aliases.sh\\n✓ Include added to dotfiles/.bash_aliases\\n\\nThis will work on ALL systems using divtools." 12 60
            ;;

        3)
            log "INFO" "User chose: Create softlink only"

            # Create softlink
            if ! create_softlink; then
                whiptail --fb --msgbox "Failed to create softlink.\\n\\nCheck logs for details." 10 60
                return 1
            fi

            whiptail --fb --msgbox "Softlink Created!\\n\\n✓ dotfiles/samba-aliases.sh -> ../projects/ads/samba-aliases.sh\\n\\nYou can now manually source this file or add includes as needed." 10 60
            ;;

        4|"")
            log "DEBUG" "User cancelled bash aliases installation"
            ;;
    esac
}

configure_local_dns() {
    # Last Updated: 01/09/2026 1:00:00 PM CDT
    log "HEAD" "=== Configure Local DNS Entries ==="
    log "INFO" "[MENU SELECTION] Local DNS Configuration initiated"
    
    # Check if container is running
    if ! docker ps | grep -q "samba-ads"; then
        log "ERROR" "Container 'samba-ads' is not running"
        whiptail --fb --msgbox "ERROR: Container 'samba-ads' is not running.\n\nStart the container first to configure DNS entries." 10 60
        return 1
    fi
    
    load_env_vars
    
    while true; do
        local choice=$(whiptail --fb --title "Local DNS Configuration" --menu \
            "Choose DNS operation:" 18 70 8 \
            "1" "Add A Record (hostname → IP)" \
            "2" "Add CNAME Record (alias → hostname)" \
            "3" "Add Wildcard A Record (*.domain → IP)" \
            "4" "List Current DNS Records" \
            "5" "Remove DNS Record" \
            "6" "Return to Main Menu" \
            3>&1 1>&2 2>&3)
        
        case $choice in
            1)  # Add A Record
                add_dns_a_record
                ;;
            2)  # Add CNAME Record
                add_dns_cname_record
                ;;
            3)  # Add Wildcard A Record
                add_dns_wildcard_record
                ;;
            4)  # List DNS Records
                list_dns_records
                ;;
            5)  # Remove DNS Record
                remove_dns_record
                ;;
            6|"")  # Return to Main Menu
                log "DEBUG" "User returned to main menu"
                return 0
                ;;
        esac
    done
}

add_dns_a_record() {
    log "INFO" "Adding A record..."
    
    local hostname=$(whiptail --fb --inputbox "Enter hostname (without domain):\n\nExample: traefik" 10 60 3>&1 1>&2 2>&3)
    [[ $? -ne 0 ]] && return 1
    
    local ip=$(whiptail --fb --inputbox "Enter IP address:\n\nExample: 10.1.1.103" 10 60 3>&1 1>&2 2>&3)
    [[ $? -ne 0 ]] && return 1
    
    if [[ $TEST_MODE -eq 1 ]]; then
        log "INFO" "[TEST] Would add A record: $hostname.${ADS_DOMAIN} → $ip"
        return 0
    fi
    
    log "INFO" "Adding A record: $hostname.${ADS_DOMAIN} → $ip"
    if docker exec samba-ads samba-tool dns add 127.0.0.1 ${ADS_DOMAIN} $hostname A $ip -U Administrator%${ADS_ADMIN_PASSWORD}; then
        log "INFO:!ts" "✓ A record added successfully"
        whiptail --fb --msgbox "A Record Added Successfully!\n\n$hostname.${ADS_DOMAIN} → $ip" 10 60
    else
        log "ERROR" "Failed to add A record"
        whiptail --fb --msgbox "ERROR: Failed to add A record.\n\nCheck container logs for details." 10 60
    fi
}

add_dns_cname_record() {
    log "INFO" "Adding CNAME record..."
    
    local alias=$(whiptail --fb --inputbox "Enter alias name (without domain):\n\nExample: www" 10 60 3>&1 1>&2 2>&3)
    [[ $? -ne 0 ]] && return 1
    
    local target=$(whiptail --fb --inputbox "Enter target hostname (FQDN):\n\nExample: traefik.${ADS_DOMAIN}" 10 60 3>&1 1>&2 2>&3)
    [[ $? -ne 0 ]] && return 1
    
    if [[ $TEST_MODE -eq 1 ]]; then
        log "INFO" "[TEST] Would add CNAME record: $alias.${ADS_DOMAIN} → $target"
        return 0
    fi
    
    log "INFO" "Adding CNAME record: $alias.${ADS_DOMAIN} → $target"
    if docker exec samba-ads samba-tool dns add 127.0.0.1 ${ADS_DOMAIN} $alias CNAME $target -U Administrator%${ADS_ADMIN_PASSWORD}; then
        log "INFO:!ts" "✓ CNAME record added successfully"
        whiptail --fb --msgbox "CNAME Record Added Successfully!\n\n$alias.${ADS_DOMAIN} → $target" 10 60
    else
        log "ERROR" "Failed to add CNAME record"
        whiptail --fb --msgbox "ERROR: Failed to add CNAME record.\n\nCheck container logs for details." 10 60
    fi
}

add_dns_wildcard_record() {
    log "INFO" "Adding wildcard A record..."
    
    local subdomain=$(whiptail --fb --inputbox "Enter subdomain prefix:\n\nExample: l1\n\nThis will create: *.l1.${ADS_DOMAIN}" 12 60 3>&1 1>&2 2>&3)
    [[ $? -ne 0 ]] && return 1
    
    local ip=$(whiptail --fb --inputbox "Enter IP address for all *.${subdomain} records:\n\nExample: 10.1.1.103" 10 60 3>&1 1>&2 2>&3)
    [[ $? -ne 0 ]] && return 1
    
    # Samba doesn't support true wildcards, but we can create a delegation or use a script approach
    # For now, we'll create a few common subdomains as an approximation
    local common_subs=("www" "api" "mail" "ftp" "test" "dev" "staging")
    
    if [[ $TEST_MODE -eq 1 ]]; then
        log "INFO" "[TEST] Would add wildcard records for *.${subdomain}.${ADS_DOMAIN} → $ip"
        return 0
    fi
    
    log "INFO" "Adding wildcard approximation for *.${subdomain}.${ADS_DOMAIN} → $ip"
    
    local success_count=0
    local fail_count=0
    
    # Create delegation zone for the subdomain
    if docker exec samba-ads samba-tool dns zonecreate 127.0.0.1 ${subdomain}.${ADS_DOMAIN} -U Administrator%${ADS_ADMIN_PASSWORD} 2>/dev/null; then
        log "INFO" "Created DNS zone: ${subdomain}.${ADS_DOMAIN}"
        
        # Add NS record pointing to this server
        docker exec samba-ads samba-tool dns add 127.0.0.1 ${ADS_DOMAIN} ${subdomain} NS $(hostname).${ADS_DOMAIN} -U Administrator%${ADS_ADMIN_PASSWORD} 2>/dev/null || true
        
        # Add wildcard A record in the subdomain zone
        docker exec samba-ads samba-tool dns add 127.0.0.1 ${subdomain}.${ADS_DOMAIN} '*' A $ip -U Administrator%${ADS_ADMIN_PASSWORD} 2>/dev/null || true
        
        log "INFO:!ts" "✓ Wildcard zone created: *.${subdomain}.${ADS_DOMAIN} → $ip"
        whiptail --fb --msgbox "Wildcard DNS Zone Created!\n\n*.${subdomain}.${ADS_DOMAIN} → $ip\n\nNote: This creates a DNS zone delegation.\nAll *.${subdomain} queries will resolve to $ip." 12 60
    else
        log "WARN" "Zone creation failed, trying individual records..."
        
        # Fallback: create individual records for common subdomains
        for sub in "${common_subs[@]}"; do
            if docker exec samba-ads samba-tool dns add 127.0.0.1 ${ADS_DOMAIN} ${sub}.${subdomain} A $ip -U Administrator%${ADS_ADMIN_PASSWORD} 2>/dev/null; then
                ((success_count++))
            else
                ((fail_count++))
            fi
        done
        
        log "INFO:!ts" "✓ Added $success_count common subdomain records"
        if [[ $fail_count -gt 0 ]]; then
            log "WARN" "$fail_count records failed (may already exist)"
        fi
        
        whiptail --fb --msgbox "DNS Records Added!\n\nAdded records for common subdomains:\n${subdomain}.www, ${subdomain}.api, ${subdomain}.mail, etc.\n\nAll resolve to: $ip\n\nFor true wildcards, consider DNS zone delegation." 14 60
    fi
}

list_dns_records() {
    log "INFO" "Listing DNS records..."
    
    if [[ $TEST_MODE -eq 1 ]]; then
        log "INFO" "[TEST] Would list DNS records for ${ADS_DOMAIN}"
        return 0
    fi
    
    log "INFO" "Retrieving DNS records for zone: ${ADS_DOMAIN}"
    
    # Get DNS records and format for display
    local records
    records=$(docker exec samba-ads samba-tool dns query 127.0.0.1 ${ADS_DOMAIN} @ ALL -U Administrator%${ADS_ADMIN_PASSWORD} 2>/dev/null | head -50)
    
    if [[ -n "$records" ]]; then
        whiptail --fb --textbox <(echo "$records") 30 100
    else
        whiptail --fb --msgbox "No DNS records found or unable to retrieve.\n\nCheck that the container is running and domain is provisioned." 10 60
    fi
}

remove_dns_record() {
    log "INFO" "Removing DNS record..."
    
    local name=$(whiptail --fb --inputbox "Enter record name (without domain):\n\nExample: traefik" 10 60 3>&1 1>&2 2>&3)
    [[ $? -ne 0 ]] && return 1
    
    local type=$(whiptail --fb --inputbox "Enter record type (A, CNAME, etc.):\n\nExample: A" 10 60 3>&1 1>&2 2>&3)
    [[ $? -ne 0 ]] && return 1
    
    if [[ $TEST_MODE -eq 1 ]]; then
        log "INFO" "[TEST] Would remove $type record: $name.${ADS_DOMAIN}"
        return 0
    fi
    
    log "INFO" "Removing $type record: $name.${ADS_DOMAIN}"
    if docker exec samba-ads samba-tool dns delete 127.0.0.1 ${ADS_DOMAIN} $name $type -U Administrator%${ADS_ADMIN_PASSWORD}; then
        log "INFO:!ts" "✓ DNS record removed successfully"
        whiptail --fb --msgbox "DNS Record Removed Successfully!\n\nRemoved: $name.${ADS_DOMAIN} ($type)" 10 60
    else
        log "ERROR" "Failed to remove DNS record"
        whiptail --fb --msgbox "ERROR: Failed to remove DNS record.\n\nRecord may not exist or check container logs." 10 60
    fi
}

################################################################################
# DNS Configuration
################################################################################

# Helper: Collect DNS configuration settings
# Last Updated: 01/09/2026 8:20:00 PM CDT
collect_dns_settings() {
    load_env_vars
    
    # Check current system state
    local systemd_resolved_active=0
    if systemctl is-active --quiet systemd-resolved; then
        systemd_resolved_active=1
    fi
    
    # Check current resolv.conf
    local current_nameservers=$(grep "^nameserver" /etc/resolv.conf | head -3)
    local current_search=$(grep "^search" /etc/resolv.conf)
    
    # Return data as formatted string (caller will parse)
    echo "$systemd_resolved_active|$current_nameservers|$current_search"
}

# Helper: Display DNS configuration summary for review
# Last Updated: 01/09/2026 9:05:00 PM CDT
display_dns_summary() {
    local systemd_resolved_active=$1
    local current_nameservers=$2
    local current_search=$3
    local ads_domain=$4
    
    # Extract just the domain name from "search domain.tld" format
    local current_search_domain=$(echo "$current_search" | sed 's/^search[[:space:]]*//g' | awk '{print $1}')
    
    local summary="CURRENT DNS CONFIGURATION
systemd-resolved: "
    
    if [[ $systemd_resolved_active -eq 1 ]]; then
        summary+="ACTIVE → Will be stopped
"
    else
        summary+="INACTIVE
"
    fi
    
    summary+="Nameserver:    $current_nameservers
Search Domain: $current_search_domain

NEW DNS CONFIGURATION (TO BE APPLIED)
Primary NS:   127.0.0.1 (Samba AD DC)
Secondary NS: 10.1.1.111 (Pihole)
Tertiary NS:  8.8.8.8 (Google)

Search Domain Change:
  FROM: $current_search_domain
  TO:   $ads_domain"
    
    echo "$summary"
}

# Helper: Execute DNS configuration (only called after user confirms)
# Last Updated: 01/09/2026 8:20:00 PM CDT
execute_dns_config() {
    local systemd_resolved_active=$1
    
    log "DEBUG" "Starting DNS configuration execution..."
    
    if [[ $TEST_MODE -eq 1 ]]; then
        [[ $systemd_resolved_active -eq 1 ]] && log "INFO" "[TEST] Would stop and mask systemd-resolved"
        log "INFO" "[TEST] Would backup /etc/resolv.conf"
        log "INFO" "[TEST] Would update /etc/resolv.conf to use 127.0.0.1 with proper hierarchy"
        return 0
    fi
    
    # ATOMIC TRANSACTION: Stop systemd-resolved THEN immediately configure replacement
    if [[ $systemd_resolved_active -eq 1 ]]; then
        log "INFO" "Stopping systemd-resolved atomically with DNS replacement..."
        
        if ! sudo systemctl stop systemd-resolved; then
            log "ERROR" "Failed to stop systemd-resolved - aborting DNS configuration"
            return 1
        fi
        log "INFO:!ts" "✓ Stopped systemd-resolved"
        
        if ! sudo systemctl mask systemd-resolved; then
            log "ERROR" "Failed to mask systemd-resolved"
            sudo systemctl start systemd-resolved
            log "ERROR" "Restarted systemd-resolved due to mask failure"
            return 1
        fi
        log "INFO:!ts" "✓ Masked systemd-resolved (will not auto-start)"
    fi
    
    # Backup existing resolv.conf
    local backup_file="/etc/resolv.conf.backup-$(date +%Y%m%d-%H%M%S)"
    log "INFO" "Backing up /etc/resolv.conf to $backup_file..."
    sudo cp /etc/resolv.conf "$backup_file"
    log "DEBUG" "Backup created at $backup_file"
    
    # Update resolv.conf IMMEDIATELY after stopping systemd-resolved
    log "INFO" "Updating /etc/resolv.conf with DNS hierarchy..."
    echo -e "nameserver 127.0.0.1\nnameserver 10.1.1.111\nnameserver 8.8.8.8\nsearch ${ADS_DOMAIN}" | sudo tee /etc/resolv.conf > /dev/null
    log "INFO:!ts" "✓ /etc/resolv.conf updated (atomic transaction complete)"
    
    log "INFO:!ts" "DNS configuration execution completed successfully"
}

configure_host_dns() {
    # Last Updated: 01/09/2026 9:50:00 PM CDT
    # REFACTORED: Collect-Display-Confirm in ONE screen (no two separate screens)
    # NOTE: Search domain is pulled from ADS_DOMAIN environment variable
    # Source: .env.ads1-98 or divtools environment files
    log "HEAD" "=== Configure DNS on Host ==="
    log "INFO" "[MENU SELECTION] DNS Configuration initiated"
    
    # PHASE 1: COLLECT
    log "DEBUG" "PHASE 1: Collecting DNS settings..."
    load_env_vars
    log "DEBUG" "*** AFTER load_env_vars: ADS_DOMAIN='$ADS_DOMAIN' ***"
    local collected_data=$(collect_dns_settings)
    log "DEBUG" "*** collect_dns_settings returned: '$collected_data' ***"
    local systemd_resolved_active=$(echo "$collected_data" | cut -d'|' -f1)
    local current_nameservers=$(echo "$collected_data" | cut -d'|' -f2)
    local current_search=$(echo "$collected_data" | cut -d'|' -f3)
    log "DEBUG" "*** Parsed values: active=$systemd_resolved_active, nameservers='$current_nameservers', search='$current_search' ***"
    
    # PHASE 2: BUILD COMBINED DISPLAY + CONFIRMATION
    log "DEBUG" "PHASE 2: Building combined DNS summary with confirmation..."
    log "DEBUG" "*** About to call display_dns_summary with ADS_DOMAIN='$ADS_DOMAIN' ***"
    local dns_summary=$(display_dns_summary "$systemd_resolved_active" "$current_nameservers" "$current_search" "$ADS_DOMAIN")
    
    # Combine summary with confirmation prompt in ONE dialog
    local combined_msg="$dns_summary

═══════════════════════════════════════════════════════════════════

WARNING: This is an atomic operation - DNS will be replaced immediately

Proceed with DNS configuration?"
    
    if ! wt_yesno "Configure DNS" "$combined_msg"; then
        log "DEBUG" "User cancelled at combined confirmation screen"
        return 0
    fi
    
    # PHASE 3: EXECUTE
    log "DEBUG" "PHASE 3: Executing DNS configuration..."
    if ! execute_dns_config "$systemd_resolved_active"; then
        log "ERROR" "DNS configuration execution failed"
        wt_msgbox "Configuration Failed" "DNS configuration encountered an error.\n\nCheck logs for details."
        return 1
    fi
    
    # SUCCESS
    local success_msg="DNS Configured Successfully!

Primary Nameserver: 127.0.0.1 (Samba AD DC)
Secondary Nameserver: 10.1.1.111 (Pihole)
Tertiary Nameserver: 8.8.8.8 (Google)
Search domain: ${ADS_DOMAIN}

systemd-resolved: stopped and masked"
    wt_msgbox "DNS Configuration Complete" "$success_msg"
    log "INFO:!ts" "DNS configuration completed successfully"
}

################################################################################
# Status Checks
################################################################################

run_status_checks() {
    log "HEAD" "=== ADS Status Checks ==="
    log "INFO" "[MENU SELECTION] Status Checks initiated"
    
    # Check if container is running
    if ! docker ps | grep -q "samba-ads"; then
        log "ERROR" "Container 'samba-ads' is not running"
        whiptail --fb --msgbox "ERROR: Container 'samba-ads' is not running.\n\nStart the container first." 10 60
        return 1
    fi
    
    log "INFO:!ts" "✓ Container 'samba-ads' is running"
    
    # Run Python tests if available
    local test_dir="$SCRIPT_DIR/test"
    if [[ -d "$test_dir" ]]; then
        log "INFO" "Running pytest test suite from: $test_dir..."
        
        # Check if venv exists, create if needed
        if [[ ! -d "$SCRIPT_DIR/.venv" ]]; then
            log "INFO" "Python virtual environment not found, creating..."
            python3 -m venv "$SCRIPT_DIR/.venv"
            log "DEBUG" "Virtual environment created at $SCRIPT_DIR/.venv"
            source "$SCRIPT_DIR/.venv/bin/activate"
            
            log "INFO" "Installing Python dependencies..."
            pip install --upgrade pip >/dev/null 2>&1
            pip install pytest python-ldap dnspython >/dev/null 2>&1
            log "DEBUG" "Dependencies installed"
        else
            log "DEBUG" "Using existing virtual environment"
            source "$SCRIPT_DIR/.venv/bin/activate"
        fi
        
        # Run tests
        log "INFO" "Executing pytest with verbose output..."
        pytest "$test_dir" -v --tb=short
        local exit_code=$?
        
        deactivate
        
        if [[ $exit_code -eq 0 ]]; then
            whiptail --fb --msgbox "✓ All tests passed!" 10 60
        else
            whiptail --msgbox "✗ Some tests failed. Check logs for details." 10 60
        fi
    else
        # Run manual checks
        log "INFO" "Python tests not found. Running manual checks..."
        
        local results=""
        
        # Domain status
        results+="Domain Status:\n"
        results+="$(docker exec samba-ads samba-tool domain info 127.0.0.1 2>&1 | head -n 5)\n\n"
        
        # FSMO roles
        results+="FSMO Roles:\n"
        results+="$(docker exec samba-ads samba-tool fsmo show 2>&1 | head -n 5)\n\n"
        
        # Container status
        results+="Container Status:\n"
        results+="$(docker ps | grep samba-ads)\n"
        
        whiptail --msgbox "$results" 20 80
    fi
}

################################################################################
# Environment Variable Validation
################################################################################

# Helper function to generate example variable entries for .env.samba
# Last Updated: 01/08/2026 02:00:00 PM CST
generate_example_env_var() {
    local var_name="$1"
    local var_desc="$2"
    local var_example="$3"
    local var_options="$4"
    
    local output=""
    
    # Add description
    output+="# $var_desc\n"
    
    # Add options if provided
    if [[ -n "$var_options" ]]; then
        output+="# Options:\n"
        IFS='|' read -ra opts <<< "$var_options"
        for opt in "${opts[@]}"; do
            output+="#    $opt\n"
        done
    fi
    
    # Add example
    output+="# $var_example\n"
    output+="# $var_name=\n"
    
    echo -e "$output"
}

# Helper function to add missing vars as examples to .env.samba
# Last Updated: 01/08/2026 02:00:00 PM CST
add_missing_vars_to_env_samba() {
    local -a missing_vars=("$@")
    
    log "INFO" "Preparing to add ${#missing_vars[@]} missing variable example(s) to $SAMBA_DIR/.env.samba"
    
    # Ensure .env.samba exists
    if [[ ! -f "$SAMBA_DIR/.env.samba" ]]; then
        log "INFO" "Creating $SAMBA_DIR/.env.samba"
        mkdir -p "$SAMBA_DIR"
        touch "$SAMBA_DIR/.env.samba"
    fi
    
    # Add timestamp comment
    local timestamp=$(date '+%m/%d/%Y %I:%M:%S %p %Z')
    echo "" >> "$SAMBA_DIR/.env.samba"
    echo "# Missing variables added as examples - $timestamp" >> "$SAMBA_DIR/.env.samba"
    echo "# Uncomment and fill in the appropriate values below" >> "$SAMBA_DIR/.env.samba"
    echo "" >> "$SAMBA_DIR/.env.samba"
    
    # Define variable metadata (name, description, example, options)
    declare -A var_metadata=(
        [ADS_DOMAIN]="DNS domain name|ADS_DOMAIN=avctn.lan|"
        [ADS_REALM]="Kerberos realm (uppercase, usually same as domain)|ADS_REALM=AVCTN.LAN|"
        [ADS_WORKGROUP]="NetBIOS workgroup name (max 15 characters)|ADS_WORKGROUP=AVCTN|"
        [ADS_ADMIN_PASSWORD]="Administrator password (must include uppercase, lowercase, numbers, special chars)|ADS_ADMIN_PASSWORD=SecurePassword123!|"
        [ADS_HOST_IP]="Static IP address of the Domain Controller|ADS_HOST_IP=10.1.1.98|"
        [ADS_DNS_FORWARDER]="External DNS servers (space or comma separated)|ADS_DNS_FORWARDER=10.1.1.111 8.8.8.8 8.8.4.4|"
        [ADS_SERVER_ROLE]="Server role in the domain|ADS_SERVER_ROLE=dc|dc: Domain Controller|member: Domain Member"
        [ADS_DOMAIN_LEVEL]="Domain functional level (determines features and compatibility)|ADS_DOMAIN_LEVEL=2016|2008_R2: Windows Server 2008 R2|2012: Windows Server 2012|2012_R2: Windows Server 2012 R2|2016: Windows Server 2016"
        [ADS_FOREST_LEVEL]="Forest functional level (optional, defaults to 2016)|ADS_FOREST_LEVEL=2016|2008_R2: Windows Server 2008 R2|2012: Windows Server 2012|2012_R2: Windows Server 2012 R2|2016: Windows Server 2016"
        [ADS_DNS_BACKEND]="DNS backend type (optional, defaults to SAMBA_INTERNAL)|ADS_DNS_BACKEND=SAMBA_INTERNAL|SAMBA_INTERNAL: Samba internal DNS|BIND9_DLZ: Bind9 with DLZ|NONE: No DNS"
        [ADS_LOG_LEVEL]="Samba logging verbosity level (optional, defaults to 1)|ADS_LOG_LEVEL=1|0: Minimal logging|1: Normal logging|2-10: Increasing verbosity"
    )
    
    # Add each missing variable as a commented example
    for var_name in "${missing_vars[@]}"; do
        if [[ -n "${var_metadata[$var_name]}" ]]; then
            IFS='|' read -ra parts <<< "${var_metadata[$var_name]}"
            local desc="${parts[0]}"
            local example="${parts[1]}"
            local options="${parts[2]}"
            
            # Only add options if they're not empty
            if [[ -n "${parts[3]}" ]]; then
                # Rebuild options string from remaining parts
                local options="${parts[2]}"
                for ((i=3; i<${#parts[@]}; i++)); do
                    options+="|${parts[$i]}"
                done
            fi
            
            echo "# $desc" >> "$SAMBA_DIR/.env.samba"
            
            # Add options if present
            if [[ -n "$options" && "$options" != " " ]]; then
                echo "# Options:" >> "$SAMBA_DIR/.env.samba"
                IFS='|' read -ra opts <<< "$options"
                for opt in "${opts[@]}"; do
                    if [[ -n "$opt" ]]; then
                        echo "#    $opt" >> "$SAMBA_DIR/.env.samba"
                    fi
                done
            fi
            
            echo "$example" >> "$SAMBA_DIR/.env.samba"
            echo "" >> "$SAMBA_DIR/.env.samba"
            
            log "DEBUG" "Added example for $var_name to $SAMBA_DIR/.env.samba"
        fi
    done
    
    log "INFO:!ts" "✓ Missing variable examples added to $SAMBA_DIR/.env.samba"
}

check_env_vars() {
    # Last Updated: 01/09/2026 01:30:00 PM CST
    # Function to shorten source path for display
    shorten_source_path() {
        local path="$1"
        # If path contains "sites", show from "./sites" onwards
        if [[ "$path" == *"/sites"* ]]; then
            echo "./sites${path##*/sites}"
        else
            # Otherwise show just the filename
            echo "${path##*/}"
        fi
    }
    
    log "HEAD" "=== Environment Variable Check ==="
    log "INFO" "[MENU SELECTION] Environment Variable Check initiated"
    
    # Display submenu for checking required vs optional variables
    local check_choice
    check_choice=$(wt_menu "Environment Variable Check" "Which variables would you like to check?" 12 60 \
        "1" "Check Required Variables Only" \
        "2" "Check Optional Variables Only" \
        "3" "Check ALL Variables")
    
    # If user cancelled (ESC or Cancel), return
    [[ $? -ne 0 ]] && { log "DEBUG" "User cancelled environment variable check"; return 1; }
    
    # Based on choice, display appropriate checks
    case "$check_choice" in
        1) check_required_vars ;;
        2) check_optional_vars ;;
        3) check_all_vars ;;
        *) log "ERROR" "Invalid choice"; return 1 ;;
    esac
}

check_required_vars() {
    # Last Updated: 01/09/2026 01:30:00 PM CST
    log "INFO" "Checking REQUIRED environment variables only..."
    
    local vars_ok=1
    local missing_vars=()
    local env_vars_output=""
    
    # Define required environment variables with descriptions
    declare -A required_vars=(
        [ADS_DOMAIN]="Domain name (e.g., avctn.lan)"
        [ADS_REALM]="Realm name (uppercase, e.g., AVCTN.LAN)"
        [ADS_WORKGROUP]="NetBIOS workgroup name (e.g., AVCTN)"
        [ADS_ADMIN_PASSWORD]="Administrator password"
        [ADS_HOST_IP]="Host IP address (e.g., 10.1.1.98)"
        [ADS_DNS_FORWARDER]="DNS forwarder IPs (e.g., 10.1.1.111 8.8.8.8 8.8.4.4)"
        [ADS_SERVER_ROLE]="Server role: dc or member"
        [ADS_DOMAIN_LEVEL]="Domain functional level"
    )
    
    # Source environment if available
    if [[ -f "$ENV_FILE" ]]; then
        log "DEBUG" "Sourcing environment from $ENV_FILE"
        source "$ENV_FILE" 2>/dev/null || true
    fi
    
    # Also try load_env_files if available
    if declare -f load_env_files >/dev/null 2>&1; then
        log "DEBUG" "Calling load_env_files() for additional environment variables"
        load_env_files 2>/dev/null || true
    fi
    
    # Build output with limited vars per screen (max 7)
    env_vars_output+="╔════════════════════════════════════════════════════════════════╗\n"
    env_vars_output+="║ REQUIRED ENVIRONMENT VARIABLES\n"
    env_vars_output+="╚════════════════════════════════════════════════════════════════╝\n\n"
    
    for var_name in "${!required_vars[@]}"; do
        local var_value="${!var_name:-<NOT SET>}"
        local var_desc="${required_vars[$var_name]}"
        local var_source="Unknown"
        
        # Determine source of variable
        if [[ -f "$ENV_FILE" ]] && grep -q "^export $var_name=" "$ENV_FILE" 2>/dev/null; then
            var_source=$(shorten_source_path "$ENV_FILE")
        elif [[ -f "$SAMBA_DIR/.env.samba" ]] && grep -q "^$var_name=" "$SAMBA_DIR/.env.samba" 2>/dev/null; then
            var_source=$(shorten_source_path "$SAMBA_DIR/.env.samba")
        elif [[ -f "$HOME/.bash_profile" ]] && grep -q "$var_name" "$HOME/.bash_profile" 2>/dev/null; then
            var_source=".bash_profile"
        fi
        
        if [[ "$var_value" == "<NOT SET>" ]]; then
            log "ERROR" "Missing required variable: $var_name"
            env_vars_output+="[MISSING] $var_name\n"
            env_vars_output+="    $var_desc\n\n"
            missing_vars+=("$var_name")
            vars_ok=0
        else
            # Mask sensitive values in output
            local display_value="$var_value"
            if [[ "$var_name" == "ADS_ADMIN_PASSWORD" ]]; then
                display_value="***MASKED*** (${#var_value} chars)"
            fi
            
            log "INFO" "Found $var_name from $var_source"
            env_vars_output+="[OK] $var_name\n"
            env_vars_output+="    Source: $var_source\n"
            env_vars_output+="    Value: $display_value\n\n"
        fi
    done
    
    # Display results
    wt_msgbox "Required Variables Status" "$env_vars_output"
    
    # Log summary and offer to add missing vars
    if [[ $vars_ok -eq 0 ]]; then
        log "ERROR" "Missing ${#missing_vars[@]} required environment variable(s): ${missing_vars[*]}"
        
        # Offer to add missing variables as examples to .env.samba
        if wt_yesno "Add Missing Variables" "Would you like to add examples for the ${#missing_vars[@]} missing variables to $SAMBA_DIR/.env.samba?\n\nThis will add commented example entries that you can uncomment and customize."; then
            log "INFO" "User confirmed adding missing variables as examples"
            add_missing_vars_to_env_samba "${missing_vars[@]}"
            wt_msgbox "Variables Added" "Missing variable examples added to:\n\n$SAMBA_DIR/.env.samba\n\nPlease edit the file to uncomment and set the appropriate values, then run the check again."
        else
            log "DEBUG" "User declined adding missing variables as examples"
        fi
        return 1
    else
        log "INFO:!ts" "✓ All required environment variables are set"
        wt_msgbox "All Required Variables Set" "✓ All required environment variables are properly configured."
        return 0
    fi
}

check_optional_vars() {
    # Last Updated: 01/09/2026 01:30:00 PM CST
    log "INFO" "Checking OPTIONAL environment variables only..."
    
    local env_vars_output=""
    
    # Define optional environment variables
    declare -A optional_vars=(
        [ADS_FOREST_LEVEL]="Forest functional level (optional)"
        [ADS_DNS_BACKEND]="DNS backend: SAMBA_INTERNAL, BIND9_DLZ, NONE (optional)"
        [ADS_LOG_LEVEL]="Log level: 0-10 (optional)"
    )
    
    # Source environment if available
    if [[ -f "$ENV_FILE" ]]; then
        log "DEBUG" "Sourcing environment from $ENV_FILE"
        source "$ENV_FILE" 2>/dev/null || true
    fi
    
    # Also try load_env_files if available
    if declare -f load_env_files >/dev/null 2>&1; then
        log "DEBUG" "Calling load_env_files() for additional environment variables"
        load_env_files 2>/dev/null || true
    fi
    
    env_vars_output+="╔════════════════════════════════════════════════════════════════╗\n"
    env_vars_output+="║ OPTIONAL ENVIRONMENT VARIABLES\n"
    env_vars_output+="╚════════════════════════════════════════════════════════════════╝\n\n"
    
    for var_name in "${!optional_vars[@]}"; do
        local var_value="${!var_name:-<NOT SET>}"
        local var_desc="${optional_vars[$var_name]}"
        local var_source="Unknown"
        
        # Determine source of variable
        if [[ -f "$ENV_FILE" ]] && grep -q "^export $var_name=" "$ENV_FILE" 2>/dev/null; then
            var_source=$(shorten_source_path "$ENV_FILE")
        elif [[ -f "$SAMBA_DIR/.env.samba" ]] && grep -q "^$var_name=" "$SAMBA_DIR/.env.samba" 2>/dev/null; then
            var_source=$(shorten_source_path "$SAMBA_DIR/.env.samba")
        fi
        
        if [[ "$var_value" == "<NOT SET>" ]]; then
            log "DEBUG" "Optional variable not set: $var_name"
            env_vars_output+="[not set] $var_name\n"
            env_vars_output+="    $var_desc\n\n"
        else
            log "INFO" "Found optional $var_name from $var_source"
            env_vars_output+="[OK] $var_name\n"
            env_vars_output+="    Source: $var_source\n"
            env_vars_output+="    Value: $var_value\n\n"
        fi
    done
    
    # Display results
    wt_msgbox "Optional Variables Status" "$env_vars_output"
}

check_all_vars() {
    # Last Updated: 01/09/2026 01:30:00 PM CST
    log "INFO" "Checking ALL environment variables..."
    
    # First check required
    check_required_vars
    local req_status=$?
    
    # Then check optional
    check_optional_vars
    
    return $req_status
}

################################################################################
# Main Menu
################################################################################

main_menu() {
    # Last Updated: 01/09/2026 1:30:00 PM CDT
    while true; do
        # Build menu items array
        local menu_items=(
            "" "═══ SETUP (Run in Order) ═══"
            "1" "Configure DNS on Host (REQUIRED FIRST)"
            "2" "Edit Environment Variables"
            "3" "ADS Setup (folders, files, network)"
            "" "═══ OPERATIONS ═══"
            "4" "Start Samba Container"
            "5" "Stop Samba Container"
            "6" "Configure Local DNS Entries"
            "" "═══ CHECKS & QOL ═══"
            "7" "ADS Status Check (run tests)"
            "8" "Check Environment Variables"
            "9" "View Container Logs"
            "10" "Install Bash Aliases (QOL)"
            "" "═══════════════════════════"
            "0" "Exit"
        )
        
        # Use whiptail helper for automatic sizing
        CHOICE=$(wt_menu "Samba AD DC Setup" "Choose an option" "${menu_items[@]}")
        local exit_code=$?
        
        # Handle cancel (ESC key or dialog closed)
        # wt_menu returns 1 when user presses ESC
        if [[ $exit_code -ne 0 ]]; then
            log "INFO" "User cancelled from main menu"
            log "HEAD" "╔════════════════════════════════════════════════════════╗"
            log "HEAD" "║ Script execution cancelled by user - Exiting"
            log "HEAD" "╚════════════════════════════════════════════════════════╝"
            exit 0
        fi
        
        # Handle empty selection (section headers)
        if [[ -z "$CHOICE" || "$CHOICE" == "" ]]; then
            continue  # Section header selected, redisplay menu
        fi
        
        # Log menu selection with timestamp
        local menu_descriptions=(
            "Exit"  # Index 0
            "Configure DNS on Host (REQUIRED FIRST)"
            "Edit Environment Variables"
            "ADS Setup (folders, files, network)"
            "Start Samba Container"
            "Stop Samba Container"
            "Configure Local DNS Entries"
            "ADS Status Check (run tests)"
            "Check Environment Variables"
            "View Container Logs"
            "Install Bash Aliases (QOL)"
        )
        
        if [[ "$CHOICE" != "0" ]]; then
            log "HEAD" "╔════════════════════════════════════════════════════════╗"
            log "HEAD" "║ MENU SELECTION: Option $CHOICE - ${menu_descriptions[$CHOICE]}"
            log "HEAD" "╚════════════════════════════════════════════════════════╝"
        fi
        
        case $CHOICE in
            1)
                configure_host_dns
                ;;
            2)
                prompt_env_vars
                ;;
            3)
                ads_setup
                ;;
            4)
                start_container
                ;;
            5)
                stop_container
                ;;
            6)
                configure_local_dns
                ;;
            7)
                run_status_checks
                ;;
            8)
                check_env_vars
                ;;
            9)
                log "INFO" "[MENU SELECTION] View Container Logs initiated"
                if docker ps | grep -q "samba-ads"; then
                    log "INFO" "Displaying container logs (press Ctrl+C to exit)..."
                    docker logs -f samba-ads
                else
                    log "WARN" "Container 'samba-ads' is not running"
                    whiptail --msgbox "Container 'samba-ads' is not running" 10 60
                fi
                ;;
            10)
                install_bash_aliases
                ;;
            0)
                log "HEAD" "╔════════════════════════════════════════════════════════╗"
                log "HEAD" "║ Script execution completed - Exiting"
                log "HEAD" "╚════════════════════════════════════════════════════════╝"
                exit 0
                ;;
        esac
    done
}

################################################################################
# Entry Point
################################################################################

# Check if whiptail is installed
if ! command -v whiptail &> /dev/null; then
    log "ERROR" "whiptail is required but not installed. Install with: sudo apt install whiptail"
    exit 1
fi

# Run main menu
main_menu
