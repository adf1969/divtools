# Deployment Guide - Active Directory Services (ADS)

**Last Updated:** December 4, 2025

## Overview

This guide walks through deploying a Samba Active Directory Domain Controller using Docker Compose on an Ubuntu Server. The deployment creates a fully functional AD domain with DNS, Kerberos, and LDAP services.

## Prerequisites

### System Requirements

**Minimum Hardware:**

- 4 CPU cores (8 recommended for production)
- 8 GB RAM (16 GB recommended)
- 100 GB disk space for domain data and logs
- Stable network connectivity with static IP address

**Software Requirements:**

- Ubuntu Server 22.04 LTS or Debian 12
- Docker 24.0+ with Docker Compose V2
- Access to divtools repository
- Root or sudo access

**Network Requirements:**

- Static IP address for domain controller
- DNS forwarder configured (external DNS for internet resolution)
- - pihole is running locally at 10.1.1.111 and should function as the DNS resolver after the Samba/ADS hosts.
- NTP server accessible for time synchronization
- Firewall rules configured for AD ports (see PRD)

### Pre-Deployment Checklist

- [ ] System has static IP configured
- [ ] Hostname properly set and matches intended DC name
- [ ] Time zone and NTP synchronization configured
- [ ] Docker and Docker Compose installed
- [ ] Divtools repository cloned to `/home/divix/divtools`
- [ ] Test environment snapshot created (if using VMs)

## Phase 1: Initial Domain Setup

### Step 1: Prepare Environment Variables

Create environment file for the domain controller:

```bash
# Location: /home/divix/divtools/docker/sites/s01-7692nw/ads1-98/.env.ads1-98
SITE_NAME=s01-7692nw
HOSTNAME=ads1-98
SITE_NUM=1

# Domain Configuration
ADS_DOMAIN=avctn.lan
ADS_REALM=AVCTN.LAN
ADS_WORKGROUP=AVCTN
ADS_ADMIN_PASSWORD=YourSecureAdminPassword123!

# Network Configuration
ADS_DC1_IP=10.1.1.98
ADS_DC2_IP=10.1.1.99  # For second DC (Phase 1 later)
ADS_DNS_FORWARDER=8.8.8.8,8.8.4.4

# Samba Version
SAMBA_VERSION=4.18

# Volume Paths
ADS_CONFIG_PATH=/home/divix/divtools/docker/sites/${SITE_NAME}/${HOSTNAME}/ads/config
ADS_DATA_PATH=/home/divix/divtools/docker/sites/${SITE_NAME}/${HOSTNAME}/ads/data
ADS_LOGS_PATH=/home/divix/divtools/docker/sites/${SITE_NAME}/${HOSTNAME}/ads/logs
```

**Security Note:** Never commit `.env` files with passwords to git. Use `.env.example` templates instead.

### Step 2: Create Docker Compose File

Create the Docker Compose configuration:

```bash
# Location: /home/divix/divtools/projects/ads/docker-compose-ads.yml
```

```yaml
version: '3.8'

services:
  samba-dc:
    image: divtools/samba-ad-dc:${SAMBA_VERSION:-4.18}
    container_name: ${HOSTNAME:-ads1}-dc
    hostname: ${HOSTNAME:-ads1}
    domainname: ${ADS_DOMAIN:-avctn.lan}
    restart: unless-stopped
    
    environment:
      - DOMAIN=${ADS_DOMAIN}
      - REALM=${ADS_REALM}
      - WORKGROUP=${ADS_WORKGROUP}
      - ADMIN_PASSWORD=${ADS_ADMIN_PASSWORD}
      - DNS_FORWARDER=${ADS_DNS_FORWARDER}
      - HOST_IP=${ADS_DC1_IP}
      
    networks:
      ads_network:
        ipv4_address: ${ADS_DC1_IP}
    
    ports:
      - "53:53/tcp"
      - "53:53/udp"
      - "88:88/tcp"
      - "88:88/udp"
      - "135:135/tcp"
      - "139:139/tcp"
      - "389:389/tcp"
      - "445:445/tcp"
      - "464:464/tcp"
      - "464:464/udp"
      - "636:636/tcp"
      - "3268:3268/tcp"
      - "3269:3269/tcp"
    
    volumes:
      - ${ADS_CONFIG_PATH}:/etc/samba:rw
      - ${ADS_DATA_PATH}:/var/lib/samba:rw
      - ${ADS_LOGS_PATH}:/var/log/samba:rw
      - /etc/localtime:/etc/localtime:ro
    
    cap_add:
      - NET_ADMIN
      - SYS_ADMIN
    
    security_opt:
      - apparmor:unconfined
    
    labels:
      - "divtools.group=ads"
      - "divtools.site=${SITE_NAME}"
      - "divtools.service=samba-dc"
    
    healthcheck:
      test: ["CMD", "samba-tool", "domain", "info", "127.0.0.1"]
      interval: 60s
      timeout: 10s
      retries: 3
      start_period: 120s

networks:
  ads_network:
    driver: bridge
    ipam:
      config:
        - subnet: 10.${SITE_NUM:-1}.0.0/20
          gateway: 10.${SITE_NUM:-1}.0.1
```

### Step 3: Build Samba Docker Image

Create the Dockerfile for Samba AD DC:

```bash
# Location: /home/divix/divtools/projects/ads/Dockerfile
```

```dockerfile
# Samba Active Directory Domain Controller
# Last Updated: 12/4/2025 12:00:00 PM CST

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install Samba and dependencies
RUN apt-get update && \
    apt-get install -y \
        samba \
        samba-dsdb-modules \
        samba-vfs-modules \
        winbind \
        libpam-winbind \
        libnss-winbind \
        krb5-user \
        krb5-config \
        bind9 \
        bind9utils \
        dnsutils \
        ldb-tools \
        ldap-utils \
        net-tools \
        iputils-ping \
        curl \
        supervisor && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copy entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Expose AD ports
EXPOSE 53/tcp 53/udp 88/tcp 88/udp 135/tcp 139/tcp 389/tcp 445/tcp \
       464/tcp 464/udp 636/tcp 3268/tcp 3269/tcp

# Set volume mount points
VOLUME ["/etc/samba", "/var/lib/samba", "/var/log/samba"]

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["samba", "-i"]
```

### Step 4: Create Entrypoint Script

Create the Docker entrypoint script:

```bash
# Location: /home/divix/divtools/projects/ads/docker-entrypoint.sh
```

```bash
#!/bin/bash
# Samba AD DC entrypoint script
# Last Updated: 12/4/2025 12:00:00 PM CST

set -e

# Required environment variables
: ${DOMAIN:?"DOMAIN environment variable is required"}
: ${REALM:?"REALM environment variable is required"}
: ${ADMIN_PASSWORD:?"ADMIN_PASSWORD environment variable is required"}

# Optional variables with defaults
DNS_FORWARDER=${DNS_FORWARDER:-8.8.8.8}
WORKGROUP=${WORKGROUP:-DOMAIN}
HOST_IP=${HOST_IP:-$(hostname -i | awk '{print $1}')}

echo "Starting Samba AD DC initialization..."
echo "Domain: $DOMAIN"
echo "Realm: $REALM"
echo "Host IP: $HOST_IP"

# Check if domain is already provisioned
if [ ! -f /var/lib/samba/private/sam.ldb ]; then
    echo "Provisioning new domain..."
    
    # Remove existing smb.conf if present
    rm -f /etc/samba/smb.conf
    
    # Provision domain
    samba-tool domain provision \
        --server-role=dc \
        --use-rfc2307 \
        --dns-backend=SAMBA_INTERNAL \
        --realm="${REALM}" \
        --domain="${WORKGROUP}" \
        --adminpass="${ADMIN_PASSWORD}" \
        --host-ip="${HOST_IP}" \
        --option="dns forwarder = ${DNS_FORWARDER}" \
        --option="log level = 1"
    
    # Copy Kerberos config
    cp /var/lib/samba/private/krb5.conf /etc/krb5.conf
    
    echo "Domain provisioned successfully!"
else
    echo "Domain already exists, starting existing domain..."
fi

# Start Samba
echo "Starting Samba services..."
exec "$@"
```

### Step 5: Build and Deploy

```bash
# Navigate to project directory
cd /home/divix/divtools/projects/ads

# Build Docker image
docker build -t divtools/samba-ad-dc:4.18 .

# Create volume directories
mkdir -p /home/divix/divtools/docker/sites/s01-7692nw/ads1-98/ads/{config,data,logs}

# Set proper permissions
chown -R root:root /home/divix/divtools/docker/sites/s01-7692nw/ads1-98/ads

# Start the domain controller
docker compose -f docker-compose-ads.yml --env-file \
  /home/divix/divtools/docker/sites/s01-7692nw/ads1-98/.env.ads1-98 up -d

# Check logs
docker logs -f ads1-98-dc
```

### Step 6: Verify Domain Functionality

```bash
# Check Samba status
docker exec ads1-98-dc samba-tool domain info 127.0.0.1

# Verify DNS
docker exec ads1-98-dc host -t SRV _ldap._tcp.avctn.lan

# Test authentication
docker exec ads1-98-dc smbclient -L localhost -U Administrator%YourSecureAdminPassword123!

# Check FSMO roles
docker exec ads1-98-dc samba-tool fsmo show

# Verify replication (will show single DC initially)
docker exec ads1-98-dc samba-tool drs showrepl
```

## Phase 2: Adding Second Domain Controller

### Step 1: Prepare Second DC Environment

Create environment file for second DC:

```bash
# Location: /home/divix/divtools/docker/sites/s01-7692nw/ads2-99/.env.ads2-99
SITE_NAME=s01-7692nw
HOSTNAME=ads2-99
SITE_NUM=1

# Domain Configuration (must match DC1)
ADS_DOMAIN=avctn.lan
ADS_REALM=AVCTN.LAN
ADS_WORKGROUP=AVCTN
ADS_ADMIN_PASSWORD=YourSecureAdminPassword123!

# Network Configuration
ADS_DC1_IP=10.1.1.98  # Primary DC
ADS_DC2_IP=10.1.1.99  # This DC
ADS_DNS_FORWARDER=10.1.1.98,8.8.8.8

# Join existing domain
ADS_JOIN_DOMAIN=true
ADS_JOIN_DC=ads1-98.avctn.lan
```

### Step 2: Deploy Second DC

```bash
# Deploy second DC using same compose file
docker compose -f docker-compose-ads.yml --env-file \
  /home/divix/divtools/docker/sites/s01-7692nw/ads2-99/.env.ads2-99 up -d

# Verify replication
docker exec ads1-98-dc samba-tool drs showrepl
docker exec ads2-99-dc samba-tool drs showrepl
```

## Testing and Validation

### Test Windows Domain Join

From Windows 10/11 workstation:

1. Open **System Properties** → **Computer Name** → **Change**
2. Select **Domain** and enter `avctn.lan`
3. Credentials: `Administrator` / `YourSecureAdminPassword123!`
4. Reboot and login with domain credentials

### Test Linux Domain Authentication

From Ubuntu client:

```bash
# Install required packages
sudo apt-get install sssd sssd-tools sssd-ldap sssd-ad

# Configure /etc/sssd/sssd.conf (see SSSD section in PROJECT-HISTORY.md)

# Join domain
sudo realm join -U Administrator avctn.lan

# Test user lookup
getent passwd Administrator@avctn.lan

# Test authentication
su - Administrator@avctn.lan
```

## Troubleshooting

### Common Issues

**1. DNS Resolution Failures**

```bash
# Check DNS configuration
docker exec ads1-98-dc cat /etc/resolv.conf

# Verify SRV records
docker exec ads1-98-dc host -t SRV _kerberos._tcp.avctn.lan

# Fix: Update DNS forwarders
docker exec ads1-98-dc samba-tool dns add localhost avctn.lan @ A 10.1.1.98
```

**2. Kerberos Ticket Issues**

```bash
# Check Kerberos config
docker exec ads1-98-dc cat /etc/krb5.conf

# Test ticket acquisition
docker exec ads1-98-dc kinit Administrator@AVCTN.LAN
docker exec ads1-98-dc klist
```

**3. Replication Problems**

```bash
# Force replication
docker exec ads1-98-dc samba-tool drs replicate ads2-99 ads1-98 DC=avctn,DC=lan

# Check replication status
docker exec ads1-98-dc samba-tool drs showrepl --verbose
```

**4. Container Won't Start**

```bash
# Check logs
docker logs ads1-98-dc

# Common causes:
# - Port conflicts (check with: netstat -tulpn | grep -E '53|88|389|445')
# - Permission issues on volumes
# - Invalid environment variables
```

## Backup and Recovery

### Create Backup

```bash
# Use backup script (to be created)
/home/divix/divtools/scripts/ads_backup.sh --dc ads1-98 --output /backup/ads

# Manual backup
docker exec ads1-98-dc samba-tool domain backup offline \
  --targetdir=/var/backups/samba

# Copy backup out of container
docker cp ads1-98-dc:/var/backups/samba /backup/ads/$(date +%Y%m%d)
```

### Restore from Backup

```bash
# Stop container
docker stop ads1-98-dc

# Remove existing data
rm -rf /home/divix/divtools/docker/sites/s01-7692nw/ads1-98/ads/data/*

# Restore backup
docker exec ads1-98-dc samba-tool domain backup restore \
  --backup-file=/var/backups/samba/backup.tar.bz2 \
  --targetdir=/var/lib/samba

# Start container
docker start ads1-98-dc
```

## Next Steps

1. **Configure Group Policies:** Use Windows RSAT tools to create and apply GPOs
2. **Create Users and Groups:** See `docs/USER-MANAGEMENT.md`
3. **Setup DNS Delegation:** See `docs/DNS-SETUP.md`
4. **Configure Multi-Site:** See `docs/MULTI-SITE-REPLICATION.md`
5. **Install Management Scripts:** See PROJECT-HISTORY.md for script requirements

## References

- **Samba Wiki:** <https://wiki.samba.org/index.php/Setting_up_Samba_as_an_Active_Directory_Domain_Controller>
- **Samba Man Pages:** <https://www.samba.org/samba/docs/current/man-html/>
- **PRD:** See `docs/PRD.md` for detailed requirements
- **PROJECT-HISTORY:** See `docs/PROJECT-HISTORY.md` for architecture decisions
