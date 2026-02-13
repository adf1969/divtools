# Samba/ADS Configuration Files Reference

This document outlines all the main Samba and Active Directory Domain Controller configuration files, their purposes, and how they are used.

## Primary Configuration Files

### 1. `/etc/samba/smb.conf` (CRITICAL - Main Config)

**Location:** `/etc/samba/smb.conf`
**Backup Location:** `/etc/samba/smb.conf.default` (created during provision)
**Purpose:** Main Samba server configuration
**Contains:**
- Global settings (workgroup, netbios name, server role, interfaces)
- Share definitions (netlogon, sysvol, etc.)
- Security settings, password backend
- Log levels, logging configuration
- Replication settings, domain controller flags
- DNS forwarder configuration

**Modified By:**
- `samba-tool domain provision` (during initial setup)
- Manual editing for tuning performance, shares, security
- Updates during domain upgrades

**How It's Used:** Samba daemon reads this on startup and when config reloads

---

### 2. `/etc/krb5.conf` (CRITICAL - Kerberos)

**Location:** `/etc/krb5.conf`
**Generated From:** `/var/lib/samba/private/krb5.conf` (created during provision)
**Purpose:** Kerberos authentication configuration
**Contains:**
- Default realm definition
- KDC (Key Distribution Center) locations
- Kerberos server addresses
- Default domain mappings
- Encryption types supported
- Clock skew tolerance

**Modified By:**
- `samba-tool domain provision` (creates the file)
- Manual editing rarely needed (system auto-generates from Samba)

**How It's Used:** Client tools (kinit, ldapsearch) and system authentication use this

---

### 3. `/var/lib/samba/private/krb5.conf` (SOURCE)

**Location:** `/var/lib/samba/private/krb5.conf`
**Purpose:** Samba's internal Kerberos configuration
**Contains:** Same as `/etc/krb5.conf` - Samba generates this, then copies to `/etc/`
**Modified By:** Samba during domain provision
**How It's Used:** This is the source; should copy to `/etc/krb5.conf` for system-wide use

---

### 4. `/var/lib/samba/private/sam.ldb` (DATABASE - Critical)

**Location:** `/var/lib/samba/private/sam.ldb`
**Purpose:** Samba's LDAP directory database
**Contains:**
- All AD objects (users, groups, computers, organizational units)
- Password hashes (stored in LDB format, not plain text)
- User attributes (displayName, mail, telephone, etc.)
- Group memberships
- Domain information
- Schema definitions
- Security descriptors

**Modified By:**
- `samba-tool` commands (user add, group add, etc.)
- Replication from other DCs
- Automatic processes (password changes, logons)

**How It's Used:** Core AD directory - all queries go here
**Backup Important:** YES - losing this means losing all AD data

---

### 5. `/var/lib/samba/private/secrets.ldb` (DATABASE - Credentials)

**Location:** `/var/lib/samba/private/secrets.ldb`
**Purpose:** Samba credentials and trust accounts database
**Contains:**
- Machine account credentials
- Domain trust secrets
- Domain SID
- Computer account passwords
- LDAP bind credentials
- KDC credentials

**Modified By:**
- `samba-tool domain provision`
- Replication processes
- Machine joins

**How It's Used:** Authentication and inter-domain trust
**Permissions:** Very restricted (readable only by root/samba processes)
**Backup Important:** YES - needed for replication and recovery

---

### 6. `/etc/resolv.conf` (DNS Resolution)

**Location:** `/etc/resolv.conf`
**Purpose:** System DNS resolver configuration
**Contains:**
- Nameserver IP addresses (should point to Samba's DNS on 127.0.0.1)
- Search domain
- DNS options

**Modified By:**
- Manual editing or systemd-resolved
- dt_ads_native.sh (Configure DNS option)

**How It's Used:** System uses this for all DNS lookups
**Important:** Should point to localhost (127.0.0.1) so Samba DNS is used

---

### 7. `/var/lib/samba/dns/` (DNS Database - If using SAMBA_INTERNAL)

**Location:** `/var/lib/samba/dns/`
**Purpose:** DNS records database (if using SAMBA_INTERNAL backend)
**Contains:**
- DNS zone files
- A records, SRV records, CNAME, PTR records
- Replication zone info

**Modified By:**
- `samba-tool dns` commands
- Replication
- DDNS (dynamic DNS) updates from clients

**How It's Used:** Samba's internal DNS server queries this for zone data
**Alternative:** Can use BIND9 backend instead of SAMBA_INTERNAL

---

### 8. `/etc/samba/smb.conf.d/` (Optional - Additional Configs)

**Location:** `/etc/samba/smb.conf.d/`
**Purpose:** Additional configuration files (included by smb.conf)
**Contains:** Domain-specific or modular configurations
**Modified By:** Manual editing for advanced setups
**How It's Used:** Samba includes these files (see `include =` in smb.conf)

---

### 9. `/var/log/samba/` (Logs - Diagnostic)

**Location:** `/var/log/samba/`
**Purpose:** Samba daemon logs
**Contains:**
- `log.samba` - Main server log
- `log.smbd` - SMB server log
- `log.winbind` - Winbind service log
- `log.ldb` - LDAP database operations
- Per-client logs (if configured)

**Modified By:** Samba daemon automatically
**How It's Used:** Troubleshooting, monitoring
**Rotation:** Usually managed by logrotate

---

### 10. `/run/samba/` (Runtime - PID files, sockets)

**Location:** `/run/samba/`
**Purpose:** Runtime files (IPC sockets, PID files)
**Contains:**
- `.samba.samba.pid` - Process ID
- Socket files for inter-process communication
- Lock files

**Modified By:** Samba daemon at runtime
**How It's Used:** System processes, administrators (not usually edited)
**Permissions:** Usually restricted

---

## Summary Table

| File | Location | Type | Edited How | Critical |
|------|----------|------|-----------|----------|
| Main Config | `/etc/samba/smb.conf` | Text Config | Manual + samba-tool | **YES** |
| Kerberos Config | `/etc/krb5.conf` | Text Config | Auto-generated | **YES** |
| User/Group Database | `/var/lib/samba/private/sam.ldb` | Binary Database | samba-tool commands | **YES** |
| Credentials Database | `/var/lib/samba/private/secrets.ldb` | Binary Database | Auto-managed | **YES** |
| DNS Resolver | `/etc/resolv.conf` | Text Config | Manual | Important |
| DNS Records | `/var/lib/samba/dns/` | Database | samba-tool dns | If DNS enabled |
| Logs | `/var/log/samba/` | Text Logs | Auto-generated | Diagnostic |

---

## Editing Files in VSCode

Use the softlinks created by Option 4 in dt_ads_native.sh (Create Config File Links) to access these files for editing:

```
$DOCKER_HOSTDIR/ads.cfg/
├── smb.conf
├── krb5.conf
├── smb.conf.default
├── resolv.conf
├── etc_samba/       (entire /etc/samba directory)
└── lib_samba/       (entire /var/lib/samba directory)
```

These softlinks make it easy to:
- Edit configs in VSCode from your divtools structure
- See the actual file locations and learn the filesystem
- Make changes directly to the real system files
- Understand Samba's configuration architecture
