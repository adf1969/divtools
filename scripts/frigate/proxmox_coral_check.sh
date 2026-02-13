#!/bin/bash
# Proxmox Coral TPU Diagnostic Check
# Diagnoses Coral TPU connectivity issues across Proxmox host and VMs
# Last Updated: 11/14/2025 7:45:00 PM CST

# Help function
show_help() {
    cat << 'HELPEOF'
PROXMOX CORAL TPU DIAGNOSTIC CHECK

USAGE:
  proxmox_coral_check.sh [OPTIONS]

DESCRIPTION:
  Diagnoses Coral TPU connectivity issues on Proxmox host and related VMs.
  This script performs read-only diagnostics and does NOT make any changes.
  Safe to run anytime for system health verification.

OPTIONS:
  -h, --help        Show this help message and exit
  -debug, --debug   Enable debug mode with detailed output
  -v, --verbose     Enable verbose output

EXAMPLES:
  # Basic diagnostic check
  proxmox_coral_check.sh

  # Check with debug output
  proxmox_coral_check.sh -debug

  # Verbose output
  proxmox_coral_check.sh -v

WHAT IT CHECKS:
  ✓ Coral TPU visible on Proxmox host (lsusb)
  ✓ Autosuspend setting on running kernel (should be -1)
  ✓ Kernel command line parameters (for persistence on reboot)
  ✓ All VMs with Coral TPU passthrough configuration
  ✓ Coral visibility in each running VM

RETURN CODES:
  0   System is healthy
  1   System has issues requiring attention

EXIT CONDITIONS:
  • If not run on Proxmox host, exits with error
  • If no issues found, exits with code 0
  • If issues found, exits with code 1

OUTPUT:
  Detailed health report with sections for:
  • Proxmox Host Status
  • USB Autosuspend Setting
  • Coral Device Detection
  • Kernel Parameters
  • VM Status and Testing
  • Overall Summary

USE CASES:
  1. Quick health check before troubleshooting
  2. Automated monitoring (exit code useful for cron)
  3. Verification after running proxmox_coral_fix.sh
  4. Part of automated monitoring/alerting systems

RELATED SCRIPTS:
  proxmox_coral_fix.sh      - Implement fixes for detected issues
  coral_status_check.sh     - VM-side health check
  CORAL_PROXMOX_SCRIPTS_GUIDE.sh - Complete documentation

SEE ALSO:
  Full guide: bash /home/divix/divtools/scripts/frigate/CORAL_PROXMOX_SCRIPTS_GUIDE.sh
  Quick reference: cat /home/divix/divtools/scripts/frigate/PROXMOX_CORAL_QUICK_COMMANDS.txt

CREATED: November 14, 2025
LOCATION: /home/divix/divtools/scripts/frigate/proxmox_coral_check.sh
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
VERBOSE=0

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
        -v|--verbose)
            VERBOSE=1
            log "INFO" "Verbose mode enabled"
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
log "INFO" "Coral TPU Diagnostic Check - Proxmox Host"
log "INFO" "═══════════════════════════════════════════════════════════"
log "INFO" "Hostname: $(hostname)"
log "INFO" "Timestamp: $(date)"
log "INFO" ""

# Check if Coral is visible on Proxmox host
log "INFO" "─── PROXMOX HOST STATUS ───"
log "INFO" "Checking for Coral TPU on Proxmox host..."

CORAL_FOUND=0
CORAL_BUS=""
CORAL_DEVICE=""
CORAL_INFO=""

# Get the Coral device info
CORAL_INFO=$(lsusb -d 18d1:9302 2>/dev/null)

if [[ -n "$CORAL_INFO" ]]; then
    CORAL_FOUND=1
    CORAL_BUS=$(echo "$CORAL_INFO" | awk '{print $2}')
    CORAL_DEVICE=$(echo "$CORAL_INFO" | sed 's/:$//' | awk '{print $4}')
    log "INFO:HEAD" "✓ Coral TPU FOUND on Proxmox host"
    log "INFO" "  Bus: $CORAL_BUS, Device: $CORAL_DEVICE"
    log "INFO" "  Info: $CORAL_INFO"
else
    log "WARN" "✗ Coral TPU NOT found on Proxmox host (lsusb)"
fi

# Check autosuspend setting on host
log "INFO" ""
log "INFO" "Checking autosuspend setting on Proxmox host..."
AUTOSUSPEND=$(cat /sys/module/usbcore/parameters/autosuspend 2>/dev/null)
if [[ -z "$AUTOSUSPEND" ]]; then
    log "WARN" "⚠ Could not read autosuspend setting"
else
    if [[ "$AUTOSUSPEND" == "-1" ]]; then
        log "INFO:HEAD" "✓ Autosuspend DISABLED (-1) on Proxmox host"
    else
        log "WARN" "✗ Autosuspend ENABLED ($AUTOSUSPEND) on Proxmox host - THIS IS A PROBLEM"
    fi
fi

# Check kernel cmdline
log "INFO" ""
log "INFO" "Checking kernel command line parameters..."
CMDLINE=$(cat /etc/kernel/cmdline 2>/dev/null)
if [[ -z "$CMDLINE" ]]; then
    log "WARN" "⚠ Could not read kernel cmdline"
else
    log "DEBUG" "Kernel cmdline: $CMDLINE"
    if echo "$CMDLINE" | grep -q "usbcore.autosuspend"; then
        log "INFO:HEAD" "✓ Kernel parameters include autosuspend setting (will persist on reboot)"
    else
        log "WARN" "✗ Kernel parameters DO NOT include autosuspend setting (temporary fix only)"
    fi
fi

# Find VMs with Coral TPU passthrough
log "INFO" ""
log "INFO" "─── VM STATUS ───"
log "INFO" "Searching for VMs with Coral TPU passthrough..."

FOUND_VM_WITH_TPU=0
VMS_FOUND=()

# Check all VM config files
for vm_config in /etc/pve/qemu-server/*.conf; do
    [[ ! -f "$vm_config" ]] && continue
    
    vm_id=$(basename "$vm_config" .conf)
    
    # Check if this VM has Coral passthrough
    if grep -q "usb.*host=18d1:9302" "$vm_config"; then
        VMS_FOUND+=("$vm_id")
        log "DEBUG" "Found VM $vm_id with Coral TPU passthrough"
    fi
done

if [[ ${#VMS_FOUND[@]} -eq 0 ]]; then
    log "WARN" "✗ No VMs found with Coral TPU passthrough"
else
    log "INFO:HEAD" "✓ Found ${#VMS_FOUND[@]} VM(s) with Coral TPU passthrough:"
    
    for vm_id in "${VMS_FOUND[@]}"; do
        # Check if VM is running
        vm_status=$(qm status "$vm_id" 2>/dev/null | awk '{print $2}')
        
        if [[ "$vm_status" == "running" ]]; then
            log "INFO:HEAD" "  ► VM $vm_id is RUNNING"
            
            # Try to check Coral presence in VM via SSH
            if command -v ssh &>/dev/null; then
                log "DEBUG" "Attempting to check Coral in VM $vm_id..."
                
                # Get VM IP (try to get from dhcp.leases or arp)
                vm_ip=$(grep -h "^$vm_id," /var/lib/dnsmasq/dhcp-leases 2>/dev/null | head -1 | cut -d',' -f3)
                
                if [[ -n "$vm_ip" ]]; then
                    log "DEBUG" "VM $vm_id IP: $vm_ip"
                    
                    # Check if Coral is visible in VM
                    if ssh -o ConnectTimeout=3 -o StrictHostKeyChecking=no "root@$vm_ip" "lsusb | grep -q 18d1:9302" 2>/dev/null; then
                        log "INFO:HEAD" "    ✓ Coral TPU VISIBLE in VM $vm_id"
                    else
                        log "WARN" "    ✗ Coral TPU NOT visible in VM $vm_id (may be connection issue)"
                    fi
                else
                    log "DEBUG" "Could not determine IP for VM $vm_id (skipping remote check)"
                fi
            fi
        else
            log "INFO" "  ► VM $vm_id is NOT running ($vm_status)"
        fi
    done
fi

# Summary
log "INFO" ""
log "INFO" "═══════════════════════════════════════════════════════════"
log "INFO" "SUMMARY"
log "INFO" "═══════════════════════════════════════════════════════════"

if [[ $CORAL_FOUND -eq 1 && "$AUTOSUSPEND" == "-1" ]]; then
    log "INFO:HEAD" "✓ System appears HEALTHY - Coral is visible and autosuspend is disabled"
    log "INFO" ""
    if [[ ${#VMS_FOUND[@]} -gt 0 ]]; then
        log "INFO" "VMs with TPU passthrough: ${#VMS_FOUND[@]}"
    fi
    exit 0
else
    log "WARN" "✗ System has ISSUES - check diagnostics above"
    log "INFO" ""
    if [[ $CORAL_FOUND -eq 0 ]]; then
        log "WARN" "  - Coral TPU not visible on Proxmox host"
    fi
    if [[ "$AUTOSUSPEND" != "-1" ]]; then
        log "WARN" "  - Autosuspend is not disabled (causing device resets)"
    fi
    exit 1
fi
