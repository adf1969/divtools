#!/bin/bash
# dthostmon_sync_config.sh
# Synchronizes dthostmon.yaml with divtools Docker folder structure
# Reads configuration from .env files and dthm-*.yaml files
# Last Updated: 11/18/2025 12:00:00 PM CST

# Source logging utilities from divtools scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Try to source divtools logging, fallback to basic logging
if [[ -f "/home/divix/divtools/scripts/util/logging.sh" ]]; then
    source "/home/divix/divtools/scripts/util/logging.sh"
else
    # Fallback logging functions
    log() {
        local level="$1"
        shift
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*"
    }
fi

# Default configuration
TEST_MODE=0
DEBUG_MODE=0
CONFIG_FILE="${PROJECT_ROOT}/config/dthostmon.yaml"
DOCKER_SITES_DIR="${DIVTOOLS:-/home/divix/divtools}/docker/sites"
DIVTOOLS_ROOT="${DIVTOOLS:-/home/divix/divtools}"
FORCE=0
YES=0
SITE_NAME=""
HOST_NAME=""

# Auto-detect current site and host from ~/.env file
detect_current_site_host() {
    local home_env="$HOME/.env"
    
    if [[ -f "$home_env" ]]; then
        # Source the file to get SITE_NAME
        local site_from_env
        site_from_env=$(grep -E "^export\s+SITE_NAME=" "$home_env" | cut -d'=' -f2 | tr -d '"' | tr -d "'")
        
        if [[ -n "$site_from_env" ]]; then
            SITE_NAME="$site_from_env"
            log "DEBUG" "Auto-detected SITE_NAME from ~/.env: $SITE_NAME"
        fi
    fi
    
    # Use current hostname if not specified
    if [[ -z "$HOST_NAME" ]]; then
        HOST_NAME=$(hostname)
        log "DEBUG" "Using current hostname: $HOST_NAME"
    fi
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -test|--test)
            TEST_MODE=1
            log "INFO" "Running in TEST mode - no changes will be written"
            shift
            ;;
        -debug|--debug)
            DEBUG_MODE=1
            log "DEBUG" "Debug mode enabled"
            shift
            ;;
        -config|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -sites-dir|--sites-dir)
            DOCKER_SITES_DIR="$2"
            shift 2
            ;;
        -h|--help)
            cat << EOF
Usage: $0 [OPTIONS]

Synchronize dthostmon.yaml with divtools Docker folder structure.

Options:
  -test, --test           Dry-run mode (show changes without applying)
  -debug, --debug         Enable debug output
  -config FILE            Path to dthostmon.yaml (default: ../config/dthostmon.yaml)
  -sites-dir DIR          Docker sites directory (default: \$DIVTOOLS/docker/sites)
    -yaml-ex, -yex FILE     Create an example dthm-site/host.yaml file; use '-' for stdout
    -yaml-exh               Create example dthm-<host>.yaml for hosts under sites dir (prompt on conflict)
    -env-ex, -eex FILE      Create an example .env.site/host file; use '-' for stdout
    -env-exh                Create example .env.<host> files for hosts under sites dir (append/prompt on conflict)
  -h, --help              Show this help message

Examples:
  $0 -test                            # Preview changes without modifying config
  $0 -debug                           # Run with verbose output
  $0 -config /path/to/config.yaml     # Use custom config file
  $0 -sites-dir /path/to/sites        # Use custom sites directory

Environment Variables (in .env files):
  Site-level (.env.SITENAME):
    DTHM_SITE_ENABLED              Site enabled (true/false)
    DTHM_SITE_TAGS                 Comma-delimited tags
    DTHM_SITE_REPORT_FREQUENCY     Report frequency (hourly/daily/weekly)
    DTHM_SITE_ALERT_RECIPIENTS     Comma-delimited email addresses

  Host-level (.env.HOSTNAME):
    DTHM_HOST_ENABLED              Host enabled (true/false)
    DTHM_HOST_HOSTNAME             IP address or hostname
    DTHM_HOST_PORT                 SSH port (default: 22)
    DTHM_HOST_USER                 SSH username
    DTHM_HOST_TAGS                 Comma-delimited tags
    DTHM_HOST_REPORT_FREQUENCY     Report frequency
    DTHM_HOST_ALERT_LEVEL          Alert level (INFO/WARN/ERROR)
    DTHM_HOST_CHECK_DOCKER         Check Docker (true/false)
    DTHM_HOST_CHECK_APT            Check APT packages (true/false)
    DTHM_HOST_LOG_PATHS            Comma-delimited log file paths

YAML Configuration Files (dthm-*.yaml):
  - dthm-site.yaml: Site-level configuration
  - dthm-host.yaml: Host-level configuration
  - Supports env var expansion:
    \${VAR}    - Expanded immediately when reading file
    \${{VAR}}  - Kept as \${VAR} for later expansion by dthostmon

EOF
            exit 0
            ;;
        -yaml-ex|-yex)
            YAML_EX_FILE="$2"
            shift 2
            ;;
        -yaml-exh)
            YAML_EX_HOSTS=1
            shift
            ;;
        -env-ex|-eex)
            ENV_EX_FILE="$2"
            shift 2
            ;;
        -env-exh)
            ENV_EX_HOSTS=1
            shift
            ;;
        -f|--force)
            FORCE=1
            shift
            ;;
        -y|--yes)
            YES=1
            shift
            ;;
        -site|--site)
            SITE_NAME="$2"
            shift 2
            ;;
        -host|--host)
            HOST_NAME="$2"
            shift 2
            ;;
        *)
            log "ERROR" "Unknown option: $1"
            log "INFO" "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Validate prerequisites
if ! command -v python3 &> /dev/null; then
    log "ERROR" "python3 is required but not found"
    exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
    log "ERROR" "Configuration file not found: $CONFIG_FILE"
    exit 1
fi

if [[ ! -d "$DOCKER_SITES_DIR" ]]; then
    log "ERROR" "Docker sites directory not found: $DOCKER_SITES_DIR"
    exit 1
fi

log "INFO" "Starting configuration sync"
log "DEBUG" "CONFIG_FILE: $CONFIG_FILE"
log "DEBUG" "DOCKER_SITES_DIR: $DOCKER_SITES_DIR"
log "DEBUG" "TEST_MODE: $TEST_MODE"

# Create backup before modifying
if [[ $TEST_MODE -eq 0 ]]; then
    BACKUP_FILE="${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    if cp "$CONFIG_FILE" "$BACKUP_FILE"; then
        log "INFO" "Created backup: $BACKUP_FILE"
    else
        log "ERROR" "Failed to create backup"
        exit 1
    fi
fi

# Helper: generate example YAML content for site/host
generate_example_yaml() {
    local type="$1"  # site or host
    if [[ "$type" == "site" ]]; then
        cat <<'YAML'
# Site-level configuration for dthostmon
# NOTE: This file is NOT read in real-time. You must run dthostmon_sync_config.sh
#       to merge this configuration into the main dthostmon.yaml file.
#
# Environment Variable Expansion:
#   ${VAR}    - Expanded immediately when sync script runs
#   ${{VAR}}  - Converted to ${VAR} in dthostmon.yaml for runtime expansion

# enabled: Enable/disable monitoring for this entire site
enabled: true

# tags: List of tags to categorize this site (production, staging, critical, etc.)
tags:
  - production
  - critical

# report_frequency: How often to generate reports (hourly/daily/weekly)
report_frequency: daily

# resource_thresholds: Define threshold ranges for resource usage classification
# Format: "min-max" percentages
resource_thresholds:
  health: "0-25"      # Green zone - healthy
  info: "26-55"       # Blue zone - informational
  warning: "56-84"    # Yellow zone - warning
  critical: "85-100"  # Red zone - critical

# alert_recipients: List of email addresses to receive alerts for this site
alert_recipients:
  - ops@example.com
  - admin@example.com
YAML
    else
        # Get actual hostname for the example
        local actual_host="${HOST_NAME:-host01}"
        cat <<YAML
# Host-level configuration for dthostmon
# Filename should be: dthm-${actual_host}.yaml
# NOTE: This file is NOT read in real-time. You must run dthostmon_sync_config.sh
#       to merge this configuration into the main dthostmon.yaml file.
#
# Environment Variable Expansion:
#   \${VAR}    - Expanded immediately when sync script runs
#   \${{VAR}}  - Converted to \${VAR} in dthostmon.yaml for runtime expansion

# name: The actual hostname (should match directory name and filename)
name: ${actual_host}

# enabled: Enable/disable monitoring for this specific host
enabled: true

# hostname: IP address or DNS name for SSH connection
hostname: 10.1.1.10

# port: SSH port (default: 22)
port: 22

# user: SSH username for monitoring connection
user: monitoring

# tags: List of tags to categorize this host (database, webserver, docker, etc.)
tags:
  - database
  - postgresql

# monitoring: Monitoring options for this host
monitoring:
  check_docker: true      # Check Docker containers and images
  check_apt: true         # Check for APT package updates
  check_disk: true        # Check disk usage
  check_services:         # List of systemd services to monitor
    - postgresql
    - docker

# log_paths: Paths to log files to monitor (supports env var expansion)
log_paths:
  - /var/log/syslog
  - /var/log/postgresql/postgresql-14-main.log
  - \${LOG_PATH}/app.log              # Expanded during sync
  - \${{RUNTIME_LOG_DIR}}/error.log   # Expanded at runtime by dthostmon
YAML
    fi
}

# Helper: generate example .env content for site/host
generate_example_env() {
    local type="$1"  # site or host
    if [[ "$type" == "site" ]]; then
        cat <<'ENV'
DTHM_SITE_ENABLED=true
DTHM_SITE_TAGS=production,critical
DTHM_SITE_REPORT_FREQUENCY=daily
DTHM_SITE_ALERT_RECIPIENTS=ops@example.com,admin@example.com
ENV
    else
        cat <<'ENV'
# Host connection settings
DTHM_HOST_ENABLED=true
DTHM_HOST_HOSTNAME=10.1.1.10
DTHM_HOST_PORT=22
DTHM_HOST_USER=monitoring

# Host metadata
DTHM_HOST_TAGS=database,postgresql
DTHM_HOST_CHECK_DOCKER=true
DTHM_HOST_CHECK_APT=true
ENV
    fi
}

# EARLY EXIT HANDLERS: Check for -yaml-exh/-env-exh BEFORE running main sync
# (These operations don't need the full sync pipeline)

# If YAML example file requested (single file mode)
if [[ -n "${YAML_EX_FILE:-}" ]]; then
    # Determine type based on filename
    filename=$(basename -- "$YAML_EX_FILE")
    if [[ "$filename" =~ site ]] ; then
        type=site
    else
        type=host
    fi
    if [[ "$YAML_EX_FILE" == "-" ]]; then
        generate_example_yaml "$type"
        exit 0
    fi
    # Create file
    if [[ $TEST_MODE -eq 1 ]]; then
        log "INFO" "TEST MODE: Would create $YAML_EX_FILE"
        exit 0
    fi
    mkdir -p "$(dirname "$YAML_EX_FILE")"
    if [[ -f "$YAML_EX_FILE" ]]; then
        if [[ $FORCE -eq 1 || $YES -eq 1 ]]; then
            log "INFO" "Overwriting $YAML_EX_FILE (force)"
        else
            read -r -p "File $YAML_EX_FILE exists - overwrite? [y/N] " yn
            if [[ ! "$yn" =~ ^[Yy] ]]; then
                log "INFO" "Skipping creation of $YAML_EX_FILE"
                exit 0
            fi
        fi
    fi
    generate_example_yaml "$type" > "$YAML_EX_FILE"
    log "INFO" "Created example YAML: $YAML_EX_FILE"
    exit 0
fi

# If ENV example file requested (single file mode)
if [[ -n "${ENV_EX_FILE:-}" ]]; then
    filename=$(basename -- "$ENV_EX_FILE")
    if [[ "$filename" =~ site ]] ; then
        type=site
    else
        type=host
    fi
    if [[ "$ENV_EX_FILE" == "-" ]]; then
        generate_example_env "$type"
        exit 0
    fi
    if [[ $TEST_MODE -eq 1 ]]; then
        log "INFO" "TEST MODE: Would create $ENV_EX_FILE"
        exit 0
    fi
    mkdir -p "$(dirname "$ENV_EX_FILE")"
    if [[ -f "$ENV_EX_FILE" ]]; then
        if [[ $FORCE -eq 1 || $YES -eq 1 ]]; then
            generate_example_env "$type" >> "$ENV_EX_FILE"
            log "INFO" "Appended example env variables to $ENV_EX_FILE (force)"
            exit 0
        fi
        read -r -p "File $ENV_EX_FILE exists - append example vars to end? [y/N] " yn
        if [[ ! "$yn" =~ ^[Yy] ]]; then
            log "INFO" "Skipping modify of $ENV_EX_FILE"
            exit 0
        else
            generate_example_env "$type" >> "$ENV_EX_FILE"
            log "INFO" "Appended example env variables to $ENV_EX_FILE"
            exit 0
        fi
    fi
    generate_example_env "$type" > "$ENV_EX_FILE"
    log "INFO" "Created example ENV: $ENV_EX_FILE"
    exit 0
fi

# If YAML example host creation requested (for specified host)
if [[ ${YAML_EX_HOSTS:-0} -eq 1 ]]; then
    # Auto-detect site/host if not provided
    if [[ -z "$HOST_NAME" || -z "$SITE_NAME" ]]; then
        detect_current_site_host
    fi
    
    # Validate detection
    if [[ -z "$SITE_NAME" ]]; then
        log "ERROR" "SITE_NAME not found in ~/.env and not provided via --site flag"
        log "INFO" "You can fix this by running: dt_host_setup.sh"
        exit 1
    fi
    
    if [[ -z "$HOST_NAME" ]]; then
        log "ERROR" "Could not determine hostname"
        exit 1
    fi
    
    # In TEST mode, just show what would be done
    if [[ $TEST_MODE -eq 1 ]]; then
        log "INFO" "TEST MODE: Would create dthm-$HOST_NAME.yaml example for site $SITE_NAME"
        exit 0
    fi
    
    # Find and create file for specified host
    found=0
    site_dir="$DOCKER_SITES_DIR/$SITE_NAME"
    if [[ ! -d "$site_dir" ]]; then
        log "ERROR" "Site directory not found: $site_dir"
        log "INFO" "Looking for Site: $SITE_NAME"
        exit 1
    fi
    
    host_dir="$site_dir/$HOST_NAME"
    if [[ ! -d "$host_dir" ]]; then
        log "ERROR" "Host directory not found: $host_dir"
        log "INFO" "Looking for Site: $SITE_NAME, Host: $HOST_NAME"
        exit 1
    fi
    
    target="$host_dir/dthm-${HOST_NAME}.yaml"
    if [[ -f "$target" ]]; then
        if [[ $FORCE -eq 1 || $YES -eq 1 ]]; then
            log "INFO" "Overwriting $target (force)"
        else
            read -r -p "YAML $target exists - overwrite? [y/N] " yn
            if [[ ! "$yn" =~ ^[Yy] ]]; then
                log "INFO" "Skipping $target"
                exit 0
            fi
        fi
    fi
    generate_example_yaml host > "$target"
    log "INFO" "Created example YAML for host: $target"
    exit 0
fi

# If ENV example host creation requested (for specified host)
if [[ ${ENV_EX_HOSTS:-0} -eq 1 ]]; then
    # Auto-detect site/host if not provided
    if [[ -z "$HOST_NAME" || -z "$SITE_NAME" ]]; then
        detect_current_site_host
    fi
    
    # Validate detection
    if [[ -z "$SITE_NAME" ]]; then
        log "ERROR" "SITE_NAME not found in ~/.env and not provided via --site flag"
        log "INFO" "You can fix this by running: dt_host_setup.sh"
        exit 1
    fi
    
    if [[ -z "$HOST_NAME" ]]; then
        log "ERROR" "Could not determine hostname"
        exit 1
    fi
    
    # In TEST mode, just show what would be done
    if [[ $TEST_MODE -eq 1 ]]; then
        log "INFO" "TEST MODE: Would create .env.$HOST_NAME example for site $SITE_NAME"
        exit 0
    fi
    
    # Find and create file for specified host
    site_dir="$DOCKER_SITES_DIR/$SITE_NAME"
    if [[ ! -d "$site_dir" ]]; then
        log "ERROR" "Site directory not found: $site_dir"
        log "INFO" "Looking for Site: $SITE_NAME"
        exit 1
    fi
    
    host_dir="$site_dir/$HOST_NAME"
    if [[ ! -d "$host_dir" ]]; then
        log "ERROR" "Host directory not found: $host_dir"
        log "INFO" "Looking for Site: $SITE_NAME, Host: $HOST_NAME"
        exit 1
    fi
    
    target="$host_dir/.env.${HOST_NAME}"
    if [[ -f "$target" ]]; then
        if [[ $FORCE -eq 1 || $YES -eq 1 ]]; then
            generate_example_env host >> "$target"
            log "INFO" "Appended example ENV for host: $target (force)"
        else
            read -r -p "ENV $target exists - append example vars? [y/N] " yn
            if [[ ! "$yn" =~ ^[Yy] ]]; then
                log "INFO" "Skipping $target"
                exit 0
            fi
            generate_example_env host >> "$target"
            log "INFO" "Appended example ENV for host: $target"
        fi
    else
        generate_example_env host > "$target"
        log "INFO" "Created example ENV for host: $target"
    fi
    exit 0
fi

# END OF EARLY EXIT HANDLERS

# Note: Auto-detection and validation is NOT performed here for the main sync operation
# The sync operation scans ALL sites/hosts in the DOCKER_SITES_DIR
# Auto-detection is only used for -yaml-exh and -env-exh operations above

# Activate virtual environment using centralized divtools venv management
VENV_NAME="dthostmon"
VENV_DIR="${DIVTOOLS:-/home/divix/divtools}/scripts/venvs/$VENV_NAME"

if [[ -f "$VENV_DIR/bin/activate" ]]; then
    log "DEBUG" "Activating virtual environment: $VENV_NAME"
    source "$VENV_DIR/bin/activate"
elif [[ -d "$VENV_DIR" ]]; then
    log "WARN" "Virtual environment found but activate script missing: $VENV_DIR"
    log "INFO" "You can recreate it with: python_venv_create $VENV_NAME"
else
    log "WARN" "Virtual environment '$VENV_NAME' not found"
    log "INFO" "Create it with: python_venv_create $VENV_NAME"
    log "INFO" "Then install requirements: pip install -r $PROJECT_ROOT/requirements.txt"
fi

# Verify Python script exists
PYTHON_SCRIPT="$SCRIPT_DIR/dthostmon_sync_config.py"
if [[ ! -f "$PYTHON_SCRIPT" ]]; then
    log "ERROR" "Python helper script not found: $PYTHON_SCRIPT"
    exit 1
fi

# Run Python helper to generate updated config
log "INFO" "Scanning Docker sites directory for configuration"

# If in test mode, enable validation and file listing in the Python helper
if [[ $TEST_MODE -eq 1 ]]; then
    VALIDATE=1
    export TEST_MODE=1
else
    VALIDATE=0
fi
export VALIDATE
export DEBUG_MODE

# Run Python script and capture YAML output (stdout) separately from messages (stderr)
TEMP_OUTPUT=$(mktemp)
TEMP_STDERR=$(mktemp)

python3 "$PYTHON_SCRIPT" "$CONFIG_FILE" "$DOCKER_SITES_DIR" > "$TEMP_OUTPUT" 2> "$TEMP_STDERR"
PYTHON_EXIT=$?

# Show stderr messages (summary, debug info)
if [[ -s "$TEMP_STDERR" ]]; then
    cat "$TEMP_STDERR"
fi

# Get YAML output
UPDATED_CONFIG=$(cat "$TEMP_OUTPUT")

# Cleanup
rm -f "$TEMP_OUTPUT" "$TEMP_STDERR"

if [[ $PYTHON_EXIT -ne 0 ]]; then
    log "ERROR" "Failed to process configuration"
    exit 1
fi

# Write or display the updated configuration
if [[ $TEST_MODE -eq 1 ]]; then
    log "INFO" "TEST MODE: Configuration changes preview"
    echo "----------------------------------------"
    echo "$UPDATED_CONFIG"
    echo "----------------------------------------"
    log "INFO" "TEST MODE: No changes were written to $CONFIG_FILE"
else
    echo "$UPDATED_CONFIG" > "$CONFIG_FILE"
    log "INFO" "Configuration updated: $CONFIG_FILE"
fi

log "INFO" "Configuration sync completed successfully"
