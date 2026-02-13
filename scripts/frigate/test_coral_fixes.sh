#!/bin/bash
# Coral USB TPU Testing & Fix Verification Script
# Last Updated: 11/11/2025 11:55:00 AM CST
#
# This script helps test individual fixes and measure their impact
# Run this to apply a fix, then monitor for improvements

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../util/logging.sh"

TEST_NAME="${1:?Usage: $0 <test_name> [parameters]}"
MONITOR_DURATION=120  # Monitor for 2 minutes after applying fix

shift  # Remove first argument

log "HEAD" "╔═══════════════════════════════════════════════════════════╗"
log "HEAD" "║     Coral USB TPU Fix Testing & Verification              ║"
log "HEAD" "╚═══════════════════════════════════════════════════════════╝"

log "INFO" "Test: $TEST_NAME"
log "INFO" "Monitor duration: $MONITOR_DURATION seconds"
log "INFO" "Timestamp: $(date)"
echo ""

# Function to check if Coral is visible
check_coral() {
    if lsusb -d 18d1:9302 2>/dev/null || lsusb -d 1a6e:089a 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to check Frigate health
check_frigate() {
    if docker ps | grep -q "frigate.*Up"; then
        return 0
    else
        return 1
    fi
}

# Function to test Coral detection in Frigate
check_frigate_coral() {
    local recent_logs=$(docker logs frigate --since 30s 2>&1 | grep -i "coral\|edgetpu" | tail -5)
    if echo "$recent_logs" | grep -q "error\|failed\|no.*device"; then
        return 1  # Errors found
    else
        return 0  # No errors
    fi
}

# Before state
log "INFO:!ts" "BEFORE STATE:"
if check_coral; then
    log "SUCCESS:!ts" "  ✓ Coral device detected"
else
    log "ERROR:!ts" "  ✗ Coral device NOT detected"
fi

echo ""

case "$TEST_NAME" in
    
    test-disable-autosuspend)
        log "HEAD" "TEST 1: Disable USB Autosuspend at Kernel Level"
        echo ""
        log "INFO" "This prevents the kernel from suspending USB ports"
        log "INFO" "Current autosuspend setting: $(cat /sys/module/usbcore/parameters/autosuspend 2>/dev/null || echo 'N/A')"
        echo ""
        
        log "WARN" "Applying fix: Setting usbcore.autosuspend = -1"
        if echo "-1" | sudo tee /sys/module/usbcore/parameters/autosuspend > /dev/null 2>&1; then
            log "SUCCESS" "Autosuspend disabled"
            echo "-1" > /sys/module/usbcore/parameters/autosuspend 2>/dev/null || \
                echo "Note: May require sudo for persistence"
        else
            log "ERROR" "Failed to write (likely needs sudo)"
        fi
        ;;
        
    test-fix-guest-autosuspend)
        log "HEAD" "TEST 2: Fix Guest USB Autosuspend (per-device)"
        echo ""
        log "INFO" "This disables autosuspend for the Coral device specifically"
        echo ""
        
        # Find Coral and disable autosuspend
        FOUND=0
        for device_path in /sys/bus/usb/devices/*; do
            if [[ ! -d "$device_path" ]]; then
                continue
            fi
            
            if [[ -f "$device_path/idVendor" && -f "$device_path/idProduct" ]]; then
                VENDOR=$(cat "$device_path/idVendor" 2>/dev/null)
                PRODUCT=$(cat "$device_path/idProduct" 2>/dev/null)
                
                if [[ "$VENDOR" == "18d1" && "$PRODUCT" == "9302" ]] || \
                   [[ "$VENDOR" == "1a6e" && "$PRODUCT" == "089a" ]]; then
                    
                    DEVICE_ID=$(basename "$device_path")
                    FOUND=1
                    
                    log "INFO" "Found Coral at: $device_path"
                    log "WARN" "Applying fix..."
                    
                    # Disable autosuspend
                    if [[ -w "$device_path/power/autosuspend" ]]; then
                        echo "-1" > "$device_path/power/autosuspend" 2>/dev/null && \
                            log "SUCCESS" "Set autosuspend = -1" || \
                            log "ERROR" "Failed to set autosuspend (needs sudo)"
                    fi
                    
                    # Set power control to on
                    if [[ -w "$device_path/power/control" ]]; then
                        echo "on" > "$device_path/power/control" 2>/dev/null && \
                            log "SUCCESS" "Set power/control = on" || \
                            log "ERROR" "Failed to set power control (needs sudo)"
                    fi
                    
                    break
                fi
            fi
        done
        
        if [[ $FOUND -eq 0 ]]; then
            log "ERROR" "Coral device not found in sysfs"
            exit 1
        fi
        ;;
        
    test-reset-usb)
        log "HEAD" "TEST 3: USB Device Reset"
        echo ""
        log "INFO" "This performs a software reset of the Coral device"
        echo ""
        
        FOUND=0
        for device_path in /sys/bus/usb/devices/*; do
            if [[ ! -d "$device_path" ]]; then
                continue
            fi
            
            if [[ -f "$device_path/idVendor" && -f "$device_path/idProduct" ]]; then
                VENDOR=$(cat "$device_path/idVendor" 2>/dev/null)
                PRODUCT=$(cat "$device_path/idProduct" 2>/dev/null)
                
                if [[ "$VENDOR" == "18d1" && "$PRODUCT" == "9302" ]] || \
                   [[ "$VENDOR" == "1a6e" && "$PRODUCT" == "089a" ]]; then
                    
                    DEVICE_ID=$(basename "$device_path")
                    FOUND=1
                    
                    log "INFO" "Found Coral at: $DEVICE_ID"
                    log "WARN" "Resetting device..."
                    
                    if [[ -w "$device_path/authorized" ]]; then
                        echo 0 > "$device_path/authorized" 2>/dev/null
                        log "INFO" "Deauthorized device"
                        sleep 2
                        
                        echo 1 > "$device_path/authorized" 2>/dev/null
                        log "SUCCESS" "Device reauthorized"
                    else
                        log "ERROR" "Cannot authorize device (needs sudo)"
                    fi
                    
                    break
                fi
            fi
        done
        
        if [[ $FOUND -eq 0 ]]; then
            log "ERROR" "Coral device not found"
            exit 1
        fi
        ;;
        
    monitor)
        log "HEAD" "TEST: Monitoring Mode"
        echo ""
        log "INFO" "Monitoring Coral status for $MONITOR_DURATION seconds"
        echo ""
        ;;
        
    *)
        log "ERROR" "Unknown test: $TEST_NAME"
        log "INFO" "Available tests:"
        log "INFO:!ts" "  test-disable-autosuspend     - Disable kernel autosuspend globally"
        log "INFO:!ts" "  test-fix-guest-autosuspend   - Disable autosuspend for Coral device"
        log "INFO:!ts" "  test-reset-usb               - Perform USB device reset"
        log "INFO:!ts" "  monitor                      - Just monitor status"
        exit 1
        ;;
esac

echo ""
log "INFO" "Waiting 5 seconds for device to settle..."
sleep 5

# === MONITORING PHASE ===
log "HEAD" "=== MONITORING FOR $MONITOR_DURATION SECONDS ==="
echo ""

CHECK_INTERVAL=10
ELAPSED=0
CORAL_DETECTED=0
FRIGATE_HEALTHY=0

while [[ $ELAPSED -lt $MONITOR_DURATION ]]; do
    REMAINING=$((MONITOR_DURATION - ELAPSED))
    
    log "DEBUG:!ts" "[$ELAPSED/$MONITOR_DURATION] Checking status..."
    
    if check_coral; then
        log "SUCCESS:!ts" "  ✓ Coral detected"
        ((CORAL_DETECTED++))
    else
        log "ERROR:!ts" "  ✗ Coral NOT detected"
    fi
    
    if check_frigate; then
        log "SUCCESS:!ts" "  ✓ Frigate running"
        
        if check_frigate_coral; then
            log "SUCCESS:!ts" "    ✓ Coral working in Frigate"
            ((FRIGATE_HEALTHY++))
        else
            log "WARN:!ts" "    ⚠ Coral errors in Frigate logs"
        fi
    else
        log "ERROR:!ts" "  ✗ Frigate not running"
    fi
    
    sleep "$CHECK_INTERVAL"
    ((ELAPSED += CHECK_INTERVAL))
done

# === FINAL SUMMARY ===
echo ""
log "HEAD" "╔═══════════════════════════════════════════════════════════╗"
log "HEAD" "║                    Test Summary                           ║"
log "HEAD" "╚═══════════════════════════════════════════════════════════╝"

DETECTION_RATE=$((CORAL_DETECTED * 100 / (MONITOR_DURATION / CHECK_INTERVAL)))

log "INFO:!ts" "Coral detection rate: $DETECTION_RATE%"
log "INFO:!ts" "Frigate health: $FRIGATE_HEALTHY detections"

if [[ $DETECTION_RATE -eq 100 ]]; then
    log "SUCCESS" "Test PASSED - Coral stable!"
elif [[ $DETECTION_RATE -ge 80 ]]; then
    log "WARN" "Test PARTIAL - Coral mostly stable but with dropouts"
else
    log "ERROR" "Test FAILED - Coral unstable"
fi

echo ""
log "INFO" "Next step: If test passed, this fix can be made permanent"
log "INFO" "If test failed, try another fix or check Proxmox host settings"
