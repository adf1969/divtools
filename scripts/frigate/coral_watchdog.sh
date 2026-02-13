#!/bin/bash
# Frigate Coral TPU Watchdog - Detects disconnections and triggers recovery
# Last Updated: 11/11/2025 11:30:00 AM CST

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../util/logging.sh"

# Configuration
TEST_MODE=0
DEBUG_MODE=0
CHECK_INTERVAL=30                # Check every 30 seconds
MAX_CONSECUTIVE_FAILURES=3       # Fail 3 times before recovery
FRIGATE_RESTART_TIMEOUT=120      # Give frigate 2 minutes to start after recovery
LOG_DIR="/var/log/divtools/monitor"
LOG_FILE="$LOG_DIR/coral_watchdog.log"

# State tracking
CONSECUTIVE_FAILURES=0
LAST_RECOVERY_TIME=0
RECOVERY_COUNT=0
BOOT_TIME=$(date +%s)

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -test|--test)
            TEST_MODE=1
            log "INFO" "Running in TEST mode - no permanent changes will be made"
            shift
            ;;
        -debug|--debug)
            DEBUG_MODE=1
            log "DEBUG" "Debug mode enabled"
            shift
            ;;
        -interval)
            CHECK_INTERVAL="$2"
            log "INFO" "Check interval set to $CHECK_INTERVAL seconds"
            shift 2
            ;;
        *)
            log "ERROR" "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Initialize
mkdir -p "$LOG_DIR"

log "HEAD" "╔═══════════════════════════════════════════════════════════╗"
log "HEAD" "║       Frigate Coral TPU Watchdog Service Started          ║"
log "HEAD" "╚═══════════════════════════════════════════════════════════╝"
log "INFO" "Check interval: $CHECK_INTERVAL seconds"
log "INFO" "Max consecutive failures before recovery: $MAX_CONSECUTIVE_FAILURES"
log "INFO" "Logs: $LOG_FILE"
echo "[$(date)] === Coral TPU Watchdog Started ===" >> "$LOG_FILE"

# Function: Check if Coral device is visible
check_coral_device() {
    [[ $DEBUG_MODE -eq 1 ]] && log "DEBUG" "Checking for Coral device..."
    
    # Check in sysfs (most reliable method)
    for device_path in /sys/bus/usb/devices/*; do
        if [[ ! -d "$device_path" ]]; then
            continue
        fi
        
        if [[ -f "$device_path/idVendor" && -f "$device_path/idProduct" ]]; then
            local vendor=$(cat "$device_path/idVendor" 2>/dev/null)
            local product=$(cat "$device_path/idProduct" 2>/dev/null)
            
            # Check for Coral (18d1:9302 or 1a6e:089a)
            if [[ "$vendor" == "18d1" && "$product" == "9302" ]] || \
               [[ "$vendor" == "1a6e" && "$product" == "089a" ]]; then
                [[ $DEBUG_MODE -eq 1 ]] && log "DEBUG" "Coral found at $device_path"
                return 0
            fi
        fi
    done
    
    [[ $DEBUG_MODE -eq 1 ]] && log "DEBUG" "Coral device not found"
    return 1
}

# Function: Check if Frigate container is running
check_frigate_running() {
    [[ $DEBUG_MODE -eq 1 ]] && log "DEBUG" "Checking if Frigate container is running..."
    
    local status=$(docker inspect frigate --format='{{.State.Running}}' 2>/dev/null)
    if [[ "$status" == "true" ]]; then
        [[ $DEBUG_MODE -eq 1 ]] && log "DEBUG" "Frigate is running"
        return 0
    else
        [[ $DEBUG_MODE -eq 1 ]] && log "DEBUG" "Frigate is not running"
        return 1
    fi
}

# Function: Check if Frigate is healthy (API responding)
check_frigate_healthy() {
    [[ $DEBUG_MODE -eq 1 ]] && log "DEBUG" "Checking Frigate API health..."
    
    local response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5000/api/version 2>/dev/null)
    
    if [[ "$response" == "200" ]]; then
        [[ $DEBUG_MODE -eq 1 ]] && log "DEBUG" "Frigate API is healthy (HTTP $response)"
        return 0
    else
        [[ $DEBUG_MODE -eq 1 ]] && log "DEBUG" "Frigate API unhealthy (HTTP $response)"
        return 1
    fi
}

# Function: Check if Coral detector is active in Frigate logs
check_coral_in_frigate() {
    [[ $DEBUG_MODE -eq 1 ]] && log "DEBUG" "Checking Frigate logs for Coral errors..."
    
    # Check recent logs for EdgeTPU errors
    local errors=$(docker logs frigate --since 60s 2>&1 | grep -i "edgetpu\|coral" | grep -i "error\|failed\|no.*device")
    
    if [[ -n "$errors" ]]; then
        [[ $DEBUG_MODE -eq 1 ]] && log "DEBUG" "EdgeTPU errors found in Frigate logs"
        echo "$errors"
        return 1
    fi
    
    [[ $DEBUG_MODE -eq 1 ]] && log "DEBUG" "No EdgeTPU errors in recent logs"
    return 0
}

# Function: Perform recovery
perform_recovery() {
    local current_time=$(date +%s)
    
    log "WARN" "Initiating Coral recovery procedure..."
    echo "[$(date)] === RECOVERY ATTEMPT #$((RECOVERY_COUNT+1)) ===" >> "$LOG_FILE"
    
    if [[ $TEST_MODE -eq 1 ]]; then
        log "INFO:!ts" "[TEST MODE] Would perform:"
        log "INFO:!ts" "  1. Stop Frigate container"
        log "INFO:!ts" "  2. Reset Coral USB device"
        log "INFO:!ts" "  3. Wait 5 seconds"
        log "INFO:!ts" "  4. Start Frigate container"
        log "INFO:!ts" "  5. Monitor for 2 minutes"
        echo "[$(date)] [TEST MODE] Recovery would be performed" >> "$LOG_FILE"
        return
    fi
    
    # Step 1: Stop Frigate
    log "INFO" "Stopping Frigate container..."
    if docker stop frigate 2>/dev/null; then
        log "SUCCESS" "Frigate stopped"
        echo "[$(date)] Frigate stopped" >> "$LOG_FILE"
    else
        log "ERROR" "Failed to stop Frigate"
        echo "[$(date)] ERROR: Failed to stop Frigate" >> "$LOG_FILE"
        return 1
    fi
    
    sleep 3
    
    # Step 2: Reset USB device
    log "INFO" "Resetting Coral USB device..."
    local reset_done=0
    
    for device_path in /sys/bus/usb/devices/*; do
        if [[ ! -d "$device_path" ]]; then
            continue
        fi
        
        if [[ -f "$device_path/idVendor" && -f "$device_path/idProduct" ]]; then
            local vendor=$(cat "$device_path/idVendor" 2>/dev/null)
            local product=$(cat "$device_path/idProduct" 2>/dev/null)
            
            if [[ "$vendor" == "18d1" && "$product" == "9302" ]] || \
               [[ "$vendor" == "1a6e" && "$product" == "089a" ]]; then
                
                log "INFO" "Authorizing reset for device at $device_path"
                
                # Try authorization method first
                if [[ -w "$device_path/authorized" ]]; then
                    echo 0 > "$device_path/authorized" 2>/dev/null
                    sleep 2
                    echo 1 > "$device_path/authorized" 2>/dev/null
                    log "SUCCESS" "Device reauthorized"
                    echo "[$(date)] Device reauthorized" >> "$LOG_FILE"
                    reset_done=1
                fi
                
                # Reapply power management settings
                if [[ -w "$device_path/power/control" ]]; then
                    echo "on" > "$device_path/power/control" 2>/dev/null
                    log "DEBUG" "Power control set to 'on'"
                fi
                
                if [[ -w "$device_path/power/autosuspend" ]]; then
                    echo "-1" > "$device_path/power/autosuspend" 2>/dev/null
                    log "DEBUG" "Autosuspend disabled"
                fi
                
                break
            fi
        fi
    done
    
    if [[ $reset_done -eq 0 ]]; then
        log "WARN" "Could not reset device (may not be present)"
        echo "[$(date)] WARNING: Could not reset device" >> "$LOG_FILE"
    fi
    
    sleep 5
    
    # Step 3: Start Frigate
    log "INFO" "Starting Frigate container..."
    if docker start frigate 2>/dev/null; then
        log "SUCCESS" "Frigate started"
        echo "[$(date)] Frigate started" >> "$LOG_FILE"
    else
        log "ERROR" "Failed to start Frigate"
        echo "[$(date)] ERROR: Failed to start Frigate" >> "$LOG_FILE"
        return 1
    fi
    
    # Update tracking
    CONSECUTIVE_FAILURES=0
    LAST_RECOVERY_TIME=$current_time
    ((RECOVERY_COUNT++))
    
    log "SUCCESS" "Recovery procedure complete (attempt #$RECOVERY_COUNT)"
    echo "[$(date)] Recovery complete - waiting $FRIGATE_RESTART_TIMEOUT seconds for stabilization" >> "$LOG_FILE"
}

# Main monitoring loop
log "INFO" "Entering monitoring loop..."
LOOP_COUNT=0

while true; do
    ((LOOP_COUNT++))
    
    [[ $DEBUG_MODE -eq 1 ]] && log "DEBUG" "=== Check iteration $LOOP_COUNT ==="
    
    # Check all conditions
    local coral_ok=0
    local frigate_running=0
    local frigate_healthy=0
    
    if check_coral_device; then
        coral_ok=1
    fi
    
    if check_frigate_running; then
        frigate_running=1
    fi
    
    if check_frigate_healthy; then
        frigate_healthy=1
    fi
    
    # Determine health status
    if [[ $coral_ok -eq 1 ]] && [[ $frigate_running -eq 1 ]] && [[ $frigate_healthy -eq 1 ]]; then
        # All good
        if [[ $CONSECUTIVE_FAILURES -gt 0 ]]; then
            log "HEAD" "✓ System recovered (was failing $CONSECUTIVE_FAILURES times)"
            echo "[$(date)] System recovered after $CONSECUTIVE_FAILURES consecutive failures" >> "$LOG_FILE"
        fi
        CONSECUTIVE_FAILURES=0
        [[ $DEBUG_MODE -eq 1 ]] && log "DEBUG" "All checks passed"
    else
        # Something is wrong
        ((CONSECUTIVE_FAILURES++))
        
        local reasons=()
        [[ $coral_ok -eq 0 ]] && reasons+=("Coral not detected")
        [[ $frigate_running -eq 0 ]] && reasons+=("Frigate not running")
        [[ $frigate_healthy -eq 0 ]] && reasons+=("Frigate unhealthy")
        
        log "WARN" "Check failed ($CONSECUTIVE_FAILURES/$MAX_CONSECUTIVE_FAILURES): ${reasons[*]}"
        echo "[$(date)] Failure #$CONSECUTIVE_FAILURES: ${reasons[*]}" >> "$LOG_FILE"
        
        # If we've exceeded the threshold, trigger recovery
        if [[ $CONSECUTIVE_FAILURES -ge $MAX_CONSECUTIVE_FAILURES ]]; then
            log "ERROR" "Maximum consecutive failures reached - triggering recovery"
            perform_recovery
            
            # Wait for Frigate to stabilize
            log "INFO" "Giving Frigate $FRIGATE_RESTART_TIMEOUT seconds to stabilize..."
            sleep "$FRIGATE_RESTART_TIMEOUT"
        fi
    fi
    
    # Wait before next check
    sleep "$CHECK_INTERVAL"
done
