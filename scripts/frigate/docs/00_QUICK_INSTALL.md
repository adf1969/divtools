# QUICK DEPLOYMENT - Copy & Paste Instructions

## TL;DR Install (5 minutes)

### On Proxmox Host (tnfs1)

**Find your VM IP:**
```bash
# Your VM is probably gpu1-75 or NAS1-1
# Get its IP (replace xxx with VM number if different)
qm guest cmd 275 network-get-interfaces | grep -E "ipv4|ip-" | head -5
```

### Copy Script to VM

```bash
scp /home/divix/divtools/scripts/frigate/coral_firmware_loader.sh \
    root@<YOUR_VM_IP>:/tmp/
```

### On VM (ssh into it)

```bash
ssh root@<YOUR_VM_IP>

# Now on VM, run these commands:
cd /tmp
sudo bash coral_firmware_loader.sh --install
sudo reboot
```

### After Reboot

```bash
# SSH back in after reboot finishes
ssh root@<YOUR_VM_IP>

# Verify
sudo systemctl status coral-firmware-loader
sudo journalctl -u coral-firmware-loader -n 20
lsusb -d 18d1:9302
docker logs frigate | grep -i "tpu\|coral" | head -10
```

**That's it! Device should be stable now.**

---

## If You Need Help

**Check device status:**
```bash
# On VM
sudo /usr/local/bin/coral_firmware_loader.sh -status
```

**View full logs:**
```bash
# On VM
sudo journalctl -u coral-firmware-loader --follow
```

**Uninstall (if needed):**
```bash
# On VM
sudo /usr/local/bin/coral_firmware_loader.sh --uninstall
```

**See what it does:**
```bash
# On VM
/usr/local/bin/coral_firmware_loader.sh --help
```

---

## What's Actually Happening?

**Your Problem:** Coral USB shows as `1a6e:089a` (bootloader) on boot, then switches to `18d1:9302` (operational) after 5-10 seconds. Frigate crashes if it starts before the switch.

**The Fix:** This script waits for the switch to happen, THEN lets Frigate start. No more crashes.

**How it works:**
1. VM boots, Coral appears as `089a`
2. systemd runs this script
3. Script triggers udev firmware load
4. Device switches to `9302` (~5-10 seconds)
5. Script exits
6. Frigate starts (device is ready)

---

## Questions?

- **Full documentation:** Read `scripts/frigate/docs/CORAL_FIRMWARE_LOADER.md`
- **Quick reference:** Read `scripts/frigate/docs/CORAL_FIRMWARE_LOADER_QUICK_REF.md`
- **Hub visibility:** Read `scripts/frigate/docs/CORAL_POWERED_HUB_VISIBILITY.md`
- **Test transitions:** Run `scripts/frigate/test_coral_transition.sh` on VM

---

**Created:** November 30, 2025  
**Location:** `/home/divix/divtools/scripts/frigate/`
