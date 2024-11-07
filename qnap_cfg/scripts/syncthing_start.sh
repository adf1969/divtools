#!/bin/bash

# Path to the Syncthing binary
SYNCTHING_BIN="/opt/bin/syncthing"  # Update with the correct path if different

# Path to store the PID file
SYNCTHING_PIDFILE="/var/run/syncthing.pid"

# Log file and additional logging settings
SYNC_LOGFILE="/var/log/syncthing.log"
SYNC_LOGFLAGS=3  # Example: 0 disables all logging flags
SYNC_LOGMAXSIZE=$((75 * 1024 * 1024))  # Maximum size of the log file, change first number to MB
SYNC_LOGMAXFILES=5  # Maximum number of old log files to keep

# Additional command line flags
SYNC_CLI_FLAGS=""  # Add any additional Syncthing command line arguments here

# Function for logging
function log() {
    echo "[START] $(date '+%Y-%m-%d %H:%M:%S') : $1" >> "$SYNC_LOGFILE"
}

# Increase UDP buffer sizes
log "Increasing UDP buffer sizes..."
sudo sysctl -w net.core.rmem_max=8388608 | tee -a "$SYNC_LOGFILE"
sudo sysctl -w net.core.wmem_max=8388608 | tee -a "$SYNC_LOGFILE"
log "UDP buffer sizes increased."

# Function to check if Syncthing is running
function is_syncthing_running() {
    if [ -f "$SYNCTHING_PIDFILE" ]; then
        local pid=$(cat "$SYNCTHING_PIDFILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            log "Syncthing is currently running with PID $pid."
            return 0  # Syncthing is running
        fi
    fi
    log "Syncthing is not running."
    return 1  # Syncthing is not running
}

# Function to kill all Syncthing processes
function kill_all_syncthing_processes() {
    log "Checking for any running Syncthing processes..."

    # Extract the PIDs, which should be the first field in the ps output
    local pids=$(ps aux | grep 'syncthing' | grep -v 'grep' | awk '{print $1}')

    if [ -n "$pids" ]; then
        log "Killing the following Syncthing processes: $pids"
        kill $pids
    else
        log "No additional Syncthing processes found."
    fi
}



# Function to start Syncthing
function start_syncthing() {
    if is_syncthing_running; then
        log "Syncthing is already running."
    else
        log "Starting Syncthing as 'syncthing' user..."
        # Run Syncthing in the background and redirect output to the log file
        sudo -u syncthing "$SYNCTHING_BIN" -no-browser \
            --logflags="$SYNC_LOGFLAGS" \
            --log-max-size="$SYNC_LOGMAXSIZE" \
            --log-max-old-files="$SYNC_LOGMAXFILES" \
            --logfile="$SYNC_LOGFILE" \
            $SYNC_CLI_FLAGS >> "$SYNC_LOGFILE" 2>&1 &
        echo $! > "$SYNCTHING_PIDFILE"
        log "Syncthing started with PID $(cat "$SYNCTHING_PIDFILE")."
    fi
}

# Function to stop Syncthing
function stop_syncthing() {
    if is_syncthing_running; then
        log "Stopping Syncthing..."
        local pid=$(cat "$SYNCTHING_PIDFILE")
        kill "$pid"
        rm -f "$SYNCTHING_PIDFILE"
        log "Syncthing stopped."
    else
        log "Syncthing is not running."
    fi
    # Ensure all Syncthing processes are killed
    kill_all_syncthing_processes
}

# Function to restart Syncthing
function restart_syncthing() {
    log "Restarting Syncthing..."
    stop_syncthing
    log "Waiting for Syncthing to stop completely..."
    sleep 5  # Ensure Syncthing is fully stopped
    start_syncthing
}

# Main script logic
case "$1" in
    start)
        start_syncthing
        ;;
    stop)
        stop_syncthing
        ;;
    restart)
        restart_syncthing
        ;;
    *)
        # Default action is to start Syncthing if no argument is provided
        start_syncthing
        ;;
esac
