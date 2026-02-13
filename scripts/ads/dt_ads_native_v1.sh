#!/bin/bash
# Samba Active Directory Domain Controller Native Installation Script
# Last Updated: 01/10/2026 10:30:00 PM CST
#
# This script provides an interactive dialog-based menu for:
# - Native Samba Installation: Installs samba directly on Ubuntu host
# - Domain Provisioning: Creates AD domain with samba-tool
# - DNS Configuration: Updates host DNS settings
# - Health Checks: Verifies domain functionality
# - Service Management: Start/stop/restart samba services
#
# Environment variables are managed in /opt/ads-native/.env.ads
# with markers for easy updates (like dt_host_setup.sh does)
#
# Logging:
# - All activity logged to /opt/ads-native/logs/dt_ads_native-TIMESTAMP.log
# - Log level based on --debug, -v, -vv flags (DEBUG vs INFO)
# - Fully timestamped with local timezone
# - Menu selections clearly identified
# - Line numbers in dialogs when DEBUG_MODE=1

# Source logging and dialog utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../util/logging.sh"
source "$SCRIPT_DIR/../util/dialog.sh"

# Check if dialog command is available
if ! check_dialog_available; then
    echo ""
    show_dialog_install_instructions
    exit 1
fi

# Default flags
TEST_MODE=0
DEBUG_MODE=0
VERBOSE=0
LOG_DIR="/opt/ads-native/logs"
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
        -v)
            VERBOSE=1
            shift
            ;;
        -vv)
            VERBOSE=2
            DEBUG_MODE=1
            shift
            ;;
        *)
            echo "ERROR: Unknown option: $1"
            echo "Usage: $0 [-test] [-debug] [-v] [-vv]"
            echo "  -test   : Test mode (no permanent changes)"
            echo "  -debug  : Enable debug logging"
            echo "  -v      : Verbose output"
            echo "  -vv     : Very verbose output (implies -debug)"
            exit 1
            ;;
    esac
done

# Initialize logging
init_logging() {
    # Create log directory
    sudo mkdir -p "$LOG_DIR"
    sudo chown -R $USER:$USER "$LOG_DIR"
    
    # Generate log filename with timestamp
    local timestamp=$(date '+%Y%m%d-%H%M%S')
    LOG_FILE="$LOG_DIR/dt_ads_native-${timestamp}.log"
    
    # Redirect stdout and stderr to log file while also displaying
    exec 1> >(tee -a "$LOG_FILE")
    exec 2> >(tee -a "$LOG_FILE" >&2)
    
    # Log initialization info
    log "HEAD" "================================"
    log "HEAD" "ADS Native Setup Script Started"
    log "HEAD" "================================"
    log "INFO" "Log file: $LOG_FILE"
    log "DEBUG" "Test Mode: $TEST_MODE"
    log "DEBUG" "Debug Mode: $DEBUG_MODE"
    log "DEBUG" "Verbose Level: $VERBOSE"
    log "DEBUG" "Current Directory: $(pwd)"
    log "DEBUG" "User: $(whoami)"
    log "INFO" "Script execution started"
}

# Initialize logging first
init_logging

log "INFO" "TEST_MODE=$TEST_MODE, DEBUG_MODE=$DEBUG_MODE, VERBOSE=$VERBOSE"

################################################################################
# Environment Variable Management
################################################################################

# Load environment files using .bash_profile function
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
        log "DEBUG" "Attempting to source $DIVTOOLS/dotfiles/.bash_profile..."
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

# Load environment variables early
log "DEBUG" "Loading divtools environment at script startup..."
load_environment

# Configuration
PROJECT_ROOT="${DIVTOOLS:-/home/divix/divtools}"
CONFIG_DIR="/opt/ads-native"
ENV_FILE="$CONFIG_DIR/.env.ads"
DATA_DIR="/var/lib/samba"
CONFIG_SAMBA_DIR="/etc/samba"
ALIASES_FILE="$CONFIG_DIR/samba-aliases-native.sh"

# Environment variable markers
ENV_MARKER_START="# >>> DT_ADS_NATIVE AUTO-MANAGED - DO NOT EDIT MANUALLY <<<"
ENV_MARKER_END="# <<< DT_ADS_NATIVE AUTO-MANAGED <<<"

################################################################################
# File Backup Helper
################################################################################

# Function to backup a file before overwriting
# Last Updated: 01/10/2026 10:30:00 PM CST
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
    if sudo cp "$file_path" "$backup_path"; then
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

# Note: set_dialog_colors() is now provided by dialog.sh utility
# No need to redefine it here - just call it

# Initialize dialog colors at script start
set_dialog_colors

################################################################################
# Helper Functions - Now from dialog.sh
################################################################################

# The following functions are now provided by dialog.sh:
# - dlg_yesno() with auto-sizing and line numbering
# - dlg_msgbox() with auto-sizing and line numbering
# - dlg_menu() with auto-sizing
# - dlg_inputbox() with auto-sizing
# - dlg_passwordbox() with auto-sizing
# - set_dialog_colors()
# - calculate_dimensions()
# - add_line_numbers()
#
# These provide consistent behavior across all divtools scripts

################################################################################
# Environment Variable Management Functions
################################################################################

# Load ADS-specific environment variables from .env.ads
# Last Updated: 01/10/2026 10:30:00 PM CST
load_ads_env_vars() {
    if [[ -f "$ENV_FILE" ]]; then
        log "DEBUG" "Loading ADS environment variables from $ENV_FILE"
        # Source variables from the auto-managed section
        eval "$(grep -E '^export (ADS_|REALM|DOMAIN|WORKGROUP|ADMIN_PASSWORD|HOST_IP)' "$ENV_FILE" 2>/dev/null)"
        log "DEBUG" "Loaded: REALM=$REALM, DOMAIN=$DOMAIN"
    else
        log "DEBUG" "No existing environment file found at $ENV_FILE"
    fi
}

# Save environment variables with markers (divtools style)
# Last Updated: 01/10/2026 10:30:00 PM CST
save_env_vars() {
    local realm="$1"
    local domain="$2"
    local workgroup="$3"
    local admin_pass="$4"
    local host_ip="$5"
    
    log "INFO" "Saving ADS environment variables to $ENV_FILE"
    
    # Create directory if it doesn't exist
    sudo mkdir -p "$(dirname "$ENV_FILE")"
    
    # Backup existing file if it exists
    if [[ -f "$ENV_FILE" ]]; then
        backup_file "$ENV_FILE"
    fi
    
    # Remove old auto-managed section if it exists
    if [[ -f "$ENV_FILE" ]] && grep -q "$ENV_MARKER_START" "$ENV_FILE"; then
        sudo sed -i "/$ENV_MARKER_START/,/$ENV_MARKER_END/d" "$ENV_FILE"
    fi
    
    # Append new section
    sudo tee -a "$ENV_FILE" > /dev/null <<EOF

$ENV_MARKER_START
# Samba AD DC Native Configuration
# Last Updated: $(date '+%m/%d/%Y %I:%M:%S %p %Z')
export REALM="$realm"
export DOMAIN="$domain"
export WORKGROUP="$workgroup"
export ADMIN_PASSWORD="$admin_pass"
export HOST_IP="$host_ip"
export SERVER_ROLE="dc"
export DOMAIN_LEVEL="2008_R2"
export LOG_LEVEL="1"
$ENV_MARKER_END
EOF
    
    log "INFO:!ts" "ADS environment variables saved successfully"
    
    # Set permissions
    sudo chmod 600 "$ENV_FILE"
    log "DEBUG" "Set permissions 600 on $ENV_FILE"
}

# Helper: Collect environment variables from user (PHASE 1 only - no confirmation display)
# Last Updated: 01/10/2026 10:30:00 PM CST
collect_env_vars() {
    log "DEBUG" "Collecting environment variables..."
    
    # Load existing values first
    load_ads_env_vars
    
    # Prompt for each variable with existing value as default
    local realm
    realm=$(dlg_inputbox "Realm" "Enter realm in uppercase (e.g., AVCTN.LAN)" "${REALM:-AVCTN.LAN}")
    [[ $? -ne 0 ]] && { log "DEBUG" "User cancelled at realm prompt"; return 1; }
    
    local domain
    domain=$(dlg_inputbox "Domain Name" "Enter domain name (e.g., avctn.lan)" "${DOMAIN:-avctn.lan}")
    [[ $? -ne 0 ]] && { log "DEBUG" "User cancelled at domain prompt"; return 1; }
    
    local workgroup
    workgroup=$(dlg_inputbox "Workgroup" "Enter NetBIOS workgroup name (e.g., AVCTN)" "${WORKGROUP:-AVCTN}")
    [[ $? -ne 0 ]] && { log "DEBUG" "User cancelled at workgroup prompt"; return 1; }
    
    local admin_pass
    admin_pass=$(dlg_passwordbox "Administrator Password" "Enter administrator password")
    [[ $? -ne 0 ]] && { log "DEBUG" "User cancelled at password prompt"; return 1; }
    
    local host_ip
    host_ip=$(dlg_inputbox "Host IP Address" "Enter the server's IP address (e.g., 10.1.1.98)" "${HOST_IP:-10.1.1.98}")
    [[ $? -ne 0 ]] && { log "DEBUG" "User cancelled at host IP prompt"; return 1; }
    
    # Export collected values to global environment for use in confirmation
    export REALM="$realm"
    export DOMAIN="$domain"
    export WORKGROUP="$workgroup"
    export ADMIN_PASSWORD="$admin_pass"
    export HOST_IP="$host_ip"
    
    # Echo pipe-delimited values for parsing by prompt_env_vars()
    echo "$realm|$domain|$workgroup|$admin_pass|$host_ip"
    log "DEBUG" "Environment variables collected successfully"
    return 0
}

# Helper: Display environment variables summary for review
# Last Updated: 01/10/2026 10:30:00 PM CST
display_env_vars_summary() {
    local realm=$1
    local domain=$2
    local workgroup=$3
    local admin_pass=$4
    local host_ip=$5
    
    local summary="The following configuration will be saved:

═══ Domain Configuration ═══
Realm:           $realm
Domain:          $domain
Workgroup:       $workgroup

═══ Network Configuration ═══
Host IP:         $host_ip

═══ Credentials ═══
Admin Password:  ${admin_pass:0:3}****** (${#admin_pass} chars)

═══ File Location ═══
Config File:     $ENV_FILE

Do you want to proceed with saving these settings?"
    
    dlg_yesno "Confirm Configuration" "$summary"
    return $?
}

# Helper: Execute the save operation
# Last Updated: 01/10/2026 10:30:00 PM CST
execute_env_vars_save() {
    local realm=$1
    local domain=$2
    local workgroup=$3
    local admin_pass=$4
    local host_ip=$5
    
    log "INFO" "User confirmed - saving environment variables"
    
    if [[ $TEST_MODE -eq 1 ]]; then
        log "INFO" "[TEST] Would save environment variables to $ENV_FILE"
        dlg_msgbox "Test Mode" "Configuration save simulated.\n\n(No actual changes made)"
        return 0
    fi
    
    save_env_vars "$realm" "$domain" "$workgroup" "$admin_pass" "$host_ip"
    
    if [[ $? -eq 0 ]]; then
        dlg_msgbox "Configuration Saved" "Environment variables saved successfully to:\n$ENV_FILE\n\nPermissions set to 600 (owner read/write only)"
        return 0
    else
        dlg_msgbox "Save Failed" "Failed to save environment variables.\n\nCheck logs for details."
        return 1
    fi
}

# Main: Prompt for environment variables with confirmation workflow
# Last Updated: 01/10/2026 10:30:00 PM CST
prompt_env_vars() {
    log "HEAD" "=== Configure Environment Variables ==="
    log "INFO" "[MENU SELECTION] Environment Variables Configuration initiated"
    
    # PHASE 1: Collect values
    local collected_values
    collected_values=$(collect_env_vars)
    if [[ $? -ne 0 ]]; then
        log "DEBUG" "User cancelled environment variable collection"
        return 0
    fi
    
    # Parse collected values
    IFS='|' read -r realm domain workgroup admin_pass host_ip <<< "$collected_values"
    
    # PHASE 2: Display summary and get confirmation
    if ! display_env_vars_summary "$realm" "$domain" "$workgroup" "$admin_pass" "$host_ip"; then
        log "DEBUG" "User declined to save environment variables"
        dlg_msgbox "Cancelled" "Configuration not saved."
        return 0
    fi
    
    # PHASE 3: Execute save
    execute_env_vars_save "$realm" "$domain" "$workgroup" "$admin_pass" "$host_ip"
    return $?
}

# Check/View current environment variables
# Last Updated: 01/11/2026 12:00:00 AM CST
check_env_vars() {
    log "HEAD" "=== Check Environment Variables ==="
    log "INFO" "[MENU SELECTION] Environment Variables Check initiated"
    
    # Load existing env vars
    load_ads_env_vars
    
    # Check if env file exists
    if [[ ! -f "$ENV_FILE" ]]; then
        dlg_msgbox "No Configuration" "No environment variables have been configured yet.\n\nFile: $ENV_FILE\n\nRun Option 2 to configure environment variables first."
        return 0
    fi
    
    # Build summary from current values
    local summary="═══ Current Environment Variables ═══\n\n"
    
    # Check each variable
    if [[ -n "$REALM" ]]; then
        summary+="Realm:              $REALM\n"
    else
        summary+="Realm:              [NOT SET]\n"
    fi
    
    if [[ -n "$DOMAIN" ]]; then
        summary+="Domain:             $DOMAIN\n"
    else
        summary+="Domain:             [NOT SET]\n"
    fi
    
    if [[ -n "$WORKGROUP" ]]; then
        summary+="Workgroup:          $WORKGROUP\n"
    else
        summary+="Workgroup:          [NOT SET]\n"
    fi
    
    if [[ -n "$ADMIN_PASSWORD" ]]; then
        summary+="Admin Password:     ${ADMIN_PASSWORD:0:3}****** (${#ADMIN_PASSWORD} chars)\n"
    else
        summary+="Admin Password:     [NOT SET]\n"
    fi
    
    if [[ -n "$HOST_IP" ]]; then
        summary+="Host IP:            $HOST_IP\n"
    else
        summary+="Host IP:            [NOT SET]\n"
    fi
    
    summary+="\n═══ File Information ═══\n"
    summary+="Config File:        $ENV_FILE\n"
    summary+="File Size:          $(wc -c < "$ENV_FILE" 2>/dev/null || echo 'N/A') bytes"
    
    log "INFO:!ts" "Current environment variables displayed to user"
    dlg_msgbox "Environment Variables" "$summary"
    return 0
}

# Create configuration file soft-links for VSCode editing
# Last Updated: 01/11/2026 12:30:00 AM CST
create_config_file_links() {
    log "HEAD" "=== Create Config File Links ==="
    log "INFO" "[MENU SELECTION] Config File Links Creation initiated"
    
    # Check if DOCKER_HOSTDIR is set
    if [[ -z "$DOCKER_HOSTDIR" ]]; then
        log "WARN" "DOCKER_HOSTDIR environment variable not set"
        dlg_msgbox "Environment Variable Not Set" "DOCKER_HOSTDIR is not set in your environment.\n\nThis variable should point to the host's shared directory (e.g., /home/divix/divtools/docker).\n\nPlease load your environment with: source ~/.bash_profile"
        return 1
    fi
    
    local links_dir="$DOCKER_HOSTDIR/ads.cfg"
    
    log "INFO" "Creating config file links in: $links_dir"
    
    # Check if directory exists
    if [[ ! -d "$links_dir" ]]; then
        log "INFO" "Creating directory: $links_dir"
        if [[ $TEST_MODE -eq 1 ]]; then
            log "INFO" "[TEST] Would create: mkdir -p $links_dir"
        else
            if ! sudo mkdir -p "$links_dir"; then
                log "ERROR" "Failed to create directory: $links_dir"
                dlg_msgbox "Failed" "Failed to create directory:\n\n$links_dir"
                return 1
            fi
        fi
    fi
    
    # Define files to soft-link
    local -a files_to_link=(
        "smb.conf:/etc/samba/smb.conf"
        "krb5.conf:/etc/krb5.conf"
        "smb.conf.default:/etc/samba/smb.conf.default"
        "resolv.conf:/etc/resolv.conf"
    )
    
    # Define directories to soft-link
    local -a dirs_to_link=(
        "etc_samba:/etc/samba"
        "lib_samba:/var/lib/samba"
    )
    
    local creation_count=0
    local error_count=0
    local summary="Creating soft-links for Samba configuration files:\n\n"
    
    # Create file soft-links
    for link_pair in "${files_to_link[@]}"; do
        IFS=':' read -r link_name target_file <<< "$link_pair"
        local link_path="$links_dir/$link_name"
        
        log "DEBUG" "Processing file link: $link_name -> $target_file"
        
        # Check if target exists
        if [[ ! -f "$target_file" ]]; then
            log "WARN" "Target file does not exist (might not be provisioned yet): $target_file"
            summary+="⚠ $link_name -> $target_file [NOT YET CREATED]\n"
            continue
        fi
        
        if [[ $TEST_MODE -eq 1 ]]; then
            log "INFO" "[TEST] Would create link: ln -sf $target_file $link_path"
            summary+="[TEST] $link_name -> $target_file\n"
            ((creation_count++))
        else
            # Remove existing link if it exists
            if [[ -L "$link_path" ]]; then
                sudo rm "$link_path"
                log "DEBUG" "Removed existing symlink: $link_path"
            fi
            
            # Create the link
            if sudo ln -sf "$target_file" "$link_path"; then
                log "INFO:!ts" "✓ Created link: $link_name -> $target_file"
                summary+="✓ $link_name\n"
                ((creation_count++))
            else
                log "ERROR" "Failed to create link: $link_path -> $target_file"
                summary+="✗ $link_name (FAILED)\n"
                ((error_count++))
            fi
        fi
    done
    
    # Create directory soft-links
    for link_pair in "${dirs_to_link[@]}"; do
        IFS=':' read -r link_name target_dir <<< "$link_pair"
        local link_path="$links_dir/$link_name"
        
        log "DEBUG" "Processing directory link: $link_name -> $target_dir"
        
        # Check if target exists
        if [[ ! -d "$target_dir" ]]; then
            log "WARN" "Target directory does not exist: $target_dir"
            summary+="⚠ $link_name -> $target_dir [NOT FOUND]\n"
            continue
        fi
        
        if [[ $TEST_MODE -eq 1 ]]; then
            log "INFO" "[TEST] Would create link: ln -sf $target_dir $link_path"
            summary+="[TEST] $link_name/ -> $target_dir/\n"
            ((creation_count++))
        else
            # Remove existing link if it exists
            if [[ -L "$link_path" ]]; then
                sudo rm "$link_path"
                log "DEBUG" "Removed existing symlink: $link_path"
            fi
            
            # Create the link
            if sudo ln -sf "$target_dir" "$link_path"; then
                log "INFO:!ts" "✓ Created link: $link_name -> $target_dir"
                summary+="✓ $link_name/ (directory)\n"
                ((creation_count++))
            else
                log "ERROR" "Failed to create link: $link_path -> $target_dir"
                summary+="✗ $link_name/ (FAILED)\n"
                ((error_count++))
            fi
        fi
    done
    
    # Display results
    summary+="\n═══════════════════════════════════════\n"
    summary+="Location: $links_dir\n\n"
    summary+="You can now:\n"
    summary+="• Edit files directly in VSCode\n"
    summary+="• View the actual file system locations\n"
    summary+="• Make changes that affect the live system"
    
    if [[ $error_count -eq 0 ]]; then
        log "INFO:!ts" "Config file links created successfully"
        dlg_msgbox "Config Links Created" "$summary"
    else
        log "WARN" "Config file links created with $error_count errors"
        dlg_msgbox "Partial Success" "$summary\n\nWarning: $error_count link(s) failed. Check logs for details."
    fi
    
    return 0
}

# Generate installation steps documentation
# Last Updated: 01/11/2026 4:55:00 PM CDT
generate_install_steps_doc() {
    # Last Updated: 01/12/2026 10:30:00 AM CDT
    
    # Load environment variables first
    if ! load_ads_env_vars; then
        log "ERROR" "Failed to load environment variables"
        dlg_msgbox "Error" "Failed to load environment variables from $ENV_FILE"
        return 1
    fi
    
    # Get domain/realm from environment (with fallback to dialog)
    local domain="${ADS_REALM:-$(dlg_inputbox 'Enter Domain Realm' 'Enter the AD realm (e.g., FHMTN1.LAN, AVCTN.LAN):' '')}"
    
    if [[ -z "$domain" ]]; then
        log "WARN" "User cancelled domain entry"
        return 0
    fi
    
    # Validate domain format
    domain=$(echo "$domain" | tr '[:lower:]' '[:upper:]')
    if [[ ! "$domain" =~ ^[A-Z0-9]+\.[A-Z]+$ ]]; then
        dlg_msgbox "Invalid Domain" "Domain must be in format: DOMAIN.LAN (e.g., FHMTN1.LAN)"
        return 1
    fi
    
    # Display header with REALM
    log "HEAD" "=== INSTALL GUIDE: $domain ==="
    
    # Calculate install steps doc path using $DIVTOOLS
    if [[ -z "$DIVTOOLS" ]]; then
        log "WARN" "DIVTOOLS not set, attempting to derive from script location"
        DIVTOOLS=$(cd "$SCRIPT_DIR/../.." && pwd)
        log "DEBUG" "Derived DIVTOOLS: $DIVTOOLS"
    fi
    
    local doc_dir="$DIVTOOLS/projects/ads/native"
    local doc_name="INSTALL-STEPS-${domain}.md"
    local doc_path="$doc_dir/$doc_name"
    
    log "DEBUG" "Generating installation steps for domain: $domain"
    log "DEBUG" "DIVTOOLS: $DIVTOOLS"
    log "DEBUG" "Document directory: $doc_dir"
    log "DEBUG" "Document path: $doc_path"
    
    # Create directory if it doesn't exist
    if [[ ! -d "$doc_dir" ]]; then
        log "DEBUG" "Creating directory: $doc_dir"
        if ! mkdir -p "$doc_dir"; then
            log "ERROR" "Failed to create directory: $doc_dir"
            dlg_msgbox "Error" "Failed to create directory:\n\n$doc_dir\n\nCheck permissions and try again."
            return 1
        fi
        log "INFO:!ts" "✓ Created directory: $doc_dir"
    fi
    
    # Backup existing file if it exists and is different
    if [[ -f "$doc_path" ]]; then
        log "DEBUG" "Document already exists, checking if content differs..."
        backup_file "$doc_path"
    fi
    
    # Generate the document content
    local doc_content="# Samba AD DC Installation Steps - $domain

**Generated:** $(date '+%Y-%m-%d %H:%M:%S')
**Domain/Realm:** $domain
**NetBIOS Name:** ${ADS_NETBIOS:-DOMAIN}
**Admin User:** ${ADS_ADMIN_USER:-Administrator}
**Host:** $(hostname)

---

## Pre-Installation Checks

- [ ] System hostname set correctly
- [ ] DNS resolver configured to use this server (127.0.0.1)
- [ ] Sufficient disk space available (~2GB minimum)
- [ ] Network connectivity verified
- [ ] Internet access available for package downloads

---

## Installation Steps

### Step 1: Install Samba Packages
- [ ] Run: \`apt-get update && apt-get install -y samba samba-dsdb-modules samba-vfs-modules krb5-user krb5-config winbind libpam-winbind libnss-winbind\`
- [ ] Verify installation: \`samba-tool --version\`
- [ ] Check for errors in output

### Step 2: Configure Environment Variables
- [ ] Domain Realm: \`$domain\`
- [ ] NetBIOS Name: \`${ADS_NETBIOS:-DOMAIN}\`
- [ ] Admin User: \`${ADS_ADMIN_USER:-Administrator}\`
- [ ] Domain Admin Password: (must be complex, 12+ chars)
- [ ] DNS Backend: \`${ADS_DNS_BACKEND:-SAMBA_INTERNAL}\`

### Step 3: Provision AD Domain
- [ ] Run: \`dt_ads_native.sh\` → Menu Option 8: Provision AD Domain
- [ ] Wait for provisioning to complete (may take 1-2 minutes)
- [ ] Check for any error messages
- [ ] Verify /etc/samba/smb.conf was created

### Step 4: Configure DNS on Host
- [ ] Run: \`dt_ads_native.sh\` → Menu Option 9: Configure DNS on Host
- [ ] Stop systemd-resolved
- [ ] Update /etc/resolv.conf to point to 127.0.0.1
- [ ] Verify DNS is working: \`nslookup ${domain}\`

### Step 5: Start Samba Services
- [ ] Run: \`dt_ads_native.sh\` → Menu Option 10: Start Samba Services
- [ ] Verify services started: \`systemctl status samba-ad-dc\`
- [ ] Check Samba logs: \`journalctl -u samba-ad-dc -n 20\`

### Step 6: Create Soft-Links for Config Editing
- [ ] Run: \`dt_ads_native.sh\` → Menu Option 4: Create Config File Links
- [ ] Verify soft-links created in \$DOCKER_HOSTDIR/ads.cfg/
- [ ] Test editing: Open smb.conf in VSCode

### Step 7: Install Bash Aliases
- [ ] Run: \`dt_ads_native.sh\` → Menu Option 5: Install Bash Aliases
- [ ] Test alias: \`ads-status\` or \`ads-health\`

### Step 8: Verify Domain Setup
- [ ] Run: \`dt_ads_native.sh\` → Menu Option 14: Run Health Checks
- [ ] Check all test results pass
- [ ] Verify FSMO roles assigned
- [ ] Confirm replication working

---

## Post-Installation Tasks

- [ ] Create domain admin user: \`samba-tool user add <username>\`
- [ ] Add user to Domain Admins group: \`samba-tool group addmembers 'Domain Admins' <username>\`
- [ ] Configure DNS zones (if using SAMBA_INTERNAL)
- [ ] Set up file shares (if needed)
- [ ] Configure GPOs (Group Policy Objects) as needed
- [ ] Join additional computers to the domain
- [ ] Enable regular backups of /var/lib/samba/private/

---

## Troubleshooting

If you encounter issues:

1. **DNS not resolving:** \`nslookup -server=127.0.0.1 $domain\`
2. **Service won't start:** \`journalctl -u samba-ad-dc -p err -n 50\`
3. **Replication issues:** \`samba-tool drs showrepl\`
4. **User authentication fails:** \`kinit Administrator@${domain}\`

---

## Configuration Files

For detailed information about Samba configuration files, see: [N-ADS-CONFIG-FILES.md](N-ADS-CONFIG-FILES.md)

---

**Last Updated:** $(date '+%Y-%m-%d %H:%M:%S')
**Auto-generated by dt_ads_native.sh**
"
    
    # Write the document
    if echo -e "$doc_content" > "$doc_path"; then
        # Create abbreviated path for display (show from ./projects/ads/native onward)
        local display_path="./projects/ads/native/$doc_name"
        log "INFO:!ts" "✓ Installation steps document created: $doc_name"
        log "INFO:!ts" "Location: $display_path"
        log "DEBUG" "Full path: $doc_path"
        dlg_msgbox "Success - REALM: $domain" "Installation steps document created:\n\n$display_path\n\nYou can now follow the steps one by one.\nUse Menu Option to update status as you complete each step."
        return 0
    else
        log "ERROR" "Failed to write document: $doc_path"
        dlg_msgbox "Error" "Failed to create installation steps document.\n\nCheck permissions on:\n$doc_path"
        return 1
    fi
}

# Check/update installation steps status
# Last Updated: 01/11/2026 4:55:00 PM CDT
check_install_steps_status() {
    # Last Updated: 01/12/2026 10:30:00 AM CDT
    
    # Load environment variables first
    if ! load_ads_env_vars; then
        log "ERROR" "Failed to load environment variables"
        dlg_msgbox "Error" "Failed to load environment variables from $ENV_FILE"
        return 1
    fi
    
    # Get domain/realm from environment
    local domain="${ADS_REALM:-}"
    
    if [[ -z "$domain" ]]; then
        dlg_msgbox "Missing Domain" "ADS_REALM not set in environment.\n\nPlease configure environment variables first (Menu Option 2)."
        return 1
    fi
    
    # Display header with REALM
    log "HEAD" "=== INSTALL GUIDE: $domain ==="
    
    # Validate document exists
    domain=$(echo "$domain" | tr '[:lower:]' '[:upper:]')
    local doc_name="INSTALL-STEPS-${domain}.md"
    
    # Use $DIVTOOLS for path calculation
    if [[ -z "$DIVTOOLS" ]]; then
        log "WARN" "DIVTOOLS not set, attempting to derive from script location"
        DIVTOOLS=$(cd "$SCRIPT_DIR/../.." && pwd)
        log "DEBUG" "Derived DIVTOOLS: $DIVTOOLS"
    fi
    
    local doc_dir="$DIVTOOLS/projects/ads/native"
    local doc_path="$doc_dir/$doc_name"
    
    if [[ ! -f "$doc_path" ]]; then
        dlg_msgbox "Document Not Found" "Installation steps document not found:\n\n$doc_name\n\nCreate it first using Menu Option to generate documentation."
        return 1
    fi
    
    log "DEBUG" "Checking installation step status for domain: $domain"
    log "DEBUG" "Document: $doc_path"
    
    # Check status of each major step
    local checks_completed=0
    local checks_total=0
    
    # Array of checks: (description, command, step_marker)
    local -a status_checks=(
        "samba-tool installed:apt-get:packages installed"
        "Samba provisioned:/etc/samba/smb.conf:domain provisioned"
        "DNS configured:/etc/resolv.conf:DNS configured"
        "Samba services running:samba-ad-dc:Samba running"
        "Config links created:$DOCKER_HOSTDIR/ads.cfg:config links"
        "Aliases installed:samba-aliases-native.sh:aliases installed"
    )
    
    # Build status summary using printf for proper newline handling
    local status_msg="**File:** ./projects/ads/native/$doc_name"$'\n'
    status_msg+="**REALM:** $domain"$'\n\n'
    status_msg+="Installation Status:"$'\n\n'
    
    # ANSI color codes for status (will display in dialog with colored text)
    # Green for complete, Orange/Yellow for incomplete
    local COLOR_GREEN='\033[1;32m'    # Bold Green
    local COLOR_ORANGE='\033[38;5;208m'  # Orange/Yellow ANSI 256-color
    local COLOR_RESET='\033[0m'       # Reset color
    
    # Check 1: Samba installed
    if command -v samba-tool &>/dev/null; then
        status_msg+="${COLOR_GREEN}✓ Samba installed: $(samba-tool --version | head -n1)${COLOR_RESET}"
        ((checks_completed++))
    else
        status_msg+="${COLOR_ORANGE}✗ Samba not installed${COLOR_RESET}"
    fi
    status_msg+=$'\n'
    ((checks_total++))
    
    # Check 2: Domain provisioned
    if [[ -f /etc/samba/smb.conf ]]; then
        status_msg+="${COLOR_GREEN}✓ Domain provisioned${COLOR_RESET}"
        ((checks_completed++))
    else
        status_msg+="${COLOR_ORANGE}✗ Domain not provisioned${COLOR_RESET}"
    fi
    status_msg+=$'\n'
    ((checks_total++))
    
    # Check 3: DNS configured
    if grep -q "127.0.0.1" /etc/resolv.conf 2>/dev/null; then
        status_msg+="${COLOR_GREEN}✓ DNS configured (127.0.0.1)${COLOR_RESET}"
        ((checks_completed++))
    else
        status_msg+="${COLOR_ORANGE}✗ DNS not configured${COLOR_RESET}"
    fi
    status_msg+=$'\n'
    ((checks_total++))
    
    # Check 4: Samba services running
    if systemctl is-active --quiet samba-ad-dc 2>/dev/null; then
        status_msg+="${COLOR_GREEN}✓ Samba AD DC service running${COLOR_RESET}"
        ((checks_completed++))
    else
        status_msg+="${COLOR_ORANGE}✗ Samba AD DC service not running${COLOR_RESET}"
    fi
    status_msg+=$'\n'
    ((checks_total++))
    
    # Check 5: Config links exist
    if [[ -L "$DOCKER_HOSTDIR/ads.cfg/smb.conf" ]]; then
        status_msg+="${COLOR_GREEN}✓ Config file links created${COLOR_RESET}"
        ((checks_completed++))
    else
        status_msg+="${COLOR_ORANGE}✗ Config file links not created${COLOR_RESET}"
    fi
    status_msg+=$'\n'
    ((checks_total++))
    
    # Check 6: Aliases installed
    if grep -q "samba-aliases-native" ~/.bashrc 2>/dev/null || grep -q "samba-aliases-native" ~/.bash_profile 2>/dev/null; then
        status_msg+="${COLOR_GREEN}✓ Bash aliases installed${COLOR_RESET}"
        ((checks_completed++))
    else
        status_msg+="${COLOR_ORANGE}✗ Bash aliases not installed${COLOR_RESET}"
    fi
    status_msg+=$'\n'
    ((checks_total++))
    
    # Add summary
    status_msg+=$'\n'"**Progress:** $checks_completed/$checks_total steps completed"
    
    # Strip ANSI color codes from status message before displaying
    # Dialog textbox doesn't render ANSI escape sequences, so we remove them for display
    local display_status=$(echo -e "$status_msg" | sed 's/\x1b\[[0-9;]*m//g')
    
    log "INFO:!ts" "Installation progress: $checks_completed/$checks_total completed"
    log "INFO:!ts" "Updated: ./projects/ads/native/$doc_name"
    
    # Display the status without ANSI codes in dialog
    dlg_msgbox "Installation Status - REALM: $domain" "$display_status"
    
    # Now update the document with checked boxes (original document update code follows)
    if [[ -w "$doc_path" ]]; then
        local updated_doc=$(cat "$doc_path" | sed "
            /^- \[ \] Run: \`apt-get update/s/- \[ \]/- [x]/ ; /samba-tool installed/! s/- \[x\] Run: \`apt-get update/- [ ] Run: \`apt-get update/ ;
            /^- \[ \] Verify installation:/s/- \[ \]/- [x]/ ; $(systemctl is-active --quiet samba-ad-dc 2>/dev/null && echo "s/- \[ \] Run: \`dt_ads_native.sh\` → Menu Option 6/- [x] Run: \`dt_ads_native.sh\` → Menu Option 6/") ;
            $(grep -q "127.0.0.1" /etc/resolv.conf 2>/dev/null && echo "s/^- \[ \] Run: \`dt_ads_native.sh\` → Menu Option 7:/- [x] Run: \`dt_ads_native.sh\` → Menu Option 7:/") ;
            $(systemctl is-active --quiet samba-ad-dc 2>/dev/null && echo "s/^- \[ \] Run: \`dt_ads_native.sh\` → Menu Option 8:/- [x] Run: \`dt_ads_native.sh\` → Menu Option 8:/") ;
            $(test -L "$DOCKER_HOSTDIR/ads.cfg/smb.conf" && echo "s/^- \[ \] Run: \`dt_ads_native.sh\` → Menu Option 4:/- [x] Run: \`dt_ads_native.sh\` → Menu Option 4:/") ;
            $(grep -q "samba-aliases-native" ~/.bashrc 2>/dev/null && echo "s/^- \[ \] Run: \`dt_ads_native.sh\` → Menu Option 5:/- [x] Run: \`dt_ads_native.sh\` → Menu Option 5:/")
        ")
        
        echo -e "$updated_doc" > "$doc_path"
        log "DEBUG" "Updated $doc_name with current status"
    else
        log "WARN" "Cannot write to $doc_path - document is read-only"
    fi
    return 0
}

################################################################################
# Installation Functions
################################################################################

check_samba_installed() {
    # Last Updated: 01/10/2026 4:50:00 PM CDT
    log "INFO" "Checking if Samba is installed..."
    
    if command -v samba-tool &> /dev/null; then
        local samba_version=$(samba-tool --version | head -n1)
        log "INFO:!ts" "✓ Samba is installed: $samba_version"
        return 0
    else
        log "WARN:!ts" "✗ Samba is not installed"
        return 1
    fi
}

install_samba() {
    # Last Updated: 01/10/2026 4:50:00 PM CDT
    log "HEAD" "=== Install Samba Native ==="
    log "INFO" "[MENU SELECTION] Samba Installation initiated"
    
    # Check if already installed
    if check_samba_installed; then
        if ! dlg_yesno "Samba Already Installed" "Samba is already installed on this system.\n\nReinstall anyway?"; then
            log "DEBUG" "User declined reinstallation"
            return 0
        fi
    fi
    
    # Confirm installation
    local install_msg="This will install the following packages:
    
• samba (AD DC, file sharing)
• samba-dsdb-modules (Directory database)
• samba-vfs-modules (Virtual file system)
• krb5-user (Kerberos client)
• krb5-config (Kerberos configuration)
• winbind (Windows integration)
• libpam-winbind (PAM authentication)
• libnss-winbind (Name service switch)

Estimated download size: ~50MB
Estimated install time: 2-3 minutes

Proceed with installation?"
    
    if ! dlg_yesno "Install Samba" "$install_msg"; then
        log "DEBUG" "User cancelled installation"
        return 0
    fi
    
    log "INFO" "Starting Samba installation..."
    
    if [[ $TEST_MODE -eq 1 ]]; then
        log "INFO" "[TEST] Would run: apt-get update"
        log "INFO" "[TEST] Would install: samba samba-dsdb-modules samba-vfs-modules krb5-user krb5-config winbind libpam-winbind libnss-winbind"
        dlg_msgbox "Test Mode" "Installation simulated successfully.\n\n(No actual changes made)"
        return 0
    fi
    
    # Update package lists
    log "INFO" "Updating package lists..."
    if ! sudo apt-get update; then
        log "ERROR" "Failed to update package lists"
        dlg_msgbox "Installation Failed" "Failed to update package lists.\n\nCheck your internet connection and try again."
        return 1
    fi
    
    # Install packages
    log "INFO" "Installing Samba packages..."
    if ! sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
        samba samba-dsdb-modules samba-vfs-modules \
        krb5-user krb5-config winbind libpam-winbind libnss-winbind; then
        log "ERROR" "Failed to install Samba packages"
        dlg_msgbox "Installation Failed" "Package installation failed.\n\nCheck logs for details:\n$LOG_FILE"
        return 1
    fi
    
    # Verify installation
    if check_samba_installed; then
        local samba_version=$(samba-tool --version | head -n1)
        log "INFO:!ts" "✓ Samba installation completed successfully"
        dlg_msgbox "Installation Complete" "Samba installed successfully!\n\nVersion: $samba_version\n\nNext step: Configure environment variables"
        return 0
    else
        log "ERROR" "Installation appeared to succeed but samba-tool not found"
        dlg_msgbox "Installation Warning" "Packages installed but samba-tool command not found.\n\nPlease check logs:\n$LOG_FILE"
        return 1
    fi
}

################################################################################
# Environment Variable Management
################################################################################

load_env_vars() {
    # Last Updated: 01/10/2026 4:50:00 PM CDT
    log "DEBUG" "Loading ADS environment variables..."
    
    # Create config directory if it doesn't exist
    if [[ ! -d "$CONFIG_DIR" ]]; then
        sudo mkdir -p "$CONFIG_DIR"
        sudo chown -R $USER:$USER "$CONFIG_DIR"
        log "DEBUG" "Created config directory: $CONFIG_DIR"
    fi
    
    # Load from env file if it exists
    if [[ -f "$ENV_FILE" ]]; then
        log "DEBUG" "Loading variables from $ENV_FILE"
        source "$ENV_FILE" 2>/dev/null || true
    else
        log "DEBUG" "No env file found at $ENV_FILE"
    fi
}

prompt_env_vars() {
    # Last Updated: 01/10/2026 4:50:00 PM CDT
    log "HEAD" "=== Configure Environment Variables ==="
    log "INFO" "[MENU SELECTION] Environment Configuration initiated"
    
    load_env_vars
    
    # Prompt for each required variable
    ADS_DOMAIN=$(dlg_inputbox "Domain Name" "Enter your AD domain name (e.g., avctn.lan):" "${ADS_DOMAIN:-avctn.lan}")
    [[ -z "$ADS_DOMAIN" ]] && { log "DEBUG" "User cancelled"; return 0; }
    
    ADS_REALM=$(dlg_inputbox "Realm Name" "Enter your Kerberos realm (usually uppercase domain):" "${ADS_REALM:-${ADS_DOMAIN^^}}")
    [[ -z "$ADS_REALM" ]] && { log "DEBUG" "User cancelled"; return 0; }
    
    ADS_WORKGROUP=$(dlg_inputbox "Workgroup/NetBIOS Name" "Enter your NetBIOS domain name (15 chars max):" "${ADS_WORKGROUP:-${ADS_DOMAIN%%.*}}")
    [[ -z "$ADS_WORKGROUP" ]] && { log "DEBUG" "User cancelled"; return 0; }
    
    ADS_ADMIN_PASSWORD=$(dlg_inputbox "Administrator Password" "Enter the Administrator password:" "${ADS_ADMIN_PASSWORD:-}")
    [[ -z "$ADS_ADMIN_PASSWORD" ]] && { log "DEBUG" "User cancelled"; return 0; }
    
    ADS_DNS_FORWARDER=$(dlg_inputbox "DNS Forwarder" "Enter DNS forwarder IP (for external lookups):" "${ADS_DNS_FORWARDER:-8.8.8.8}")
    [[ -z "$ADS_DNS_FORWARDER" ]] && { log "DEBUG" "User cancelled"; return 0; }
    
    ADS_HOST_IP=$(dlg_inputbox "Host IP Address" "Enter this server's IP address:" "${ADS_HOST_IP:-$(hostname -I | awk '{print $1}')}")
    [[ -z "$ADS_HOST_IP" ]] && { log "DEBUG" "User cancelled"; return 0; }
    
    # Save to env file
    log "INFO" "Saving environment variables to $ENV_FILE..."
    
    if [[ $TEST_MODE -eq 1 ]]; then
        log "INFO" "[TEST] Would save variables to $ENV_FILE"
        dlg_msgbox "Test Mode" "Variables would be saved:\n\nADS_DOMAIN=$ADS_DOMAIN\nADS_REALM=$ADS_REALM\nADS_WORKGROUP=$ADS_WORKGROUP\n\n(No actual changes made)"
        return 0
    fi
    
    # Create env file with markers
    sudo tee "$ENV_FILE" > /dev/null <<EOF
$ENV_MARKER_START
# Samba AD DC Configuration
# Last Updated: $(date '+%Y-%m-%d %H:%M:%S %Z')

# Domain Configuration
export ADS_DOMAIN="$ADS_DOMAIN"
export ADS_REALM="$ADS_REALM"
export ADS_WORKGROUP="$ADS_WORKGROUP"

# Authentication
export ADS_ADMIN_PASSWORD="$ADS_ADMIN_PASSWORD"

# Network Configuration
export ADS_DNS_FORWARDER="$ADS_DNS_FORWARDER"
export ADS_HOST_IP="$ADS_HOST_IP"

# Optional Configuration
export ADS_SERVER_ROLE="dc"
export ADS_DNS_BACKEND="SAMBA_INTERNAL"
export ADS_DOMAIN_LEVEL="2016"
export ADS_FOREST_LEVEL="2016"
export ADS_LOG_LEVEL="1"
$ENV_MARKER_END
EOF
    
    sudo chown $USER:$USER "$ENV_FILE"
    log "INFO:!ts" "✓ Environment variables saved"
    dlg_msgbox "Configuration Saved" "Environment variables saved successfully!\n\nFile: $ENV_FILE"
}

################################################################################
# Domain Provisioning
################################################################################

provision_domain() {
    # Last Updated: 01/10/2026 4:50:00 PM CDT
    log "HEAD" "=== Provision AD Domain ==="
    log "INFO" "[MENU SELECTION] Domain Provisioning initiated"
    
    # Check if samba is installed
    if ! check_samba_installed; then
        dlg_msgbox "Samba Not Installed" "Samba is not installed.\n\nPlease install Samba first (Option 1)"
        return 1
    fi
    
    # Load environment variables
    load_env_vars
    
    # Check required variables
    if [[ -z "$ADS_DOMAIN" ]] || [[ -z "$ADS_REALM" ]] || [[ -z "$ADS_ADMIN_PASSWORD" ]]; then
        dlg_msgbox "Missing Configuration" "Required environment variables not set.\n\nPlease configure environment variables first (Option 2)"
        return 1
    fi
    
    # Check if domain already provisioned
    if [[ -f "$DATA_DIR/private/sam.ldb" ]]; then
        log "WARN" "Domain database already exists"
        if ! dlg_yesno "Domain Exists" "A domain database already exists at:\n$DATA_DIR/private/sam.ldb\n\nThis means the domain is already provisioned.\n\nRe-provision anyway? (This will DELETE the existing domain!)"; then
            log "DEBUG" "User declined re-provisioning"
            return 0
        fi
        
        # Stop samba services before reprovisioning
        log "INFO" "Stopping Samba services..."
        sudo systemctl stop samba-ad-dc || true
        
        # Backup existing data
        local backup_dir="$DATA_DIR.backup-$(date +%Y%m%d-%H%M%S)"
        log "INFO" "Backing up existing domain to $backup_dir..."
        sudo mv "$DATA_DIR" "$backup_dir"
    fi
    
    # Confirm provisioning
    local provision_msg="Ready to provision AD domain with:

Domain: $ADS_DOMAIN
Realm: $ADS_REALM  
Workgroup: $ADS_WORKGROUP
Host IP: $ADS_HOST_IP
DNS Forwarder: $ADS_DNS_FORWARDER

This will:
• Create AD database in /var/lib/samba
• Generate smb.conf in /etc/samba
• Configure Kerberos in /etc/krb5.conf
• Set Administrator password

Proceed with provisioning?"
    
    if ! dlg_yesno "Provision Domain" "$provision_msg"; then
        log "DEBUG" "User cancelled provisioning"
        return 0
    fi
    
    log "INFO" "Starting domain provisioning..."
    
    if [[ $TEST_MODE -eq 1 ]]; then
        log "INFO" "[TEST] Would provision domain with samba-tool"
        dlg_msgbox "Test Mode" "Domain provisioning simulated.\n\n(No actual changes made)"
        return 0
    fi
    
    # Remove existing smb.conf if it exists
    if [[ -f "$CONFIG_SAMBA_DIR/smb.conf" ]]; then
        log "INFO" "Removing existing smb.conf"
        sudo rm -f "$CONFIG_SAMBA_DIR/smb.conf"
    fi
    
    # Run samba-tool domain provision
    log "INFO" "Running samba-tool domain provision..."
    if ! sudo samba-tool domain provision \
        --server-role=dc \
        --use-rfc2307 \
        --dns-backend=SAMBA_INTERNAL \
        --realm="$ADS_REALM" \
        --domain="$ADS_WORKGROUP" \
        --adminpass="$ADS_ADMIN_PASSWORD" \
        --host-ip="$ADS_HOST_IP" \
        --option="dns forwarder = $ADS_DNS_FORWARDER" \
        --option="log level = 1"; then
        log "ERROR" "Domain provisioning failed"
        dlg_msgbox "Provisioning Failed" "Domain provisioning failed.\n\nCheck logs for details:\n$LOG_FILE"
        return 1
    fi
    
    # Copy Kerberos config
    if [[ -f "$DATA_DIR/private/krb5.conf" ]]; then
        log "INFO" "Copying Kerberos configuration to /etc/krb5.conf"
        sudo cp "$DATA_DIR/private/krb5.conf" /etc/krb5.conf
    fi
    
    log "INFO:!ts" "✓ Domain provisioning completed successfully"
    dlg_msgbox "Provisioning Complete" "Domain provisioned successfully!\n\nDomain: $ADS_DOMAIN\nRealm: $ADS_REALM\n\nNext step: Configure DNS on host (Option 3)"
    
    return 0
}

################################################################################
# DNS Configuration
################################################################################

configure_host_dns() {
    # Last Updated: 01/10/2026 4:50:00 PM CDT
    log "HEAD" "=== Configure DNS on Host ==="
    log "INFO" "[MENU SELECTION] DNS Configuration initiated"
    
    load_env_vars
    
    # Get current DNS settings
    local current_nameservers=$(grep "^nameserver" /etc/resolv.conf 2>/dev/null | awk '{print $2}' | tr '\n' ' ')
    local current_search=$(grep "^search" /etc/resolv.conf 2>/dev/null | awk '{print $2}')
    
    # Check if systemd-resolved is active
    local systemd_resolved_active=0
    if systemctl is-active --quiet systemd-resolved; then
        systemd_resolved_active=1
    fi
    
    local dns_msg="Current DNS Configuration:
    
Nameservers: $current_nameservers
Search Domain: $current_search
systemd-resolved: $([ $systemd_resolved_active -eq 1 ] && echo "ACTIVE" || echo "inactive")

NEW DNS CONFIGURATION:
Primary NS:   127.0.0.1 (Samba AD DC)
Secondary NS: ${ADS_DNS_FORWARDER:-8.8.8.8} (External)
Search Domain: ${ADS_DOMAIN}

$([ $systemd_resolved_active -eq 1 ] && echo "WARNING: systemd-resolved will be stopped and masked")

Proceed with DNS configuration?"
    
    if ! dlg_yesno "Configure DNS" "$dns_msg"; then
        log "DEBUG" "User cancelled DNS configuration"
        return 0
    fi
    
    if [[ $TEST_MODE -eq 1 ]]; then
        log "INFO" "[TEST] Would configure DNS settings"
        dlg_msgbox "Test Mode" "DNS configuration simulated.\n\n(No actual changes made)"
        return 0
    fi
    
    # Stop and mask systemd-resolved if active
    if [[ $systemd_resolved_active -eq 1 ]]; then
        log "INFO" "Stopping systemd-resolved..."
        sudo systemctl stop systemd-resolved
        sudo systemctl mask systemd-resolved
        log "INFO:!ts" "✓ systemd-resolved stopped and masked"
    fi
    
    # Backup resolv.conf
    if [[ -f /etc/resolv.conf ]]; then
        local backup_file="/etc/resolv.conf.backup-$(date +%Y%m%d-%H%M%S)"
        sudo cp /etc/resolv.conf "$backup_file"
        log "INFO" "Backed up resolv.conf to $backup_file"
    fi
    
    # Update resolv.conf
    log "INFO" "Updating /etc/resolv.conf..."
    echo -e "nameserver 127.0.0.1\nnameserver ${ADS_DNS_FORWARDER:-8.8.8.8}\nsearch ${ADS_DOMAIN}" | sudo tee /etc/resolv.conf > /dev/null
    
    log "INFO:!ts" "✓ DNS configuration completed"
    dlg_msgbox "DNS Configured" "DNS configured successfully!\n\nPrimary: 127.0.0.1 (Samba AD DC)\nSecondary: ${ADS_DNS_FORWARDER}\nSearch: ${ADS_DOMAIN}"
    
    return 0
}

################################################################################
# Service Management
################################################################################

start_samba_services() {
    # Last Updated: 01/10/2026 4:50:00 PM CDT
    log "HEAD" "=== Start Samba Services ==="
    log "INFO" "[MENU SELECTION] Start Services initiated"
    
    if [[ $TEST_MODE -eq 1 ]]; then
        log "INFO" "[TEST] Would start samba-ad-dc service"
        dlg_msgbox "Test Mode" "Services start simulated.\n\n(No actual changes made)"
        return 0
    fi
    
    log "INFO" "Starting samba-ad-dc service..."
    if ! sudo systemctl start samba-ad-dc; then
        log "ERROR" "Failed to start samba-ad-dc"
        dlg_msgbox "Start Failed" "Failed to start Samba services.\n\nCheck logs:\njournalctl -u samba-ad-dc -n 50"
        return 1
    fi
    
    # Enable on boot
    sudo systemctl enable samba-ad-dc
    
    log "INFO:!ts" "✓ Samba services started and enabled"
    dlg_msgbox "Services Started" "Samba AD DC services started successfully!\n\nEnabled on boot: Yes\n\nCheck status with:\nsystemctl status samba-ad-dc"
    
    return 0
}

stop_samba_services() {
    # Last Updated: 01/10/2026 4:50:00 PM CDT
    log "HEAD" "=== Stop Samba Services ==="
    log "INFO" "[MENU SELECTION] Stop Services initiated"
    
    if [[ $TEST_MODE -eq 1 ]]; then
        log "INFO" "[TEST] Would stop samba-ad-dc service"
        dlg_msgbox "Test Mode" "Services stop simulated.\n\n(No actual changes made)"
        return 0
    fi
    
    log "INFO" "Stopping samba-ad-dc service..."
    if ! sudo systemctl stop samba-ad-dc; then
        log "ERROR" "Failed to stop samba-ad-dc"
        dlg_msgbox "Stop Failed" "Failed to stop Samba services.\n\nCheck status:\nsystemctl status samba-ad-dc"
        return 1
    fi
    
    log "INFO:!ts" "✓ Samba services stopped"
    dlg_msgbox "Services Stopped" "Samba AD DC services stopped successfully."
    
    return 0
}

restart_samba_services() {
    # Last Updated: 01/10/2026 4:50:00 PM CDT
    log "HEAD" "=== Restart Samba Services ==="
    log "INFO" "[MENU SELECTION] Restart Services initiated"
    
    if [[ $TEST_MODE -eq 1 ]]; then
        log "INFO" "[TEST] Would restart samba-ad-dc service"
        dlg_msgbox "Test Mode" "Services restart simulated.\n\n(No actual changes made)"
        return 0
    fi
    
    log "INFO" "Restarting samba-ad-dc service..."
    if ! sudo systemctl restart samba-ad-dc; then
        log "ERROR" "Failed to restart samba-ad-dc"
        dlg_msgbox "Restart Failed" "Failed to restart Samba services.\n\nCheck logs:\njournalctl -u samba-ad-dc -n 50"
        return 1
    fi
    
    log "INFO:!ts" "✓ Samba services restarted"
    dlg_msgbox "Services Restarted" "Samba AD DC services restarted successfully."
    
    return 0
}

view_service_logs() {
    # Last Updated: 01/10/2026 4:50:00 PM CDT
    log "HEAD" "=== View Service Logs ==="
    log "INFO" "[MENU SELECTION] View Logs initiated"
    
    dlg_msgbox "Viewing Logs" "Opening journalctl for samba-ad-dc service.\n\nPress 'q' to quit the log viewer."
    
    sudo journalctl -u samba-ad-dc -n 100 --no-pager
    
    read -p "Press Enter to continue..."
}

################################################################################
# Bash Aliases Installation
################################################################################

install_bash_aliases() {
    # Last Updated: 01/10/2026 10:45:00 PM CST
    log "HEAD" "=== Install Samba Bash Aliases (Native) ==="
    log "INFO" "[MENU SELECTION] Bash Aliases Installation initiated"
    
    local source_file="$PROJECT_ROOT/projects/ads/native/samba-aliases-native.sh"
    local dotfiles_dir="$PROJECT_ROOT/dotfiles"
    local dotfiles_aliases="$dotfiles_dir/samba-aliases-native.sh"
    local user_bash_aliases="$HOME/.bash_aliases"
    local divtools_bash_aliases="$dotfiles_dir/.bash_aliases"
    
    # Check if source file exists
    if [[ ! -f "$source_file" ]]; then
        log "ERROR" "Source aliases file not found: $source_file"
        dlg_msgbox "Error" "ERROR: samba-aliases-native.sh not found at:\n\n$source_file\n\nPlease ensure the file exists before running this option."
        return 1
    fi
    
    # Helper function to create/update softlink
    create_softlink() {
        local link_target="$dotfiles_aliases"
        local link_source="../projects/ads/native/samba-aliases-native.sh"
        
        log "DEBUG" "Creating/updating softlink: $link_target -> $link_source"
        
        if [[ $TEST_MODE -eq 1 ]]; then
            log "INFO" "[TEST] Would create softlink: ln -sf $link_source $link_target"
            return 0
        fi
        
        # Create the softlink (relative path from dotfiles to projects/ads/native)
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
        local include_line="source \"\$DIVTOOLS/dotfiles/samba-aliases-native.sh\""
        
        log "DEBUG" "Adding include to: $target_file"
        
        # Check if include already exists
        if [[ -f "$target_file" ]] && grep -q "samba-aliases-native.sh" "$target_file"; then
            log "WARN" "Include for samba-aliases-native.sh already exists in $target_file"
            local message="Include for samba-aliases-native.sh already exists in:

$target_file

Add it anyway (might cause duplicate aliases)?"
            if ! dlg_yesno "Include Already Exists" "$message"; then
                log "DEBUG" "User cancelled due to existing include"
                return 0
            fi
        fi
        
        if [[ $TEST_MODE -eq 1 ]]; then
            log "INFO" "[TEST] Would append '$include_line' to $target_file"
            return 0
        fi
        
        # Add the include at the end of the file
        echo -e "\n# Samba AD DC Native Bash Aliases\n$include_line" >> "$target_file"
        log "INFO:!ts" "✓ Added include to $target_file"
        return 0
    }
    
    # Show user options
    local choice=$(dlg_menu "Bash Aliases Installation" "Choose how to install Samba bash aliases:" \
        "1" "Create softlink in dotfiles + include in ~/.bash_aliases" \
        "2" "Create softlink in dotfiles + include in dotfiles/.bash_aliases" \
        "3" "Create softlink in dotfiles only" \
        "4" "Cancel")
    
    case $choice in
        1)
            log "INFO" "User chose: Create softlink + include in ~/.bash_aliases"
            
            # Create softlink first
            if ! create_softlink; then
                dlg_msgbox "Failed" "Failed to create softlink.\n\nCheck logs for details."
                return 1
            fi
            
            # Add include to user's ~/.bash_aliases
            if ! add_include_to_file "$user_bash_aliases"; then
                dlg_msgbox "Failed" "Failed to add include to ~/.bash_aliases.\n\nCheck logs for details."
                return 1
            fi
            
            dlg_msgbox "Installation Complete" "Installation Complete!\n\n✓ Softlink created: dotfiles/samba-aliases-native.sh\n✓ Include added to ~/.bash_aliases\n\nRun 'source ~/.bash_aliases' to activate."
            ;;
        
        2)
            log "INFO" "User chose: Create softlink + include in dotfiles/.bash_aliases"
            
            # Create softlink first
            if ! create_softlink; then
                dlg_msgbox "Failed" "Failed to create softlink.\n\nCheck logs for details."
                return 1
            fi
            
            # Add include to divtools .bash_aliases
            if ! add_include_to_file "$divtools_bash_aliases"; then
                dlg_msgbox "Failed" "Failed to add include to dotfiles/.bash_aliases.\n\nCheck logs for details."
                return 1
            fi
            
            dlg_msgbox "Installation Complete" "Installation Complete!\n\n✓ Softlink created: dotfiles/samba-aliases-native.sh\n✓ Include added to dotfiles/.bash_aliases\n\nThis will work on ALL systems using divtools."
            ;;
        
        3)
            log "INFO" "User chose: Create softlink only"
            
            # Create softlink
            if ! create_softlink; then
                dlg_msgbox "Failed" "Failed to create softlink.\n\nCheck logs for details."
                return 1
            fi
            
            dlg_msgbox "Softlink Created" "Softlink Created!\n\n✓ dotfiles/samba-aliases-native.sh -> ../projects/ads/native/samba-aliases-native.sh\n\nYou can now manually source this file or add includes as needed."
            ;;
        
        4|"")
            log "DEBUG" "User cancelled bash aliases installation"
            ;;
    esac
}

################################################################################
# Health Checks
################################################################################

run_health_checks() {
    # Last Updated: 01/10/2026 4:50:00 PM CDT
    log "HEAD" "=== Health Checks ==="
    log "INFO" "[MENU SELECTION] Health Checks initiated"
    
    local results=""
    
    # Check if service is running
    results+="Service Status:\n"
    if systemctl is-active --quiet samba-ad-dc; then
        results+="✓ samba-ad-dc is running\n\n"
    else
        results+="✗ samba-ad-dc is NOT running\n\n"
    fi
    
    # Check domain info
    results+="Domain Information:\n"
    local domain_info=$(sudo samba-tool domain info 127.0.0.1 2>&1)
    if [[ $? -eq 0 ]]; then
        results+="$domain_info\n\n"
    else
        results+="✗ Failed to get domain info\n\n"
    fi
    
    # Check FSMO roles
    results+="FSMO Roles:\n"
    local fsmo_roles=$(sudo samba-tool fsmo show 2>&1 | head -n 10)
    results+="$fsmo_roles\n"
    
    dlg_msgbox "Health Check Results" "$results"
}

################################################################################
# Main Menu
################################################################################

main_menu() {
    # Last Updated: 01/12/2026 05:59:00 PM CDT
    
    # Load environment to get REALM for menu display
    local display_realm="${ADS_REALM:-Not Configured}"
    if ! declare -f load_ads_env_vars >/dev/null 2>&1; then
        load_ads_env_vars >/dev/null 2>&1
        display_realm="${ADS_REALM:-Not Configured}"
    fi
    
    while true; do
        local -a menu_items=(
            "" "═══ INSTALLATION ═══"
            "1" "Install Samba (Native)"
            "2" "Configure Environment Variables"
            "3" "Check Environment Variables"
            "4" "Create Config File Links (for VSCode)"
            "5" "Install Bash Aliases"
            "" "═══ INSTALL GUIDE: $display_realm ═══"
            "6" "Generate Installation Steps Doc"
            "7" "Update Installation Steps Doc"
            "" "═══ DOMAIN SETUP ═══"
            "8" "Provision AD Domain"
            "9" "Configure DNS on Host"
            "" "═══ SERVICE MANAGEMENT ═══"
            "10" "Start Samba Services"
            "11" "Stop Samba Services"
            "12" "Restart Samba Services"
            "13" "View Service Logs"
            "" "═══ DIAGNOSTICS ═══"
            "14" "Run Health Checks"
            "" "═════════════════════════════"
            "0" "Exit"
        )
        
        CHOICE=$(dlg_menu "Samba AD DC Native Setup" "Choose an option" "${menu_items[@]}" 3>&1 1>&2 2>&3)
        local exit_code=$?
        
        # Handle cancel (ESC key)
        if [[ $exit_code -ne 0 ]]; then
            log "INFO" "User cancelled from main menu"
            log "HEAD" "Script execution cancelled - Exiting"
            exit 0
        fi
        
        # Handle empty selection (section headers)
        if [[ -z "$CHOICE" ]]; then
            continue
        fi
        
        local menu_descriptions=(
            "Exit"
            "Install Samba (Native)"
            "Configure Environment Variables"
            "Check Environment Variables"
            "Create Config File Links (for VSCode)"
            "Install Bash Aliases"
            "Generate Installation Steps Doc"
            "Update Installation Steps Doc"
            "Provision AD Domain"
            "Configure DNS on Host"
            "Start Samba Services"
            "Stop Samba Services"
            "Restart Samba Services"
            "View Service Logs"
            "Run Health Checks"
        )
        
        if [[ "$CHOICE" != "0" ]]; then
            log "HEAD" "═══════════════════════════════════════════"
            log "HEAD" "MENU SELECTION: Option $CHOICE - ${menu_descriptions[$CHOICE]}"
            log "HEAD" "═══════════════════════════════════════════"
        fi
        
        case $CHOICE in
            1) install_samba ;;
            2) prompt_env_vars ;;
            3) check_env_vars ;;
            4) create_config_file_links ;;
            5) install_bash_aliases ;;
            6) generate_install_steps_doc ;;
            7) check_install_steps_status ;;
            8) provision_domain ;;
            9) configure_host_dns ;;
            10) start_samba_services ;;
            11) stop_samba_services ;;
            12) restart_samba_services ;;
            13) view_service_logs ;;
            14) run_health_checks ;;
            0)
                log "HEAD" "Script execution completed - Exiting"
                exit 0
                ;;
        esac
    done
}

################################################################################
# Entry Point
################################################################################

# Check if dialog is installed
if ! command -v dialog &> /dev/null; then
    log "ERROR" "dialog is required but not installed. Install with: sudo apt install dialog"
    exit 1
fi

# Run main menu
main_menu
