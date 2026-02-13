# TrueNAS Usage Correction - Quick Start

## What This Solves
When you mount a TrueNAS ZFS dataset via NFS/SMB, `df` shows incorrect usage because it reports the parent dataset's quota, not the actual space used by child datasets.

## Solution Overview
1. **TrueNAS script** exports actual ZFS usage to a file
2. **Enhanced df_color()** reads that file and shows correct values

## Quick Setup

### Automated Setup (Recommended)

The deployment script will:
- ✓ Verify the target system has ZFS
- ✓ Check that the dataset exists
- ✓ Copy scripts to TrueNAS
- ✓ Test the script
- ✓ Add cron job automatically (runs every 30 minutes by default)
- ✓ Prevent duplicate cron entries

```bash
# Basic deployment
./scripts/truenas/deploy_to_truenas.sh -h NAS1-1

# Test mode (see what would happen)
./scripts/truenas/deploy_to_truenas.sh -h NAS1-1 -test -debug

# Deploy without setting up cron (manual setup)
./scripts/truenas/deploy_to_truenas.sh -h NAS1-1 --skip-cron
```

**Configuration Options:**
Edit `scripts/truenas/deploy_to_truenas.sh` to change:
- `UPDATE_INTERVAL_MINUTES=30` - How often to update (default: 30 minutes)
- `ZFS_PARENT_DATASET="tpool/FieldsHm"` - Dataset to monitor
- `EXPORT_FILENAME=".zfs_usage_info"` - Output filename

### Manual Setup

If you prefer to do it manually:

#### Step 1: Copy Scripts
```bash
scp scripts/truenas/tns_upd_size.sh root@NAS1-1:/root/scripts/
scp scripts/util/logging.sh root@NAS1-1:/root/scripts/util/
ssh root@NAS1-1 "chmod +x /root/scripts/tns_upd_size.sh"
```

#### Step 2: Test on TrueNAS
```bash
ssh root@NAS1-1
/root/scripts/tns_upd_size.sh -test -debug

# If it looks good, run for real:
/root/scripts/tns_upd_size.sh

# Verify the file was created:
cat /mnt/tpool/FieldsHm/.zfs_usage_info
```

#### Step 3: Add Cron Job on TrueNAS
Via TrueNAS Web UI:
- **Tasks → Cron Jobs → Add**
- Command: `/root/scripts/tns_upd_size.sh`
- Schedule: Every 30 minutes
- User: root

Or via command line:
```bash
ssh root@NAS1-1
crontab -e

# Add this line (every 30 minutes):
*/30 * * * * /root/scripts/tns_upd_size.sh >> /var/log/zfs_usage.log 2>&1
```

### Final Step: On Your Client Systems
```bash
# The enhanced df_color() is already in your .bash_profile
# Just reload it:
source ~/.bash_profile

# Or start a new shell
```

### Test It
```bash
# Run your normal df command:
dfc

# You should now see correct usage for //NAS1-1/FieldsHm
# Before: 12T  7.5G   12T   1%  ← WRONG
# After:  20T  8.3T   12T  41%  ← CORRECT

# To see debug info:
dfc -debug
```

## Testing the Setup

Run the test script to verify everything:
```bash
./scripts/truenas/test_usage_correction.sh
```

This will:
- Check if helper scripts exist
- Look for remote mounts
- Check for .zfs_usage_info files
- Test the extraction function
- Run dfc with debug output

## Files Created

| File | Purpose |
|------|---------|
| `scripts/truenas/tns_upd_size.sh` | TrueNAS script to export ZFS usage |
| `scripts/util/truenas_usage.sh` | Helper functions to read usage data |
| `scripts/truenas/README.md` | Detailed documentation |
| `scripts/truenas/test_usage_correction.sh` | Test script |
| `scripts/truenas/.zfs_usage_info.example` | Example usage file |
| `dotfiles/.bash_profile` | Enhanced df_color() function |

## What Gets Modified

**Enhanced:** `dotfiles/.bash_profile`
- The `df_color()` function now checks for remote mounts
- If found, reads `.zfs_usage_info` from the mount point
- Displays corrected values automatically

**No changes needed to:**
- Your existing aliases
- Your dfc command
- Any other scripts

## Configuration Options

### For Different Datasets
Edit `deploy_to_truenas.sh` before running:
```bash
# Change these variables at the top of the script:
UPDATE_INTERVAL_MINUTES=30          # How often to run (default: 30 minutes)
ZFS_PARENT_DATASET="tpool/FieldsHm" # Dataset to monitor
EXPORT_FILENAME=".zfs_usage_info"   # Output filename
```

### For Multiple Datasets
Deploy separately for each dataset:
```bash
# Edit the script to change ZFS_PARENT_DATASET, then run:
./scripts/truenas/deploy_to_truenas.sh -h NAS1-1

# Or run the script manually with different parameters:
ssh root@NAS1-1 '/root/scripts/tns_upd_size.sh -d tank/Media -f /mnt/tank/Media/.zfs_usage_info'
```

### Update Frequency
Default is 30 minutes. To change:
- Edit `UPDATE_INTERVAL_MINUTES` in `deploy_to_truenas.sh`
- Or manually edit crontab on TrueNAS

Common values:
- Every 5 minutes: `UPDATE_INTERVAL_MINUTES=5`
- Every 15 minutes: `UPDATE_INTERVAL_MINUTES=15`
- Every 30 minutes: `UPDATE_INTERVAL_MINUTES=30` (default)
- Every hour: `UPDATE_INTERVAL_MINUTES=60`

## Troubleshooting

**Client doesn't show corrected values?**
1. Check if file exists: `ls -la /mnt/NAS1-1/FieldsHm/.zfs_usage_info`
2. Check if readable: `cat /mnt/NAS1-1/FieldsHm/.zfs_usage_info`
3. Run with debug: `dfc -debug`

**Script fails on TrueNAS?**
1. Check dataset exists: `zfs list tpool/FieldsHm`
2. Run in test mode: `./tns_upd_size.sh -test -debug`
3. Check log: `tail /var/log/zfs_usage.log`

## Next Steps

1. Copy scripts to TrueNAS
2. Run test on TrueNAS
3. Add cron job
4. Test on client with `dfc -debug`
5. Enjoy accurate disk usage! 🎉

See `README.md` for detailed documentation.

---
Last Updated: 11/4/2025 10:00:00 PM CST
