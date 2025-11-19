# Configuration Synchronization Guide

## Overview

The `dthostmon_sync_config.sh` script synchronizes the `dthostmon.yaml` configuration file with the existing divtools Docker folder structure. This enables automatic discovery and configuration of monitoring hosts from your existing infrastructure setup.

**Last Updated:** 11/16/2025 2:55:00 PM CST

## Quick Start

```bash
# Preview what would be changed (recommended first run)
./scripts/dthostmon_sync_config.sh -test

# Run with debug output to see detailed processing
./scripts/dthostmon_sync_config.sh -test -debug

# Apply changes (creates automatic backup)
./scripts/dthostmon_sync_config.sh
```

## Folder Structure

The script scans the `$DIVTOOLS/docker/sites` directory (referred to as `$DOCKER_SITES_DIR`) which has this structure:

```
$DOCKER_SITES_DIR/
├── s01-prod/                      # Site folder
│   ├── .env.s01-prod             # Site-level configuration (ENV vars)
│   ├── dthm-site.yaml            # Site-level configuration (YAML) [optional]
│   ├── db01/                     # Host folder
│   │   ├── .env.db01            # Host-level configuration (ENV vars)
│   │   └── dthm-host.yaml       # Host-level configuration (YAML) [optional]
│   ├── web01/
│   │   ├── .env.web01
│   │   └── dthm-host.yaml
│   └── app01/
│       └── .env.app01
├── s02-dev/
│   ├── .env.s02-dev
│   ├── devbox/
│   └── testserver/
└── s00-shared/
    └── tools/
```

## Configuration Methods

The script supports three methods of configuration, which are merged together (later methods override earlier):

### 1. Site/Host YAML Files (dthm-*.yaml)

Optional YAML files for structured configuration.

**dthm-site.yaml** (site-level):
```yaml
# Site-level configuration
enabled: true
tags:
  - production
  - critical
report_frequency: daily
resource_thresholds:
  health: "0-25"
  info: "26-55"
  warning: "56-84"
  critical: "85-100"
alert_recipients:
  - ops@example.com
  - admin@example.com
```

**dthm-host.yaml** (host-level):
```yaml
# Host-level configuration
enabled: true
hostname: 10.1.1.10
port: 22
user: monitoring
tags:
  - database
  - postgresql
  - high-priority
monitoring:
  check_docker: true
  check_apt: true
  check_disk: true
  check_services:
    - postgresql
    - docker
log_paths:
  - /var/log/syslog
  - /var/log/postgresql/postgresql-14-main.log
  - ${LOG_PATH}/app.log              # Expanded immediately
  - ${{RUNTIME_LOG_PATH}}/error.log  # Kept as ${RUNTIME_LOG_PATH} for later expansion
```

### 2. Environment Variable Files (.env.*)

Define configuration using `DTHM_*` environment variables in `.env` files.

**Site-Level Variables** (`.env.SITENAME`):
```bash
# Site configuration
DTHM_SITE_ENABLED=true
DTHM_SITE_TAGS="production,critical"
DTHM_SITE_REPORT_FREQUENCY=daily
DTHM_SITE_ALERT_RECIPIENTS="ops@example.com,admin@example.com"
```

**Host-Level Variables** (`.env.HOSTNAME`):
```bash
# Host connection settings
DTHM_HOST_ENABLED=true
DTHM_HOST_HOSTNAME=10.1.1.10
DTHM_HOST_PORT=22
DTHM_HOST_USER=monitoring

# Host metadata
DTHM_HOST_TAGS="database,postgresql,high-priority"

# Monitoring configuration
DTHM_HOST_REPORT_FREQUENCY=daily
DTHM_HOST_ALERT_LEVEL=WARN
DTHM_HOST_CHECK_DOCKER=true
DTHM_HOST_CHECK_APT=true

# Log paths (comma-delimited)
DTHM_HOST_LOG_PATHS="/var/log/syslog,/var/log/postgresql/*.log"
```

### Supported Environment Variables

#### Site-Level (`DTHM_SITE_*`)
| Variable | Type | Description | Example |
|----------|------|-------------|---------|
| `DTHM_SITE_ENABLED` | Boolean | Enable/disable site monitoring | `true` |
| `DTHM_SITE_TAGS` | List | Comma-delimited tags | `production,critical` |
| `DTHM_SITE_REPORT_FREQUENCY` | String | Report frequency | `hourly`, `daily`, `weekly` |
| `DTHM_SITE_ALERT_RECIPIENTS` | List | Comma-delimited emails | `ops@ex.com,admin@ex.com` |

#### Host-Level (`DTHM_HOST_*`)
| Variable | Type | Description | Example |
|----------|------|-------------|---------|
| `DTHM_HOST_ENABLED` | Boolean | Enable/disable host | `true` |
| `DTHM_HOST_HOSTNAME` | String | IP or hostname | `10.1.1.10` |
| `DTHM_HOST_PORT` | Integer | SSH port | `22` or `2222` |
| `DTHM_HOST_USER` | String | SSH username | `monitoring` |
| `DTHM_HOST_TAGS` | List | Comma-delimited tags | `web,nginx,ssl` |
| `DTHM_HOST_REPORT_FREQUENCY` | String | Report frequency | `daily` |
| `DTHM_HOST_ALERT_LEVEL` | String | Alert threshold | `INFO`, `WARN`, `ERROR` |
| `DTHM_HOST_CHECK_DOCKER` | Boolean | Check Docker status | `true` |
| `DTHM_HOST_CHECK_APT` | Boolean | Check APT packages | `true` |
| `DTHM_HOST_LOG_PATHS` | List | Comma-delimited paths | `/var/log/app.log,/var/log/syslog` |

## Environment Variable Expansion

The script supports two types of environment variable expansion in YAML files:

### Immediate Expansion: `${VAR}`
Variables in this format are expanded **immediately** when reading the YAML file.

```yaml
log_paths:
  - ${LOG_PATH}/app.log        # Expanded to /opt/logs/app.log (if LOG_PATH=/opt/logs)
  - /var/log/syslog
```

**Use when:** The variable is already set in the environment when running the sync script.

### Deferred Expansion: `${{VAR}}`
Variables in this format are converted to `${VAR}` and kept for **later expansion** by dthostmon when it reads `dthostmon.yaml`.

```yaml
custom_commands:
  - echo "Path: ${{RUNTIME_LOG_DIR}}"  # Becomes ${RUNTIME_LOG_DIR} in dthostmon.yaml
```

**Use when:** The variable will be set in the runtime environment (e.g., Docker container) but is not available during sync.

### Example: Mixed Expansion

```yaml
# dthm-host.yaml
monitoring:
  service_name: ${APP_SERVICE}          # Expand now (APP_SERVICE=myapp)
  log_dir: ${{RUNTIME_LOG_DIR}}         # Keep as ${RUNTIME_LOG_DIR}
  config_path: ${CONFIG_BASE}/app.conf  # Expand now

# Results in dthostmon.yaml:
monitoring:
  service_name: myapp
  log_dir: ${RUNTIME_LOG_DIR}
  config_path: /etc/myapp/app.conf
```

## Configuration Merging

When multiple configuration sources exist for the same site or host, they are merged with this priority (highest to lowest):

1. **ENV variables** (`.env.*` files) - Highest priority
2. **YAML files** (`dthm-*.yaml`) - Medium priority
3. **Existing dthostmon.yaml** - Lowest priority (preserved if not overridden)

### Merging Behavior

- **Simple values** (strings, numbers, booleans): Later values override earlier
- **Lists** (arrays): Later values completely replace earlier (not appended)
- **Nested objects** (dicts): Recursively merged key-by-key

### Example Merge

**dthm-host.yaml:**
```yaml
enabled: true
tags: [database, postgresql]
monitoring:
  check_docker: true
  check_disk: true
```

**.env.host01:**
```bash
DTHM_HOST_ENABLED=false
DTHM_HOST_TAGS="database,postgresql,production"
DTHM_HOST_CHECK_APT=true
```

**Result in dthostmon.yaml:**
```yaml
- name: host01
  enabled: false                        # Overridden by ENV
  tags: [database, postgresql, production]  # Overridden by ENV
  monitoring:
    check_docker: true                  # From YAML (preserved)
    check_disk: true                    # From YAML (preserved)
    check_apt: true                     # From ENV (added)
```

## Command-Line Options

```bash
Usage: dthostmon_sync_config.sh [OPTIONS]

Options:
  -test, --test           Dry-run mode (preview changes without writing)
  -debug, --debug         Enable verbose debug output
  -config FILE            Path to dthostmon.yaml (default: ../config/dthostmon.yaml)
  -sites-dir DIR          Docker sites directory (default: $DIVTOOLS/docker/sites)
  -yaml-ex, -yex FILE     Create an example `dthm-site.yaml` or `dthm-host.yaml` file; use '-' for stdout
  -yaml-exh               Create example `dthm-<host>.yaml` files for hosts under $DOCKER_SITES_DIR (with prompts)
  -env-ex, -eex FILE      Create an example `.env.site` or `.env.host` file; use '-' for stdout
  -env-exh                Create example `.env.<host>` files for hosts under $DOCKER_SITES_DIR (with prompts)
  -f, --force             Force overwrite/append without prompting
  -y, --yes               Alias for --force (non-interactive yes)
  -site SITE              Limit operations to a specific SITE under $DOCKER_SITES_DIR
  -host HOST              Limit operations to a specific HOST under a SITE (requires -site)
  -h, --help              Show help message

Examples:
  # Preview changes
  ./scripts/dthostmon_sync_config.sh -test

  # Run with debug output
  ./scripts/dthostmon_sync_config.sh -debug

  # Use custom paths
  ./scripts/dthostmon_sync_config.sh \
    -config /opt/config/dthostmon.yaml \
    -sites-dir /opt/docker/sites

  # Test mode with debug
  ./scripts/dthostmon_sync_config.sh -test -debug

  # Create an example host YAML to stdout
  ./scripts/dthostmon_sync_config.sh -yaml-ex -

  # Create example dthm-host.yaml files for all hosts under the sites dir
  ./scripts/dthostmon_sync_config.sh -yaml-exh -sites-dir $DIVTOOLS/docker/sites
  # Force overwrite all examples for a site/host without prompts
  ./scripts/dthostmon_sync_config.sh -yaml-exh -sites-dir $DIVTOOLS/docker/sites -f

  # Create an example .env file to stdout
  ./scripts/dthostmon_sync_config.sh -env-ex -

  # Create example .env files for all hosts
  ./scripts/dthostmon_sync_config.sh -env-exh -sites-dir $DIVTOOLS/docker/sites
  # Force append or create env example files for all hosts without prompts
  ./scripts/dthostmon_sync_config.sh -env-exh -f -sites-dir $DIVTOOLS/docker/sites
```

## Workflow Examples

### Example 1: Initial Setup

You have an existing divtools Docker infrastructure and want to set up monitoring for the first time.

```bash
# 1. Create minimal .env files for each host
cd $DIVTOOLS/docker/sites/s01-prod/db01
cat > .env.db01 << EOF
DTHM_HOST_ENABLED=true
DTHM_HOST_HOSTNAME=10.1.1.10
DTHM_HOST_USER=monitoring
DTHM_HOST_TAGS=database,postgresql,production
EOF

# 2. Preview what will be added to dthostmon.yaml
cd /path/to/dthostmon
./scripts/dthostmon_sync_config.sh -test

# 3. Apply configuration
./scripts/dthostmon_sync_config.sh

# 4. Verify configuration was updated
cat config/dthostmon.yaml
```

### Example 2: Add New Hosts

You've added new hosts to your Docker infrastructure.

```bash
# 1. Create host directory and .env file
mkdir -p $DIVTOOLS/docker/sites/s01-prod/newhost
cd $DIVTOOLS/docker/sites/s01-prod/newhost
cat > .env.newhost << EOF
DTHM_HOST_ENABLED=true
DTHM_HOST_HOSTNAME=10.1.1.50
DTHM_HOST_USER=sshuser
DTHM_HOST_TAGS=application,nodejs
EOF

# 2. Sync to add new host
cd /path/to/dthostmon
./scripts/dthostmon_sync_config.sh

# New host automatically added to dthostmon.yaml
```

### Example 3: Update Existing Configuration

You need to update tags or settings for multiple hosts.

```bash
# 1. Update .env files or create dthm-*.yaml files
cd $DIVTOOLS/docker/sites/s01-prod/db01
echo 'DTHM_HOST_TAGS=database,postgresql,production,backup-enabled' >> .env.db01

# 2. Run sync to update
cd /path/to/dthostmon
./scripts/dthostmon_sync_config.sh -debug

# Configuration for db01 is updated in dthostmon.yaml
```

### Example 4: Site-Wide Configuration

Set monitoring frequency for an entire site.

```bash
# 1. Create site-level configuration
cd $DIVTOOLS/docker/sites/s02-dev
cat > .env.s02-dev << EOF
DTHM_SITE_ENABLED=true
DTHM_SITE_TAGS=development,testing
DTHM_SITE_REPORT_FREQUENCY=weekly
EOF

# 2. Sync configuration
cd /path/to/dthostmon
./scripts/dthostmon_sync_config.sh

# All hosts in s02-dev inherit weekly reporting (unless overridden at host level)
```

## Backup and Safety

### Automatic Backups

Every time the script runs (except in `-test` mode), it creates a timestamped backup:

```bash
config/dthostmon.yaml.backup.20251116_143022
```

### Restore from Backup

```bash
# List backups
ls -lt config/dthostmon.yaml.backup.*

# Restore from backup
cp config/dthostmon.yaml.backup.20251116_143022 config/dthostmon.yaml
```

### Test Mode

Always use `-test` mode first to preview changes:

```bash
# Preview changes without modifying config
./scripts/dthostmon_sync_config.sh -test

# Check the preview output carefully
# If it looks good, run without -test
./scripts/dthostmon_sync_config.sh
```

**Note:** `-test` now performs validation on the combined generated configuration. Any warnings or errors will be printed. If validation finds errors, the script exits with a non-zero status so you can catch issues in automation. Use `-debug` to see full validation details.

## Troubleshooting

### Script Reports "Configuration file not found"

**Problem:** The script can't find `dthostmon.yaml`.

**Solution:** Specify the config file path explicitly:
```bash
./scripts/dthostmon_sync_config.sh -config /full/path/to/dthostmon.yaml
```

### Script Reports "Docker sites directory not found"

**Problem:** `$DOCKER_SITES_DIR` doesn't exist or `$DIVTOOLS` is not set.

**Solution:** Set `DIVTOOLS` or specify sites directory:
```bash
export DIVTOOLS=/path/to/divtools
# OR
./scripts/dthostmon_sync_config.sh -sites-dir /path/to/docker/sites
```

### Changes Not Applied

**Problem:** Config doesn't update after running script.

**Solution:** 
1. Run with `-debug` to see what's happening:
   ```bash
   ./scripts/dthostmon_sync_config.sh -debug
   ```
2. Verify `.env.*` files have correct variable names (must start with `DTHM_`)
3. Check file permissions (script must be able to write to `config/` directory)

### Environment Variables Not Expanding

**Problem:** Variables like `${LOG_PATH}` remain unexpanded.

**Solution:**
1. **For immediate expansion:** Ensure variable is set in environment when running script:
   ```bash
   export LOG_PATH=/var/log
   ./scripts/dthostmon_sync_config.sh
   ```
2. **For deferred expansion:** Use `${{VAR}}` format instead of `${VAR}`

### Wrong Values in dthostmon.yaml

**Problem:** Script overwrote manual changes.

**Solution:**
1. Restore from backup:
   ```bash
   cp config/dthostmon.yaml.backup.YYYYMMDD_HHMMSS config/dthostmon.yaml
   ```
2. Move manual changes to `.env.*` or `dthm-*.yaml` files so they persist
3. Run sync again

### Host Appears Multiple Times

**Problem:** Host is duplicated in `dthostmon.yaml`.

**Solution:** This shouldn't happen (script matches by `name`), but if it does:
1. Restore from backup
2. Manually remove duplicate entries
3. Report bug with `-debug` output

## Integration with dthostmon

After running the sync script, dthostmon will automatically use the updated configuration:

```bash
# Review current configuration
./dthostmon_cli.py config

# Test host connections
./dthostmon_cli.py setup

# Start monitoring
./dthostmon_cli.py monitor
```

## Best Practices

### 1. Start with Test Mode
Always run with `-test` first to preview changes before applying.

```bash
./scripts/dthostmon_sync_config.sh -test
```

### 2. Use ENV Files for Simple Config
For basic host settings (hostname, port, user, tags), use `.env.*` files.

### 3. Use YAML Files for Complex Config
For structured configuration (monitoring options, log paths, custom commands), use `dthm-*.yaml` files.

### 4. Version Control .env Templates
Create `.env.example` templates in your Docker sites:

```bash
# .env.HOSTNAME.example
DTHM_HOST_ENABLED=true
DTHM_HOST_HOSTNAME=<IP_ADDRESS>
DTHM_HOST_USER=monitoring
DTHM_HOST_TAGS=<TAGS>
```

### 5. Regular Syncs
Run the sync script periodically or after infrastructure changes:

```bash
# Add to cron or systemd timer
0 */6 * * * /path/to/dthostmon/scripts/dthostmon_sync_config.sh
```

### 6. Keep Backups
The script creates automatic backups, but you can create manual ones:

```bash
cp config/dthostmon.yaml config/dthostmon.yaml.manual-backup
```

### 7. Document Custom Settings
Add comments to your `dthm-*.yaml` files:

```yaml
# Custom monitoring for database server
# Owner: DBA Team
# Last Updated: 2025-11-16
enabled: true
tags:
  - database
  - critical
```

## See Also

- **PRD Requirements:** FR-CONFIG-007, FR-CONFIG-008, FR-CONFIG-009
- **Configuration Guide:** `docs/CONFIGURATION.md` (if exists)
- **Main README:** `README.md`
- **Example Config:** `config/dthostmon.yaml.example`
