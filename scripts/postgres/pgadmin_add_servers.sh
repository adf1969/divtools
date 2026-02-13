#!/bin/bash
# Script to add PostgreSQL servers to pgAdmin via REST API
# Last Updated: 11/8/2025 7:30:00 PM CST

# Source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../util/logging.sh"

# Default flags
TEST_MODE=0
DEBUG_MODE=0

# pgAdmin connection details
PGADMIN_URL="${PGADMIN_URL:-http://10.1.1.74:5050}"
PGADMIN_EMAIL="${PGADMIN_EMAIL:-andrew@avcorp.biz}"
PGADMIN_PASSWORD="${PGADMIN_PASSWORD:-3mpms3}"

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

log "INFO" "Starting pgAdmin server configuration via API"
log "DEBUG" "PGADMIN_URL=$PGADMIN_URL"

# Create a temporary cookie file
COOKIE_FILE=$(mktemp)
trap "rm -f $COOKIE_FILE" EXIT

# Login to pgAdmin
log "INFO" "Logging in to pgAdmin..."
if [[ $TEST_MODE -eq 0 ]]; then
    LOGIN_RESPONSE=$(curl -s -c "$COOKIE_FILE" -X POST \
        "$PGADMIN_URL/login" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "email=$PGADMIN_EMAIL&password=$PGADMIN_PASSWORD")
    
    if [[ $? -ne 0 ]]; then
        log "ERROR" "Failed to login to pgAdmin"
        exit 1
    fi
    log "INFO" "Successfully logged in to pgAdmin"
else
    log "INFO:!ts" "  [TEST] Would login to pgAdmin"
fi

# Function to add a server
add_server() {
    local name="$1"
    local group="$2"
    local host="$3"
    local port="$4"
    local maintenance_db="$5"
    local username="$6"
    local comment="$7"
    
    log "INFO" "Adding server: $name ($host:$port)"
    
    if [[ $TEST_MODE -eq 0 ]]; then
        RESPONSE=$(curl -s -b "$COOKIE_FILE" -X POST \
            "$PGADMIN_URL/api/v1/servers" \
            -H "Content-Type: application/json" \
            -H "X-Requested-With: XMLHttpRequest" \
            -d "{
                \"name\": \"$name\",
                \"server_group\": \"$group\",
                \"host\": \"$host\",
                \"port\": $port,
                \"maintenance_db\": \"$maintenance_db\",
                \"username\": \"$username\",
                \"ssl_mode\": \"prefer\",
                \"comment\": \"$comment\",
                \"connect_now\": false,
                \"save_password\": false
            }")
        
        if [[ $? -eq 0 ]]; then
            log "INFO" "Successfully added server: $name"
            log "DEBUG" "Response: $RESPONSE"
        else
            log "ERROR" "Failed to add server: $name"
            log "DEBUG" "Response: $RESPONSE"
        fi
    else
        log "INFO:!ts" "  [TEST] Would add server: $name at $host:$port"
    fi
}

# Add servers from the configuration
log "INFO" "Adding configured servers..."

# Server 1: S01 Postgres Server (standalone)
add_server \
    "S01 Postgres Server" \
    "Servers" \
    "10.1.1.74" \
    "5432" \
    "postgres" \
    "postgres" \
    "Standalone PostgreSQL server for general-purpose databases not tied to specific apps"

# Server 2: Moodle Database
add_server \
    "Moodle Database" \
    "Servers" \
    "10.1.1.74" \
    "5434" \
    "moodle" \
    "moodle" \
    "Moodle Learning Management System Database"

# Server 3: OpenWebUI Database
add_server \
    "OpenWebUI Database" \
    "Servers" \
    "10.1.1.75" \
    "5436" \
    "openwebui" \
    "openwebui" \
    "OpenWebUI (Ollama Web Interface) Database on gpu1-75"

# Server 4: n8n Workflow Database
add_server \
    "n8n Workflow Database" \
    "Servers" \
    "10.1.1.74" \
    "5438" \
    "n8n" \
    "n8n" \
    "n8n Workflow Automation Database"

log "INFO" "Server configuration completed"
log "INFO" "Note: You'll need to enter passwords when connecting to each server for the first time"

exit 0
