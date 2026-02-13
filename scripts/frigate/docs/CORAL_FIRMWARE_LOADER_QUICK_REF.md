# Coral TPU Firmware Loader - Quick Reference

## TL;DR

The Coral USB device on your VM shows as `1a6e:089a` (bootloader) at first, then transitions to `18d1:9302` (operational) when firmware loads. If this transition is slow, Frigate crashes before it's ready.

**Solution:** Run `coral_firmware_loader.sh` at boot to ensure device is in `9302` mode BEFORE Frigate starts.

## Installation (One-Time on VM)

```bash
# Copy from Proxmox host to VM
scp /home/divix/divtools/scripts/frigate/coral_firmware_loader.sh root@<vm-ip>:/tmp/

# On VM:
cd /tmp
sudo chmod +x coral_firmware_loader.sh
sudo ./coral_firmware_loader.sh --install

# Reboot to test
sudo reboot
```

## Verify It Worked

```bash
# Check service status
sudo systemctl status coral-firmware-loader

# View logs
sudo journalctl -u coral-firmware-loader -n 30

# Check device is present
lsusb -d 18d1:9302
# Should show: Bus 004 Device XXX: ID 18d1:9302 Global Unichip Corp.

# Check Frigate logs (no TPU errors)
docker logs frigate | grep -i "tpu\|coral\|edge" | tail -10
```

## Uninstall (If Needed)

```bash
sudo /usr/local/bin/coral_firmware_loader.sh --uninstall
```

## What It Does

| Stage | What Happens | Time |
|-------|--------------|------|
| 1. Boot | systemd starts `coral-firmware-loader.service` | ~1 sec |
| 2. Check | Script checks if device is `18d1:9302` | ~1 sec |
| 3. Trigger | If not ready, triggers udev firmware load | ~1 sec |
| 4. Wait | Waits for device to transition (with timeout) | 5-10 sec (usually) |
| 5. Done | Returns success; boot continues | ~1 sec |
| 6. Services | Frigate and Docker services start AFTER step 5 | N/A |

**Total time:** Usually 5-15 seconds before Frigate can start safely.

## Commands Reference

```bash
# Manual check (any time)
./coral_firmware_loader.sh -status

# Manual force reload (if stuck)
sudo ./coral_firmware_loader.sh -force-reload

# With debug output
sudo ./coral_firmware_loader.sh -debug -verbose

# Install
sudo ./coral_firmware_loader.sh --install

# Uninstall
sudo ./coral_firmware_loader.sh --uninstall

# Help
./coral_firmware_loader.sh --help
```

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | ✓ Success - Device is ready (18d1:9302) |
| 1 | ✗ Failure - Device not found or timeout |

**Use in scripts:** `if ./coral_firmware_loader.sh -status; then echo "Ready!"; fi`

## Why Two Device IDs?

| Device ID | Mode | Description |
|-----------|------|-------------|
| `1a6e:089a` | **Bootloader** | Device just powered on, firmware NOT loaded yet |
| `18d1:9302` | **Operational** | Firmware loaded, device ready for use |

**What happens:**
1. VM boots, Proxmox passes through USB device
2. USB device appears as `1a6e:089a` (bootloader)
3. Linux udev rules run `libedgetpu` firmware loader
4. Device re-enumerates as `18d1:9302` (operational)
5. Frigate can now see and use the TPU

**The Problem:** If Frigate starts too early (step 2 or 3), it crashes because TPU isn't available yet.

**The Solution:** Wait for step 4 to complete, THEN start Frigate.

## Integration with Frigate

**If Frigate is systemd service:**
```ini
# Edit: /etc/systemd/system/frigate.service
[Unit]
After=coral-firmware-loader.service
```

**If Frigate is Docker (no special setup needed):**
- Just ensure the `--install` was done
- Docker services start after systemd finishes
- Should "just work" automatically

**If Frigate is docker-compose with delay:**
```yaml
frigate:
  command: sh -c "sleep 10 && /init"
  # Boot delay gives time for coral loader to finish
```

## Troubleshooting Checklist

- [ ] Device passes through to VM (check Proxmox: `qm config 275 | grep usb`)
- [ ] Both `1a6e:089a` and `18d1:9302` are in passthrough list
- [ ] Powered USB hub is properly connected to host
- [ ] Script is installed: `ls -l /usr/local/bin/coral_firmware_loader.sh`
- [ ] Service is enabled: `sudo systemctl is-enabled coral-firmware-loader`
- [ ] Systemd logs show success: `sudo journalctl -u coral-firmware-loader | grep "✓"`
- [ ] Device appears on boot: `lsusb -d 18d1:9302`
- [ ] Frigate starts without TPU errors: `docker logs frigate | grep -i error`

## More Help

- Full documentation: `/home/divix/divtools/scripts/frigate/docs/CORAL_FIRMWARE_LOADER.md`
- Script help: `./coral_firmware_loader.sh --help`
- Frigate docs: https://docs.frigate.video/
- Google Coral USB setup: https://coral.ai/docs/accelerator/get-started/

---

**Last Updated:** 11/30/2025
