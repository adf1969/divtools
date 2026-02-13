# Coral USB TPU - Complete File Index

## Location: `/home/divix/divtools/scripts/frigate/`

### 📋 DOCUMENTATION FILES (Read These First)

1. **EXECUTIVE_SUMMARY.md** ⭐ START HERE
   - High-level summary of issue and fix
   - Perfect for quick understanding
   - Contains timeline and status

2. **README_CORAL_FIX.md** ⭐ MAIN REFERENCE
   - Complete guide with all commands
   - Day-to-day operation procedures
   - Emergency recovery procedures

3. **MAINTENANCE_CHECKLIST.md** ⭐ FOR NEXT 48 HOURS
   - Step-by-step checklist for monitoring
   - Checkpoint dates and times
   - Emergency procedures

4. **CORAL_USB_SUMMARY.md**
   - Detailed summary with monitoring guide
   - Timeline of changes
   - Next steps and milestones

5. **CORAL_USB_QUICK_REFERENCE.md**
   - Quick lookup for common tasks
   - Troubleshooting guide
   - Command reference

6. **CORAL_USB_DIAGNOSTICS.md**
   - Diagnostic information and findings
   - Problem analysis
   - Root cause explanation

7. **TEST_REPORT_20251111.md**
   - Complete test report
   - Testing methodology
   - Findings and conclusions

### 🔧 UTILITY SCRIPTS (Run These)

1. **coral_status_check.sh** ⭐ RUN REGULARLY (every 6-12 hours)
   ```bash
   /home/divix/divtools/scripts/frigate/coral_status_check.sh
   ```
   - Quick health check
   - Verifies: autosuspend, Coral visible, Frigate healthy, no errors
   - Exit code 0 = all good, 1 = issues detected

2. **proxmox_disable_coral_autosuspend.sh** (Emergency Fix)
   ```bash
   ssh root@tnfs1 'bash /home/divix/divtools/scripts/frigate/proxmox_disable_coral_autosuspend.sh'
   ```
   - Quick fix if Coral disappears
   - Sets autosuspend=-1 on Proxmox host
   - Temporary (resets on reboot)

3. **diagnostic_coral_usb.sh**
   ```bash
   /home/divix/divtools/scripts/frigate/diagnostic_coral_usb.sh /tmp
   ```
   - Full diagnostic report
   - USB settings, power management, kernel logs
   - Save output for analysis

4. **proxmox_test_coral.sh**
   ```bash
   ssh root@tnfs1 'bash /home/divix/divtools/scripts/frigate/proxmox_test_coral.sh status'
   ```
   - Run tests on Proxmox host
   - Tests: status, disable-autosuspend, reset-coral, monitor

### 📁 ORIGINAL FRIGATE SCRIPTS (Already Existed)

- `fix_coral_usb_autosuspend.sh` - Disable per-device autosuspend
- `reset_coral_usb.sh` - Manual USB device reset
- `monitor_coral_tpu.sh` - Monitoring and recovery
- `dt_install_tpu_drivers.sh` - TPU driver installation

### 🔔 SERVICE FILES

- `coral_watchdog.service` - Systemd service (not yet deployed)
- `coral_watchdog.sh` - Auto-recovery daemon (not yet deployed)

---

## Quick Start Commands

### Check Status (Do This Regularly)
```bash
/home/divix/divtools/scripts/frigate/coral_status_check.sh
```

### If Coral is Disconnected (Emergency)
```bash
ssh root@tnfs1 'bash /home/divix/divtools/scripts/frigate/proxmox_disable_coral_autosuspend.sh'
```

### View System Status
```bash
# Check autosuspend setting
cat /sys/module/usbcore/parameters/autosuspend

# Check if Coral is visible
lsusb | grep 18d1

# Check Frigate status
docker ps --filter name=frigate

# View Frigate logs (Coral section)
docker logs frigate --since 1h | grep -i coral
```

---

## 48-Hour Monitoring Timeline

**Start Date**: November 11, 2025 ~12:15 PM (after VM reboot)

- [ ] **6 hours** (11/11 ~6:15 PM) - Run status check ✓
- [ ] **12 hours** (11/12 ~12:15 AM) - Run status check ✓
- [ ] **24 hours** (11/12 ~12:15 PM) - Run status check ✓
- [ ] **36 hours** (11/13 ~12:15 AM) - Run status check ✓
- [ ] **48 hours** (11/13 ~12:15 PM) - Run status check ✓
  - **IF ALL PASS**: Proceed with permanent Proxmox host fix

---

## Next Major Milestone

### After 48-Hour Test Passes (November 13)

Make fix permanent on Proxmox host:

1. Edit kernel parameters:
   ```bash
   ssh root@tnfs1 'nano /etc/kernel/cmdline'
   # Add at the end: usbcore.autosuspend=-1
   ```

2. Or use one-liner:
   ```bash
   ssh root@tnfs1 'echo "$(cat /etc/kernel/cmdline) usbcore.autosuspend=-1" > /etc/kernel/cmdline'
   ```

3. Reboot Proxmox host:
   ```bash
   ssh root@tnfs1 'reboot'
   ```

4. Verify after reboot:
   ```bash
   ssh root@tnfs1 'cat /sys/module/usbcore/parameters/autosuspend'
   # Should show: -1
   ```

---

## File Organization Summary

```
/home/divix/divtools/scripts/frigate/
├── 📋 Documentation (7 files)
│   ├── EXECUTIVE_SUMMARY.md ⭐
│   ├── README_CORAL_FIX.md ⭐
│   ├── MAINTENANCE_CHECKLIST.md ⭐
│   ├── CORAL_USB_SUMMARY.md
│   ├── CORAL_USB_QUICK_REFERENCE.md
│   ├── CORAL_USB_DIAGNOSTICS.md
│   └── TEST_REPORT_20251111.md
│
├── 🔧 New Scripts (4 files)
│   ├── coral_status_check.sh ⭐
│   ├── proxmox_disable_coral_autosuspend.sh ⭐
│   ├── diagnostic_coral_usb.sh
│   ├── proxmox_test_coral.sh
│   ├── proxmox_coral_reset.sh
│   ├── test_coral_fixes.sh
│   └── install_coral_recovery.sh
│
├── 🔔 Service Files (2 files)
│   ├── coral_watchdog.service
│   └── coral_watchdog.sh
│
└── Original Scripts (pre-existing)
    ├── fix_coral_usb_autosuspend.sh
    ├── reset_coral_usb.sh
    ├── monitor_coral_tpu.sh
    └── ... (others)
```

---

## Important Notes

⚠️ **DO NOT EDIT GRUB SETTINGS AGAIN** - Already done and working

✓ **DO MONITOR** - Run status check every 6-12 hours for next 48 hours

✓ **DO APPLY PROXMOX FIX** - After 48-hour test passes, make permanent

⚠️ **DO NOT PANIC** - If Coral disappears, run emergency fix script

---

## Status Summary

| Component | Status | Last Verified |
|-----------|--------|---------------|
| VM Fix Applied | ✓ Working | 11/11 11:52 AM |
| Coral Device | ✓ Visible | 11/11 11:52 AM |
| Frigate Status | ✓ Healthy | 11/11 11:52 AM |
| Recent Errors | ✓ None | 11/11 11:52 AM |
| 48-Hour Test | ⏳ In Progress | Started 11/11 12:15 PM |
| Proxmox Fix | ⏳ Pending | To apply 11/13 (after test) |

---

**Created**: November 11, 2025  
**Status**: Active - In 48-hour monitoring phase  
**Next Review**: Every 6-12 hours  
**Target Completion**: November 13, 2025 12:15 PM
