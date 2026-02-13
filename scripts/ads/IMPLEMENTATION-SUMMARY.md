- # dt_ads_setup.sh - Implementation Summary

## What Was Added

### 1. ✅ Logging Infrastructure

#### Log Initialization Function

```bash
init_logging()
```

- Creates `/opt/ads-setup/logs` directory automatically
- Generates timestamped log filename: `dt_ads_setup-YYYYMMDD-HHMMSS.log`
- Redirects stdout and stderr to log file AND console (using `tee`)
- Logs script start time, mode flags, and environment info
- Called automatically at script startup (before any other functions)

#### Log File Features

- **Path**: `/opt/ads-setup/logs/dt_ads_setup-YYYYMMDD-HHMMSS.log`
- **Timestamps**: Include local timezone (CST, CDT, MST, etc.)
- **Real-time**: Output visible on console while saving to file
- **Complete**: Both stdout and stderr captured

### 2. ✅ Pre-Flight Check for systemd-resolved

#### New Function: `check_systemd_resolved()`

```bash
check_systemd_resolved()
```

- Detects if systemd-resolved is running
- Warns user if port 53 conflict detected
- Prompts user to stop and disable systemd-resolved
- **Stops service**: `sudo systemctl stop systemd-resolved`
- **Masks service**: `sudo systemctl mask systemd-resolved` (prevents auto-start)
- Logs all actions with full context
- Called at start of `ads_setup()` function

#### Log Output Example

```
[2025-12-06 22:45:32 CST] INFO: Checking for systemd-resolved on port 53...
[2025-12-06 22:45:32 CST] WARN: systemd-resolved is currently running and listening on port 53
[2025-12-06 22:45:34 CST] DEBUG: User confirmed systemd-resolved stop
[2025-12-06 22:45:35 CST] INFO: ✓ Stopped systemd-resolved
[2025-12-06 22:45:36 CST] INFO: ✓ Masked systemd-resolved (will not auto-start)
```

### 3. ✅ Menu Selection Tracking

#### Enhanced `main_menu()` Function

Each menu option now logged with:

- Clear visual separators (box drawing characters)
- Menu option number and description
- Timestamp of selection

#### Log Output Example

```
╔════════════════════════════════════════════════════════╗
║ MENU SELECTION: Option 1 - ADS Setup (folders, files, network)
╚════════════════════════════════════════════════════════╝
```

### 4. ✅ Comprehensive Function Logging

#### Updated Functions with Logging

**`ads_setup()`**

- Menu selection tracking
- systemd-resolved pre-flight check
- Environment variable prompts
- Folder creation and verification
- Compose file deployment
- Bash alias installation
- Docker network verification/creation
- Completion status

**`start_container()`**

- Menu selection tracking
- Container status check (running/not running)
- Start vs restart decision
- Docker compose execution
- Log display options
- Completion confirmation

**`stop_container()`**

- Menu selection tracking
- Container status verification
- User confirmation tracking
- Stop command execution
- Completion status

**`configure_host_dns()`**

- Menu selection tracking
- Current DNS configuration display
- Backup file creation with path
- DNS update confirmation
- systemd-resolved configuration
- Completion status

**`run_status_checks()`**

- Menu selection tracking
- Container verification
- Python virtual environment creation/setup
- Test execution
- Results display

### 5. ✅ Debug-Aware Logging

#### Two Log Levels

- **INFO** (default): High-level operational messages
- **DEBUG** (with --debug flag): Detailed debugging information

#### Log Statements Include

- Function entry/exit points (with DEBUG)
- Variable values (with DEBUG)
- User confirmations (yes/no responses)
- File operations and paths
- Docker command execution
- Configuration changes
- Error and warning conditions
- Progress indicators (✓ ✗)

### 6. ✅ Timestamp Format with Timezone

#### All Timestamps Include

- Date: `YYYY-MM-DD`
- Time: `HH:MM:SS` (24-hour format)
- Timezone: `CST`, `CDT`, `MST`, `EDT`, etc. (auto-detected)

#### Examples

```
[2025-12-06 22:45:30 CST] INFO: Script execution started
[2025-12-06 14:32:15 CDT] DEBUG: Test Mode: 0
[2025-12-06 10:15:42 MST] HEAD: === ADS Setup ===
```

## Code Locations

### Main Logging Initialization

- **Lines 48-70**: `init_logging()` function definition
- **Line 72**: Call to `init_logging()` at script start

### Pre-Flight Checks

- **Lines 105-153**: `check_systemd_resolved()` function
- **Line 429**: Call in `ads_setup()` function

### Menu Tracking

- **Lines 720-746**: Enhanced `main_menu()` function with selection logging

### Function Logging Updates

- `setup_folders()` - Lines 183-220
- `check_folders()` - Lines 222-263
- `deploy_compose_files()` - Lines 265-318
- `check_compose_files()` - Lines 320-357
- `ads_setup()` - Lines 426-485
- `start_container()` - Lines 493-547
- `stop_container()` - Lines 549-580
- `configure_host_dns()` - Lines 588-640
- `run_status_checks()` - Lines 648-700

## Usage Examples

### Standard Execution (INFO level)

```bash
./dt_ads_setup.sh
# Logs to: /opt/ads-setup/logs/dt_ads_setup-YYYYMMDD-HHMMSS.log
# Shows: Basic operations and results
```

### Debug Mode (DEBUG level)

```bash
./dt_ads_setup.sh --debug
# Logs to: /opt/ads-setup/logs/dt_ads_setup-YYYYMMDD-HHMMSS.log
# Shows: Detailed debugging information
```

### Test Mode (No actual changes)

```bash
./dt_ads_setup.sh --test
# Logs to: /opt/ads-setup/logs/dt_ads_setup-YYYYMMDD-HHMMSS.log
# Actions: Logged but NOT executed
```

### Debug + Test (Full information without risk)

```bash
./dt_ads_setup.sh --test --debug
# Full debugging with test-mode protection
```

## Verification

### Check Log Creation

```bash
ls -lah /opt/ads-setup/logs/
```

### View Recent Log

```bash
tail -f /opt/ads-setup/logs/dt_ads_setup-*.log
```

### Search for Menu Selections

```bash
grep "MENU SELECTION" /opt/ads-setup/logs/dt_ads_setup-*.log
```

### Search for systemd-resolved Handling

```bash
grep "systemd-resolved" /opt/ads-setup/logs/dt_ads_setup-*.log
```

### Search for Errors

```bash
grep "ERROR" /opt/ads-setup/logs/dt_ads_setup-*.log
```

## Integration Points

### Divtools Utilities

- Uses `logging.sh` for consistent log level handling
- Follows `dt_host_setup.sh` patterns for environment variable management
- Compatible with divtools directory structure

### Environment Variables

- `TEST_MODE`: 0 (normal) or 1 (test)
- `DEBUG_MODE`: 0 (normal) or 1 (debug)
- `LOG_DIR`: `/opt/ads-setup/logs` (auto-created)
- `LOG_FILE`: Auto-generated with timestamp

### Functions Modified

- `init_logging()` - NEW
- `check_systemd_resolved()` - NEW
- `ads_setup()` - Enhanced with logging
- `start_container()` - Enhanced with logging
- `stop_container()` - Enhanced with logging
- `configure_host_dns()` - Enhanced with logging
- `run_status_checks()` - Enhanced with logging
- `main_menu()` - Enhanced with selection tracking

## What the Script Now Does

✅ **Before any operation**: Initializes logging to `/opt/ads-setup/logs`  
✅ **On startup**: Logs script start, mode flags, and environment  
✅ **Before ADS setup**: Checks for systemd-resolved and offers to stop it  
✅ **Every menu selection**: Logs option number and description  
✅ **During operations**: Logs all actions with timestamps and timezone  
✅ **On errors**: Logs all warnings and errors  
✅ **On completion**: Logs success confirmation  
✅ **In test mode**: Prefixes with `[TEST]` and shows what would happen  
✅ **In debug mode**: Shows detailed debugging information  

## Answers to User's Questions

### Q: Does dt_ads_setup.sh stop systemd on the host if it is running?

**A: YES** - The new `check_systemd_resolved()` function:

- Detects if systemd-resolved is running
- Warns the user about the port 53 conflict
- Prompts user to stop and disable it
- Executes stop and mask commands
- Logs all actions with timestamps

### Q: Does dt_ads_setup.sh provide extensive logging?

**A: YES** - Comprehensive logging:

- All activity logged to `/opt/ads-setup/logs/dt_ads_setup-TIMESTAMP.log`
- Timestamps include local timezone
- Debug-aware logging (DEBUG vs INFO levels)
- Menu selections clearly identified with boxes
- All operations tracked and auditable
- Real-time output to console while saving to file
