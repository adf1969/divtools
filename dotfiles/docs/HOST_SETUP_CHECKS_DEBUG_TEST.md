# Host Setup Checks - Debug & Test Enhancements

## Summary

The `host_setup_checks.sh` script has been enhanced with `-debug` and `-test` flags to allow thorough testing and troubleshooting. A companion test script has also been created for easy validation.

## What Was Fixed

### Problem
The original script was not showing the setup menu when environment variables were not set in `.bash_profile`. The script silently returned with no indication of why nothing happened.

### Solution
Added comprehensive debug and test mode support:

1. **Debug Mode (`-debug`)** - Shows exactly what the script is doing at each step
2. **Test Mode (`-test`)** - Dry-run execution (no changes made to the system)
3. **Enhanced Detection** - Now properly detects incomplete setups when called

## Files Updated/Created

### Updated
- `/home/divix/divtools/scripts/util/host_setup_checks.sh`
  - Added flag parsing at the beginning
  - Added `debug_log()` function
  - Added debug output to all major functions
  - Added test mode support to `run_host_setup()` and `run_host_change_log_setup()`

### Created
- `/home/divix/divtools/scripts/test_host_setup_checks.sh`
  - Easy-to-run test script
  - Checks both setup completion statuses
  - Calls the main function with debug/test flags
  - Provides clear summary of results

- `/home/divix/divtools/dotfiles/docs/HOST_SETUP_CHECKS_TESTING.md`
  - Comprehensive testing guide
  - Step-by-step instructions for TNHL01
  - Expected output examples
  - Troubleshooting tests

## How to Test

### Easiest Method - Run the Test Script

```bash
/home/divix/divtools/scripts/test_host_setup_checks.sh
```

This script will:
1. Check if dt_host_setup has been run
2. Check if host_change_log has been run
3. Run the checks with debug and test flags
4. Show you exactly what's happening

### Manual Test with Full Debug Output

```bash
export DT_INCLUDE_HOST_SETUP=1
export DT_INCLUDE_HOST_CHANGE_LOG=1
source /home/divix/divtools/scripts/util/host_setup_checks.sh -debug -test
host_setup_checks
```

### Test Integration with .bash_profile

```bash
export DT_INCLUDE_HOST_SETUP=1
export DT_INCLUDE_HOST_CHANGE_LOG=1
bash -i
# In the new shell, the checks should run automatically
```

## Debug Output Explained

### Setup Detection
```
[DEBUG] Checking dt_host_setup status...
[DEBUG]   Looking for ~/.env file
[DEBUG]   ~/.env does not exist - setup is INCOMPLETE
[DEBUG] dt_host_setup is NOT complete, adding to menu
```

This shows the script is:
1. Checking for `~/.env`
2. Looking for `SITE_NAME=` in that file
3. Determining the setup is incomplete
4. Adding it to the menu

### Completion Checks
```
[DEBUG] Found 2 incomplete setup(s)
```

Shows that both setups need to be run.

### Test Mode Execution
```
[TEST MODE] Would execute: sudo /opt/divtools/scripts/dt_host_setup.sh
[TEST MODE] Would execute: sudo /opt/divtools/scripts/util/host_chg_mon/host_change_log.sh setup
```

Shows what WOULD execute without actually running anything.

## Key Points

✅ **Environment Variables Required**
- The flags `DT_INCLUDE_HOST_SETUP=1` and `DT_INCLUDE_HOST_CHANGE_LOG=1` must be set
- These should be in your `.env` files at one of the precedence levels
- Without these, the checks don't know which setups to verify

✅ **Interactive Shell Required**
- Checks only run in interactive shells (`bash -i`)
- Non-interactive shells skip the checks automatically

✅ **Debug Output Location**
- Debug messages go to stderr (2>&1)
- Can be captured separately: `script 2>debug.log`

✅ **Flags Can Be Combined**
- `-debug -test` can be used together
- Flags work when sourcing or calling the function

## Flag Usage Examples

### Just Debug (no test)
```bash
source script.sh -debug
host_setup_checks
# Shows what's happening, but actually executes setup scripts
```

### Just Test (no debug)
```bash
source script.sh -test
host_setup_checks
# Dry-run execution, no debug output
```

### Both Debug and Test
```bash
source script.sh -debug -test
host_setup_checks
# Shows everything AND doesn't execute setup scripts
```

### When Calling Function
```bash
source script.sh
host_setup_checks -debug -test
```

## What the Test Script Does

```
/home/divix/divtools/scripts/test_host_setup_checks.sh
```

1. **Reports current status**
   - Shows if `~/.env` exists
   - Shows if `SITE_NAME` is in `~/.env`
   - Shows if monitoring manifest exists

2. **Sets environment variables**
   - `DT_INCLUDE_HOST_SETUP=1`
   - `DT_INCLUDE_HOST_CHANGE_LOG=1`

3. **Runs the checks**
   - Sources `host_setup_checks.sh` with `-debug -test`
   - Calls `host_setup_checks()`

4. **Shows results**
   - Displays the menu (if both setups incomplete)
   - Shows what would execute (test mode)
   - Shows debug output

5. **Provides guidance**
   - Suggests next steps
   - Shows how to enable permanently

## Expected Behavior on Fresh System (like TNHL01)

When running the test script on a system where dt_host_setup and host_change_log have NOT been run:

```
✗ ~/.env does NOT exist
✗ dt_host_setup appears INCOMPLETE

✗ Manifest NOT found
✗ host_change_log appears INCOMPLETE

════════════════════════════════════════════════════════════════
⚠️  Pending Host Setup Tasks Detected
════════════════════════════════════════════════════════════════
  • Host Setup (Environment & Variables)
  • Host Change Log Monitoring

These setups have not been completed on this host.
Would you like to run them now?

[Whiptail menu with both items checked appears]

[TEST MODE] Would execute: sudo /opt/divtools/scripts/dt_host_setup.sh
[TEST MODE] Would execute: sudo /opt/divtools/scripts/util/host_chg_mon/host_change_log.sh setup
```

## Verification Checklist

After running tests, verify:

- [ ] Script runs without syntax errors
- [ ] Debug output shows each check being performed
- [ ] Both setups are detected as incomplete (on fresh system)
- [ ] Whiptail menu appears with both items
- [ ] [TEST MODE] messages show (when using -test)
- [ ] No actual changes made (when using -test)
- [ ] Menu disappears and returns to shell (when canceling)

## Next Steps

1. **Run test script on TNHL01**
   ```bash
   /home/divix/divtools/scripts/test_host_setup_checks.sh
   ```

2. **Verify menu appears with both setups**
   - Should show "Host Setup (Environment & Variables)"
   - Should show "Host Change Log Monitoring"

3. **Enable permanently**
   ```bash
   echo "export DT_INCLUDE_HOST_SETUP=1" >> ~/.env
   echo "export DT_INCLUDE_HOST_CHANGE_LOG=1" >> ~/.env
   ```

4. **Test from .bash_profile**
   ```bash
   bash -i
   # Should see menu on login
   ```

5. **Run actual setups**
   - Select items from menu and click OK
   - Watch dt_host_setup.sh and host_change_log.sh run

## Troubleshooting

**Q: No debug output**
- Make sure you're using `-debug` flag
- Check that you're sourcing the script with the flag: `source script.sh -debug`

**Q: Menu doesn't appear**
- Check environment variables are set: `echo $DT_INCLUDE_HOST_SETUP`
- Verify you're in interactive shell: `bash -i`
- Run test script to see what's happening: `/home/divix/divtools/scripts/test_host_setup_checks.sh`

**Q: Setup scripts are executing in test mode**
- Make sure to use `-test` flag
- Check that TEST_MODE=1 in debug output

**Q: Still getting stuck setups**
- Run test script with both flags: `test_script.sh -debug -test`
- Check the setup completion detection:
  - dt_host_setup: Does `~/.env` exist with `SITE_NAME=`?
  - host_change_log: Does `/var/log/divtools/monitor/monitoring_manifest.json` exist?

## Files for Reference

- **Main Script**: `/home/divix/divtools/scripts/util/host_setup_checks.sh`
- **Test Script**: `/home/divix/divtools/scripts/test_host_setup_checks.sh`
- **Testing Guide**: `/home/divix/divtools/dotfiles/docs/HOST_SETUP_CHECKS_TESTING.md`
- **Original Docs**: `/home/divix/divtools/dotfiles/docs/HOST_SETUP_CHECKS*.md`

---

**Last Updated**: November 11, 2025
