# Powered USB Hub Visibility & Passthrough Behavior

## Is the Hub Visible to the VM?

**Short answer:** The hub itself is largely **invisible** at the OS level. You pass through the **devices**, not the hub.

### How It Works

```
Proxmox Host (tnfs1)
├─ Powered USB 3.0 Hub (connected to host USB port)
│  ├─ Coral USB TPU (1a6e:089a / 18d1:9302)
│  └─ (Other USB devices on hub)
└─ USB Passthrough Rule (in Proxmox VM config)
   └─ "Pass device 1a6e:089a to VM 275"
   └─ "Pass device 18d1:9302 to VM 275"

VM (gpu1-75 / NAS1-1)
├─ Sees: Coral TPU (1a6e:089a and/or 18d1:9302)
├─ Sees: The USB port/protocol layer (USB 3.0)
└─ Does NOT see: The physical hub itself
```

### What This Means

| Question | Answer |
|----------|--------|
| Can VM see the hub device? | No - hub is invisible to VM |
| Can VM see devices on the hub? | Yes - via USB passthrough |
| Do I need to pass the hub through? | No - just pass the devices |
| Will the powered hub be listed in `lsusb` on VM? | No, hub is not visible |
| Will the Coral be listed in `lsusb` on VM? | Yes, because it's passed through |
| Will the Coral work better on the hub? | Yes - hub provides better power/signal |

### Real Examples

**On Proxmox Host:**
```bash
$ lsusb | grep -E "Atolla|Coral|089a|9302"
Bus 004 Device 025: ID 1f75:0880 Innostor Technology Corp. 
    ↑ This is the Atolla hub itself

Bus 004 Device 026: ID 1a6e:089a Global Unichip Corp. 
    ↑ Coral on the hub
```

**On VM (after passthrough):**
```bash
$ lsusb | grep -E "Atolla|Coral|089a|9302"
Bus 004 Device 021: ID 1a6e:089a Global Unichip Corp.
    ↑ Coral is visible (same device, re-enumerated in VM)
    
# The Atolla hub is NOT listed here
# But the Coral works because it's plugged into it
```

### What the VM Actually Sees

When you pass through USB devices, the VM sees:
- ✅ The USB device itself (Coral TPU)
- ✅ The USB protocol/speed (3.0, 2.0, etc.)
- ✅ Device descriptors and interfaces
- ❌ The physical hub structure
- ❌ Other devices on the hub (unless also passed through)

**From the VM's perspective:**
> "I have a USB 3.0 device (Coral) connected to one of my USB ports"

The VM doesn't care that the actual host connection goes through a powered hub—it just sees the device on USB 3.0.

## Why Use a Powered Hub If It's Invisible?

The hub isn't visible, but it **does provide real benefits:**

1. **Better Power Delivery**
   - Hub provides stable 5V power to Coral
   - Prevents power-related resets
   - Reduces "device disconnected" errors

2. **Better Signal Integrity**
   - Hub isolates electrical noise
   - Reduces USB transfer errors
   - Cleaner USB communication

3. **Port Management**
   - Can plug multiple USB devices on hub
   - Doesn't consume all host USB ports
   - Easier cable management

4. **Re-enumeration Stability**
   - Device transitions (089a → 9302) happen more reliably
   - Fewer "device offline" messages

**These benefits are real, even though the hub itself is invisible to software.**

## Checking Hub Connection Status

### On the Proxmox Host

**See the hub itself:**
```bash
lsusb | grep -i atolla
# Should show: Bus 004 Device XXX: ID 1f75:0880 Innostor Technology Corp.

# Or search for any hub
lsusb | grep -i hub

# Or search for Coral parent
lsusb -t | grep -A2 Coral
```

**Check USB bus topology:**
```bash
lsusb -t | head -30
# Shows USB tree with hubs and devices

# Or verbose info on Coral:
lsusb -d 18d1:9302 -v | head -20
```

**Verify the device is on USB 3.0:**
```bash
lsusb -d 1a6e:089a -v 2>/dev/null | grep -i "bcdUSB\|iSerialNumber"
# Should show: bcdUSB 3.00 (for USB 3.0)
```

### On the VM

**Check Coral is passed through:**
```bash
lsusb -d 1a6e:089a  # Bootloader
lsusb -d 18d1:9302  # Operational
# Should show device with same bus assignment as seen from host
```

**Check USB 3.0 speed:**
```bash
lsusb -v -d 18d1:9302 2>/dev/null | grep -i speed
# Should show: SuperSpeed USB (5000Mbps)
```

### Check Host-Level Connection

**See what's plugged into which host port:**
```bash
# On Proxmox host
cat /sys/kernel/debug/usb/devices | grep -B5 -A5 "089a\|9302"

# Or check dmesg for recent device enumeration
dmesg -e | grep -E "usb|Coral" | tail -20
```

## Powered Hub Visibility in Different Places

| Tool/Command | Sees Hub? | Sees Coral? | Shows What |
|--------------|-----------|------------|-----------|
| `lsusb` on host | ✅ Yes | ✅ Yes | Hub + Coral |
| `lsusb` on VM | ❌ No | ✅ Yes | Just Coral |
| `lsusb -t` on host | ✅ Yes | ✅ Yes | Tree with hub as parent |
| `dmesg` on host | ✅ Yes | ✅ Yes | Hub enumeration + Coral |
| `dmesg` on VM | ❌ No | ✅ Yes | Just Coral |
| Proxmox UI | ✅ Yes | ✅ Yes | All USB devices |
| Frigate logs | ❌ No | ✅ Yes | Coral detection |
| EdgeTPU library | ❌ No | ✅ Yes | TPU device |

## Troubleshooting Hub Connection

### Hub is plugged in but Coral not showing in `lsusb`

```bash
# On Proxmox host
# 1. Check hub is seen
lsusb | grep -i "innostor\|hub"

# 2. Check host-to-hub connection
lsusb -t

# 3. Check for USB errors
dmesg -e | grep -i "usb.*error\|disconnect" | tail -10

# 4. Verify powered hub has power
# (should be obvious from indicator light)

# 5. Try replugging Coral into hub
# (unplug Coral from hub, wait 5s, replug)
```

### Hub not powering devices

**Symptoms:**
- Device appears in lsusb but frequently disconnects
- "device reset" messages in dmesg

**Check:**
```bash
# Verify hub has external power
# Should have AC adapter plugged in and indicator light on

# Check if devices are getting powered
dmesg -e | grep -i "power"

# Try a different USB 3.0 port on hub
# Move Coral to different port on hub
```

### Device keeps re-enumerating

**Symptoms:**
- Device shows as 089a, then 9302, then back to 089a (repeating)
- Frigate keeps crashing

**Check:**
```bash
# Is hub powered?
# Is USB cable properly connected?
# Try different port on hub

# Check host dmesg
dmesg -e | grep -E "usb.*reset|Coral" | tail -20

# Check if VM is getting events
ssh to vm and check: dmesg -e | tail -20
```

## Summary: Hub Visibility

| Aspect | Visibility | Details |
|--------|-----------|---------|
| **Software** | Invisible to VM | Hub doesn't appear in VM's OS |
| **Physical** | Invisible to VM | VM doesn't "see" the device |
| **Functional** | Invisible to VM | VM doesn't manage hub power |
| **Benefits** | Very Visible | Improved stability, fewer disconnects |
| **On Host** | Visible | Can see hub in `lsusb`, dmesg, Proxmox UI |
| **For Frigate** | Irrelevant | Only Coral device matters to Frigate |
| **For EdgeTPU** | Irrelevant | Only Coral device matters to EdgeTPU |

**Bottom line:** The hub is a transparent conduit for USB communication. The VM never "sees" it, but definitely benefits from its presence.

---

**Related Files:**
- `coral_firmware_loader.sh` - Ensures device transitions properly regardless of hub
- `CORAL_FIRMWARE_LOADER.md` - Full integration guide
- `CORAL_PROXMOX_SCRIPTS_GUIDE.sh` - Proxmox-side diagnostics

**Last Updated:** November 30, 2025
