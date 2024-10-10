#!/bin/sh

# Path to Syncthing binary
SYNCTHING_BIN="/opt/bin/syncthing"

# Log file
LOG_FILE="/opt/var/log/syncthing.log"

# Process ID file
PID_FILE="/opt/var/run/syncthing.pid"

# Check if Syncthing is running
is_running() {
    if [ -f "$PID_FILE" ]; then
        if kill -0 $(cat "$PID_FILE") > /dev/null 2>&1; then
            return 0
        else
            rm -f "$PID_FILE"  # Clean up PID file if process isn't running
        fi
    fi
    return 1
}

# Start Syncthing
start() {
    if is_running; then
        echo "Syncthing is already running."
    else
        echo "Starting Syncthing..."
        # Redirect output and start Syncthing in the background
        $SYNCTHING_BIN -no-browser > "$LOG_FILE" 2>&1 &
        echo $! > "$PID_FILE"
        disown # Ensure the process is detached from the terminal
        echo "Syncthing started."
    fi
}

# Stop Syncthing
stop() {
    if is_running; then
        echo "Stopping Syncthing..."
        kill $(cat "$PID_FILE")
        rm -f "$PID_FILE"
        echo "Syncthing stopped."
    else
        echo "Syncthing is not running."
    fi
}

# Restart Syncthing
restart() {
    stop
    start
}

# Usage information
usage() {
    echo "Usage: $0 {start|stop|restart|status}"
    exit 1
}

# Check command-line arguments
case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        restart
        ;;
    status)
        if is_running; then
            echo "Syncthing is running."
        else
            echo "Syncthing is not running."
        fi
        ;;
    *)
        usage
        ;;
esac

exit 0

