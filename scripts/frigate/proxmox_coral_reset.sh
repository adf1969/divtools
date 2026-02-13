#!/bin/bash
# Proxmox USB Coral Recovery - Resets USB device at hypervisor level
# Last Updated: 11/11/2025 11:35:00 AM CST
# Run this on Proxmox host (tnfs1) to reset the Coral at hardware level

# Only run on Proxmox host
if [[ ! -f /etc/pve/.version ]]; then
    echo "[ERROR] This script must be run on a Proxmox host"
    exit 1
fi

TEST_MODE=0
DEBUG_MODE=0
VM_ID=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -test|--test)
            TEST_MODE=1
            echo "[INFO] Running in TEST mode"
            shift
            ;;
        -debug|--debug)
            DEBUG_MODE=1
            echo "[DEBUG] Debug mode enabled"
            shift
            ;;
        -vmid)
            VM_ID="$2"
            echo "[INFO] Target VM ID: $VM_ID"
            shift 2
            ;;
        *)
            echo "[ERROR] Unknown option: $1"
            exit 1
            ;;
    esac
done

# Default to GPU1-75 (VM 275)
if [[ -z "$VM_ID" ]]; then
    VM_ID=275
fi

echo "[INFO] Coral USB Recovery on Proxmox"
echo "[INFO] Target VM ID: $VM_ID"
echo "[INFO] Timestamp: $(date)"

# Find the Coral device
echo "[INFO] Searching for Coral device (18d1:9302)..."
CORAL_BUS=""
CORAL_DEVICE=""

for device in $(lsusb -d 18d1:9302 2>/dev/null | awk '{print $2":"$4}' | sed 's/://' | sed 's/:$//'); do
    if [[ -n "$device" ]]; then
        CORAL_BUS=$(echo "$device" | cut -d'/' -f1)
        CORAL_DEVICE=$(echo "$device" | cut -d'/' -f2)
        echo "[INFO] Found Coral at Bus $CORAL_BUS, Device $CORAL_DEVICE"
        break
    fi
done

if [[ -z "$CORAL_BUS" ]]; then
    echo "[ERROR] Coral device not found!"
    exit 1
fi

# Find the USB controller
echo "[INFO] Finding USB controller for bus $CORAL_BUS..."
USB_CONTROLLER=$(lsusb -t | grep -A 5 "Bus $CORAL_BUS" | grep "xHCI\|EHCI" | head -1)
echo "[DEBUG] USB Controller: $USB_CONTROLLER"

# Method 1: Reset via sysfs unbind/bind (less disruptive)
echo "[INFO] Attempting USB device reset via sysfs..."

for device_path in /sys/bus/usb/devices/*; do
    if [[ ! -d "$device_path" ]]; then
        continue
    fi
    
    if [[ -f "$device_path/idVendor" && -f "$device_path/idProduct" ]]; then
        VENDOR=$(cat "$device_path/idVendor" 2>/dev/null)
        PRODUCT=$(cat "$device_path/idProduct" 2>/dev/null)
        
        if [[ "$VENDOR" == "18d1" && "$PRODUCT" == "9302" ]]; then
            DEVICE_ID=$(basename "$device_path")
            BUS_PATH=$(dirname "$device_path")
            
            echo "[INFO] Found device at $device_path"
            echo "[INFO] Device ID: $DEVICE_ID"
            
            if [[ $TEST_MODE -eq 1 ]]; then
                echo "[TEST] Would unbind: echo $DEVICE_ID > ${BUS_PATH}/driver/unbind"
                echo "[TEST] Would wait 3 seconds"
                echo "[TEST] Would bind: echo $DEVICE_ID > ${BUS_PATH}/driver/bind"
            else
                echo "[INFO] Unbinding device..."
                if echo "$DEVICE_ID" > "${BUS_PATH}/driver/unbind" 2>/dev/null; then
                    echo "[SUCCESS] Device unbound"
                    sleep 3
                    
                    echo "[INFO] Rebinding device..."
                    if echo "$DEVICE_ID" > "${BUS_PATH}/driver/bind" 2>/dev/null; then
                        echo "[SUCCESS] Device rebound successfully"
                        sleep 2
                        
                        # Verify
                        if lsusb | grep -q "18d1:9302"; then
                            echo "[SUCCESS] Coral device detected after reset"
                        else
                            echo "[WARN] Coral device not immediately visible - may take a moment"
                        fi
                    else
                        echo "[ERROR] Failed to rebind device"
                        exit 1
                    fi
                else
                    echo "[WARN] Failed to unbind (may need to check VM status)"
                fi
            fi
            
            exit 0
        fi
    fi
done

echo "[ERROR] Could not find Coral in sysfs"
exit 1
