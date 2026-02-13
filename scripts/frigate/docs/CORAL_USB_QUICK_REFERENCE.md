# Coral USB TPU - Quick Reference Guide
## for gpu1-75 / tnfs1 Setup

### Problem
Coral USB TPU (18d1:9302) on VM gpu1-75 disconnects every 2-10 minutes due to USB autosuspend timeout.

### Root Cause
`usbcore.autosuspend = 2` seconds causes the USB port to suspend, disconnecting the Coral.

### Solution: ALREADY APPLIED TO VM ✓
The VM gpu1-75 already has this fix applied (set during grub boot):
```bash
# In /etc/default/grub:
GRUB_CMDLINE_LINUX="usbcore.autosuspend=-1"
```
This persists across reboots and prevents the Coral from being suspended.

---

## If Coral Disconnects Again

### Check Current Status
```bash
# On vm (gpu1-75):
lsusb | grep -i coral
docker logs frigate --since 1m | grep -i coral

# On proxmox host (tnfs1):
ssh root@tnfs1 "lsusb | grep -i coral"
```

### Quick Fix (Temporary)
If the Coral drops offline, run this on the Proxmox host to restore it:

```bash
# Option 1: Using the script
ssh root@tnfs1 'bash /home/divix/divtools/scripts/frigate/proxmox_disable_coral_autosuspend.sh'

# Option 2: Manual command
ssh root@tnfs1 'echo "-1" > /sys/module/usbcore/parameters/autosuspend'
```

Then monitor the VM:
```bash
# Watch for Coral to appear
watch -n 2 'lsusb | grep -i coral || echo "WAITING..."'

# Watch Frigate logs
docker logs frigate -f | grep -i coral
```

---

## Permanent Fixes

### On Proxmox Host (tnfs1) - TODO
To prevent future issues, update the Proxmox host's kernel parameters:

```bash
ssh root@tnfs1

# Edit the kernel command line
nano /etc/kernel/cmdline

# Add this parameter to the end:
# usbcore.autosuspend=-1

# Save and reboot
reboot
```

Or do it all at once:
```bash
ssh root@tnfs1 'bash -s' <<'EOF'
# Add parameter if not already present
if ! grep -q "usbcore.autosuspend" /etc/kernel/cmdline; then
    echo "$(cat /etc/kernel/cmdline) usbcore.autosuspend=-1" > /etc/kernel/cmdline
    echo "✓ Parameter added. Reboot required."
    cat /etc/kernel/cmdline
else
    echo "Parameter already present"
fi
EOF
```

---

## Files Created for This Issue

| Script | Purpose | Location |
|--------|---------|----------|
| `proxmox_disable_coral_autosuspend.sh` | Quick fix for Proxmox host | `/divtools/scripts/frigate/` |
| `fix_coral_usb_autosuspend.sh` | Per-device autosuspend fix | `/divtools/scripts/frigate/` |
| `coral_watchdog.sh` | Auto-recovery monitoring service | `/divtools/scripts/frigate/` |
| `diagnostic_coral_usb.sh` | Comprehensive diagnostic tool | `/divtools/scripts/frigate/` |

---

## Testing Timeline

### ✓ Completed Tests
- [x] **11/11/2025 11:19 AM** - VM Diagnostic: Coral not visible, autosuspend=2
- [x] **11/11/2025 11:45 AM** - Disabled Proxmox host autosuspend (temporary)
- [x] **11/11/2025 11:50 AM** - Disabled VM autosuspend (temporary)
- [x] **11/11/2025 12:00 PM** - Set VM kernel parameter permanently via GRUB
- [x] **11/11/2025 12:15 PM** - **VM REBOOT TEST: ✓ SUCCESS - Coral now visible and working!**

### Next Steps
- [ ] Monitor VM for stability (target: 24-48 hours without disconnection)
- [ ] Once stable, update Proxmox host GRUB/kernel parameters
- [ ] Deploy auto-recovery watchdog service for extra safety

---

## Monitoring Commands

### Real-time Monitoring
```bash
# Watch Coral in lsusb
watch -n 2 'lsusb | grep 18d1'

# Watch Frigate for Coral errors
docker logs frigate -f | grep -E "coral|edgetpu|edgetpu.*error"

# Watch Frigate health status
watch -n 5 'docker ps --format "table {{.Names}}\t{{.Status}}"'
```

### Check Logs
```bash
# Frigate logs (last 50 lines)
docker logs frigate --tail 50 | grep -i coral

# Kernel logs (USB events)
ssh root@tnfs1 'dmesg | grep -i "usb.*4-6" | tail -20'
```

---

## Summary of the Fix

**The Coral was disconnecting because:**
- Linux kernel parameter `usbcore.autosuspend=2` caused USB ports to suspend after 2 seconds
- Coral TPU doesn't handle suspend/resume well and disconnects
- Once disconnected, Proxmox xHCI passthrough had trouble re-establishing the connection
- This created a loop of disconnection → Frigate crash → reconnect attempt → disconnection

**The fix:**
- Set `usbcore.autosuspend=-1` in kernel boot parameters
- This disables autosuspend for ALL USB devices (safer for real-time devices like Coral)
- Now applied to VM gpu1-75 and confirmed working ✓
- Still needs to be applied permanently to Proxmox host (currently temporary)

---

## Next: Deploy Auto-Recovery (Optional but Recommended)

Once you confirm 24-48 hours of stable operation, you can deploy the watchdog service:

```bash
cd /home/divix/divtools/scripts/frigate
sudo bash install_coral_recovery.sh
```

This will:
- Monitor for Coral disconnections
- Automatically attempt recovery
- Log all events for troubleshooting

---

**Last Updated:** November 11, 2025, 12:15 PM CST  
**Status:** ✓ VM Fix Applied and Tested  
**Next Test Date:** November 13, 2025 (48-hour stability check)
