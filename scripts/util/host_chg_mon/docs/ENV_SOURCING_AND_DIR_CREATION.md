# Environment File Sourcing & Directory Creation

## Summary

Two critical improvements have been made to `host_change_log.sh`:

1. **Environment File Sourcing** - Script now actively sources `.env.s00-shared`
2. **Automatic Directory Creation** - Script creates `DT_LOG_DIR` if it doesn't exist

## Problem Statement

### Issue 1: Environment File Not Being Sourced
The script was only using environment variables IF they were already set in the shell. It was NOT sourcing the `.env.s00-shared` file, so variables were never loaded from the config.

**Before:**
```bash
# Just checked if variables were already set
DT_LOG_DIR="${DT_LOG_DIR:-/var/log/divtools/monitor}"
```

**After:**
```bash
# Now actively sources the env file
if [[ -f "/opt/divtools/docker/sites/s00-shared/.env.s00-shared" ]]; then
    ENV_FILE_SHARED="/opt/divtools/docker/sites/s00-shared/.env.s00-shared"
    set +u  # Allow unset variables during source
    source "$ENV_FILE_SHARED" 2>/dev/null || true
    set -u  # Re-enable safety
fi

# Then use variables with fallbacks
DT_LOG_DIR="${DT_LOG_DIR:-/var/log/divtools/monitor}"
```

### Issue 2: Script Fails if Directory Doesn't Exist
If `DT_LOG_DIR` didn't exist, script operations would fail. Now it creates the directory automatically.

**Before:**
```bash
# Script expected directory to already exist
mkdir -p "${MONITOR_BASE_DIR}"/{history,apt,docker,checksums,logs,bin}
```

**After:**
```bash
# Script creates base directory first if missing
if [[ ! -d "$MONITOR_BASE_DIR" ]]; then
    mkdir -p "$MONITOR_BASE_DIR"
fi

# Then creates subdirectories
mkdir -p "${MONITOR_BASE_DIR}"/{history,apt,docker,checksums,logs,bin}
```

## Implementation

### 1. Environment File Sourcing (Lines 24-36)

```bash
# Source shared environment variables if available
ENV_FILE_SHARED=""
if [[ -f "/opt/divtools/docker/sites/s00-shared/.env.s00-shared" ]]; then
    ENV_FILE_SHARED="/opt/divtools/docker/sites/s00-shared/.env.s00-shared"
    # Temporarily allow unset variables while sourcing env file
    set +u
    source "$ENV_FILE_SHARED" 2>/dev/null || true
    set -u
elif [[ -f "/home/divix/divtools/docker/sites/s00-shared/.env.s00-shared" ]]; then
    ENV_FILE_SHARED="/home/divix/divtools/docker/sites/s00-shared/.env.s00-shared"
    set +u
    source "$ENV_FILE_SHARED" 2>/dev/null || true
    set -u
fi
```

**Features:**
- Checks primary location first: `/opt/divtools/docker/sites/s00-shared/.env.s00-shared`
- Falls back to alternate location if not found
- Uses `set +u` to allow unset variables in the env file
- Uses `set -u` to re-enable safety after sourcing
- Suppresses errors with `2>/dev/null || true`
- Stores filename in `ENV_FILE_SHARED` variable for logging

### 2. Ensure Log Directory Function (Lines 73-82)

```bash
ensure_log_dir() {
    if [[ ! -d "$MONITOR_BASE_DIR" ]]; then
        log_debug "Creating log directory: ${MONITOR_BASE_DIR}"
        mkdir -p "$MONITOR_BASE_DIR" || {
            log_error "Failed to create log directory: ${MONITOR_BASE_DIR}"
            exit 1
        }
    fi
}
```

**Features:**
- New helper function called early in setup
- Creates directory with `mkdir -p`
- Includes error handling (exits if creation fails)
- Logs via `log_debug()` for visibility
- Uses `||` operator to catch creation failures

### 3. Enhanced setup_directories() (Lines 96-113)

```bash
setup_directories() {
    log_info "Setting up monitoring directory structure..."
    log_debug "TEST_MODE=$TEST_MODE, DEBUG_MODE=$DEBUG_MODE"
    
    if [[ $TEST_MODE -eq 1 ]]; then
        log_warning "[TEST MODE] Would create directory structure at: ${MONITOR_BASE_DIR}/{...}"
        return
    fi
    
    # Create base directory first if missing
    if [[ ! -d "$MONITOR_BASE_DIR" ]]; then
        log_info "Creating base monitoring directory: ${MONITOR_BASE_DIR}"
        mkdir -p "$MONITOR_BASE_DIR"
        chmod 755 "$MONITOR_BASE_DIR"
    fi
    
    # Create subdirectories
    mkdir -p "${MONITOR_BASE_DIR}"/{history,apt,docker,checksums,logs,bin}
    mkdir -p "${CONFIG_DIR}"
    
    # Set permissions
    chmod 755 "${MONITOR_BASE_DIR}"
    chmod 755 "${CONFIG_DIR}"
    
    log_success "Directory structure created at ${MONITOR_BASE_DIR}"
}
```

**Features:**
- Explicit check and creation of base directory
- Logging of directory creation attempts
- Clear separation of base directory and subdirectories
- Proper permission setting (755)
- Test mode support (shows what would be created)

### 4. do_setup() Integration (Line 755-760)

```bash
do_setup() {
    log_info "Starting host change monitoring setup..."
    # ... display configuration ...
    
    if [[ $TEST_MODE -eq 0 ]]; then
        check_root
        # Ensure log directory exists early
        ensure_log_dir
    else
        log_warning "[TEST MODE] Skipping root check"
    fi
    setup_directories
    # ... rest of setup ...
}
```

**Features:**
- Calls `ensure_log_dir()` after root check
- Called before any other operations
- Skipped in test mode
- Ensures directory exists before other setup operations

## Execution Flow

### Startup Sequence
1. Script starts with `set -euo pipefail` (error handling)
2. Parse `-test` and `-debug` flags
3. **Source `/opt/divtools/docker/sites/s00-shared/.env.s00-shared`** ← NEW
4. Load `DT_LOG_*` variables with fallback defaults
5. Set `MONITOR_BASE_DIR = ${DT_LOG_DIR}`

### Setup Sequence
1. `do_setup()` starts
2. Display environment configuration (shows which env file was sourced)
3. `check_root()` - verify running as root
4. **`ensure_log_dir()` - CREATE DIRECTORY IF MISSING** ← NEW
5. `setup_directories()` - create subdirectories
6. `configure_bash_history()` - configure shells
7. Rest of setup operations...

## Usage Examples

### Test mode (no directory creation)
```bash
./host_change_log.sh -test -debug setup
```

### Production setup (creates directory if missing)
```bash
sudo ./host_change_log.sh setup
```

### Custom directory location (creates if missing)
```bash
DT_LOG_DIR=/var/custom/logs sudo ./host_change_log.sh setup
```

### Verify which env file is being sourced
```bash
./host_change_log.sh -test setup | grep "Shared env file"
```

## Verification

All changes have been validated:
- ✅ Syntax check passed (`bash -n`)
- ✅ Environment file is sourced correctly
- ✅ Directory creation is functional
- ✅ Test mode works properly
- ✅ Debug mode shows proper logging
- ✅ Fallback defaults work if env file not found

## Files Modified

- `/home/divix/divtools/scripts/util/host_chg_mon/host_change_log.sh`
  - Lines 24-36: Environment file sourcing
  - Lines 73-82: New `ensure_log_dir()` function
  - Lines 96-113: Enhanced `setup_directories()` function
  - Lines 755-760: Integration in `do_setup()`

## Backward Compatibility

✅ **Fully backward compatible**
- Script still works if environment file doesn't exist (uses fallback defaults)
- Existing directory structures are unaffected
- No breaking changes to command-line interface
- All existing features continue to work as before
