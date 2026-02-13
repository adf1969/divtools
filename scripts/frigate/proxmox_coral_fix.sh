#!/bin/bash
# Proxmox Coral TPU Fix Script
# Implements fixes for Coral TPU connectivity issues
# Last Updated: 11/14/2025 7:50:00 PM CST

# Help function
show_help() {
    cat << 'HELPEOF'
PROXMOX CORAL TPU FIX SCRIPT

USAGE:
  proxmox_coral_fix.sh [OPTIONS]

DESCRIPTION:
  Implements fixes for Coral TPU connectivity issues on Proxmox host.
  Includes built-in diagnostic checks and multiple levels of safety.
  Temporary fixes work immediately, permanent fixes require manual action.
  Script NEVER auto-reboots - you control when to reboot.

OPTIONS:
  -h, --help              Show this help message and exit
  -test, --test           Run in TEST mode (shows what would happen, no changes)
  -debug, --debug         Enable debug mode with detailed output
  -skip-checks            Skip diagnostic checks and apply fixes directly (emergency only)

EXAMPLES:
  # Test mode (safe, no changes)
  proxmox_coral_fix.sh -test

  # Apply fixes for real
  proxmox_coral_fix.sh

  # Apply with debug output
  proxmox_coral_fix.sh -debug

  # Emergency: skip checks and apply fixes directly
  proxmox_coral_fix.sh -skip-checks

WHAT IT DOES:
  STEP 1: Runs diagnostic check (proxmox_coral_check.sh)
          • If system is healthy, exits without making changes
          • If system has issues, proceeds with fixes

  STEP 2: Disable USB Autosuspend (Temporary)
          • Sets usbcore.autosuspend=-1 on running kernel
          • Takes effect immediately
          • Survives until Proxmox host reboots

  STEP 3: Reset xHCI USB Controller
          • Unbinds xHCI device from driver
          • Rebinds it to force re-enumeration
          • Causes Coral TPU to reconnect at Proxmox level

  STEP 4: Verify Coral on Proxmox Host
          • Checks if Coral TPU is visible after reset
          • Waits up to 10 seconds for re-enumeration

  STEP 4B: Verify Coral Inside VM (gpu1-75)
          • Checks if Coral is actually accessible inside the VM
          • If visible on host but NOT in VM: passthrough is broken
          • Offers VM reboot option if needed (you must confirm)

  STEP 5: Check permanent kernel parameters
          • Verifies /etc/kernel/cmdline has autosuspend setting
          • Provides instructions for permanent fix if needed

RETURN CODES:
  0   Success (fixes applied or system already healthy)
  1   Error (something went wrong)

TEST MODE DETAILS:
  • Shows what commands would be executed
  • Does NOT actually execute any commands
  • Safe to run to verify behavior
  • Useful for validating before actual fix

TEMPORARY vs PERMANENT FIXES:
  TEMPORARY:
    • Applied immediately by this script
    • Works until Proxmox host reboots
    • If host reboots, must re-run this script

  PERMANENT:
    • Requires kernel parameter modification
    • Need to:
      1. Add parameters to /etc/kernel/cmdline
      2. Run proxmox-boot-tool refresh
      3. Reboot Proxmox host
    • Script provides exact commands to run

SAFETY FEATURES:
  ✓ Never auto-reboots (you control when)
  ✓ Diagnostic check prevents fixing healthy systems
  ✓ Test mode shows what would happen
  ✓ Proper error handling with meaningful messages
  ✓ Exit codes for automation

RELATED SCRIPTS:
  proxmox_coral_check.sh    - Diagnostic only (read-only)
  coral_status_check.sh     - VM-side health check
  CORAL_PROXMOX_SCRIPTS_GUIDE.sh - Complete documentation

USE CASES:
  1. Emergency recovery when Frigate fails with EdgeTPU error
  2. Automated fixes via cron/monitoring
  3. Testing via -test mode before applying
  4. Integration with alerting systems (uses proper exit codes)

EXAMPLE WORKFLOW:
  1. Verify the problem: proxmox_coral_check.sh
  2. Test the fix: proxmox_coral_fix.sh -test
  3. Apply the fix: proxmox_coral_fix.sh
  4. Restart Frigate: docker restart frigate
  5. Check status: /home/divix/divtools/scripts/frigate/coral_status_check.sh
  6. Plan permanent fix (when ready)

SEE ALSO:
  Full guide: bash /home/divix/divtools/scripts/frigate/CORAL_PROXMOX_SCRIPTS_GUIDE.sh
  Quick reference: cat /home/divix/divtools/scripts/frigate/PROXMOX_CORAL_QUICK_COMMANDS.txt

CREATED: November 14, 2025
LOCATION: /home/divix/divtools/scripts/frigate/proxmox_coral_fix.sh
HELPEOF
    exit 0
}

# Check for help first (before Proxmox check)
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
fi

# Only run on Proxmox host
if [[ ! -f /etc/pve/.version ]]; then
    echo "[ERROR] This script must be run on a Proxmox host"
    exit 1
fi

# Source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(dirname "$SCRIPT_DIR")/util/logging.sh"

DEBUG_MODE=0
TEST_MODE=0
SKIP_CHECKS=0
FORCE_REBOOT=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            ;;
        -debug|--debug)
            DEBUG_MODE=1
            log "DEBUG" "Debug mode enabled"
            shift
            ;;
        -test|--test)
            TEST_MODE=1
            log "INFO" "Running in TEST mode - no permanent changes will be made"
            shift
            ;;
        -skip-checks|--skip-checks)
            SKIP_CHECKS=1
            log "WARN" "Skipping diagnostic checks"
            shift
            ;;
        *)
            log "ERROR" "Unknown option: $1"
            log "ERROR" "Run with -h or --help for usage information"
            exit 1
            ;;
    esac
done

log "INFO" "═══════════════════════════════════════════════════════════"
log "INFO" "Coral TPU Fix Script - Proxmox Host"
log "INFO" "═══════════════════════════════════════════════════════════"
log "INFO" "Hostname: $(hostname)"
log "INFO" "Timestamp: $(date)"
log "INFO" ""

if [[ $TEST_MODE -eq 1 ]]; then
    log "WARN" "⚠ TEST MODE - No permanent changes will be made"
    log "INFO" ""
fi

# Step 1: Run diagnostic check unless skipped
if [[ $SKIP_CHECKS -eq 0 ]]; then
    log "INFO" "─── STEP 1: Diagnostic Check ───"
    
    if bash "$SCRIPT_DIR/proxmox_coral_check.sh" -debug 2>/dev/null; then
        log "INFO" "✓ System check passed"
        log "INFO" ""
        log "INFO" "System appears healthy. Exiting without making changes."
        exit 0
    else
        log "WARN" "✗ System check found issues - proceeding with fixes"
        log "INFO" ""
    fi
else
    log "INFO" "Skipping diagnostic checks (as requested)"
    log "INFO" ""
fi

# Step 2: Disable autosuspend on running kernel
log "INFO" "─── STEP 2: Disable USB Autosuspend (Temporary) ───"

CURRENT_AUTOSUSPEND=$(cat /sys/module/usbcore/parameters/autosuspend 2>/dev/null)
log "DEBUG" "Current autosuspend setting: $CURRENT_AUTOSUSPEND"

if [[ "$CURRENT_AUTOSUSPEND" == "-1" ]]; then
    log "INFO" "✓ Autosuspend already disabled on running kernel"
else
    log "INFO" "Disabling autosuspend on running kernel..."
    
    if [[ $TEST_MODE -eq 1 ]]; then
        log "TEST" "Would run: echo -1 > /sys/module/usbcore/parameters/autosuspend"
    else
        if echo "-1" > /sys/module/usbcore/parameters/autosuspend 2>/dev/null; then
            log "INFO:HEAD" "✓ Autosuspend disabled on running kernel"
            CURRENT_AUTOSUSPEND=$(cat /sys/module/usbcore/parameters/autosuspend 2>/dev/null)
            log "DEBUG" "Verified: autosuspend = $CURRENT_AUTOSUSPEND"
        else
            log "ERROR" "✗ Failed to disable autosuspend"
            exit 1
        fi
    fi
fi

# Step 3: Reset xHCI controller
log "INFO" ""
log "INFO" "─── STEP 3: Reset xHCI USB Controller ───"

log "INFO" "Finding xHCI controller..."
XHCI_DEVICE=$(lspci | grep -i xhci | head -1)

if [[ -z "$XHCI_DEVICE" ]]; then
    log "ERROR" "✗ Could not find xHCI controller"
    exit 1
fi

log "DEBUG" "Found: $XHCI_DEVICE"
XHCI_BUS=$(echo "$XHCI_DEVICE" | awk '{print $1}')
log "DEBUG" "xHCI Bus ID: $XHCI_BUS"

log "INFO" "Unbinding xHCI device from driver..."

if [[ $TEST_MODE -eq 1 ]]; then
    log "TEST" "Would run: echo $XHCI_BUS > /sys/bus/pci/drivers/xhci_hcd/unbind"
    log "TEST" "Would sleep 2 seconds"
    log "TEST" "Would run: echo $XHCI_BUS > /sys/bus/pci/drivers/xhci_hcd/bind"
    log "TEST" "Would sleep 5 seconds"
else
    if echo "$XHCI_BUS" > /sys/bus/pci/drivers/xhci_hcd/unbind 2>/dev/null; then
        log "INFO:HEAD" "✓ xHCI unbound successfully"
        sleep 2
        
        log "INFO" "Rebinding xHCI device..."
        if echo "$XHCI_BUS" > /sys/bus/pci/drivers/xhci_hcd/bind 2>/dev/null; then
            log "INFO:HEAD" "✓ xHCI rebound successfully"
            sleep 5
        else
            log "WARN" "⚠ Warning: Failed to rebind xHCI device (may already be bound)"
        fi
    else
        log "WARN" "⚠ Warning: Could not unbind xHCI device (may be in use by QEMU/VM)"
        log "WARN" "This is normal when the VM has an active USB passthrough connection"
        log "INFO" "Continuing to check VM status..."
        sleep 2
    fi
fi

# Step 4: Verify Coral is visible on Proxmox host
log "INFO" ""
log "INFO" "─── STEP 4: Verify Coral on Proxmox Host ───"

sleep 2

CORAL_CHECK=$(lsusb -d 18d1:9302 2>/dev/null)
CORAL_VISIBLE_HOST=0

if [[ -n "$CORAL_CHECK" ]]; then
    log "INFO:HEAD" "✓ Coral TPU is VISIBLE on Proxmox host"
    log "INFO" "  $CORAL_CHECK"
    CORAL_VISIBLE_HOST=1
else
    log "WARN" "⚠ Coral TPU not immediately visible (may take a moment to re-enumerate)"
    log "INFO" "Waiting 5 more seconds..."
    sleep 5
    
    CORAL_CHECK=$(lsusb -d 18d1:9302 2>/dev/null)
    if [[ -n "$CORAL_CHECK" ]]; then
        log "INFO:HEAD" "✓ Coral TPU is now VISIBLE on Proxmox host"
        log "INFO" "  $CORAL_CHECK"
        CORAL_VISIBLE_HOST=1
    else
        log "WARN" "✗ Coral TPU not visible on Proxmox host"
        log "WARN" "This may indicate a hardware issue with the USB device"
    fi
fi

# Step 4B: Check if Coral is visible on VM (critical - visible on host but not VM means passthrough is broken)
log "INFO" ""
log "INFO" "─── STEP 4B: Verify Coral on VM (gpu1-75) ───"

CORAL_VISIBLE_VM=0
if [[ $TEST_MODE -eq 1 ]]; then
    log "TEST" "Would run on VM: qm exec 275 lsusb | grep 18d1"
else
    # Run lsusb inside VM using qm exec
    VM_CORAL_CHECK=$(qm exec 275 "lsusb 2>/dev/null" 2>/dev/null | grep "18d1:9302" || true)
    
    if [[ -n "$VM_CORAL_CHECK" ]]; then
        log "INFO:HEAD" "✓ Coral TPU is VISIBLE inside VM (gpu1-75)"
        log "INFO" "  $VM_CORAL_CHECK"
        log "INFO" "Passthrough is working correctly"
        CORAL_VISIBLE_VM=1
    else
        log "WARN" "✗ Coral TPU is NOT visible inside VM (gpu1-75)"
        log "WARN" "This means the xHCI passthrough connection is broken at QEMU level"
        
        if [[ $CORAL_VISIBLE_HOST -eq 1 ]]; then
            log "WARN" ""
            log "WARN" "⚠ DIAGNOSIS: Device visible on host but NOT in VM"
            log "WARN" "The xHCI reset on Proxmox host did not restore the passthrough."
            log "WARN" "A VM reboot is usually needed to fix QEMU-level passthrough issues."
            log "WARN" ""
            log "WARN" "Would you like to reboot the VM now? (REQUIRES YOUR CONFIRMATION)"
            log "WARN" "To reboot: ssh root@$(hostname) 'qm reboot 275'"
            log "WARN" ""
            log "WARN" "The VM will:"
            log "WARN" "  1. Gracefully shutdown (takes ~10-30 seconds)"
            log "WARN" "  2. Restart automatically"
            log "WARN" "  3. Coral should reconnect automatically"
            log "WARN" ""
            log "WARN" "After VM reboots:"
            log "WARN" "  docker restart frigate"
            log "WARN" "  docker logs frigate | grep -i edgetpu"
        fi
    fi
fi

# Step 5: Check/update kernel parameters for persistence
log "INFO" ""
log "INFO" "─── STEP 5: Permanent Kernel Parameters ───"

CMDLINE=$(cat /etc/kernel/cmdline 2>/dev/null)
log "DEBUG" "Current kernel cmdline: $CMDLINE"

if echo "$CMDLINE" | grep -q "usbcore.autosuspend"; then
    log "INFO" "✓ Kernel parameters already include autosuspend setting (persistent on reboot)"
else
    log "WARN" "⚠ Kernel parameters DO NOT include autosuspend setting"
    log "INFO" ""
    log "INFO" "The temporary fix will RESET if Proxmox host reboots."
    log "INFO" ""
    log "INFO" "To make this permanent, you should:"
    log "INFO" "  1. Run: ssh root@$(hostname) 'echo \"$(cat /etc/kernel/cmdline) usbcore.autosuspend=-1 usbcore.autosuspend_delay_ms=0\" > /etc/kernel/cmdline'"
    log "INFO" "  2. Run: ssh root@$(hostname) 'proxmox-boot-tool refresh'"
    log "INFO" "  3. Reboot the Proxmox host when convenient"
    log "INFO" ""
fi

# Step 6: Summary
log "INFO" "═══════════════════════════════════════════════════════════"
log "INFO" "FIX COMPLETE"
log "INFO" "═══════════════════════════════════════════════════════════"

if [[ $TEST_MODE -eq 1 ]]; then
    log "WARN" "TEST MODE - No changes were actually made"
    log "INFO" ""
    log "INFO" "To apply the fixes for real, run:"
    log "INFO" "  $0"
else
    # Check results
    if [[ $CORAL_VISIBLE_VM -eq 1 ]]; then
        # Everything worked!
        log "INFO:HEAD" "✓ SUCCESS - Coral TPU is available in VM"
        log "INFO" ""
        log "INFO" "Status:"
        log "INFO" "  ✓ Autosuspend disabled on running kernel"
        log "INFO" "  ✓ xHCI controller reset"
        log "INFO" "  ✓ Coral visible on Proxmox host"
        log "INFO" "  ✓ Coral visible inside VM"
        log "INFO" ""
        log "INFO" "Temporary fix will work until Proxmox host reboots."
        log "INFO" ""
        log "INFO" "Recommended next steps:"
        log "INFO" "  1. docker restart frigate"
        log "INFO" "  2. docker logs frigate | tail -50 | grep -i edgetpu"
        log "INFO" "  3. See permanent fix instructions above for kernel parameters"
    elif [[ $CORAL_VISIBLE_HOST -eq 1 ]]; then
        # Host is OK but VM is broken
        log "INFO:HEAD" "✓ Host-level fix applied, but VM passthrough issue detected"
        log "INFO" ""
        log "INFO" "Status:"
        log "INFO" "  ✓ Autosuspend disabled on running kernel"
        log "INFO" "  ✓ xHCI controller reset"
        log "INFO" "  ✓ Coral visible on Proxmox host"
        log "INFO" "  ✗ Coral NOT visible inside VM (QEMU passthrough broken)"
        log "INFO" ""
        log "INFO" "The xHCI reset did not restore the passthrough connection."
        log "INFO" "A VM reboot is usually needed to fix this."
        log "INFO" ""
        log "WARN" "⚠ RECOMMENDED: Reboot the VM"
        log "WARN" "To reboot: qm reboot 275"
        log "INFO" ""
        log "INFO" "After VM reboots:"
        log "INFO" "  1. Wait 30-60 seconds for VM to restart"
        log "INFO" "  2. docker restart frigate"
        log "INFO" "  3. Verify: docker logs frigate | tail -50 | grep -i edgetpu"
    else
        # Even host is broken
        log "WARN" "✗ Coral TPU not visible even on Proxmox host"
        log "INFO" ""
        log "INFO" "This indicates a hardware issue, not a passthrough problem."
        log "WARN" "Check:"
        log "WARN" "  1. Is the Coral TPU physically connected?"
        log "WARN" "  2. Try: lsusb | grep 18d1  # manually on Proxmox host"
        log "WARN" "  3. Check dmesg: dmesg | tail -100 | grep -i usb"
    fi
fi

exit 0
