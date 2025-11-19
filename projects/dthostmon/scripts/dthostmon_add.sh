#!/bin/bash
# dthostmon Remote Self-Registration Script
# Last Updated: 1/16/2025 1:45:00 PM CST
#
# Implements FR-CONFIG-002: Allows remote hosts to self-register in the monitoring system
# This script connects to the dthostmon REST API and registers the local host for monitoring

# Default values
API_HOST="monitor"
API_PORT="8080"
API_PROTOCOL="http"
API_KEY=""
SITE="default"
TAGS=""
SSH_USER="monitoring"
SSH_KEY_PATH="$HOME/.ssh/id_ed25519"

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Usage
usage() {
    cat << EOF
dthostmon Remote Self-Registration Script

Usage: $0 [OPTIONS]

Options:
    --api-host HOST         API host (default: monitor)
    --api-port PORT         API port (default: 8080)
    --api-protocol PROTO    API protocol http/https (default: http)
    --api-key KEY          API key for authentication (required)
    --site SITE            Site identifier (default: default)
    --tags TAGS            Comma-separated tags (e.g., production,database)
    --ssh-user USER        SSH user for monitoring (default: monitoring)
    --ssh-key PATH         Path to SSH public key (default: ~/.ssh/id_ed25519.pub)
    --help, -h             Show this help message

Example:
    $0 --api-key abc123 --site s01-chicago --tags production,webserver

Environment Variables:
    DTHOSTMON_API_HOST     Same as --api-host
    DTHOSTMON_API_PORT     Same as --api-port
    DTHOSTMON_API_KEY      Same as --api-key
    DTHOSTMON_SITE         Same as --site
    DTHOSTMON_TAGS         Same as --tags

EOF
    exit 0
}

# Logging
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --api-host)
            API_HOST="$2"
            shift 2
            ;;
        --api-port)
            API_PORT="$2"
            shift 2
            ;;
        --api-protocol)
            API_PROTOCOL="$2"
            shift 2
            ;;
        --api-key)
            API_KEY="$2"
            shift 2
            ;;
        --site)
            SITE="$2"
            shift 2
            ;;
        --tags)
            TAGS="$2"
            shift 2
            ;;
        --ssh-user)
            SSH_USER="$2"
            shift 2
            ;;
        --ssh-key)
            SSH_KEY_PATH="$2"
            shift 2
            ;;
        --help|-h)
            usage
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Check for environment variables
API_HOST="${DTHOSTMON_API_HOST:-$API_HOST}"
API_PORT="${DTHOSTMON_API_PORT:-$API_PORT}"
API_KEY="${DTHOSTMON_API_KEY:-$API_KEY}"
SITE="${DTHOSTMON_SITE:-$SITE}"
TAGS="${DTHOSTMON_TAGS:-$TAGS}"

# Validate required parameters
if [ -z "$API_KEY" ]; then
    log_error "API key is required. Use --api-key or set DTHOSTMON_API_KEY environment variable"
    exit 1
fi

# Get host information
HOSTNAME=$(hostname -f 2>/dev/null || hostname)
SHORT_HOSTNAME=$(hostname -s)
IP_ADDRESS=$(hostname -I | awk '{print $1}')

log_info "========================================"
log_info "dthostmon Remote Self-Registration"
log_info "========================================"
log_info "Host: $HOSTNAME ($IP_ADDRESS)"
log_info "Site: $SITE"
log_info "Tags: $TAGS"
log_info "API: ${API_PROTOCOL}://${API_HOST}:${API_PORT}"
echo ""

# Check if SSH user exists
if ! id "$SSH_USER" &>/dev/null; then
    log_warn "SSH user '$SSH_USER' does not exist"
    read -p "Create SSH user '$SSH_USER'? [Y/n]: " create_user
    create_user=${create_user:-Y}
    
    if [[ "$create_user" =~ ^[Yy] ]]; then
        log_info "Creating user '$SSH_USER'..."
        sudo useradd -m -s /bin/bash "$SSH_USER"
        log_success "User created"
    else
        log_error "Cannot proceed without SSH user"
        exit 1
    fi
fi

# Check if SSH key exists
SSH_PUB_KEY="${SSH_KEY_PATH}.pub"
if [ ! -f "$SSH_PUB_KEY" ]; then
    log_warn "SSH public key not found at: $SSH_PUB_KEY"
    read -p "Generate new SSH key? [Y/n]: " generate_key
    generate_key=${generate_key:-Y}
    
    if [[ "$generate_key" =~ ^[Yy] ]]; then
        log_info "Generating SSH key..."
        ssh-keygen -t ed25519 -f "${SSH_KEY_PATH%.pub}" -C "dthostmon@$HOSTNAME" -N ""
        log_success "SSH key generated"
    else
        log_error "Cannot proceed without SSH key"
        exit 1
    fi
fi

# Read SSH public key
SSH_PUBLIC_KEY=$(cat "$SSH_PUB_KEY")
log_success "SSH public key loaded"

# Setup SSH authorized_keys for monitoring user
log_info "Configuring SSH access for user '$SSH_USER'..."
SSH_DIR="/home/$SSH_USER/.ssh"
sudo mkdir -p "$SSH_DIR"
sudo chmod 700 "$SSH_DIR"

# Add public key if not already present
if ! sudo grep -qF "$SSH_PUBLIC_KEY" "$SSH_DIR/authorized_keys" 2>/dev/null; then
    echo "$SSH_PUBLIC_KEY" | sudo tee -a "$SSH_DIR/authorized_keys" > /dev/null
    sudo chmod 600 "$SSH_DIR/authorized_keys"
    sudo chown -R "$SSH_USER:$SSH_USER" "$SSH_DIR"
    log_success "SSH public key added to authorized_keys"
else
    log_success "SSH public key already present in authorized_keys"
fi

# Build registration payload
TAGS_JSON="[]"
if [ -n "$TAGS" ]; then
    # Convert comma-separated tags to JSON array
    TAGS_JSON="[\"$(echo "$TAGS" | sed 's/,/","/g')\"]"
fi

PAYLOAD=$(cat << EOF
{
    "name": "$SHORT_HOSTNAME",
    "hostname": "$IP_ADDRESS",
    "port": 22,
    "user": "$SSH_USER",
    "site": "$SITE",
    "tags": $TAGS_JSON,
    "enabled": true
}
EOF
)

log_info "Registering host with dthostmon API..."

# Make API request
API_URL="${API_PROTOCOL}://${API_HOST}:${API_PORT}/api/v1/hosts/register"
HTTP_CODE=$(curl -s -o /tmp/dthostmon_response.json -w "%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -H "X-API-Key: $API_KEY" \
    -d "$PAYLOAD" \
    "$API_URL")

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
    log_success "Host registered successfully!"
    
    # Display response
    if [ -f /tmp/dthostmon_response.json ]; then
        log_info "Response:"
        cat /tmp/dthostmon_response.json | python3 -m json.tool 2>/dev/null || cat /tmp/dthostmon_response.json
        rm -f /tmp/dthostmon_response.json
    fi
    
    echo ""
    log_success "Registration complete!"
    log_info "This host will now be monitored by dthostmon"
    log_info "Monitoring user: $SSH_USER"
    log_info "Site: $SITE"
    log_info "Tags: $TAGS"
    
elif [ "$HTTP_CODE" = "409" ]; then
    log_warn "Host already registered (HTTP 409 Conflict)"
    
    if [ -f /tmp/dthostmon_response.json ]; then
        log_info "Response:"
        cat /tmp/dthostmon_response.json | python3 -m json.tool 2>/dev/null || cat /tmp/dthostmon_response.json
        rm -f /tmp/dthostmon_response.json
    fi
    
    log_info "Host configuration may need to be updated manually"
    exit 0
    
else
    log_error "Registration failed (HTTP $HTTP_CODE)"
    
    if [ -f /tmp/dthostmon_response.json ]; then
        log_error "Response:"
        cat /tmp/dthostmon_response.json
        rm -f /tmp/dthostmon_response.json
    fi
    
    exit 1
fi

# Cleanup
rm -f /tmp/dthostmon_response.json

exit 0
