#!/bin/bash
# Quick Usage Guide for Coral TPU Proxmox Scripts
# This file serves as documentation for the two new scripts

cat << 'EOF'

╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║        CORAL TPU PROXMOX DIAGNOSTIC AND FIX SCRIPTS - QUICK REFERENCE        ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝

LOCATION:
  Both scripts are in: /home/divix/divtools/scripts/frigate/

═════════════════════════════════════════════════════════════════════════════════

SCRIPT 1: proxmox_coral_check.sh
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PURPOSE:
  Diagnoses Coral TPU connectivity issues on Proxmox host and related VMs.
  Does NOT make any changes - only reports status.

LOCATION TO RUN:
  On Proxmox host (tnfs1)

BASIC USAGE:
  ssh root@tnfs1 'bash /home/divix/divtools/scripts/frigate/proxmox_coral_check.sh'

OPTIONS:
  -debug, --debug    Show detailed debug output
  -v, --verbose      Verbose mode

EXAMPLES:
  # Basic check
  ssh root@tnfs1 'bash /home/divix/divtools/scripts/frigate/proxmox_coral_check.sh'

  # With debug output
  ssh root@tnfs1 'bash /home/divix/divtools/scripts/frigate/proxmox_coral_check.sh -debug'

WHAT IT CHECKS:
  ✓ Coral TPU visible on Proxmox host (lsusb)
  ✓ Autosuspend setting on running kernel
  ✓ Kernel cmdline parameters (for persistence on reboot)
  ✓ VMs with Coral TPU passthrough
  ✓ Coral visibility in each running VM

EXPECTED OUTPUT (Healthy System):
  ✓ System appears HEALTHY - Coral is visible and autosuspend is disabled
  ✓ VMs with TPU passthrough: 1

EXPECTED OUTPUT (Unhealthy System):
  ✗ System has ISSUES - check diagnostics above
    - Coral TPU not visible on Proxmox host
    - Autosuspend is not disabled (causing device resets)

═════════════════════════════════════════════════════════════════════════════════

SCRIPT 2: proxmox_coral_fix.sh
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PURPOSE:
  Implements fixes for Coral TPU connectivity issues.
  Includes diagnostic checks and applies both temporary and permanent fixes.

LOCATION TO RUN:
  On Proxmox host (tnfs1)

IMPORTANT NOTES:
  - NEVER reboots automatically (you can do that manually if needed)
  - Temporary fixes survive until Proxmox host reboots
  - Permanent fixes require manual action (kernel parameters)

BASIC USAGE:
  ssh root@tnfs1 'bash /home/divix/divtools/scripts/frigate/proxmox_coral_fix.sh'

OPTIONS:
  -test, --test           Run in TEST mode (no changes made, shows what would happen)
  -debug, --debug         Show detailed debug output
  -skip-checks            Skip diagnostic checks and apply fixes directly

EXAMPLES:
  # Test mode (safe to run, shows what would happen)
  ssh root@tnfs1 'bash /home/divix/divtools/scripts/frigate/proxmox_coral_fix.sh -test'

  # Apply fixes for real
  ssh root@tnfs1 'bash /home/divix/divtools/scripts/frigate/proxmox_coral_fix.sh'

  # Apply fixes and skip the diagnostic check
  ssh root@tnfs1 'bash /home/divix/divtools/scripts/frigate/proxmox_coral_fix.sh -skip-checks'

WHAT IT DOES:
  STEP 1: Runs diagnostic check (proxmox_coral_check.sh)
          - If system is healthy, exits without making changes
          - If system has issues, proceeds with fixes

  STEP 2: Disable USB Autosuspend (Temporary)
          - Sets usbcore.autosuspend=-1 on running kernel
          - Takes effect immediately
          - Resets if Proxmox host reboots

  STEP 3: Reset xHCI USB Controller
          - Unbinds xHCI device from driver
          - Rebinds it to force re-enumeration
          - Causes Coral to reconnect

  STEP 4: Verify Coral is visible
          - Checks if Coral TPU appears after reset
          - Waits up to 10 seconds for re-enumeration

  STEP 5: Check for permanent kernel parameters
          - Checks if /etc/kernel/cmdline includes autosuspend setting
          - Tells you if manual permanent fix is needed

EXPECTED OUTPUT (Already Healthy):
  ✓ System check passed
  System appears healthy. Exiting without making changes.

EXPECTED OUTPUT (Fixed Successfully):
  ✓ Temporary fixes applied successfully
  Status:
    ✓ Autosuspend disabled on running kernel
    ✓ xHCI controller reset
    ✓ Coral TPU verified
  This temporary fix will work until the Proxmox host reboots.

═════════════════════════════════════════════════════════════════════════════════

PERMANENT FIX (Manual Kernel Parameters)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

The temporary fixes work immediately but reset on Proxmox reboot.
To make the fix permanent, the scripts will tell you to:

STEP 1: Add parameters to kernel cmdline
  ssh root@tnfs1 'echo "$(cat /etc/kernel/cmdline) usbcore.autosuspend=-1 usbcore.autosuspend_delay_ms=0" > /etc/kernel/cmdline'

STEP 2: Refresh boot configuration
  ssh root@tnfs1 'proxmox-boot-tool refresh'

STEP 3: Reboot Proxmox host (when you're ready)
  ssh root@tnfs1 'reboot'

STEP 4: Verify after reboot
  ssh root@tnfs1 'bash /home/divix/divtools/scripts/frigate/proxmox_coral_check.sh'

═════════════════════════════════════════════════════════════════════════════════

TROUBLESHOOTING WORKFLOW
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SITUATION: Frigate is failing with "Failed to load delegate from libedgetpu.so.1.0"

STEP 1: Run diagnostic check
  ssh root@tnfs1 'bash /home/divix/divtools/scripts/frigate/proxmox_coral_check.sh'

STEP 2: Review output
  - If "System appears HEALTHY", the issue may be Frigate-specific
  - If "System has ISSUES", proceed to Step 3

STEP 3: Test the fix (safe, no changes)
  ssh root@tnfs1 'bash /home/divix/divtools/scripts/frigate/proxmox_coral_fix.sh -test'

STEP 4: Apply the fix
  ssh root@tnfs1 'bash /home/divix/divtools/scripts/frigate/proxmox_coral_fix.sh'

STEP 5: Check Frigate
  # Give it a few seconds for device to reconnect
  sleep 5
  docker restart frigate
  docker logs frigate --since 30s | grep -i "coral\|edgetpu\|delegate"

STEP 6: Plan permanent fix (optional but recommended)
  - Follow "Permanent Fix" section above to make changes survive reboots
  - Don't rush - do this when you have maintenance window

═════════════════════════════════════════════════════════════════════════════════

AUTOMATION (For monitoring)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

You could run the check script periodically (e.g., via cron):

  */30 * * * * ssh -o StrictHostKeyChecking=no root@tnfs1 'bash /home/divix/divtools/scripts/frigate/proxmox_coral_check.sh' >> /var/log/coral_check.log 2>&1

Or create a cron job that auto-fixes if issues are detected:

  */5 * * * * ssh -o StrictHostKeyChecking=no root@tnfs1 'bash /home/divix/divtools/scripts/frigate/proxmox_coral_check.sh' || ssh -o StrictHostKeyChecking=no root@tnfs1 'bash /home/divix/divtools/scripts/frigate/proxmox_coral_fix.sh'

═════════════════════════════════════════════════════════════════════════════════

RELATED SCRIPTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

proxmox_coral_reset.sh
  Similar to proxmox_coral_fix.sh but older version
  Use the new proxmox_coral_fix.sh instead

coral_status_check.sh
  Checks Coral status on the VM itself (not on Proxmox host)
  Run this to verify TPU is working from inside the VM

═════════════════════════════════════════════════════════════════════════════════

SUPPORT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Debug information is available with the -debug flag:
  ssh root@tnfs1 'bash /home/divix/divtools/scripts/frigate/proxmox_coral_check.sh -debug'

The scripts use the logging.sh utility from:
  /home/divix/divtools/scripts/util/logging.sh

═════════════════════════════════════════════════════════════════════════════════

Created: November 14, 2025
Last Updated: 11/14/2025 7:55:00 PM CST

EOF
