#!/bin/bash
# Docker entrypoint for dthostmon
# Last Updated: 11/14/2025 12:00:00 PM CDT

set -e

# Function to run monitoring cycle
run_monitor() {
    echo "[$(date)] Running monitoring cycle"
    cd /app && python3 src/dthostmon_cli.py -c /opt/dthostmon/config/dthostmon.yaml monitor
}

# Function to start API server
start_api() {
    echo "Starting dthostmon API server..."
    cd /app && python3 src/dthostmon_api.py -c /opt/dthostmon/config/dthostmon.yaml --host 0.0.0.0
}

# Function to start cron + API (combined mode)
start_combined() {
    echo "Starting dthostmon in combined mode (cron + API)"
    
    # Initialize database
    echo "Initializing database..."
    cd /app && python3 src/dthostmon_cli.py -c /opt/dthostmon/config/dthostmon.yaml monitor --init-db
    
    # Setup cron job
    CRON_INTERVAL="${MONITOR_INTERVAL:-3600}"
    CRON_SCHEDULE="0 */$((CRON_INTERVAL / 3600)) * * *"
    
    echo "$CRON_SCHEDULE cd /app && /usr/local/bin/python3 src/dthostmon_cli.py -c /opt/dthostmon/config/dthostmon.yaml monitor >> /opt/dthostmon/logs/cron.log 2>&1" > /etc/cron.d/dthostmon
    chmod 0644 /etc/cron.d/dthostmon
    crontab /etc/cron.d/dthostmon
    
    echo "Cron job configured: $CRON_SCHEDULE"
    
    # Start cron in background
    cron
    
    # Start API server in foreground
    start_api
}

# Main command dispatcher
case "$1" in
    monitor)
        # Run single monitoring cycle and exit
        run_monitor
        ;;
    api)
        # Start API server only
        start_api
        ;;
    combined|"")
        # Start both cron and API (default)
        start_combined
        ;;
    *)
        # Custom command
        exec "$@"
        ;;
esac
