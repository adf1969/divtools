# ADS Environment Variables Reference

**Last Updated:** January 8, 2026

## Overview

This document describes all environment variables used by the Samba AD DC setup script (`dt_ads_setup.sh`). The script can validate these variables and report their status and source locations.

## Variable Sources

Environment variables can come from three sources (checked in order):

1. **Host Environment File:** `$DIVTOOLS/docker/sites/$SITE_NAME/$HOSTNAME/.env.$HOSTNAME`
   - Site and host specific configuration
   - Example: `/home/divix/divtools/docker/sites/s01-7692nw/ads1-98/.env.ads1-98`

2. **Samba Environment File:** `$DIVTOOLS/docker/sites/$SITE_NAME/$HOSTNAME/samba/.env.samba`
   - Container-specific Samba configuration
   - Example: `/home/divix/divtools/docker/sites/s01-7692nw/ads1-98/samba/.env.samba`

3. **User Profile:** `~/.bash_profile` (via `load_env_files()` function)
   - Central divtools environment management
   - Uses `load_env_files()` from divtools infrastructure
   - Provides `$SITE_NAME`, `$HOSTNAME`, `$DOCKER_HOSTDIR`

## Required Environment Variables

These variables MUST be set before running ADS Setup.

### Basic Domain Configuration

| Variable | Description | Example | Required |
|----------|-------------|---------|----------|
| `ADS_DOMAIN` | DNS domain name (lowercase) | `avctn.lan` | Yes |
| `ADS_REALM` | Kerberos realm (uppercase) | `AVCTN.LAN` | Yes |
| `ADS_WORKGROUP` | NetBIOS name (max 15 chars) | `AVCTN` | Yes |

### Credentials and Authentication

| Variable | Description | Example | Required |
|----------|-------------|---------|----------|
| `ADS_ADMIN_PASSWORD` | Administrator password | `SecurePass123!` | Yes |

**Password Requirements:**

- Minimum 8 characters (12+ recommended)
- Must contain: uppercase, lowercase, numbers, special characters
- Change from defaults immediately

### Network Configuration

| Variable | Description | Example | Required |
|----------|-------------|---------|----------|
| `ADS_HOST_IP` | DC host IP address | `10.1.1.98` | Yes |
| `ADS_DNS_FORWARDER` | External DNS servers | `8.8.8.8 8.8.4.4` | Yes |

**Notes:**

- `ADS_HOST_IP` must be static
- `ADS_DNS_FORWARDER` is comma or space separated list

### Server Configuration

| Variable | Description | Example | Required |
|----------|-------------|---------|----------|
| `ADS_SERVER_ROLE` | Server role | `dc` or `member` | Yes |
| `ADS_DOMAIN_LEVEL` | Domain functional level | `2016` | Yes |

**Valid Values:**

- `ADS_SERVER_ROLE`: `dc` (Domain Controller), `member` (Member Server)
- `ADS_DOMAIN_LEVEL`: `2008_R2`, `2012`, `2012_R2`, `2016`

## Optional Environment Variables

These variables have defaults but can be customized.

| Variable | Description | Default | Source |
|----------|-------------|---------|--------|
| `ADS_FOREST_LEVEL` | Forest functional level | `2016` | `.env.samba` |
| `ADS_DNS_BACKEND` | DNS backend type | `SAMBA_INTERNAL` | `.env.samba` |
| `ADS_LOG_LEVEL` | Samba log verbosity (0-10) | `1` | `.env.samba` |

**Valid Values:**

- `ADS_DNS_BACKEND`: `SAMBA_INTERNAL`, `BIND9_DLZ`, `NONE`
- `ADS_LOG_LEVEL`: `0` (minimal) to `10` (debug)

## Site and Host Information Variables

These are typically loaded from `.bash_profile` via `load_env_files()`:

| Variable | Description | Example | Source |
|----------|-------------|---------|--------|
| `SITE_NAME` | Site identifier | `s01-7692nw` | `.bash_profile` |
| `SITE_NUM` | Site number | `1` | `.env.samba` |
| `HOSTNAME` | Host name | `ads1-98` | `.bash_profile` |

## Checking Environment Variables

The script includes a menu option to check and validate all required and optional environment variables.

### From Command Line

```bash
# Run the script
/home/divix/divtools/scripts/ads/dt_ads_setup.sh

# From the menu, select: "Check Environment Variables" (option 7)
```

### What the Check Does

The environment variable check will:

1. **Source Environment Files**
   - Attempts to load from `.env.$HOSTNAME`
   - Attempts to load from `samba/.env.samba`
   - Calls `load_env_files()` if available

2. **Validate Required Variables**
   - Checks each required variable is set
   - Masks sensitive values (passwords)
   - Reports missing variables as errors

3. **Check Optional Variables**
   - Lists optional variables that are set
   - Shows variables using defaults

4. **Report Variable Sources**
   - Displays which file each variable came from
   - Helps troubleshoot configuration issues

5. **Display Results**
   - Shows formatted table with status
   - Uses symbols:
     - ✓ (variable is set)
     - ✗ (variable is MISSING/required)
     - ◯ (variable is optional, not set)

## Example Output

```
╔══════════════════════════════════════════════════════════════════╗
║ REQUIRED ENVIRONMENT VARIABLES                                  ║
╚══════════════════════════════════════════════════════════════════╝

✓ ADS_DOMAIN
    Source: /home/divix/divtools/docker/sites/s01-7692nw/ads1-98/.env.ads1-98
    Value:  avctn.lan

✓ ADS_REALM
    Source: /home/divix/divtools/docker/sites/s01-7692nw/ads1-98/.env.ads1-98
    Value:  AVCTN.LAN

✗ ADS_ADMIN_PASSWORD
    Description: Administrator password
    Status: MISSING - Required for operation

✓ ADS_HOST_IP
    Source: /home/divix/divtools/docker/sites/s01-7692nw/ads1-98/samba/.env.samba
    Value:  10.1.1.98

✓ ADS_ADMIN_PASSWORD
    Source: .bash_profile (via load_env_files)
    Value:  ***MASKED*** (18 chars)
```

## Setting Up Environment Variables

### Option 1: Host Environment File (Recommended)

Edit the host environment file:

```bash
nano /home/divix/divtools/docker/sites/s01-7692nw/ads1-98/.env.ads1-98
```

Add variables with the `AUTO-MANAGED` markers:

```bash
# >>> DT_ADS_SETUP AUTO-MANAGED - DO NOT EDIT MANUALLY <<<
# Samba AD DC Configuration
# Last Updated: MM/DD/YYYY HH:MM:SS TZ

export ADS_DOMAIN="avctn.lan"
export ADS_REALM="AVCTN.LAN"
export ADS_WORKGROUP="AVCTN"
export ADS_ADMIN_PASSWORD="SecurePassword123!"
export ADS_HOST_IP="10.1.1.98"
export ADS_DNS_FORWARDER="8.8.8.8 8.8.4.4"
export ADS_SERVER_ROLE="dc"
export ADS_DOMAIN_LEVEL="2016"
# <<< DT_ADS_SETUP AUTO-MANAGED <<<
```

### Option 2: Samba Environment File

Edit the Samba environment file:

```bash
nano /home/divix/divtools/docker/sites/s01-7692nw/ads1-98/samba/.env.samba
```

Add variables (no export needed):

```bash
# Domain Configuration
ADS_DOMAIN=avctn.lan
ADS_REALM=AVCTN.LAN
ADS_WORKGROUP=AVCTN

# Administrator Password
ADS_ADMIN_PASSWORD=SecurePassword123!

# Network Configuration
ADS_HOST_IP=10.1.1.98
ADS_DNS_FORWARDER=8.8.8.8 8.8.4.4

# Server Role
ADS_SERVER_ROLE=dc
ADS_DOMAIN_LEVEL=2016
```

### Option 3: Interactive Prompt

Use the script's "Edit Environment Variables" menu (option 6) to be prompted for each variable interactively.

## Troubleshooting Missing Variables

### If Variables Are Missing

1. **Check file locations** - Ensure files exist:

   ```bash
   # Host environment file
   cat /home/divix/divtools/docker/sites/s01-7692nw/ads1-98/.env.ads1-98
   
   # Samba environment file
   cat /home/divix/divtools/docker/sites/s01-7692nw/ads1-98/samba/.env.samba
   ```

2. **Check bash_profile** - Ensure `load_env_files()` function exists:

   ```bash
   grep "load_env_files" ~/.bash_profile
   ```

3. **Re-run environment check** - After adding variables:

   ```bash
   /home/divix/divtools/scripts/ads/dt_ads_setup.sh
   # Select: "Check Environment Variables"
   ```

4. **Verify file syntax** - Ensure proper variable format:

   ```bash
   # Should show variable values
   source /home/divix/divtools/docker/sites/s01-7692nw/ads1-98/.env.ads1-98
   echo "Domain: $ADS_DOMAIN"
   ```

## Related Documentation

- [README.md](../README.md) - Project overview
- [QUICK-REFERENCE.md](../QUICK-REFERENCE.md) - Command reference
- [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md) - Deployment steps
- [IMPLEMENTATION-STEPS.md](../phase1-configs/IMPLEMENTATION-STEPS.md) - Phase 1 setup
