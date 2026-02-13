#!/bin/bash
# Add/update pgAdmin servers from a YAML config file for a site
# Last Updated: 11/8/2025 9:50:00 PM CST

# Source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../util/logging.sh"

# Default flags (initialize before sourcing bash_profile)
TEST_MODE=0
DEBUG_MODE=0
SITE=""

# Source .bash_profile to get load_env_files() and related functions
# Last Updated: 11/8/2025 9:30:00 PM CST
source_bash_profile() {
    local bash_profile="$DIVTOOLS/dotfiles/.bash_profile"

    if [ -f "$bash_profile" ]; then
        source "$bash_profile"
        [ "$DEBUG_MODE" -eq 1 ] && log "DEBUG" "Sourced .bash_profile for required functions."
    else
        log "ERROR" ".bash_profile not found at $bash_profile."
        exit 1
    fi
} # source_bash_profile

# Parse arguments first to set DEBUG_MODE
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
        -site)
            SITE="$2"
            shift 2
            ;;
        *)
            # Save unknown options for later
            break
            ;;
    esac
done

# Call source_bash_profile to get load_env_files function
source_bash_profile

# Load all environment variables using the proper divtools method
if ! declare -f load_env_files >/dev/null; then
    log "ERROR" "load_env_files function not found after sourcing .bash_profile."
    exit 1
fi
if ! load_env_files 2>/dev/null; then
    log "ERROR" "Environment setup failed. Please run: \$DIVTOOLS/scripts/dt_host_setup.sh"
    exit 1
fi
log "INFO" "Environment variables loaded using load_env_files() (CFG_MODE=$CFG_MODE)."

# Parse remaining arguments
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
        -site)
            SITE="$2"
            shift 2
            ;;
        *)
            log "ERROR" "Unknown option: $1"
            log "INFO" "Usage: $0 [-test|--test] [-debug|--debug] [-site <site#|site-name>]"
            exit 1
            ;;
    esac
done

# Determine site directory
if [[ -z "$SITE" ]]; then
    SITE="$SITE_NAME"
fi
if [[ -z "$SITE" ]]; then
    log "ERROR" "SITE not specified and SITE_NAME not found in environment"
    exit 1
fi
DOCKER_SITEDIR="$DOCKERDIR/sites/$SITE"
PG_SERVERS_FILE="$DOCKER_SITEDIR/.site-info/pg-servers.yml"

if [[ ! -f "$PG_SERVERS_FILE" ]]; then
    log "ERROR" "Server config file not found: $PG_SERVERS_FILE"
    exit 1
fi

# pgAdmin variables should now be loaded from the proper .env files
if [[ -z "$PGADMIN_API_HOST" ]]; then PGADMIN_API_HOST="10.1.1.74"; fi
if [[ -z "$PGADMIN_API_PORT" ]]; then PGADMIN_API_PORT="5050"; fi
if [[ -z "$PGADMIN_DEFAULT_EMAIL" ]]; then PGADMIN_DEFAULT_EMAIL=""; fi
if [[ -z "$PGADMIN_DEFAULT_PASSWORD" ]]; then PGADMIN_DEFAULT_PASSWORD=""; fi

PGADMIN_URL="http://$PGADMIN_API_HOST:$PGADMIN_API_PORT"

log "INFO" "Using pgAdmin at $PGADMIN_URL"

# Get list of existing servers
log "INFO" "Fetching existing servers from pgAdmin database..."
if [[ ! -f "/opt/pgadmin/pgadmin4.db" ]]; then
    log "ERROR" "pgAdmin database not found at /opt/pgadmin/pgadmin4.db"
    exit 1
fi

# Check if sqlite3 is available
if ! command -v sqlite3 >/dev/null 2>&1; then
    log "ERROR" "sqlite3 is required but not installed."
    log "INFO" "Install with: sudo apt install sqlite3"
    exit 1
fi

EXISTING_SERVERS=$(sudo sqlite3 /opt/pgadmin/pgadmin4.db "SELECT name FROM server WHERE user_id = 1;" 2>/dev/null)
if [[ $? -ne 0 ]]; then
    log "ERROR" "Failed to query pgAdmin database"
    exit 1
fi

# Add servers from YAML file if not already present
log "INFO" "Processing server list from $PG_SERVERS_FILE"
COUNT_ADDED=0
SERVER_COUNT=$(yq '.servers | length' "$PG_SERVERS_FILE")
for index in $(seq 0 $((SERVER_COUNT - 1))); do
    NAME=$(yq '.servers['$index'].name' "$PG_SERVERS_FILE")
    GROUP=$(yq '.servers['$index'].group' "$PG_SERVERS_FILE")
    HOST=$(yq '.servers['$index'].host' "$PG_SERVERS_FILE")
    PORT=$(yq '.servers['$index'].port' "$PG_SERVERS_FILE")
    MAINTENANCE_DB=$(yq '.servers['$index'].maintenance_db' "$PG_SERVERS_FILE")
    USERNAME=$(yq '.servers['$index'].username' "$PG_SERVERS_FILE")
    COMMENT=$(yq '.servers['$index'].comment' "$PG_SERVERS_FILE")

    if echo "$EXISTING_SERVERS" | grep -Fxq "$NAME"; then
        log "INFO" "Server '$NAME' already exists, skipping."
    else
        log "INFO" "Adding server: $NAME ($HOST:$PORT)"
        if [[ $TEST_MODE -eq 0 ]]; then
            # Insert server into pgAdmin database
            SQL="INSERT INTO server (user_id, servergroup_id, name, host, port, maintenance_db, username, comment, save_password) VALUES (1, 1, '$NAME', '$HOST', $PORT, '$MAINTENANCE_DB', '$USERNAME', '$COMMENT', 0);"
            if sudo sqlite3 /opt/pgadmin/pgadmin4.db "$SQL" 2>/dev/null; then
                log "INFO" "Successfully added server '$NAME' to pgAdmin database"
                COUNT_ADDED=$((COUNT_ADDED+1))
            else
                log "ERROR" "Failed to add server '$NAME' to pgAdmin database"
            fi
        else
            log "INFO:!ts" "  [TEST] Would add server: $NAME at $HOST:$PORT"
        fi
    fi
done

if [[ $COUNT_ADDED -gt 0 ]]; then
    log "INFO" "Restarting pgAdmin container to pick up database changes..."
    if [[ $TEST_MODE -eq 0 ]]; then
        # Restart pgAdmin container
        if command -v docker >/dev/null 2>&1; then
            docker restart pgadmin 2>/dev/null || log "WARN" "Could not restart pgAdmin container - you may need to restart it manually"
        else
            log "WARN" "Docker not found - you may need to restart pgAdmin container manually"
        fi
    else
        log "INFO:!ts" "  [TEST] Would restart pgAdmin container"
    fi
fi

log "INFO" "Server update complete. $COUNT_ADDED new servers added."
exit 0
