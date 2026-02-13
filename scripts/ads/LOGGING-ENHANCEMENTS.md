# dt_ads_setup.sh Logging Enhancements

**Last Updated: 12/6/2025 10:45:00 PM CST**

## Overview

The `dt_ads_setup.sh` script has been enhanced with production-grade logging infrastructure and comprehensive pre-flight checks. All operations are now fully auditable and traceable.

## Logging Infrastructure

### Log File Location
- **Path**: `/opt/ads-setup/logs/`
- **Format**: `dt_ads_setup-YYYYMMDD-HHMMSS.log`
- **Example**: `dt_ads_setup-20251206-224530.log`

### Log Initialization
- Logs are created automatically on script start
- Directory structure is created with proper permissions
- Both stdout and stderr are captured to log file
- Real-time output is displayed while logging

### Log Levels
The script respects the `--debug` flag to control verbosity:

#### Without `--debug` flag (INFO level):
- ✅ High-level operational messages
- ✅ Status updates and confirmations
- ✅ Errors and warnings
- ❌ DEBUG-level details suppressed
- ❌ Configuration snippets excluded

#### With `--debug` flag (DEBUG level):
- ✅ All INFO level messages
- ✅ Detailed DEBUG messages showing:
  - Variable values
  - Function entry/exit
  - User confirmations (yes/no responses)
  - File operations with paths
  - Docker commands being executed
  - Configuration being applied

### Log Content Examples

#### Menu Selection Logging
```
╔════════════════════════════════════════════════════════╗
║ MENU SELECTION: Option 1 - ADS Setup (folders, files, network)
╚════════════════════════════════════════════════════════╝
```

Each menu option is clearly logged with timestamp and description.

#### Function Execution
```
[2025-12-06 22:45:30 CST] HEAD: === ADS Setup ===
[2025-12-06 22:45:30 CST] INFO: [MENU SELECTION] ADS Setup initiated
[2025-12-06 22:45:32 CST] INFO: Checking for systemd-resolved on port 53...
[2025-12-06 22:45:33 CST] INFO: Creating folder structure...
```

#### Timestamp Format
- Local timezone included (e.g., CST, CDT, MST)
- Human-readable format: `YYYY-MM-DD HH:MM:SS TZ`
- Divtools logging.sh utilities used for consistency

## Pre-Flight Checks

### systemd-resolved Detection & Handling

**Problem**: systemd-resolved listens on port 53, which conflicts with Samba AD DC DNS.

**Solution**: 
- ✅ Automatically detect if systemd-resolved is running
- ✅ Warn user of port 53 conflict
- ✅ Prompt user to stop and disable it
- ✅ Log all actions with timestamps

**Execution Flow**:
1. Called at start of `ads_setup()` function
2. Checks if systemd-resolved is running: `systemctl is-active --quiet systemd-resolved`
3. If running, prompts user for action
4. If user confirms, stops service: `sudo systemctl stop systemd-resolved`
5. Masks service to prevent auto-start: `sudo systemctl mask systemd-resolved`
6. All actions logged with full context

**Log Examples**:
```
[2025-12-06 22:45:32 CST] INFO: Checking for systemd-resolved on port 53...
[2025-12-06 22:45:32 CST] WARN: systemd-resolved is currently running and listening on port 53
[2025-12-06 22:45:32 CST] WARN: Samba AD DC requires exclusive access to port 53 for DNS
[2025-12-06 22:45:32 CST] WARN: systemd-resolved is enabled and will start on reboot
[2025-12-06 22:45:34 CST] DEBUG: User confirmed systemd-resolved stop
[2025-12-06 22:45:34 CST] INFO: Stopping systemd-resolved...
[2025-12-06 22:45:35 CST] INFO: ✓ Stopped systemd-resolved
[2025-12-06 22:45:36 CST] INFO: ✓ Masked systemd-resolved (will not auto-start)
```

## Comprehensive Function Logging

Every major function logs its operations:

### `ads_setup()`
- Menu selection log
- systemd-resolved check
- Environment variable entry
- Folder creation and verification
- Compose file deployment
- Bash alias installation
- Docker network creation
- Completion status

### `start_container()`
- Menu selection log
- Container status check
- Start/restart decision
- Docker compose execution
- Log display options
- Completion status

### `stop_container()`
- Menu selection log
- Container status verification
- User confirmation
- Stop command execution
- Completion status

### `configure_host_dns()`
- Menu selection log
- Current DNS display
- Backup creation with path
- DNS update confirmation
- systemd-resolved configuration
- Completion status

### `run_status_checks()`
- Menu selection log
- Container verification
- Python virtual environment setup
- Test execution
- Test result logging

### `prompt_env_vars()`
- Environment file loading
- Variable prompts with defaults
- User input validation
- Save confirmation
- File write logging

## Test Mode (`--test` flag)

When running with `--test`:
- All permanent operations prefixed with `[TEST]`
- Destructive operations logged but not executed
- Example: `[TEST] Would copy: dci-samba.yml → /path/to/samba/`
- Useful for dry-run verification

## Debug Mode (`--debug` flag)

When running with `--debug`:
- Additional DEBUG-level messages shown
- Variable values logged
- Function flow clearly visible
- User responses logged
- File paths in operations logged
- Docker commands displayed

## Usage Examples

### Normal Run (INFO level logging)
```bash
./dt_ads_setup.sh
# Logs to: /opt/ads-setup/logs/dt_ads_setup-20251206-224530.log
# Shows: High-level operations and results
```

### Debug Run (DEBUG level logging)
```bash
./dt_ads_setup.sh --debug
# Logs to: /opt/ads-setup/logs/dt_ads_setup-20251206-224530.log
# Shows: All operations plus debugging details
```

### Test Run (Preview operations)
```bash
./dt_ads_setup.sh --test
# Logs to: /opt/ads-setup/logs/dt_ads_setup-20251206-224530.log
# Actions: All logged but NOT executed
```

### Combined (Debug + Test)
```bash
./dt_ads_setup.sh --test --debug
# Full debugging with test-mode protection
```

## Log Analysis

### View Recent Log
```bash
tail -f /opt/ads-setup/logs/dt_ads_setup-*.log
```

### Search for Errors
```bash
grep "ERROR" /opt/ads-setup/logs/dt_ads_setup-*.log
```

### View Menu Selections
```bash
grep "MENU SELECTION" /opt/ads-setup/logs/dt_ads_setup-*.log
```

### View systemd-resolved Handling
```bash
grep -A5 "systemd-resolved" /opt/ads-setup/logs/dt_ads_setup-*.log
```

### Count Operations by Level
```bash
grep -E "INFO|WARN|ERROR|DEBUG" /opt/ads-setup/logs/dt_ads_setup-*.log | cut -d']' -f2 | sort | uniq -c
```

## Audit Trail Examples

### Complete Setup Execution
```
[2025-12-06 22:45:30 CST] HEAD: ================================
[2025-12-06 22:45:30 CST] HEAD: ADS Setup Script Started
[2025-12-06 22:45:30 CST] HEAD: ================================
[2025-12-06 22:45:30 CST] INFO: Log file: /opt/ads-setup/logs/dt_ads_setup-20251206-224530.log
[2025-12-06 22:45:30 CST] DEBUG: Test Mode: 0
[2025-12-06 22:45:30 CST] DEBUG: Debug Mode: 0
[2025-12-06 22:45:30 CST] INFO: TEST_MODE=0, DEBUG_MODE=0
[2025-12-06 22:45:30 CST] HEAD: ╔════════════════════════════════════════════════════════╗
[2025-12-06 22:45:30 CST] HEAD: ║ MENU SELECTION: Option 1 - ADS Setup (folders, files, network)
[2025-12-06 22:45:30 CST] HEAD: ╚════════════════════════════════════════════════════════╝
[2025-12-06 22:45:30 CST] HEAD: === ADS Setup ===
[2025-12-06 22:45:30 CST] INFO: [MENU SELECTION] ADS Setup initiated
[2025-12-06 22:45:32 CST] INFO: Checking for systemd-resolved on port 53...
[2025-12-06 22:45:33 CST] INFO: ✓ systemd-resolved is not running
[2025-12-06 22:45:33 CST] INFO: Prompting for environment variables...
[2025-12-06 22:45:45 CST] DEBUG: User entered domain: avctn.lan
[2025-12-06 22:45:48 CST] INFO: Creating folder structure...
[2025-12-06 22:45:49 CST] INFO: ✓ Folder structure created successfully
[2025-12-06 22:45:50 CST] INFO: Deploying docker-compose files...
[2025-12-06 22:45:51 CST] INFO: ✓ Docker compose files deployed successfully
[2025-12-06 22:45:52 CST] INFO: ADS Setup completed successfully
```

## Key Features

✅ **Audit Trail**: Every operation logged with timestamp  
✅ **Flexible Verbosity**: DEBUG vs INFO levels  
✅ **Menu Tracking**: All selections clearly logged  
✅ **Pre-flight Checks**: systemd-resolved automatic handling  
✅ **Test Mode**: Safe dry-run capability  
✅ **Timezone Support**: Local timezone in timestamps  
✅ **Error Tracking**: All errors and warnings logged  
✅ **File Operations**: Backups and modifications tracked  
✅ **User Interactions**: Confirmations and decisions logged  
✅ **Container Lifecycle**: Start, stop, restart all tracked  

## Integration with divtools

- Uses divtools logging.sh utilities for consistency
- Follows divtools environment variable management patterns
- Compatible with existing divtools scripts
- Log directory follows divtools standards (/opt/$APP/)
- Timestamps include timezone like other divtools scripts

## Future Enhancements

Potential additions:
- Rotation of old log files (keep last 30 days)
- Email notification on errors
- Centralized logging to syslog
- Real-time log monitoring dashboard
- Test result summary files
- Integration with monitoring systems

