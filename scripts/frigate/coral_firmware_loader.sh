#!/bin/bash
# Coral TPU USB Firmware Loader for VM
# Ensures Coral USB device transitions from bootloader (1a6e:089a) to operational (18d1:9302) mode
# Designed to run at VM boot to guarantee TPU is ready before Frigate starts
# Last Updated: 11/30/2025 1:45:00 PM CST

# Source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../util/logging.sh" 2>/dev/null || true

# Default configuration
INSTALL_TARGET="/usr/local/bin/coral_firmware_loader.sh"
INSTALL_DIR="/usr/local/bin"
SYSTEMD_TARGET="/etc/systemd/system/coral-firmware-loader.service"
CONFIG_DIR="/etc/coral-tpu"
WAIT_TIMEOUT=60  # seconds to wait for device transition
RETRY_INTERVAL=2  # seconds between retry checks
DEBUG_MODE=0
TEST_MODE=0
VERBOSE=0

# Color definitions for manual coloring when logging.sh not available
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[36m'
NC='\033[0m'

# ─────────────────────────────────────────────────────────────────────────
# Logging wrapper (fallback if logging.sh not available)
# ─────────────────────────────────────────────────────────────────────────
log_msg() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        DEBUG)
            if [[ $DEBUG_MODE -eq 1 ]]; then
                echo -e "${BLUE}[DEBUG]${NC} $timestamp | $message"
            fi
            ;;
        INFO)
            echo -e "${GREEN}[INFO]${NC} $timestamp | $message"
            ;;
        WARN)
            echo -e "${YELLOW}[WARN]${NC} $timestamp | $message"
            ;;
        ERROR)
            echo -e "${RED}[ERROR]${NC} $timestamp | $message"
            ;;
        *)
            echo -e "${BLUE}[$level]${NC} $timestamp | $message"
            ;;
    esac
}

# ─────────────────────────────────────────────────────────────────────────
# Help function
# ─────────────────────────────────────────────────────────────────────────
show_help() {
    cat << 'HELPEOF'
CORAL TPU FIRMWARE LOADER (VM-SIDE)

USAGE:
  coral_firmware_loader.sh [OPTIONS]

DESCRIPTION:
  Ensures Coral TPU transitions from bootloader (1a6e:089a) to operational
  (18d1:9302) mode at VM boot. Can be run manually, via systemd, or on demand.
  
  WHY: When VM boots, USB passthrough may attach Coral in bootloader mode.
  This script ensures the firmware is loaded and device re-enumerates to 9302
  before Frigate starts, preventing initialization crashes.

OPTIONS:
  -h, --help           Show this help message and exit
  -install             Install script to system and create systemd unit
  -uninstall           Remove systemd unit and installed script
  -status              Check if Coral is present and in correct mode
  -force-reload        Force udev reload and USB re-enumeration
  -debug, --debug      Enable debug mode with detailed output
  -test, --test        Run in TEST mode (no actual changes)
  -verbose             Show detailed progress messages
  -timeout SECONDS     Change wait timeout (default: 60s)

EXAMPLES:
  # Manual check on VM
  ./coral_firmware_loader.sh -status

  # Install to system with systemd support
  sudo ./coral_firmware_loader.sh --install

  # Run with debug output
  sudo ./coral_firmware_loader.sh -debug

  # Test mode (safe, no changes)
  ./coral_firmware_loader.sh -test

  # Force reload of firmware
  sudo ./coral_firmware_loader.sh -force-reload

  # Check if device is ready (exit code 0 = ready)
  ./coral_firmware_loader.sh -status && echo "TPU ready!" || echo "TPU not ready"

WHAT IT DOES:
  STEP 1: Check if Coral is present (VID:PID 18d1:9302)
  STEP 2: If not found, check for bootloader (1a6e:089a)
  STEP 3: If in bootloader, trigger udev rules to load firmware
  STEP 4: Wait for device to re-enumerate to 9302 mode
  STEP 5: Verify EdgeTPU runtime libraries are available (optional)
  STEP 6: Exit with success when ready or timeout reached

WHY INSTALLATION IS NEEDED:
  On first run, script may need to:
  - Call udevadm (requires sudo/root)
  - Access USB device paths (requires proper permissions)
  - Run at system boot (requires systemd unit)

INSTALLATION DETAILS:
  The --install option:
  1. Copies this script to /usr/local/bin/coral_firmware_loader.sh
  2. Makes it executable
  3. Creates /etc/systemd/system/coral-firmware-loader.service
  4. Enables the systemd unit to run at boot
  5. Creates /etc/coral-tpu/ config directory
  
  After installation:
  - Script runs automatically at boot (before multi-user.target)
  - Can still be run manually for ad-hoc checks
  - Systemd journal logs all output: sudo journalctl -u coral-firmware-loader

SYSTEMD BEHAVIOR:
  The installed service:
  - Type=oneshot (runs once and exits)
  - Before=multi-user.target (runs before services start)
  - Timeout=120s (allows up to 2 minutes for device transition)
  - Logs to systemd journal
  - Can be manually triggered: sudo systemctl start coral-firmware-loader

DEBUGGING:
  View systemd logs:
    sudo journalctl -u coral-firmware-loader -n 50 --follow

  Manual test with debug:
    sudo ./coral_firmware_loader.sh -debug -verbose

  Check device status:
    lsusb -d 18d1:9302  # Operational mode (should exist)
    lsusb -d 1a6e:089a  # Bootloader mode (should NOT exist)

  Check if EdgeTPU libraries are available:
    ldconfig -p | grep edgetpu

INTEGRATION WITH FRIGATE:
  Option 1: Via systemd dependency
    Frigate systemd unit can use:
      After=coral-firmware-loader.service
  
  Option 2: Via boot delay
    Add brief delay to Frigate container startup (5-10 seconds)
    to allow systemd service to complete

  Option 3: Inside Docker Compose
    Add init delay before frigate service:
      frigate:
        healthcheck:
          test: lsusb -d 18d1:9302 > /dev/null 2>&1
          interval: 10s
          timeout: 5s
          retries: 30

SUCCESS INDICATORS:
  ✓ "Coral TPU is present in operational mode (18d1:9302)"
  ✓ Script exits with code 0
  ✓ systemd logs show completion

FAILURE INDICATORS:
  ✗ "Coral TPU not found (neither bootloader nor operational)"
  ✗ Script exits with code 1 after timeout
  ✗ systemd logs show timeout or device errors

TROUBLESHOOTING:
  Q: Script times out waiting for device
  A: Check host USB passthrough is working:
     - On Proxmox: qm config <vmid> | grep usb
     - Device may need powered USB hub

  Q: Device shows 089a but never transitions to 9302
  A: Firmware files may be missing:
     - Host check: apt list libedgetpu1-std (on Proxmox)
     - VM check: dpkg -l | grep libedgetpu
     - Install if missing: sudo apt install libedgetpu1-std

  Q: Permission denied when running
  A: Script needs root for udevadm:
     - Run with: sudo ./coral_firmware_loader.sh
     - Or after installation: systemd service has root

  Q: How do I know if it worked?
  A: Check after boot:
     - lsusb -d 18d1:9302 (should show device)
     - docker logs frigate (should NOT show EdgeTPU errors)
     - journalctl -u coral-firmware-loader (should show success)

LOCATION:
  Source: /home/divix/divtools/scripts/frigate/coral_firmware_loader.sh
  Installed: /usr/local/bin/coral_firmware_loader.sh
  Systemd: /etc/systemd/system/coral-firmware-loader.service

SEE ALSO:
  Frigate container logs: docker logs -f frigate
  Host USB checks: lsusb, dmesg
  Proxmox VM config: qm config <vmid>
  EdgeTPU status: cat /sys/kernel/debug/usb/devices | grep 18d1

HELPEOF
}

# ─────────────────────────────────────────────────────────────────────────
# Core functions
# ─────────────────────────────────────────────────────────────────────────

# Check if device is present
check_device() {
    local vid_pid="$1"
    lsusb -d "$vid_pid" >/dev/null 2>&1
    return $?
}

# Wait for device with retries
wait_for_device() {
    local vid_pid="$1"
    local timeout="$2"
    local elapsed=0
    
    log_msg "INFO" "Waiting for Coral TPU to be ready (${vid_pid})..."
    log_msg "DEBUG" "Timeout: ${timeout}s, retry interval: ${RETRY_INTERVAL}s"
    
    while [[ $elapsed -lt $timeout ]]; do
        if check_device "$vid_pid"; then
            log_msg "INFO" "✓ Coral TPU is present and ready (${vid_pid})"
            return 0
        fi
        
        log_msg "DEBUG" "Device not yet ready, retrying... [${elapsed}/${timeout}s]"
        sleep "$RETRY_INTERVAL"
        elapsed=$((elapsed + RETRY_INTERVAL))
    done
    
    log_msg "WARN" "Timeout reached after ${timeout}s waiting for device ${vid_pid}"
    return 1
}

# Trigger udev rules to load firmware
trigger_firmware_load() {
    log_msg "INFO" "Triggering udev rules to load Coral firmware..."
    
    if [[ $TEST_MODE -eq 1 ]]; then
        log_msg "INFO" "[TEST] Would run: udevadm control --reload"
        log_msg "INFO" "[TEST] Would run: udevadm trigger --subsystem-match=usb --action=add"
        return 0
    fi
    
    # Reload udev rules
    if ! sudo udevadm control --reload 2>/dev/null; then
        log_msg "WARN" "Failed to reload udev (may not be running or need sudo)"
    fi
    
    # Trigger re-enumeration of USB devices
    if ! sudo udevadm trigger --subsystem-match=usb --action=add 2>/dev/null; then
        log_msg "WARN" "Failed to trigger udev (may need sudo)"
        return 1
    fi
    
    log_msg "INFO" "Udev rules triggered, waiting for device transition..."
    return 0
}

# Check EdgeTPU runtime availability (informational)
check_edgetpu_runtime() {
    log_msg "DEBUG" "Checking for EdgeTPU runtime libraries..."
    
    if ldconfig -p 2>/dev/null | grep -q edgetpu; then
        log_msg "DEBUG" "✓ libedgetpu is available"
        return 0
    else
        log_msg "DEBUG" "⚠ libedgetpu not found in system library cache"
        log_msg "DEBUG" "  (This is OK if device is still in bootloader or libs not yet installed)"
        return 1
    fi
}

# ─────────────────────────────────────────────────────────────────────────
# Status and reporting functions
# ─────────────────────────────────────────────────────────────────────────

check_status() {
    log_msg "INFO" "Checking Coral TPU status..."
    
    local operational=0
    local bootloader=0
    
    if check_device "18d1:9302"; then
        log_msg "INFO" "✓ Coral TPU is present in operational mode (18d1:9302)"
        operational=1
    fi
    
    if check_device "1a6e:089a"; then
        log_msg "INFO" "⚠ Coral TPU is in bootloader mode (1a6e:089a)"
        log_msg "INFO" "  Firmware will be loaded automatically"
        bootloader=1
    fi
    
    if [[ $operational -eq 0 && $bootloader -eq 0 ]]; then
        log_msg "ERROR" "Coral TPU not found (neither bootloader nor operational)"
        log_msg "ERROR" "Check:"
        log_msg "ERROR" "  - USB passthrough on Proxmox (qm config <vmid> | grep usb)"
        log_msg "ERROR" "  - dmesg for USB enumeration errors"
        log_msg "ERROR" "  - Powered USB hub connection"
        return 1
    fi
    
    return 0
}

# ─────────────────────────────────────────────────────────────────────────
# Installation functions
# ─────────────────────────────────────────────────────────────────────────

do_install() {
    log_msg "INFO" "Installing Coral TPU Firmware Loader..."
    
    if [[ $TEST_MODE -eq 1 ]]; then
        log_msg "INFO" "[TEST] Would install to: $INSTALL_TARGET"
        log_msg "INFO" "[TEST] Would create systemd unit at: $SYSTEMD_TARGET"
        log_msg "INFO" "[TEST] Would create config directory: $CONFIG_DIR"
        return 0
    fi
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        log_msg "ERROR" "Installation requires root privileges"
        log_msg "ERROR" "Please run: sudo $0 --install"
        return 1
    fi
    
    # Copy script to system location
    log_msg "INFO" "Copying script to $INSTALL_TARGET..."
    if ! cp "$0" "$INSTALL_TARGET"; then
        log_msg "ERROR" "Failed to copy script to $INSTALL_TARGET"
        return 1
    fi
    chmod +x "$INSTALL_TARGET"
    log_msg "INFO" "✓ Script installed to $INSTALL_TARGET"
    
    # Create config directory
    log_msg "INFO" "Creating config directory..."
    mkdir -p "$CONFIG_DIR"
    touch "$CONFIG_DIR/installed.marker"
    log_msg "INFO" "✓ Config directory created at $CONFIG_DIR"
    
    # Create systemd service unit
    log_msg "INFO" "Creating systemd service unit..."
    cat > "$SYSTEMD_TARGET" << 'SYSTEMD_EOF'
[Unit]
Description=Coral TPU USB Firmware Loader
Documentation=https://coral.ai/docs/
Before=multi-user.target
ConditionPathExists=/dev/bus/usb
StartLimitBurst=3
StartLimitIntervalSec=300

[Service]
Type=oneshot
ExecStart=/usr/local/bin/coral_firmware_loader.sh
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal
SyslogIdentifier=coral-loader
TimeoutStartSec=120s
Environment="DEBUG_MODE=0"

[Install]
WantedBy=multi-user.target
SYSTEMD_EOF
    
    if [[ ! -f "$SYSTEMD_TARGET" ]]; then
        log_msg "ERROR" "Failed to create systemd unit at $SYSTEMD_TARGET"
        return 1
    fi
    log_msg "INFO" "✓ Systemd service unit created at $SYSTEMD_TARGET"
    
    # Reload systemd daemon
    log_msg "INFO" "Reloading systemd daemon..."
    if ! systemctl daemon-reload; then
        log_msg "ERROR" "Failed to reload systemd daemon"
        return 1
    fi
    log_msg "INFO" "✓ Systemd daemon reloaded"
    
    # Enable service
    log_msg "INFO" "Enabling Coral TPU Firmware Loader service..."
    if ! systemctl enable coral-firmware-loader.service; then
        log_msg "ERROR" "Failed to enable service"
        return 1
    fi
    log_msg "INFO" "✓ Service enabled (will run at next boot)"
    
    log_msg "INFO" "Installation complete!"
    log_msg "INFO" ""
    log_msg "INFO" "Next steps:"
    log_msg "INFO" "  1. Reboot VM to test automatic boot behavior"
    log_msg "INFO" "  2. Check status: sudo systemctl status coral-firmware-loader"
    log_msg "INFO" "  3. View logs: sudo journalctl -u coral-firmware-loader -n 20"
    log_msg "INFO" "  4. Manual test: /usr/local/bin/coral_firmware_loader.sh -status"
    
    return 0
}

do_uninstall() {
    log_msg "INFO" "Uninstalling Coral TPU Firmware Loader..."
    
    if [[ $TEST_MODE -eq 1 ]]; then
        log_msg "INFO" "[TEST] Would disable service"
        log_msg "INFO" "[TEST] Would remove: $SYSTEMD_TARGET"
        log_msg "INFO" "[TEST] Would remove: $INSTALL_TARGET"
        return 0
    fi
    
    if [[ $EUID -ne 0 ]]; then
        log_msg "ERROR" "Uninstall requires root privileges"
        log_msg "ERROR" "Please run: sudo $0 --uninstall"
        return 1
    fi
    
    # Stop and disable service
    if systemctl is-enabled coral-firmware-loader.service >/dev/null 2>&1; then
        log_msg "INFO" "Disabling service..."
        systemctl disable coral-firmware-loader.service
    fi
    
    # Remove systemd unit
    if [[ -f "$SYSTEMD_TARGET" ]]; then
        log_msg "INFO" "Removing systemd unit..."
        rm -f "$SYSTEMD_TARGET"
        systemctl daemon-reload
    fi
    
    # Remove installed script
    if [[ -f "$INSTALL_TARGET" ]]; then
        log_msg "INFO" "Removing installed script..."
        rm -f "$INSTALL_TARGET"
    fi
    
    log_msg "INFO" "Uninstall complete"
    return 0
}

# ─────────────────────────────────────────────────────────────────────────
# Main execution flow
# ─────────────────────────────────────────────────────────────────────────

main() {
    local action="load"  # default action
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            --install)
                action="install"
                shift
                ;;
            --uninstall)
                action="uninstall"
                shift
                ;;
            -status|--status)
                action="status"
                shift
                ;;
            -force-reload|--force-reload)
                action="force-reload"
                shift
                ;;
            -debug|--debug)
                DEBUG_MODE=1
                shift
                ;;
            -test|--test)
                TEST_MODE=1
                log_msg "INFO" "Running in TEST mode - no permanent changes will be made"
                shift
                ;;
            -verbose|--verbose)
                VERBOSE=1
                shift
                ;;
            -timeout)
                WAIT_TIMEOUT="$2"
                shift 2
                ;;
            *)
                log_msg "ERROR" "Unknown option: $1"
                echo "Use -h or --help for usage information"
                exit 1
                ;;
        esac
    done
    
    # Execute requested action
    case "$action" in
        install)
            do_install
            exit $?
            ;;
        uninstall)
            do_uninstall
            exit $?
            ;;
        status)
            check_status
            exit $?
            ;;
        force-reload)
            log_msg "INFO" "Forcing Coral TPU firmware reload..."
            trigger_firmware_load
            wait_for_device "18d1:9302" "$WAIT_TIMEOUT"
            exit $?
            ;;
        load)
            # Default: load firmware if needed
            log_msg "INFO" "Coral TPU Firmware Loader started"
            
            # Check if already operational
            if check_device "18d1:9302"; then
                log_msg "INFO" "✓ Coral TPU is already operational (18d1:9302)"
                check_edgetpu_runtime
                exit 0
            fi
            
            # Check if in bootloader mode
            if check_device "1a6e:089a"; then
                log_msg "INFO" "Coral TPU found in bootloader mode (1a6e:089a)"
                trigger_firmware_load
                wait_for_device "18d1:9302" "$WAIT_TIMEOUT"
                exit $?
            fi
            
            # Device not found at all
            log_msg "ERROR" "Coral TPU not found"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
