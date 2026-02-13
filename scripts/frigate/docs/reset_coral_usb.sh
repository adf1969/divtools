#!/bin/bash
# Software reset of Coral Edge TPU USB device
# Last Updated: 11/5/2025 12:55:00 PM CST

# Source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../util/logging.sh"

log "INFO" "Attempting software reset of Coral Edge TPU..."

# Find the Coral device
USB_PATH=""
for device_path in /sys/bus/usb/devices/*; do
    [[ ! -d "$device_path" ]] && continue
    
    if [[ -f "$device_path/idVendor" && -f "$device_path/idProduct" ]]; then
        VENDOR=$(cat "$device_path/idVendor" 2>/dev/null)
        PRODUCT=$(cat "$device_path/idProduct" 2>/dev/null)
        
        if [[ "$VENDOR" == "18d1" && "$PRODUCT" == "9302" ]]; then
            USB_PATH="$device_path"
            DEVICE_NAME=$(basename "$device_path")
            log "SUCCESS" "Found Coral TPU at: $USB_PATH"
            break
        fi
    fi
done

if [[ -z "$USB_PATH" ]]; then
    log "ERROR" "Coral Edge TPU not found"
    exit 1
fi

# Get the USB bus path for unbinding
BUS_PATH=$(dirname "$USB_PATH")
DEVICE_ID=$(basename "$USB_PATH")

log "INFO" "Device ID: $DEVICE_ID"
log "INFO" "Unbinding USB device..."

# Unbind the device
if echo "$DEVICE_ID" > "${BUS_PATH}/driver/unbind" 2>/dev/null; then
    log "SUCCESS" "Device unbound"
else
    log "WARN" "Failed to unbind (may already be unbound)"
fi

log "INFO" "Waiting 3 seconds..."
sleep 3

log "INFO" "Rebinding USB device..."

# Rebind the device
if echo "$DEVICE_ID" > "${BUS_PATH}/driver/bind" 2>/dev/null; then
    log "SUCCESS" "Device rebound"
else
    log "ERROR" "Failed to rebind device"
    log "INFO" "Trying alternative method..."
    
    # Alternative: authorize/deauthorize
    if [[ -f "$USB_PATH/authorized" ]]; then
        echo 0 > "$USB_PATH/authorized"
        sleep 2
        echo 1 > "$USB_PATH/authorized"
        log "SUCCESS" "Device reauthorized"
    fi
fi

log "INFO" "Waiting for device to stabilize..."
sleep 3

# Verify device is back
if lsusb | grep -q "18d1:9302"; then
    log "SUCCESS" "Coral TPU detected after reset"
    
    # Reapply power management settings
    log "INFO" "Reapplying power management settings..."
    
    # Find the device again (may have new path)
    for device_path in /sys/bus/usb/devices/*; do
        [[ ! -d "$device_path" ]] && continue
        
        if [[ -f "$device_path/idVendor" && -f "$device_path/idProduct" ]]; then
            VENDOR=$(cat "$device_path/idVendor" 2>/dev/null)
            PRODUCT=$(cat "$device_path/idProduct" 2>/dev/null)
            
            if [[ "$VENDOR" == "18d1" && "$PRODUCT" == "9302" ]]; then
                if [[ -f "$device_path/power/control" ]]; then
                    echo "on" > "$device_path/power/control"
                    log "SUCCESS" "Power control set to 'on'"
                fi
                if [[ -f "$device_path/power/autosuspend" ]]; then
                    echo "-1" > "$device_path/power/autosuspend"
                    log "SUCCESS" "Autosuspend disabled"
                fi
                break
            fi
        fi
    done
    
    echo
    log "SUCCESS" "Coral USB reset complete"
    log "INFO" "You can now start Frigate"
else
    log "ERROR" "Coral TPU not detected after reset"
    log "INFO" "May need physical unplug/replug"
fi
