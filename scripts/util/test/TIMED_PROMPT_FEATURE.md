# Host Setup Checks - Timed Prompt Feature

## Overview
Modified `host_setup_checks.sh` to prevent VSCode terminal hangs when sudo prompts are in the background.

## Problem
- Sometimes when opening a VSCode terminal, the whiptail menu would pop up
- If a sudo prompt was running in the background, it would hang VSCode
- User couldn't dismiss the whiptail without interaction

## Solution
Added a **timed prompt** that appears BEFORE the whiptail menu:
- Asks user: "Would you like to review and configure these setups now? [Y/n]"
- **10-second timeout** - auto-selects "No" if user doesn't respond
- Only shows whiptail menu if user explicitly presses "Y"

## Workflow

### Before (Old Behavior)
```
Login → Check setups → IMMEDIATELY show whiptail menu → User must interact
```

### After (New Behavior)
```
Login → Check setups → Timed prompt (10 sec) → User answers:
  - Press 'Y' → Show whiptail menu
  - Press 'n' → Skip setup
  - No response (timeout) → Auto-skip setup
```

## Code Changes

### Added Function: `timed_setup_prompt()`
Location: `scripts/util/host_setup_checks.sh` lines 51-88

```bash
timed_setup_prompt() {
    local timeout=10
    local response
    
    echo "Would you like to review and configure these setups now?"
    echo "[Y/n] (Auto-selecting 'No' in ${timeout} seconds...)"
    
    if read -t $timeout -n 1 -r response; then
        case "$response" in
            [Yy]) return 0 ;;  # Proceed
            *) return 1 ;;      # Skip
        esac
    else
        # Timeout - auto-skip
        return 1
    fi
}
```

### Modified: `host_setup_checks()` 
Location: `scripts/util/host_setup_checks.sh` lines 325-331

Added call to `timed_setup_prompt()` before showing whiptail:

```bash
if ! timed_setup_prompt; then
    debug_log "User declined or timed out on setup prompt - exiting"
    return 0
fi
```

## Testing

Run the test script:
```bash
/opt/divtools/scripts/util/test/test_timed_prompt.sh
```

This will:
1. Show the timed prompt
2. Wait 10 seconds for input
3. Report whether user said YES or timed out

## Environment Variables

The function respects existing flags:
- `DEBUG_MODE=1` - Shows debug output
- `TEST_MODE=1` - Runs in test mode (no actual execution)
- `DIVTOOLS_SKIP_CHECKS=1` - Completely bypasses all checks

## Timeout Adjustment

To change the timeout duration, edit line 53 in `host_setup_checks.sh`:
```bash
local timeout=10  # Change to desired seconds
```

## Last Updated
11/11/2025 10:05:00 PM CDT
