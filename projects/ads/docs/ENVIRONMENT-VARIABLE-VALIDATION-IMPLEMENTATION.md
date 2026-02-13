# Environment Variable Validation Implementation Summary

**Date:** January 8, 2026  
**File Modified:** `/home/divix/divtools/scripts/ads/dt_ads_setup.sh`

## Overview

Added comprehensive environment variable validation functionality to `dt_ads_setup.sh` that allows users to easily check and verify that all required environment variables are properly configured before running ADS setup operations.

## What Was Added

### 1. New Menu Option: "Check Environment Variables" (Option 7)

Users can now access environment variable validation directly from the main menu:

```
Samba AD DC Setup
├─ 1: ADS Setup (folders, files, network)
├─ 2: Start Samba Container
├─ 3: Stop Samba Container
├─ 4: ADS Status Check (run tests)
├─ 5: Configure DNS on Host
├─ 6: Edit Environment Variables
├─ 7: Check Environment Variables  ← NEW
├─ 8: View Container Logs
└─ 9: Exit
```

### 2. New Function: `check_env_vars()`

**Location:** Lines 680-820 (before Main Menu section)

**Last Updated:** 01/08/2026 11:30:00 AM CST

**Functionality:**

The function performs comprehensive validation of environment variables:

#### Required Variables (8 total)

- `ADS_DOMAIN` - Domain name (e.g., avctn.lan)
- `ADS_REALM` - Realm name (e.g., AVCTN.LAN)
- `ADS_WORKGROUP` - NetBIOS name (e.g., AVCTN)
- `ADS_ADMIN_PASSWORD` - Administrator password
- `ADS_HOST_IP` - Host IP address (e.g., 10.1.1.98)
- `ADS_DNS_FORWARDER` - DNS forwarders (e.g., 8.8.8.8 8.8.4.4)
- `ADS_SERVER_ROLE` - Server role (dc or member)
- `ADS_DOMAIN_LEVEL` - Domain functional level (2008_R2, 2012, 2012_R2, 2016)

#### Optional Variables (3 total)

- `ADS_FOREST_LEVEL` - Forest functional level (optional)
- `ADS_DNS_BACKEND` - DNS backend type (optional)
- `ADS_LOG_LEVEL` - Samba log level 0-10 (optional)

### 3. Variable Source Detection

The function automatically detects where each variable is defined:

```
Checked locations (in order):
1. Host env file:      $HOST_DIR/.env.$HOSTNAME
                       e.g., docker/sites/s01-7692nw/ads1-98/.env.ads1-98

2. Samba env file:     $SAMBA_DIR/.env.samba
                       e.g., docker/sites/s01-7692nw/ads1-98/samba/.env.samba

3. User profile:       ~/.bash_profile (via load_env_files() function)
                       Provides SITE_NAME, HOSTNAME, DOCKER_HOSTDIR
```

### 4. Output Display

Results are shown in a formatted whiptail dialog with:

**Required Variables Section:**

```
╔══════════════════════════════════════════════════════════╗
║ REQUIRED ENVIRONMENT VARIABLES                          ║
╚══════════════════════════════════════════════════════════╝

✓ ADS_DOMAIN
    Source: /docker/sites/s01-7692nw/ads1-98/.env.ads1-98
    Value:  avctn.lan

✗ ADS_ADMIN_PASSWORD
    Description: Administrator password
    Status: MISSING - Required for operation
```

**Optional Variables Section:**

```
╔══════════════════════════════════════════════════════════╗
║ OPTIONAL ENVIRONMENT VARIABLES                          ║
╚══════════════════════════════════════════════════════════╝

✓ ADS_LOG_LEVEL
    Source: /docker/sites/s01-7692nw/ads1-98/samba/.env.samba
    Value:  1

◯ ADS_FOREST_LEVEL
    Description: Forest functional level (optional)
    Status: Not set (will use defaults)
```

**Variable Sources Reference:**

```
╔══════════════════════════════════════════════════════════╗
║ VARIABLE SOURCES                                        ║
╚══════════════════════════════════════════════════════════╝

Location of environment files checked:
  1. Host env file: /docker/sites/s01-7692nw/ads1-98/.env.ads1-98
  2. Samba env file: /docker/sites/s01-7692nw/ads1-98/samba/.env.samba
  3. User profile: ~/.bash_profile (via load_env_files)

Legend:
  ✓ Variable is set and available
  ✗ Variable is REQUIRED but MISSING
  ◯ Variable is optional and not set
```

### 5. Security Features

- **Password Masking:** Sensitive values (passwords) are masked in output
  - Display: `***MASKED*** (18 chars)` instead of actual password
  - Shows character count for verification

- **Detailed Logging:** All validation steps logged:
  - File sourcing operations
  - Environment variable detection
  - Variable source determination
  - Missing variable errors

### 6. Return Codes

The function returns appropriate exit codes:

- `0` - All required variables are set (success)
- `1` - One or more required variables are missing (error)

## How to Use

### From the Menu

```bash
/home/divix/divtools/scripts/ads/dt_ads_setup.sh

# Select option 7: "Check Environment Variables"
# Review the displayed information
# Variables can then be added using option 6 if needed
```

### Before Running ADS Setup

Users should run the environment check before starting the main ADS setup to ensure all required variables are configured:

```bash
# Run setup script
./dt_ads_setup.sh

# First, check environment variables (option 7)
# Then edit if needed (option 6)
# Finally, run ADS Setup (option 1)
```

## Documentation Added

Created comprehensive reference document:  
**File:** `/home/divix/divtools/projects/ads/docs/ENVIRONMENT-VARIABLES.md`

This document includes:

- Complete variable reference with descriptions
- Variable source locations
- Required vs. optional variables table
- Password requirements and constraints
- Example configuration values
- Troubleshooting guide
- Step-by-step setup instructions for each source

## Menu Structure Updated

Updated main menu to accommodate new option:

| Old | New | Description |
|-----|-----|-------------|
| 8 items | 9 items | Added "Check Environment Variables" |
| Menu height: 20 | Menu height: 22 | Increased for additional menu item |
| Menu items: 10 | Menu items: 12 | Updated for proper display |

## Environment Variable Integration

The check function integrates with existing divtools infrastructure:

1. **Calls `load_env_files()`** (if available)
   - Uses standard divtools environment loader
   - Provides `SITE_NAME`, `HOSTNAME`, `DOCKER_HOSTDIR`

2. **Sources `.bash_profile`** (fallback)
   - Loads environment if `load_env_files()` not available
   - Ensures compatibility with divtools architecture

3. **Respects Environment Markers**
   - Recognizes `# >>> DT_ADS_SETUP AUTO-MANAGED` sections
   - Compatible with script update methodology

## Logging

All validation steps are fully logged to:  
**Default:** `/opt/ads-setup/logs/dt_ads_setup-TIMESTAMP.log`

Log entries include:

- Variable source detection
- Which files were sourced
- Missing variable errors
- Successful validation summary

## Validation Complete

✅ **Syntax verified:** `bash -n` passed without errors  
✅ **Function tested:** Integration with existing code verified  
✅ **Menu structure:** Updated and validated  
✅ **Documentation:** Comprehensive reference created  
✅ **Logging:** Integrated with existing logging infrastructure  

## Next Steps for Users

1. **Run environment check** - Menu option 7 to verify setup
2. **Add missing variables** - Use option 6 if variables are missing
3. **Document configuration** - Reference the ENVIRONMENT-VARIABLES.md file
4. **Run ADS Setup** - Once all variables are set, proceed with option 1

---

**Implementation Details:**

- Total lines added: ~145 lines of code
- Function complexity: Moderate (uses associative arrays, file checks)
- Performance: Instantaneous (local checks only)
- Dependencies: `bash`, existing logging infrastructure, `whiptail`
