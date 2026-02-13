# Samba AD DC Quick Reference - Native Installation

**Last Updated:** 1/27/2025 10:00:00 PM CST

Quick command reference for native Samba Active Directory Domain Controller operations.

## Installation Script

```bash
# Launch interactive menu
sudo /home/divix/divtools/scripts/ads/dt_ads_native.sh

# Menu Options:
# 1 - Install Samba
# 2 - Configure Environment Variables
# 3 - Provision Domain
# 4 - Configure Host DNS
# 5 - Start Samba Services
# 6 - Stop Samba Services
# 7 - Restart Samba Services
# 8 - View Logs
# 9 - Run Health Checks
```

## Service Management

### Systemd Commands

```bash
# Check status
sudo systemctl status samba-ad-dc

# Start service
sudo systemctl start samba-ad-dc

# Stop service
sudo systemctl stop samba-ad-dc

# Restart service
sudo systemctl restart samba-ad-dc

# Enable at boot
sudo systemctl enable samba-ad-dc

# Disable at boot
sudo systemctl disable samba-ad-dc

# View service logs
sudo journalctl -u samba-ad-dc -f
sudo journalctl -u samba-ad-dc -n 100
```

### Bash Aliases

```bash
ads-status       # Show samba-ad-dc service status
ads-logs         # Tail samba-ad-dc logs
ads-health       # Run health checks
ads-users        # List AD users
ads-computers    # List AD computers
ads-groups       # List AD groups
ads-start        # Start samba-ad-dc
ads-stop         # Stop samba-ad-dc
ads-restart      # Restart samba-ad-dc
```

## User Management

### Add User

```bash
# Interactive
sudo samba-tool user add <username>

# With password
sudo samba-tool user add <username> <password>

# With description
sudo samba-tool user add <username> --description="Full Name"

# Example
sudo samba-tool user add jdoe --given-name="John" --surname="Doe" \
  --description="John Doe - IT Department"
```

### List Users

```bash
# All users
sudo samba-tool user list

# Via alias
ads-users

# With LDAP
ldapsearch -H ldap://localhost -D "cn=administrator,cn=users,dc=avctn,dc=lan" \
  -W -b "cn=users,dc=avctn,dc=lan" "(objectClass=user)"
```

### Delete User

```bash
sudo samba-tool user delete <username>
```

### Reset Password

```bash
# Interactive
sudo samba-tool user setpassword <username>

# Direct
sudo samba-tool user setpassword <username> --newpassword="<password>"

# Force change at next login
sudo samba-tool user setpassword <username> --must-change-at-next-login
```

### Disable/Enable User

```bash
# Disable
sudo samba-tool user disable <username>

# Enable
sudo samba-tool user enable <username>

# Check status
sudo samba-tool user show <username>
```

## Group Management

### Add Group

```bash
# Security group
sudo samba-tool group add <groupname>

# Distribution group
sudo samba-tool group add <groupname> --group-type=Distribution

# Example
sudo samba-tool group add ITAdmins --description="IT Administrators"
```

### List Groups

```bash
# All groups
sudo samba-tool group list

# Via alias
ads-groups

# Show group members
sudo samba-tool group listmembers <groupname>
```

### Add User to Group

```bash
sudo samba-tool group addmembers <groupname> <username>

# Multiple users
sudo samba-tool group addmembers <groupname> user1,user2,user3

# Example
sudo samba-tool group addmembers "Domain Admins" jdoe
```

### Remove User from Group

```bash
sudo samba-tool group removemembers <groupname> <username>
```

### Delete Group

```bash
sudo samba-tool group delete <groupname>
```

## Computer Management

### List Computers

```bash
# All computers
sudo samba-tool computer list

# Via alias
ads-computers

# With details
ldapsearch -H ldap://localhost -D "cn=administrator,cn=users,dc=avctn,dc=lan" \
  -W -b "cn=computers,dc=avctn,dc=lan" "(objectClass=computer)"
```

### Delete Computer

```bash
sudo samba-tool computer delete <computername>
```

## DNS Management

### List DNS Records

```bash
# List zones
sudo samba-tool dns zonelist localhost -U administrator

# List records in zone
sudo samba-tool dns query localhost avctn.lan @ ALL -U administrator
```

### Add DNS Record

```bash
# A record
sudo samba-tool dns add localhost avctn.lan server1 A 10.1.1.100 -U administrator

# CNAME record
sudo samba-tool dns add localhost avctn.lan www CNAME server1 -U administrator

# PTR record (reverse)
sudo samba-tool dns add localhost 1.1.10.in-addr.arpa 100 PTR server1.avctn.lan -U administrator
```

### Delete DNS Record

```bash
sudo samba-tool dns delete localhost avctn.lan server1 A 10.1.1.100 -U administrator
```

### Update DNS Record

```bash
# Delete old, add new
sudo samba-tool dns delete localhost avctn.lan server1 A 10.1.1.100 -U administrator
sudo samba-tool dns add localhost avctn.lan server1 A 10.1.1.101 -U administrator
```

## Domain Management

### Domain Info

```bash
# Show domain info
sudo samba-tool domain info 127.0.0.1

# Show domain level
sudo samba-tool domain level show
```

### FSMO Roles

```bash
# Show all FSMO roles
sudo samba-tool fsmo show

# Transfer role
sudo samba-tool fsmo transfer --role=<role> --host=<target-dc>

# Seize role (force)
sudo samba-tool fsmo seize --role=<role>

# Roles:
# - schema
# - naming
# - pdc
# - rid
# - infrastructure
```

### Replication

```bash
# Show replication status
sudo samba-tool drs showrepl

# Force replication
sudo samba-tool drs replicate <dest-dc> <source-dc> dc=avctn,dc=lan

# Example (multi-DC)
sudo samba-tool drs replicate ads2-99 ads1-98 dc=avctn,dc=lan
```

### Password Policy

```bash
# Show current policy
sudo samba-tool domain passwordsettings show

# Set password policy
sudo samba-tool domain passwordsettings set --complexity=off
sudo samba-tool domain passwordsettings set --min-pwd-length=8
sudo samba-tool domain passwordsettings set --min-pwd-age=1
sudo samba-tool domain passwordsettings set --max-pwd-age=42
```

## GPO Management

### List GPOs

```bash
sudo samba-tool gpo listall
```

### Create GPO

```bash
sudo samba-tool gpo create "<GPO Name>" -U administrator
```

### Delete GPO

```bash
sudo samba-tool gpo del <GPO-GUID> -U administrator
```

## Kerberos

### Get Ticket

```bash
# For administrator
kinit administrator@AVCTN.LAN

# For other user
kinit <username>@AVCTN.LAN

# List current tickets
klist

# Destroy tickets
kdestroy
```

### Test Authentication

```bash
# Test kinit
kinit administrator@AVCTN.LAN
klist

# Test LDAP with Kerberos
ldapsearch -H ldap://ads1-98.avctn.lan -Y GSSAPI -b "dc=avctn,dc=lan"
```

## SMB Client Testing

### List Shares

```bash
# As administrator
smbclient -L localhost -U administrator

# As specific user
smbclient -L localhost -U <username>
```

### Connect to Share

```bash
# Connect to netlogon
smbclient //localhost/netlogon -U administrator

# Connect to sysvol
smbclient //localhost/sysvol -U administrator

# Connect to custom share
smbclient //server/share -U <username>
```

## DNS Testing

### Query DNS

```bash
# Test domain
host avctn.lan
nslookup avctn.lan

# Test SRV records
host -t SRV _ldap._tcp.avctn.lan
host -t SRV _kerberos._tcp.avctn.lan
host -t SRV _gc._tcp.avctn.lan

# Test A record
host ads1-98.avctn.lan

# Test PTR (reverse)
host 10.1.1.98

# Dig queries
dig @127.0.0.1 avctn.lan
dig @127.0.0.1 _ldap._tcp.avctn.lan SRV
```

## LDAP Queries

### Basic Search

```bash
# Search users
ldapsearch -H ldap://localhost -D "cn=administrator,cn=users,dc=avctn,dc=lan" \
  -W -b "cn=users,dc=avctn,dc=lan" "(objectClass=user)"

# Search groups
ldapsearch -H ldap://localhost -D "cn=administrator,cn=users,dc=avctn,dc=lan" \
  -W -b "cn=users,dc=avctn,dc=lan" "(objectClass=group)"

# Search computers
ldapsearch -H ldap://localhost -D "cn=administrator,cn=users,dc=avctn,dc=lan" \
  -W -b "cn=computers,dc=avctn,dc=lan" "(objectClass=computer)"
```

### Filter Examples

```bash
# Find specific user
ldapsearch -H ldap://localhost -D "cn=administrator,cn=users,dc=avctn,dc=lan" \
  -W -b "dc=avctn,dc=lan" "(sAMAccountName=jdoe)"

# Find users in group
ldapsearch -H ldap://localhost -D "cn=administrator,cn=users,dc=avctn,dc=lan" \
  -W -b "dc=avctn,dc=lan" "(memberOf=cn=ITAdmins,cn=users,dc=avctn,dc=lan)"

# Find disabled users
ldapsearch -H ldap://localhost -D "cn=administrator,cn=users,dc=avctn,dc=lan" \
  -W -b "dc=avctn,dc=lan" "(&(objectClass=user)(userAccountControl:1.2.840.113556.1.4.803:=2))"
```

## Configuration Files

### smb.conf

```bash
# Edit main config
sudo nano /etc/samba/smb.conf

# Test config
sudo testparm

# Test with verbosity
sudo testparm -v
```

### krb5.conf

```bash
# Edit Kerberos config
sudo nano /etc/krb5.conf

# Samba's generated config
sudo cat /var/lib/samba/private/krb5.conf

# Copy Samba's config
sudo cp /var/lib/samba/private/krb5.conf /etc/krb5.conf
```

### resolv.conf

```bash
# Edit DNS resolvers
sudo nano /etc/resolv.conf

# Should contain:
# nameserver 127.0.0.1
# search avctn.lan
```

## Logs

### View Logs

```bash
# Systemd journal (real-time)
sudo journalctl -u samba-ad-dc -f

# Last 100 lines
sudo journalctl -u samba-ad-dc -n 100

# Today's logs
sudo journalctl -u samba-ad-dc --since today

# Logs since specific time
sudo journalctl -u samba-ad-dc --since "2025-01-27 10:00:00"

# Script logs
tail -f /opt/ads-native/logs/dt_ads_native.log

# Samba logs (if enabled)
tail -f /var/log/samba/log.samba
tail -f /var/log/samba/log.smbd
```

## Backup

### Manual Backup

```bash
# Backup Samba data
sudo samba-tool domain backup offline --targetdir=/backup

# Or tar method
sudo systemctl stop samba-ad-dc
sudo tar -czf /backup/samba-$(date +%F).tar.gz \
  /var/lib/samba /etc/samba /etc/krb5.conf
sudo systemctl start samba-ad-dc

# Backup to NFS
sudo cp /backup/samba-*.tar.gz /mnt/nas/backups/
```

### Restore

```bash
# Stop service
sudo systemctl stop samba-ad-dc

# Restore from tar
sudo tar -xzf /backup/samba-YYYY-MM-DD.tar.gz -C /

# Or use samba-tool
sudo samba-tool domain backup restore --backup-file=/backup/samba-backup.tar.bz2 \
  --targetdir=/var/lib/samba

# Start service
sudo systemctl start samba-ad-dc
```

## Troubleshooting Commands

### Check Port Bindings

```bash
# All Samba ports
sudo netstat -tulpn | grep samba

# Specific ports
sudo netstat -tulpn | grep :53    # DNS
sudo netstat -tulpn | grep :88    # Kerberos
sudo netstat -tulpn | grep :389   # LDAP
sudo netstat -tulpn | grep :636   # LDAPS
```

### Test Components

```bash
# Test DNS server
dig @127.0.0.1 avctn.lan

# Test Kerberos
kinit administrator@AVCTN.LAN
klist

# Test LDAP
ldapsearch -H ldap://localhost -x -b "dc=avctn,dc=lan"

# Test SMB
smbclient -L localhost -N
```

### Database Checks

```bash
# Check database integrity
sudo samba-tool dbcheck

# Check and fix
sudo samba-tool dbcheck --fix

# Cross-reference check
sudo samba-tool dbcheck --cross-ncs
```

## Environment File

Location: `/opt/ads-native/.env.ads`

```bash
# View environment
cat /opt/ads-native/.env.ads

# Edit environment
sudo nano /opt/ads-native/.env.ads

# Example content:
REALM=AVCTN.LAN
DOMAIN=avctn
ADMIN_PASSWORD=YourSecurePassword
IP_ADDRESS=10.1.1.98
```

## Common Task Sequences

### Full Installation

```bash
# 1. Run script
sudo /home/divix/divtools/scripts/ads/dt_ads_native.sh

# 2. Select options in order:
#    Option 1: Install Samba
#    Option 2: Configure Environment Variables
#    Option 3: Provision Domain
#    Option 4: Configure Host DNS
#    Option 5: Start Samba Services
#    Option 9: Run Health Checks
```

### Daily Operations

```bash
# Check status
ads-status

# View recent logs
ads-logs

# Add new user
sudo samba-tool user add newuser

# Add user to group
sudo samba-tool group addmembers "Domain Users" newuser

# Check health
ads-health
```

### After Reboot

```bash
# Verify service started
sudo systemctl status samba-ad-dc

# If not started
sudo systemctl start samba-ad-dc

# Run health checks
ads-health
```

## See Also

- [README.md](README.md) - Overview and introduction
- [IMPLEMENTATION-STEPS.md](IMPLEMENTATION-STEPS.md) - Detailed setup guide
- [Samba Wiki](https://wiki.samba.org/) - Official documentation
