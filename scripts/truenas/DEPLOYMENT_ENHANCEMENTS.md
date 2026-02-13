# Enhanced Deployment Script Summary

## What Changed

The `deploy_to_truenas.sh` script has been significantly enhanced with the following features:

### 1. Configuration Settings (Top of Script)
```bash
# ===== CONFIGURATION SETTINGS =====
UPDATE_INTERVAL_MINUTES=30       # How often cron runs (default: 30 min)
ZFS_PARENT_DATASET="tpool/FieldsHm"  # Dataset to monitor
EXPORT_FILENAME=".zfs_usage_info"    # Output filename
# =================================
```

### 2. System Verification
The script now:
- ✓ **Verifies ZFS is available** on the target system
- ✓ **Confirms the dataset exists** before deploying
- ✓ **Detects system type** (TrueNAS, FreeBSD, Linux)
- ✓ **Shows dataset mountpoint** for verification

### 3. Automatic Cron Setup
The script now:
- ✓ **Automatically adds cron job** based on `UPDATE_INTERVAL_MINUTES`
- ✓ **Checks for existing entries** to prevent duplicates
- ✓ **Verifies cron entry** after adding
- ✓ **Smart schedule calculation**:
  - Minutes < 60: `*/N * * * *` format
  - Minutes ≥ 60: `0 */H * * *` format (hourly)

### 4. New Options
- `--skip-cron` - Deploy without setting up cron (for manual setup)
- Enhanced `--help` showing current configuration
- Better error messages and validation

### 5. Improved Output
The script now shows a comprehensive deployment summary:
```
=========================================
Deployment Summary
=========================================
System Type:     TrueNAS
Dataset:         tpool/FieldsHm
Update Interval: 30 minutes
Script Location: /root/scripts/tns_upd_size.sh
Cron Job:        Configured ✓
=========================================
```

## Usage Examples

### Basic Deployment (Automated)
```bash
# Deploy with automatic cron setup
./scripts/truenas/deploy_to_truenas.sh -h NAS1-1

# Result: Scripts copied, tested, cron configured (30 min interval)
```

### Test Mode (See What Would Happen)
```bash
# Dry run to see all actions
./scripts/truenas/deploy_to_truenas.sh -h NAS1-1 -test -debug
```

### Deploy Without Cron
```bash
# Deploy scripts only, configure cron manually
./scripts/truenas/deploy_to_truenas.sh -h NAS1-1 --skip-cron
```

### Custom Configuration
```bash
# 1. Edit the script
vi scripts/truenas/deploy_to_truenas.sh

# 2. Change these values:
UPDATE_INTERVAL_MINUTES=15           # Run every 15 minutes
ZFS_PARENT_DATASET="tank/Media"      # Different dataset

# 3. Deploy
./scripts/truenas/deploy_to_truenas.sh -h NAS1-1
```

## Safety Features

### Duplicate Prevention
The script checks for existing cron entries:
- If found with **same command**: Skips adding (no duplicates)
- If found with **different command**: Shows warning, doesn't modify
- If not found: Adds new entry

### Validation Before Deployment
- Tests SSH connection
- Verifies ZFS command exists
- Confirms dataset exists
- Shows dataset mountpoint
- Runs test execution before enabling

### Test Mode
Use `-test` flag to see all commands without executing:
```bash
./scripts/truenas/deploy_to_truenas.sh -h NAS1-1 -test
```

## What Gets Deployed

1. **Script**: `/root/scripts/tns_upd_size.sh`
2. **Utilities**: `/root/scripts/util/logging.sh`
3. **Cron Entry**: Runs script every N minutes (configurable)
4. **Log File**: `/var/log/zfs_usage.log`

## Cron Schedule Examples

Based on `UPDATE_INTERVAL_MINUTES`:

| Interval | Cron Schedule | Description |
|----------|---------------|-------------|
| 5 | `*/5 * * * *` | Every 5 minutes |
| 10 | `*/10 * * * *` | Every 10 minutes |
| 15 | `*/15 * * * *` | Every 15 minutes |
| 30 | `*/30 * * * *` | Every 30 minutes (default) |
| 60 | `0 * * * *` | Every hour |
| 120 | `0 */2 * * *` | Every 2 hours |

## Troubleshooting

### "Dataset not found"
```bash
# List available datasets on TrueNAS:
ssh root@NAS1-1 "zfs list -o name"

# Update ZFS_PARENT_DATASET in the script
```

### "Cron entry differs from desired"
The script found an existing cron entry but with different parameters.
To update manually:
```bash
ssh root@NAS1-1
crontab -e
# Update the line with tns_upd_size.sh
```

### Test the deployed script
```bash
# SSH to TrueNAS and run manually
ssh root@NAS1-1
/root/scripts/tns_upd_size.sh -test -debug
```

### View cron log
```bash
ssh root@NAS1-1
tail -f /var/log/zfs_usage.log
```

## Related Files

- `scripts/truenas/deploy_to_truenas.sh` - Enhanced deployment script
- `scripts/truenas/tns_upd_size.sh` - TrueNAS usage export script
- `scripts/truenas/QUICKSTART.md` - Updated quick start guide
- `scripts/truenas/README.md` - Full documentation
- `scripts/util/truenas_usage.sh` - Client-side helper functions
- `dotfiles/.bash_profile` - Enhanced df_color() function

---
Last Updated: 11/4/2025 10:30:00 PM CST
