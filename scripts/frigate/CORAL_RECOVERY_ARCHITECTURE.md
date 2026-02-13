# Coral TPU Recovery Architecture (November 27, 2025)

## Overview
The Coral TPU recovery system now uses a **single-source-of-truth** architecture where the Proxmox host script handles all diagnostics and offers recovery options (never forcing automatic reboots).

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│          proxmox_coral_fix.sh (MAIN SCRIPT)                │
│                  Run on Proxmox host                        │
│                                                               │
│  Step 1: Check autosuspend on host                           │
│  Step 2: Try xHCI reset (via sysfs)                          │
│  Step 3: Check Coral visible on HOST                         │
│  Step 4: Check Coral visible in VM (via qm exec)             │
│       ├─ If yes → SUCCESS, exit with instructions            │
│       └─ If no → OFFER VM reboot (requires confirmation)     │
│                                                               │
└─────────────────────────────────────────────────────────────┘
                           ↓
            ┌──────────────────────────────┐
            │ VM visible?                  │
            └──────────────────────────────┘
                    ↙              ↘
              YES (✓)            NO (✗)
                ↓                  ↓
        Device working      Offer reboot:
        Recommend:          "qm reboot 275"
        1. docker           (USER DECIDES)
           restart
           frigate
        2. Check logs
        
        NEVER AUTOMATIC REBOOT
```

## Recovery Flow

### Scenario 1: Host-level Issue (Device not visible on Proxmox)
```
$ proxmox_coral_fix.sh -skip-checks
├─ Disable autosuspend ✓
├─ Try xHCI reset
└─ Check host visibility
    └─ ✗ NOT VISIBLE
        └─ Hardware issue detected
            └─ Suggest checking:
               • Physical USB cable
               • lsusb | grep 18d1
               • dmesg | grep usb
```

### Scenario 2: QEMU Passthrough Issue (Host OK, VM broken)
```
$ proxmox_coral_fix.sh -skip-checks
├─ Disable autosuspend ✓
├─ Try xHCI reset ⚠ (fails because QEMU holds device)
│   └─ [WARN] This is normal when passthrough active
├─ Check host visibility
│   └─ ✓ VISIBLE on host
├─ Check VM visibility (qm exec 275 lsusb)
│   └─ ✗ NOT visible in VM
├─ Diagnose: QEMU passthrough broken
└─ OFFER recovery:
    "Would you like to reboot the VM now? (REQUIRES YOUR CONFIRMATION)"
    "To reboot: ssh root@tnfs1 'qm reboot 275'"
    [USER DECIDES]
```

### Scenario 3: Full Recovery (Everything works)
```
$ proxmox_coral_fix.sh -skip-checks
├─ Disable autosuspend ✓
├─ Try xHCI reset ✓
├─ Check host visibility
│   └─ ✓ VISIBLE on host
├─ Check VM visibility
│   └─ ✓ VISIBLE in VM
└─ SUCCESS
    ├─ Recommend: docker restart frigate
    ├─ Verify: docker logs frigate | grep edgetpu
    └─ Permanent fix: kernel parameters already applied
```

## Key Design Decisions

### 1. Single Script from Proxmox Host
**Why?** The passthrough issue originates at the host level. Running from Proxmox:
- ✓ Can check both host and VM status
- ✓ Can use `qm exec` to run commands inside VM
- ✓ Can trigger kernel-level fixes (xHCI reset)
- ✓ Has all diagnostic information in one place

**vs. Old approach (VM script SSH'ing to host):**
- ✗ Required bidirectional SSH setup
- ✗ Couldn't check VM status accurately
- ✗ Multiple points of failure

### 2. Offer Reboot, Never Force It
**Why?** Production systems need explicit confirmation:
- ✓ User/admin has control over when restart happens
- ✓ Can plan for Frigate downtime
- ✓ No surprise reboots from automated processes
- ✓ Clear output shows exactly what to do

**Output when reboot recommended:**
```
⚠ RECOMMENDED: Reboot the VM
To reboot: qm reboot 275

After VM reboots:
  1. Wait 30-60 seconds for VM to restart
  2. docker restart frigate
  3. Verify: docker logs frigate | tail -50 | grep -i edgetpu
```

### 3. VM Script is Secondary (Information Only)
**Purpose:** Quick manual check when on the VM:
```bash
$ vm_coral_recovery.sh
├─ Check if Coral visible (exit if yes)
├─ Check autosuspend setting
└─ Suggest options:
    1. Trigger Proxmox fix: ssh root@tnfs1 'proxmox_coral_fix.sh -skip-checks'
    2. Request admin: qm reboot 275
    3. Try restart: docker restart frigate
```

## Usage Summary

### Recommended: Run from Proxmox Host
```bash
# Quick test (shows what would happen)
proxmox_coral_fix.sh -test

# Actual fix (checks host and VM, offers recovery)
proxmox_coral_fix.sh -skip-checks

# With diagnostic output
proxmox_coral_fix.sh -debug -skip-checks
```

### Alternative: Quick Check from VM
```bash
# Show Coral status and suggest options
vm_coral_recovery.sh

# Test mode
vm_coral_recovery.sh -test
```

## Exit Codes

### proxmox_coral_fix.sh
- `0` - Success (fixes applied or no issues found)
- `1` - Error or intervention needed (e.g., xHCI reset failed without VM fix)

### vm_coral_recovery.sh
- `0` - Coral visible, no recovery needed
- `1` - Coral not visible, recovery options provided

## Integration with Monitoring

### Automated Health Check
```bash
# Cron job to monitor Coral availability
*/15 * * * * ssh root@tnfs1 'bash proxmox_coral_fix.sh -test' | \
             grep -q "✓ Coral TPU is VISIBLE in VM" || \
             echo "WARNING: Coral TPU issue detected" | mail admin@example.com
```

### Alert When Intervention Needed
```bash
# Monitor for passthrough issues
*/5 * * * * \
  if ! ssh root@tnfs1 'lsusb | grep -q 18d1:9302'; then
    echo "CRITICAL: Coral not visible on Proxmox host" | mail admin
    exit 1
  fi
```

## Troubleshooting

### Problem: "Failed to unbind xHCI device"
**Cause:** VM has active passthrough connection; QEMU is holding the device  
**Solution:** This is normal and expected. Script continues to check VM status.

### Problem: "Coral visible on host but NOT in VM"
**Cause:** QEMU passthrough connection broken  
**Solution:** Script offers VM reboot. Accept it or run `qm reboot 275` manually.

### Problem: "Coral not visible even on host"
**Cause:** Hardware issue, not software  
**Solution:** Check USB cable, physical device, kernel logs

## Future Enhancements

1. **Auto-Recovery Option:** Add `-auto-reboot` flag for fully automated recovery (explicit opt-in)
   ```bash
   proxmox_coral_fix.sh -skip-checks -auto-reboot
   ```

2. **Email Notifications:** Integrate with mail system for alerts

3. **Metrics Collection:** Log recovery events for trending analysis

4. **Multi-VM Support:** Extend to handle multiple VMs with Coral passthrough

## Created/Modified
- **November 27, 2025 3:30 PM CST** - Complete architecture redesign
- **File:** `proxmox_coral_fix.sh` (Enhanced with qm exec VM checking)
- **File:** `vm_coral_recovery.sh` (Simplified to information-only)
- **File:** `CORAL_RECOVERY_ARCHITECTURE.md` (This document)
