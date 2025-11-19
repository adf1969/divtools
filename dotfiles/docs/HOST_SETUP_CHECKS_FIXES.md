# Host Setup Checks - Fix for Double Sourcing & Not Running

## Issues Identified

### Issue 1: Checks Not Running at Login
**Root Cause**: The environment variables `DT_INCLUDE_HOST_SETUP` and `DT_INCLUDE_HOST_CHANGE_LOG` were never set, so the script had nothing to check.

### Issue 2: Double Sourcing
**Root Cause**: No guard to prevent the script from being sourced multiple times if `.bash_profile` is sourced multiple times.

## Fixes Applied

### Fix 1: Added Double-Sourcing Protection

Added to `host_setup_checks.sh`:
```bash
# Prevent double-sourcing
if [ -n "$HOST_SETUP_CHECKS_SOURCED" ]; then
    return 0
fi
export HOST_SETUP_CHECKS_SOURCED=1
```

This ensures the script is only sourced once per shell session.

### Fix 2: Better Flag Initialization

Changed flag initialization to support both environment variables and command-line arguments:
```bash
# Initialize TEST_MODE and DEBUG_MODE from environment if not already set
TEST_MODE=${TEST_MODE:-0}
DEBUG_MODE=${DEBUG_MODE:-0}
```

This allows you to set `TEST_MODE=1` or `DEBUG_MODE=1` in the environment before sourcing.

### Fix 3: Added Debug Output

Added debug log when script is sourced:
```bash
debug_log "host_setup_checks.sh sourced (TEST_MODE=$TEST_MODE, DEBUG_MODE=$DEBUG_MODE)"
```

### Fix 4: Improved .bash_profile Integration

Updated `.bash_profile` to be more robust:
```bash
HOST_SETUP_CHECKS_SCRIPT="${DIVTOOLS:-/opt/divtools}/scripts/util/host_setup_checks.sh"
if [ -f "$HOST_SETUP_CHECKS_SCRIPT" ]; then
    source "$HOST_SETUP_CHECKS_SCRIPT"
    host_setup_checks
fi
```

## New Diagnostic Script

Created `/home/divix/divtools/scripts/diagnose_host_setup_checks.sh` to help troubleshoot.

This script checks:
1. Is this an interactive shell?
2. Is DIVTOOLS variable set?
3. Does host_setup_checks.sh exist?
4. Are required environment variables set?
5. Where are variables set (.env files)?
6. Has the script been sourced?
7. What's the setup completion status?
8. Summary and recommendations

## How to Use the Diagnostic Script

Simply run:
```bash
/home/divix/divtools/scripts/diagnose_host_setup_checks.sh
```

or if you're already in an interactive shell:
```bash
bash /home/divix/divtools/scripts/diagnose_host_setup_checks.sh
```

The script will tell you exactly why the checks aren't running.

## Why Checks Aren't Running

The most likely reason: **Environment variables are NOT set**

The script looks for these variables:
- `DT_INCLUDE_HOST_SETUP` (set to 1 or true)
- `DT_INCLUDE_HOST_CHANGE_LOG` (set to 1 or true)

**Without these variables**, the script has no work to do and exits silently.

## How to Enable (Choose ONE location)

### Option 1: User Level (just you)
```bash
cat >> ~/.env << 'EOF'
export DT_INCLUDE_HOST_SETUP=1
export DT_INCLUDE_HOST_CHANGE_LOG=1
EOF
```

### Option 2: Shared Level (all hosts)
```bash
cat >> /opt/divtools/docker/sites/s00-shared/.env.s00-shared << 'EOF'
export DT_INCLUDE_HOST_SETUP=1
export DT_INCLUDE_HOST_CHANGE_LOG=1
EOF
```

### Option 3: Site Level
```bash
# Replace SITE_NAME with your actual site name
cat >> /opt/divtools/docker/sites/SITE_NAME/.env.SITE_NAME << 'EOF'
export DT_INCLUDE_HOST_SETUP=1
export DT_INCLUDE_HOST_CHANGE_LOG=1
EOF
```

## After Setting Variables

After adding variables to your `.env` file:

1. **Open a NEW interactive shell**:
   ```bash
   bash -i
   ```

2. **Or source .bash_profile** (in current shell):
   ```bash
   source ~/.bash_profile
   ```
   
   Note: If you've already sourced it once, the double-sourcing protection will prevent re-sourcing. Just open a new shell instead.

3. **The menu should appear** if setups are incomplete

## Testing Without Enabling Permanently

To test without adding to `.env`:

```bash
export DT_INCLUDE_HOST_SETUP=1
export DT_INCLUDE_HOST_CHANGE_LOG=1
bash -i
```

## Debugging

### Enable Debug Mode
```bash
export DEBUG_MODE=1
source ~/.bash_profile
```

### Enable Test Mode (dry-run)
```bash
export TEST_MODE=1
export DT_INCLUDE_HOST_SETUP=1
export DT_INCLUDE_HOST_CHANGE_LOG=1
bash -i
```

### Run Diagnostic Script
```bash
/home/divix/divtools/scripts/diagnose_host_setup_checks.sh
```

This will show you:
- Which variables are set
- Where they're set (which .env file)
- Why checks are or aren't running
- What the completion status is for each setup

## Double Sourcing Issue

The double-sourcing protection means:
- First time `.bash_profile` is sourced → script runs normally
- Second time `.bash_profile` is sourced → script returns immediately
- New shell → script runs normally again

To reset (if testing):
```bash
unset HOST_SETUP_CHECKS_SOURCED
```

## Summary of Changes

### Files Modified
1. **host_setup_checks.sh**
   - Added double-sourcing protection
   - Better flag initialization
   - Added debug output on sourcing

2. **.bash_profile**
   - Improved robustness
   - Better variable handling
   - Added comments

### Files Created
3. **diagnose_host_setup_checks.sh**
   - Comprehensive diagnostic tool
   - Checks all conditions
   - Provides recommendations

## Quick Reference

| Issue | Solution |
|-------|----------|
| Checks not running | Set `DT_INCLUDE_*` variables in .env |
| Don't know why it's not running | Run diagnostic script |
| Testing without permanent changes | Export variables before bash -i |
| Want debug output | Set `DEBUG_MODE=1` |
| Want dry-run | Set `TEST_MODE=1` |
| Double sourcing | Fixed automatically with guard |

## Next Steps

1. **Run diagnostic script to see current state**:
   ```bash
   /home/divix/divtools/scripts/diagnose_host_setup_checks.sh
   ```

2. **Enable variables in appropriate .env file**

3. **Open new interactive shell**:
   ```bash
   bash -i
   ```

4. **Menu should appear if setups are incomplete**

---

**Last Updated**: November 11, 2025 8:30 PM CDT
