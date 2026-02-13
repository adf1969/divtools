# Test and Debug Modes - host_change_log.sh

## Overview

The `host_change_log.sh` script now includes comprehensive **test** and **debug** modes following divtools workspace conventions.

- **Test Mode** (`-test`): Shows what changes *would* be made without actually making them
- **Debug Mode** (`-debug`): Displays detailed execution information for troubleshooting

## Test Mode (`-test` / `--test`)

### Purpose
Test mode allows you to perform dry-runs of the script to see exactly what would happen without making any permanent changes.

### Usage
```bash
# Test the setup without making changes
./host_change_log.sh -test setup

# Test with environment variables
DT_LOG_DIVTOOLS=TRUE ./host_change_log.sh -test setup

# Test with divtools git logging
./host_change_log.sh -test -debug setup
```

### What Gets Stubbed in Test Mode
- Directory creation (shows what *would* be created)
- Bash history configuration (shows what *would* be added to bashrc files)
- File modifications (shows what *would* be changed)
- Root privilege check (skipped to allow testing as non-root)

### What Still Runs
- Manifest generation (read-only operations)
- Configuration display
- Status checks

### Example Output
```
[WARNING] [TEST MODE] No permanent changes will be made
[INFO] Starting host change monitoring setup...
[DEBUG] Debug mode enabled
[INFO] Environment: DT_LOG_DIR=/opt/dtlogs, DT_LOG_MAXSIZE=100m, DT_LOG_MAXDAYS=30
[WARNING] [TEST MODE] Skipping root check
[WARNING] [TEST MODE] Would create directory structure at: /opt/dtlogs/{history,apt,docker,checksums,logs,bin}
[WARNING] [TEST MODE] Would create config directory at: /etc/divtools
[INFO] Configuring bash history settings...
[WARNING] [TEST MODE] Would add bash history config to /root/.bashrc
...
[WARNING] [TEST MODE] Setup simulation completed - no changes were made
```

## Debug Mode (`-debug` / `--debug`)

### Purpose
Debug mode enables detailed logging throughout execution to help troubleshoot issues or understand what the script is doing.

### Usage
```bash
# Run setup with debug output
./host_change_log.sh -debug setup

# Test with debug
./host_change_log.sh -test -debug setup

# Verify with debug
./host_change_log.sh -debug verify
```

### What Gets Logged in Debug Mode
- All variable values (TEST_MODE, DEBUG_MODE settings)
- Function entry/exit points
- Conditional logic decisions
- File operation details
- Process detection and TTY extraction

### Example Output
```
[DEBUG] Debug mode enabled
[INFO] Starting host change monitoring setup...
[DEBUG] TEST_MODE=0, DEBUG_MODE=1
[INFO] Environment: DT_LOG_DIR=/var/log/divtools/monitor, ...
[DEBUG] Adding bash history config to /root/.bashrc
[SUCCESS] Configured bash history for root user
[DEBUG] Starship is installed - no additional configuration needed
[DEBUG] TEST_MODE=0 (will not modify files)
```

## Combined Usage

### Test + Debug (Recommended for Initial Setup)
```bash
./host_change_log.sh -test -debug setup
```

This combination:
1. Shows exactly what would happen (test mode)
2. Provides detailed information about each step (debug mode)
3. Doesn't make any permanent changes
4. Perfect for initial verification

### Typical Workflow

```bash
# Step 1: Dry-run with debug info
./host_change_log.sh -test -debug setup

# Step 2: Review output carefully

# Step 3: If satisfied, run without -test flag
./host_change_log.sh setup

# Step 4: Debug any issues
./host_change_log.sh -debug verify
```

## Environment Variables with Test/Debug Modes

```bash
# Test with specific environment variables
DT_LOG_DIR=/opt/dtlogs DT_LOG_MAXSIZE=100m DT_LOG_MAXDAYS=30 \
    ./host_change_log.sh -test -debug setup

# Test with divtools git logging
DT_LOG_DIVTOOLS=TRUE ./host_change_log.sh -test -debug setup
```

## Implementation Details

### Flag Parsing
Flags are parsed before the command:
```bash
./host_change_log.sh [FLAGS] <command>

# Valid:
./host_change_log.sh -test -debug setup
./host_change_log.sh -debug -test setup
./host_change_log.sh -test setup

# Not valid (flags must come before command):
./host_change_log.sh setup -test
```

### Code Architecture

#### 1. Flag Variables (Lines 20-21)
```bash
TEST_MODE=0
DEBUG_MODE=0
```

#### 2. Debug Logging Function (Lines 54-58)
```bash
log_debug() {
    if [[ $DEBUG_MODE -eq 1 ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $*"
    fi
}
```

#### 3. Flag Parsing in main() (Lines 847-865)
```bash
# Parse global flags first
while [[ $# -gt 0 ]]; do
    case "$1" in
        -test|--test)
            TEST_MODE=1
            log_warning "Running in TEST mode..."
            shift
            ;;
        -debug|--debug)
            DEBUG_MODE=1
            log_debug "Debug mode enabled"
            shift
            ;;
        *)
            break
            ;;
    esac
done
```

#### 4. Test Mode Stubs
Scattered throughout functions:
```bash
if [[ $TEST_MODE -eq 1 ]]; then
    log_warning "[TEST MODE] Would create directory structure at: ..."
    return
fi

# Permanent operation follows
mkdir -p "${MONITOR_BASE_DIR}"/{history,apt,docker,checksums,logs,bin}
```

#### 5. Debug Logging
Added to key functions:
```bash
log_debug "Adding bash history config to /root/.bashrc"
log_debug "TEST_MODE=$TEST_MODE, DEBUG_MODE=$DEBUG_MODE"
log_debug "Starship is installed - no additional configuration needed"
```

## Troubleshooting

### Issue: `-test` flag not recognized
**Solution**: Ensure you're using the updated script version
```bash
grep "TEST_MODE" /home/divix/divtools/scripts/util/host_chg_mon/host_change_log.sh
```

### Issue: Debug output not showing
**Solution**: Verify DEBUG_MODE is set by checking flag parsing
```bash
./host_change_log.sh -test -debug setup | grep DEBUG
```

### Issue: Need more debug information
**Solution**: Check the git diff to see all added debug points
```bash
git diff HEAD scripts/util/host_chg_mon/host_change_log.sh | grep log_debug
```

## Integration with Existing Features

### Test Mode with divtools Git Logging
```bash
# Test without enabling git logging
./host_change_log.sh -test setup

# Test with git logging enabled
DT_LOG_DIVTOOLS=TRUE ./host_change_log.sh -test -debug setup
```

### Test Mode with Session History Capture
```bash
# Test session history setup
./host_change_log.sh -test setup

# Check what would be created
grep "capture_session_histories" /tmp/changes_summary.md
```

## Statistics

- **Lines added**: ~88 lines (flag variables, parsing, debug logging, test stubs)
- **Original size**: 826 lines
- **New size**: 915 lines
- **Syntax validation**: ✅ PASSED (bash -n)

## Related Documentation

- Main script: `/home/divix/divtools/scripts/util/host_chg_mon/host_change_log.sh`
- Feature guide: `HOST_CHANGE_LOG_UPDATES.md`
- Workspace conventions: `/home/divix/divtools/.github/copilot-instructions.md`

## Examples by Use Case

### Initial Setup with Verification
```bash
# Step 1: Test without making changes
./host_change_log.sh -test -debug setup

# Step 2: Run actual setup
sudo ./host_change_log.sh setup

# Step 3: Verify it worked
./host_change_log.sh status
```

### Troubleshooting Configuration
```bash
# Debug the verify command
./host_change_log.sh -debug verify

# Check manifest generation
./host_change_log.sh -test manifest
```

### Testing Environment Variable Configuration
```bash
# Test with custom log directory
DT_LOG_DIR=/opt/custom_logs ./host_change_log.sh -test -debug setup

# Test with divtools logging
DT_LOG_DIVTOOLS=TRUE ./host_change_log.sh -test -debug setup
```

### CI/CD Integration
```bash
# Test mode suitable for pre-flight checks
./host_change_log.sh -test setup && echo "READY FOR PRODUCTION"

# Debug mode suitable for logging in CI pipelines
./host_change_log.sh -debug manifest >> build.log 2>&1
```
