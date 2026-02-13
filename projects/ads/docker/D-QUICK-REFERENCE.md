# ADS Quick Reference

**Last Updated:** December 6, 2025

## Setup Script Commands

```bash
# Interactive menu
/home/divix/divtools/scripts/ads/dt_ads_setup.sh

# Test mode (no changes)
/home/divix/divtools/scripts/ads/dt_ads_setup.sh --test

# Debug mode (verbose)
/home/divix/divtools/scripts/ads/dt_ads_setup.sh --debug
```

## Container Management

### Using Divtools Aliases (Recommended)

```bash
# Start container (first time setup)
dcup samba-dc

# Stop container
dcstop samba-dc

# Restart container
dcrestart samba-dc

# View logs
dclogs samba-dc

# Shell access
dexec samba-dc /bin/bash
```

### Manual Docker Commands (Alternative)

```bash
# Start container (first time setup)
cd /home/divix/divtools/docker/sites/s01-7692nw/ads1-98
docker compose -f dc-ads1-98.yml up -d

# Stop container
docker stop samba-ads

# Restart container
docker restart samba-ads

# View logs
docker logs -f samba-ads

# Shell access
docker exec -it samba-ads /bin/bash
```

## Testing

```bash
# Run all tests
cd /home/divix/divtools/scripts/ads
source .venv/bin/activate
pytest test/ -v

# Run specific test category
pytest test/test_ads.py::TestDNS -v

# Run single test
pytest test/test_ads.py::TestDNS::test_dns_srv_records -v
```

## Bash Aliases (after installation)

### Using ADS Aliases (Recommended)

```bash
# Domain management
ads-status          # Domain info
ads-fsmo            # FSMO roles
ads-health          # Health check
ads-repl            # Replication status

# Container management
ads-shell           # Shell in container
ads-logs            # Follow logs
ads-restart         # Restart container
ads-start           # Start container
ads-stop            # Stop container

# User and group management
ads-users           # List users
ads-groups          # List groups
ads-user-create     # Create user
ads-group-addmember # Add user to group

# Testing and diagnostics
ads-dns-test        # Test DNS resolution
ads-ldap-test       # Test LDAP connectivity
ads-smb-test        # Test SMB connectivity
ads-kinit           # Test Kerberos authentication

# Configuration
ads-config          # Show Samba configuration
ads-krb5-show       # Show Kerberos configuration
ads-backup          # Create backup
```

### Manual Commands (Alternative)

```bash
# Domain management
samba-tool domain info 127.0.0.1
samba-tool fsmo show
samba-tool domain level show

# Container management
docker exec -it samba-ads /bin/bash
docker logs -f samba-ads
docker restart samba-ads
docker stop samba-ads

# User and group management
samba-tool user list
samba-tool group list
samba-tool user create username password
samba-tool group addmembers "Group Name" username

# Testing and diagnostics
docker exec -it samba-ads host -t SRV _ldap._tcp.avctn.lan
ldapsearch -H ldap://localhost -x -b "DC=avctn,DC=lan" -s base
smbclient -L localhost -U Administrator
kinit Administrator@AVCTN.LAN

# Configuration
docker exec -it samba-ads cat /etc/samba/smb.conf
docker exec -it samba-ads cat /etc/krb5.conf
# Backup commands vary
```

## Environment Variables

```bash
# Edit environment file
nano /home/divix/divtools/docker/sites/s01-7692nw/ads1-98/.env.ads1-98

# Required variables:
export ADS_DOMAIN="avctn.lan"
export ADS_REALM="AVCTN.LAN"
export ADS_WORKGROUP="AVCTN"
export ADS_ADMIN_PASSWORD="YourSecurePassword"
export ADS_HOST_IP="10.1.1.98"
export ADS_DNS_FORWARDER="8.8.8.8 8.8.4.4"
```

## File Locations

```text
Setup Script:
  /home/divix/divtools/scripts/ads/dt_ads_setup.sh

Implementation Guide:
  /home/divix/divtools/projects/ads/phase1-configs/IMPLEMENTATION-STEPS.md

Tests:
  /home/divix/divtools/scripts/ads/test/test_ads.py

Docker Compose:
  /home/divix/divtools/docker/sites/s01-7692nw/ads1-98/dc-ads1-98.yml
  /home/divix/divtools/docker/sites/s01-7692nw/ads1-98/samba/dci-samba.yml

Environment:
  /home/divix/divtools/docker/sites/s01-7692nw/ads1-98/.env.ads1-98

Data:
  /opt/samba/data/
  /opt/samba/config/
  /opt/samba/logs/
```

## Common Tasks

### First-Time Setup

```bash
# 1. Run setup script
/home/divix/divtools/scripts/ads/dt_ads_setup.sh

# 2. Select: ADS Setup
#    - Enter domain info
#    - Creates folders
#    - Deploys files

# 3. Select: Start Samba Container
#    - Watch logs during provisioning

# 4. Select: ADS Status Check
#    - Runs all tests
```

### Check Status

```bash
# Quick status
ads-status

# Full health check
ads-health

# Run all tests
cd /home/divix/divtools/scripts/ads
source .venv/bin/activate
pytest test/ -v
```

### Create User

```bash
# Create user
samba-tool user create johndoe 'SecurePass123!'

# Add to group
samba-tool group addmembers "Domain Users" johndoe

# Set password never expires
samba-tool user setexpiry johndoe --noexpiry
```

### View Logs

```bash
# Container logs
docker logs -f samba-ads

# Samba logs (from container)
docker exec samba-ads tail -f /var/log/samba/log.samba

# All Samba logs
docker exec samba-ads ls -la /var/log/samba/
```

### Backup

```bash
# Backup data
sudo tar -czf /backup/samba-$(date +%Y%m%d).tar.gz /opt/samba/data

# Backup configs
cd /home/divix/divtools
git add docker/sites/s01-7692nw/ads1-98/
git commit -m "Backup ADS configuration"
```

### Troubleshooting

```bash
# Check container status
docker ps | grep samba-ads
docker inspect samba-ads

# Check DNS
docker exec samba-ads host -t SRV _ldap._tcp.avctn.lan

# Check LDAP
ldapsearch -H ldap://localhost -x -b "" -s base

# Check time sync
date
docker exec samba-ads date

# Check ports
sudo ss -tulpn | grep -E ':(53|88|389|445)\b'

# Restart systemd-resolved (if needed)
sudo systemctl restart systemd-resolved

# Stop systemd-resolved (to free port 53)
sudo systemctl stop systemd-resolved
sudo systemctl mask systemd-resolved
```

## Integration

### With docker_ps.sh

```bash
docker_ps.sh
# Shows container in 'ads' group
```

### With dt_host_setup.sh

Environment variables follow the same pattern:

- Stored in `.env.$HOSTNAME`
- Auto-managed markers
- Loaded on subsequent runs

### With Bash Profile

Uses same logging utilities:

- `log "INFO" "message"`
- `log "WARN" "message"`
- `log "ERROR" "message"`
