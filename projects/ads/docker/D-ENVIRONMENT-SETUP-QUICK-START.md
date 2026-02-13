# Quick Environment Variable Setup Guide

**For:** `/home/divix/divtools/scripts/ads/dt_ads_setup.sh`  
**Date:** January 8, 2026

## TL;DR - Quick Setup

1. Run setup script:
   ```bash
   /home/divix/divtools/scripts/ads/dt_ads_setup.sh
   ```

2. Select option **7** to check environment variables

3. If missing, select option **6** to set them

4. Run option **1** to start ADS setup

---

## Required Environment Variables Checklist

**All 8 of these must be set:**

- [ ] `ADS_DOMAIN=avctn.lan` (or your domain)
- [ ] `ADS_REALM=AVCTN.LAN` (uppercase)
- [ ] `ADS_WORKGROUP=AVCTN` (NetBIOS name, max 15 chars)
- [ ] `ADS_ADMIN_PASSWORD=SecurePass123!` (see password requirements)
- [ ] `ADS_HOST_IP=10.1.1.98` (DC host IP)
- [ ] `ADS_DNS_FORWARDER=8.8.8.8 8.8.4.4` (external DNS)
- [ ] `ADS_SERVER_ROLE=dc` (dc for domain controller)
- [ ] `ADS_DOMAIN_LEVEL=2016` (2008_R2, 2012, 2012_R2, or 2016)

---

## Where to Set Variables

### Option A: During Script (Recommended for First-Time)

```bash
./dt_ads_setup.sh → Option 6 → Answer prompts
```

**Pros:** Guided prompts, automatic saving  
**Cons:** Only works when running script

### Option B: Edit Host Environment File (Recommended for Permanent)

```bash
nano /home/divix/divtools/docker/sites/s01-7692nw/ads1-98/.env.ads1-98
```

Add this section:

```bash
# >>> DT_ADS_SETUP AUTO-MANAGED - DO NOT EDIT MANUALLY <<<
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

### Option C: Edit Samba Environment File

```bash
nano /home/divix/divtools/docker/sites/s01-7692nw/ads1-98/samba/.env.samba
```

Add this section:

```bash
# Domain Configuration
ADS_DOMAIN=avctn.lan
ADS_REALM=AVCTN.LAN
ADS_WORKGROUP=AVCTN
ADS_ADMIN_PASSWORD=SecurePassword123!
ADS_HOST_IP=10.1.1.98
ADS_DNS_FORWARDER=8.8.8.8 8.8.4.4
ADS_SERVER_ROLE=dc
ADS_DOMAIN_LEVEL=2016
```

---

## Password Requirements

**Minimum:** 8 characters (12+ recommended)

**Must include:**
- Uppercase letters (A-Z)
- Lowercase letters (a-z)
- Numbers (0-9)
- Special characters (!@#$%^&*)

**Examples:**
- ✓ `SecurePass123!`
- ✓ `Avctn@DC2024!`
- ✓ `MyDomain#Password99`
- ✗ `password` (too simple)
- ✗ `12345678` (no letters/special chars)

---

## Variable Source Locations

When you run the check (Option 7), it will tell you WHERE each variable came from:

```
✓ ADS_DOMAIN
    Source: /docker/sites/s01-7692nw/ads1-98/.env.ads1-98

✓ ADS_ADMIN_PASSWORD
    Source: .bash_profile (via load_env_files)
```

---

## Verification Steps

After setting variables, verify they work:

### Using Setup Script (Recommended)

```bash
# Run environment check in script
/home/divix/divtools/scripts/ads/dt_ads_setup.sh
# Select: Option 7 - Check Environment Variables
```

### Manual Verification

```bash
# Check host environment file
cat /home/divix/divtools/docker/sites/s01-7692nw/ads1-98/.env.ads1-98 | grep ADS_

# Check Samba environment file
ENV_FILE="/home/divix/divtools/docker/sites/s01-7692nw/ads1-98/samba/.env.samba"
cat "$ENV_FILE" | grep ADS_

# Run environment check in script
./dt_ads_setup.sh
# Select: Option 7 - Check Environment Variables
```

---

## Common Issues & Solutions

| Issue | Solution |
| ------- | ---------- |
| ✗ ADS_ADMIN_PASSWORD missing | Run option 6, or edit .env files directly |
| ✗ ADS_DOMAIN missing | Set domain name to match your network |
| ✓ Variables set but showing wrong source | Files are being read, check which one has your value |
| Password doesn't meet requirements | Must have uppercase, lowercase, number, special char |

---

## Optional Variables (Defaults Used if Not Set)

These will use defaults if not configured:

- `ADS_FOREST_LEVEL` (default: 2016)
- `ADS_DNS_BACKEND` (default: SAMBA_INTERNAL)
- `ADS_LOG_LEVEL` (default: 1)

---

## Next Steps After Setup

1. ✅ Check environment variables (Option 7)
2. ✅ Edit environment variables (Option 6) if needed
3. ✅ Run ADS Setup (Option 1)
4. ✅ Start Container (Option 2)
5. ✅ Check Status (Option 4)

For full documentation, see: `/home/divix/divtools/projects/ads/docs/ENVIRONMENT-VARIABLES.md`
