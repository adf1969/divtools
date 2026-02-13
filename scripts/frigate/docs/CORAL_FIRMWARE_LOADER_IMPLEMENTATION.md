# Coral TPU Firmware Loader - Implementation Summary

**Created:** November 30, 2025

## Files Created

| File | Purpose | Size |
|------|---------|------|
| `coral_firmware_loader.sh` | Main VM boot script (self-installing) | 20 KB |
| `test_coral_transition.sh` | Educational test to understand device behavior | 10 KB |
| `docs/CORAL_FIRMWARE_LOADER.md` | Comprehensive integration guide | 5.8 KB |
| `docs/CORAL_FIRMWARE_LOADER_QUICK_REF.md` | Quick reference cheat sheet | 4.4 KB |

**Location:** `/home/divix/divtools/scripts/frigate/`

## Problem We're Solving

Your Coral USB TPU shows up as two different device IDs depending on firmware state:

- **`1a6e:089a`** = Bootloader mode (device just powered on, not ready)
- **`18d1:9302`** = Operational mode (firmware loaded, ready for use)

**The Issue:** On boot, the device appears as `089a` first. If Frigate starts before it transitions to `9302`, Frigate crashes with libusb errors. After 5-10 seconds, the device transitions and Frigate works—but you get a crash period.

**The Solution:** Run `coral_firmware_loader.sh` at VM boot to:
1. Check if device is operational (`9302`)
2. If not, trigger udev rules to load firmware
3. Wait for device to transition (usually 5-10 seconds)
4. Exit only when device is ready
5. Allow systemd to proceed with Frigate and other services

## Quick Installation

### On Your VM (gpu1-1 / NAS1-1):

```bash
# Copy from Proxmox host
scp /home/divix/divtools/scripts/frigate/coral_firmware_loader.sh \
    root@<your-vm-ip>:/tmp/

# Install with one command
ssh root@<your-vm-ip> "cd /tmp && sudo bash coral_firmware_loader.sh --install"

# Reboot to test
ssh root@<your-vm-ip> sudo reboot
```

Or manually copy the script content to `/usr/local/bin/` on your VM and run:
```bash
sudo /usr/local/bin/coral_firmware_loader.sh --install
```

### What `--install` Does

1. ✅ Copies script to `/usr/local/bin/coral_firmware_loader.sh`
2. ✅ Creates systemd service at `/etc/systemd/system/coral-firmware-loader.service`
3. ✅ Enables service to run at boot (before multi-user.target)
4. ✅ Creates config directory at `/etc/coral-tpu/`
5. ✅ Reloads systemd daemon

**Result:** Next time VM boots, device will be in `9302` mode BEFORE Frigate starts.

## Verification

### Immediately after installation:

```bash
# Check service status
sudo systemctl status coral-firmware-loader

# View what it did
sudo journalctl -u coral-firmware-loader -n 30 --follow

# Manual test
/usr/local/bin/coral_firmware_loader.sh -status
```

### After rebooting VM:

```bash
# Device should be present
lsusb -d 18d1:9302

# No errors in Frigate
docker logs frigate | grep -i "tpu\|coral\|edge"

# Systemd logs should show success
sudo journalctl -u coral-firmware-loader | tail -5
```

## How It Works (Technical Details)

### The Device Transition Process

```
BOOT SEQUENCE:
──────────────────────────────────────────────────────────────────────
Time  Event
──────────────────────────────────────────────────────────────────────
T+0s  VM boots
      └─ Proxmox USB passthrough attaches Coral
      
T+1s  Device enumerates as 1a6e:089a (bootloader mode)
      └─ Device is present but firmware NOT loaded
      
T+2s  systemd starts coral-firmware-loader.service
      └─ Script detects 089a state
      
T+3s  Script triggers udev rules
      └─ udev runs libedgetpu firmware loader
      
T+4s  Firmware transfer begins (~2-3 MB file)
      
T+7s  Device re-enumerates as 18d1:9302 (operational)
      └─ Firmware successfully loaded
      
T+8s  Script detects 9302, exits with success
      └─ systemd marks service as "Started"
      
T+8s  systemd starts Frigate and Docker
      └─ Frigate finds TPU ready immediately
      
T+10s Frigate is fully initialized, no crashes
──────────────────────────────────────────────────────────────────────
```

### Without the firmware loader:

```
PROBLEMATIC SEQUENCE:
──────────────────────────────────────────────────────────────────────
T+1s  Device enumerates as 1a6e:089a
      
T+2s  systemd starts Frigate immediately
      └─ Frigate tries to initialize TPU
      
T+2-8s  Frigate crashes repeatedly
      └─ libusb transfer errors
      └─ EdgeTPU not found
      
T+8s  Device finally transitions to 9302
      
T+10s  Frigate restarts, works correctly
──────────────────────────────────────────────────────────────────────
```

## Script Features

### Built-in Installation (`--install`)
```bash
sudo coral_firmware_loader.sh --install
# Copies itself to /usr/local/bin
# Creates systemd service
# Enables automatic boot
```

### Status Checking (`-status`)
```bash
./coral_firmware_loader.sh -status
# Returns 0 if 9302 present
# Returns 1 if not found
# Shows what state device is in
```

### Manual Firmware Load (`-force-reload`)
```bash
sudo ./coral_firmware_loader.sh -force-reload
# Trigger udev rules manually
# Wait for device transition
```

### Debug Mode (`-debug -verbose`)
```bash
sudo ./coral_firmware_loader.sh -debug -verbose
# Show all checks and decisions
# Useful for troubleshooting
```

### Test Mode (`-test`)
```bash
./coral_firmware_loader.sh -test
# Show what would happen
# No actual changes made
```

## Systemd Service Details

The installed systemd unit runs:
- **When:** At boot, before `multi-user.target`
- **Type:** `oneshot` (runs once and exits)
- **Timeout:** 120 seconds (allows up to 2 minutes for device)
- **Logs:** Captured by systemd journal
- **Command:** `/usr/local/bin/coral_firmware_loader.sh`

**View logs:**
```bash
sudo journalctl -u coral-firmware-loader -n 50 --follow
```

## Integration with Frigate

### Option 1: Systemd Dependency (If Frigate has systemd unit)

Edit `/etc/systemd/system/frigate.service`:
```ini
[Unit]
...
After=coral-firmware-loader.service
...
```

Then:
```bash
sudo systemctl daemon-reload
sudo systemctl restart frigate
```

### Option 2: Docker Compose (Simplest)

If using Docker Compose, just add a short boot delay:
```yaml
frigate:
  container_name: frigate
  image: ghcr.io/blakeblackshear/frigate:stable
  
  # Add 10-second delay to allow firmware loader to finish
  command: sh -c "sleep 10 && /init"
```

Or use a health check:
```yaml
frigate:
  healthcheck:
    test: lsusb -d 18d1:9302 > /dev/null 2>&1
    interval: 5s
    timeout: 3s
    retries: 60  # Wait up to 5 minutes
```

### Option 3: No Special Setup (Recommended)

If systemd service is installed, just reboot. The service runs automatically before other services start. Frigate will "just work."

## Device ID Reference

| ID | Name | Status | Use |
|----|------|--------|-----|
| `1a6e:089a` | Bootloader | 🔴 Not Ready | Device just powered on |
| `18d1:9302` | Operational | 🟢 Ready | Device ready for TPU |

**In Proxmox passthrough config, pass BOTH:**
```
usb0: host=1a6e:089a,usb3=1
usb1: host=18d1:9302,usb3=1
```

This way the VM can handle the device in either state.

## Troubleshooting

### Device times out (not transitioning from 089a to 9302)

**Symptoms:**
- Script waits 60 seconds then times out
- Device never shows as `18d1:9302`

**Check:**
```bash
# On Proxmox host
qm config 275 | grep usb

# On VM, check dmesg
dmesg -e | grep -i "usb\|coral" | tail -10

# Check if firmware files exist on Proxmox
dpkg -l | grep libedgetpu
```

**Solutions:**
- Ensure powered USB hub is used and properly powered
- Verify both device IDs are in Proxmox USB passthrough config
- Check host dmesg for USB enumeration errors
- Try moving to a different USB 3.0 port

### Device not found at all

**Symptoms:**
- Script reports "Coral TPU not found"
- `lsusb` never shows either `089a` or `9302`

**Check:**
```bash
# Verify passthrough is configured
qm config 275 | grep usb

# Check host dmesg
dmesg -e | grep -E "(1a6e:089a|18d1:9302|Coral)"

# Check USB bus on host
lsusb | grep -E "(1a6e|18d1)"
```

**Solutions:**
- Verify Coral is connected to powered USB hub
- Check powered hub is plugged in and powered
- Verify Proxmox sees device: `lsusb` on host
- Try different USB 3.0 port on host
- Power cycle Coral (unplug and replug from hub)

### Permissions denied error

**Symptoms:**
```
ERROR: Permission denied
Please run: sudo ./coral_firmware_loader.sh
```

**Solutions:**
```bash
# Run with sudo
sudo ./coral_firmware_loader.sh -status

# Or, after installation, use systemd
sudo systemctl start coral-firmware-loader
```

## Test Script

A companion test script is included to understand device behavior:

```bash
/home/divix/divtools/scripts/frigate/test_coral_transition.sh
```

This script:
- Shows current device state (bootloader vs operational)
- Monitors the transition in real-time
- Explains what's happening at each phase
- Educational tool for understanding the process

## Files Reference

| File | Purpose |
|------|---------|
| `coral_firmware_loader.sh` | Main installation script (copy to VM) |
| `test_coral_transition.sh` | Educational test tool |
| `docs/CORAL_FIRMWARE_LOADER.md` | Full integration guide |
| `docs/CORAL_FIRMWARE_LOADER_QUICK_REF.md` | Quick cheat sheet |
| `docs/CORAL_RECOVERY_ARCHITECTURE.md` | Overall recovery architecture (existing) |

## Next Steps

1. **Copy script to VM:**
   ```bash
   scp coral_firmware_loader.sh root@<vm-ip>:/tmp/
   ```

2. **Install on VM:**
   ```bash
   ssh root@<vm-ip> "sudo /tmp/coral_firmware_loader.sh --install"
   ```

3. **Reboot to test:**
   ```bash
   ssh root@<vm-ip> sudo reboot
   ```

4. **Verify:**
   ```bash
   ssh root@<vm-ip> "sudo systemctl status coral-firmware-loader && lsusb -d 18d1:9302"
   ```

5. **Check Frigate:**
   ```bash
   docker logs frigate | grep -i "tpu\|coral\|success" | head -20
   ```

## Questions?

- **Script help:** `./coral_firmware_loader.sh --help`
- **Full guide:** Read `CORAL_FIRMWARE_LOADER.md`
- **Quick ref:** Check `CORAL_FIRMWARE_LOADER_QUICK_REF.md`
- **Test device:** Run `test_coral_transition.sh`

---

**Status:** ✅ Ready to use  
**Location:** `/home/divix/divtools/scripts/frigate/`  
**Last Updated:** November 30, 2025
