#!/bin/bash

# Path to the Syncthing binary
SYNCTHING_BIN="/opt/bin/syncthing"  # Update with the correct path if different

# Path to store the PID file
SYNCTHING_PIDFILE="/var/run/syncthing.pid"

# Log file and additional logging settings
SYNC_LOGFILE="/var/log/syncthing.log"
SYNC_LOGFLAGS=3  # Example: 0 disables all logging flags
SYNC_LOGMAXSIZE=$((75 * 1024 * 1024))  # Maximum size of the log file xM * 1024 * 1024, change first # to MB
SYNC_LOGMAXFILES=5  # Maximum number of old log files to keep

# Additional command line flags
SYNC_CLI_FLAGS=""  # Add any additional Syncthing command line arguments here

# Function to check if Syncthing is running
function is_syncthing_running() {
    if [ -f "$SYNCTHING_PIDFILE" ]; then
        local pid=$(cat "$SYNCTHING_PIDFILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            return 0  # Syncthing is running
        fi
    fi
    return 1  # Syncthing is not running
}

# Function to start Syncthing
function start_syncthing() {
    if is_syncthing_running; then
        echo "Syncthing is already running." | tee -a "$SYNC_LOGFILE"
    else
        echo "Starting Syncthing as 'syncthing' user..." | tee -a "$SYNC_LOGFILE"
        sudo -u syncthing nohup "$SYNCTHING_BIN" -no-browser \
            --logflags="$SYNC_LOGFLAGS" \
            --log-max-size="$SYNC_LOGMAXSIZE" \
            --log-max-old-files="$SYNC_LOGMAXFILES" \
            --logfile="$SYNC_LOGFILE" \
            $SYNC_CLI_FLAGS >> "$SYNC_LOGFILE" 2>&1 &
        echo $! > "$SYNCTHING_PIDFILE"
        echo "Syncthing started with PID $(cat "$SYNCTHING_PIDFILE")." | tee -a "$SYNC_LOGFILE"
    fi
}

# Function to stop Syncthing
function stop_syncthing() {
    if is_syncthing_running; then
        echo "Stopping Syncthing..." | tee -a "$SYNC_LOGFILE"
        local pid=$(cat "$SYNCTHING_PIDFILE")
        kill "$pid"
        rm -f "$SYNCTHING_PIDFILE"
        echo "Syncthing stopped." | tee -a "$SYNC_LOGFILE"
    else
        echo "Syncthing is not running." | tee -a "$SYNC_LOGFILE"
    fi
}

# Function to restart Syncthing
function restart_syncthing() {
    stop_syncthing
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
