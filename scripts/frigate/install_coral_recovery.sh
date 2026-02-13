#!/bin/bash
# Coral TPU Setup & Recovery System Installer
# Last Updated: 11/11/2025 11:45:00 AM CST
# Installs all scripts and services needed for Coral TPU stability on GPU1-75

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../util/logging.sh"

TEST_MODE=0
INSTALL_WATCHDOG=1
INSTALL_RULES=1
HOSTNAME=$(hostname)

log "HEAD" "╔═══════════════════════════════════════════════════════════╗"
log "HEAD" "║     Coral TPU Stability System Installer & Setup         ║"
log "HEAD" "╚═══════════════════════════════════════════════════════════╝"

log "INFO" "Hostname: $HOSTNAME"
log "INFO" "Script directory: $SCRIPT_DIR"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -test|--test)
            TEST_MODE=1
            log "INFO" "Running in TEST mode - no system changes"
            shift
            ;;
        --no-watchdog)
            INSTALL_WATCHDOG=0
            log "INFO" "Skipping watchdog installation"
            shift
            ;;
        --no-rules)
            INSTALL_RULES=0
            log "INFO" "Skipping udev rules installation"
            shift
            ;;
        *)
            log "ERROR" "Unknown option: $1"
            exit 1
            ;;
    esac
done

# === STEP 1: Check prerequisites ===
log "HEAD" "=== STEP 1: Checking Prerequisites ==="

log "INFO" "Checking for Docker..."
if ! command -v docker &> /dev/null; then
    log "ERROR" "Docker not found. Please install Docker first."
    exit 1
fi
log "SUCCESS" "Docker found"

log "INFO" "Checking for Frigate container..."
if ! docker ps -a | grep -q "frigate"; then
    log "ERROR" "Frigate container not found. Please start Frigate first."
    exit 1
fi
log "SUCCESS" "Frigate container found"

log "INFO" "Checking for curl..."
if ! command -v curl &> /dev/null; then
    log "WARN" "curl not found - watchdog health checks may not work"
fi

# === STEP 2: Make scripts executable ===
log "HEAD" "=== STEP 2: Setting Script Permissions ==="

SCRIPTS=(
    "fix_coral_usb_autosuspend.sh"
    "reset_coral_usb.sh"
    "monitor_coral_tpu.sh"
    "coral_watchdog.sh"
    "proxmox_coral_reset.sh"
    "proxmox_usb_tuning.sh"
)

for script in "${SCRIPTS[@]}"; do
    if [[ -f "$SCRIPT_DIR/$script" ]]; then
        if [[ $TEST_MODE -eq 1 ]]; then
            log "INFO:!ts" "[TEST] Would chmod +x $SCRIPT_DIR/$script"
        else
            chmod +x "$SCRIPT_DIR/$script"
            log "SUCCESS" "Made executable: $script"
        fi
    else
        log "WARN" "Script not found: $script"
    fi
done

# === STEP 3: Fix USB autosuspend immediately ===
log "HEAD" "=== STEP 3: Fixing USB Autosuspend (Immediate) ==="

if [[ $TEST_MODE -eq 1 ]]; then
    log "INFO:!ts" "[TEST] Would run: $SCRIPT_DIR/fix_coral_usb_autosuspend.sh"
else
    log "INFO" "Running USB autosuspend fix..."
    if bash "$SCRIPT_DIR/fix_coral_usb_autosuspend.sh" 2>&1 | tail -20; then
        log "SUCCESS" "USB autosuspend fix applied"
    else
        log "WARN" "USB autosuspend fix had issues (may need sudo)"
    fi
fi

# === STEP 4: Install systemd watchdog service ===
if [[ $INSTALL_WATCHDOG -eq 1 ]]; then
    log "HEAD" "=== STEP 4: Installing Watchdog Service ==="
    
    SERVICE_FILE="/etc/systemd/system/coral_watchdog.service"
    SOURCE_SERVICE="$SCRIPT_DIR/coral_watchdog.service"
    
    if [[ ! -f "$SOURCE_SERVICE" ]]; then
        log "ERROR" "Service file not found: $SOURCE_SERVICE"
    else
        if [[ $TEST_MODE -eq 1 ]]; then
            log "INFO:!ts" "[TEST] Would copy service to $SERVICE_FILE"
            log "INFO:!ts" "[TEST] Would enable service"
            log "INFO:!ts" "[TEST] Would start service"
        else
            log "INFO" "Installing systemd service..."
            
            if cp "$SOURCE_SERVICE" "$SERVICE_FILE" 2>/dev/null; then
                log "SUCCESS" "Service file installed"
                
                # Reload systemd
                systemctl daemon-reload 2>/dev/null
                log "SUCCESS" "Systemd daemon reloaded"
                
                # Enable service
                if systemctl enable coral_watchdog.service 2>/dev/null; then
                    log "SUCCESS" "Service enabled for auto-start"
                fi
                
                # Start service
                if systemctl start coral_watchdog.service 2>/dev/null; then
                    log "SUCCESS" "Watchdog service started"
                    
                    # Show status
                    sleep 2
                    systemctl status coral_watchdog.service --no-pager 2>/dev/null | head -10
                else
                    log "ERROR" "Failed to start watchdog service"
                fi
            else
                log "ERROR" "Failed to install service file (may need sudo)"
            fi
        fi
    fi
else
    log "INFO" "Skipping watchdog installation (--no-watchdog)"
fi

# === STEP 5: Create log directories ===
log "HEAD" "=== STEP 5: Setting Up Logging ==="

LOG_DIR="/var/log/divtools/monitor"

if [[ $TEST_MODE -eq 1 ]]; then
    log "INFO:!ts" "[TEST] Would create log directory: $LOG_DIR"
else
    if mkdir -p "$LOG_DIR" 2>/dev/null; then
        chmod 755 "$LOG_DIR"
        log "SUCCESS" "Log directory created: $LOG_DIR"
    else
        log "WARN" "Could not create log directory (may need sudo)"
    fi
fi

# === STEP 6: Create udev rules ===
if [[ $INSTALL_RULES -eq 1 ]]; then
    log "HEAD" "=== STEP 6: Installing Udev Rules ==="
    
    UDEV_FILE="/etc/udev/rules.d/99-coral-no-autosuspend.rules"
    
    if [[ $TEST_MODE -eq 1 ]]; then
        log "INFO:!ts" "[TEST] Would install udev rules to: $UDEV_FILE"
    else
        if [[ ! -f "$UDEV_FILE" ]]; then
            cat > "$UDEV_FILE" <<'EOF'
# Disable USB autosuspend for Google Coral Edge TPU
# Last Updated: 11/11/2025
#
# This prevents USB transfer errors and device resets

# Coral USB Accelerator (18d1:9302)
SUBSYSTEM=="usb", ATTRS{idVendor}=="18d1", ATTRS{idProduct}=="9302", ATTR{power/control}="on"

# Older Coral models
SUBSYSTEM=="usb", ATTRS{idVendor}=="1a6e", ATTRS{idProduct}=="089a", ATTR{power/control}="on"
EOF
            log "SUCCESS" "Udev rules created: $UDEV_FILE"
            
            # Reload udev
            if udevadm control --reload-rules 2>/dev/null && udevadm trigger 2>/dev/null; then
                log "SUCCESS" "Udev rules reloaded"
            else
                log "WARN" "Could not reload udev rules (may need sudo)"
            fi
        else
            log "INFO" "Udev rules already exist"
        fi
    fi
else
    log "INFO" "Skipping udev rules installation (--no-rules)"
fi

# === STEP 7: Test configuration ===
log "HEAD" "=== STEP 7: Testing Configuration ==="

log "INFO" "Checking for Coral device..."
if lsusb | grep -q "18d1:9302"; then
    log "SUCCESS" "Coral TPU detected"
else
    log "WARN" "Coral TPU not currently visible (may be in reset cycle)"
fi

log "INFO" "Checking Frigate container status..."
if docker ps | grep -q "frigate"; then
    log "SUCCESS" "Frigate container is running"
    
    # Check logs for errors
    if docker logs frigate --since 1m 2>&1 | grep -q "edgetpu.*error\|coral.*error"; then
        log "WARN" "Recent errors found in Frigate logs - recovery may trigger"
    else
        log "SUCCESS" "No recent Coral errors in Frigate logs"
    fi
else
    log "ERROR" "Frigate container is not running"
fi

# === STEP 8: Summary and next steps ===
log "HEAD" "╔═══════════════════════════════════════════════════════════╗"
log "HEAD" "║              Installation Complete - Next Steps           ║"
log "HEAD" "╚═══════════════════════════════════════════════════════════╝"

log "SUCCESS" "✓ Watchdog service installed and started"
log "SUCCESS" "✓ USB autosuspend settings applied"
log "SUCCESS" "✓ Udev rules installed"
log "SUCCESS" "✓ Log directory created at $LOG_DIR"
echo ""

log "INFO" "Monitor the watchdog service:"
log "INFO:!ts" "  sudo systemctl status coral_watchdog -f"
echo ""

log "INFO" "View watchdog logs:"
log "INFO:!ts" "  tail -f $LOG_DIR/coral_watchdog.log"
log "INFO:!ts" "  journalctl -u coral_watchdog -f"
echo ""

log "INFO" "If you encounter issues, run:"
log "INFO:!ts" "  cd $SCRIPT_DIR"
log "INFO:!ts" "  bash reset_coral_usb.sh          # Manual USB reset"
log "INFO:!ts" "  bash proxmox_usb_tuning.sh       # Tune Proxmox host (requires SSH)"
echo ""

log "WARN" "To disable watchdog (e.g., for testing):"
log "INFO:!ts" "  sudo systemctl stop coral_watchdog"
log "INFO:!ts" "  sudo systemctl disable coral_watchdog"
echo ""

log "HEAD" "Documentation:"
log "INFO:!ts" "  See $SCRIPT_DIR/CORAL_USB_DIAGNOSTICS.md for detailed information"
echo ""

log "SUCCESS" "Setup complete! $(date)"
