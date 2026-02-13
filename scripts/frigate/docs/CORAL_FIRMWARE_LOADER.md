# Coral TPU Firmware Loader - VM Integration Guide

**File:** `/home/divix/divtools/scripts/frigate/coral_firmware_loader.sh`

**Purpose:** Ensure Coral TPU transitions from bootloader (1a6e:089a) to operational mode (18d1:9302) at VM boot, preventing Frigate startup crashes.

## Quick Start

### 1. On Your VM (gpu1-75 / NAS1-1)

Copy the script from the host:
```bash
# From Proxmox host, copy to VM
scp /home/divix/divtools/scripts/frigate/coral_firmware_loader.sh root@<vm-ip>:/tmp/

# Then on the VM
cd /tmp
chmod +x coral_firmware_loader.sh
sudo ./coral_firmware_loader.sh --install
```

Or manually copy/paste the script content to `/usr/local/bin/coral_firmware_loader.sh` and run install.

### 2. What Installation Does

The `--install` flag:
- Copies script to `/usr/local/bin/coral_firmware_loader.sh`
- Creates `/etc/systemd/system/coral-firmware-loader.service`
- Enables the service to run at boot
- Runs before `multi-user.target` (before Frigate/Docker services start)

### 3. Verify Installation

```bash
# Check if service is enabled
sudo systemctl status coral-firmware-loader

# Run script manually to test
sudo /usr/local/bin/coral_firmware_loader.sh -status

# View systemd logs
sudo journalctl -u coral-firmware-loader -n 20 --follow
```

## Usage

### On the VM:

**Check current status:**
```bash
./coral_firmware_loader.sh -status
```

**Manual firmware load (debug):**
```bash
sudo ./coral_firmware_loader.sh -debug -verbose
```

**Force reload (if stuck in bootloader):**
```bash
sudo ./coral_firmware_loader.sh -force-reload
```

**View help:**
```bash
./coral_firmware_loader.sh --help
```

## How It Works

**Scenario 1: Device already operational**
- Coral shows as `18d1:9302` in `lsusb`
- Script exits immediately (takes ~1 second)
- Frigate can start normally

**Scenario 2: Device in bootloader mode**
- Coral shows as `1a6e:089a` in `lsusb`
- Script triggers udev rules to load firmware
- Device re-enumerates to `18d1:9302` (usually within 5-10 seconds)
- Frigate can start safely

**Scenario 3: Device not visible at all**
- Check Proxmox VM USB passthrough config
- Check host dmesg for enumeration errors
- Verify powered USB hub connection on host

## Frigate Integration

### Option A: Systemd Dependency (Recommended)

If Frigate runs as a systemd service, make it depend on Coral loader:

```ini
# /etc/systemd/system/frigate.service (or similar)
[Unit]
...
After=coral-firmware-loader.service
...
```

Then restart Frigate:
```bash
sudo systemctl restart frigate
```

### Option B: Docker Compose Health Check

If using Docker Compose:

```yaml
frigate:
  container_name: frigate
  image: ghcr.io/blakeblackshear/frigate:stable
  restart: unless-stopped
  
  # Add short delay to allow systemd service to run
  command: sh -c "sleep 5 && /init"
  
  # Or use healthcheck to wait for device
  healthcheck:
    test: lsusb -d 18d1:9302 > /dev/null 2>&1
    interval: 5s
    timeout: 3s
    retries: 60  # Wait up to 5 minutes
```

### Option C: Boot Delay (Simplest)

Just add a 10-second delay before Frigate starts:

```bash
#!/bin/bash
# /usr/local/bin/start_frigate.sh
sleep 10
docker start frigate
```

Then cron or systemd can call this wrapper instead of `docker start frigate` directly.

## Troubleshooting

### Device times out waiting for transition

**Cause:** USB passthrough not working or Coral not connected properly

**Check:**
```bash
# On Proxmox host
qm config 275 | grep usb
# Should show: usb0: host=1a6e:089a,usb3=1
# AND: usb1: host=18d1:9302,usb3=1

# On Proxmox host, check dmesg
dmesg -e | grep -E "(usb|coral|1a6e|18d1)" | tail -20
```

### Device shows 089a but never transitions to 9302

**Cause:** Firmware files not available or udev rules not running

**Check:**
```bash
# On VM, check if libedgetpu is installed
dpkg -l | grep libedgetpu

# If missing, install (if you have internet on VM)
sudo apt update
sudo apt install -y libedgetpu1-std

# Or on Proxmox host (check if present)
dpkg -l | grep libedgetpu
```

### Script says "permission denied"

**Cause:** Script needs root to run udevadm

**Fix:**
```bash
sudo ./coral_firmware_loader.sh
# or after installation:
sudo systemctl start coral-firmware-loader
```

### How do I know it worked?

**Success indicators:**
```bash
# Device is present
lsusb -d 18d1:9302
# Should return: Bus 004 Device NNN: ID 18d1:9302 Global Unichip Corp.

# No errors in Frigate logs
docker logs frigate | grep -i "edge\|tpu\|coral" | grep -i error

# Check systemd logs
sudo journalctl -u coral-firmware-loader | grep -i "✓"
```

## File Locations

| Purpose | Location |
|---------|----------|
| Source script | `/home/divix/divtools/scripts/frigate/coral_firmware_loader.sh` |
| Installed script | `/usr/local/bin/coral_firmware_loader.sh` |
| Systemd unit | `/etc/systemd/system/coral-firmware-loader.service` |
| Config dir | `/etc/coral-tpu/` |
| Systemd logs | `journalctl -u coral-firmware-loader` |

## Related References

- **Proxmox USB passthrough:** `qm config <vmid> | grep usb`
- **Frigate container logs:** `docker logs -f frigate`
- **Host USB enumeration:** `dmesg -e | grep usb`
- **EdgeTPU status:** `lsusb`, `ldconfig -p | grep edgetpu`
- **Proxmox kernel cmdline:** `/etc/kernel/cmdline` (your usbcore.autosuspend=-1 settings)
- **USB device info:** `cat /sys/kernel/debug/usb/devices`

## When to Use This

✅ **Use this script when:**
- VM boots and Coral sometimes appears as 089a (bootloader)
- Frigate crashes or fails to detect TPU on startup
- You want reliable TPU presence before any service starts
- You need to troubleshoot USB enumeration timing

❌ **Don't need this if:**
- Coral always shows as 18d1:9302 immediately on boot
- Frigate starts without any TPU errors or crashes

---

**Last Updated:** 11/30/2025
