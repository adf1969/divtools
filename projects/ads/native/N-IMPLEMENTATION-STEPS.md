# Native Samba AD DC Implementation Steps

**Last Updated:** 1/27/2025 10:00:00 PM CST

This guide provides step-by-step instructions for deploying Samba Active Directory Domain Controller natively on Ubuntu 24.04.

## Prerequisites

- **Ubuntu 24.04 LTS** installed on ads1-98
- **Static IP address** configured (e.g., 10.1.1.98)
- **Root or sudo access**
- **Divtools installed** at `/home/divix/divtools`

## Phase 1: Host Preparation

### Step 1.1: Verify Hostname

Ensure the hostname is set correctly:

```bash
# Check current hostname
hostnamectl

# Set if needed
sudo hostnamectl set-hostname ads1-98.avctn.lan
```

### Step 1.2: Configure Static IP

Ensure static IP is configured (not DHCP):

```bash
# Check current IP
ip addr show

# Verify static configuration
cat /etc/netplan/*.yaml
```

### Step 1.3: Update System

```bash
sudo apt-get update
sudo apt-get upgrade -y
```

## Phase 2: Install Samba

### Step 2.1: Run Installation Script

```bash
# Launch the native installation script
sudo /home/divix/divtools/scripts/ads/dt_ads_native.sh
```

### Step 2.2: Install Samba Packages

Select **Option 1: Install Samba** from the menu.

This installs:
- `samba` - Core Samba server
- `krb5-user` - Kerberos client utilities
- `winbind` - Windows integration service
- `smbclient` - SMB client for testing

**Note:** During installation, Kerberos configuration prompts will appear:
- **Default Kerberos realm:** `AVCTN.LAN`
- **Kerberos servers:** `ads1-98.avctn.lan`
- **Administrative server:** `ads1-98.avctn.lan`

## Phase 3: Configure Environment

### Step 3.1: Set Environment Variables

Select **Option 2: Configure Environment Variables** from the menu.

Enter values when prompted:

| Variable | Value | Description |
|----------|-------|-------------|
| `REALM` | `AVCTN.LAN` | Kerberos realm (uppercase domain) |
| `DOMAIN` | `avctn` | NetBIOS domain name (lowercase) |
| `ADMIN_PASSWORD` | `<your_password>` | Administrator password |
| `IP_ADDRESS` | `10.1.1.98` | Static IP of this DC |

These values are stored in `/opt/ads-native/.env.ads`.

### Step 3.2: Verify Configuration

```bash
# Check environment file
sudo cat /opt/ads-native/.env.ads
```

## Phase 4: Provision Domain

### Step 4.1: Run Domain Provision

Select **Option 3: Provision Domain** from the menu.

This runs:

```bash
samba-tool domain provision \
  --realm=AVCTN.LAN \
  --domain=AVCTN \
  --adminpass="<password>" \
  --server-role=dc \
  --use-rfc2307
```

**Expected Output:**

```
Looking up IPv4 addresses
Looking up IPv6 addresses
No IPv6 address will be assigned
Setting up share.ldb
Setting up secrets.ldb
Setting up the registry
Setting up the privileges database
Setting up idmap db
Setting up SAM db
Setting up sam.ldb partitions and settings
Setting up sam.ldb rootDSE
Pre-loading the Samba 4 and AD schema
Adding DomainDN: DC=avctn,DC=lan
...
A Kerberos configuration suitable for Samba AD has been generated at /var/lib/samba/private/krb5.conf
Once the above files are installed, your Samba AD server will be ready to use
Server Role:           active directory domain controller
Hostname:              ads1-98
NetBIOS Domain:        AVCTN
DNS Domain:            avctn.lan
DOMAIN SID:            S-1-5-21-...
```

### Step 4.2: Verify Kerberos Configuration

The provision process creates `/var/lib/samba/private/krb5.conf`. Copy it to system location:

```bash
sudo cp /var/lib/samba/private/krb5.conf /etc/krb5.conf
```

**Note:** The script may automate this step.

## Phase 5: Configure DNS

### Step 5.1: Stop systemd-resolved

Select **Option 4: Configure Host DNS** from the menu.

This performs:

1. **Stops systemd-resolved** (conflicts with Samba DNS on port 53)
2. **Disables systemd-resolved** (prevents restart on reboot)
3. **Updates /etc/resolv.conf** to use localhost DNS

**Manual equivalent:**

```bash
# Stop systemd-resolved
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved

# Update resolv.conf
sudo rm /etc/resolv.conf  # Remove symlink
echo "nameserver 127.0.0.1" | sudo tee /etc/resolv.conf
echo "search avctn.lan" | sudo tee -a /etc/resolv.conf
```

### Step 5.2: Verify DNS Configuration

```bash
# Check resolv.conf
cat /etc/resolv.conf
# Should show:
# nameserver 127.0.0.1
# search avctn.lan

# Verify systemd-resolved is stopped
sudo systemctl status systemd-resolved
# Should show: inactive (dead)
```

## Phase 6: Start Samba Services

### Step 6.1: Start samba-ad-dc

Select **Option 5: Start Samba Services** from the menu.

This runs:

```bash
sudo systemctl unmask samba-ad-dc
sudo systemctl enable samba-ad-dc
sudo systemctl start samba-ad-dc
```

### Step 6.2: Verify Service Status

```bash
# Check service status
sudo systemctl status samba-ad-dc

# Expected output:
# ● samba-ad-dc.service - Samba AD Daemon
#      Loaded: loaded (/lib/systemd/system/samba-ad-dc.service; enabled)
#      Active: active (running) since ...
```

### Step 6.3: Check Listening Ports

```bash
# Verify Samba is listening on required ports
sudo netstat -tulpn | grep samba

# Expected ports:
# 53   (DNS)
# 88   (Kerberos)
# 389  (LDAP)
# 636  (LDAPS)
# 464  (Kerberos Password)
# 3268 (Global Catalog)
# 3269 (Global Catalog SSL)
```

## Phase 7: Health Checks

### Step 7.1: Run Health Checks

Select **Option 9: Run Health Checks** from the menu.

Or run manually:

```bash
# Domain info
sudo samba-tool domain info 127.0.0.1

# FSMO roles
sudo samba-tool fsmo show

# Replication status
sudo samba-tool drs showrepl
```

### Step 7.2: Test DNS

```bash
# Test SRV records
host -t SRV _ldap._tcp.avctn.lan
host -t SRV _kerberos._tcp.avctn.lan

# Test A record
host ads1-98.avctn.lan

# Expected output:
# ads1-98.avctn.lan has address 10.1.1.98
```

### Step 7.3: Test Kerberos

```bash
# Get Kerberos ticket
kinit administrator@AVCTN.LAN
# Enter password when prompted

# List tickets
klist

# Expected output:
# Ticket cache: FILE:/tmp/krb5cc_...
# Default principal: administrator@AVCTN.LAN
# 
# Valid starting     Expires            Service principal
# ...                ...                krbtgt/AVCTN.LAN@AVCTN.LAN
```

### Step 7.4: Test SMB

```bash
# List shares as administrator
smbclient -L localhost -U administrator
# Enter password

# Expected output:
# Sharename       Type      Comment
# ---------       ----      -------
# sysvol          Disk      
# netlogon        Disk      
# IPC$            IPC       IPC Service (Samba 4.x.x)
```

## Phase 8: Create Test User

### Step 8.1: Add User via samba-tool

```bash
# Add a test user
sudo samba-tool user add testuser
# Enter password when prompted

# List users
sudo samba-tool user list
```

### Step 8.2: Verify User Authentication

```bash
# Get Kerberos ticket for test user
kinit testuser@AVCTN.LAN
klist

# Verify LDAP entry
ldapsearch -H ldap://localhost -D "cn=administrator,cn=users,dc=avctn,dc=lan" \
  -W -b "cn=users,dc=avctn,dc=lan" "(sAMAccountName=testuser)"
```

## Phase 9: Install Bash Aliases

### Step 9.1: Source Aliases

The script should create aliases automatically. Verify:

```bash
# Check if aliases are loaded
type ads-status

# If not, source manually
source ~/.bash_aliases
```

### Step 9.2: Test Aliases

```bash
# Show service status
ads-status

# View logs
ads-logs

# Run health checks
ads-health

# List users
ads-users

# List computers
ads-computers

# List groups
ads-groups
```

## Phase 10: Configure Firewall (if applicable)

If using UFW or iptables, allow required ports:

```bash
# UFW example
sudo ufw allow 53/tcp
sudo ufw allow 53/udp
sudo ufw allow 88/tcp
sudo ufw allow 88/udp
sudo ufw allow 389/tcp
sudo ufw allow 636/tcp
sudo ufw allow 464/tcp
sudo ufw allow 464/udp
sudo ufw allow 3268/tcp
sudo ufw allow 3269/tcp
```

## Troubleshooting

### Service Fails to Start

**Symptom:** `systemctl start samba-ad-dc` fails

**Check logs:**

```bash
sudo journalctl -u samba-ad-dc -n 100
```

**Common causes:**

1. **Port 53 in use:**
   ```bash
   sudo netstat -tulpn | grep :53
   # If systemd-resolved is running, stop it (Step 5.1)
   ```

2. **smb.conf errors:**
   ```bash
   sudo testparm
   # Check for syntax errors
   ```

3. **Kerberos config issues:**
   ```bash
   # Verify krb5.conf
   sudo cat /etc/krb5.conf
   # Ensure it matches Samba's generated config
   ```

### DNS Not Resolving

**Symptom:** `host avctn.lan` fails

**Checks:**

```bash
# Verify resolv.conf
cat /etc/resolv.conf
# Should show: nameserver 127.0.0.1

# Check DNS server is listening
sudo netstat -tulpn | grep :53

# Test DNS directly
dig @127.0.0.1 avctn.lan
```

**Fix:**

Re-run Step 5 (Configure DNS).

### Kerberos Errors

**Symptom:** `kinit` fails with "Cannot resolve network address"

**Checks:**

```bash
# Verify /etc/hosts
cat /etc/hosts
# Should include:
# 10.1.1.98  ads1-98.avctn.lan ads1-98

# Verify krb5.conf
cat /etc/krb5.conf
# Ensure [realms] section has correct KDC
```

**Fix:**

```bash
# Add to /etc/hosts
echo "10.1.1.98  ads1-98.avctn.lan ads1-98" | sudo tee -a /etc/hosts

# Copy Samba's krb5.conf
sudo cp /var/lib/samba/private/krb5.conf /etc/krb5.conf
```

### Replication Errors

**Symptom:** `samba-tool drs showrepl` shows errors

**Note:** For a single DC, this is expected (no replication partners).

**For multi-DC setups:**

```bash
# Force replication
sudo samba-tool drs replicate <destination-dc> <source-dc> dc=avctn,dc=lan

# Check replication health
sudo samba-tool drs showrepl
```

## Logs and Monitoring

### View Logs

```bash
# Via script (Option 8)
sudo /home/divix/divtools/scripts/ads/dt_ads_native.sh
# Select Option 8: View Logs

# Direct journalctl
sudo journalctl -u samba-ad-dc -f

# Script logs
tail -f /opt/ads-native/logs/dt_ads_native.log

# Samba logs (if enabled)
tail -f /var/log/samba/log.samba
```

### Enable Debug Logging

Edit `/etc/samba/smb.conf`:

```ini
[global]
    log level = 3
    log file = /var/log/samba/log.%m
    max log size = 1000
```

Restart samba:

```bash
sudo systemctl restart samba-ad-dc
```

## Backup and Recovery

### Backup Domain

```bash
# Backup Samba data
sudo tar -czf /backup/samba-backup-$(date +%F).tar.gz \
  /var/lib/samba /etc/samba /etc/krb5.conf /opt/ads-native

# Backup to NFS
sudo cp /backup/samba-backup-*.tar.gz /mnt/nas/backups/
```

### Restore Domain

```bash
# Extract backup
sudo tar -xzf /backup/samba-backup-YYYY-MM-DD.tar.gz -C /

# Restart services
sudo systemctl restart samba-ad-dc
```

## Next Steps

- **Join Windows Clients:** Use `ads1-98.avctn.lan` as DNS and domain join wizard
- **Add Additional DCs:** Provision additional servers and join to domain
- **Configure Group Policy:** Use RSAT tools from Windows client
- **Set up File Shares:** Add file share definitions to smb.conf
- **Monitor Health:** Schedule regular health checks (Option 9)

## See Also

- [README.md](README.md) - Overview and quick start
- [QUICK-REFERENCE.md](QUICK-REFERENCE.md) - Command reference
- [Samba Wiki: Setting up AD DC](https://wiki.samba.org/index.php/Setting_up_Samba_as_an_Active_Directory_Domain_Controller)
