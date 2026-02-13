#!/bin/bash
# Fixes Coral Edge TPU USB autosuspend and power management issues
# Last Updated: 11/5/2025 12:15:00 PM CST

# Source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../util/logging.sh"

log "INFO" "Fixing Coral Edge TPU USB autosuspend and power management..."
log "INFO" "Searching for Google Coral TPU (idVendor=18d1, idProduct=9302)..."

# Search all USB device paths in sysfs for the Coral TPU
# This is more reliable than using lsusb and avoids bus number formatting issues
USB_PATH=""
for device_path in /sys/bus/usb/devices/*; do
    # Skip if not a valid device directory
    [[ ! -d "$device_path" ]] && continue
    
    # Check if this device has vendor/product ID files
    if [[ -f "$device_path/idVendor" && -f "$device_path/idProduct" ]]; then
        VENDOR=$(cat "$device_path/idVendor" 2>/dev/null)
        PRODUCT=$(cat "$device_path/idProduct" 2>/dev/null)
        
        # Check if this is the Coral TPU (18d1:9302)
        if [[ "$VENDOR" == "18d1" && "$PRODUCT" == "9302" ]]; then
            USB_PATH="$device_path"
            DEVICE_NAME=$(basename "$device_path")
            log "SUCCESS" "Found Coral TPU at: $USB_PATH"
            log "INFO" "Device identifier: $DEVICE_NAME"
            break
        fi
    fi
done

if [[ -z "$USB_PATH" || ! -d "$USB_PATH" ]]; then
    log "ERROR" "Coral Edge TPU not found in sysfs"
    log "INFO" "Make sure the device is connected and visible in 'lsusb'"
    log "INFO" "Looking for: idVendor=18d1, idProduct=9302"
    exit 1
fi

log "INFO" "USB device path: $USB_PATH"

# Check current power management settings
if [[ -f "$USB_PATH/power/control" ]]; then
    CURRENT_CONTROL=$(cat "$USB_PATH/power/control")
    log "INFO" "Current power control: $CURRENT_CONTROL"
else
    log "WARN" "Power control file not found at $USB_PATH/power/control"
fi

if [[ -f "$USB_PATH/power/autosuspend" ]]; then
    CURRENT_AUTOSUSPEND=$(cat "$USB_PATH/power/autosuspend")
    log "INFO" "Current autosuspend delay: $CURRENT_AUTOSUSPEND seconds"
fi

# Disable autosuspend
log "INFO" "Disabling USB autosuspend for Coral TPU..."

if [[ -f "$USB_PATH/power/control" ]]; then
    echo "on" | tee "$USB_PATH/power/control" > /dev/null
    log "SUCCESS" "Set power/control to 'on'"
fi

if [[ -f "$USB_PATH/power/autosuspend" ]]; then
    echo "-1" | tee "$USB_PATH/power/autosuspend" > /dev/null
    log "SUCCESS" "Set autosuspend to -1 (disabled)"
fi

# Also disable autosuspend_delay_ms if it exists
if [[ -f "$USB_PATH/power/autosuspend_delay_ms" ]]; then
    echo "-1" | tee "$USB_PATH/power/autosuspend_delay_ms" > /dev/null
    log "SUCCESS" "Set autosuspend_delay_ms to -1"
fi

# Verify settings
log "INFO" "Verifying new settings..."
echo
log "INFO:!ts" "Power control: $(cat "$USB_PATH/power/control" 2>/dev/null || echo 'N/A')"
log "INFO:!ts" "Autosuspend: $(cat "$USB_PATH/power/autosuspend" 2>/dev/null || echo 'N/A')"
log "INFO:!ts" "Autosuspend delay (ms): $(cat "$USB_PATH/power/autosuspend_delay_ms" 2>/dev/null || echo 'N/A')"
echo

log "SUCCESS" "Coral TPU power management settings updated"
log "INFO" "These settings will persist until reboot"
echo

# Detect divtools structure and create permanent udev rule
HOSTNAME=$(hostname)
log "INFO" "Detecting divtools directory structure..."

# Try to find the divtools docker sites directory
DIVTOOLS_BASE="/home/divix/divtools"
SITE_DIRS=("$DIVTOOLS_BASE/docker/sites"/s*/*/frigate/rules.d)

# Find the matching site directory for this hostname
RULES_DIR=""
for dir in "${SITE_DIRS[@]}"; do
    if [[ -d "$dir" ]] && [[ "$dir" == *"/$HOSTNAME/"* ]]; then
        RULES_DIR="$dir"
        break
    fi
done

# If not found, try to create it
if [[ -z "$RULES_DIR" ]]; then
    # Try to find any site directory matching this hostname
    for site_dir in "$DIVTOOLS_BASE/docker/sites"/s*/*; do
        if [[ -d "$site_dir" ]] && [[ "$(basename "$site_dir")" == "$HOSTNAME" ]]; then
            RULES_DIR="$site_dir/frigate/rules.d"
            mkdir -p "$RULES_DIR"
            log "INFO" "Created rules.d directory: $RULES_DIR"
            break
        fi
    done
fi

if [[ -z "$RULES_DIR" ]]; then
    log "WARN" "Could not find divtools site directory for hostname: $HOSTNAME"
    log "INFO" "Falling back to current directory"
    RULES_DIR="./rules.d"
    mkdir -p "$RULES_DIR"
fi

UDEV_RULE_FILE="$RULES_DIR/99-coral-no-autosuspend.rules"

# Create the udev rule file
log "INFO" "Creating udev rule file..."
cat > "$UDEV_RULE_FILE" <<'EOF'
# Disable USB autosuspend for Google Coral Edge TPU
# Last Updated: 11/5/2025 12:40:00 PM CST
#
# This prevents USB transfer errors and device resets that cause Frigate crashes
#
# Install to: /etc/udev/rules.d/99-coral-no-autosuspend.rules
# Then run:
#   sudo udevadm control --reload-rules
#   sudo udevadm trigger

# Coral USB Accelerator (idVendor=18d1, idProduct=9302)
SUBSYSTEM=="usb", ATTRS{idVendor}=="18d1", ATTRS{idProduct}=="9302", ATTR{power/control}="on"

# Older Coral models (if you have them)
SUBSYSTEM=="usb", ATTRS{idVendor}=="1a6e", ATTRS{idProduct}=="089a", ATTR{power/control}="on"
EOF

log "SUCCESS" "Udev rule saved to: $UDEV_RULE_FILE"
echo

# Ask if user wants to install the rule
log "HEAD" "=== PERMANENT FIX (Udev Rule) ==="
echo
log "INFO:!ts" "A udev rule has been created to make these settings permanent."
log "INFO:!ts" "The rule will be installed to: /etc/udev/rules.d/99-coral-no-autosuspend.rules"
echo

read -p "Do you want to install the udev rule now? [y/N]: " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    log "INFO" "Installing udev rule..."
    
    # Copy the rule to system location
    if cp "$UDEV_RULE_FILE" /etc/udev/rules.d/99-coral-no-autosuspend.rules 2>/dev/null; then
        log "SUCCESS" "Udev rule installed to /etc/udev/rules.d/"
        
        # Reload udev rules
        log "INFO" "Reloading udev rules..."
        if udevadm control --reload-rules 2>/dev/null; then
            log "SUCCESS" "Udev rules reloaded"
        else
            log "WARN" "Failed to reload udev rules (may need sudo)"
        fi
        
        log "INFO" "Triggering udev for USB devices..."
        if udevadm trigger 2>/dev/null; then
            log "SUCCESS" "Udev triggered"
        else
            log "WARN" "Failed to trigger udev (may need sudo)"
        fi
        
        echo
        log "SUCCESS" "Permanent fix installed! Settings will persist across reboots."
    else
        log "ERROR" "Failed to copy udev rule (may need sudo)"
        log "INFO" "You can manually install with:"
        log "INFO:!ts" "  sudo cp $UDEV_RULE_FILE /etc/udev/rules.d/"
        log "INFO:!ts" "  sudo udevadm control --reload-rules"
        log "INFO:!ts" "  sudo udevadm trigger"
    fi
else
    log "INFO" "Udev rule not installed. Settings will reset on reboot."
    log "INFO" "To install later, run:"
    log "INFO:!ts" "  sudo cp $UDEV_RULE_FILE /etc/udev/rules.d/"
    log "INFO:!ts" "  sudo udevadm control --reload-rules"
    log "INFO:!ts" "  sudo udevadm trigger"
fi
echo
