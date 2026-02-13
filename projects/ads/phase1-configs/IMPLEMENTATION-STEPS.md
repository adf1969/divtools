# Phase 1 Implementation Steps - Samba AD DC Deployment

**Last Updated:** December 5, 2025

This document provides step-by-step instructions for deploying the Samba Active Directory Domain Controller using the configuration files generated in `projects/ads/phase1-configs/`.

## Prerequisites

// TODO THis is it.

Before starting deployment:

- [X] Ubuntu Server 22.04 or Debian 12 installed on ads1-98
- [X] Docker and Docker Compose V2 installed
- [X] Static IP configured (10.1.1.98 for primary DC)
- [X] NTP time synchronization configured
- [X] Hostname set correctly: `hostnamectl set-hostname ads1-98.avctn.lan`
- [x] Create snapshot of ads1-98 VM for rollback capability

## Directory Structure Overview

```
Projects (source):
/home/divix/divtools/projects/ads/phase1-configs/
├── docker-compose/
│   ├── dci-samba.yml          → Deploy to sites folder
│   ├── dc-ads1-98.yml         → Deploy to sites folder
│   ├── .env.samba             → Deploy to sites folder (customize first)
│   └── .env.samba.example     → Reference only
├── scripts/
│   └── entrypoint.sh          → Deploy to sites folder
└── aliases/
    └── samba-aliases.sh       → Append to ~/.bash_aliases

Deployment (destination):
/home/divix/divtools/docker/sites/s01-7692nw/ads1-98/
├── dc-ads1-98.yml             # Host-level compose
└── samba/
    ├── dci-samba.yml          # Samba service compose
    ├── .env.samba             # Environment variables (customized)
    └── entrypoint.sh          # Container initialization

System directories (created automatically):
/opt/samba/
├── data/                      # Persisted Samba data (/var/lib/samba)
├── config/                    # Runtime configs (/etc/samba)
└── logs/                      # Samba logs (/var/log/samba)
```

## Step 0: Configure NTP time synchronization

- [ ] **Configure NTP time synchronization**

Time synchronization is critical for Kerberos and AD replication. Complete one of the following options on the host (`ads1-98`) **before** provisioning the domain.

Option A — Install and configure `chrony` (recommended):

```bash
# Install chrony
sudo apt update
sudo apt install -y chrony

# Backup original config
sudo cp /etc/chrony/chrony.conf /etc/chrony/chrony.conf.orig

# Use public pool servers or your local NTP server
sudo tee /etc/chrony/chrony.conf > /dev/null <<'EOF'
pool 0.pool.ntp.org iburst
pool 1.pool.ntp.org iburst
pool 2.pool.ntp.org iburst
pool 3.pool.ntp.org iburst
driftfile /var/lib/chrony/chrony.drift
makestep 1 -1
rtcsync
EOF

# Restart and enable
sudo systemctl restart chrony
sudo systemctl enable chrony

# Verify sync status
chronyc tracking
timedatectl status
```

Option B — Use `systemd-timesyncd` (lightweight):

```bash
sudo apt update
sudo apt install -y systemd-timesyncd
sudo timedatectl set-ntp true
sudo systemctl restart systemd-timesyncd
timedatectl status
```

DECISION: Chose Option B. timesyncd is already installed.
I configured this with: timedatectl status

Verification:

- Ensure the system clock is within 5 minutes of a valid time source: `date` and `docker exec -it samba-ads date` (after container start).
- If using a local NTP server, replace the `pool` lines above with your internal server IP or hostname.

Once NTP is configured, mark the prerequisite as completed and proceed to Step 1.

## Host domain membership checks (important)

- [x] **Verify host is not domain-joined**
- [x] **Clean up domain membership if needed**
- [ ] **Stop systemd-resolved to free port 53**

If this host was previously joined to the `avctn.lan` domain as a client, you must cleanly remove that membership before provisioning the host as a Domain Controller. The output you provided indicates several useful facts:

- `realm` is not installed: the machine was not necessarily joined via `realmd`.
- `sssd` is installed but inactive (skipped): no active SSSD domain client running.
- `winbind` is not installed: likely not joined via winbind/net ads.
- `klist` is not installed: no Kerberos client tools present to inspect tickets.
- `systemd-resolved` is listening on `127.0.0.53:53` and `127.0.0.54:53` — DNS is handled locally by systemd-resolved and will conflict with any service binding to host port 53.

Interpretation: Based on these results, the host does not appear to be actively joined as a domain client (no active SSSD or winbind, and `realm` not installed). That means it is safe to provision as a DC, *but* you must address the local DNS listener before starting Samba (port 53 conflict).

Recommended quick checks (run on the host):

```bash
# Check for realmd/sssd/winbind services and client joins
which realm || echo "realm not installed"
systemctl is-enabled --quiet sssd && systemctl status sssd --no-pager || echo "sssd inactive or not enabled"
which wbinfo || echo "winbind not installed"
which klist || echo "krb5 client not installed"

# Check ports that will conflict with a DC
sudo ss -tulpn | grep -E ':(53|88|389|445)\b' || true

# Check for existing Kerberos tickets (if klist installed)
klist || true
```

If these checks show an active domain client (e.g., `sssd` active, `wbinfo -u` returns users, `realm list` shows the domain), do NOT provision the DC on this host until you unjoin it cleanly. Recommended safe approach:

1. Snapshot the VM now for rollback.

2. Backup client config files you may need later:

```bash
sudo cp -a /etc/sssd /root/sssd.bak || true
sudo cp -a /etc/krb5.conf /root/krb5.conf.bak || true
sudo cp -a /etc/samba/smb.conf /root/smb.conf.bak || true
```

1. If joined with `realmd` / `sssd`:

```bash
# Remove realm membership (if realmd installed)
sudo apt update && sudo apt install -y realmd || true
sudo realm leave --verbose avctn.lan || true

# Stop and disable SSSD
sudo systemctl stop sssd || true
sudo systemctl disable sssd || true
sudo rm -rf /var/lib/sss /var/cache/sss /etc/sssd/sssd.conf || true
```

1. If joined with `winbind`/`net ads`:

```bash
sudo apt update && sudo apt install -y samba winbind || true
sudo net ads leave -U Administrator || true
sudo systemctl stop winbind || true
sudo systemctl disable winbind || true
```

1. Handle `systemd-resolved` DNS conflict (must be addressed before starting Samba)

By default Ubuntu's `systemd-resolved` listens on `127.0.0.53` for DNS. Samba's AD DNS needs host port 53 available. Two safe options:

- Option A (recommended for provisioning): stop and mask `systemd-resolved` so Samba can bind to port 53.

```bash
# Backup resolv.conf
sudo cp /etc/resolv.conf /root/resolv.conf.bak || true

# Stop and mask resolved
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved
sudo systemctl mask systemd-resolved

# Replace /etc/resolv.conf with a sensible default that points to external DNS until Samba is started
echo -e "nameserver 8.8.8.8\nsearch avctn.lan" | sudo tee /etc/resolv.conf

# Verify no process listens on 53
sudo ss -tulpn | grep -E ':(53|88|389|445)\\b' || true
```

- Option B (less intrusive): configure `systemd-resolved` to not bind the loopback listener and forward to external servers — more complex and OS-specific; not recommended for first-time provisioning.

1. After cleanup verify ports are free and no client services remain:

```bash
sudo ss -tulpn | grep -E ':(53|88|389|445)\\b' || true
systemctl status sssd || true
which wbinfo || true
```

If everything looks clear (no active client services, no listeners on critical ports), proceed with the regular provisioning steps in Step 1.

If you prefer, I can add an interactive cleanup script to `projects/ads/phase1-configs/scripts/` that performs safe backups and prompts before each destructive action. Tell me if you want that and I'll create it.

## Step 1: Create Directory Structure

- [ ] **Create directory structure**
- [ ] **Set ownership and permissions**

```bash
# Create sites directory structure
sudo mkdir -p /home/divix/divtools/docker/sites/s01-7692nw/ads1-98/samba

# Create system directories for persisted data
sudo mkdir -p /opt/samba/{data,config,logs}

# Set ownership (adjust user/group as needed)
sudo chown -R $(whoami):$(whoami) /home/divix/divtools/docker/sites/s01-7692nw/ads1-98
sudo chown -R root:root /opt/samba

# Set permissions
sudo chmod 755 /opt/samba
sudo chmod 700 /opt/samba/data       # Sensitive data
sudo chmod 755 /opt/samba/config
sudo chmod 755 /opt/samba/logs
```

## Step 2: Deploy Configuration Files

- [ ] **Copy docker-compose files**
- [ ] **Copy entrypoint script**
- [ ] **Make entrypoint executable**

## Step 3: Customize Environment Variables

- [ ] **Edit .env.samba file**
- [ ] **Set ADS_ADMIN_PASSWORD**
- [ ] **Verify domain settings**

## Step 4: Configure Docker Network

- [ ] **Create or verify site network**

## Step 5: Install Bash Aliases

- [ ] **Append aliases to ~/.bash_aliases**
- [ ] **Reload aliases**

## Step 6: Start Samba Container

- [ ] **Start Samba container**
- [ ] **Watch provisioning logs**
- [ ] **Wait for provisioning completion**

### Using Divtools Aliases (Recommended)

```bash
# Start the container using divtools alias
dcstart samba-dc

# Watch the logs during provisioning (takes 2-5 minutes)
dclogs samba-dc

# Press Ctrl+C when you see "Samba is now running in foreground mode"
```

### Manual Docker Commands (Alternative)

```bash
# Navigate to host directory
cd /home/divix/divtools/docker/sites/s01-7692nw/ads1-98

# Start the container (will provision domain on first run)
docker compose -f dc-ads1-98.yml up -d

# Watch the logs during provisioning (takes 2-5 minutes)
docker logs -f samba-ads

# Press Ctrl+C when you see "Samba is now running in foreground mode"
```

### What Happens When You Run `dcstart samba-dc`

The `dcstart samba-dc` command triggers this sequence:

1. **Alias Resolution**: `dcstart` → `dcrun start samba-dc`
2. **dcrun Function**: Uses `get_docker_compose_file()` to find your `dc-ads1-98.yml`
3. **Docker Compose**: Runs `sudo -E docker compose --profile all -f dc-ads1-98.yml start samba-dc`
4. **Container Start**: The `samba-dc` service starts in the background
5. **Entrypoint Execution**: The `entrypoint.sh` script runs inside the container

#### Entrypoint Script Execution Steps

The entrypoint script (`/usr/local/bin/entrypoint.sh`) performs these actions:

1. **Environment Check**: Validates all required ADS_* environment variables
2. **Domain Detection**: Checks if `/var/lib/samba` directory exists and contains domain data
3. **First-Time Setup**: If no domain exists, runs `samba-tool domain provision`
4. **Provisioning Process**:
   - Creates the AD forest and domain
   - Sets up the domain controller role
   - Generates `smb.conf` configuration
   - Creates Kerberos configuration
   - Initializes the LDAP directory
   - Sets up DNS zones
5. **Service Start**: Launches Samba in foreground mode with all services active

#### Expected Log Output During Provisioning

```
Starting Samba AD DC provisioning...
Domain provisioned successfully
Setting up secrets.ldb
Setting up the registry
Setting up the privileges database
Setting up idmap db
Setting up SAM db
Setting up sam.ldb partitions and settings
Setting up sam.ldb rootDSE
Pre-loading the Samba 4 and AD schema
Adding DomainDN: DC=avctn,DC=lan
Adding configuration container
Setting up sam.ldb schema
Setting up configuration data
Setting up sam.ldb data
Setting up display specifiers
Modifying display specifiers and extended rights
Adding users container
Modifying users container
Adding computers container
Modifying computers container
Setting up sam.ldb indexes
Adding builtin groups and roles
Adding privileged groups
Adding default groups
Administrator password has been set
Setting up self join
Setting up sam.ldb rootDSE marking as synchronized
Setting up dirsync cookie
Setting up NTLM trusts
Setting up sam.ldb rootDSE netlogon
Setting up sam.ldb rootDSE partitions
Setting up sam.ldb ACLs
Setting up Kerberos configuration
Setting up DNS configuration
Setting up DNS dynamic updates
Samba is now running in foreground mode
```

**What happens during first start:**

1. Entrypoint script detects no existing domain
2. Creates directory structure in `/opt/samba/data` (host-mounted to `/var/lib/samba`)
3. Runs `samba-tool domain provision` with your configured parameters
4. Generates `smb.conf` and Kerberos configuration files
5. Starts Samba in foreground mode with DNS, LDAP, Kerberos, and SMB services

## What Happens When You Run `dcup samba-dc` (First-Time Setup)

**Note**: For initial container creation and domain provisioning, use `dcup samba-dc`. The `dcstart samba-dc` command only works for restarting an already-created container.

The `dcup samba-dc` command creates and starts the Samba AD DC container in the divtools environment. Here's what occurs step-by-step:

### 1. Command Resolution

- **Input**: `dcup samba-dc`
- **Alias Resolution**: `dcup` → `dcrun up -d --build --remove-orphans samba-dc`
- **dcrun Function**: Uses `get_docker_compose_file()` to locate your compose file
- **Result**: `sudo -E docker compose --profile all -f dc-ads1-98.yml up -d --build --remove-orphans samba-dc`

### 2. Docker Compose Execution

- **Compose File**: `dc-ads1-98.yml` (includes `dci-samba.yml`)
- **Service**: `samba-dc` (defined in `dci-samba.yml`)
- **Image**: `ubuntu:22.04` (base image - samba installed at runtime)
- **Container**: `samba-ads` (created from Ubuntu 22.04 with samba installed)

### 3. Image and Container Creation

- **Image Pull/Build**: Downloads `ubuntu:22.04` if not cached
- **Container Creation**: Creates `samba-ads` container with mounted volumes
- **Volume Mounting**:
  - `/opt/samba/data` → `/var/lib/samba` (domain database)
  - `/opt/samba/config` → `/etc/samba` (configuration files)
  - `/opt/samba/logs` → `/var/log/samba` (log files)
- **Entrypoint Execution**: `/usr/local/bin/entrypoint.sh` runs

### 4. Samba Installation (First-Time Only)

The entrypoint script checks if samba is installed and installs it if needed:

```bash
apt-get update && apt-get install -y samba krb5-user winbind
```

### 5. Domain Provisioning (First-Time Only)

If no existing domain database is found, the entrypoint script performs:

1. **Domain Detection**: Checks for existing `/var/lib/samba` content
2. **Provisioning Command**: `samba-tool domain provision` with your configured parameters
3. **Database Creation**: Initializes LDAP directory, user accounts, groups
4. **Configuration Generation**: Creates `smb.conf` and Kerberos config
5. **Service Initialization**: Starts Samba services (SMB, LDAP, DNS, Kerberos)

### 6. Service Activation

After provisioning, these network services become available:

- **DNS**: Port 53 (TCP/UDP) - Internal domain DNS
- **LDAP**: Port 389 (TCP) - Directory services  
- **LDAPS**: Port 636 (TCP) - Encrypted LDAP
- **Kerberos**: Port 88 (TCP/UDP) - Authentication
- **SMB/CIFS**: Port 445 (TCP) - File sharing
- **NetBIOS**: Port 139 (TCP) - Legacy SMB

### 6. Health Checks

- **Container Health**: Docker health check runs `samba-tool domain info 127.0.0.1`
- **Service Readiness**: All services must be responding before container is marked healthy
- **Timeout**: 120 second startup period, 60 second check interval

### 7. Expected Outcomes

- **Container Status**: `docker ps` shows `samba-ads` running
- **Service Status**: `ads-status` shows domain information
- **DNS Resolution**: `nslookup ads1-98.avctn.lan` works
- **Authentication**: `kinit Administrator@AVCTN.LAN` succeeds

### 8. Monitoring and Logs

- **Log Location**: Container logs via `dclogs samba-dc`
- **Samba Logs**: Available at `/opt/samba/logs/` on host
- **Health Monitoring**: `ads-health` for comprehensive status

### 9. Troubleshooting

If startup fails:

- Check logs: `dclogs samba-dc`
- Verify environment: `ads-status`
- Check port conflicts: `sudo ss -tulpn | grep -E ':(53|88|389|445)\b'`
- Verify permissions: `ls -la /opt/samba/`

### 10. Integration with Divtools

- **Service Discovery**: Container automatically registers with divtools monitoring
- **Alias Availability**: ADS-specific aliases become available after startup
- **Backup Integration**: Container data is included in divtools backup procedures

#### Post-Provisioning Services

After successful provisioning, these services are active:

- **DNS Server**: Port 53 (TCP/UDP) - Internal DNS for domain resolution
- **LDAP Server**: Port 389 (TCP) - Directory services
- **LDAPS Server**: Port 636 (TCP) - Encrypted LDAP
- **Kerberos KDC**: Port 88 (TCP/UDP) - Authentication
- **Kerberos Kpasswd**: Port 464 (TCP/UDP) - Password changes
- **SMB/CIFS**: Port 445 (TCP) - File sharing
- **NetBIOS**: Port 139 (TCP) - Legacy SMB support
- **Global Catalog**: Port 3268 (TCP) - Forest-wide directory search
- **Global Catalog SSL**: Port 3269 (TCP) - Encrypted global catalog

## Step 7: Verify Domain Functionality

- [ ] **Reload bash aliases**
- [ ] **Check domain status**
- [ ] **List FSMO roles**
- [ ] **Test DNS resolution**
- [ ] **Test LDAP**
- [ ] **Test Kerberos authentication**
- [ ] **Test SMB connectivity**

After container starts successfully, run these verification steps:

### Using Divtools Aliases (Recommended)

```bash
# Reload aliases to detect the running container
source ~/.bash_aliases

# Check domain status (using alias)
ads-status

# Expected output:
# Forest           : avctn.lan
# Domain           : avctn.lan
# Netbios domain   : AVCTN
# DC name          : ads1-98
# ...

# List FSMO roles
ads-fsmo

# Test DNS resolution
ads-dns-test

# Test LDAP
ads-ldap-test

# Test Kerberos authentication
ads-kinit

# Test SMB connectivity
ads-smb-test
```

### Manual Commands (Alternative)

```bash
# Check domain status (using alias)
ads-status

# Expected output:
# Forest           : avctn.lan
# Domain           : avctn.lan
# Netbios domain   : AVCTN
# DC name          : ads1-98
# ...

# List FSMO roles
ads-fsmo

# Test DNS resolution
docker exec -it samba-ads host -t SRV _ldap._tcp.avctn.lan

# Test LDAP
ldapsearch -H ldap://localhost -x -b "DC=avctn,DC=lan" -s base

# Test Kerberos authentication
kinit Administrator@AVCTN.LAN
# Enter password when prompted
klist

# Test SMB connectivity
smbclient -L localhost -U Administrator
# Enter password when prompted
```

## Step 8: Create Test User

- [ ] **Create test user**
- [ ] **Verify user creation**
- [ ] **Set password to never expire**
- [ ] **Add user to Domain Admins**

```bash
# Create a test user (using alias)
ads-user-create testuser 'TestPassword123!'

# Verify user was created
ads-users | grep testuser

# Set user password to never expire (for testing)
samba-tool user setexpiry testuser --noexpiry

# Add user to Domain Admins (for testing)
ads-group-addmember "Domain Admins" testuser
```

## Step 9: Configure DNS on ads1-98 Host

- [ ] **Backup resolv.conf**
- [ ] **Update resolv.conf to use localhost DNS**
- [ ] **Configure systemd-resolved (if used)**
- [ ] **Restart systemd-resolved**

Point the ads1-98 host to use the Samba DC for DNS:

```bash
# Backup current resolv.conf
sudo cp /etc/resolv.conf /etc/resolv.conf.backup

# Edit resolv.conf
sudo nano /etc/resolv.conf
```

Change to:

```
nameserver 127.0.0.1
nameserver 8.8.8.8
search avctn.lan
```

For persistent configuration (Ubuntu 22.04 with systemd-resolved):

```bash
# Edit systemd-resolved config
sudo nano /etc/systemd/resolved.conf
```

Add:

```ini
[Resolve]
DNS=127.0.0.1 8.8.8.8
Domains=avctn.lan
```

Restart resolved:

```bash
sudo systemctl restart systemd-resolved
```

## Step 10: Test Windows Client Domain Join

- [ ] **Configure DNS on Windows VM**
- [ ] **Join Windows VM to domain**
- [ ] **Restart Windows VM**
- [ ] **Login with domain credentials**

From a Windows 10/11 VM:

1. **Configure DNS:**
   - Set DNS server to 10.1.1.98 (the Samba DC)

2. **Join Domain:**
   - Right-click **This PC** → **Properties**
   - Click **Advanced system settings**
   - Click **Computer Name** tab → **Change**
   - Select **Domain** and enter: `avctn.lan`
   - Click **OK**
   - Enter credentials: `Administrator` / [your password]
   - Restart when prompted

3. **Login:**
   - At login screen, use: `AVCTN\Administrator` or `Administrator@avctn.lan`

## Step 11: Health Check and Monitoring

- [ ] **Run full health check**
- [ ] **View logs**
- [ ] **Check replication status**
- [ ] **View current connections**
- [ ] **Check for errors in logs**

Run these commands periodically to ensure DC health:

```bash
# Full health check
ads-health

# View logs
ads-logs

# Check replication (shows this DC only for now)
ads-repl

# View current connections
smbstatus

# Check for errors in logs
ads-log log.samba | grep -i error
```

## Step 12: Backup Configuration

- [ ] **Create backup directory**
- [ ] **Backup Samba data**
- [ ] **Commit compose files to git**

Create initial backup:

```bash
# Create backup directory
sudo mkdir -p /backup/samba

# Backup current state
ads-backup /backup/samba/initial-provision-$(date +%Y%m%d)

# Backup compose files and configs (version control)
cd /home/divix/divtools
git add docker/sites/s01-7692nw/ads1-98/samba/
git commit -m "Add Samba AD DC configuration for ads1-98"
```

## Troubleshooting

### Container Won't Start

```bash
# Check logs (using alias)
dclogs samba-dc

# Or manually
docker logs samba-ads

# Common issues:
# - Port 53, 88, 389, or 445 already in use
sudo ss -tulpn | grep -E ':(53|88|389|445)\b'
```

### DNS Not Working

```bash
# Verify DNS forwarder in smb.conf (using alias)
ads-config | grep "dns forwarder"

# Test DNS from inside container (using alias)
ads-dns-test

# Or manually
docker exec -it samba-ads host -t SRV _ldap._tcp.avctn.lan

# Check if port 53 is accessible
nc -zv 10.1.1.98 53
```

### Kerberos Authentication Failing

```bash
# Check time synchronization (CRITICAL - must be within 5 minutes)
date
docker exec -it samba-ads date

# Verify krb5.conf (using alias)
ads-krb5-show

# Or manually
docker exec -it samba-ads cat /etc/krb5.conf

# Test ticket acquisition (using alias)
ads-kinit

# Or manually
kinit Administrator@AVCTN.LAN
klist -e
```

### Domain Provision Failed

```bash
# Stop container
docker stop samba-ads

# Remove incomplete data
sudo rm -rf /opt/samba/data/*
sudo rm -rf /opt/samba/config/*

# Start container again (will re-provision)
docker start samba-ads
docker logs -f samba-ads
```

## Next Steps

After successful deployment:

1. **Add Second DC (Phase 1b):** Deploy ads2-99 for high availability
2. **Create OUs:** Organize users, groups, computers into OUs
3. **Create Groups:** Set up security and distribution groups
4. **Configure GPOs:** Use Windows RSAT tools to create Group Policies
5. **Join Linux Clients:** Configure SSSD on Ubuntu systems
6. **Setup Monitoring:** Integrate with Prometheus/InfluxDB
7. **Schedule Backups:** Automate daily backups

## File Deployment Reference

| Source File | Destination | Purpose |
|-------------|-------------|---------|
| `docker-compose/dci-samba.yml` | `sites/$SITE/$HOST/samba/` | Samba service definition |
| `docker-compose/dc-ads1-98.yml` | `sites/$SITE/$HOST/` | Host-level compose |
| `docker-compose/.env.samba` | `sites/$SITE/$HOST/samba/` | Environment variables |
| `scripts/entrypoint.sh` | `sites/$SITE/$HOST/samba/` | Container init script |
| `aliases/samba-aliases.sh` | Append to `~/.bash_aliases` | Command shortcuts |

## Volume Mapping Reference

| Container Path | Host Path | Purpose |
|----------------|-----------|---------|
| `/var/lib/samba` | `/opt/samba/data` | Domain database, SYSVOL |
| `/etc/samba` | `/opt/samba/config` | Runtime configs |
| `/var/log/samba` | `/opt/samba/logs` | Service logs |
| `/usr/local/bin/entrypoint.sh` | `sites/$SITE/$HOST/samba/entrypoint.sh` | Init script |

## Container Image Architecture

### Why Ubuntu 22.04, Not a Pre-Built Samba Image?

**The Problem:**
- No official Samba AD DC Docker image exists
- `servercontainers/samba`: Designed for file sharing (SMB shares), not AD DC provisioning
- `ubuntu/samba:latest`: Referenced in original templates but never created
- Other samba containers: Outdated or unmaintained

**Our Solution: Ubuntu 22.04 + Runtime Samba Installation**

```
docker-compose.yml specifies: image: ubuntu:22.04
       ↓
dcup samba-dc creates container from Ubuntu 22.04
       ↓
Container starts, entrypoint.sh runs automatically
       ↓
entrypoint.sh checks: "is samba-tool available?"
       ↓
If NO → apt-get update && apt-get install -y samba krb5-user winbind
       ↓
samba-tool domain provision creates:
   • LDAP directory (/var/lib/samba)
   • smb.conf configuration file
   • krb5.conf Kerberos config
   • User/group databases
       ↓
Samba starts with all services active (LDAP, DNS, Kerberos, SMB)
```

**Why This Works Well:**

✅ **Ubuntu 22.04 is the recommended base OS** for Samba 4.15+ (LTS release, well-maintained)
✅ **Samba packages compiled by Ubuntu maintainers** = optimized for Ubuntu, fewer dependencies
✅ **Transparent to operators**: Anyone can see "oh, it's Ubuntu running samba services"
✅ **No proprietary image magic**: Easy to troubleshoot, inspect, modify
✅ **Official, maintained packages**: Security updates flow from Ubuntu repos
✅ **Standard Linux tools available**: ssh, curl, jq, etc. for debugging

**Trade-offs:**

⚠️ First container creation is slower (apt-get update + install ~30-60 seconds)
⚠️ Larger image size than stripped-down samba-only images (but only matters for first pull)
⚠️ Not pre-optimized for samba (but Ubuntu packages are well-optimized anyway)

**How the Entrypoint Script Works:**

```bash
# entrypoint.sh executes at container startup

# 1. Check if samba is already installed
if ! command -v samba-tool &> /dev/null; then
    log "Samba not found, installing..."
    apt-get update && apt-get install -y samba krb5-user winbind
    log "Samba installed successfully"
fi

# 2. Check if domain is already provisioned
if [ -f /var/lib/samba/private/sam.ldb ]; then
    log "Domain already provisioned. Starting existing domain controller..."
    # (domain already exists, just start services)
else
    log "No existing domain found. Provisioning new domain..."
    # (run samba-tool domain provision with your settings)
    samba-tool domain provision \
        --server-role="${SERVER_ROLE}" \
        --use-rfc2307 \
        --dns-backend="${DNS_BACKEND}" \
        --realm="${REALM}" \
        --domain="${WORKGROUP}" \
        --adminpass="${ADMIN_PASSWORD}" \
        # ... more options from .env.samba
fi

# 3. Start Samba in foreground mode
exec samba
```

**Key Points:**
- The entrypoint runs **every time the container starts**
- If domain DB exists (`/var/lib/samba/private/sam.ldb`): just start services
- If domain DB missing: provision new domain from scratch
- Environment variables come from `.env.samba` file (mounted via docker-compose)

## References

- **PROJECT-HISTORY:** `docs/PROJECT-HISTORY.md` - Architecture decisions
- **PRD:** `docs/PRD.md` - Requirements and specifications
- **SAMBA-CONFIGURATION:** `docs/SAMBA-CONFIGURATION.md` - Configuration guide
- **DEPLOYMENT-GUIDE:** `docs/DEPLOYMENT-GUIDE.md` - Detailed deployment info
