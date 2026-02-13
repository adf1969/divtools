# Coral USB TPU Troubleshooting Summary
## For gpu1-75 VM with Frigate on tnfs1 Proxmox

---

## ✓ ISSUE IDENTIFIED & FIXED (11/11/2025)

### Root Cause
USB autosuspend timeout (`usbcore.autosuspend=2`) was causing the Coral TPU to disconnect every 2-10 minutes.

### Solution Applied
**VM (gpu1-75)**: ✓ ALREADY FIXED  
- Kernel parameter set: `usbcore.autosuspend=-1`
- Location: `/etc/default/grub` 
- Status: Tested and working - Coral now visible and Frigate functional

**Proxmox Host (tnfs1)**: ⏳ TEMPORARY FIX (manual, temporary)
- Current: `usbcore.autosuspend=-1` (set manually via shell)
- Status: Temporary - resets on reboot
- Next Step: Make permanent via kernel parameters after 48-hour stability test

---

## Quick Commands for Daily Use

### Check if Coral is working
```bash
# On gpu1-75 VM:
lsusb | grep -i coral
docker ps --filter name=frigate --format "{{.Status}}"
docker logs frigate --since 1h | grep -i "error\|failed" | wc -l
```

### If Coral drops offline
```bash
# Step 1: Check host
ssh root@tnfs1 "lsusb | grep 18d1"

# Step 2: Re-enable autosuspend fix on host (if needed)
ssh root@tnfs1 'bash /home/divix/divtools/scripts/frigate/proxmox_disable_coral_autosuspend.sh'

# Step 3: Monitor recovery in VM
watch -n 2 'lsusb | grep coral || echo "DISCONNECTED"'
docker logs frigate -f | grep coral
```

---

## Available Scripts in /divtools/scripts/frigate/

### For Immediate Issues
- **`proxmox_disable_coral_autosuspend.sh`** - Quickly disable autosuspend on Proxmox host (temporary fix)
- **`fix_coral_usb_autosuspend.sh`** - Disable autosuspend per-device (guest-side)
- **`reset_coral_usb.sh`** - Manually reset Coral device

### For Diagnostics
- **`diagnostic_coral_usb.sh`** - Full diagnostic report with all USB and power settings
- **`proxmox_test_coral.sh`** - Run specific tests on Proxmox host

### For Monitoring (Future)
- **`coral_watchdog.sh`** - Auto-recovery service (not yet deployed)
- **`coral_watchdog.service`** - Systemd service file for watchdog

---

## Timeline of Changes

### 11/11/2025
| Time | Action | Status |
|------|--------|--------|
| 11:19 AM | Diagnosed: autosuspend=2 is root cause | ✓ |
| 11:45 AM | Disabled autosuspend on Proxmox host (temporary) | ✓ |
| 11:50 AM | Disabled autosuspend on VM (temporary) | ✓ |
| 12:00 PM | Set VM kernel parameter permanently via GRUB | ✓ |
| 12:15 PM | **VM REBOOT TEST: Coral working!** | ✓ |

### Next Milestones
- **11/13/2025** - 48-hour stability check (continue monitoring)
- **11/13/2025** - Apply permanent fix to Proxmox host (if VM stable)
- **11/15/2025** - Optionally deploy watchdog service

---

## What Changed in Your System

### On gpu1-75 VM
```bash
# File: /etc/default/grub
# Changed from:
GRUB_CMDLINE_LINUX=""
# To:
GRUB_CMDLINE_LINUX="usbcore.autosuspend=-1"

# Effect: Disables USB autosuspend on every boot
```

### What Still Needs to Happen
```bash
# On tnfs1 Proxmox host:
# Edit /etc/kernel/cmdline and add: usbcore.autosuspend=-1
# This is optional but recommended for consistency
# Can be done after confirming VM stability
```

---

## Monitoring Checklist (For Next 48 Hours)

Use this checklist to verify stability:

```bash
# Every 6-12 hours, run:
echo "=== Coral Status Check ==="
echo "Coral visible in lsusb:"
lsusb | grep 18d1

echo ""
echo "Frigate status:"
docker ps --filter name=frigate

echo ""
echo "Recent Coral errors (last 4 hours):"
docker logs frigate --since 4h | grep -i "coral\|edgetpu.*error" | wc -l

echo ""
echo "System uptime:"
uptime

echo ""
echo "Coral autosuspend setting:"
cat /sys/module/usbcore/parameters/autosuspend
```

If all checks pass consistently for 48 hours, the fix is working!

---

## Recovery Procedure (If Needed Before 48 Hours)

If Coral disconnects during the test period:

```bash
# 1. Verify it's actually disconnected
lsusb | grep 18d1

# 2. Re-enable the fix on Proxmox host
ssh root@tnfs1 'bash /home/divix/divtools/scripts/frigate/proxmox_disable_coral_autosuspend.sh'

# 3. Wait 5 seconds and check if it reappears
sleep 5
lsusb | grep 18d1

# 4. If still not visible, restart the VM or Frigate container
docker restart frigate

# 5. Log it and note the time for analysis
echo "$(date): Coral disconnection event" >> /tmp/coral_events.log
```

---

## Notes

1. **Why reboot fixed it**: The VM reboot re-established the USB passthrough with the new kernel parameter active
2. **Why it was disconnecting**: Every 2 seconds, the Coral would get suspended and lost the USB connection
3. **Why Proxmox host also needs the fix**: To prevent the device from being suspended on the host, which could affect passthrough
4. **Why this affects only this VM**: It's passing through a USB device over xHCI emulation, which is more sensitive to power management

---

## Next: After 48-Hour Test Passes

Once you confirm 48 hours of stable operation:

```bash
# 1. Update Proxmox host permanently
ssh root@tnfs1 'bash -s' <<'EOF'
if ! grep -q "usbcore.autosuspend" /etc/kernel/cmdline; then
    echo "$(cat /etc/kernel/cmdline) usbcore.autosuspend=-1" > /etc/kernel/cmdline
    echo "✓ Added to kernel parameters. Host reboot required."
fi
EOF

# 2. Schedule Proxmox host reboot at convenient time
ssh root@tnfs1 'echo "shutdown -r +60 \"Applying Coral USB fix\"" | at now'

# 3. After reboot, verify:
ssh root@tnfs1 'cat /sys/module/usbcore/parameters/autosuspend'
```

---

**Status**: WORKING ✓  
**Last Test**: 11/11/2025 12:15 PM  
**Next Review**: 11/13/2025  
**Created By**: Diagnostic Testing Script  
**For**: gpu1-75 VM / tnfs1 Proxmox
