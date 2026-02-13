#!/bin/bash
# Coral USB TPU Diagnostic Tool - Comprehensive Testing Suite
# Last Updated: 11/11/2025 11:50:00 AM CST
# Run this to collect detailed diagnostic data about USB passthrough issues

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../util/logging.sh"

OUTPUT_DIR="${1:-.}"
HOSTNAME=$(hostname)
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="$OUTPUT_DIR/coral_diagnostics_${HOSTNAME}_${TIMESTAMP}.txt"

{
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║        Coral USB TPU Diagnostic Report                    ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""
    echo "Hostname: $HOSTNAME"
    echo "Timestamp: $(date)"
    echo "System: $(uname -a)"
    echo ""
    
    # === SECTION 1: USB Device Detection ===
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║ SECTION 1: USB Device Detection                           ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""
    
    echo "=== lsusb Output ==="
    lsusb 2>&1 || echo "lsusb failed"
    echo ""
    
    echo "=== Coral Device Search (18d1:9302 or 1a6e:089a) ==="
    if lsusb -d 18d1:9302 2>/dev/null; then
        echo "Found: Google Coral USB Accelerator (18d1:9302)"
    elif lsusb -d 1a6e:089a 2>/dev/null; then
        echo "Found: Coral USB Accelerator (1a6e:089a)"
    else
        echo "NOT FOUND: Coral device not detected via lsusb"
    fi
    echo ""
    
    echo "=== Sysfs Device Tree ==="
    for device_path in /sys/bus/usb/devices/*; do
        [[ ! -d "$device_path" ]] && continue
        if [[ -f "$device_path/idVendor" && -f "$device_path/idProduct" ]]; then
            VENDOR=$(cat "$device_path/idVendor" 2>/dev/null)
            PRODUCT=$(cat "$device_path/idProduct" 2>/dev/null)
            if [[ "$VENDOR" == "18d1" || "$VENDOR" == "1a6e" ]]; then
                DEVICE_ID=$(basename "$device_path")
                echo "Found: $DEVICE_ID (${VENDOR}:${PRODUCT})"
                echo "  Path: $device_path"
                echo "  Speed: $(cat $device_path/speed 2>/dev/null || echo 'N/A')"
                echo "  State: $(cat $device_path/state 2>/dev/null || echo 'N/A')"
            fi
        fi
    done
    echo ""
    
    # === SECTION 2: Power Management Settings ===
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║ SECTION 2: Power Management Settings                      ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""
    
    for device_path in /sys/bus/usb/devices/*; do
        [[ ! -d "$device_path" ]] && continue
        if [[ -f "$device_path/idVendor" && -f "$device_path/idProduct" ]]; then
            VENDOR=$(cat "$device_path/idVendor" 2>/dev/null)
            PRODUCT=$(cat "$device_path/idProduct" 2>/dev/null)
            if [[ "$VENDOR" == "18d1" || "$VENDOR" == "1a6e" ]]; then
                DEVICE_ID=$(basename "$device_path")
                echo "=== Power Settings for $DEVICE_ID ==="
                
                # Power control
                if [[ -f "$device_path/power/control" ]]; then
                    echo "  power/control: $(cat $device_path/power/control)"
                else
                    echo "  power/control: NOT AVAILABLE"
                fi
                
                # Autosuspend
                if [[ -f "$device_path/power/autosuspend" ]]; then
                    echo "  power/autosuspend: $(cat $device_path/power/autosuspend) seconds"
                else
                    echo "  power/autosuspend: NOT AVAILABLE"
                fi
                
                # Autosuspend delay ms
                if [[ -f "$device_path/power/autosuspend_delay_ms" ]]; then
                    echo "  power/autosuspend_delay_ms: $(cat $device_path/power/autosuspend_delay_ms) ms"
                else
                    echo "  power/autosuspend_delay_ms: NOT AVAILABLE"
                fi
                
                # Active duration
                if [[ -f "$device_path/power/active_duration" ]]; then
                    echo "  power/active_duration: $(cat $device_path/power/active_duration) ms"
                fi
                
                echo ""
            fi
        fi
    done
    
    # === SECTION 3: Kernel Parameters ===
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║ SECTION 3: Kernel Parameters                              ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""
    
    if [[ -f /sys/module/usbcore/parameters/autosuspend ]]; then
        echo "usbcore.autosuspend: $(cat /sys/module/usbcore/parameters/autosuspend)"
    fi
    
    if [[ -f /sys/module/usbhid/parameters/mousepoll ]]; then
        echo "usbhid.mousepoll: $(cat /sys/module/usbhid/parameters/mousepoll)"
    fi
    
    echo ""
    
    # === SECTION 4: Recent USB Events (Kernel Logs) ===
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║ SECTION 4: Recent USB Events                              ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""
    
    echo "=== Last 50 USB-related kernel messages ==="
    dmesg 2>/dev/null | grep -i "usb\|xhci\|coral\|18d1\|1a6e" | tail -50 || echo "dmesg not available (may need sudo)"
    echo ""
    
    # === SECTION 5: Container-specific diagnostics (if on VM) ===
    if docker ps >/dev/null 2>&1; then
        echo "╔═══════════════════════════════════════════════════════════╗"
        echo "║ SECTION 5: Docker/Container Diagnostics                   ║"
        echo "╚═══════════════════════════════════════════════════════════╝"
        echo ""
        
        echo "=== Frigate Container Status ==="
        docker ps --filter "name=frigate" --format "table {{.ID}}\t{{.Status}}\t{{.Names}}" 2>/dev/null || echo "Docker not available"
        echo ""
        
        echo "=== USB Devices Visible Inside Frigate Container ==="
        docker exec frigate lsusb 2>/dev/null | grep -i "18d1\|1a6e" || echo "Coral not visible in container (or container not running)"
        echo ""
        
        echo "=== Recent Frigate Log Entries (EdgeTPU/Coral errors) ==="
        docker logs frigate --since 5m 2>&1 | grep -i "edgetpu\|coral\|failed.*delegate\|no.*device" | tail -30 || echo "No recent Coral errors found"
        echo ""
        
        echo "=== Frigate Configuration (detector section) ==="
        docker exec frigate cat /config/config.yml 2>/dev/null | grep -A 20 "detectors:" | head -30 || echo "Could not read config"
        echo ""
    fi
    
    # === SECTION 6: Proxmox VM Configuration (if on VM) ===
    if [[ -f /etc/pve/.version ]]; then
        echo "╔═══════════════════════════════════════════════════════════╗"
        echo "║ SECTION 6: Proxmox VM Configuration                       ║"
        echo "╚═══════════════════════════════════════════════════════════╝"
        echo ""
        echo "This appears to be a Proxmox host, not a VM"
        echo ""
    else
        # Try to detect if running in a Proxmox VM
        if grep -q "qemu" /proc/cpuinfo 2>/dev/null; then
            echo "╔═══════════════════════════════════════════════════════════╗"
            echo "║ SECTION 6: Virtual Machine Diagnostics                    ║"
            echo "╚═══════════════════════════════════════════════════════════╝"
            echo ""
            echo "Detected: Running in virtual machine (likely Proxmox KVM)"
            echo ""
        fi
    fi
    
    # === SECTION 7: System Load and Performance ===
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║ SECTION 7: System Load and Performance                    ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""
    
    echo "=== Current Load Average ==="
    cat /proc/loadavg
    echo ""
    
    echo "=== Memory Usage ==="
    free -h 2>/dev/null || cat /proc/meminfo | head -5
    echo ""
    
    echo "=== Disk Space ==="
    df -h / 2>/dev/null || echo "df not available"
    echo ""
    
    # === SECTION 8: Summary and Observations ===
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║ SECTION 8: Analysis Summary                               ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""
    
    # Check if Coral is detected
    if lsusb -d 18d1:9302 2>/dev/null || lsusb -d 1a6e:089a 2>/dev/null; then
        echo "✓ Coral device is CURRENTLY DETECTED"
    else
        echo "✗ Coral device is NOT CURRENTLY DETECTED (may be in disconnect cycle)"
    fi
    echo ""
    
    # Check power management
    for device_path in /sys/bus/usb/devices/*; do
        [[ ! -d "$device_path" ]] && continue
        if [[ -f "$device_path/idVendor" && -f "$device_path/idProduct" ]]; then
            VENDOR=$(cat "$device_path/idVendor" 2>/dev/null)
            PRODUCT=$(cat "$device_path/idProduct" 2>/dev/null)
            if [[ "$VENDOR" == "18d1" || "$VENDOR" == "1a6e" ]]; then
                CONTROL=$(cat "$device_path/power/control" 2>/dev/null)
                AUTOSUSPEND=$(cat "$device_path/power/autosuspend" 2>/dev/null)
                
                if [[ "$CONTROL" == "on" && "$AUTOSUSPEND" == "-1" ]]; then
                    echo "✓ Power management is OPTIMIZED for Coral"
                else
                    echo "⚠ Power management may need optimization"
                    echo "  - power/control: $CONTROL (should be 'on')"
                    echo "  - power/autosuspend: $AUTOSUSPEND (should be '-1')"
                fi
            fi
        fi
    done
    echo ""
    
    # Final notes
    echo "═══════════════════════════════════════════════════════════════"
    echo "Next steps:"
    echo "1. Review this report for power management settings"
    echo "2. Check kernel logs for USB errors or resets"
    echo "3. Review Frigate logs for EdgeTPU detector failures"
    echo "4. If optimization needed, run: fix_coral_usb_autosuspend.sh"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "Report generated: $(date)"
    
} | tee "$REPORT_FILE"

log "SUCCESS" "Diagnostic report saved to: $REPORT_FILE"
