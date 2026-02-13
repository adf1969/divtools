#!/bin/bash
# Dynamic USB TPU Passthrough Hook for LXC
# Last Updated: 9/21/2025 11:28 PM CDT

# Source logging function
if [ -f "/opt/divtools/scripts/util/logging.sh" ]; then
  source "/opt/divtools/scripts/util/logging.sh"
else
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] Logging script not found at /opt/divtools/scripts/util/logging.sh" >> /var/log/lxc_usb_hook.log
  exit 1
fi

log "INFO" "Running USB TPU hook"
if ! command -v lsusb >/dev/null 2>&1; then
  log "ERROR" "lsusb not found"
  exit 1
fi
if ! command -v stat >/dev/null 2>&1; then
  log "ERROR" "stat not found"
  exit 1
fi
VENDOR_IDS=("1a6e" "18d1")
PRODUCT_IDS=("089a" "9302")
USB_DEVICE=""
for i in "${!VENDOR_IDS[@]}"; do
  USB_DEVICE=$(lsusb -d ${VENDOR_IDS[$i]}:${PRODUCT_IDS[$i]} | awk '{print $2 "/" $4}' | sed 's/://')
  if [ -n "$USB_DEVICE" ]; then
    log "INFO" "TPU found with ID ${VENDOR_IDS[$i]}:${PRODUCT_IDS[$i]}"
    break
  fi
done
if [ -n "$USB_DEVICE" ]; then
  mkdir -p ${LXC_ROOTFS_MOUNT}/dev/bus/usb/${USB_DEVICE%/*}
  if [ -e "/dev/bus/usb/$USB_DEVICE" ]; then
    MAJOR=$(stat -c %t /dev/bus/usb/$USB_DEVICE)
    MINOR=$(stat -c %T /dev/bus/usb/$USB_DEVICE)
    # Convert hex to decimal
    MAJOR_DEC=$(printf "%d" 0x${MAJOR:-0} 2>/dev/null)
    MINOR_DEC=$(printf "%d" 0x${MINOR:-0} 2>/dev/null)
    if [ "$MAJOR_DEC" != "189" ]; then
      log "ERROR" "Invalid major number for /dev/bus/usb/$USB_DEVICE: $MAJOR_DEC (expected 189)"
      exit 1
    fi
    if [[ ! "$MINOR_DEC" =~ ^[0-9]+$ ]]; then
      log "ERROR" "Invalid minor number for /dev/bus/usb/$USB_DEVICE: $MINOR"
      exit 1
    fi
    log "INFO" "Device node /dev/bus/usb/$USB_DEVICE already exists with major: $MAJOR_DEC, minor: $MINOR_DEC"
  else
    log "ERROR" "Device /dev/bus/usb/$USB_DEVICE does not exist"
    exit 1
  fi
  chmod 666 ${LXC_ROOTFS_MOUNT}/dev/bus/usb/$USB_DEVICE
  if [ $? -ne 0 ]; then
    log "ERROR" "Failed to set permissions (chmod) for /dev/bus/usb/$USB_DEVICE"
    exit 1
  fi
  chown root:plugdev ${LXC_ROOTFS_MOUNT}/dev/bus/usb/$USB_DEVICE
  if [ $? -ne 0 ]; then
    log "ERROR" "Failed to set permissions (chown) for /dev/bus/usb/$USB_DEVICE"
    exit 1
  fi
  log "INFO" "TPU mounted at /dev/bus/usb/$USB_DEVICE"
else
  log "ERROR" "TPU not found for IDs 1a6e:089a or 18d1:9302"
  exit 1
fi