# Coral USB TPU Disconnect Issue - Diagnosis & Solutions

## Problem Summary
The Coral Edge TPU (USB device 18d1:9302) on GPU1-75 VM experiences periodic disconnections, causing Frigate to crash and restart. The device works on other systems without issue, suggesting it's a configuration or passthrough issue specific to this VM/Proxmox setup.

## Findings

### Current Setup
- **Proxmox Host**: tnfs1 (10.1.1.70)
- **VM**: gpu1-75 (10.1.1.75) - VM ID 275
- **USB Passthrough Config**: `usb0: host=18d1:9302` and `usb1: host=1a6e:089a`
- **Connection Type**: USB 4-6 SuperSpeed (xHCI)

### Symptoms
- `Failed to load delegate from libedgetpu.so.1.0` errors in Frigate logs
- Device not visible inside VM via `lsusb` despite being on host
- Periodic USB disconnect/reconnect cycles visible in host dmesg
- Device works flawlessly on other systems

### Root Cause Analysis

The issue appears to be related to **USB power management and link state conflicts** in the Proxmox passthrough chain:

1. **Proxmox xHCI Host Controller** - May have aggressive power/LPM settings
2. **QEMU Passthrough Layer** - USB passthrough has link negotiation overhead
3. **Coral Device Power State** - The TPU is more sensitive to power/suspend signals than regular USB devices
4. **Kernel autosuspend settings** - System trying to suspend the USB port

### Why Other Systems Work
- **Direct USB (non-passthrough)**: No QEMU intermediary, direct kernel control
- **Different USB ports**: Other systems may have better power delivery or simpler hub topology
- **Different kernel versions**: Host kernel settings don't interfere

## Solutions

### 1. Proxmox Host-Level Fixes
- Disable USB link power management on the xHCI controller
- Reduce USB polling/timeout delays
- Ensure consistent power delivery to the USB port

### 2. VM Guest-Level Fixes
- Disable USB autosuspend for the Coral device
- Apply udev rules to prevent power management
- Run periodic monitoring to detect and recover from disconnections

### 3. Frigate Recovery
- Automatic watchdog to detect when Coral is unavailable
- Self-healing with exponential backoff
- Fallback to CPU detection when TPU unavailable

## Implementation Files
- `fix_coral_usb_autosuspend.sh` - Disable USB power management (guest)
- `reset_coral_usb.sh` - Perform USB device reset (guest)
- `monitor_coral_tpu.sh` - Monitor and auto-recover (guest)
- `coral_watchdog.service` - Systemd service for continuous monitoring
- `coral_proxmox_recovery.sh` - Host-level recovery script (runs on tnfs1)
- `proxmox_usb_tuning.sh` - Optimize Proxmox USB settings (runs on tnfs1)

## Diagnosis Commands

### Check device on host
```bash
ssh root@tnfs1 "lsusb | grep -i google"
ssh root@tnfs1 "lsusb -v -d 18d1:9302"
```

### Check device in VM
```bash
docker exec frigate lsusb | grep -i google
```

### Monitor for disconnections
```bash
watch -n 1 'lsusb | grep -i google || echo "DISCONNECTED"'
```

### Check kernel USB events
```bash
ssh root@tnfs1 "dmesg | grep 'usb 4-6' | tail"
```

### Check Frigate logs for errors
```bash
docker logs frigate --follow | grep -i coral
```

## Recommended Actions

### Immediate (Today)
1. Run `fix_coral_usb_autosuspend.sh` in the guest to disable power management
2. Run `monitor_coral_tpu.sh` as a systemd service for auto-recovery
3. Monitor Frigate logs for stabilization

### Short-term (This Week)
1. Connect to Proxmox host and run USB power management tuning
2. Install systemd watchdog service on VM
3. Test stability under camera load

### Long-term (This Month)
1. Consider switching to PCIe Coral if stability isn't achieved
2. Document the final working configuration
3. Apply fixes to other similar VMs that might have the same issue

