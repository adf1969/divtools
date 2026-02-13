# Coral USB TPU Fix - Summary & Quick Reference

## ✓ FIX VERIFIED WORKING (11/11/2025)

Your Coral USB TPU issue has been **identified, diagnosed, and fixed**.

### What Was Wrong
- USB autosuspend was set to 2 seconds on both VM and Proxmox host
- After 2 seconds of inactivity, the Coral device would be suspended
- When suspended, the USB connection was lost and Frigate crashed

### What Was Fixed
- **VM (gpu1-75)**: Kernel parameter `usbcore.autosuspend=-1` added to `/etc/default/grub`
- **Proxmox host (tnfs1)**: Temporarily set to `-1` via shell command
- **Result**: ✓ Coral now visible in VM, Frigate running healthy

---

## Quick Status Check

Run this anytime to verify everything is working:

```bash
/home/divix/divtools/scripts/frigate/coral_status_check.sh
```

This checks:
- ✓ Autosuspend disabled
- ✓ Coral device visible
- ✓ Frigate running
- ✓ No recent errors

---

## If Coral Ever Disconnects Again

Quick recovery (run on Proxmox host):
```bash
ssh root@tnfs1 'echo "-1" > /sys/module/usbcore/parameters/autosuspend'
```

Or use the script:
```bash
ssh root@tnfs1 'bash /home/divix/divtools/scripts/frigate/proxmox_disable_coral_autosuspend.sh'
```

Then verify it came back:
```bash
lsusb | grep 18d1
docker logs frigate -f | grep coral
```

---

## Next: 48-Hour Stability Test

The fix has been applied and tested. Now monitor for **48 hours** to ensure stability.

Check periodically:
```bash
# Every 6-12 hours, run:
/home/divix/divtools/scripts/frigate/coral_status_check.sh

# If all 4 checks pass for 48 hours → fix is confirmed working ✓
```

---

## After 48 Hours: Make Proxmox Host Fix Permanent

Once you confirm 2 days of stable operation:

```bash
# Add parameter to Proxmox kernel boot configuration
ssh root@tnfs1 'bash -s' <<'EOF'
if ! grep -q "usbcore.autosuspend" /etc/kernel/cmdline; then
    echo "$(cat /etc/kernel/cmdline) usbcore.autosuspend=-1" > /etc/kernel/cmdline
    echo "✓ Parameter added. Reboot required."
fi
EOF
```

Then reboot the Proxmox host at a convenient time.

---

## Files Created for This Issue

All in `/home/divix/divtools/scripts/frigate/`:

| File | Purpose |
|------|---------|
| `coral_status_check.sh` | Quick health check (run this regularly) |
| `proxmox_disable_coral_autosuspend.sh` | Emergency fix for Proxmox host |
| `CORAL_USB_SUMMARY.md` | Detailed summary & monitoring guide |
| `CORAL_USB_QUICK_REFERENCE.md` | Quick reference for troubleshooting |
| `TEST_REPORT_20251111.md` | Full test report with findings |
| `CORAL_USB_DIAGNOSTICS.md` | Diagnostic information |
| `diagnostic_coral_usb.sh` | Run full diagnostics if needed |

---

## Current System Status

```
VM (gpu1-75):
  ✓ Autosuspend disabled via GRUB kernel parameter (PERMANENT)
  ✓ Coral device visible: Bus 012 Device 002
  ✓ Frigate running and healthy
  ✓ No recent errors

Proxmox Host (tnfs1):
  ✓ Autosuspend disabled via shell (TEMPORARY - resets on reboot)
  ⏳ Needs permanent fix in kernel parameters (TODO after 48-hour test)
```

---

## Monitoring Checklist (Next 48 Hours)

- [ ] **6 hours**: Run status check, verify all 4 checks pass
- [ ] **12 hours**: Run status check, verify all 4 checks pass
- [ ] **24 hours**: Run status check, verify all 4 checks pass
- [ ] **36 hours**: Run status check, verify all 4 checks pass
- [ ] **48 hours**: Run status check, verify all 4 checks pass

If all pass, proceed with permanent fix on Proxmox host.

---

## Command Reference

```bash
# Check status
/home/divix/divtools/scripts/frigate/coral_status_check.sh

# Watch for disconnections
watch -n 2 'lsusb | grep 18d1 || echo "DISCONNECTED"'

# Check current autosuspend setting
cat /sys/module/usbcore/parameters/autosuspend  # Should be -1

# View Frigate logs (Coral section)
docker logs frigate --since 1h | grep -i "coral\|edgetpu"

# Check Frigate status
docker ps --filter name=frigate --format "table {{.Status}}"

# Emergency fix on Proxmox host
ssh root@tnfs1 'bash /home/divix/divtools/scripts/frigate/proxmox_disable_coral_autosuspend.sh'
```

---

## What NOT to Do

❌ Don't manually disable USB power management per-device - the kernel parameter is cleaner  
❌ Don't restart Frigate unless necessary - the Coral should stay connected now  
❌ Don't reboot Proxmox host yet - wait for 48-hour test to pass first  

---

## Timeline

- **11/11/2025 11:19 AM** - Issue identified: autosuspend=2 causes disconnections
- **11/11/2025 11:50 AM** - Temporary fixes applied to both VM and host
- **11/11/2025 12:00 PM** - Permanent fix added to VM kernel parameters
- **11/11/2025 12:15 PM** - **VM REBOOT: Fix verified working ✓**
- **11/13/2025** - 48-hour stability test target
- **11/13/2025** - Apply permanent fix to Proxmox host (if test passes)

---

## Support

If issues arise during the 48-hour test:

1. Run diagnostic:
   ```bash
   /home/divix/divtools/scripts/frigate/diagnostic_coral_usb.sh /tmp
   cat /tmp/coral_diagnostics_gpu1-75_*.txt
   ```

2. Check host status:
   ```bash
   ssh root@tnfs1 '/home/divix/divtools/scripts/frigate/proxmox_test_coral.sh status'
   ```

3. Apply emergency fix:
   ```bash
   ssh root@tnfs1 'bash /home/divix/divtools/scripts/frigate/proxmox_disable_coral_autosuspend.sh'
   ```

---

**Status**: ✓ WORKING  
**Last Test**: 11/11/2025 11:52 AM  
**Next Review**: In 6 hours  
**Current Uptime**: Counting toward 48-hour goal
