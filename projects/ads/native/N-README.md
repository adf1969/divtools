# Samba Active Directory Domain Controller - Native Installation

**Deployment Type:** Native Installation (No Docker)  
**Target OS:** Ubuntu 24.04 LTS  
**Domain:** avctn.lan  
**Realm:** AVCTN.LAN  
**Workgroup:** AVCTN  

## Why Native Installation?

The native installation approach provides several advantages over containerization for Samba AD DC:

- **Simplicity:** Direct installation on host eliminates container complexity
- **Performance:** No virtualization overhead, direct hardware access
- **Transparency:** All configs in standard Linux locations (/etc/samba/, /var/lib/samba/)
- **Debugging:** Standard systemd journaling and syslog integration
- **No Port Conflicts:** Direct binding to 53, 88, 389, 636 without docker network complications

## Installation Script

The `dt_ads_native.sh` script provides a complete menu-driven workflow:

```bash
sudo /home/divix/divtools/scripts/ads/dt_ads_native.sh
```

### Menu Options

1. **Install Samba** - Installs samba, krb5-user, winbind, smbclient packages
2. **Configure Environment Variables** - Sets REALM, DOMAIN, ADMIN_PASSWORD, IP_ADDRESS
3. **Provision Domain** - Runs samba-tool domain provision
4. **Configure Host DNS** - Stops systemd-resolved, sets up /etc/resolv.conf
5. **Start Samba Services** - Starts samba-ad-dc via systemd
6. **Stop Samba Services** - Stops samba-ad-dc
7. **Restart Samba Services** - Restarts samba-ad-dc
8. **View Logs** - Shows recent samba-ad-dc journal entries
9. **Run Health Checks** - Verifies domain info, FSMO roles, replication

## Quick Start

### Step 1: Install and Configure

```bash
# Run the setup script
sudo /home/divix/divtools/scripts/ads/dt_ads_native.sh

# Select Option 1: Install Samba
# Select Option 2: Configure Environment Variables
#   - REALM: AVCTN.LAN
#   - DOMAIN: avctn
#   - ADMIN_PASSWORD: (your chosen password)
#   - IP_ADDRESS: (your DC's static IP)
```

### Step 2: Provision Domain

```bash
# Select Option 3: Provision Domain
# This runs samba-tool domain provision with your configured values
```

### Step 3: Configure DNS

```bash
# Select Option 4: Configure Host DNS
# This stops systemd-resolved and configures /etc/resolv.conf
```

### Step 4: Start Services

```bash
# Select Option 5: Start Samba Services
# Verify with Option 9: Run Health Checks
```

## Environment Variables

Configuration is stored in `/opt/ads-native/.env.ads`:

```bash
REALM=AVCTN.LAN
DOMAIN=avctn
ADMIN_PASSWORD=your_password_here
IP_ADDRESS=10.1.1.98
```

## Service Management

The script manages the `samba-ad-dc` systemd service:

```bash
# Via script menu:
Option 5: Start Samba Services
Option 6: Stop Samba Services
Option 7: Restart Samba Services

# Direct systemd commands:
sudo systemctl status samba-ad-dc
sudo systemctl start samba-ad-dc
sudo systemctl stop samba-ad-dc
sudo systemctl restart samba-ad-dc
```

## Logs

View logs via the script or directly:

```bash
# Via script (Option 8: View Logs)

# Or directly:
sudo journalctl -u samba-ad-dc -n 50 -f
tail -f /opt/ads-native/logs/dt_ads_native.log
```

## Health Checks

Option 9 runs these checks:

- **Domain Info:** `samba-tool domain info 127.0.0.1`
- **FSMO Roles:** `samba-tool fsmo show`
- **Replication:** `samba-tool drs showrepl`

## Key Files

- **Script:** `/home/divix/divtools/scripts/ads/dt_ads_native.sh`
- **Samba Config:** `/etc/samba/smb.conf`
- **Kerberos Config:** `/etc/krb5.conf`
- **Environment:** `/opt/ads-native/.env.ads`
- **Logs:** `/opt/ads-native/logs/dt_ads_native.log`
- **DNS Config:** `/etc/resolv.conf`

## Bash Aliases

The script creates samba-specific aliases (no docker exec needed):

```bash
# These will be available after running the script:
ads-status          # Show samba-ad-dc service status
ads-logs            # Tail samba-ad-dc logs
ads-health          # Run health checks
ads-users           # List AD users
ads-computers       # List AD computers
ads-groups          # List AD groups
```

## DNS Configuration

The native installation requires DNS configuration:

1. **Stop systemd-resolved** (conflicts with Samba DNS on port 53)
2. **Configure /etc/resolv.conf** to point to localhost
3. **Set static IP** on the host

The script handles this via Option 4.

## Post-Installation Testing

After provisioning and starting services:

```bash
# Test DNS
host -t SRV _ldap._tcp.avctn.lan
nslookup avctn.lan

# Test Kerberos
kinit administrator@AVCTN.LAN
klist

# Test AD connectivity
smbclient -L localhost -U administrator
```

## Troubleshooting

### Service Won't Start

```bash
# Check logs
sudo journalctl -u samba-ad-dc -n 100

# Check DNS conflicts
sudo netstat -tulpn | grep :53

# Verify systemd-resolved is stopped
sudo systemctl status systemd-resolved
```

### Port Conflicts

Native installation binds directly to:

- **53** (DNS)
- **88** (Kerberos)
- **389** (LDAP)
- **636** (LDAPS)
- **464** (Kerberos Password)
- **3268, 3269** (Global Catalog)

Ensure no other services use these ports.

### DNS Resolution Issues

```bash
# Verify resolv.conf
cat /etc/resolv.conf
# Should contain: nameserver 127.0.0.1

# Test DNS
dig @127.0.0.1 avctn.lan
```

## Comparison: Native vs Docker

| Aspect | Native | Docker |
|--------|--------|--------|
| Complexity | Low (direct install) | Medium (container, networks, volumes) |
| Performance | Best (no overhead) | Slightly slower |
| Port Management | Direct binding | Requires port mapping |
| Configuration | `/etc/samba/` | Bind mounts or volumes |
| Debugging | Standard systemd logs | docker logs + journald |
| Updates | `apt-get upgrade samba` | Rebuild container |
| Best For | Single-purpose VM | Multi-app hosts |

## See Also

- [IMPLEMENTATION-STEPS.md](IMPLEMENTATION-STEPS.md) - Detailed step-by-step guide
- [QUICK-REFERENCE.md](QUICK-REFERENCE.md) - Command reference
- [../docker/README.md](../docker/README.md) - Docker-based approach (alternative)
