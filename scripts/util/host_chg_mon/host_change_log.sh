#!/bin/bash
#
# host_change_log.sh - Setup and maintain host change monitoring
#
# This script configures a host to properly preserve and organize files
# that should be monitored for changes by n8n or other monitoring tools.
#
# Monitors:
#   - APT package installations
#   - Docker configuration files
#   - User command history (root, divix, others)
#   - Critical log files
#
# Usage:
#   ./host_change_log.sh setup    # Initial setup and configuration
#   ./host_change_log.sh verify   # Verify configuration is still valid
#   ./host_change_log.sh manifest # Generate monitoring manifest for n8n
#   ./host_change_log.sh status   # Show current monitoring status
#

set -euo pipefail

# Default flags
TEST_MODE=0
DEBUG_MODE=0

# Initialize environment tracking variable
ENV_FILES_LOADED=""

# Step 0: Load local environment overrides from ~/.env (highest priority for SITE_NAME)
if [[ -f "$HOME/.env" ]]; then
    ENV_FILES_LOADED="$HOME/.env"
    set +u
    source "$HOME/.env" 2>/dev/null || true
    set -u
fi

# Load environment variables - shared, site, and host-specific
# Step 1: Load shared env (always)
if [[ -f "/opt/divtools/docker/sites/s00-shared/.env.s00-shared" ]]; then
    [[ -n "$ENV_FILES_LOADED" ]] && ENV_FILES_LOADED="${ENV_FILES_LOADED}:" || true
    ENV_FILES_LOADED="${ENV_FILES_LOADED}/opt/divtools/docker/sites/s00-shared/.env.s00-shared"
    set +u
    source "/opt/divtools/docker/sites/s00-shared/.env.s00-shared" 2>/dev/null || true
    set -u
elif [[ -f "/home/divix/divtools/docker/sites/s00-shared/.env.s00-shared" ]]; then
    [[ -n "$ENV_FILES_LOADED" ]] && ENV_FILES_LOADED="${ENV_FILES_LOADED}:" || true
    ENV_FILES_LOADED="${ENV_FILES_LOADED}/home/divix/divtools/docker/sites/s00-shared/.env.s00-shared"
    set +u
    source "/home/divix/divtools/docker/sites/s00-shared/.env.s00-shared" 2>/dev/null || true
    set -u
fi

# Step 2: Load site-specific env if SITE_NAME is set
if [[ -n "${SITE_NAME:-}" ]]; then
    site_env_file="/opt/divtools/docker/sites/${SITE_NAME}/.env.${SITE_NAME}"
    if [[ -f "$site_env_file" ]]; then
        ENV_FILES_LOADED="${ENV_FILES_LOADED}:${site_env_file}"
        set +u
        source "$site_env_file" 2>/dev/null || true
        set -u
    fi
fi

# Step 3: Load host-specific env if SITE_NAME is set
# Try both uppercase and lowercase hostname variants since hostnames can vary in case
if [[ -n "${SITE_NAME:-}" ]]; then
    HOSTNAME_SHORT=$(hostname)
    HOSTNAME_LOWER=${HOSTNAME_SHORT,,}
    # Try uppercase hostname first
    host_env_file="/opt/divtools/docker/sites/${SITE_NAME}/${HOSTNAME_SHORT}/.env.${HOSTNAME_SHORT}"
    if [[ ! -f "$host_env_file" ]]; then
        # Try lowercase hostname
        host_env_file="/opt/divtools/docker/sites/${SITE_NAME}/${HOSTNAME_LOWER}/.env.${HOSTNAME_LOWER}"
    fi
    if [[ -f "$host_env_file" ]]; then
        ENV_FILES_LOADED="${ENV_FILES_LOADED}:${host_env_file}"
        set +u
        source "$host_env_file" 2>/dev/null || true
        set -u
    fi
fi

# Load environment variables if available
# Default values if env vars not set (with explicit fallbacks)
DT_LOG_DIR="${DT_LOG_DIR:-/var/log/divtools/monitor}"
DT_LOG_MAXSIZE="${DT_LOG_MAXSIZE:-100m}"
DT_LOG_MAXDAYS="${DT_LOG_MAXDAYS:-30}"
DT_LOG_DIVTOOLS="${DT_LOG_DIVTOOLS:-FALSE}"
DT_VERBOSE="${DT_VERBOSE:-0}"

# Configuration
SCRIPT_NAME=$(basename "$0")
MONITOR_BASE_DIR="${DT_LOG_DIR}"
MANIFEST_FILE="${MONITOR_BASE_DIR}/monitoring_manifest.json"
CONFIG_DIR="/etc/divtools"
HISTORY_SIZE=10000
HISTORY_FILESIZE=20000

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

log_debug() {
    # Show debug if either DEBUG_MODE or DT_VERBOSE > 0
    if [[ $DEBUG_MODE -eq 1 || $DT_VERBOSE -gt 0 ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $*"
    fi
}

# Ensure monitoring base directory exists
ensure_log_dir() {
    if [[ ! -d "$MONITOR_BASE_DIR" ]]; then
        log_debug "Creating log directory: ${MONITOR_BASE_DIR}"
        mkdir -p "$MONITOR_BASE_DIR" || {
            log_error "Failed to create log directory: ${MONITOR_BASE_DIR}"
            exit 1
        }
    fi
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

# Create monitoring directory structure
setup_directories() {
    log_info "Setting up monitoring directory structure..."
    log_debug "TEST_MODE=$TEST_MODE, DEBUG_MODE=$DEBUG_MODE"
    
    if [[ $TEST_MODE -eq 1 ]]; then
        log_warning "[TEST MODE] Would create directory structure at: ${MONITOR_BASE_DIR}/{history,apt,docker,checksums,logs,bin}"
        log_warning "[TEST MODE] Would create config directory at: ${CONFIG_DIR}"
        return
    fi
    
    # Create the base monitor directory first if it doesn't exist
    if [[ ! -d "$MONITOR_BASE_DIR" ]]; then
        log_info "Creating base monitoring directory: ${MONITOR_BASE_DIR}"
        mkdir -p "$MONITOR_BASE_DIR"
        chmod 755 "$MONITOR_BASE_DIR"
    fi
    
    # Create subdirectories
    mkdir -p "${MONITOR_BASE_DIR}"/{history,apt,docker,checksums,logs,bin}
    mkdir -p "${CONFIG_DIR}"
    
    # Set appropriate permissions
    chmod 755 "${MONITOR_BASE_DIR}"
    chmod 755 "${CONFIG_DIR}"
    
    log_success "Directory structure created at ${MONITOR_BASE_DIR}"
}

# Configure bash history for better persistence
# Note: Starship prompt does NOT use PROMPT_COMMAND. Instead, we need to:
# 1. Use bash's built-in session history tracking
# 2. Configure bash to save history after each command via HISTCONTROL and shopt settings
# 3. Use multiple history files to track different sessions/TTYs
configure_bash_history() {
    log_info "Configuring bash history settings..."
    log_debug "TEST_MODE=$TEST_MODE (will not modify files)"
    log_info "NOTE: Starship prompt detected - using bash native session tracking"
    
    # For Starship compatibility, we use HISTFILE + bash settings instead of PROMPT_COMMAND
    local bashrc_additions="
# Added by divtools host_change_log.sh
# Enhanced bash history configuration for monitoring with Starship compatibility
export HISTSIZE=${HISTORY_SIZE}
export HISTFILESIZE=${HISTORY_FILESIZE}
export HISTTIMEFORMAT='%F %T '
export HISTCONTROL=ignoredups:erasedups
# Append to history file, don't overwrite
shopt -s histappend
# Save history after each command (bash 4.1+)
shopt -s histverify
# Use extended history format
shopt -s extdebug
# Enable history expansion even in non-interactive shells where possible
set -H
# Write history after each command
PROMPT_COMMAND=\"history -a; history -n; \${PROMPT_COMMAND}\"
"
    
    # Configure for root user
    if ! grep -q "divtools host_change_log.sh" /root/.bashrc 2>/dev/null; then
        log_debug "Adding bash history config to /root/.bashrc"
        if [[ $TEST_MODE -eq 1 ]]; then
            log_warning "[TEST MODE] Would add bash history config to /root/.bashrc"
        else
            echo "$bashrc_additions" >> /root/.bashrc
            log_success "Configured bash history for root user"
        fi
    else
        log_info "Root bash history already configured"
    fi
    
    # Configure for divix user
    if id "divix" &>/dev/null; then
        local divix_home=$(eval echo ~divix)
        if [[ -f "${divix_home}/.bashrc" ]]; then
            if ! grep -q "divtools host_change_log.sh" "${divix_home}/.bashrc" 2>/dev/null; then
                log_debug "Adding bash history config to ${divix_home}/.bashrc"
                if [[ $TEST_MODE -eq 1 ]]; then
                    log_warning "[TEST MODE] Would add bash history config to ${divix_home}/.bashrc"
                else
                    echo "$bashrc_additions" >> "${divix_home}/.bashrc"
                    chown divix:divix "${divix_home}/.bashrc"
                    log_success "Configured bash history for divix user"
                fi
            else
                log_info "Divix bash history already configured"
            fi
        fi
    fi
    
    # Configure for other users with home directories
    while IFS=: read -r username _ uid _ _ home _; do
        if [[ $uid -ge 1000 && -d "$home" && -f "$home/.bashrc" ]]; then
            if [[ "$username" != "divix" && "$username" != "nobody" ]]; then
                if ! grep -q "divtools host_change_log.sh" "$home/.bashrc" 2>/dev/null; then
                    log_debug "Adding bash history config to $home/.bashrc for user $username"
                    if [[ $TEST_MODE -eq 1 ]]; then
                        log_warning "[TEST MODE] Would add bash history config to $home/.bashrc for user $username"
                    else
                        echo "$bashrc_additions" >> "$home/.bashrc"
                        chown "$username:" "$home/.bashrc"
                        log_success "Configured bash history for user: $username"
                    fi
                fi
            fi
        fi
    done < /etc/passwd
    
    log_info "Checking for Starship configuration..."
    # If Starship is in use, provide configuration guidance
    if command -v starship &>/dev/null; then
        log_info "Starship prompt detected - history configuration is compatible"
        log_info "Starship uses PROMPT_COMMAND which works with bash history"
        log_debug "Starship is installed - no additional configuration needed"
    fi
}

# Create symlinks to important log files for easier monitoring
setup_log_links() {
    log_info "Creating symlinks to important log files..."
    
    local log_dir="${MONITOR_BASE_DIR}/logs"
    
    if [[ $TEST_MODE -eq 1 ]]; then
        log_warning "[TEST MODE] Would create symlinks in: ${log_dir}"
        return
    fi
    
    # Ensure logs directory exists before creating symlinks
    if [[ ! -d "$log_dir" ]]; then
        log_debug "Creating logs directory: ${log_dir}"
        mkdir -p "$log_dir" || {
            log_warning "Could not create logs directory: ${log_dir}"
            return
        }
    fi
    
    # APT logs
    if [[ -f /var/log/apt/history.log ]]; then
        ln -sf /var/log/apt/history.log "${log_dir}/apt-history.log" && log_debug "Linked apt-history.log"
    else
        log_debug "APT history log not found: /var/log/apt/history.log (skipped)"
    fi
    
    if [[ -f /var/log/dpkg.log ]]; then
        ln -sf /var/log/dpkg.log "${log_dir}/dpkg.log" && log_debug "Linked dpkg.log"
    else
        log_debug "DPKG log not found: /var/log/dpkg.log (skipped)"
    fi
    
    # System logs
    if [[ -f /var/log/syslog ]]; then
        ln -sf /var/log/syslog "${log_dir}/syslog" && log_debug "Linked syslog"
    else
        log_debug "System log not found: /var/log/syslog (skipped)"
    fi
    
    if [[ -f /var/log/auth.log ]]; then
        ln -sf /var/log/auth.log "${log_dir}/auth.log" && log_debug "Linked auth.log"
    else
        log_debug "Auth log not found: /var/log/auth.log (skipped)"
    fi
    
    # Docker logs (if docker is installed)
    if command -v docker &>/dev/null; then
        if [[ -f /var/log/docker.log ]]; then
            ln -sf /var/log/docker.log "${log_dir}/docker.log" && log_debug "Linked docker.log"
        else
            log_debug "Docker log not found: /var/log/docker.log (skipped)"
        fi
    fi
    
    log_success "Log file symlinks created in ${log_dir}"
}

# Copy rotated/archived log files to monitoring directory using rsync
# Preserves old logs and only copies changes (not re-copying unchanged files)
# Old logs are NOT deleted based on age, but oldest are removed if size limit exceeded
copy_rotated_logs() {
    log_info "Archiving rotated log files..."
    
    local log_dir="${MONITOR_BASE_DIR}/logs"
    
    if [[ $TEST_MODE -eq 1 ]]; then
        log_warning "[TEST MODE] Would copy rotated log files to: ${log_dir}"
        return
    fi
    
    # Ensure logs directory exists
    if [[ ! -d "$log_dir" ]]; then
        log_debug "Creating logs directory: ${log_dir}"
        mkdir -p "$log_dir" || {
            log_warning "Could not create logs directory: ${log_dir}"
            return
        }
    fi
    
    log_debug "Starting rotated log file archival..."
    local copied_count=0
    
    # Use rsync to copy rotated logs (*.1, *.1.gz, *.2, etc.)
    # This avoids re-copying unchanged files
    # Scan /var/log for rotated logs
    log_debug "Scanning /var/log for rotated log files..."
    
    find /var/log -maxdepth 1 -type f \( -name "*.1" -o -name "*.1.gz" -o -name "*.1.bz2" \
        -o -name "*.2" -o -name "*.2.gz" -o -name "*.2.bz2" \
        -o -name "*.3" -o -name "*.3.gz" -o -name "*.3.bz2" \
        -o -name "*.log.old" \) 2>/dev/null | while read -r file; do
        
        local filename=$(basename "$file")
        log_debug "Found rotated log: $filename"
        
        # Use rsync to copy only if file is different or doesn't exist
        if rsync -ah --ignore-existing "$file" "${log_dir}/" 2>/dev/null; then
            ((copied_count++))
            log_debug "Copied: $filename"
        else
            # File already exists, check if it's different
            if rsync -ah --checksum "$file" "${log_dir}/" 2>/dev/null | grep -q "$filename"; then
                log_debug "Updated: $filename"
            else
                log_debug "Already current: $filename"
            fi
        fi
    done
    
    # Also check for compressed backups in standard locations
    find /var/log -maxdepth 1 -type f -name "*.gz" 2>/dev/null | grep -E '\.[0-9]+\.gz$' | while read -r file; do
        local filename=$(basename "$file")
        log_debug "Found compressed archive: $filename"
        
        if rsync -ah --ignore-existing "$file" "${log_dir}/" 2>/dev/null; then
            ((copied_count++))
            log_debug "Copied: $filename"
        fi
    done
    
    if [[ $copied_count -gt 0 ]]; then
        log_success "Copied ${copied_count} rotated log file(s) to ${log_dir}"
    else
        log_debug "No new rotated log files to copy"
    fi
}

# Copy current history files for baseline/backup
backup_current_histories() {
    log_info "Backing up current history files..."
    
    if [[ $TEST_MODE -eq 1 ]]; then
        log_warning "[TEST MODE] Would backup history files from /root, divix, and other users"
        return
    fi
    
    local history_dir="${MONITOR_BASE_DIR}/history"
    local timestamp=$(date +%Y%m%d-%H%M%S)
    
    # Root history
    if [[ -f /root/.bash_history ]]; then
        cp /root/.bash_history "${history_dir}/root.bash_history.${timestamp}"
        ln -sf "${history_dir}/root.bash_history.${timestamp}" "${history_dir}/root.bash_history.latest"
    fi
    
    # Divix history
    if id "divix" &>/dev/null; then
        local divix_home=$(eval echo ~divix)
        if [[ -f "${divix_home}/.bash_history" ]]; then
            cp "${divix_home}/.bash_history" "${history_dir}/divix.bash_history.${timestamp}"
            ln -sf "${history_dir}/divix.bash_history.${timestamp}" "${history_dir}/divix.bash_history.latest"
        fi
    fi
    
    # Other users
    while IFS=: read -r username _ uid _ _ home _; do
        if [[ $uid -ge 1000 && -f "$home/.bash_history" ]]; then
            if [[ "$username" != "divix" && "$username" != "nobody" ]]; then
                cp "$home/.bash_history" "${history_dir}/${username}.bash_history.${timestamp}"
                ln -sf "${history_dir}/${username}.bash_history.${timestamp}" "${history_dir}/${username}.bash_history.latest"
            fi
        fi
    done < /etc/passwd
    
    log_success "History files backed up with timestamp: ${timestamp}"
}

# Capture all session/TTY histories
# This function monitors and preserves all active shell sessions across TTYs
capture_session_histories() {
    log_info "Setting up all session/TTY history tracking..."
    
    local history_dir="${MONITOR_BASE_DIR}/history"
    local sessions_file="${history_dir}/active_sessions.log"
    
    if [[ $TEST_MODE -eq 1 ]]; then
        log_warning "[TEST MODE] Would create session history capture script at: ${MONITOR_BASE_DIR}/bin/capture_tty_history.sh"
        return
    fi
    
    # Create a monitoring script that captures multi-session history
    local session_monitor_script="${MONITOR_BASE_DIR}/bin/capture_tty_history.sh"
    mkdir -p "${MONITOR_BASE_DIR}/bin"
    
    cat > "$session_monitor_script" <<'EOFSCRIPT'
#!/bin/bash
# Capture all active TTY/session histories
# This script runs periodically to ensure all session histories are captured

HISTORY_DIR="${1:-.}"
SESSIONS_FILE="${HISTORY_DIR}/active_sessions.log"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Function to capture session history from a process
capture_session_history() {
    local pid=$1
    local user=$2
    local tty=$3
    local cmd=$4
    
    # Try to read the history for this process
    if [[ -r "/proc/$pid/environ" ]]; then
        # Extract HISTFILE environment variable if set
        local histfile
        histfile=$(grep -ao 'HISTFILE=[^:]*' "/proc/$pid/environ" 2>/dev/null | head -1 | cut -d= -f2)
        
        if [[ -n "$histfile" && -f "$histfile" ]]; then
            # Copy this history file with unique identifier
            local safe_name="${user}_${tty//\//_}.history.${TIMESTAMP}"
            cp "$histfile" "${HISTORY_DIR}/${safe_name}" 2>/dev/null
            echo "$pid:$user:$tty:$histfile:${HISTORY_DIR}/${safe_name}" >> "$SESSIONS_FILE"
        fi
    fi
}

# Log current active sessions
echo "=== Session Capture: $(date) ===" >> "$SESSIONS_FILE"

# Get all shell processes with their TTY and user
ps aux | grep -E '(bash|sh|zsh|fish)' | grep -v grep | while read -r user pid rest; do
    # Get the TTY for this process
    tty=$(ps -o tty= -p "$pid" 2>/dev/null || echo "notty")
    
    # Capture history if available
    capture_session_history "$pid" "$user" "$tty" "$rest"
done

echo "=== End capture ===" >> "$SESSIONS_FILE"
EOFSCRIPT
    
    chmod +x "$session_monitor_script"
    log_success "Session history capture script created: ${session_monitor_script}"
    
    # Create a cron job to regularly capture session histories
    local cron_cmd="/bin/bash ${session_monitor_script} ${history_dir} >> /var/log/divtools/monitor/session_capture.log 2>&1"
    
    log_info "To enable periodic session history capture, add to crontab:"
    log_info "  */5 * * * * ${cron_cmd}"
    log_info "  (Runs every 5 minutes to capture multi-session histories)"
}


# Cleanup and rotate old log files based on age and size
cleanup_old_logs() {
    log_info "Cleaning up old log files..."
    
    if [[ $TEST_MODE -eq 1 ]]; then
        log_warning "[TEST MODE] Would clean logs older than ${DT_LOG_MAXDAYS} days or if dir exceeds ${DT_LOG_MAXSIZE}"
        return
    fi
    
    local history_dir="${MONITOR_BASE_DIR}/history"
    local max_days="${DT_LOG_MAXDAYS:-30}"
    local max_size="${DT_LOG_MAXSIZE:-100m}"
    
    if [[ ! -d "$history_dir" ]]; then
        log_debug "History directory doesn't exist yet: ${history_dir}"
        return
    fi
    
    # Convert max_size to bytes for comparison
    local max_size_bytes
    if [[ "$max_size" =~ ^([0-9]+)([kmg])$ ]]; then
        local num="${BASH_REMATCH[1]}"
        local unit="${BASH_REMATCH[2]}"
        case "$unit" in
            k) max_size_bytes=$((num * 1024)) ;;
            m) max_size_bytes=$((num * 1024 * 1024)) ;;
            g) max_size_bytes=$((num * 1024 * 1024 * 1024)) ;;
        esac
    else
        # If no unit specified, assume bytes
        max_size_bytes="$max_size"
    fi
    
    log_debug "Max size: ${DT_LOG_MAXSIZE} (${max_size_bytes} bytes), Max age: ${max_days} days"
    
    # Step 1: Remove files older than DT_LOG_MAXDAYS
    log_debug "Removing files older than ${max_days} days from ${history_dir}"
    local removed_by_age=0
    while IFS= read -r file; do
        if [[ -n "$file" ]]; then
            rm -f "$file"
            ((removed_by_age++))
            log_debug "Removed old file: $file"
        fi
    done < <(find "$history_dir" -maxdepth 1 -type f -name "*.history.*" -mtime "+${max_days}" 2>/dev/null)
    
    # Also remove old .bash_history backups (except .latest symlinks)
    while IFS= read -r file; do
        if [[ -n "$file" && ! "$file" =~ \.latest$ ]]; then
            rm -f "$file"
            ((removed_by_age++))
            log_debug "Removed old backup: $file"
        fi
    done < <(find "$history_dir" -maxdepth 1 -type f -name "*.bash_history.*" -mtime "+${max_days}" 2>/dev/null)
    
    if [[ $removed_by_age -gt 0 ]]; then
        log_info "Removed ${removed_by_age} file(s) older than ${max_days} days"
    fi
    
    # Step 2: Check total directory size and remove oldest files if needed
    local current_size
    current_size=$(du -sb "$history_dir" 2>/dev/null | awk '{print $1}')
    
    log_debug "Current history directory size: $current_size bytes (limit: $max_size_bytes bytes)"
    
    if [[ $current_size -gt $max_size_bytes ]]; then
        log_warning "History directory exceeds size limit (${current_size} > ${max_size_bytes})"
        log_info "Removing oldest files to meet size limit..."
        
        local removed_by_size=0
        # Find all files, sort by modification time (oldest first), and remove until under limit
        while IFS= read -r file; do
            if [[ -n "$file" && -f "$file" && ! "$file" =~ \.latest$ ]]; then
                rm -f "$file"
                ((removed_by_size++))
                current_size=$(du -sb "$history_dir" 2>/dev/null | awk '{print $1}')
                log_debug "Removed: $file (new size: ${current_size} bytes)"
                
                # Check if we're under the limit now
                if [[ $current_size -le $max_size_bytes ]]; then
                    log_info "Directory now under size limit: $current_size bytes"
                    break
                fi
            fi
        done < <(find "$history_dir" -maxdepth 1 -type f ! -name "*.latest" -printf '%T@ %p\n' 2>/dev/null | sort -n | awk '{print $2}')
        
        if [[ $removed_by_size -gt 0 ]]; then
            log_info "Removed ${removed_by_size} file(s) to meet size limit"
        fi
    else
        log_debug "History directory is within size limits"
    fi
    
    log_success "Log cleanup completed"
}

# Calculate checksums for docker config files
calculate_docker_checksums() {
    log_info "Calculating checksums for docker configuration files..."
    log_debug "  Base directory: /home/divix/divtools/docker"
    log_debug "  Output file: ${MONITOR_BASE_DIR}/checksums/docker_configs.sha256"
    
    if [[ $TEST_MODE -eq 1 ]]; then
        log_warning "[TEST MODE] Would calculate checksums for docker config files"
        log_debug "[TEST MODE] Would scan: /home/divix/divtools/docker for *.yml files"
        log_debug "[TEST MODE] Would scan: /home/divix/divtools/docker/config for all files"
        return
    fi
    
    local docker_base="/home/divix/divtools/docker"
    local checksum_file="${MONITOR_BASE_DIR}/checksums/docker_configs.sha256"
    
    if [[ ! -d "$docker_base" ]]; then
        log_warning "Docker config directory not found: ${docker_base}"
        return
    fi
    
    log_debug "  Scanning for .yml files in ${docker_base}..."
    # Calculate checksums for all docker-compose files
    local yml_count
    yml_count=$(find "$docker_base" -name "*.yml" -type f | wc -l)
    log_debug "  Found ${yml_count} .yml files"
    find "$docker_base" -name "*.yml" -type f -exec sha256sum {} \; > "${checksum_file}.tmp"
    
    # Also check other docker config directories if they exist
    if [[ -d "${docker_base}/config" ]]; then
        log_debug "  Scanning for files in ${docker_base}/config..."
        local config_count
        config_count=$(find "${docker_base}/config" -type f | wc -l)
        log_debug "  Found ${config_count} files in config directory"
        find "${docker_base}/config" -type f -exec sha256sum {} \; >> "${checksum_file}.tmp"
    fi
    
    local total_checksums
    total_checksums=$(wc -l < "${checksum_file}.tmp")
    log_debug "  Total checksums calculated: ${total_checksums}"
    
    mv "${checksum_file}.tmp" "${checksum_file}"
    chmod 644 "${checksum_file}"
    
    log_success "Docker checksums saved to ${checksum_file}"
}

# Review divtools git repository status (optional, host-level configuration)
# Captures comprehensive git information at time of monitoring run
# Creates timestamped files for historical tracking and allows rotation of old snapshots
review_divtools_git() {
    log_info "Reviewing divtools git repository status..."
    log_debug "  DT_LOG_DIVTOOLS enabled - capturing full git snapshot"
    
    if [[ $TEST_MODE -eq 1 ]]; then
        log_warning "[TEST MODE] Would collect comprehensive git status from /opt/divtools"
        log_debug "[TEST MODE] Would create timestamped git status files in ${MONITOR_BASE_DIR}/git/"
        return
    fi
    
    local divtools_base="/opt/divtools"
    local git_status_dir="${MONITOR_BASE_DIR}/git"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local iso_timestamp
    iso_timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    # Create git status directory if it doesn't exist
    if [[ ! -d "$git_status_dir" ]]; then
        log_debug "  Creating git status directory: ${git_status_dir}"
        mkdir -p "$git_status_dir"
        chmod 755 "$git_status_dir"
    fi
    
    if [[ ! -d "$divtools_base" ]]; then
        log_warning "divtools directory not found: ${divtools_base}"
        return 1
    fi
    
    if [[ ! -d "${divtools_base}/.git" ]]; then
        log_warning "divtools is not a git repository: ${divtools_base}"
        return 1
    fi
    
    log_info "Capturing comprehensive git status from ${divtools_base}..."
    log_debug "  Timestamp: ${timestamp}"
    
    # Create files for this snapshot
    local git_status_file="${git_status_dir}/git_status_${timestamp}.json"
    local git_diff_file="${git_status_dir}/git_diff_${timestamp}.patch"
    local git_log_file="${git_status_dir}/git_log_${timestamp}.txt"
    local git_summary_file="${git_status_dir}/LATEST.json"
    
    # === Collect git status JSON ===
    local current_branch remote_branch current_commit last_commit_date last_commit_author last_commit_message
    current_branch=$(cd "$divtools_base" && git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    current_commit=$(cd "$divtools_base" && git rev-parse HEAD 2>/dev/null || echo "unknown")
    remote_branch=$(cd "$divtools_base" && git rev-parse --abbrev-ref @{u} 2>/dev/null || echo "none")
    last_commit_date=$(cd "$divtools_base" && git log -1 --format="%aI" 2>/dev/null || echo "unknown")
    last_commit_author=$(cd "$divtools_base" && git log -1 --format="%an" 2>/dev/null || echo "unknown")
    last_commit_message=$(cd "$divtools_base" && git log -1 --format="%s" 2>/dev/null || echo "unknown")
    
    # Count various git states
    local uncommitted_count unpushed_count
    uncommitted_count=$(cd "$divtools_base" && git status --short 2>/dev/null | wc -l)
    unpushed_count=0
    if [[ "$remote_branch" != "none" ]]; then
        unpushed_count=$(cd "$divtools_base" && git rev-list --count @{u}..HEAD 2>/dev/null || echo "0")
    fi
    
    # Get modified and untracked files
    local modified_files=() untracked_files=()
    while IFS= read -r file; do
        if [[ -n "$file" ]]; then
            if cd "$divtools_base" && git ls-files --others --exclude-standard | grep -q "^$file$"; then
                untracked_files+=("$file")
            else
                modified_files+=("$file")
            fi
        fi
    done < <(cd "$divtools_base" && git status --porcelain 2>/dev/null | awk '{print $NF}')
    
    # Get remote URL
    local remote_url
    remote_url=$(cd "$divtools_base" && git config --get remote.origin.url 2>/dev/null || echo "unknown")
    
    # Get branch count
    local branch_count
    branch_count=$(cd "$divtools_base" && git branch --list 2>/dev/null | wc -l)
    
    # Get tag count
    local tag_count
    tag_count=$(cd "$divtools_base" && git tag --list 2>/dev/null | wc -l)
    
    log_debug "  Branch: ${current_branch}, Commit: ${current_commit:0:7}"
    log_debug "  Uncommitted: ${uncommitted_count}, Unpushed: ${unpushed_count}"
    log_debug "  Modified files: ${#modified_files[@]}, Untracked: ${#untracked_files[@]}"
    
    # === Write JSON status file ===
    cat > "$git_status_file" <<EOF
{
  "timestamp": "$iso_timestamp",
  "snapshot_time": "$timestamp",
  "divtools_path": "$(cd "$divtools_base" && realpath .)",
  "hostname": "$(hostname)",
  "git_status": {
    "current_branch": "$current_branch",
    "current_commit": "$current_commit",
    "remote_tracking": "$remote_branch",
    "remote_url": "$remote_url",
    "branch_count": $branch_count,
    "tag_count": $tag_count,
    "last_commit": {
      "timestamp": "$last_commit_date",
      "author": "$last_commit_author",
      "message": "$last_commit_message"
    }
  },
  "changes": {
    "uncommitted_changes": $uncommitted_count,
    "unpushed_commits": $unpushed_count,
    "modified_files_count": ${#modified_files[@]},
    "untracked_files_count": ${#untracked_files[@]}
  },
  "modified_files": [
EOF
    
    local first=true
    for file in "${modified_files[@]}"; do
        [[ "$first" != true ]] && echo "," >> "$git_status_file"
        echo -n "    \"$file\"" >> "$git_status_file"
        first=false
    done
    
    cat >> "$git_status_file" <<EOF
  ],
  "untracked_files": [
EOF
    
    first=true
    for file in "${untracked_files[@]}"; do
        [[ "$first" != true ]] && echo "," >> "$git_status_file"
        echo -n "    \"$file\"" >> "$git_status_file"
        first=false
    done
    
    cat >> "$git_status_file" <<'EOF'
  ],
  "notes": "Comprehensive git snapshot captured for monitoring. Includes status, changes, modified/untracked files. Use git diff and log files for detailed change history."
}
EOF
    
    chmod 644 "$git_status_file"
    log_debug "  Git status JSON saved: git_status_${timestamp}.json"
    
    # === Capture git diff (all uncommitted changes) ===
    log_debug "  Capturing git diff..."
    if cd "$divtools_base" && git diff HEAD > "$git_diff_file" 2>/dev/null; then
        local diff_size
        diff_size=$(stat -c%s "$git_diff_file" 2>/dev/null || echo "unknown")
        log_debug "    Diff file size: ${diff_size} bytes"
        chmod 644 "$git_diff_file"
    else
        log_debug "    No uncommitted changes or diff failed"
        rm -f "$git_diff_file"
    fi
    
    # === Capture git log (last 50 commits) ===
    log_debug "  Capturing git log (last 50 commits)..."
    if cd "$divtools_base" && git log --oneline -50 > "$git_log_file" 2>/dev/null; then
        local log_lines
        log_lines=$(wc -l < "$git_log_file")
        log_debug "    Log entries captured: ${log_lines}"
        chmod 644 "$git_log_file"
    else
        log_debug "    Failed to capture git log"
        rm -f "$git_log_file"
    fi
    
    # === Update LATEST symlink ===
    local latest_json_link="${git_status_dir}/LATEST.json"
    local latest_diff_link="${git_status_dir}/LATEST.patch"
    local latest_log_link="${git_status_dir}/LATEST_log.txt"
    
    ln -sf "git_status_${timestamp}.json" "$latest_json_link"
    [[ -f "$git_diff_file" ]] && ln -sf "git_diff_${timestamp}.patch" "$latest_diff_link"
    [[ -f "$git_log_file" ]] && ln -sf "git_log_${timestamp}.txt" "$latest_log_link"
    log_debug "  Updated LATEST symlinks for quick access"
    
    # === Cleanup old git snapshots (keep last 30, or 7 days worth) ===
    log_debug "  Cleaning up old git snapshots..."
    local file_count
    file_count=$(ls -1 "$git_status_dir"/git_status_*.json 2>/dev/null | wc -l)
    
    if [[ $file_count -gt 30 ]]; then
        log_debug "    Found ${file_count} snapshot files (max 30), removing oldest..."
        ls -1 "$git_status_dir"/git_status_*.json 2>/dev/null | head -n $((file_count - 30)) | while read -r old_file; do
            log_debug "      Removing: $(basename "$old_file")"
            rm -f "$old_file"
            # Also remove associated diff and log files
            local base_name
            base_name=$(basename "$old_file" .json)
            rm -f "$git_status_dir/${base_name}.patch"
            rm -f "$git_status_dir/${base_name}.txt"
        done
    fi
    
    log_success "divtools git snapshot saved: git_status_${timestamp}.json"
    log_info "  Full snapshot: ${git_status_file}"
    log_info "  Diff patch: ${git_diff_file}"
    log_info "  Commit log: ${git_log_file}"
    log_info "  Latest links: LATEST.json, LATEST.patch, LATEST_log.txt"
}


# Generate manifest file for n8n monitoring
generate_manifest() {
    log_info "Generating monitoring manifest..."
    log_debug "  Output file: ${MANIFEST_FILE}"
    log_debug "  History directory: ${MONITOR_BASE_DIR}/history"
    log_debug "  Docker base path: /home/divix/divtools/docker"
    log_debug "  DT_LOG_DIVTOOLS setting: ${DT_LOG_DIVTOOLS}"
    
    if [[ $TEST_MODE -eq 1 ]]; then
        log_warning "[TEST MODE] Would generate monitoring manifest at: ${MANIFEST_FILE}"
        log_debug "[TEST MODE] Would scan history files in ${MONITOR_BASE_DIR}/history"
        return
    fi
    
    local manifest_tmp="${MANIFEST_FILE}.tmp"
    log_debug "  Creating temporary file: ${manifest_tmp}"
    
    cat > "$manifest_tmp" <<EOF
{
  "generated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "hostname": "$(hostname)",
  "monitoring": {
    "bash_history": {
      "enabled": true,
      "check_frequency": "daily",
      "files": [
EOF
    
    # Add history files
    local first=true
    local history_file_count=0
    for histfile in "${MONITOR_BASE_DIR}"/history/*.latest; do
        if [[ -f "$histfile" ]]; then
            history_file_count=$((history_file_count + 1))
            [[ "$first" != true ]] && echo "," >> "$manifest_tmp"
            echo -n "        {\"path\": \"$histfile\", \"user\": \"$(basename "$histfile" .bash_history.latest)\"}" >> "$manifest_tmp"
            first=false
            log_debug "    Added history file: $histfile"
        fi
    done
    log_debug "  Total history files: ${history_file_count}"
    
    cat >> "$manifest_tmp" <<EOF

      ],
      "notes": "History files are updated in real-time via PROMPT_COMMAND. Check daily for new commands."
    },
    "apt_packages": {
      "enabled": true,
      "check_frequency": "daily",
      "files": [
        {"path": "/var/log/apt/history.log", "type": "append-only"},
        {"path": "/var/log/dpkg.log", "type": "append-only"}
      ],
      "notes": "APT logs are rotated monthly. Check for new package installations/removals."
    },
    "docker_configs": {
      "enabled": true,
      "check_frequency": "daily",
      "checksum_file": "${MONITOR_BASE_DIR}/checksums/docker_configs.sha256",
      "base_path": "/home/divix/divtools/docker",
      "notes": "Monitor docker-compose files for changes. Compare checksums to detect modifications."
    },
    "system_logs": {
      "enabled": true,
      "check_frequency": "daily",
      "files": [
        {"path": "/var/log/syslog", "type": "rotated"},
        {"path": "/var/log/auth.log", "type": "rotated"}
      ],
      "notes": "System logs are rotated daily. Parse for critical events."
    },
    "session_histories": {
      "enabled": true,
      "check_frequency": "daily",
      "directory": "${MONITOR_BASE_DIR}/history",
      "session_monitor": "${MONITOR_BASE_DIR}/bin/capture_tty_history.sh",
      "notes": "All user sessions and TTYs are captured. Multiple concurrent sessions are tracked separately."
    },
    "divtools_git": {
      "enabled": $([ "${DT_LOG_DIVTOOLS}" == "TRUE" ] && echo "true" || echo "false"),
      "check_frequency": "daily",
      "status_file": "${MONITOR_BASE_DIR}/divtools_git_status.json",
      "base_path": "/opt/divtools",
      "notes": "Tracks git changes in divtools repository when DT_LOG_DIVTOOLS=TRUE. Useful for detecting sync issues across multiple hosts."
    }
  },
  "recommendations": {
    "monitoring_frequency": "Daily checks are sufficient for most changes",
    "critical_paths": [
      "${MONITOR_BASE_DIR}",
      "/var/log/apt",
      "/home/divix/divtools/docker"
    ],
    "persistence": "All monitored files persist across reboots. History files are safe with PROMPT_COMMAND configuration."
  }
}
EOF
    
    log_debug "  Moving temporary manifest to: ${MANIFEST_FILE}"
    mv "$manifest_tmp" "$MANIFEST_FILE"
    chmod 644 "$MANIFEST_FILE"
    
    local manifest_size
    manifest_size=$(stat -f%z "$MANIFEST_FILE" 2>/dev/null || stat -c%s "$MANIFEST_FILE" 2>/dev/null || echo "unknown")
    log_debug "  Manifest file size: ${manifest_size} bytes"

    log_success "Monitoring manifest generated: ${MANIFEST_FILE}"
}

# Verify configuration
verify_configuration() {
    log_info "Verifying monitoring configuration..."
    
    local errors=0
    
    # Check directories
    if [[ ! -d "$MONITOR_BASE_DIR" ]]; then
        log_error "Monitor base directory missing: ${MONITOR_BASE_DIR}"
        ((errors++))
    else
        log_success "Monitor base directory exists"
    fi
    
    # Check bash history configuration
    if grep -q "divtools host_change_log.sh" /root/.bashrc; then
        log_success "Root bash history configured"
    else
        log_warning "Root bash history not configured"
        ((errors++))
    fi
    
    # Check history files
    local history_count=$(find "${MONITOR_BASE_DIR}/history" -name "*.latest" 2>/dev/null | wc -l)
    if [[ $history_count -gt 0 ]]; then
        log_success "Found ${history_count} history file(s) being monitored"
    else
        log_warning "No history files found in monitoring directory"
    fi
    
    # Check manifest
    if [[ -f "$MANIFEST_FILE" ]]; then
        log_success "Monitoring manifest exists"
    else
        log_warning "Monitoring manifest not found"
        ((errors++))
    fi
    
    # Check log files
    if [[ -f /var/log/apt/history.log ]]; then
        log_success "APT history log exists"
    else
        log_warning "APT history log not found"
    fi
    
    # Check docker configs
    if [[ -d /home/divix/divtools/docker ]]; then
        local docker_yml_count=$(find /home/divix/divtools/docker -name "*.yml" -type f | wc -l)
        log_success "Found ${docker_yml_count} docker-compose file(s)"
    else
        log_warning "Docker config directory not found"
    fi
    
    # Check log directory size
    if [[ -d "${MONITOR_BASE_DIR}/history" ]]; then
        local history_size
        history_size=$(du -sh "${MONITOR_BASE_DIR}/history" 2>/dev/null | awk '{print $1}')
        log_info "History directory size: ${history_size}"
    fi
    
    # Run cleanup to ensure logs are within limits
    cleanup_old_logs
    
    if [[ $errors -eq 0 ]]; then
        log_success "All verifications passed!"
    else
        log_warning "Verification completed with ${errors} issue(s)"
    fi
    
    return $errors
}

# Show current status
show_status() {
    log_info "Current monitoring status for $(hostname):"
    echo
    
    # History files status
    echo "=== Bash History Monitoring ==="
    if [[ -d "${MONITOR_BASE_DIR}/history" ]]; then
        for histfile in "${MONITOR_BASE_DIR}"/history/*.latest; do
            if [[ -f "$histfile" ]]; then
                local user=$(basename "$histfile" .bash_history.latest)
                local line_count=$(wc -l < "$histfile" 2>/dev/null || echo "0")
                local last_modified=$(stat -c %y "$histfile" 2>/dev/null | cut -d. -f1)
                printf "  %-10s: %5d commands (last: %s)\n" "$user" "$line_count" "$last_modified"
            fi
        done
    else
        echo "  Not configured"
    fi
    echo
    
    # APT status
    echo "=== APT Package Log Status ==="
    if [[ -f /var/log/apt/history.log ]]; then
        local last_apt=$(grep -E "^Start-Date:" /var/log/apt/history.log | tail -1 | cut -d: -f2-)
        echo "  Last APT action: ${last_apt:-Never}"
        local total_installs=$(grep -c "^Commandline: apt" /var/log/apt/history.log 2>/dev/null || echo "0")
        echo "  Total logged actions: ${total_installs}"
    else
        echo "  No APT history log found"
    fi
    echo
    
    # Docker status
    echo "=== Docker Configuration Status ==="
    if [[ -f "${MONITOR_BASE_DIR}/checksums/docker_configs.sha256" ]]; then
        local checksum_count=$(wc -l < "${MONITOR_BASE_DIR}/checksums/docker_configs.sha256")
        local checksum_date=$(stat -c %y "${MONITOR_BASE_DIR}/checksums/docker_configs.sha256" 2>/dev/null | cut -d. -f1)
        echo "  Monitoring ${checksum_count} docker config file(s)"
        echo "  Last checksum: ${checksum_date}"
    else
        echo "  Not configured"
    fi
    echo
    
    # Manifest status
    echo "=== Monitoring Manifest ==="
    if [[ -f "$MANIFEST_FILE" ]]; then
        local manifest_date=$(jq -r .generated "$MANIFEST_FILE" 2>/dev/null || echo "unknown")
        echo "  Generated: ${manifest_date}"
        echo "  Location: ${MANIFEST_FILE}"
    else
        echo "  Not generated yet"
    fi
    echo
    
    # divtools git status (if available)
    echo "=== divtools Git Status ==="
    if [[ "${DT_LOG_DIVTOOLS}" == "TRUE" && -f "${MONITOR_BASE_DIR}/divtools_git_status.json" ]]; then
        local git_status_file="${MONITOR_BASE_DIR}/divtools_git_status.json"
        local branch=$(jq -r '.git_status.current_branch' "$git_status_file" 2>/dev/null || echo "unknown")
        local commit=$(jq -r '.git_status.current_commit' "$git_status_file" 2>/dev/null | cut -c1-7)
        local uncommitted=$(jq -r '.changes.uncommitted_changes' "$git_status_file" 2>/dev/null || echo "0")
        local unpushed=$(jq -r '.changes.unpushed_commits' "$git_status_file" 2>/dev/null || echo "0")
        
        echo "  Branch: ${branch}"
        echo "  Current commit: ${commit}"
        echo "  Uncommitted changes: ${uncommitted}"
        echo "  Unpushed commits: ${unpushed}"
        echo "  Status file: ${git_status_file}"
    elif [[ "${DT_LOG_DIVTOOLS}" == "TRUE" ]]; then
        echo "  Enabled but not yet logged (run setup or status will update on next run)"
    else
        echo "  Not enabled (set DT_LOG_DIVTOOLS=TRUE to enable)"
    fi
    echo
}

# Setup cron job for periodic updates (optional)
setup_cron() {
    log_info "Setting up cron job for periodic verification..."
    
    local cron_cmd="/home/divix/divtools/scripts/util/host_change_log.sh verify >> /var/log/divtools/monitor/verify.log 2>&1"
    local cron_entry="0 2 * * * ${cron_cmd}"
    
    # Check if cron entry already exists
    if crontab -l 2>/dev/null | grep -q "host_change_log.sh verify"; then
        log_info "Cron job already configured"
    else
        (crontab -l 2>/dev/null; echo "# Divtools host change monitoring verification"; echo "$cron_entry") | crontab -
        log_success "Cron job added (runs daily at 2 AM)"
    fi
}

# Main setup function
do_setup() {
    log_info "Starting host change monitoring setup..."
    [[ $TEST_MODE -eq 1 ]] && log_warning "[TEST MODE] No permanent changes will be made"
    
    # If -debug is set, automatically increase DT_VERBOSE
    if [[ $DEBUG_MODE -eq 1 ]]; then
        DT_VERBOSE=3
        log_debug "Debug mode enabled - DT_VERBOSE set to 3"
    fi
    
    # Show environment configuration
    log_info "Environment configuration:"
    log_debug "  Hostname: $(hostname)"
    log_debug "  Script: $0"
    log_debug "  Working directory: $(pwd)"
    log_info "  Loaded env files: ${ENV_FILES_LOADED}"
    log_debug "  Env files sourced from:"
    log_debug "    Primary: /opt/divtools/docker/sites/s00-shared/.env.s00-shared"
    [[ -n "${SITE_NAME:-}" ]] && log_debug "    Site: /opt/divtools/docker/sites/${SITE_NAME}/.env.${SITE_NAME}"
    [[ -n "${SITE_NAME:-}" ]] && log_debug "    Host: /opt/divtools/docker/sites/${SITE_NAME}/$(hostname)/.env.$(hostname)"
    log_info "  DT_LOG_DIR=${DT_LOG_DIR}"
    log_debug "    (Effective: ${MONITOR_BASE_DIR})"
    log_info "  DT_LOG_MAXSIZE=${DT_LOG_MAXSIZE}"
    log_info "  DT_LOG_MAXDAYS=${DT_LOG_MAXDAYS}"
    log_info "  DT_LOG_DIVTOOLS=${DT_LOG_DIVTOOLS}"
    log_debug "    (Git logging: $([ "$DT_LOG_DIVTOOLS" == "TRUE" ] || [ "$DT_LOG_DIVTOOLS" == "1" ] || [ "$DT_LOG_DIVTOOLS" == "true" ] && echo 'ENABLED' || echo 'DISABLED'))"
    log_debug "  SITE_NAME=${SITE_NAME:-not set}"
    log_debug "  DT_VERBOSE=${DT_VERBOSE}"
    log_debug "  TEST_MODE=${TEST_MODE}"
    log_debug "  DEBUG_MODE=${DEBUG_MODE}"
    echo
    
    if [[ $TEST_MODE -eq 0 ]]; then
        check_root
        # Ensure log directory exists early
        log_debug "Ensuring log directory exists..."
        ensure_log_dir
        log_debug "Log directory verified/created"
    else
        log_warning "[TEST MODE] Skipping root check"
    fi
    
    log_debug "Calling: setup_directories()"
    setup_directories
    
    log_debug "Calling: configure_bash_history()"
    configure_bash_history
    
    log_debug "Calling: capture_session_histories()"
    capture_session_histories
    
    log_debug "Calling: setup_log_links()"
    setup_log_links
    
    log_debug "Calling: copy_rotated_logs()"
    copy_rotated_logs
    
    log_debug "Calling: backup_current_histories()"
    backup_current_histories
    
    log_debug "Calling: cleanup_old_logs()"
    cleanup_old_logs
    
    log_debug "Calling: calculate_docker_checksums()"
    calculate_docker_checksums
    
    # Review divtools if enabled at host level
    if [[ "${DT_LOG_DIVTOOLS}" == "TRUE" ]] || [[ "${DT_LOG_DIVTOOLS}" == "1" ]] || [[ "${DT_LOG_DIVTOOLS}" == "true" ]]; then
        log_debug "DT_LOG_DIVTOOLS is enabled, calling: review_divtools_git()"
        review_divtools_git
    else
        log_debug "divtools git logging not enabled (DT_LOG_DIVTOOLS=${DT_LOG_DIVTOOLS})"
        log_info "divtools git logging not enabled (set DT_LOG_DIVTOOLS=TRUE or 1 to enable)"
    fi
    
    log_debug "Calling: generate_manifest()"
    generate_manifest
    
    echo
    if [[ $TEST_MODE -eq 1 ]]; then
        log_warning "[TEST MODE] Setup simulation completed - no changes were made"
    else
        log_success "Setup completed successfully!"
    fi
    echo
    echo "Configuration Summary:"
    echo "  Log Directory:  ${DT_LOG_DIR}"
    echo "  Max Log Size:   ${DT_LOG_MAXSIZE}"
    echo "  Max Log Days:   ${DT_LOG_MAXDAYS}"
    echo "  divtools Log:   ${DT_LOG_DIVTOOLS}"
    [[ $TEST_MODE -eq 1 ]] && echo "  Mode:           TEST (no changes made)"
    [[ $DEBUG_MODE -eq 1 ]] && echo "  Mode:           DEBUG (verbose output)"
    echo
    echo "Next steps:"
    echo "  1. Review the manifest file: ${MANIFEST_FILE}"
    echo "  2. Configure n8n to monitor the files listed in the manifest"
    echo "  3. Recommended check frequency: Daily"
    echo "  4. Run '$0 status' to see current monitoring status"
    echo "  5. Run '$0 verify' periodically to ensure configuration is maintained"
    echo
    echo "Optional: Add to cron with: $0 setup-cron"
}

# Usage information
usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [FLAGS] <command>

Global Flags:
  -test, --test    Run in test mode (shows what would be done without making changes)
  -debug, --debug  Enable debug mode (shows detailed execution information)

Commands:
  setup        Perform initial setup and configuration
  verify       Verify that monitoring configuration is still valid
  cleanup      Clean up old log files based on DT_LOG_MAXDAYS and DT_LOG_MAXSIZE
  manifest     Regenerate the monitoring manifest file
  status       Show current monitoring status
  setup-cron   Add verification to crontab (runs daily)
  help         Show this help message

Description:
  This script configures a host to preserve and organize files for
  change monitoring. It ensures bash history is properly saved,
  creates monitoring directories, and generates a manifest file
  for external monitoring tools like n8n.

  Features:
    • Bash history with Starship prompt compatibility
    • Multi-session/TTY history tracking
    • APT package change logging
    • Docker configuration checksums
    • System log aggregation
    • Optional divtools git status logging
    • Environment variable based configuration

Configuration (from environment variables):
  DT_LOG_DIR         - Log directory (default: /var/log/divtools/monitor)
  DT_LOG_MAXSIZE     - Max log size (default: 100m)
  DT_LOG_MAXDAYS     - Max days to retain logs (default: 30)
  DT_LOG_DIVTOOLS    - Enable divtools git logging TRUE/FALSE (default: FALSE)

  These are sourced from: /home/divix/docker/sites/s00-shared/.env.s00-shared

Examples:
  $SCRIPT_NAME setup                                   # Run once on new host
  $SCRIPT_NAME verify                                  # Check configuration periodically
  $SCRIPT_NAME status                                  # See what's being monitored
  $SCRIPT_NAME -test setup                             # Test mode - see what would be done
  $SCRIPT_NAME -debug setup                            # Debug mode - detailed output
  $SCRIPT_NAME -test -debug setup                      # Test mode with debug output

  # With environment variables:
  DT_LOG_DIVTOOLS=TRUE DT_LOG_DIR=/opt/dtlogs $SCRIPT_NAME setup

  # Test divtools git logging before enabling:
  $SCRIPT_NAME -test -debug setup
  DT_LOG_DIVTOOLS=TRUE $SCRIPT_NAME -test setup

Test Mode:
  Use -test flag to see what changes would be made without actually making them.
  Useful for dry-runs, testing, and verification.
  
  Example: $SCRIPT_NAME -test setup

Debug Mode:
  Use -debug flag to see detailed execution information.
  Useful for troubleshooting and understanding script behavior.
  
  Example: $SCRIPT_NAME -debug verify

Log Cleanup:
  The script automatically removes log files based on:
    • DT_LOG_MAXDAYS: Remove files older than this many days (default: 30)
    • DT_LOG_MAXSIZE: If directory exceeds this size, remove oldest files (default: 100m)
  
  Cleanup runs automatically during setup and verify commands.
  You can also run cleanup manually: $SCRIPT_NAME cleanup
  
  Supported size formats: k, m, g (e.g., 100m = 100 megabytes)

Monitoring Locations:
  Base directory:      ${MONITOR_BASE_DIR}
  Manifest file:       ${MANIFEST_FILE}
  Bash histories:      ${MONITOR_BASE_DIR}/history/
  Session histories:   ${MONITOR_BASE_DIR}/history/ (TTY-specific)
  Docker checksums:    ${MONITOR_BASE_DIR}/checksums/
  divtools git status: ${MONITOR_BASE_DIR}/divtools_git_status.json (if enabled)

Starship Compatibility:
  This script is compatible with Starship prompt. Bash history is
  configured to persist via PROMPT_COMMAND while working alongside
  Starship's prompt rendering.

Multi-Session History:
  Session history capture script is available at:
  ${MONITOR_BASE_DIR}/bin/capture_tty_history.sh

  Add to crontab to capture histories from all active sessions:
  */5 * * * * /bin/bash ${MONITOR_BASE_DIR}/bin/capture_tty_history.sh \\
    ${MONITOR_BASE_DIR}/history >> /var/log/divtools/monitor/session_capture.log 2>&1
  
EOF
}

# Main command dispatcher
main() {
    # Parse global flags first
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -test|--test)
                TEST_MODE=1
                log_warning "Running in TEST mode - no permanent changes will be made"
                shift
                ;;
            -debug|--debug)
                DEBUG_MODE=1
                DT_VERBOSE=3
                log_debug "Debug mode enabled - comprehensive tracing activated"
                shift
                ;;
            *)
                # Not a flag, break to process command
                break
                ;;
        esac
    done
    
    local command="${1:-help}"
    
    case "$command" in
        setup)
            do_setup
            ;;
        verify)
            check_root
            verify_configuration
            ;;
        cleanup)
            check_root
            cleanup_old_logs
            ;;
        manifest)
            check_root
            log_debug "Command: manifest - running calculate_docker_checksums, review_divtools_git, and generate_manifest"
            log_debug "  TEST_MODE=$TEST_MODE"
            log_debug "  DEBUG_MODE=$DEBUG_MODE"
            log_debug "  MONITOR_BASE_DIR=${MONITOR_BASE_DIR}"
            log_debug "Starting calculate_docker_checksums..."
            calculate_docker_checksums
            log_debug "calculate_docker_checksums completed"
            
            # Review divtools if enabled at host level
            if [[ "${DT_LOG_DIVTOOLS}" == "TRUE" ]] || [[ "${DT_LOG_DIVTOOLS}" == "1" ]] || [[ "${DT_LOG_DIVTOOLS}" == "true" ]]; then
                log_debug "Starting review_divtools_git..."
                review_divtools_git
                log_debug "review_divtools_git completed"
            else
                log_debug "divtools git logging not enabled (DT_LOG_DIVTOOLS=${DT_LOG_DIVTOOLS})"
            fi
            
            log_debug "Starting generate_manifest..."
            generate_manifest
            log_debug "generate_manifest completed"
            log_info "Manifest generation workflow complete"
            ;;
        status)
            show_status
            ;;
        setup-cron)
            check_root
            setup_cron
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            log_error "Unknown command: $command"
            echo
            usage
            exit 1
            ;;
    esac
}

main "$@"
