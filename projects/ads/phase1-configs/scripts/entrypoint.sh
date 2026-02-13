#!/bin/bash
# Samba AD DC Container Entrypoint Script
# Deploy Location: /home/divix/divtools/docker/sites/$SITE_NAME/$HOSTNAME/samba/entrypoint.sh
# Example: /home/divix/divtools/docker/sites/s01-7692nw/ads1-98/samba/entrypoint.sh
# Last Updated: 12/5/2025 8:00:00 AM CST

set -e

# Function to log with timestamps
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

log "Starting Samba AD DC initialization..."

# Check if samba is installed, install if not
if ! command -v samba-tool &> /dev/null; then
    log "Samba not found, installing..."
    apt-get update && apt-get install -y samba krb5-user winbind
    log "Samba installed successfully"
else
    log "Samba already installed"
fi

# Required environment variables
if [ -z "$DOMAIN" ]; then
    log "ERROR: DOMAIN environment variable is required"
    exit 1
fi

if [ -z "$REALM" ]; then
    log "ERROR: REALM environment variable is required"
    exit 1
fi

if [ -z "$ADMIN_PASSWORD" ]; then
    log "ERROR: ADMIN_PASSWORD environment variable is required"
    exit 1
fi

# Optional variables with defaults
DNS_FORWARDER=${DNS_FORWARDER:-8.8.8.8}
WORKGROUP=${WORKGROUP:-DOMAIN}
HOST_IP=${HOST_IP:-$(hostname -i | awk '{print $1}')}
SERVER_ROLE=${SERVER_ROLE:-dc}
DNS_BACKEND=${DNS_BACKEND:-SAMBA_INTERNAL}
DOMAIN_LEVEL=${DOMAIN_LEVEL:-2016}
FOREST_LEVEL=${FOREST_LEVEL:-2016}
LOG_LEVEL=${LOG_LEVEL:-1}

log "Configuration:"
log "  Domain: $DOMAIN"
log "  Realm: $REALM"
log "  Workgroup: $WORKGROUP"
log "  Host IP: $HOST_IP"
log "  Server Role: $SERVER_ROLE"
log "  DNS Backend: $DNS_BACKEND"
log "  DNS Forwarder: $DNS_FORWARDER"

# Check if domain is already provisioned
if [ -f /var/lib/samba/private/sam.ldb ]; then
    log "Domain already provisioned. Starting existing domain controller..."
    
    # Verify smb.conf exists
    if [ ! -f /etc/samba/smb.conf ]; then
        log "WARNING: smb.conf not found in /etc/samba, domain may need reprovisioning"
    fi
    
    # Copy Kerberos config if it doesn't exist in /etc
    if [ -f /var/lib/samba/private/krb5.conf ] && [ ! -f /etc/krb5.conf ]; then
        log "Copying Kerberos configuration to /etc/krb5.conf"
        cp /var/lib/samba/private/krb5.conf /etc/krb5.conf
    fi
    
else
    log "No existing domain found. Provisioning new domain..."
    
    # Remove any existing incomplete smb.conf
    if [ -f /etc/samba/smb.conf ]; then
        log "Removing existing smb.conf"
        rm -f /etc/samba/smb.conf
    fi
    
    # Create directories if they don't exist
    mkdir -p /var/lib/samba/private
    mkdir -p /var/lib/samba/sysvol
    mkdir -p /var/log/samba
    mkdir -p /etc/samba
    
    # Set proper permissions
    chmod 700 /var/lib/samba/private
    
    # Provision the domain
    log "Running samba-tool domain provision..."
    samba-tool domain provision \
        --server-role="${SERVER_ROLE}" \
        --use-rfc2307 \
        --dns-backend="${DNS_BACKEND}" \
        --realm="${REALM}" \
        --domain="${WORKGROUP}" \
        --adminpass="${ADMIN_PASSWORD}" \
        --host-ip="${HOST_IP}" \
        --function-level="${DOMAIN_LEVEL}" \
        --option="dns forwarder = ${DNS_FORWARDER}" \
        --option="log level = ${LOG_LEVEL}"
    
    if [ $? -eq 0 ]; then
        log "Domain provision completed successfully!"
    else
        log "ERROR: Domain provision failed!"
        exit 1
    fi
    
    # Copy Kerberos config to system location
    if [ -f /var/lib/samba/private/krb5.conf ]; then
        log "Copying Kerberos configuration to /etc/krb5.conf"
        cp /var/lib/samba/private/krb5.conf /etc/krb5.conf
    fi
    
    # Set permissions on smb.conf
    if [ -f /etc/samba/smb.conf ]; then
        chmod 644 /etc/samba/smb.conf
        log "Set permissions on smb.conf"
    fi
    
    log "Domain provisioning complete!"
    log "Administrator password: [REDACTED]"
    log "You can now join Windows/Linux clients to the domain"
fi

# Display domain info before starting
log "Domain Controller Information:"
samba-tool domain info 127.0.0.1 || log "WARNING: Could not retrieve domain info"

# Start Samba
log "Starting Samba services..."
log "Samba is now running in foreground mode"

# Execute the CMD from docker-compose
exec "$@"
