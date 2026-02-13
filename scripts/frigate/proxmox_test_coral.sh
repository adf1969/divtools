#!/bin/bash
# Proxmox Test & Diagnostic for Coral USB Passthrough Issues
# Run on tnfs1 Proxmox host
# Last Updated: 11/11/2025 11:58:00 AM CST

if [[ ! -f /etc/pve/.version ]]; then
    echo "[ERROR] This script must run on Proxmox host"
    exit 1
fi

TEST_NAME="${1:?Usage: $0 <test_name>}"
MONITOR_DURATION=120

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║   Proxmox Coral USB Passthrough Testing & Diagnostics    ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
echo "Hostname: $(hostname)"
echo "Test: $TEST_NAME"
echo "Timestamp: $(date)"
echo ""

# Check for Coral
check_coral_host() {
    if lsusb | grep -q "18d1:9302"; then
        return 0
    fi
    return 1
}

case "$TEST_NAME" in
    
    status)
        echo "=== Current Status ==="
        echo ""
        
        echo "Coral device on host:"
        if check_coral_host; then
            lsusb | grep "18d1"
            echo "✓ PRESENT"
        else
            echo "✗ NOT PRESENT"
        fi
        echo ""
        
        echo "VM gpu1-75 status:"
        qm status 275 2>/dev/null || echo "Cannot query VM status"
        echo ""
        
        echo "Host usbcore.autosuspend:"
        cat /sys/module/usbcore/parameters/autosuspend
        echo ""
        
        echo "Recent USB events (last 20):"
        dmesg | grep -i "usb\|xhci" | tail -20
        echo ""
        ;;
        
    disable-autosuspend-proxmox)
        echo "=== Test: Disable USB Autosuspend on Proxmox Host ==="
        echo ""
        echo "Current setting: $(cat /sys/module/usbcore/parameters/autosuspend)"
        echo ""
        
        echo "[INFO] Setting autosuspend to -1..."
        if echo "-1" | tee /sys/module/usbcore/parameters/autosuspend > /dev/null; then
            echo "[SUCCESS] Proxmox autosuspend disabled"
        else
            echo "[ERROR] Failed to disable (needs sudo)"
            exit 1
        fi
        
        echo ""
        echo "New setting: $(cat /sys/module/usbcore/parameters/autosuspend)"
        echo ""
        
        # Verify Coral is still present
        echo "Verifying Coral is present..."
        sleep 2
        if lsusb | grep -q "18d1:9302"; then
            echo "[SUCCESS] ✓ Coral still detected after autosuspend fix"
        else
            echo "[WARN] ✗ Coral not detected - may need device reset"
        fi
        ;;
        
    reset-coral-proxmox)
        echo "=== Test: Reset Coral Device on Proxmox Host ==="
        echo ""
        
        if ! check_coral_host; then
            echo "[ERROR] Coral not present on host"
            exit 1
        fi
        
        echo "Current Coral device:"
        lsusb | grep "18d1"
        echo ""
        
        # Find in sysfs
        for device_path in /sys/bus/usb/devices/*; do
            [[ ! -d "$device_path" ]] && continue
            
            if [[ -f "$device_path/idVendor" && -f "$device_path/idProduct" ]]; then
                VENDOR=$(cat "$device_path/idVendor" 2>/dev/null)
                PRODUCT=$(cat "$device_path/idProduct" 2>/dev/null)
                
                if [[ "$VENDOR" == "18d1" && "$PRODUCT" == "9302" ]]; then
                    DEVICE_ID=$(basename "$device_path")
                    echo "[INFO] Found Coral at: $DEVICE_ID ($device_path)"
                    
                    echo "[INFO] Step 1: Deauthorizing device..."
                    if echo 0 > "$device_path/authorized" 2>/dev/null; then
                        echo "[SUCCESS] Device deauthorized"
                        sleep 3
                    else
                        echo "[ERROR] Failed to deauthorize"
                        exit 1
                    fi
                    
                    echo "[INFO] Step 2: Reauthorizing device..."
                    if echo 1 > "$device_path/authorized" 2>/dev/null; then
                        echo "[SUCCESS] Device reauthorized"
                        sleep 3
                    else
                        echo "[ERROR] Failed to reauthorize"
                        exit 1
                    fi
                    
                    break
                fi
            fi
        done
        
        # Verify
        echo "[INFO] Verifying Coral..."
        sleep 2
        if lsusb | grep -q "18d1:9302"; then
            echo "[SUCCESS] ✓ Coral restored!"
            lsusb | grep "18d1"
        else
            echo "[ERROR] ✗ Coral not detected after reset"
            exit 1
        fi
        ;;
        
    monitor)
        echo "=== Monitoring Mode (for $MONITOR_DURATION seconds) ==="
        echo ""
        
        CHECK_INTERVAL=10
        ELAPSED=0
        DETECTIONS=0
        TOTAL_CHECKS=0
        
        while [[ $ELAPSED -lt $MONITOR_DURATION ]]; do
            ((TOTAL_CHECKS++))
            
            if check_coral_host; then
                ((DETECTIONS++))
                echo "[$(date '+%H:%M:%S')] ✓ Coral present"
            else
                echo "[$(date '+%H:%M:%S')] ✗ Coral NOT present"
            fi
            
            sleep "$CHECK_INTERVAL"
            ((ELAPSED += CHECK_INTERVAL))
        done
        
        UPTIME=$((DETECTIONS * 100 / TOTAL_CHECKS))
        echo ""
        echo "=== Results ==="
        echo "Detection rate: $UPTIME% ($DETECTIONS/$TOTAL_CHECKS)"
        
        if [[ $UPTIME -eq 100 ]]; then
            echo "Status: ✓ STABLE"
        elif [[ $UPTIME -ge 80 ]]; then
            echo "Status: ⚠ MOSTLY STABLE"
        else
            echo "Status: ✗ UNSTABLE"
        fi
        ;;
        
    list-tests)
        echo "Available tests:"
        echo "  status                    - Show current status"
        echo "  disable-autosuspend-proxmox - Disable USB autosuspend on host"
        echo "  reset-coral-proxmox       - Reset Coral device on host"
        echo "  monitor                   - Monitor for disconnections"
        ;;
        
    *)
        echo "[ERROR] Unknown test: $TEST_NAME"
        echo ""
        $0 list-tests
        exit 1
        ;;
        
esac

echo ""
echo "Test completed: $(date)"
