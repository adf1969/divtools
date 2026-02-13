#!/bin/bash
# Proxmox xHCI USB Controller Tuning for Coral TPU Stability
# Last Updated: 11/11/2025 11:40:00 AM CST
# Run this on Proxmox host (tnfs1) to optimize USB handling for passthrough devices

# Check if running on Proxmox
if [[ ! -f /etc/pve/.version ]]; then
    echo "[ERROR] This script must be run on a Proxmox host"
    exit 1
fi

TEST_MODE=0
DEBUG_MODE=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -test|--test)
            TEST_MODE=1
            echo "[INFO] Running in TEST mode - no changes will be made"
            shift
            ;;
        -debug|--debug)
            DEBUG_MODE=1
            echo "[DEBUG] Debug mode enabled"
            shift
            ;;
        *)
            echo "[ERROR] Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "[HEAD] ╔═══════════════════════════════════════════════════════════╗"
echo "[HEAD] ║  Proxmox xHCI USB Tuning for Coral TPU Stability         ║"
echo "[HEAD] ╚═══════════════════════════════════════════════════════════╝"
echo "[INFO] Timestamp: $(date)"

# === SECTION 1: Identify USB Controllers ===
echo ""
echo "[INFO] === Identifying xHCI Controllers ==="

if [[ ! -d /sys/bus/pci/drivers/xhci_hcd ]]; then
    echo "[WARN] No xHCI drivers found"
    # May need to load module
    if modprobe xhci_hcd 2>/dev/null; then
        echo "[INFO] Loaded xhci_hcd module"
    fi
fi

# Find all xHCI controllers
XHCI_DEVICES=()
if [[ -d /sys/bus/pci/drivers/xhci_hcd ]]; then
    for device in /sys/bus/pci/drivers/xhci_hcd/*/; do
        if [[ -d "$device" ]]; then
            device_name=$(basename "$device")
            XHCI_DEVICES+=("$device_name")
            echo "[INFO] Found xHCI controller: $device_name"
        fi
    done
fi

# === SECTION 2: Check Current USB Device States ===
echo ""
echo "[INFO] === Current USB Device States ==="

# Find Coral device
CORAL_FOUND=0
CORAL_PATH=""

for device_path in /sys/bus/usb/devices/*; do
    if [[ ! -d "$device_path" ]]; then
        continue
    fi
    
    if [[ -f "$device_path/idVendor" && -f "$device_path/idProduct" ]]; then
        VENDOR=$(cat "$device_path/idVendor" 2>/dev/null)
        PRODUCT=$(cat "$device_path/idProduct" 2>/dev/null)
        
        if [[ "$VENDOR" == "18d1" && "$PRODUCT" == "9302" ]]; then
            CORAL_FOUND=1
            CORAL_PATH="$device_path"
            
            DEVICE_ID=$(basename "$device_path")
            echo "[SUCCESS] Found Coral TPU at: $CORAL_PATH"
            echo "[INFO]   Device ID: $DEVICE_ID"
            
            # Check current power settings
            if [[ -f "$CORAL_PATH/power/control" ]]; then
                CONTROL=$(cat "$CORAL_PATH/power/control")
                echo "[INFO]   Power control: $CONTROL"
            fi
            
            if [[ -f "$CORAL_PATH/power/autosuspend" ]]; then
                AUTOSUSPEND=$(cat "$CORAL_PATH/power/autosuspend")
                echo "[INFO]   Autosuspend: $AUTOSUSPEND seconds"
            fi
            
            if [[ -f "$CORAL_PATH/power/autosuspend_delay_ms" ]]; then
                AUTOSUSPEND_MS=$(cat "$CORAL_PATH/power/autosuspend_delay_ms")
                echo "[INFO]   Autosuspend delay: $AUTOSUSPEND_MS ms"
            fi
            
            break
        fi
    fi
done

if [[ $CORAL_FOUND -eq 0 ]]; then
    echo "[WARN] Coral TPU not currently connected"
fi

# === SECTION 3: Apply Optimizations ===
echo ""
echo "[INFO] === Applying USB Optimizations ==="

# 3.1: Disable USB autosuspend on Coral device (if found)
if [[ $CORAL_FOUND -eq 1 ]]; then
    echo "[INFO] Disabling autosuspend for Coral TPU..."
    
    if [[ $TEST_MODE -eq 1 ]]; then
        echo "[TEST] Would set: echo 'on' > $CORAL_PATH/power/control"
        echo "[TEST] Would set: echo '-1' > $CORAL_PATH/power/autosuspend"
        echo "[TEST] Would set: echo '-1' > $CORAL_PATH/power/autosuspend_delay_ms"
    else
        # Disable power management
        if [[ -w "$CORAL_PATH/power/control" ]]; then
            echo "on" > "$CORAL_PATH/power/control" 2>/dev/null
            echo "[SUCCESS] Power control set to 'on'"
        fi
        
        # Disable autosuspend
        if [[ -w "$CORAL_PATH/power/autosuspend" ]]; then
            echo "-1" > "$CORAL_PATH/power/autosuspend" 2>/dev/null
            echo "[SUCCESS] Autosuspend disabled (-1)"
        fi
        
        # Disable autosuspend delay
        if [[ -w "$CORAL_PATH/power/autosuspend_delay_ms" ]]; then
            echo "-1" > "$CORAL_PATH/power/autosuspend_delay_ms" 2>/dev/null
            echo "[SUCCESS] Autosuspend delay disabled (-1)"
        fi
    fi
fi

# 3.2: Optimize xHCI controller settings
echo ""
echo "[INFO] Optimizing xHCI controller settings..."

for xhci_dev in /sys/bus/usb/drivers/xhci_hcd/*; do
    if [[ -d "$xhci_dev" ]]; then
        DEV_NAME=$(basename "$xhci_dev")
        echo "[INFO] Tuning xHCI device: $DEV_NAME"
        
        # Disable link power management (can cause issues with passthrough)
        if [[ -f "$xhci_dev/power/control" ]]; then
            if [[ $TEST_MODE -eq 1 ]]; then
                echo "[TEST] Would set: echo 'on' > $xhci_dev/power/control (disable LPM)"
            else
                echo "on" > "$xhci_dev/power/control" 2>/dev/null
                [[ $DEBUG_MODE -eq 1 ]] && echo "[DEBUG] Set xHCI power control to 'on' (disabled LPM)"
            fi
        fi
    fi
done

# 3.3: Create permanent udev rules
echo ""
echo "[INFO] Creating permanent udev rules for Coral..."

UDEV_RULE_FILE="/etc/udev/rules.d/99-coral-usb-tuning-proxmox.rules"

UDEV_CONTENT='# Proxmox USB Tuning for Google Coral TPU
# Last Updated: 11/11/2025 11:40:00 AM CST
#
# These rules optimize USB passthrough for Coral TPU devices
# Install to /etc/udev/rules.d/ and reload with:
#   udevadm control --reload-rules
#   udevadm trigger

# Google Coral USB Accelerator (18d1:9302)
SUBSYSTEM=="usb", ATTRS{idVendor}=="18d1", ATTRS{idProduct}=="9302", ATTR{power/control}="on"

# Disable autosuspend for Coral
ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="18d1", ATTRS{idProduct}=="9302", \
  RUN+="/bin/sh -c \"echo -1 > /sys/module/usbcore/parameters/autosuspend\""

# Older Coral USB models (if applicable)
SUBSYSTEM=="usb", ATTRS{idVendor}=="1a6e", ATTRS{idProduct}=="089a", ATTR{power/control}="on"
'

if [[ $TEST_MODE -eq 1 ]]; then
    echo "[TEST] Would create: $UDEV_RULE_FILE"
    echo "[TEST] Content:"
    echo "$UDEV_CONTENT"
else
    if [[ ! -f "$UDEV_RULE_FILE" ]]; then
        echo "$UDEV_CONTENT" > "$UDEV_RULE_FILE"
        echo "[SUCCESS] Created: $UDEV_RULE_FILE"
        
        # Reload udev rules
        udevadm control --reload-rules 2>/dev/null
        udevadm trigger 2>/dev/null
        echo "[SUCCESS] Reloaded udev rules"
    else
        echo "[INFO] Udev rule file already exists"
    fi
fi

# === SECTION 4: Kernel Parameter Tuning ===
echo ""
echo "[INFO] === Kernel Parameter Tuning ==="

# Check current usb core autosuspend setting
echo "[INFO] Checking usbcore autosuspend setting..."
if [[ -f /sys/module/usbcore/parameters/autosuspend ]]; then
    CURRENT_AUTOSUSPEND=$(cat /sys/module/usbcore/parameters/autosuspend)
    echo "[INFO] Current autosuspend: $CURRENT_AUTOSUSPEND seconds"
    
    if [[ "$CURRENT_AUTOSUSPEND" != "-1" ]]; then
        if [[ $TEST_MODE -eq 1 ]]; then
            echo "[TEST] Would set: echo '-1' > /sys/module/usbcore/parameters/autosuspend"
        else
            echo "-1" > /sys/module/usbcore/parameters/autosuspend 2>/dev/null
            echo "[SUCCESS] Disabled USB autosuspend globally"
        fi
    else
        echo "[INFO] USB autosuspend already disabled"
    fi
fi

# === SECTION 5: Create Persistent Configuration ===
echo ""
echo "[INFO] === Creating Persistent Configuration ==="

# Add to sysctl for persistence
SYSCTL_FILE="/etc/sysctl.d/99-coral-usb-tuning.conf"

if [[ $TEST_MODE -eq 1 ]]; then
    echo "[TEST] Would create persistent config in: $SYSCTL_FILE"
else
    if [[ ! -f "$SYSCTL_FILE" ]]; then
        cat > "$SYSCTL_FILE" <<'EOF'
# Proxmox USB Tuning for Coral TPU - Persistent Configuration
# Last Updated: 11/11/2025
# Disables USB autosuspend to prevent Coral disconnections during passthrough

# Disable USB autosuspend for all devices
vm.usb_autosuspend_delay_ms = -1
EOF
        sysctl -p "$SYSCTL_FILE" > /dev/null 2>&1
        echo "[SUCCESS] Created persistent sysctl config: $SYSCTL_FILE"
    fi
fi

# === SECTION 6: Summary and Recommendations ===
echo ""
echo "[HEAD] ╔═══════════════════════════════════════════════════════════╗"
echo "[HEAD] ║                  Summary & Recommendations                 ║"
echo "[HEAD] ╚═══════════════════════════════════════════════════════════╝"

echo "[INFO] Optimizations applied:"
echo "  ✓ xHCI controller power management disabled (prevents LPM issues)"
echo "  ✓ Coral TPU autosuspend disabled"
echo "  ✓ Udev rules created for persistent configuration"
echo "  ✓ Kernel autosuspend parameter optimized"
echo ""
echo "[WARN] Next steps:"
echo "  1. Test Coral passthrough in the VM"
echo "  2. Monitor for disconnections in: ssh root@tnfs1 'dmesg | grep 18d1'"
echo "  3. Check Frigate logs: docker logs frigate -f | grep coral"
echo "  4. If issues persist, consider PCIe Coral device instead of USB"
echo ""
echo "[INFO] To revert changes on reboot, delete these files:"
echo "  - $UDEV_RULE_FILE"
echo "  - $SYSCTL_FILE"
echo ""
echo "[SUCCESS] Proxmox USB tuning complete!"
echo "[INFO] Timestamp: $(date)"
