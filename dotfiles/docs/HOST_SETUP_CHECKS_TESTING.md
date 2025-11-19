# Host Setup Checks - Testing Guide

## Overview

The `host_setup_checks.sh` script now includes `-debug` and `-test` flags to allow thorough testing before deployment.

## Flags

### `-debug` or `--debug`
Enables debug output showing what the script is doing at each step.

**Output prefix**: `[DEBUG]` messages in white

### `-test` or `--test`
Runs in test mode where setup scripts are NOT actually executed, only reported as "would execute".

**Output prefix**: `[TEST MODE]` messages in yellow

## Testing on TNHL01

Since TNHL01 has not had dt_host_setup or host_change_log run, it's the perfect test system.

### Step 1: Enable Environment Variables (for testing)

You need to set the environment variables BEFORE sourcing the .bash_profile. There are two approaches:

**Option A: Set in shell before testing**
```bash
export DT_INCLUDE_HOST_SETUP=1
export DT_INCLUDE_HOST_CHANGE_LOG=1
export DEBUG_MODE=1
export TEST_MODE=1
```

**Option B: Create test .env file**
```bash
# Create a temporary .env
cat > /tmp/test_env.sh << 'EOF'
export DT_INCLUDE_HOST_SETUP=1
export DT_INCLUDE_HOST_CHANGE_LOG=1
EOF

source /tmp/test_env.sh
```

### Step 2: Test with Debug Mode (without test mode first)

Test that the script detects incomplete setups:

```bash
# Set environment variables
export DT_INCLUDE_HOST_SETUP=1
export DT_INCLUDE_HOST_CHANGE_LOG=1

# Source and run with debug
source /home/divix/divtools/scripts/util/host_setup_checks.sh --debug --test

# Call the function
host_setup_checks --debug --test
```

**Expected output:**
```
[DEBUG] host_setup_checks() started
[DEBUG] TEST_MODE=1, DEBUG_MODE=1
[DEBUG] DT_INCLUDE_HOST_SETUP=1
[DEBUG] DT_INCLUDE_HOST_CHANGE_LOG=1
[DEBUG] Checking DT_INCLUDE_HOST_SETUP...
[DEBUG] DT_INCLUDE_HOST_SETUP is enabled, checking status...
[DEBUG] Checking dt_host_setup status...
[DEBUG]   Looking for ~/.env file
[DEBUG]   ~/.env does not exist - setup is INCOMPLETE
[DEBUG] dt_host_setup is NOT complete, adding to menu
[DEBUG] Checking DT_INCLUDE_HOST_CHANGE_LOG...
[DEBUG] DT_INCLUDE_HOST_CHANGE_LOG is enabled, checking status...
[DEBUG] Checking host_change_log status...
[DEBUG]   Looking for manifest at: /var/log/divtools/monitor/monitoring_manifest.json
[DEBUG]   Manifest NOT found - setup is INCOMPLETE
[DEBUG] host_change_log is NOT complete, adding to menu
[DEBUG] Found 2 incomplete setup(s)

════════════════════════════════════════════════════════════════
⚠️  Pending Host Setup Tasks Detected
════════════════════════════════════════════════════════════════
  • Host Setup (Environment & Variables)
  • Host Change Log Monitoring

These setups have not been completed on this host.
Would you like to run them now?

[TEST MODE] Would execute: sudo /opt/divtools/scripts/dt_host_setup.sh
[TEST MODE] Would execute: sudo /opt/divtools/scripts/util/host_chg_mon/host_change_log.sh setup
```

### Step 3: Direct Function Call Test

```bash
export DT_INCLUDE_HOST_SETUP=1
export DT_INCLUDE_HOST_CHANGE_LOG=1

# Source the script
source /home/divix/divtools/scripts/util/host_setup_checks.sh

# Call with flags
host_setup_checks -debug -test
```

### Step 4: Test from .bash_profile (Simulated)

To test the actual integration, simulate what the .bash_profile does:

```bash
export DT_INCLUDE_HOST_SETUP=1
export DT_INCLUDE_HOST_CHANGE_LOG=1

# Source .bash_profile (this will call host_setup_checks at the end)
bash -i -c "
  export DT_INCLUDE_HOST_SETUP=1
  export DT_INCLUDE_HOST_CHANGE_LOG=1
  source /home/divix/divtools/scripts/util/host_setup_checks.sh --debug --test
  host_setup_checks --debug --test
"
```

## Debug Output Interpretation

### Setup Status Checks

```
[DEBUG] Checking dt_host_setup status...
[DEBUG]   Looking for ~/.env file
[DEBUG]   ~/.env does not exist - setup is INCOMPLETE
```
This means the script is looking for `~/.env` and checking if it contains `SITE_NAME`.

```
[DEBUG] Checking host_change_log status...
[DEBUG]   Looking for manifest at: /var/log/divtools/monitor/monitoring_manifest.json
[DEBUG]   Manifest NOT found - setup is INCOMPLETE
```
This means the script is looking for the monitoring manifest file.

### Menu Building

```
[DEBUG] DT_INCLUDE_HOST_SETUP is enabled, checking status...
[DEBUG] dt_host_setup is NOT complete, adding to menu
[DEBUG] Found 2 incomplete setup(s)
```
This shows the script has identified incomplete setups and will display the menu.

## Test Mode Behavior

When `-test` or `--test` is used:

1. The script shows what WOULD happen
2. No sudo commands are actually executed
3. Setup scripts are NOT run
4. All output shows `[TEST MODE]` prefix
5. Perfect for validating the logic without making changes

## Troubleshooting Tests

### Test 1: Variables not being read

```bash
export DT_INCLUDE_HOST_SETUP=1
source /home/divix/divtools/scripts/util/host_setup_checks.sh --debug --test
host_setup_checks --debug --test 2>&1 | grep "DT_INCLUDE"
```

Expected output should show:
```
[DEBUG] DT_INCLUDE_HOST_SETUP=1
[DEBUG] DT_INCLUDE_HOST_CHANGE_LOG=...
```

### Test 2: Status detection

```bash
bash -x /home/divix/divtools/scripts/util/host_setup_checks.sh --debug --test << 'EOF'
check_host_setup_status
echo "Exit code: $?"
EOF
```

Should show trace of execution and exit code 1 (not complete).

### Test 3: Interactive vs Non-interactive

```bash
# Test in non-interactive shell (should exit silently)
echo "export DT_INCLUDE_HOST_SETUP=1; source /home/divix/divtools/scripts/util/host_setup_checks.sh --debug; host_setup_checks" | bash

# Test in interactive shell (should show prompts)
bash -i << 'EOF'
export DT_INCLUDE_HOST_SETUP=1
source /home/divix/divtools/scripts/util/host_setup_checks.sh --debug --test
host_setup_checks
EOF
```

## Complete Test Scenario for TNHL01

```bash
#!/bin/bash
# test_host_setup_checks.sh

echo "=== Test: Host Setup Checks Detection ==="
echo ""

# Set test environment
export DT_INCLUDE_HOST_SETUP=1
export DT_INCLUDE_HOST_CHANGE_LOG=1

echo "Step 1: Check if ~/.env exists..."
if [ -f ~/.env ]; then
    echo "  ✓ ~/.env exists"
    if grep -q "SITE_NAME=" ~/.env; then
        echo "  ✓ SITE_NAME found (setup already complete)"
    else
        echo "  ✗ SITE_NAME not found (setup incomplete)"
    fi
else
    echo "  ✗ ~/.env does not exist (setup incomplete)"
fi

echo ""
echo "Step 2: Check if monitoring manifest exists..."
if [ -f /var/log/divtools/monitor/monitoring_manifest.json ]; then
    echo "  ✓ Manifest found (setup already complete)"
else
    echo "  ✗ Manifest not found (setup incomplete)"
fi

echo ""
echo "Step 3: Run setup checks with debug and test mode..."
source /home/divix/divtools/scripts/util/host_setup_checks.sh --debug --test
host_setup_checks --debug --test

echo ""
echo "=== Test Complete ==="
```

Save and run:
```bash
chmod +x /tmp/test_host_setup_checks.sh
/tmp/test_host_setup_checks.sh 2>&1 | head -50
```

## What to Look For

✅ **Successful Test Indicators:**
- `[DEBUG]` messages show the script is running
- Script detects that dt_host_setup is incomplete
- Script detects that host_change_log is incomplete
- Menu appears with both setups listed
- `[TEST MODE]` messages show what would execute
- No actual sudo execution happens

❌ **Problem Indicators:**
- No `[DEBUG]` output (debug mode not working)
- Variables show as "not set" (environment not passed correctly)
- Script exits without showing menu (interactive shell check failing)
- No menu appears (completion detection wrong or variables not set)

## Next Steps

Once testing is verified on TNHL01:

1. Enable in your actual .env files
2. Test on additional hosts
3. Deploy to production with confidence

## Quick Test Commands

```bash
# Quick test in one line
export DT_INCLUDE_HOST_SETUP=1 DT_INCLUDE_HOST_CHANGE_LOG=1 && \
  bash -i -c "source /home/divix/divtools/scripts/util/host_setup_checks.sh -debug -test && host_setup_checks"

# Test just the detection
source /home/divix/divtools/scripts/util/host_setup_checks.sh -debug && \
  DT_INCLUDE_HOST_SETUP=1 check_host_setup_status && \
  echo "Status: $?"

# Test from actual shell
bash -i
# Then in the shell:
export DT_INCLUDE_HOST_SETUP=1
export DT_INCLUDE_HOST_CHANGE_LOG=1
# Open new shell or manually source:
source ~/.bash_profile
```
