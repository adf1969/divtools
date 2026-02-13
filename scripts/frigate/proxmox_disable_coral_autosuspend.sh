#!/bin/bash
# Quick Coral USB Autosuspend Fix - Proxmox Host Version
# Last Updated: 11/11/2025 12:15:00 PM CST
#
# Run this on the Proxmox host (tnfs1) to disable USB autosuspend 
# preventing Coral TPU disconnections in passthrough VMs
#
# Usage: ssh root@tnfs1 'bash -s' < this_script
# Or: bash proxmox_disable_coral_autosuspend.sh

if [[ ! -f /etc/pve/.version ]]; then
    echo "[WARN] This script is intended for Proxmox hosts"
    echo "[INFO] Continuing anyway..."
fi

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║   Disable USB Autosuspend on Proxmox Host                ║"
echo "║   (Quick fix for Coral TPU passthrough issues)           ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

echo "Current autosuspend setting:"
CURRENT=$(cat /sys/module/usbcore/parameters/autosuspend 2>/dev/null)
echo "  usbcore.autosuspend = $CURRENT"
echo ""

if [[ "$CURRENT" == "-1" ]]; then
    echo "✓ Autosuspend already disabled!"
    exit 0
fi

echo "Disabling USB autosuspend..."
if echo "-1" | tee /sys/module/usbcore/parameters/autosuspend > /dev/null 2>&1; then
    echo "✓ Setting applied successfully"
    echo ""
    echo "New value:"
    echo "  usbcore.autosuspend = $(cat /sys/module/usbcore/parameters/autosuspend)"
else
    echo "✗ Failed to set value (may need sudo)"
    exit 1
fi

echo ""
echo "Verifying Coral device..."
if lsusb | grep -q "18d1:9302"; then
    echo "✓ Coral TPU is present: $(lsusb | grep '18d1')"
else
    echo "⚠ Coral TPU not currently detected (may be in reset state)"
fi

echo ""
echo "✓ Autosuspend disabled on Proxmox host"
echo ""
echo "NOTE: This change is temporary and will reset on reboot."
echo "To make it permanent, update Proxmox kernel parameters:"
echo "  Edit: /etc/kernel/cmdline"
echo "  Add:  usbcore.autosuspend=-1"
echo "  Then reboot the host"
