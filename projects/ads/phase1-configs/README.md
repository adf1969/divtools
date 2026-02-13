# Phase 1 Configuration Files - Samba AD DC

**Created:** December 5, 2025  
**Status:** Ready for Deployment

## Overview

This directory contains all configuration files needed to deploy a Samba Active Directory Domain Controller on ads1-98 using Docker Compose. All files are ready to deploy following the instructions in `IMPLEMENTATION-STEPS.md`.

## Directory Structure

```
phase1-configs/
├── README.md                          # This file
├── IMPLEMENTATION-STEPS.md            # Complete deployment guide (START HERE)
├── docker-compose/
│   ├── dci-samba.yml                 # Samba service compose file
│   ├── dc-ads1-98.yml                # Host-level compose file
│   ├── .env.samba                    # Environment variables (customize before use)
│   └── .env.samba.example            # Example environment file (reference)
├── scripts/
│   └── entrypoint.sh                 # Container initialization script
└── aliases/
    └── samba-aliases.sh              # Bash aliases for Samba commands
```

## Quick Start

**⚠️ Before deploying, read `IMPLEMENTATION-STEPS.md` completely!**

### 1. Review Files

Each file contains comments indicating:
- **Deploy Location:** Where the file should be copied
- **Last Updated:** When the file was created/modified
- **Purpose:** What the file does

### 2. Customize Environment Variables

Edit `docker-compose/.env.samba` before deployment:
- Set strong `ADS_ADMIN_PASSWORD`
- Verify `ADS_HOST_IP`, `ADS_DOMAIN`, `ADS_REALM`
- Review all other settings

### 3. Deploy Files

Follow the step-by-step instructions in `IMPLEMENTATION-STEPS.md`.

**Key deployment paths:**
- Compose files → `/home/divix/divtools/docker/sites/s01-7692nw/ads1-98/`
- Aliases → Append to `~/.bash_aliases`
- System volumes → Created in `/opt/samba/`

## File Descriptions

### docker-compose/dci-samba.yml
- **Purpose:** Samba AD DC service definition
- **Deploy To:** `docker/sites/$SITE_NAME/$HOSTNAME/samba/dci-samba.yml`
- **Key Features:**
  - Volume mappings to /opt/samba/
  - All required AD ports exposed
  - Health checks configured
  - Divtools labels for organization

### docker-compose/dc-ads1-98.yml
- **Purpose:** Host-level compose file
- **Deploy To:** `docker/sites/$SITE_NAME/$HOSTNAME/dc-ads1-98.yml`
- **Key Features:**
  - Includes dci-samba.yml
  - Can include other services
  - Main entry point for docker compose commands

### docker-compose/.env.samba
- **Purpose:** Environment variables for Samba container
- **Deploy To:** `docker/sites/$SITE_NAME/$HOSTNAME/samba/.env.samba`
- **IMPORTANT:** 
  - Contains passwords - NEVER commit to git
  - Customize all values before deployment
  - See `.env.samba.example` for documentation

### docker-compose/.env.samba.example
- **Purpose:** Template with all available variables
- **Deploy To:** Reference only (can commit to git)
- **Contains:**
  - All environment variables with descriptions
  - Default values and options
  - Advanced configuration options

### scripts/entrypoint.sh
- **Purpose:** Container initialization and domain provisioning
- **Deploy To:** `docker/sites/$SITE_NAME/$HOSTNAME/samba/entrypoint.sh`
- **Features:**
  - Detects first-run vs existing domain
  - Automatic domain provisioning
  - Configuration validation
  - Logging with timestamps

### aliases/samba-aliases.sh
- **Purpose:** Bash aliases for transparent container execution
- **Deploy To:** Append to `~/.bash_aliases`
- **Provides:**
  - 30+ command aliases (samba-tool, ldapsearch, kinit, etc.)
  - Management shortcuts (ads-status, ads-logs, ads-shell)
  - Helper functions (ads-user-create, ads-backup)
  - Auto-detects container on each shell

## Volume Structure

Following divtools standards:

**Configuration (version controlled):**
```
/home/divix/divtools/docker/sites/s01-7692nw/ads1-98/samba/
├── dci-samba.yml
├── .env.samba
└── entrypoint.sh
```

**Persisted Data (backed up separately):**
```
/opt/samba/
├── data/        # Domain database, SYSVOL, private keys
├── config/      # Runtime smb.conf, krb5.conf (generated)
└── logs/        # Operational logs
```

## Deployment Checklist

Before starting deployment:

- [ ] Read `IMPLEMENTATION-STEPS.md` completely
- [ ] Review all configuration files
- [ ] Customize `.env.samba` with actual values
- [ ] Verify ads1-98 has static IP (10.1.1.98)
- [ ] Ensure Docker and Docker Compose V2 installed
- [ ] Create VM snapshot for rollback capability
- [ ] Verify NTP time synchronization configured
- [ ] Set hostname: `ads1-98.avctn.lan`

## Deployment Summary

**Time Required:** 30-60 minutes (first-time deployment)

**Steps:**
1. Create directory structure
2. Deploy configuration files
3. Customize environment variables
4. Configure Docker network
5. Install bash aliases
6. Start Samba container (auto-provisions domain)
7. Verify domain functionality
8. Create test user
9. Configure DNS on host
10. Test Windows domain join
11. Run health checks
12. Create backup

## Testing

After deployment, verify:

```bash
# Domain status
ads-status

# FSMO roles
ads-fsmo

# DNS resolution
host -t SRV _ldap._tcp.avctn.lan

# LDAP query
ldapsearch -H ldap://localhost -x -b "DC=avctn,DC=lan" -s base

# Kerberos
kinit Administrator@AVCTN.LAN
klist

# SMB
smbclient -L localhost -U Administrator
```

## Troubleshooting

Common issues and solutions documented in:
- `IMPLEMENTATION-STEPS.md` - Troubleshooting section
- `docs/SAMBA-CONFIGURATION.md` - Configuration guide
- `docs/DEPLOYMENT-GUIDE.md` - Detailed deployment info

## Next Steps

After successful Phase 1 deployment:

1. **Second DC (Phase 1b):** Deploy ads2-99 for HA
2. **Create OUs and Groups:** Organize directory structure
3. **Windows Integration:** Join Windows clients, test GPOs
4. **Linux Integration:** Configure SSSD on Ubuntu systems
5. **Monitoring:** Integrate with Prometheus/InfluxDB
6. **Backup Automation:** Schedule daily backups
7. **Phase 2:** Multi-site configuration

## Documentation References

- **Implementation Guide:** `IMPLEMENTATION-STEPS.md` (this folder)
- **Project History:** `../docs/PROJECT-HISTORY.md`
- **Requirements:** `../docs/PRD.md`
- **Samba Configuration:** `../docs/SAMBA-CONFIGURATION.md`
- **Deployment Details:** `../docs/DEPLOYMENT-GUIDE.md`

## Support

For questions or issues:
1. Check `IMPLEMENTATION-STEPS.md` troubleshooting section
2. Review `PROJECT-HISTORY.md` for architecture decisions
3. Consult `SAMBA-CONFIGURATION.md` for Samba-specific issues
4. Check container logs: `ads-logs` or `docker logs samba-ads1`

---

**Ready to deploy?** Start with `IMPLEMENTATION-STEPS.md` Step 1.
