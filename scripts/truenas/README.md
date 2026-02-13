# TrueNAS ZFS Usage Correction for Remote Mounts

## Problem
When NFS/SMB clients mount a TrueNAS ZFS parent dataset that contains child datasets, `df` shows incorrect usage information. The client sees the parent dataset's quota/space, not the actual combined usage of all child datasets.

### Example Problem:
**On TrueNAS:**
```
tpool/FieldsHm/HASS                 2.9T  160K  2.9T   1%
tpool/FieldsHm/MEDIA                 19T  7.1T   12T  39%
tpool/FieldsHm/HASS/frigate         4.0T  1.2T  2.9T  29%
```

**On NFS/SMB Client:**
```
//NAS1-1/FieldsHm                    12T  7.5G   12T   1%  ← WRONG!
```

The client shows 7.5G used when the actual usage is ~8.3T (7.1T MEDIA + 1.2T frigate).

## Solution
This solution uses two components:

1. **TrueNAS Script** (`tns_upd_size.sh`): Exports actual ZFS dataset usage to a file
2. **Enhanced `df_color()` Function**: Reads the exported data and displays corrected values on clients

## Setup Instructions

### 1. On TrueNAS Server

#### Install the Script
```bash
# Copy the script to TrueNAS
scp scripts/truenas/tns_upd_size.sh root@truenas:/root/scripts/
scp scripts/util/logging.sh root@truenas:/root/scripts/util/

# Make executable
ssh root@truenas "chmod +x /root/scripts/tns_upd_size.sh"
```

#### Test the Script
```bash
# Test mode - see what would be written
ssh root@truenas "/root/scripts/tns_upd_size.sh -test -debug"

# Actual run
ssh root@truenas "/root/scripts/tns_upd_size.sh -debug"

# Verify the export file was created
ssh root@truenas "cat /mnt/tpool/FieldsHm/.zfs_usage_info"
```

#### Configure Cron Job
Add to TrueNAS cron (via web UI or command line):

**Via Web UI:**
- Go to: Tasks → Cron Jobs → Add
- Description: `Update ZFS Usage Info`
- Command: `/root/scripts/tns_upd_size.sh`
- Schedule: Every 5 minutes (or as desired)
- User: `root`

**Via Command Line:**
```bash
ssh root@truenas
crontab -e

# Add this line (runs every 5 minutes):
*/5 * * * * /root/scripts/tns_upd_size.sh >> /var/log/zfs_usage.log 2>&1
```

### 2. On Client Systems

#### Reload Your Bash Profile
The enhanced `df_color()` function is already in your `.bash_profile`. Simply reload it:

```bash
source ~/.bash_profile
```

Or start a new shell session.

#### Test the Enhanced Function
```bash
# Regular df output
dfc

# With debug output to see TrueNAS corrections
dfc -debug
```

## How It Works

### TrueNAS Script (`tns_upd_size.sh`)
1. Queries ZFS for actual dataset usage: `zfs list -r tpool/FieldsHm`
2. Exports data to `/mnt/tpool/FieldsHm/.zfs_usage_info`
3. File is accessible to NFS/SMB clients mounting the share

### Client Function (`df_color()`)
1. Runs `df` as normal
2. For each mounted filesystem:
   - Detects if it's a remote NFS/SMB mount
   - Checks for `.zfs_usage_info` file in the mount point
   - If found, reads actual usage from the file
   - Recalculates usage percentage
   - Displays corrected values

## File Format

The `.zfs_usage_info` file uses this format:

```ini
# ZFS Dataset Usage Information
# Generated: 2025-11-04 21:30:00
# Parent Dataset: tpool/FieldsHm
# Format: dataset|used|available|referenced|mountpoint

[PARENT]
name=tpool/FieldsHm
used=8.3T
available=11.7T
mountpoint=/mnt/tpool/FieldsHm

[DATASET:HASS]
used=1.2T
available=2.9T
referenced=160K
mountpoint=/mnt/tpool/FieldsHm/HASS

[DATASET:MEDIA]
used=7.1T
available=12T
referenced=7.1T
mountpoint=/mnt/tpool/FieldsHm/MEDIA
```

## Script Options

### `tns_upd_size.sh` Options:
```
-test, --test       Run in test mode (no file writes)
-debug, --debug     Enable debug output
-f, --file FILE     Export file path (default: /mnt/tpool/FieldsHm/.zfs_usage_info)
-d, --dataset DS    Parent dataset (default: tpool/FieldsHm)
-h, --help          Show help message
```

### Examples:
```bash
# Test run with debug output
./tns_upd_size.sh -test -debug

# Export to custom location
./tns_upd_size.sh -f /mnt/tank/mydata/.zfs_usage_info -d tank/mydata

# Normal run for production
./tns_upd_size.sh
```

## Troubleshooting

### Client doesn't show corrected values
1. Check if `.zfs_usage_info` exists in the mount:
   ```bash
   ls -la /mnt/NAS1-1/FieldsHm/.zfs_usage_info
   ```

2. Check if file is readable:
   ```bash
   cat /mnt/NAS1-1/FieldsHm/.zfs_usage_info
   ```

3. Run with debug:
   ```bash
   dfc -debug
   ```

4. Check mount type:
   ```bash
   df -T /mnt/NAS1-1/FieldsHm
   # Should show: nfs, nfs4, cifs, or smbfs
   ```

### Script fails on TrueNAS
1. Check if ZFS is available:
   ```bash
   zfs list
   ```

2. Check dataset exists:
   ```bash
   zfs list tpool/FieldsHm
   ```

3. Check permissions:
   ```bash
   ls -ld /mnt/tpool/FieldsHm
   ```

4. Run in test mode:
   ```bash
   ./tns_upd_size.sh -test -debug
   ```

## Multiple Datasets
To monitor multiple parent datasets, run the script multiple times with different parameters:

```bash
# Add to cron:
*/5 * * * * /root/scripts/tns_upd_size.sh -d tpool/FieldsHm -f /mnt/tpool/FieldsHm/.zfs_usage_info
*/5 * * * * /root/scripts/tns_upd_size.sh -d tank/Media -f /mnt/tank/Media/.zfs_usage_info
*/5 * * * * /root/scripts/tns_upd_size.sh -d backup/Archive -f /mnt/backup/Archive/.zfs_usage_info
```

## Related Files
- **TrueNAS Script**: `scripts/truenas/tns_upd_size.sh`
- **Helper Functions**: `scripts/util/truenas_usage.sh`
- **Enhanced df_color()**: `dotfiles/.bash_profile` (line ~1200)
- **Alias**: `dotfiles/.bash_aliases` (dfc → df_color)

## Last Updated
11/4/2025 9:50:00 PM CST
