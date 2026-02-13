#!/bin/bash
# Monitor Coral TPU USB stability and auto-restart Frigate on crashes
# Last Updated: 11/5/2025 1:10:00 PM CST

# Source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../util/logging.sh"

LOG_FILE="/var/log/divtools/monitor/coral_monitor.log"
mkdir -p "$(dirname "$LOG_FILE")"

RESET_COUNT=0
LAST_RESET_TIME=0

log "INFO" "Starting Coral TPU monitor..."
log "INFO" "Logs: $LOG_FILE"

# Function to get kernel uptime in seconds
get_uptime_seconds() {
    awk '{print int($1)}' /proc/uptime
}

# Function to check for recent USB resets
check_usb_resets() {
    local current_time=$(get_uptime_seconds)
    local recent_resets=$(dmesg | grep "usb 12-1: reset SuperSpeed" | tail -5)
    
    if [[ -n "$recent_resets" ]]; then
        # Extract the most recent reset timestamp
        local latest_reset=$(echo "$recent_resets" | tail -1 | grep -oP '^\[\s*\K[0-9]+')
        
        if [[ -n "$latest_reset" && "$latest_reset" != "$LAST_RESET_TIME" ]]; then
            LAST_RESET_TIME=$latest_reset
            ((RESET_COUNT++))
            
            log "WARN" "USB reset detected at kernel time $latest_reset (reset #$RESET_COUNT)"
            echo "[$(date)] USB Reset #$RESET_COUNT at kernel time $latest_reset" >> "$LOG_FILE"
            
            return 0  # Reset detected
        fi
    fi
    
    return 1  # No new reset
}

# Function to check if Frigate is healthy
check_frigate_health() {
    local status=$(docker inspect frigate --format '{{.State.Health.Status}}' 2>/dev/null)
    
    if [[ "$status" == "healthy" ]]; then
        return 0
    else
        log "ERROR" "Frigate is not healthy: $status"
        echo "[$(date)] Frigate unhealthy: $status" >> "$LOG_FILE"
        return 1
    fi
}

# Function to check for USB transfer errors in Frigate logs
check_frigate_errors() {
    local errors=$(docker logs frigate --since 60s 2>&1 | grep -i "USB transfer error\|Fatal Python error")
    
    if [[ -n "$errors" ]]; then
        log "ERROR" "USB transfer errors detected in Frigate logs"
        echo "[$(date)] USB transfer error detected:" >> "$LOG_FILE"
        echo "$errors" >> "$LOG_FILE"
        return 1
    fi
    
    return 0
}

# Function to reset and restart
perform_recovery() {
    log "WARN" "Attempting automatic recovery..."
    echo "[$(date)] === AUTOMATIC RECOVERY ATTEMPT ===" >> "$LOG_FILE"
    
    # Stop Frigate
    docker stop frigate
    sleep 3
    
    # Reset USB device
    for dev in /sys/bus/usb/devices/*; do
        if [[ -f "$dev/idVendor" && "$(cat $dev/idVendor 2>/dev/null)" == "18d1" ]] && \
           [[ -f "$dev/idProduct" && "$(cat $dev/idProduct 2>/dev/null)" == "9302" ]]; then
            log "INFO" "Resetting Coral at $dev"
            echo 0 > "$dev/authorized" 2>/dev/null
            sleep 2
            echo 1 > "$dev/authorized" 2>/dev/null
            sleep 2
            
            # Reapply power settings
            echo "on" > "$dev/power/control" 2>/dev/null
            echo "-1" > "$dev/power/autosuspend" 2>/dev/null
            echo "-1" > "$dev/power/autosuspend_delay_ms" 2>/dev/null
            break
        fi
    done
    
    sleep 3
    
    # Start Frigate
    docker start frigate
    
    log "SUCCESS" "Recovery complete - Frigate restarted"
    echo "[$(date)] Recovery complete" >> "$LOG_FILE"
}

# Main monitoring loop
log "INFO" "Monitoring every 60 seconds..."
echo "[$(date)] === Coral TPU Monitor Started ===" >> "$LOG_FILE"

while true; do
    sleep 60
    
    # Check for USB resets
    if check_usb_resets; then
        log "WARN" "USB reset detected (total: $RESET_COUNT)"
        
        # Give it 10 seconds to see if Frigate crashes
        sleep 10
        
        # Check if Frigate is still healthy
        if ! check_frigate_health || ! check_frigate_errors; then
            log "ERROR" "Frigate failed after USB reset - initiating recovery"
            perform_recovery
            
            # Reset counter after recovery
            if [[ $RESET_COUNT -ge 5 ]]; then
                log "ERROR" "WARNING: $RESET_COUNT resets detected - hardware issue likely"
                echo "[$(date)] HARDWARE ISSUE: $RESET_COUNT resets - consider replacing USB cable/port/device" >> "$LOG_FILE"
            fi
        else
            log "INFO" "Frigate survived reset - continuing monitoring"
        fi
    fi
    
    # Periodic health check
    if ! check_frigate_health; then
        log "ERROR" "Frigate unhealthy - checking for errors"
        if ! check_frigate_errors; then
            perform_recovery
        fi
    fi
done
