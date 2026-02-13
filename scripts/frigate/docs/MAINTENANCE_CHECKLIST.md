# Coral USB TPU Maintenance Checklist

## Quick Start: Today (November 11, 2025)

- [x] Identified root cause: `usbcore.autosuspend=2`
- [x] Applied temporary fix to Proxmox host (manual)
- [x] Applied permanent fix to VM (GRUB parameter)
- [x] Rebooted VM to test fix
- [x] ✓ **Coral is now visible and working**
- [x] Created recovery scripts
- [x] Created monitoring tools

**Status**: System operational, Coral working ✓

---

## Monitoring: Next 48 Hours

**Goal**: Confirm 48 hours of stable operation without disconnections

Every 6-12 hours, run:
```bash
/home/divix/divtools/scripts/frigate/coral_status_check.sh
```

Or manually check:
```bash
# All these should show success:
cat /sys/module/usbcore/parameters/autosuspend      # Should be: -1
lsusb | grep 18d1                                     # Should show device
docker ps --filter name=frigate                       # Should show: Up
docker logs frigate --since 1h | grep -i coral        # Should be empty (no errors)
```

**Checkpoint Dates**:
- [ ] 6 hours after reboot (11/11 ~6:15 PM) - Run status check
- [ ] 12 hours after reboot (11/12 ~12:15 AM) - Run status check  
- [ ] 24 hours after reboot (11/12 ~12:15 PM) - Run status check
- [ ] 36 hours after reboot (11/13 ~12:15 AM) - Run status check
- [ ] 48 hours after reboot (11/13 ~12:15 PM) - **TEST COMPLETE IF ALL PASS**

---

## After 48-Hour Test Passes (November 13)

If all checks pass for 48 hours:

```bash
# 1. Make fix permanent on Proxmox host
ssh root@tnfs1 'bash -s' <<'EOF'
if ! grep -q "usbcore.autosuspend" /etc/kernel/cmdline; then
    echo "$(cat /etc/kernel/cmdline) usbcore.autosuspend=-1" > /etc/kernel/cmdline
    echo "✓ Parameter added. Proxmox host reboot required."
fi
EOF

# 2. Reboot Proxmox host at convenient time
ssh root@tnfs1 'shutdown -r +120 "Applying Coral USB fix"'

# 3. After reboot, verify:
ssh root@tnfs1 'echo "Autosuspend: $(cat /sys/module/usbcore/parameters/autosuspend)"'
```

---

## Emergency Procedures

### If Coral Disconnects During 48-Hour Test

```bash
# 1. Check current status
lsusb | grep 18d1

# 2. If not found, run emergency fix on Proxmox host
ssh root@tnfs1 'echo "-1" > /sys/module/usbcore/parameters/autosuspend'

# 3. Wait 5 seconds
sleep 5

# 4. Verify it's back
lsusb | grep 18d1

# 5. If still not visible, use the script
ssh root@tnfs1 'bash /home/divix/divtools/scripts/frigate/proxmox_disable_coral_autosuspend.sh'

# 6. Log the event
echo "$(date): Coral disconnection event" >> /tmp/coral_events.log
```

### If Frigate Won't Start

```bash
# Restart container
docker restart frigate

# Wait 10 seconds
sleep 10

# Check logs
docker logs frigate --tail 50 | grep -i coral
```

### If Everything is Broken

```bash
# 1. Quick recovery on Proxmox host
ssh root@tnfs1 'bash /home/divix/divtools/scripts/frigate/proxmox_disable_coral_autosuspend.sh'

# 2. Restart Frigate
docker restart frigate

# 3. Monitor recovery
watch -n 2 'lsusb | grep 18d1 && echo "✓ Found" || echo "✗ Missing"'
```

---

## Reference: Created Files

### Scripts
- `/home/divix/divtools/scripts/frigate/coral_status_check.sh` - Use for periodic checks
- `/home/divix/divtools/scripts/frigate/proxmox_disable_coral_autosuspend.sh` - Use for emergency fixes
- `/home/divix/divtools/scripts/frigate/diagnostic_coral_usb.sh` - Full diagnostics

### Documentation  
- `/home/divix/divtools/scripts/frigate/README_CORAL_FIX.md` - Complete guide
- `/home/divix/divtools/scripts/frigate/CORAL_USB_SUMMARY.md` - Summary & monitoring
- `/home/divix/divtools/scripts/frigate/CORAL_USB_QUICK_REFERENCE.md` - Quick reference
- `/home/divix/divtools/scripts/frigate/TEST_REPORT_20251111.md` - Test results
- `/home/divix/divtools/scripts/frigate/CORAL_USB_DIAGNOSTICS.md` - Diagnostic info

---

## Key Commands Reference

```bash
# Status check
/home/divix/divtools/scripts/frigate/coral_status_check.sh

# Emergency fix
ssh root@tnfs1 'bash /home/divix/divtools/scripts/frigate/proxmox_disable_coral_autosuspend.sh'

# Manual fix (if script doesn't work)
ssh root@tnfs1 'echo "-1" > /sys/module/usbcore/parameters/autosuspend'

# Check current autosuspend
cat /sys/module/usbcore/parameters/autosuspend

# Check Coral visible
lsusb | grep 18d1

# Check Frigate
docker ps --filter name=frigate --format "{{.Status}}"

# Restart Frigate
docker restart frigate

# View Frigate logs
docker logs frigate -f | grep -i coral

# View kernel log (Proxmox)
ssh root@tnfs1 'dmesg | grep 18d1 | tail -10'
```

---

## Success Criteria

The fix is confirmed working when:
- ✓ Autosuspend disabled (value = -1)
- ✓ Coral device visible in lsusb
- ✓ Frigate container running and healthy
- ✓ No Coral errors in logs for 24+ hours
- ✓ 48+ hours without disconnection

---

## If Issues Persist After 48 Hours

If the Coral still disconnects after all fixes are applied:

1. Consider hardware issue with USB port or cable
2. Try different USB port on Proxmox host
3. Consider upgrading to PCIe Coral instead of USB
4. Review Proxmox BIOS settings for xHCI power management

---

## Contact/Support

If you need to troubleshoot:

1. Check `/home/divix/divtools/scripts/frigate/README_CORAL_FIX.md`
2. Run diagnostic: `/home/divix/divtools/scripts/frigate/diagnostic_coral_usb.sh /tmp`
3. Review test results: `/home/divix/divtools/scripts/frigate/TEST_REPORT_20251111.md`

---

**Setup Date**: November 11, 2025  
**VM**: gpu1-75  
**Host**: tnfs1  
**Device**: Coral USB TPU (18d1:9302)  
**Status**: Working ✓  
**Last Update**: 11/11/2025 11:52 AM
