# PostgreSQL Scripts - Project Changelog

## 2025-12-30: Local File System Backup Configuration

### Major Changes

#### PostgreSQL Backup Architecture Updated
- **Previous approach**: SSH-based remote backups (impractical for Docker container)
- **New approach**: Local file system access to bind-mounted PostgreSQL data
- **Data location**: `/opt/postgres/pgdata` (bind-mounted from Docker container)
- **Backup storage**: `/opt/pgbackrest/` (physical backups) and `/opt/pgbackup/` (logical backups)

#### Updated Files

1. **pgbackrest.conf** - Changed to local backup configuration
   - Removed SSH host configuration
   - Set `db-path=/opt/postgres/pgdata` (local mount point)
   - Local backup repository at `/opt/pgbackrest`
   - No SSH authentication needed

2. **pg_backrest_backup.sh** - Updated for local backups
   - Added validation of PostgreSQL data directory (`/opt/postgres/pgdata`)
   - Removed SSH-related code
   - Verifies Docker container is accessible via bind mount
   - Added directory structure verification

3. **pg_backup.sh** - Complete rewrite for Docker-based logical backups
   - Uses `docker exec` to run `pg_dump` and `pg_dumpall`
   - Full argument parsing for flexible backup options
   - Automatic backup retention/cleanup
   - Email notification support
   - Test mode for validation
   - Complete divtools standards compliance

### Two-Tier Backup Strategy

#### Physical Backups (pgBackRest)
**Purpose**: Crash recovery and point-in-time restore
- Location: `/opt/pgbackrest/backup/`
- Type: Physical file blocks
- Recovery: Full or point-in-time
- File format: Custom pgBackRest format (compressed)

**Usage:**
```bash
./scripts/postgres/pg_backrest_backup.sh -full        # Full backup
./scripts/postgres/pg_backrest_backup.sh              # Incremental backup
./scripts/postgres/pg_backrest_backup.sh -email       # With notification
```

#### Logical Backups (pg_dump/pg_dumpall)
**Purpose**: Database migration, archival, selective restore
- Location: `/opt/pgbackup/backups/`
- Type: SQL format
- Recovery: Full database restore
- File format: SQL (text or custom format, gzip compressed)

**Usage:**
```bash
./scripts/postgres/pg_backup.sh -all -compress        # All databases
./scripts/postgres/pg_backup.sh -db mydb              # Specific database
./scripts/postgres/pg_backup.sh -all -email -debug    # With notifications
```

### New Documentation

#### PGBACKREST-SETUP.md
- Local file system backup configuration
- Directory structure and initialization
- Configuration verification steps
- Test procedures
- Troubleshooting for local backups

#### PG_BACKUP.md (New)
- Complete logical backup guide
- pg_dump and pg_dumpall usage
- Restore procedures
- CRON integration examples
- Backup comparison table (physical vs logical)
- Performance considerations

### pg_backup.sh Features

**Backup Selection:**
- `-all` - Backup all databases
- `-db <name>` - Backup specific database

**Backup Settings:**
- `-compress` - Gzip compression (enabled by default)
- `-type` - Backup method specification
- `-retention <days>` - Auto-cleanup old backups (default: 7 days)

**Storage Options:**
- `-backupdir` - Custom backup directory
- `-logdir` - Custom log directory

**Notifications:**
- `-email` - Email status reports
- `PGADMIN_DEFAULT_EMAIL` - Recipient email
- `SMTP_SERVER` and `SMTP_PORT` - Email configuration

**Testing:**
- `-test` - Dry-run mode
- `-debug` - Debug output

### CRON Examples

```bash
# Physical backup - full backup Sunday 1 AM
0 1 * * 0 /home/divix/divtools/scripts/postgres/pg_backrest_backup.sh -full -email >> /opt/pgbackrest/log/cron.log 2>&1

# Physical backup - incremental daily 2 AM
0 2 * * * /home/divix/divtools/scripts/postgres/pg_backrest_backup.sh -email >> /opt/pgbackrest/log/cron.log 2>&1

# Logical backup - all databases daily 3 AM
0 3 * * * /home/divix/divtools/scripts/postgres/pg_backup.sh -all -compress -email >> /opt/pgbackup/logs/cron.log 2>&1
```

### Directory Structure

```
/opt/postgres/
└── pgdata/                        # Docker bind-mount (READ-ONLY for backups)

/opt/pgbackrest/
├── backup/                        # Physical backups
├── log/                           # pgBackRest logs

/opt/pgbackup/
├── backups/                       # Logical SQL dumps
└── logs/                          # pg_dump logs
```

### Migration from SSH Approach

If you had started SSH setup:
1. Delete SSH keys if generated
2. No need for docker exec changes to PostgreSQL container
3. No SSH daemon needed in PostgreSQL image
4. Much simpler local access via bind mount

---

## 2025-12-30: Email Notification Support Added

### Changes Made

#### Updated pg_backrest_backup.sh Script
- **Location:** `scripts/postgres/pg_backrest_backup.sh`
- **New Features:**
  - Email notification support with `-email` flag
  - Automatic environment loading via `load_env_files()` from `.bash_profile`
  - Email recipient from `$PGADMIN_DEFAULT_EMAIL` environment variable
  - SMTP server configuration via `$SMTP_SERVER` and `$SMTP_PORT` env vars
  - Multiple email backend support (mail, sendmail, msmtp)
  - Detailed email reports with backup status, timestamp, and file counts
  
- **Environment Variables Required:**
  - `PGADMIN_DEFAULT_EMAIL` - Recipient email address
  - `SMTP_SERVER` - SMTP server hostname (optional, auto-detected)
  - `SMTP_PORT` - SMTP server port (default: 587)

- **Functions Added:**
  - `load_environment()` - Loads environment variables from `.bash_profile`
  - `send_email_notification()` - Sends formatted email with backup status

### Usage Examples

```bash
# Run incremental backup with email notification
./pg_backrest_backup.sh -email

# Run full backup with email and debug output
./pg_backrest_backup.sh -full -email -debug

# Test email notification without running backup
./pg_backrest_backup.sh -test -email

# Run backup with all options
./pg_backrest_backup.sh -full -email -debug -test
```

### Email Features

- **Status Indicators:** SUCCESS, FAILED, COMPLETED WITH WARNINGS
- **Email Contents:**
  - Backup status and completion status
  - Hostname and timestamp
  - Backup type (full/incremental)
  - Configuration file location
  - File count and backup location
  - pgBackRest version information

- **Fallback Email Methods:**
  1. `mail` command (most common)
  2. `sendmail` binary (system default)
  3. `msmtp` (msmtp-based configuration)

### CRON Integration with Email Notifications

```bash
# Daily incremental backup at 2 AM with email notification
0 2 * * * /home/divix/divtools/scripts/postgres/pg_backrest_backup.sh -email >> /opt/pgbackrest/log/cron.log 2>&1

# Full backup every Sunday at 1 AM with email notification
0 1 * * 0 /home/divix/divtools/scripts/postgres/pg_backrest_backup.sh -full -email >> /opt/pgbackrest/log/cron.log 2>&1
```

### Environment Setup

The script automatically loads environment variables using divtools' `load_env_files()` function. Ensure your `.bash_profile` has:

```bash
export PGADMIN_DEFAULT_EMAIL="admin@example.com"
export SMTP_SERVER="mail.example.com"
export SMTP_PORT="587"
```

---

## 2025-12-30: pgBackRest Backup Script Implementation

### Changes Made

#### 1. Created pgBackRest Configuration File
- **Location:** `docker/sites/s01-7692nh/tnapp01/pgbackrest/pgbackrest.conf`
- **Purpose:** Configures pgBackRest to backup PostgreSQL server at `10.1.1.97:5432`
- **Key Configuration:**
  - Base directory: `/opt/pgbackrest`
  - Log directory: `/opt/pgbackrest/log`
  - Backup directory: `/opt/pgbackrest/backup`
  - Compression: gzip with level 9
  - Retention: Keep last 7 full backups
  - Archive mode: Enabled for WAL file archival
  - Backup type: Incremental (delta) by default

#### 2. Rewrote pg_backrest_backup.sh Script
- **Location:** `scripts/postgres/pg_backrest_backup.sh`
- **Standards Applied:**
  - Divtools logging framework (sourced from `scripts/util/logging.sh`)
  - `-test` flag for test mode (no actual backups performed)
  - `-debug` flag for debug output
  - `-full` flag to run full backup instead of incremental
  - `-incr` flag to explicitly run incremental backup (default)
- **Features:**
  - Automatic directory initialization for `/opt/pgbackrest` and subdirectories
  - Configuration file validation before backup
  - Backup execution with proper error handling
  - Backup verification to confirm files were created
  - Comprehensive logging at DEBUG, INFO, WARN, and ERROR levels
  - Test mode shows what would be executed without making changes
  - Last Updated timestamps on all functions

### Usage Examples

```bash
# Run incremental backup (default)
./pg_backrest_backup.sh

# Run full backup
./pg_backrest_backup.sh -full

# Test mode - shows what would happen without executing
./pg_backrest_backup.sh -test

# Run with debug output
./pg_backrest_backup.sh -debug

# Combine flags
./pg_backrest_backup.sh -full -test -debug
```

### CRON Integration

To schedule regular backups, add to crontab:

```bash
# Daily incremental backup at 2 AM
0 2 * * * /home/divix/divtools/scripts/postgres/pg_backrest_backup.sh >> /opt/pgbackrest/log/cron.log 2>&1

# Full backup every Sunday at 1 AM
0 1 * * 0 /home/divix/divtools/scripts/postgres/pg_backrest_backup.sh -full >> /opt/pgbackrest/log/cron.log 2>&1
```

### Directory Structure

```
/opt/pgbackrest/
├── log/                      # pgBackRest logs and cron logs
│   ├── pgbackrest.log       # Main pgBackRest log
│   └── cron.log             # CRON execution logs
└── backup/                   # Backup repository
    ├── backup.manifest       # Backup manifest
    └── [backup-files]        # Backup data files
```

### Requirements

- pgBackRest v2.57.0+ installed on backup host
- PostgreSQL server accessible at `10.1.1.97:5432`
- SSH access to PostgreSQL host (for pg_controldata)
- `/opt/pgbackrest` directory with proper permissions
- Configuration file at `docker/sites/s01-7692nh/tnapp01/pgbackrest/pgbackrest.conf`

### Related Files

- Configuration: `docker/sites/s01-7692nh/tnapp01/pgbackrest/pgbackrest.conf`
- Script: `scripts/postgres/pg_backrest_backup.sh`
- Logging: `scripts/util/logging.sh`

### Future Enhancements

- [x] Add email notification support
- [ ] Add backup restoration script (`pg_backrest_restore.sh`)
- [ ] Add backup status/verification script (`pg_backrest_status.sh`)
- [ ] Add incremental backup differential reporting
- [ ] Create systemd timer as alternative to CRON

### Changes Made

#### 1. Created pgBackRest Configuration File
- **Location:** `docker/sites/s01-7692nh/tnapp01/pgbackrest/pgbackrest.conf`
- **Purpose:** Configures pgBackRest to backup PostgreSQL server at `10.1.1.97:5432`
- **Key Configuration:**
  - Base directory: `/opt/pgbackrest`
  - Log directory: `/opt/pgbackrest/log`
  - Backup directory: `/opt/pgbackrest/backup`
  - Compression: gzip with level 9
  - Retention: Keep last 7 full backups
  - Archive mode: Enabled for WAL file archival
  - Backup type: Incremental (delta) by default

#### 2. Rewrote pg_backrest_backup.sh Script
- **Location:** `scripts/postgres/pg_backrest_backup.sh`
- **Standards Applied:**
  - Divtools logging framework (sourced from `scripts/util/logging.sh`)
  - `-test` flag for test mode (no actual backups performed)
  - `-debug` flag for debug output
  - `-full` flag to run full backup instead of incremental
  - `-incr` flag to explicitly run incremental backup (default)
- **Features:**
  - Automatic directory initialization for `/opt/pgbackrest` and subdirectories
  - Configuration file validation before backup
  - Backup execution with proper error handling
  - Backup verification to confirm files were created
  - Comprehensive logging at DEBUG, INFO, WARN, and ERROR levels
  - Test mode shows what would be executed without making changes
  - Last Updated timestamps on all functions

### Usage Examples

```bash
# Run incremental backup (default)
./pg_backrest_backup.sh

# Run full backup
./pg_backrest_backup.sh -full

# Test mode - shows what would happen without executing
./pg_backrest_backup.sh -test

# Run with debug output
./pg_backrest_backup.sh -debug

# Combine flags
./pg_backrest_backup.sh -full -test -debug
```

### CRON Integration

To schedule regular backups, add to crontab:

```bash
# Daily incremental backup at 2 AM
0 2 * * * /home/divix/divtools/scripts/postgres/pg_backrest_backup.sh >> /opt/pgbackrest/log/cron.log 2>&1

# Full backup every Sunday at 1 AM
0 1 * * 0 /home/divix/divtools/scripts/postgres/pg_backrest_backup.sh -full >> /opt/pgbackrest/log/cron.log 2>&1
```

### Directory Structure

```
/opt/pgbackrest/
├── log/                      # pgBackRest logs and cron logs
│   ├── pgbackrest.log       # Main pgBackRest log
│   └── cron.log             # CRON execution logs
└── backup/                   # Backup repository
    ├── backup.manifest       # Backup manifest
    └── [backup-files]        # Backup data files
```

### Requirements

- pgBackRest v2.57.0+ installed on backup host
- PostgreSQL server accessible at `10.1.1.97:5432`
- SSH access to PostgreSQL host (for pg_controldata)
- `/opt/pgbackrest` directory with proper permissions
- Configuration file at `docker/sites/s01-7692nh/tnapp01/pgbackrest/pgbackrest.conf`

### Related Files

- Configuration: `docker/sites/s01-7692nh/tnapp01/pgbackrest/pgbackrest.conf`
- Script: `scripts/postgres/pg_backrest_backup.sh`
- Logging: `scripts/util/logging.sh`

### Future Enhancements

- [ ] Add backup restoration script (`pg_backrest_restore.sh`)
- [ ] Add backup status/verification script (`pg_backrest_status.sh`)
- [ ] Add incremental backup differential reporting
- [ ] Add email notifications on backup completion/failure
- [ ] Create systemd timer as alternative to CRON
