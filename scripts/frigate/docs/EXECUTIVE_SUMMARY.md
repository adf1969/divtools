# CORAL USB TPU FIX - EXECUTIVE SUMMARY

## Status: ✓ ISSUE IDENTIFIED AND FIXED

**Date**: November 11, 2025  
**System**: VM gpu1-75 (Frigate) on Proxmox host tnfs1  
**Issue**: Coral USB TPU disconnecting every 2-10 minutes  
**Root Cause**: `usbcore.autosuspend=2` kernel parameter  
**Solution**: Set `usbcore.autosuspend=-1` in kernel boot parameters

---

## What Happened

### The Problem
Your Coral USB TPU was disconnecting frequently, causing Frigate to crash with:
```
ValueError: Failed to load delegate from libedgetpu.so.1.0
No EdgeTPU was detected
```

### Why It Was Happening
The Linux kernel was configured to suspend USB devices after 2 seconds of inactivity. The Coral USB TPU doesn't handle suspend/resume cycles well and would disconnect when suspended. Once disconnected, the Proxmox USB passthrough couldn't re-establish the connection.

### The Solution
Disable USB autosuspend by setting it to -1 (never suspend).

---

## What Was Changed

### VM (gpu1-75) - PERMANENT ✓
**File**: `/etc/default/grub`
```
GRUB_CMDLINE_LINUX="usbcore.autosuspend=-1"
```
**Status**: Applied, tested, confirmed working

### Proxmox Host (tnfs1) - TEMPORARY (needs follow-up)
**Current**: `usbcore.autosuspend=-1` (set via shell command)
**Status**: Working but resets on reboot
**Next Step**: Make permanent after 48-hour stability test

---

## Verification

All tests pass:
- ✓ Autosuspend is disabled (value = -1)
- ✓ Coral device is visible (`lsusb | grep 18d1` returns device)
- ✓ Frigate is running and healthy
- ✓ No Coral errors in recent logs

---

## What You Need to Do Now

### Next 48 Hours: Monitor
Run this command periodically (every 6-12 hours):
```bash
/home/divix/divtools/scripts/frigate/coral_status_check.sh
```

**Goal**: Verify Coral stays connected for 48 hours without disconnection.

### After 48-Hour Test Passes (November 13)
Make the fix permanent on the Proxmox host:
```bash
ssh root@tnfs1 'bash -s' <<'EOF'
if ! grep -q "usbcore.autosuspend" /etc/kernel/cmdline; then
    echo "$(cat /etc/kernel/cmdline) usbcore.autosuspend=-1" > /etc/kernel/cmdline
fi
EOF
```
Then reboot the Proxmox host at your convenience.

---

## If Coral Disconnects During the 48-Hour Test

Emergency fix (run on Proxmox host):
```bash
ssh root@tnfs1 'bash /home/divix/divtools/scripts/frigate/proxmox_disable_coral_autosuspend.sh'
```

Or manually:
```bash
ssh root@tnfs1 'echo "-1" > /sys/module/usbcore/parameters/autosuspend'
```

---

## Key Files Created

| File | Purpose |
|------|---------|
| `coral_status_check.sh` | Run this to verify system health (quick check) |
| `proxmox_disable_coral_autosuspend.sh` | Emergency fix script for Proxmox host |
| `README_CORAL_FIX.md` | Complete reference guide |
| `MAINTENANCE_CHECKLIST.md` | Checklist for next 48 hours |
| `CORAL_USB_SUMMARY.md` | Detailed summary with troubleshooting |

All in: `/home/divix/divtools/scripts/frigate/`

---

## Technical Details

**Why this works:**
- USB autosuspend causes the kernel to suspend devices after inactivity
- Coral TPU can't handle suspend/resume cycles over xHCI emulation
- Setting autosuspend to -1 disables this feature

**Why rebooting helped:**
- The new kernel parameter took effect on boot
- USB passthrough was re-established cleanly
- Device stayed connected after initialization

**Why Proxmox host also needs the fix:**
- Prevents device from suspending on the host side
- Ensures stable passthrough channel to the VM

---

## Expected Outcome

After the 48-hour test and permanent Proxmox host fix:
- Coral should remain connected indefinitely
- Frigate should run without crashes
- Object detection should work smoothly

---

## Contact Information

If issues arise:
1. Read `/home/divix/divtools/scripts/frigate/README_CORAL_FIX.md`
2. Run status check: `/home/divix/divtools/scripts/frigate/coral_status_check.sh`
3. Run emergency fix: `ssh root@tnfs1 'bash /home/divix/divtools/scripts/frigate/proxmox_disable_coral_autosuspend.sh'`

---

**Timeline**
- **11/11/2025 11:19 AM** - Issue identified
- **11/11/2025 12:00 PM** - Fix applied to VM
- **11/11/2025 12:15 PM** - Fix verified working
- **11/13/2025 12:15 PM** - Target completion date for 48-hour test
- **After 11/13** - Apply permanent fix to Proxmox host

**Current Status**: Working ✓  
**Confidence Level**: High (tested and verified)  
**Risk Level**: Low (only kernel parameter change)
