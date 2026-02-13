#!/bin/bash
# Update PostgreSQL user password using environment variables or command-line arguments
# Last Updated: 11/10/2025 12:00:00 AM CST

# Source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../util/logging.sh"

# Default flags and variables (initialize before sourcing bash_profile)
TEST_MODE=0
DEBUG_MODE=0
DISPLAY_ONLY=0
CONFIRM_YES=0
CONFIRM_NO=0
FORCE_DROP=0
MAKE_SUPERUSER=0
MAKE_CREATEROLE=0
MAKE_CREATEDB=0
MAKE_INHERIT=0
MAKE_REPLICATION=0
MAKE_BYPASSRLS=0
MAKE_SYSTEM_ROLE=0
OPERATION="update"
PG_USER=""
PG_PASSWORD=""
PG_HOST="localhost"
PG_PORT="5432"
PG_DB=""
PG_ADMIN_USER=""
PG_ADMIN_PASSWORD=""
USE_DOCKER_EXEC=0
DOCKER_CONTAINER=""

# Source .bash_profile to get load_env_files() and related functions
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

# Parse arguments first to set DEBUG_MODE (for early debug output)
# Check if debug flag is present WITHOUT consuming arguments
if [[ "$*" == *"-debug"* ]] || [[ "$*" == *"--debug"* ]]; then
    DEBUG_MODE=1
fi

# Call source_bash_profile to get load_env_files function
source_bash_profile

# Load all environment variables using the proper divtools method
if ! declare -f load_env_files >/dev/null; then
    log "ERROR" "load_env_files function not found after sourcing .bash_profile."
    exit 1
fi
if ! load_env_files 2>/dev/null; then
    log "WARN" "Environment setup incomplete. Some variables may not be loaded."
fi

# Set defaults from environment variables AFTER load_env_files
PG_USER="${POSTGRES_DT_USER:-divix}"
PG_PASSWORD="${POSTGRES_DT_PASSWORD:-3mpms3}"
PG_DB="${POSTGRES_DB:-postgres}"
PG_ADMIN_USER="${PGADMIN_USER:-postgres}"
PG_ADMIN_PASSWORD="${PGADMIN_PASSWORD:-}"

log "DEBUG" "Environment variables loaded (DEBUG_MODE=$DEBUG_MODE, PG_USER=$PG_USER, PG_DB=$PG_DB, PG_ADMIN_USER=$PG_ADMIN_USER)"

# Parse all arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|-host|--host)
            # Parse host and optional port (e.g., "localhost:5433")
            host_input="$2"
            if [[ $host_input == *":"* ]]; then
                PG_HOST="${host_input%:*}"
                PG_PORT="${host_input##*:}"
                log "DEBUG" "Parsed host from -h: host=$PG_HOST, port=$PG_PORT"
            else
                PG_HOST="$host_input"
                log "DEBUG" "Set host from -h: $PG_HOST"
            fi
            shift 2
            ;;
        -p|-port|--port)
            PG_PORT="$2"
            log "DEBUG" "Set port from -p: $PG_PORT"
            shift 2
            ;;
        -u|-user|--user)
            PG_USER="$2"
            log "DEBUG" "Set user from -u: $PG_USER"
            shift 2
            ;;
        -pass|--pass|--password)
            PG_PASSWORD="$2"
            log "DEBUG" "Set password from -pass (value hidden)"
            shift 2
            ;;
        -admin-user|--admin-user)
            PG_ADMIN_USER="$2"
            log "DEBUG" "Set admin user from -admin-user: $PG_ADMIN_USER"
            shift 2
            ;;
        -admin-pass|--admin-pass|--admin-password)
            PG_ADMIN_PASSWORD="$2"
            log "DEBUG" "Set admin password from -admin-pass (value hidden)"
            shift 2
            ;;
        -de|-docker-exec|--docker-exec)
            USE_DOCKER_EXEC=1
            DOCKER_CONTAINER="$2"
            log "DEBUG" "Docker exec mode enabled for container: $DOCKER_CONTAINER"
            shift 2
            ;;
        -op|-operation|--operation)
            OPERATION="$2"
            log "DEBUG" "Operation set to: $OPERATION"
            shift 2
            ;;
        -y|-yes|--yes)
            CONFIRM_YES=1
            log "DEBUG" "Auto-confirm enabled (answer YES to all)"
            shift
            ;;
        -n|-no|--no)
            CONFIRM_NO=1
            log "DEBUG" "Auto-confirm disabled (answer NO to all)"
            shift
            ;;
        -ls-users|-lsu|--list-users)
            OPERATION="list-users"
            log "DEBUG" "List users operation enabled"
            shift
            ;;
        -ls-dbs|-lsd|--list-databases|--list-dbs)
            OPERATION="list-databases"
            log "DEBUG" "List databases operation enabled"
            shift
            ;;
        -su|-super-user|--super-user)
            # When superuser is set, enable ALL privilege flags to match postgres user
            MAKE_SUPERUSER=1
            MAKE_CREATEROLE=1
            MAKE_CREATEDB=1
            MAKE_INHERIT=1
            MAKE_REPLICATION=1
            MAKE_BYPASSRLS=1
            MAKE_SYSTEM_ROLE=1
            log "DEBUG" "Superuser flag set - all privileges enabled"
            shift
            ;;
        -cr|-create-role|--create-role)
            MAKE_CREATEROLE=1
            log "DEBUG" "Create role flag set"
            shift
            ;;
        -cdb|-create-db|--create-db)
            MAKE_CREATEDB=1
            log "DEBUG" "Create database flag set"
            shift
            ;;
        -inherit|-inh|--inherit)
            MAKE_INHERIT=1
            log "DEBUG" "Inherit flag set"
            shift
            ;;
        -repl|-replication|--replication)
            MAKE_REPLICATION=1
            log "DEBUG" "Replication flag set"
            shift
            ;;
        -bypassrls|-bypass|--bypass-rls)
            MAKE_BYPASSRLS=1
            log "DEBUG" "Bypass RLS flag set"
            shift
            ;;
        -sr|-system-role|--system-role)
            MAKE_SYSTEM_ROLE=1
            log "DEBUG" "System role flag set"
            shift
            ;;
        -force|--force)
            FORCE_DROP=1
            log "DEBUG" "Force drop enabled - will revoke all privileges before dropping"
            shift
            ;;
        -ls|--list|--display)
            DISPLAY_ONLY=1
            log "DEBUG" "Display mode enabled"
            shift
            ;;
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
            print_usage
            exit 1
            ;;
    esac
done

# Confirmation function for protected operations
ask_confirmation() {
    local message="$1"
    
    # If auto-yes is set, confirm automatically
    if [[ $CONFIRM_YES -eq 1 ]]; then
        log "WARN" "$message (auto-confirmed with -y flag)"
        return 0
    fi
    
    # If auto-no is set, deny automatically
    if [[ $CONFIRM_NO -eq 1 ]]; then
        log "WARN" "$message (auto-denied with -n flag)"
        return 1
    fi
    
    # Ask user for confirmation
    read -p "$(echo -e "\033[33m$message (yes/no): \033[0m")" -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

# Check if user is protected
is_protected_user() {
    local user="$1"
    [[ "$user" == "postgres" ]] || [[ "$user" == "divix" ]]
}

# Print usage information
print_usage() {
    cat << 'EOF'
Usage: pg_update_user.sh [OPTIONS]

Options:
  -h, -host <hostname[:port]>   PostgreSQL host (default: localhost)
                                Can include port (e.g., localhost:5433)
  -p, -port <port>              PostgreSQL port (default: 5432)
  -u, -user <username>          PostgreSQL user to update
                                (default: $POSTGRES_DT_USER or "divix")
  -pass <password>              Password to set for the user
                                (default: $POSTGRES_DT_PASSWORD or "3mpms3")
  
  Privilege Flags (only valid with update operation):
  -su, -super-user              Grant ALL superuser privileges
                                Equivalent to setting all flags below
                                Creates a full postgres-equivalent account
  -cr, -create-role             User can create new roles
  -cdb, -create-db              User can create new databases
  -inherit, -inh                User inherits rights from parent roles
  -repl, -replication           User can initiate replication and backups
  -bypassrls, -bypass           User can bypass row-level security (RLS)
  -sr, -system-role             User is marked as a system role
  
  Connection Options:
  -admin-user <username>        PostgreSQL admin user
                                (default: $PGADMIN_USER or "postgres")
  -admin-pass <password>        PostgreSQL admin password (for direct psql)
                                (default: $PGADMIN_PASSWORD)
                                NOT required if using -docker-exec
  -de, -docker-exec <container> Use docker exec instead of direct psql connection
                                Specify the container name (e.g., "postgres")
  -op, -operation <op>          Operation to perform (default: "update")
                                  update     : Update password (create if not exists)
                                  show       : Display user information
                                  del, rm    : Delete the user
                                  list-users : List all PostgreSQL users in a table
                                  list-databases : List all databases with size and owner
  -ls-users, -lsu               Shortcut for -op list-users (same as -op list-users)
  -ls-dbs, -lsd                 Shortcut for -op list-databases (same as -op list-databases)
  -force, --force               Force drop user by revoking all privileges first
                                Only valid with delete operation
                                Use this if getting "cannot be dropped" errors
  -y, -yes, --yes               Auto-confirm all prompts (answer YES)
  -n, -no, --no                 Auto-reject all prompts (answer NO)
  -ls, --list, --display        Display the current settings without making changes
  -test, --test                 Test mode - show what would be done
  -debug, --debug               Enable debug output

Protection:
  The "postgres" and "divix" users are protected. Operations on these users
  will require confirmation unless overridden with -y flag.
  Use -n flag to auto-reject any changes to protected users.

Environment Variables Used:
  POSTGRES_DT_USER              Default user to update (fallback: "divix")
  POSTGRES_DT_PASSWORD          Default password to set (fallback: "3mpms3")
  POSTGRES_DB                   Default database name (fallback: "postgres")
  PGADMIN_USER                  Admin user for connection (fallback: "postgres")
  PGADMIN_PASSWORD              Admin password for direct psql mode

Examples:
  # Display current settings
  pg_update_user.sh --display

  # Update testuser using docker exec (no credentials needed)
  pg_update_user.sh -u testuser -pass "newpass" -de postgres

  # Update testuser using direct psql with admin password
  pg_update_user.sh -u testuser -pass "newpass" -admin-pass "postgrespass"

  # Update specific user on specific host with admin user
  pg_update_user.sh -u appuser -pass "newpass123" -h prod-db.example.com -admin-user admin -admin-pass "adminpass"

  # Update with host:port in single argument via docker exec
  pg_update_user.sh -u testuser -pass "newpass" -de postgres -h "localhost:5432"

  # Test mode with debug output using docker exec
  pg_update_user.sh -u testuser -pass "newpass" -de postgres -test -debug

  # Test mode with debug output using direct psql
  pg_update_user.sh -u testuser -pass "newpass" -admin-pass "postgrespass" -test -debug

  # Show user information
  pg_update_user.sh -u testuser -op show -de postgres

  # Create superuser "divix" as a backdoor/recovery account (all privileges)
  pg_update_user.sh -u divix -pass "backdoor_password" -su -de postgres

  # Create superuser with test mode to preview
  pg_update_user.sh -u divix -pass "backdoor_password" -su -de postgres -test

  # Create user with specific privileges (can create roles and databases)
  pg_update_user.sh -u developer -pass "devpass" -cr -cdb -de postgres

  # Create user with replication privileges
  pg_update_user.sh -u replicator -pass "replpass" -repl -inherit -de postgres

  # Create user with all privileges (equivalent to -su)
  pg_update_user.sh -u admin_backup -pass "adminpass" -cr -cdb -inherit -repl -bypassrls -sr -de postgres

  # Delete a user with confirmation
  pg_update_user.sh -u olduser -op del -de postgres

  # Delete a user that has privileges (force drop - revoke all first)
  pg_update_user.sh -u testuser -op del -de postgres -force

  # Force delete with test mode to preview
  pg_update_user.sh -u testuser -op del -de postgres -force -test

  # List all users in table format
  pg_update_user.sh -op list-users -de postgres

  # List all databases with size and owner information
  pg_update_user.sh -op list-databases -de postgres

  # List databases using shortcut flag
  pg_update_user.sh -ls-dbs -de postgres

  # List databases in test mode to see the query
  pg_update_user.sh -op list-databases -de postgres -test

  # Create superuser with debug output
  pg_update_user.sh -u divix -pass "backdoor_password" -su -de postgres -debug

  # Display superuser configuration before creating
  pg_update_user.sh -u divix -pass "backdoor_password" -su -de postgres --display

  # Delete a user (with confirmation)
  pg_update_user.sh -u testuser -op del -de postgres -test

  # Delete a user auto-confirmed
  pg_update_user.sh -u testuser -op rm -de postgres -y

  # Try to update protected user (will require confirmation)
  pg_update_user.sh -u divix -pass "newpass" -de postgres -test

  # Update protected user with auto-confirmation
  pg_update_user.sh -u postgres -pass "newpass123" -de postgres -y -test

  # List all PostgreSQL users
  pg_update_user.sh -ls-users -de postgres

  # List all users using -op syntax
  pg_update_user.sh -op list-users -de postgres

  # List all users via direct psql connection
  pg_update_user.sh -op list-users -admin-pass "postgrespass"
EOF
}

# Validate required values
if [[ -z "$PG_USER" ]]; then
    log "ERROR" "PostgreSQL user not specified. Use -u option or set POSTGRES_DT_USER"
    exit 1
fi

if [[ -z "$PG_PASSWORD" ]]; then
    log "ERROR" "PostgreSQL password not specified. Use -pass option or set POSTGRES_DT_PASSWORD"
    exit 1
fi

if [[ -z "$PG_HOST" ]]; then
    log "ERROR" "PostgreSQL host not specified. Use -h option or set default."
    exit 1
fi

# Validate docker exec or credentials
if [[ $USE_DOCKER_EXEC -eq 0 ]]; then
    # For direct psql connection, admin password is required
    if [[ -z "$PG_ADMIN_PASSWORD" ]]; then
        log "ERROR" "Admin password not specified. Use -admin-pass option, set PGADMIN_PASSWORD, or use -docker-exec mode."
        exit 1
    fi
fi

if [[ $USE_DOCKER_EXEC -eq 1 ]] && [[ -z "$DOCKER_CONTAINER" ]]; then
    log "ERROR" "Docker container name not specified with -docker-exec"
    exit 1
fi

# Validate operation
case "$OPERATION" in
    update|show|del|rm|list-users|list-databases)
        log "DEBUG" "Operation validated: $OPERATION"
        ;;
    *)
        log "ERROR" "Invalid operation: $OPERATION. Valid operations are: update, show, del, rm, list-users, list-databases"
        exit 1
        ;;
esac

# Validate user is specified (not needed for list-users or list-databases)
if [[ "$OPERATION" != "list-users" ]] && [[ "$OPERATION" != "list-databases" ]] && [[ -z "$PG_USER" ]]; then
    log "ERROR" "PostgreSQL user not specified. Use -u option or set POSTGRES_DT_USER"
    exit 1
fi

# Validate operation-specific requirements
case "$OPERATION" in
    update)
        if [[ -z "$PG_PASSWORD" ]]; then
            log "ERROR" "Password required for update operation. Use -pass option"
            exit 1
        fi
        ;;
    show)
        # Show operation only needs username
        log "DEBUG" "Show operation requires only username"
        ;;
    del|rm)
        # Delete operation only needs username
        log "DEBUG" "Delete operation requires only username"
        ;;
    list-users)
        # List users doesn't need username or password
        log "DEBUG" "List users operation requires no username"
        ;;
    list-databases)
        # List databases doesn't need username or password
        log "DEBUG" "List databases operation requires no username"
        ;;
esac

# Validate privilege flags are only used with update operation
# Check if any privilege flag is set
if [[ $MAKE_SUPERUSER -eq 1 ]] || [[ $MAKE_CREATEROLE -eq 1 ]] || [[ $MAKE_CREATEDB -eq 1 ]] || 
   [[ $MAKE_INHERIT -eq 1 ]] || [[ $MAKE_REPLICATION -eq 1 ]] || [[ $MAKE_BYPASSRLS -eq 1 ]] || 
   [[ $MAKE_SYSTEM_ROLE -eq 1 ]]; then
    if [[ "$OPERATION" != "update" ]]; then
        log "ERROR" "Privilege flags can only be used with update operation"
        exit 1
    fi
    log "DEBUG" "Privilege flags will be applied to user '$PG_USER'"
fi

# Check for protected users and request confirmation
if is_protected_user "$PG_USER"; then
    if [[ "$OPERATION" != "show" ]] && [[ "$OPERATION" != "list-users" ]] && [[ "$OPERATION" != "list-databases" ]]; then
        log "WARN" "Attempting to $OPERATION user '${PG_USER}' which is a protected system user."
        if ! ask_confirmation "Are you sure you want to $OPERATION the protected user '$PG_USER'"; then
            log "INFO" "Operation cancelled by user"
            exit 0
        fi
    fi
fi

log "DEBUG" "Validation passed. Ready to execute operation: $OPERATION"

# Display mode (AFTER all arguments parsed and validated)
if [[ $DISPLAY_ONLY -eq 1 ]]; then
    log "INFO:!ts" "═══════════════════════════════════════════════════════════"
    log "INFO:!ts" "PostgreSQL User Configuration"
    log "INFO:!ts" "═══════════════════════════════════════════════════════════"
    log "INFO:!ts" "Operation:         $OPERATION"
    log "INFO:!ts" "Host:              $PG_HOST"
    log "INFO:!ts" "Port:              $PG_PORT"
    log "INFO:!ts" "Database:          $PG_DB"
    log "INFO:!ts" "User:              $PG_USER"
    if [[ "$OPERATION" == "update" ]]; then
        log "INFO:!ts" "New Password:      [set to '$PG_PASSWORD']"
        log "INFO:!ts" "──────────────────────────────────────────────────────────"
        log "INFO:!ts" "Privileges:"
        [[ $MAKE_SUPERUSER -eq 1 ]] && log "INFO:!ts" "  • Superuser:               YES (full admin rights)" || log "INFO:!ts" "  • Superuser:               NO"
        [[ $MAKE_CREATEROLE -eq 1 ]] && log "INFO:!ts" "  • Can Create Roles:        YES" || log "INFO:!ts" "  • Can Create Roles:        NO"
        [[ $MAKE_CREATEDB -eq 1 ]] && log "INFO:!ts" "  • Can Create Databases:    YES" || log "INFO:!ts" "  • Can Create Databases:    NO"
        [[ $MAKE_INHERIT -eq 1 ]] && log "INFO:!ts" "  • Inherit Rights:          YES" || log "INFO:!ts" "  • Inherit Rights:          NO"
        [[ $MAKE_REPLICATION -eq 1 ]] && log "INFO:!ts" "  • Replication:             YES" || log "INFO:!ts" "  • Replication:             NO"
        [[ $MAKE_BYPASSRLS -eq 1 ]] && log "INFO:!ts" "  • Bypass RLS:              YES" || log "INFO:!ts" "  • Bypass RLS:              NO"
        [[ $MAKE_SYSTEM_ROLE -eq 1 ]] && log "INFO:!ts" "  • System Role:             YES" || log "INFO:!ts" "  • System Role:             NO"
    fi
    log "INFO:!ts" "Admin User:        $PG_ADMIN_USER"
    log "INFO:!ts" "Admin Password:    $([ -z "$PG_ADMIN_PASSWORD" ] && echo "[not set]" || echo "[set]")"
    if [[ $USE_DOCKER_EXEC -eq 1 ]]; then
        log "INFO:!ts" "Execution Mode:    Docker Exec"
        log "INFO:!ts" "Docker Container:  $DOCKER_CONTAINER"
    else
        log "INFO:!ts" "Execution Mode:    Direct psql"
    fi
    log "INFO:!ts" "═══════════════════════════════════════════════════════════"
    exit 0
fi

# Build SQL command based on operation
case "$OPERATION" in
    update)
        # Build privilege clause based on flags
        PRIVILEGE_CLAUSE=""
        
        [[ $MAKE_SUPERUSER -eq 1 ]] && PRIVILEGE_CLAUSE="$PRIVILEGE_CLAUSE SUPERUSER" || PRIVILEGE_CLAUSE="$PRIVILEGE_CLAUSE NOSUPERUSER"
        [[ $MAKE_CREATEROLE -eq 1 ]] && PRIVILEGE_CLAUSE="$PRIVILEGE_CLAUSE CREATEROLE" || PRIVILEGE_CLAUSE="$PRIVILEGE_CLAUSE NOCREATEROLE"
        [[ $MAKE_CREATEDB -eq 1 ]] && PRIVILEGE_CLAUSE="$PRIVILEGE_CLAUSE CREATEDB" || PRIVILEGE_CLAUSE="$PRIVILEGE_CLAUSE NOCREATEDB"
        [[ $MAKE_INHERIT -eq 1 ]] && PRIVILEGE_CLAUSE="$PRIVILEGE_CLAUSE INHERIT" || PRIVILEGE_CLAUSE="$PRIVILEGE_CLAUSE NOINHERIT"
        [[ $MAKE_REPLICATION -eq 1 ]] && PRIVILEGE_CLAUSE="$PRIVILEGE_CLAUSE REPLICATION" || PRIVILEGE_CLAUSE="$PRIVILEGE_CLAUSE NOREPLICATION"
        [[ $MAKE_BYPASSRLS -eq 1 ]] && PRIVILEGE_CLAUSE="$PRIVILEGE_CLAUSE BYPASSRLS" || PRIVILEGE_CLAUSE="$PRIVILEGE_CLAUSE NOBYPASSRLS"
        # Note: System role flag is tracked but not included in CREATE USER (requires separate configuration)
        
        # Trim leading/trailing whitespace
        PRIVILEGE_CLAUSE=$(echo "$PRIVILEGE_CLAUSE" | xargs)
        
        # Build SQL: Use DO block to handle both new and existing users gracefully
        # Try to CREATE USER, catch exception if user exists, then ALTER USER to ensure privileges are set
        SQL_CMD="DO \$\$ BEGIN CREATE USER ${PG_USER} WITH PASSWORD '${PG_PASSWORD}' $PRIVILEGE_CLAUSE; EXCEPTION WHEN DUPLICATE_OBJECT THEN ALTER USER ${PG_USER} WITH PASSWORD '${PG_PASSWORD}' $PRIVILEGE_CLAUSE; END \$\$; ALTER USER ${PG_USER} WITH PASSWORD '${PG_PASSWORD}' $PRIVILEGE_CLAUSE;"
        log "DEBUG" "SQL Command: CREATE/ALTER USER ${PG_USER} WITH ($PRIVILEGE_CLAUSE)"
        ;;
    show)
        SQL_CMD="SELECT rolname, rolsuper, rolinherit, rolcanlogin FROM pg_roles WHERE rolname = '${PG_USER}';"
        log "DEBUG" "SQL Command: SELECT ... FROM pg_roles WHERE rolname = '${PG_USER}'"
        ;;
    del|rm)
        if [[ $FORCE_DROP -eq 1 ]]; then
            # Force drop: revoke all privileges then drop user
            SQL_CMD="REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM ${PG_USER}; REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public FROM ${PG_USER}; REVOKE ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public FROM ${PG_USER}; REVOKE ALL ON SCHEMA public FROM ${PG_USER}; REVOKE ALL ON DATABASE ${PG_DB} FROM ${PG_USER}; DROP USER IF EXISTS ${PG_USER};"
            log "DEBUG" "SQL Command: Force drop - revoke privileges then DROP USER"
        else
            SQL_CMD="DROP USER IF EXISTS ${PG_USER};"
            log "DEBUG" "SQL Command: DROP USER IF EXISTS ${PG_USER}"
        fi
        ;;
    list-users)
        # List all users with useful details
        SQL_CMD="SELECT rolname AS Username, CASE WHEN rolcanlogin THEN 'yes' ELSE 'no' END AS CanLogin, CASE WHEN rolsuper THEN 'yes' ELSE 'no' END AS IsSuperuser, CASE WHEN rolinherit THEN 'yes' ELSE 'no' END AS InheritsPrivs, CASE WHEN rolcreatedb THEN 'yes' ELSE 'no' END AS CreateDB FROM pg_roles ORDER BY rolname;"
        log "DEBUG" "SQL Command: List all users with details"
        ;;
    list-databases)
        # List all databases with size and owner information
        SQL_CMD="SELECT datname AS Database, pg_size_pretty(pg_database_size(datname)) AS Size, usename AS Owner FROM pg_database JOIN pg_user ON pg_database.datdba = pg_user.usesysid ORDER BY datname;"
        log "DEBUG" "SQL Command: List all databases with size and owner"
        ;;
esac

# Execute the command
if [[ $TEST_MODE -eq 1 ]]; then
    log "INFO" "TEST MODE: Would execute the following command:"
    if [[ $USE_DOCKER_EXEC -eq 1 ]]; then
        log "INFO:raw" "  docker exec $DOCKER_CONTAINER psql -U ${PG_ADMIN_USER} -d $PG_DB -c \"${SQL_CMD}\""
    else
        log "INFO:raw" "  psql -h $PG_HOST -p $PG_PORT -U ${PG_ADMIN_USER} -d $PG_DB -c \"${SQL_CMD}\""
    fi
    case "$OPERATION" in
        update)
            log "INFO" "User '$PG_USER' password would be updated to: [hidden]"
            # Show which privileges would be set
            privs=()
            [[ $MAKE_SUPERUSER -eq 1 ]] && privs+=("Superuser")
            [[ $MAKE_CREATEROLE -eq 1 ]] && privs+=("CreateRole")
            [[ $MAKE_CREATEDB -eq 1 ]] && privs+=("CreateDB")
            [[ $MAKE_INHERIT -eq 1 ]] && privs+=("Inherit")
            [[ $MAKE_REPLICATION -eq 1 ]] && privs+=("Replication")
            [[ $MAKE_BYPASSRLS -eq 1 ]] && privs+=("BypassRLS")
            [[ $MAKE_SYSTEM_ROLE -eq 1 ]] && privs+=("SystemRole")
            if [[ ${#privs[@]} -gt 0 ]]; then
                log "INFO" "Privileges will be set: ${privs[*]}"
            fi
            ;;
        show)
            log "INFO" "User '$PG_USER' information would be displayed"
            ;;
        del|rm)
            log "INFO" "User '$PG_USER' would be deleted"
            if [[ $FORCE_DROP -eq 1 ]]; then
                log "INFO" "Force drop enabled: All privileges will be revoked first"
            fi
            ;;
        list-users)
            log "INFO" "All PostgreSQL users would be listed"
            ;;
        list-databases)
            log "INFO" "All PostgreSQL databases would be listed"
            ;;
    esac
else
    if [[ $USE_DOCKER_EXEC -eq 1 ]]; then
        log "INFO" "Connecting to PostgreSQL via docker exec on container: $DOCKER_CONTAINER..."
        log "DEBUG" "Executing: docker exec $DOCKER_CONTAINER psql -U ${PG_ADMIN_USER} -d $PG_DB -c \"${SQL_CMD}\""
        
        if docker exec "$DOCKER_CONTAINER" psql -U "${PG_ADMIN_USER}" -d "$PG_DB" -c "$SQL_CMD" 2>&1 | tee /tmp/pg_update_user.log; then
            case "$OPERATION" in
                update)
                    log "INFO:HEAD" "✓ Successfully updated password for user '$PG_USER'"
                    ;;
                show)
                    log "INFO:HEAD" "✓ User information displayed above"
                    ;;
                del|rm)
                    if [[ $FORCE_DROP -eq 1 ]]; then
                        log "INFO:HEAD" "✓ User '$PG_USER' deleted successfully (privileges revoked)"
                    else
                        log "INFO:HEAD" "✓ User '$PG_USER' deleted successfully"
                    fi
                    ;;
                list-users)
                    log "INFO:HEAD" "✓ User list displayed above"
                    ;;
                list-databases)
                    log "INFO:HEAD" "✓ Database list displayed above"
                    ;;
            esac
        else
            error_output=$(cat /tmp/pg_update_user.log)
            if echo "$error_output" | grep -q "already exists\|NOTICE"; then
                # For update operations, "already exists" is acceptable
                if [[ "$OPERATION" == "update" ]]; then
                    log "INFO:HEAD" "✓ User password updated (user already existed)"
                else
                    log "WARN" "Operation may have partially succeeded:"
                    log "WARN:raw" "$error_output"
                fi
            else
                log "ERROR" "Operation failed. Error details:"
                log "ERROR:raw" "$error_output"
                exit 1
            fi
        fi
    else
        # Direct psql connection mode
        export PGPASSWORD="${PG_ADMIN_PASSWORD}"
        log "DEBUG" "PGPASSWORD set for admin user (value hidden)"
        
        log "INFO" "Connecting to PostgreSQL at ${PG_HOST}:${PG_PORT}..."
        log "DEBUG" "Executing: psql -h $PG_HOST -p $PG_PORT -U ${PG_ADMIN_USER} -d $PG_DB -c \"${SQL_CMD}\""
        
        if psql -h "$PG_HOST" -p "$PG_PORT" -U "${PG_ADMIN_USER}" -d "$PG_DB" -c "$SQL_CMD" 2>&1 | tee /tmp/pg_update_user.log; then
            case "$OPERATION" in
                update)
                    log "INFO:HEAD" "✓ Successfully updated password for user '$PG_USER'"
                    ;;
                show)
                    log "INFO:HEAD" "✓ User information displayed above"
                    ;;
                del|rm)
                    log "INFO:HEAD" "✓ User '$PG_USER' deleted successfully"
                    ;;
                list-users)
                    log "INFO:HEAD" "✓ User list displayed above"
                    ;;
                list-databases)
                    log "INFO:HEAD" "✓ Database list displayed above"
                    ;;
            esac
        else
            error_output=$(cat /tmp/pg_update_user.log)
            if echo "$error_output" | grep -q "already exists\|NOTICE"; then
                if [[ "$OPERATION" == "update" ]]; then
                    log "INFO:HEAD" "✓ User password updated (user already existed)"
                else
                    log "WARN" "Operation may have partially succeeded:"
                    log "WARN:raw" "$error_output"
                fi
            else
                log "ERROR" "Operation failed. Error details:"
                log "ERROR:raw" "$error_output"
                unset PGPASSWORD
                exit 1
            fi
        fi
        unset PGPASSWORD
    fi
fi

log "INFO" "Operation completed successfully."
exit 0
