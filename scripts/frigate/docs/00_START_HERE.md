# 🚀 START HERE - Coral USB TPU Fix

## What Happened?

Your Coral USB TPU on VM gpu1-75 was disconnecting every 2-10 minutes because the kernel was suspending the USB port after 2 seconds of inactivity.

## What's Fixed?

✓ **Issue Identified**: `usbcore.autosuspend=2` causes USB port to suspend  
✓ **Fix Applied**: Changed to `usbcore.autosuspend=-1` (never suspend)  
✓ **VM Test**: ✓ WORKING - Coral now visible and Frigate healthy  
✓ **Status**: Confirmed working as of 11/11/2025 11:52 AM

## What You Need to Do

### Right Now (Next 6 hours)
Nothing - system is working fine!

### Next 48 Hours (11/11 - 11/13)
Run this command every 6-12 hours to verify stability:
```bash
/home/divix/divtools/scripts/frigate/coral_status_check.sh
```

### After 48 Hours (11/13)
If all checks pass, make the fix permanent on Proxmox host:
```bash
ssh root@tnfs1 'echo "$(cat /etc/kernel/cmdline) usbcore.autosuspend=-1" > /etc/kernel/cmdline'
ssh root@tnfs1 'reboot'
```

## If Something Goes Wrong

**If Coral disconnects:**
```bash
ssh root@tnfs1 'bash /home/divix/divtools/scripts/frigate/proxmox_disable_coral_autosuspend.sh'
```

**Quick manual fix:**
```bash
ssh root@tnfs1 'echo "-1" > /sys/module/usbcore/parameters/autosuspend'
```

## Documentation

- **EXECUTIVE_SUMMARY.md** - High-level overview
- **README_CORAL_FIX.md** - Complete reference guide  
- **MAINTENANCE_CHECKLIST.md** - 48-hour monitoring checklist
- **FILE_INDEX.md** - Index of all files
- **CORAL_USB_QUICK_REFERENCE.md** - Troubleshooting quick reference

All files in: `/home/divix/divtools/scripts/frigate/`

## Key Files Changed

**On VM (gpu1-75):**
```
/etc/default/grub
GRUB_CMDLINE_LINUX="usbcore.autosuspend=-1"
```
Status: ✓ PERMANENT (already applied and tested)

**On Proxmox Host (tnfs1):**
```
/etc/kernel/cmdline
(needs: usbcore.autosuspend=-1)
```
Status: ⏳ TEMPORARY (will apply after 48-hour test)

## Monitoring Checklist

- [ ] **6 hours**  (11/11 ~6:15 PM)   - Run status check
- [ ] **12 hours** (11/12 ~12:15 AM)  - Run status check
- [ ] **24 hours** (11/12 ~12:15 PM)  - Run status check
- [ ] **36 hours** (11/13 ~12:15 AM)  - Run status check
- [ ] **48 hours** (11/13 ~12:15 PM)  - Run status check → IF PASS, apply Proxmox fix

## Success = This Always Shows

```
✓ Autosuspend disabled (-1)
✓ Coral device visible (lsusb)
✓ Frigate running (healthy)
✓ No recent errors
```

## Questions?

Read the comprehensive guides in `/home/divix/divtools/scripts/frigate/`

---

**Created**: November 11, 2025  
**Status**: ✓ WORKING  
**Next Action**: Monitor for 48 hours, then apply Proxmox host fix
