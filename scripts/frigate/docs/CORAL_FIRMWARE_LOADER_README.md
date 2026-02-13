# Coral TPU Firmware Loader - Complete Package

**Created:** November 30, 2025  
**Status:** ✅ Ready to deploy

## Package Contents

### Executable Scripts

1. **`coral_firmware_loader.sh`** (20 KB, executable)
   - Main VM boot script with `--install` support
   - Ensures Coral transitions from bootloader (1a6e:089a) to operational (18d1:9302)
   - Self-installing: copies itself to `/usr/local/bin/` and creates systemd service
   - Can be run manually or automatically at boot
   - Features: `-status`, `-force-reload`, `-debug`, `-verbose`, `-test` flags

2. **`test_coral_transition.sh`** (10 KB, executable)
   - Educational tool to understand device state transitions
   - Monitors 089a → 9302 transition in real-time
   - Shows what's happening at each phase
   - Great for learning and troubleshooting

### Documentation

1. **`CORAL_FIRMWARE_LOADER_IMPLEMENTATION.md`** (Summary guide)
   - Overview of the solution
   - Installation instructions
   - Technical details of how it works
   - Troubleshooting guide

2. **`CORAL_FIRMWARE_LOADER.md`** (Comprehensive guide)
   - Complete usage documentation
   - Integration options with Frigate
   - Detailed troubleshooting
   - VM-level and systemd configuration

3. **`CORAL_FIRMWARE_LOADER_QUICK_REF.md`** (Cheat sheet)
   - TL;DR version
   - Quick commands
   - Exit codes
   - Common issues and fixes

4. **`CORAL_POWERED_HUB_VISIBILITY.md`** (Hub reference)
   - Explains why hub is "invisible" to VM
   - Shows what's visible at different layers
   - Hub troubleshooting checklist
   - Connection verification commands

## The Problem

Your Coral TPU USB has **two device IDs**:
- `1a6e:089a` = Bootloader (firmware not loaded, device not ready)
- `18d1:9302` = Operational (firmware loaded, device ready)

On VM boot, device appears as `089a` first. If Frigate starts too early, it crashes. After 5-10 seconds, device transitions to `9302` and Frigate works.

## The Solution

This package provides a **VM-side boot script** that:
1. Detects if Coral is in bootloader mode
2. Triggers udev rules to load firmware
3. Waits for device to transition to operational mode
4. Exits only when device is ready
5. Allows Frigate and other services to start safely

## Quick Start

### Step 1: Copy Script to VM
```bash
scp /home/divix/divtools/scripts/frigate/coral_firmware_loader.sh \
    root@<your-vm-ip>:/tmp/
```

### Step 2: Install on VM
```bash
ssh root@<your-vm-ip>
cd /tmp
sudo bash coral_firmware_loader.sh --install
```

The `--install` flag:
- Copies script to `/usr/local/bin/`
- Creates systemd service unit
- Enables automatic boot
- Reloads systemd daemon

### Step 3: Reboot to Verify
```bash
sudo reboot

# After reboot, check status
sudo systemctl status coral-firmware-loader
sudo journalctl -u coral-firmware-loader -n 30

# Verify device is ready
lsusb -d 18d1:9302
```

### Step 4: Check Frigate
```bash
# Should not show EdgeTPU initialization errors
docker logs frigate | grep -i "tpu\|coral" | head -20
```

## Usage Examples

### Check Status Anytime
```bash
./coral_firmware_loader.sh -status
# Exit code 0 = device ready
# Exit code 1 = device not ready
```

### Manual Firmware Load
```bash
sudo ./coral_firmware_loader.sh -force-reload
```

### Debug Mode
```bash
sudo ./coral_firmware_loader.sh -debug -verbose
```

### Test Mode (Safe, No Changes)
```bash
./coral_firmware_loader.sh -test
```

### Learn About Device Transitions
```bash
./test_coral_transition.sh
```

### View Help
```bash
./coral_firmware_loader.sh --help
```

## How It Works

### Device ID Transition Explained

```
BOOTLOADER (1a6e:089a)
    ↓ [Udev firmware load triggered]
    ↓ [Firmware transferred via USB]
    ↓ [Device re-enumerates]
OPERATIONAL (18d1:9302)
```

### Boot Sequence

```
VM BOOTS
  ├─ T+0s   Coral enumerates as 1a6e:089a
  ├─ T+1s   systemd starts coral_firmware_loader.service
  ├─ T+2s   Script detects bootloader mode
  ├─ T+3s   Script triggers udev firmware load
  ├─ T+7s   Device transitions to 18d1:9302
  ├─ T+8s   Script exits successfully
  ├─ T+8s   systemd starts Frigate (or other services)
  └─ T+10s  Frigate fully initialized, TPU ready
```

### Systemd Service

The installed service:
- Runs at boot before `multi-user.target`
- Type: `oneshot` (runs once and exits)
- Timeout: 120 seconds
- Logs: via systemd journal
- Command: `/usr/local/bin/coral_firmware_loader.sh`

**View logs:**
```bash
sudo journalctl -u coral-firmware-loader -n 50 --follow
```

## Integration with Frigate

### Option 1: Systemd Dependency
If Frigate is a systemd service, make it depend on coral-firmware-loader:
```ini
[Unit]
...
After=coral-firmware-loader.service
```

### Option 2: Docker Compose Delay
Add boot delay to Frigate startup:
```yaml
frigate:
  command: sh -c "sleep 10 && /init"
```

### Option 3: No Special Setup
Just install and reboot. Services start after systemd finishes. "Just works."

## File Locations

| File           | Path                                                           | Size  | Purpose            |
| -------------- | -------------------------------------------------------------- | ----- | ------------------ |
| Main script    | `scripts/frigate/coral_firmware_loader.sh`                     | 20 KB | VM boot script     |
| Test script    | `scripts/frigate/test_coral_transition.sh`                     | 10 KB | Learning tool      |
| Implementation | `scripts/frigate/docs/CORAL_FIRMWARE_LOADER_IMPLEMENTATION.md` | 8 KB  | Setup guide        |
| Full guide     | `scripts/frigate/docs/CORAL_FIRMWARE_LOADER.md`                | 6 KB  | Complete reference |
| Quick ref      | `scripts/frigate/docs/CORAL_FIRMWARE_LOADER_QUICK_REF.md`      | 4 KB  | Cheat sheet        |
| Hub visibility | `scripts/frigate/docs/CORAL_POWERED_HUB_VISIBILITY.md`         | 6 KB  | Hub explanation    |

## Troubleshooting Checklist

- [ ] Both `1a6e:089a` and `18d1:9302` in Proxmox passthrough config
- [ ] Powered USB hub is plugged in and powered (indicator light on)
- [ ] Coral is plugged into USB 3.0 port on powered hub
- [ ] Script is installed: `ls -l /usr/local/bin/coral_firmware_loader.sh`
- [ ] Service is enabled: `sudo systemctl is-enabled coral-firmware-loader`
- [ ] Service runs on boot: check `sudo journalctl -u coral-firmware-loader`
- [ ] Device transitions: `lsusb -d 18d1:9302` shows device
- [ ] Frigate logs: `docker logs frigate | grep -i error` shows no EdgeTPU errors

## Expected Results After Installation

**Before:**
```
VM boots
  → Device appears as 089a
  → Frigate starts immediately
  → Frigate crashes (libusb errors)
  → After 5-10s, device becomes 9302
  → Frigate restarts, works
Result: ~5-10 second startup crash period
```

**After:**
```
VM boots
  → Device appears as 089a
  → systemd starts coral_firmware_loader
  → Script waits for transition to 9302
  → Frigate starts only after 9302 ready
  → Frigate starts cleanly, no crashes
Result: No startup crashes, reliable TPU access
```

## Next Steps

1. ✅ Copy `coral_firmware_loader.sh` to VM
2. ✅ Run `--install` flag to install systemd service
3. ✅ Reboot VM to test automatic boot behavior
4. ✅ Verify with `sudo systemctl status coral-firmware-loader`
5. ✅ Check Frigate logs show no TPU errors
6. ✅ Monitor for 24-48 hours with powered hub connected

## Success Indicators

You'll know it's working when:
- ✅ Service status shows "Started coral-firmware-loader.service"
- ✅ `lsusb -d 18d1:9302` shows device right after boot
- ✅ Frigate logs show successful EdgeTPU initialization
- ✅ No libusb transfer errors in Frigate container
- ✅ Frigate process is stable, no crashes
- ✅ dmesg shows no repeated USB resets

## Key Insight: Why This Matters

The Coral USB device's firmware is loaded by udev rules (in the libedgetpu package). This happens a few seconds after boot. Without waiting for this to complete, Frigate crashes trying to use an unprepared device.

This script ensures the firmware is loaded **before** Frigate starts, eliminating the crash period entirely.

## Questions or Issues?

1. **Script not installing?** Check permissions: `sudo`
2. **Device not transitioning?** Check powered hub power and connection
3. **Systemd not running?** Check `/etc/systemd/system/coral-firmware-loader.service` exists
4. **Still getting TPU errors?** Check `docker logs frigate | grep -i edge`
5. **Need more info?** Read the full documentation files

## Files at a Glance

```
/home/divix/divtools/scripts/frigate/
├── coral_firmware_loader.sh           ← Main script (copy to VM)
├── test_coral_transition.sh           ← Test/learning tool
└── docs/
    ├── CORAL_FIRMWARE_LOADER_IMPLEMENTATION.md  ← Setup guide
    ├── CORAL_FIRMWARE_LOADER.md                ← Full reference
    ├── CORAL_FIRMWARE_LOADER_QUICK_REF.md      ← Cheat sheet
    └── CORAL_POWERED_HUB_VISIBILITY.md         ← Hub explanation
```

---

**Status:** ✅ Ready to deploy  
**Created:** November 30, 2025  
**Version:** 1.0  
**For:** Google Coral USB TPU on Proxmox VMs with boot-time initialization issues
