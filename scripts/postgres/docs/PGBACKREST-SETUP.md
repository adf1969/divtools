# pgBackRest Setup Guide

## Local File System Backup

pgBackRest performs **physical backups** of PostgreSQL data files. Since the PostgreSQL Docker container's data is bind-mounted to `/opt/postgres` on the host, pgBackRest can access it directly without SSH.

### Setup Steps

#### 1. Verify PostgreSQL Data Mount
Confirm that PostgreSQL data is bind-mounted at `/opt/postgres`:

```bash
# Check that the mount exists and contains pgdata
ls -la /opt/postgres/pgdata
```

You should see PostgreSQL's data directory structure (base, global, pg_wal, etc.).

#### 2. Initialize pgBackRest Directories
Create the backup repository directories:

```bash
# Create base directory
mkdir -p /opt/pgbackrest/{backup,log}

# Set appropriate permissions
chmod 700 /opt/pgbackrest
chmod 700 /opt/pgbackrest/backup
chmod 700 /opt/pgbackrest/log
```

#### 3. Verify Configuration
Ensure `pgbackrest.conf` points to the correct local paths:

```bash
cat /home/divix/divtools/docker/sites/s01-7692nh/tnapp01/pgbackrest/pgbackrest.conf
```

Key settings:
- `repo-path=/opt/pgbackrest` - Backup repository
- `db-path=/opt/postgres/pgdata` - PostgreSQL data location
- `log-path=/opt/pgbackrest/log` - Logs

#### 4. Test the Backup Script
Run the backup script in test mode:

```bash
./scripts/postgres/pg_backrest_backup.sh -test -debug
```

Expected output:
- Directory structure verified
- Config file validation successful
- Would execute backup command

#### 5. Run First Backup
Perform an initial full backup:

```bash
# Full backup (recommended for first backup)
./scripts/postgres/pg_backrest_backup.sh -full -debug

# Or with email notification
./scripts/postgres/pg_backrest_backup.sh -full -email
```

### Configuration Options

In `pgbackrest.conf`:

```ini
[global]
repo-path=/opt/pgbackrest          # Backup storage location
compress-type=gz                   # Compression (gz, bzip2, or none)
compress-level=9                   # Compression level (1-9)
retention-full=7                   # Keep last 7 full backups
retention-full-type=count          # Retention by count

[postgres]
db-path=/opt/postgres/pgdata       # Local PostgreSQL data directory
backup-type=incr                   # Backup type (incr or full)
```

### Backup Types

- **Incremental backup** (default): Only backs up changed blocks since last backup
- **Full backup**: Complete copy of all data files

Use full backup:
- First time
- Periodically (weekly/monthly) as base for incremental backups
- For disaster recovery baseline

```bash
# Full backup
./pg_backrest_backup.sh -full

# Incremental backup (faster, uses less space)
./pg_backrest_backup.sh -incr  # or just ./pg_backrest_backup.sh
```

### CRON Integration (Final Setup Step)

Schedule regular backups with optimized incremental strategy for fast execution:

```bash
# Daily full backup at 2:00 AM (resets incremental chain, ~72 seconds)
0 2 * * * /home/divix/divtools/scripts/postgres/pg_backrest_backup.sh -full >> /var/log/pgbackrest-cron.log 2>&1

# Incremental backup every 4 hours (only changed blocks, very fast)
0 */4 * * * /home/divix/divtools/scripts/postgres/pg_backrest_backup.sh -incr >> /var/log/pgbackrest-cron.log 2>&1
```

#### Schedule Explanation

This recommended schedule provides an optimal balance between backup frequency and resource utilization:

- **Recovery Point Objective (RPO):** 4 hours (lose at most 4 hours of data on recovery)
- **Daily Backups:** 1 full + 6 incremental backups = 7 total backups per day
- **Storage Per Day:** ~54MB (based on observed 69.4MB database with 9:1 compression)
- **Daily Storage Over 30 Days:** ~1.6GB (well within retention of 4 full + 6 differential)
- **Full Backup Duration:** ~72 seconds (fast enough for automated scheduling)
- **Incremental Duration:** Much faster (only changed blocks since last backup)

#### Setup Instructions

1. **Create log directory if needed:**
   ```bash
   sudo mkdir -p /var/log
   touch /var/log/pgbackrest-cron.log
   sudo chmod 666 /var/log/pgbackrest-cron.log
   ```

2. **Add cron entries:**
   ```bash
   crontab -e
   # Then paste the two cron entries above
   ```

3. **Verify cron entries were added:**
   ```bash
   crontab -l
   ```

4. **Monitor backup execution:**
   ```bash
   tail -f /var/log/pgbackrest-cron.log
   ```

#### Why This Schedule?

Given that:
- Full backups complete in ~72 seconds (acceptable overhead)
- Incremental backups are much faster (only changes)
- Retention policy keeps 4 full backups + 6 differentials (30-day window)
- Most production environments benefit from sub-24-hour RPO

This 4-hour backup interval provides:
- ✅ Frequent recovery points (4-hour intervals)
- ✅ Fast backup execution (no impact on production)
- ✅ Reasonable storage requirements (~54MB/day)
- ✅ Multiple backup generations for restore options

### Directory Structure

```
/opt/pgbackrest/
├── log/                           # pgBackRest logs
│   ├── pgbackrest.log
│   └── cron.log
└── backup/                        # Backup repository
    ├── backup.manifest            # Backup metadata
    └── [backup-files]             # Compressed backup data
```

### Troubleshooting

#### "pg_controldata not found"
pgBackRest uses `pg_controldata` to verify database integrity. Install PostgreSQL client tools:

```bash
# On Debian/Ubuntu
sudo apt-get install postgresql-client-16

# Verify installation
which pg_controldata
```

#### "Cannot access database directory"
Verify permissions on `/opt/postgres`:

```bash
# Check ownership and permissions
ls -la /opt/postgres/

# Should be readable by the user running pgBackRest (usually root)
```

#### "Docker container not accessible"
Ensure PostgreSQL container is running:

```bash
docker ps | grep postgres
```

### Email Notifications

Send backup reports via email:

```bash
./pg_backrest_backup.sh -full -email      # Full backup with email
./pg_backrest_backup.sh -incr -email      # Incremental backup with email
./pg_backrest_backup.sh -test-email       # Test email configuration
```

Requires environment variables:
- `PGADMIN_DEFAULT_EMAIL` - Recipient address (e.g., andrew@avcorp.biz)
- `SMTP_SERVER` - SMTP server hostname (e.g., monitor)
- `SMTP_PORT` - SMTP port (default: 25 for relay, 587 for submission with auth)

#### Email Status Messages

The script intelligently handles pgBackRest exit codes to provide accurate status:

**SUCCESS** - New files backed up successfully
- Occurs when backup includes changes since last backup
- Email shows file count and backup location

**SUCCESS - NO CHANGES** - Database unchanged (exit code 55)
- Normal, healthy condition when database has not been modified
- No backup files created (this is not an error!)
- Previous backup remains current and ready for recovery
- Common with frequent incremental backup schedules

**FAILED** - Real backup errors
- Occurs on actual pgBackRest errors (disk full, permissions, etc.)
- Check logs in `/var/log/pgbackrest` for details
- Real failure requiring investigation and action

#### SMTP Port Selection

- **Port 25** (default, recommended): Open relay - allows relay from trusted networks
  - Best for internal mail relays without authentication
  - Monitor postfix configured for this: `mynetworks = 127.0.0.0/8,192.168.0.0/16,10.0.0.0/8,...`
  - Less strict recipient validation

- **Port 587** (submission): Requires SMTP authentication
  - Use with credentials for external SMTP services
  - Stricter recipient validation (may reject external addresses without auth)

### Related Documentation

- **Setup Guide:** This file (`PGBACKREST-SETUP.md`)
- **Logical Backups:** `docs/PG_BACKUP.md` (pg_dump/pg_dumpall)
- **Configuration:** `docker/sites/s01-7692nh/tnapp01/pgbackrest/pgbackrest.conf`
- **Changelog:** `docs/PROJECT-CHANGELOG.md`
