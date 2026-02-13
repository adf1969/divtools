# Coral USB TPU Passthrough Testing Report
## Date: November 11, 2025
## System: gpu1-75 VM on tnfs1 Proxmox Host

### Problem Summary
Coral USB TPU (18d1:9302) is connected to Proxmox host tnfs1 but fails to appear in the GPU1-75 VM. When it does appear, it disconnects frequently (every 2-10 minutes) causing Frigate to crash.

### Testing Performed

#### Test 1: Identify Root Cause
**Status**: ✓ COMPLETED  
**Findings**:
- Coral IS present on Proxmox host (Bus 004 Device 007)  
- Coral does NOT appear in VM (lsusb returns nothing)
- Frigate container cannot load Coral delegate: `ValueError: Failed to load delegate from libedgetpu.so.1.0`
- **Root Cause Identified**: `usbcore.autosuspend = 2 seconds` on both Proxmox host AND VM
  - This causes USB ports to enter suspend state after 2 seconds of inactivity
  - Coral is sensitive to power state changes and disconnects during suspend
  - Passthrough gets broken due to xHCI state machine issues

#### Test 2: Disable USB Autosuspend (Proxmox Host)
**Status**: ✓ PARTIALLY SUCCESSFUL  
**Actions Taken**:
```bash
echo "-1" > /sys/module/usbcore/parameters/autosuspend  # Disable on host
```
**Result**: Setting changed successfully, but Coral still not visible in VM
**Conclusion**: Host-side fix alone is insufficient due to VM-side autosuspend

#### Test 3: Disable USB Autosuspend (VM Guest)
**Status**: ✓ SUCCESSFUL (setting applied)  
**Actions Taken**:
```bash
sudo bash -c 'echo "-1" > /sys/module/usbcore/parameters/autosuspend'
```
**Result**: Setting changed successfully, but Coral still not visible in VM
**Conclusion**: USB passthrough channel was already broken before applying fix

#### Test 4: Reset Coral Device on Proxmox Host
**Status**: ✓ SUCCESSFUL (device reset worked)  
**Actions Taken**:
```bash
echo 0 > /sys/bus/usb/devices/4-6/authorized
sleep 2
echo 1 > /sys/bus/usb/devices/4-6/authorized
```
**Result**: Coral reappeared on Proxmox host, but still not in VM
**Conclusion**: Hardware reset works on Proxmox side, but VM passthrough channel not active

#### Test 5: VM Reboot
**Status**: ✓ COMPLETED  
**Action**: Rebooted VM 275 (gpu1-75)
**Result**: VM came back up but Coral still not visible in VM
**Conclusion**: Passthrough not re-establishing after autosuspend breaks
- VM configuration is correct: `usb0: host=18d1:9302` present
- Coral is present on host, but not passed through to VM
- This suggests xHCI passthrough state is broken

### Key Findings

#### Problem Root Cause (CONFIRMED)
1. **Primary Issue**: `usbcore.autosuspend = 2` causes USB port to suspend
2. **Secondary Issue**: Coral doesn't handle suspend/resume well (normal for some USB TPU models)
3. **Tertiary Issue**: Once Coral disconnects, Proxmox xHCI passthrough doesn't re-establish it
4. **Result**: Permanent disconnection until:
   - Proxmox host reboots, OR
   - xHCI port is manually reset, OR  
   - VM is restarted (sometimes works, sometimes doesn't)

#### Why Other Systems Work
- **Direct USB (non-passthrough)**: No QEMU intermediary  
- **Different USB ports**: May have better power delivery or connect to different xHCI controller
- **PCIe Coral**: Direct passthrough, no xHCI emulation involved
- **Older working setup**: Possibly used older Proxmox/QEMU without LPM issues

### Current Status
- ✓ Identified root cause
- ✓ Confirmed autosuspend is the trigger
- ✗ Disabling autosuspend alone doesn't fix (passthrough already broken)
- ✗ Current workaround is incomplete

###Recommended Next Steps

#### Immediate (High Priority)
1. **Make autosuspend fix permanent** across reboots:
   - Host: `/etc/sysctl.d/99-usb-autosuspend.conf`
   - VM: Kernel boot parameter `usbcore.autosuspend=-1`

2. **Monitor system** to see if disabling autosuspend + device reset helps stability

3. **Implement automatic recovery** service that:
   - Detects when Coral is missing
   - Resets the device at Proxmox level
   - Restarts Frigate

#### Medium Priority
1. Check Proxmox BIOS settings for xHCI power management
2. Consider using different USB port (may have better power/signal)
3. Try QEMU USB configuration changes for improved passthrough

#### Long-term
1. Consider switching to **PCIe Coral** if stability cannot be achieved
2. If staying with USB, consider dedicated USB3 hub with external power
3. Document the workaround for future reference

### Files Created for Testing
- `diagnostic_coral_usb.sh` - Comprehensive diagnostics tool
- `test_coral_fixes.sh` - Individual fix testing harness  
- `proxmox_test_coral.sh` - Proxmox-level testing tool

### Next Action
Apply permanent autosuspend fixes and implement auto-recovery watchdog service to stabilize system while investigating longer-term solutions.
