#!/bin/bash
# Coral USB Device Transition Test
# Quick test to verify 1a6e:089a → 18d1:9302 transition behavior
# Run this on your VM to understand the device state changes
# Last Updated: 11/30/2025 1:50:00 PM CST

set -e

BOOTLOADER_VID_PID="1a6e:089a"
OPERATIONAL_VID_PID="18d1:9302"

RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[36m'
NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Coral TPU USB Device Transition Test                          ║${NC}"
echo -e "${BLUE}║  Understanding 1a6e:089a → 18d1:9302 Transition               ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

check_device() {
    local vid_pid="$1"
    local mode_name="$2"
    
    echo -e "${BLUE}[CHECK]${NC} Looking for $mode_name ($vid_pid)..."
    
    if lsusb -d "$vid_pid" >/dev/null 2>&1; then
        local full_info=$(lsusb -d "$vid_pid")
        echo -e "${GREEN}✓ FOUND${NC}: $full_info"
        return 0
    else
        echo -e "${YELLOW}✗ NOT FOUND${NC}"
        return 1
    fi
}

get_device_details() {
    local vid_pid="$1"
    
    if lsusb -d "$vid_pid" -v 2>/dev/null | head -20; then
        return 0
    fi
    return 1
}

monitor_transition() {
    local bootloader="$BOOTLOADER_VID_PID"
    local operational="$OPERATIONAL_VID_PID"
    local timeout=30
    local elapsed=0
    local interval=2
    
    echo ""
    echo -e "${YELLOW}[MONITOR]${NC} Watching for device transition..."
    echo "Press Ctrl+C to stop monitoring"
    echo ""
    
    while [[ $elapsed -lt $timeout ]]; do
        echo -n "[$elapsed/$timeout s] "
        
        # Check both states
        bootloader_found=0
        operational_found=0
        
        if lsusb -d "$bootloader" >/dev/null 2>&1; then
            bootloader_found=1
            echo -ne "${YELLOW}BOOTLOADER (089a)${NC} "
        fi
        
        if lsusb -d "$operational" >/dev/null 2>&1; then
            operational_found=1
            echo -ne "${GREEN}OPERATIONAL (9302)${NC} "
        fi
        
        if [[ $bootloader_found -eq 0 && $operational_found -eq 0 ]]; then
            echo -ne "${RED}NOT FOUND${NC} "
        fi
        
        echo ""
        
        # If we've seen the transition, report it
        if [[ $bootloader_found -eq 0 && $operational_found -eq 1 ]]; then
            echo -e "${GREEN}✓ TRANSITION COMPLETE!${NC} Device is now operational (9302)"
            return 0
        fi
        
        sleep "$interval"
        elapsed=$((elapsed + interval))
    done
    
    echo -e "${YELLOW}⚠ Timeout reached after ${timeout}s${NC}"
    return 1
}

show_what_this_means() {
    cat << 'EOF'

════════════════════════════════════════════════════════════════════════════════
WHAT'S HAPPENING HERE:
════════════════════════════════════════════════════════════════════════════════

When you connect (or reboot with) the Coral TPU to your VM via USB passthrough:

PHASE 1 (Bootloader Mode - 1a6e:089a)
  └─ Device enumerated but firmware NOT loaded yet
  └─ This happens within ~1 second of VM boot
  └─ Device is "visible" but can't be used for TPU work
  └─ Frigate will crash if it tries to use TPU in this state

PHASE 2 (Firmware Loading - ~5-10 seconds)
  └─ Linux udev rules detect 1a6e:089a device
  └─ udev runs libedgetpu firmware loader (from package libedgetpu1-std)
  └─ Firmware file is transferred to device over USB
  └─ Device re-enumerates (disconnects & reconnects)

PHASE 3 (Operational Mode - 18d1:9302)
  └─ Device firmware is loaded
  └─ Device is now ready for TPU work
  └─ Frigate can successfully initialize and use device
  └─ This is when you want Frigate to start

════════════════════════════════════════════════════════════════════════════════
WHY THIS MATTERS FOR YOUR SETUP:
════════════════════════════════════════════════════════════════════════════════

The Problem:
  - If Frigate starts in Phase 1 or 2, it crashes (TPU not available)
  - Currently you're seeing: "Frigate crashes for a while waiting for TPU"
  - This is exactly what's happening—Frigate starts too early

The Solution:
  - Use coral_firmware_loader.sh to wait for Phase 3 to complete
  - Then start Frigate
  - Frigate starts cleanly, finds TPU immediately

════════════════════════════════════════════════════════════════════════════════
WHAT YOU SHOULD EXPECT:
════════════════════════════════════════════════════════════════════════════════

✓ GOOD (with firmware loader installed):
  1. VM boots
  2. systemd starts coral_firmware_loader.sh
  3. Device transitions 089a → 9302 (takes ~5-10s)
  4. Script exits successfully
  5. Docker/Frigate services start
  6. Frigate initializes cleanly, finds TPU ready
  7. No crashes, no errors

✗ PROBLEMATIC (without firmware loader):
  1. VM boots
  2. Device shows as 089a
  3. Docker services start immediately
  4. Frigate tries to initialize TPU (not ready yet)
  5. Frigate crashes with libusb/EdgeTPU errors
  6. After 5-10s, device transitions to 9302
  7. Frigate restarts, finds TPU now ready
  8. Frigate works (but with initial crash period)

════════════════════════════════════════════════════════════════════════════════
EOF
}

# Main execution
echo -e "${BLUE}STEP 1: Check for Bootloader Mode (1a6e:089a)${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if check_device "$BOOTLOADER_VID_PID" "Bootloader"; then
    bootloader_present=1
else
    bootloader_present=0
fi

echo ""
echo -e "${BLUE}STEP 2: Check for Operational Mode (18d1:9302)${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if check_device "$OPERATIONAL_VID_PID" "Operational"; then
    operational_present=1
else
    operational_present=0
fi

echo ""
echo -e "${BLUE}STEP 3: Current Status Summary${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ $operational_present -eq 1 ]]; then
    echo -e "${GREEN}✓ Coral TPU is OPERATIONAL (18d1:9302)${NC}"
    echo "  → Device is ready for use"
    echo "  → Frigate can start normally"
elif [[ $bootloader_present -eq 1 ]]; then
    echo -e "${YELLOW}⚠ Coral TPU is in BOOTLOADER mode (1a6e:089a)${NC}"
    echo "  → Firmware is loading or not yet loaded"
    echo "  → Device will transition to 9302 in a few seconds"
    echo "  → Frigate should wait before starting"
else
    echo -e "${RED}✗ Coral TPU NOT FOUND${NC}"
    echo "  → Check USB passthrough on Proxmox"
    echo "  → Check powered USB hub connection"
    echo "  → Check dmesg on Proxmox host"
fi

echo ""
echo -e "${BLUE}STEP 4: Device Transition Behavior${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ $bootloader_present -eq 1 && $operational_present -eq 0 ]]; then
    echo -e "${YELLOW}Device appears to be in bootloader mode.${NC}"
    echo "Let's watch for the transition to 9302 mode..."
    echo ""
    
    # Trigger udev in case it hasn't run yet
    echo -e "${BLUE}[TRIGGER]${NC} Triggering udev to load firmware..."
    sudo udevadm control --reload 2>/dev/null || true
    sudo udevadm trigger --subsystem-match=usb --action=add 2>/dev/null || true
    sleep 2
    
    monitor_transition
elif [[ $operational_present -eq 1 ]]; then
    echo -e "${GREEN}✓ Device is already operational (9302)${NC}"
    echo "  → No transition needed"
    echo "  → This is expected if device was on for a while"
fi

echo ""
show_what_this_means

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Next Steps:${NC}"
echo "  1. Review the explanation above"
echo "  2. Install the firmware loader on your VM:"
echo "     sudo coral_firmware_loader.sh --install"
echo "  3. Reboot your VM to test"
echo "  4. Check status: sudo systemctl status coral-firmware-loader"
echo "  5. View logs: sudo journalctl -u coral-firmware-loader -n 30"
echo -e "${BLUE}════════════════════════════════════════════════════════════════════════════════════${NC}"
