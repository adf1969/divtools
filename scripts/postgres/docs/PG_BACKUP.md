# PostgreSQL Logical Backups Guide

## Overview

The `pg_backup.sh` script provides logical backups using `pg_dump` and `pg_dumpall` via Docker exec. These backups create SQL dumps that can be restored to any PostgreSQL version and are useful for:

- Database migrations
- Selective restores
- Archival in SQL format
- Disaster recovery validation
- Cross-version compatibility

## Quick Start

### Backup All Databases
```bash
# Interactive shell (loads environment from /etc/profile)
bash -i -c '/home/divix/divtools/scripts/postgres/pg_backup.sh -all -compress -email'
```

### Backup Specific Database
```bash
bash -i -c '/home/divix/divtools/scripts/postgres/pg_backup.sh -db myDatabase -compress -email'
```

### Test Mode (Recommended First Step)
```bash
bash -i -c '/home/divix/divtools/scripts/postgres/pg_backup.sh -all -test -debug'
```

## Command-Line Options

### Backup Selection
- `-all` - Backup all databases using `pg_dumpall` (creates single file with all DBs)
- `-db <name>` - Backup specific database using `pg_dump` (single database only)

### Backup Settings
- `-compress` - Gzip compress backup files (default: enabled, reduces size by 60-80%)
- `-nocompress` - Store backup as uncompressed SQL (not recommended for large databases)

### Retention Options (Smart Cleanup)
Backups are automatically cleaned up according to retention policies:

- `-retention <days>` - Keep backups modified within last N days (default: 7 days)
- `-retention-count <count>` - Keep last N backup files (0 = disabled, >0 = enforce maximum)
- `-max-size <MB>` - Keep oldest backups until total disk usage falls below size (0 = unlimited)

**Examples:**
```bash
# Keep backups for 7 days
./pg_backup.sh -all -retention 7

# Keep last 5 backup files
./pg_backup.sh -all -retention-count 5

# Combine: keep last 3 files OR backups from last 30 days (whichever is more conservative)
./pg_backup.sh -all -retention 30 -retention-count 3

# Keep total size under 500 MB, delete oldest first
./pg_backup.sh -all -max-size 500
```

### Storage Options
- `-backupdir <path>` - Directory for backup files (default: `/opt/pgbackup/backups`)
- `-logdir <path>` - Directory for log files (default: `/opt/pgbackup/logs`)

### Server Options
- `-server <hostname>` - PostgreSQL server (default: localhost)
- `-port <port>` - PostgreSQL port (default: 5432)

### Notifications & Debugging
- `-email` - Send email notification on completion
  - **SUCCESS**: Normal priority, includes backup summary
  - **FAILED**: HIGH priority with error details
- `-test` - Test mode (shows what would execute without making changes)
- `-debug` - Show detailed debug output

## Environment Requirements

The script requires running in an interactive shell so that `/etc/profile` sources the divtools `.bash_profile`:

```bash
# CORRECT: Interactive shell loads environment
bash -i -c '/home/divix/divtools/scripts/postgres/pg_backup.sh -all -email'

# WRONG: Non-interactive shell won't load SMTP_SERVER, etc.
/home/divix/divtools/scripts/postgres/pg_backup.sh -all -email
```

This ensures:
- `load_env_files()` is available to load divtools environment
- `SMTP_SERVER`, `PGADMIN_DEFAULT_EMAIL`, etc. are properly set
- Email notifications work correctly

## Usage Examples

### Daily All Databases Backup with Email
```bash
bash -i -c '/home/divix/divtools/scripts/postgres/pg_backup.sh -all -compress -email'
```
Backups all databases, compresses with gzip, cleans up files older than 7 days, sends email notification.

### Backup Specific Database with Extended Retention
```bash
bash -i -c '/home/divix/divtools/scripts/postgres/pg_backup.sh -db production -compress -retention 30'
```
Backups `production` database, keeps backups for 30 days, no email.

### Manual Backup with Debug Output (Test First)
```bash
bash -i -c '/home/divix/divtools/scripts/postgres/pg_backup.sh -all -test -debug'
```
Shows exactly what would execute without making changes. Verify this first before running for real.

### Backup with Limited File Count (Keep Disk Space Bounded)
```bash
bash -i -c '/home/divix/divtools/scripts/postgres/pg_backup.sh -all -compress -retention-count 5 -email'
```
Keeps maximum of 5 most recent backup files, automatically deletes older ones.

### Production Backup with Both Retention Policies
```bash
bash -i -c '/home/divix/divtools/scripts/postgres/pg_backup.sh -all -compress -retention 14 -retention-count 10 -email'
```
Keeps backups: max 10 files AND within last 14 days (whichever constraint is more restrictive).

## Directory Structure

```
/opt/pgbackup/
├── backups/                       # Backup files (automatically cleaned up)
│   ├── pgdumpall-20251230-020000.sql.gz     (all databases)
│   ├── pgdumpall-20251229-020000.sql.gz     (all databases)
│   ├── pgdump-mydb-20251230-143000.sql.gz   (specific database)
│   └── pgdump-mydb-20251229-143000.sql.gz   (specific database)
└── logs/                          # Backup logs
    ├── pgdumpall-20251230-020000.log
    ├── pgdumpall-20251229-020000.log
    └── pgdump-mydb-20251230-143000.log
```

## CRON Integration

**IMPORTANT**: All cron jobs must use `bash -i -c` to ensure environment loads correctly.

### Daily All Databases Backup (2 AM)
```bash
0 2 * * * bash -i -c '/opt/divtools/scripts/postgres/pg_backup.sh -all -compress -email -retention 7' >> /opt/pgbackup/logs/cron.log 2>&1
```

### Specific Database Backup (Daily at 3 AM)
```bash
0 3 * * * bash -i -c '/opt/divtools/scripts/postgres/pg_backup.sh -db myapp_prod -compress -email' >> /opt/pgbackup/logs/cron.log 2>&1
```

### Bounded Storage Strategy (Keep Last 5 Files)
```bash
0 2 * * * bash -i -c '/opt/divtools/scripts/postgres/pg_backup.sh -all -compress -retention-count 5 -email' >> /opt/pgbackup/logs/cron.log 2>&1
```

## Retention Strategies

### Day-Based Retention (Default)
```bash
bash -i -c '/home/divix/divtools/scripts/postgres/pg_backup.sh -all -retention 7'
```
- Deletes backup files older than 7 days
- Useful for: regular cleanup, operational windows

### Count-Based Retention
```bash
bash -i -c '/home/divix/divtools/scripts/postgres/pg_backup.sh -all -retention-count 5'
```
- Always keeps exactly the last N backup files
- Deletes oldest when count exceeded
- Useful for: bounded disk space, fixed recovery points

### Combined Retention (Recommended)
```bash
bash -i -c '/home/divix/divtools/scripts/postgres/pg_backup.sh -all -retention 30 -retention-count 3'
```
- Keeps files matching BOTH conditions
- Result: max 3 files that are within last 30 days
- Most conservative approach (recommended for production)

## Email Notifications

When using `-email` flag, the script sends status emails:

### SUCCESS Email (Normal Priority)
Sent on successful backup completion:
```
Status: SUCCESS
Backup Summary:
- Total files: 3
- Total size: 15.2 MB
- Backup location: /opt/pgbackup/backups
- Retention: 7 days
- Max files: 3
```

### FAILED Email (HIGH Priority Only)
Sent only on backup failure with error details for investigation.

### SMTP Configuration
The script uses port 25 (relay) instead of port 587 for:
- More reliable delivery (less strict validation)
- No authentication required
- Faster email sending

Environment variables (loaded from `/etc/profile` → `.bash_profile` → `load_env_files()`):
- `SMTP_SERVER` (default: `monitor`)
- `SMTP_PORT` (default: 25)
- `PGADMIN_DEFAULT_EMAIL` (required for notifications)

## Backup Formats

### All Databases Backup (pg_dumpall)
```bash
bash -i -c '/home/divix/divtools/scripts/postgres/pg_backup.sh -all'
```

Creates single SQL file containing:
- All databases in cluster
- All users and roles
- Database privileges
- Global settings

File naming: `pgdumpall-YYYYMMDD-HHMMSS.sql.gz`
Typical size: 1-10 MB (compressed)

### Specific Database Backup (pg_dump)
```bash
bash -i -c '/home/divix/divtools/scripts/postgres/pg_backup.sh -db mydb'
```

Creates single SQL file containing:
- Single database schema and data
- Database-specific settings

File naming: `pgdump-DBNAME-YYYYMMDD-HHMMSS.sql.gz`
Size varies by database

## Restore Operations

### Restore All Databases
```bash
gunzip -c /opt/pgbackup/backups/pgdumpall-20251230-020000.sql.gz | \
  docker exec -i postgres psql -U postgres
```

### Restore Specific Database
```bash
# Drop if exists
docker exec postgres dropdb -U postgres mydb

# Restore
gunzip -c /opt/pgbackup/backups/pgdump-mydb-20251230-143000.sql.gz | \
  docker exec -i postgres psql -U postgres -d mydb
```

### Restore to Different Server
```bash
gunzip -c backup.sql.gz | psql -h remote-server -U postgres -d mydb
```

## Troubleshooting

### "SMTP server not configured"
**Cause**: Running in non-interactive shell (environment not loaded)
**Solution**: Use `bash -i -c` wrapper
```bash
# Wrong
./pg_backup.sh -all -email

# Correct
bash -i -c '/home/divix/divtools/scripts/postgres/pg_backup.sh -all -email'
```

### "PostgreSQL container not running"
```bash
docker ps | grep postgres
docker start postgres  # If needed
```

### "Permission denied" on backup directory
```bash
sudo chown -R $(whoami):$(id -gn) /opt/pgbackup
```

### Backup file corruption test
```bash
gzip -t /opt/pgbackup/backups/*.sql.gz
```

## Comparison: Physical vs Logical Backups

| Aspect | pgBackRest (Physical) | pg_dump (Logical) |
|--------|----------------------|-------------------|
| Speed | Very fast | Slower for large DB |
| Recovery | Fast point-in-time | Full or selective restore |
| Size | Smaller (incremental) | Larger (full copy) |
| Portability | Version-specific | Any PostgreSQL version |
| Restore | Full database | Selective possible |
| Format | Raw blocks | SQL text |

**Best practice**: Use both methods
- **pgBackRest**: Crash recovery, point-in-time restore
- **pg_dump**: Archival, migration, upgrades, selective restore

## Related Documentation

- **Physical Backups**: `docs/PGBACKREST-SETUP.md`
- **pgBackRest Script**: `scripts/postgres/pg_backrest_backup.sh`
- **Email Utility**: `scripts/smtp/send_email.py`

## Last Updated: 2025-12-30
