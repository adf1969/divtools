# ADS Setup Automation - Summary

**Last Updated:** December 6, 2025

## Overview

Comprehensive automation for Samba Active Directory Domain Controller deployment with:
- Interactive whiptail-based setup script
- Comprehensive pytest test suite
- Checkboxed implementation guide
- Automated environment management

## What Was Created

### 1. Updated Implementation Guide

**File:** `projects/ads/phase1-configs/IMPLEMENTATION-STEPS.md`

**Changes:**
- ✅ Added checkboxes to EVERY step and sub-step
- ✅ Added Steps 2-5 with detailed instructions
- ✅ Updated all container references from `samba-ads1` to `samba-ads`
- ✅ Added NTP configuration section (Step 0)
- ✅ Added domain membership checks

**Usage:**
Check off boxes as you complete each step in the deployment.

### 2. Interactive Setup Script

**File:** `scripts/ads/dt_ads_setup.sh`

**Features:**
- 🎯 Whiptail-based menu interface
- 🔧 ADS Setup: Creates folders, deploys files, validates config
- 🚀 Container Start/Stop: Manages samba-ads container
- ✅ Status Checks: Runs pytest test suite
- 🌐 DNS Configuration: Updates host DNS settings
- 💾 Environment Management: Stores settings in `.env.$HOSTNAME` with update markers
- 🧪 Test Mode: Run with `--test` to simulate actions
- 🐛 Debug Mode: Run with `--debug` for verbose output

**Usage:**
```bash
# Interactive menu
/home/divix/divtools/scripts/ads/dt_ads_setup.sh

# Test mode (no changes)
/home/divix/divtools/scripts/ads/dt_ads_setup.sh --test

# Debug mode
/home/divix/divtools/scripts/ads/dt_ads_setup.sh --debug
```

**Menu Options:**
1. **ADS Setup** - Creates folder structure, deploys compose files, prompts for env vars
2. **Start Container** - Starts samba-dc service (use `dcstart samba-dc` alias)
3. **Stop Container** - Stops samba-dc service (use `dcstop samba-dc` alias)
4. **Status Check** - Runs comprehensive pytest test suite (use `ads-status` alias)
5. **Configure DNS** - Updates host DNS to use localhost
6. **Edit Env Vars** - Re-prompts for environment variables
7. **View Logs** - Follows container logs (use `dclogs samba-dc` alias)
8. **Exit**

### 3. Python Test Suite

**Files:**
- `scripts/ads/test/test_ads.py` - pytest test suite
- `scripts/ads/test/requirements.txt` - Python dependencies
- `scripts/ads/test/README.md` - Test documentation

**Test Coverage:**
- ✅ Container Status (running, health)
- ✅ Domain Info (info, FSMO roles)
- ✅ DNS (SRV records, resolution, reverse lookup)
- ✅ LDAP (anonymous bind, rootDSE)
- ✅ SMB (shares list, smbstatus)
- ✅ Kerberos (realm config)
- ✅ Users & Groups (list operations)
- ✅ Replication (status query)
- ✅ Time Sync (< 5 minute difference)

**Manual Usage:**
```bash
# Create venv and install dependencies
cd /home/divix/divtools/scripts/ads
python3 -m venv .venv
source .venv/bin/activate
pip install -r test/requirements.txt

# Run all tests
pytest test/test_ads.py -v

# Run specific test class
pytest test/test_ads.py::TestDNS -v

# Run specific test
pytest test/test_ads.py::TestDNS::test_dns_srv_records -v
```

**Automated Usage:**
Tests are automatically run when you select "ADS Status Check" from `dt_ads_setup.sh` menu.

### 4. Updated Docker Compose Files

**Files:**
- `projects/ads/phase1-configs/docker-compose/dci-samba.yml`
- `projects/ads/phase1-configs/IMPLEMENTATION-STEPS.md`
- `projects/ads/phase1-configs/aliases/samba-aliases.sh`

**Changes:**
- ✅ Container name changed from `samba-${HOSTNAME}` to `samba-ads`
- ✅ All documentation updated to use `samba-ads`
- ✅ Bash aliases updated to detect `samba-ads` container
- ✅ Labels configured for docker_ps.sh grouping:
  ```yaml
  labels:
    - "divtools.group=ads"
    - "divtools.site=${SITE_NAME}"
    - "divtools.hostname=${HOSTNAME}"
    - "divtools.service=samba-dc"
  ```

### 5. Environment Variable Management

**File:** `docker/sites/$SITE_NAME/$HOSTNAME/.env.$HOSTNAME`

**Features:**
- Environment variables stored with update markers (like dt_host_setup.sh)
- Automatically loaded on subsequent runs
- Values presented as defaults when re-prompting
- Section markers:
  ```bash
  # >>> DT_ADS_SETUP AUTO-MANAGED - DO NOT EDIT MANUALLY <<<
  export ADS_DOMAIN="avctn.lan"
  ...
  # <<< DT_ADS_SETUP AUTO-MANAGED <<<
  ```

**Variables Managed:**
- `ADS_DOMAIN` - Domain name (e.g., avctn.lan)
- `ADS_REALM` - Realm (uppercase domain)
- `ADS_WORKGROUP` - NetBIOS workgroup name
- `ADS_ADMIN_PASSWORD` - Administrator password
- `ADS_HOST_IP` - Host IP address
- `ADS_DNS_FORWARDER` - DNS forwarders
- `ADS_SERVER_ROLE` - Server role (dc)
- `ADS_DOMAIN_LEVEL` - Domain functional level
- `ADS_LOG_LEVEL` - Logging verbosity
- `SITE_NAME` - Divtools site name
- `HOSTNAME` - Server hostname

## Quick Start Guide

### First-Time Setup

1. **Run the setup script:**
   ```bash
   cd /home/divix/divtools/scripts/ads
   ./dt_ads_setup.sh
   ```

2. **Select "ADS Setup" from menu:**
   - Prompts for domain name, realm, passwords, etc.
   - Creates folder structure with correct permissions
   - Deploys docker-compose files
   - Offers to install bash aliases
   - Creates/verifies Docker network

3. **Review generated files:**
   - Check `docker/sites/s01-7692nw/ads1-98/samba/dci-samba.yml`
   - Check `docker/sites/s01-7692nw/ads1-98/dc-ads1-98.yml`
   - Check `docker/sites/s01-7692nw/ads1-98/.env.ads1-98`

4. **Start the container:**
   - Select "Start Samba Container" from menu
   - Optionally watch logs during provisioning (2-5 minutes)

5. **Run status checks:**
   - Select "ADS Status Check" from menu
   - Tests will auto-create venv and run pytest
   - View detailed results

6. **Configure DNS:**
   - Select "Configure DNS on Host" from menu
   - Updates /etc/resolv.conf and systemd-resolved

### Using the Implementation Guide

Open `projects/ads/phase1-configs/IMPLEMENTATION-STEPS.md` in VS Code and check off boxes as you complete each step:

```markdown
## Step 1: Create Directory Structure

- [x] **Create directory structure**
- [x] **Set ownership and permissions**
```

### Running Tests Independently

```bash
# Activate venv
cd /home/divix/divtools/scripts/ads
source .venv/bin/activate

# Run all tests
pytest test/ -v

# Run only DNS tests
pytest test/test_ads.py::TestDNS -v

# Run with detailed output
pytest test/ -v --tb=short

# Deactivate when done
deactivate
```

## Environment Variables - Where They're Stored

1. **User prompts:** First time running "ADS Setup", script prompts for all values
2. **Storage location:** `docker/sites/$SITE_NAME/$HOSTNAME/.env.$HOSTNAME`
3. **Subsequent runs:** Values loaded from .env file and shown as defaults
4. **Manual editing:** Edit the file directly between the markers:
   ```bash
   nano docker/sites/s01-7692nw/ads1-98/.env.ads1-98
   ```

## Test Mode & Debug Mode

### Test Mode

Simulates all actions without making changes:

```bash
./dt_ads_setup.sh --test
```

**What it does:**
- Shows what folders would be created
- Shows what files would be copied
- Shows what commands would run
- NO permanent changes made

**Use when:**
- Verifying script behavior
- Reviewing what will happen
- Testing on production systems

### Debug Mode

Enables verbose logging:

```bash
./dt_ads_setup.sh --debug
```

**What it shows:**
- All variable values
- File paths
- Command execution details
- Function entry/exit

**Use when:**
- Troubleshooting issues
- Understanding script flow
- Reporting bugs

### Combined Mode

```bash
./dt_ads_setup.sh --test --debug
```

## Integration with Divtools

### docker_ps.sh Integration

The container is labeled for proper grouping:

```bash
docker_ps.sh
# Shows:
# Group: ads
#   samba-ads (running)
```

### Bash Aliases Integration

After installing aliases with the script:

```bash
source ~/.bash_aliases

# Use Samba tools directly:
samba-tool user list
ldapsearch -H ldap://localhost -x -b "DC=avctn,DC=lan"
kinit Administrator@AVCTN.LAN

# Management shortcuts:
ads-status      # Domain info
ads-fsmo        # FSMO roles
ads-logs        # Follow logs
ads-shell       # Shell in container
ads-restart     # Restart container
```

### Logging Utilities

The script uses the same logging utilities as other divtools scripts:

```bash
source scripts/util/logging.sh
log "INFO" "message"
log "WARN" "message"
log "ERROR" "message"
log "DEBUG" "message"
```

## File Structure

```
/home/divix/divtools/
├── projects/ads/phase1-configs/
│   ├── IMPLEMENTATION-STEPS.md          # Updated with checkboxes
│   ├── docker-compose/
│   │   ├── dci-samba.yml               # Updated: samba-ads container name
│   │   ├── dc-ads1-98.yml
│   │   ├── .env.samba
│   │   └── .env.samba.example
│   ├── scripts/
│   │   └── entrypoint.sh
│   └── aliases/
│       └── samba-aliases.sh            # Updated: samba-ads detection
├── scripts/ads/
│   ├── dt_ads_setup.sh                 # New: Interactive setup script
│   └── test/
│       ├── test_ads.py                 # New: pytest test suite
│       ├── requirements.txt            # New: Python dependencies
│       └── README.md                   # New: Test documentation
└── docker/sites/s01-7692nw/ads1-98/
    ├── .env.ads1-98                    # Generated by script
    ├── dc-ads1-98.yml                  # Deployed by script
    └── samba/
        ├── dci-samba.yml               # Deployed by script
        ├── .env.samba                  # Deployed by script
        └── entrypoint.sh               # Deployed by script
```

## Next Steps

1. **Run the setup script** to deploy your first DC (ads1-98)
2. **Use the checkboxed guide** in IMPLEMENTATION-STEPS.md to track progress
3. **Run status checks** after container starts to verify all services
4. **Join a Windows client** to test domain functionality
5. **Deploy second DC** (ads2-99) for high availability
6. **Schedule automated tests** via cron for continuous monitoring

## Troubleshooting

### Script Issues

**Whiptail not found:**
```bash
sudo apt install whiptail
```

**Logging function not found:**
```bash
# Ensure logging.sh exists
ls -l scripts/util/logging.sh
```

**Permission denied:**
```bash
chmod +x scripts/ads/dt_ads_setup.sh
```

### Test Issues

**pytest not found:**
```bash
cd scripts/ads
python3 -m venv .venv
source .venv/bin/activate
pip install -r test/requirements.txt
```

**Container not running:**
```bash
docker ps | grep samba-ads
# If not running:
cd docker/sites/s01-7692nw/ads1-98
docker compose -f dc-ads1-98.yml up -d
```

**Tests failing:**
```bash
# Check container logs
docker logs samba-ads

# Wait for provisioning (2-5 minutes after first start)
docker logs -f samba-ads
```

### Container Issues

**Port conflicts:**
```bash
# Check what's using port 53
sudo ss -tulpn | grep :53

# Stop systemd-resolved
sudo systemctl stop systemd-resolved
sudo systemctl mask systemd-resolved
```

**Time sync errors:**
```bash
# Fix NTP
sudo systemctl restart systemd-timesyncd
date  # Check time
```

## References

- **Implementation Steps:** `projects/ads/phase1-configs/IMPLEMENTATION-STEPS.md`
- **Setup Script:** `scripts/ads/dt_ads_setup.sh`
- **Test Suite:** `scripts/ads/test/README.md`
- **PRD:** `projects/ads/docs/PRD.md`
- **Project History:** `projects/ads/docs/PROJECT-HISTORY.md`
