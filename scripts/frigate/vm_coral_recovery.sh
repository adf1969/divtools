#!/bin/bash
# Coral TPU VM Recovery Script
# Quick recovery when Coral TPU becomes unavailable in the VM
# Last Updated: 11/27/2025 3:30:00 PM CST
# Run this on the VM (gpu1-75) as a quick check/recovery attempt

# Help function
show_help() {
    cat << 'HELPEOF'
CORAL TPU VM RECOVERY SCRIPT

USAGE:
  vm_coral_recovery.sh [OPTIONS]

DESCRIPTION:
  Quick Coral TPU recovery check when run on the VM.
  Checks if Coral is visible and suggests recovery options.
  
  NOTE: For full recovery with automatic fixes, use the Proxmox script:
    ssh root@tnfs1 'bash /home/divix/divtools/scripts/frigate/proxmox_coral_fix.sh -skip-checks'

LOCATION TO RUN:
  On the VM (gpu1-75) - NOT on Proxmox host

OPTIONS:
  -h, --help        Show this help message and exit
  -debug, --debug   Enable debug mode with detailed output
  -test, --test     Run in TEST mode (show what would happen)

EXAMPLES:
  # Quick check
  /home/divix/divtools/scripts/frigate/vm_coral_recovery.sh

  # Test mode (safe, no changes)
  /home/divix/divtools/scripts/frigate/vm_coral_recovery.sh -test

  # With debug output
  /home/divix/divtools/scripts/frigate/vm_coral_recovery.sh -debug

WHAT IT DOES:
  STEP 1: Check if Coral is visible (exits if yes)
  STEP 2: Verify autosuspend is disabled on VM
  STEP 3: Suggests recovery options based on situation

WHY IT'S NEEDED:
  When you're already on the VM and notice Coral is missing, this script
  provides quick diagnostics. However, the actual fix must come from the
  Proxmox host since the passthrough issue is at the host level.

WHEN TO USE:
  1. You're on the VM and Frigate fails with EdgeTPU error
  2. You want a quick check before contacting admin
  3. You want to trigger remote recovery from VM

RECOVERY OPTIONS PROVIDED:
  Option 1: Trigger Proxmox fix via SSH (requires SSH access from VM to host)
  Option 2: Request admin to run: qm reboot 275
  Option 3: Manual restart of Frigate container

SUCCESS INDICATORS:
  ✓ "Coral TPU is already VISIBLE" - Device is working
  ✓ Script suggests next steps if found

FAILURE INDICATORS:
  ✗ "Coral TPU is NOT visible" - Device not available
  ✗ Script provides recovery options

BEST PRACTICE:
  For production recovery, run from Proxmox host instead:
    proxmox_coral_fix.sh -skip-checks
  
  This script is mainly for quick manual checks when on the VM.

AUTOMATED USE (ADVANCED):
  Can be called via SSH from monitoring system, but the Proxmox fix script
  is recommended for automated recovery since it has better diagnostics.

SEE ALSO:
  proxmox_coral_fix.sh - Main fix script (run on Proxmox host)
  proxmox_coral_check.sh - Diagnostic on Proxmox host
  coral_status_check.sh - Health check on VM

CREATED: November 20, 2025
LOCATION: /home/divix/divtools/scripts/frigate/vm_coral_recovery.sh
HELPEOF
    exit 0
}

# Check for help first
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
fi

# Source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(dirname "$SCRIPT_DIR")/util/logging.sh"

DEBUG_MODE=0
TEST_MODE=0

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
            log "INFO" "Running in TEST mode - no changes will be made"
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
log "INFO" "Coral TPU VM Quick Check"
log "INFO" "═══════════════════════════════════════════════════════════"
log "INFO" "Hostname: $(hostname)"
log "INFO" "Timestamp: $(date)"
log "INFO" ""

if [[ $TEST_MODE -eq 1 ]]; then
    log "WARN" "⚠ TEST MODE - No changes will be made"
    log "INFO" ""
fi

# Step 1: Check if Coral is already visible
log "INFO" "─── STEP 1: Check Coral Visibility ───"
log "INFO" "Checking if Coral TPU is visible..."

if lsusb | grep -q "18d1:9302" 2>/dev/null; then
    CORAL_INFO=$(lsusb | grep "18d1:9302")
    log "INFO:HEAD" "✓ Coral TPU is already VISIBLE"
    log "INFO" "  $CORAL_INFO"
    log "INFO" ""
    log "INFO" "No recovery needed. Device is working correctly."
    log "INFO" "If Frigate still isn't using it:"
    log "INFO" "  docker restart frigate"
    exit 0
else
    log "WARN" "✗ Coral TPU is NOT visible"
    log "INFO" "Attempting to diagnose..."
fi

# Step 2: Check autosuspend on VM
log "INFO" ""
log "INFO" "─── STEP 2: Check Autosuspend Setting ───"

AUTOSUSPEND=$(cat /sys/module/usbcore/parameters/autosuspend 2>/dev/null)
log "DEBUG" "Current autosuspend: $AUTOSUSPEND"

if [[ "$AUTOSUSPEND" != "-1" ]]; then
    log "WARN" "⚠ Autosuspend is ENABLED ($AUTOSUSPEND)"
    log "INFO" "Attempting to disable..."
    
    if [[ $TEST_MODE -eq 1 ]]; then
        log "TEST" "Would run: echo -1 > /sys/module/usbcore/parameters/autosuspend"
    else
        if echo "-1" > /sys/module/usbcore/parameters/autosuspend 2>/dev/null; then
            log "INFO:HEAD" "✓ Autosuspend disabled on this VM"
            log "INFO" "This may not fix the issue if it's a QEMU-level passthrough problem"
        else
            log "WARN" "⚠ Could not disable autosuspend (permission denied - may need sudo)"
        fi
    fi
else
    log "INFO" "✓ Autosuspend already disabled (-1)"
fi

# Step 3: Suggest recovery options
log "INFO" ""
log "INFO" "─── STEP 3: Recovery Options ───"
log "INFO" ""
log "INFO" "Coral TPU is not visible on this VM."
log "INFO" "This is typically a QEMU passthrough issue on the Proxmox host."
log "INFO" ""
log "INFO" "RECOMMENDED SOLUTIONS (in order):"
log "INFO" ""
log "INFO" "  1. [BEST] Trigger Proxmox fix from this VM:"
log "INFO" "     ssh root@tnfs1 'bash /home/divix/divtools/scripts/frigate/proxmox_coral_fix.sh -skip-checks'"
log "INFO" "     (Proxmox host will diagnose and offer VM reboot if needed)"
log "INFO" ""
log "INFO" "  2. [IF SSH DOESN'T WORK] Request admin to reboot VM:"
log "INFO" "     ssh root@tnfs1 'qm reboot 275'"
log "INFO" "     (Most reliable fix for QEMU passthrough issues)"
log "INFO" ""
log "INFO" "  3. [QUICK TRY] Just restart Frigate:"
log "INFO" "     docker restart frigate"
log "INFO" "     (Works if device reconnects on its own)"
log "INFO" ""
log "INFO" "═══════════════════════════════════════════════════════════"
log "INFO" "Most Coral issues require VM reboot to fix the QEMU passthrough."
log "INFO" "═══════════════════════════════════════════════════════════"

exit 1

