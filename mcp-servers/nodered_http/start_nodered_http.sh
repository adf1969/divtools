#!/bin/bash
# start_nodered_http.sh - Control script for Node-RED HTTP API server
# Last Updated: 02/14/2026 11:00:00 AM CDT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_FILE="$SCRIPT_DIR/server.js"
PID_FILE="$SCRIPT_DIR/nodered_http.pid"
LOG_FILE="$SCRIPT_DIR/nodered_http.log"
SECRETS_FILE="$SCRIPT_DIR/secrets/.env.secret"

# Load secrets from external file
if [[ -f "$SECRETS_FILE" ]]; then
    source "$SECRETS_FILE"
fi

# Default configuration (use environment variables, fall back to defaults)
NODE_RED_URL="${NODE_RED_URL:-http://10.1.1.215:1880}"
NODE_RED_AUTH="${NODE_RED_AUTH:-}"  # Should be loaded from secrets file
PORT="${PORT:-3001}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[$timestamp] [$level] $message" >> "$LOG_FILE"
    echo -e "${BLUE}[$timestamp]${NC} [$level] $message"
}

is_running() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            return 0
        else
            # PID file exists but process is dead
            rm -f "$PID_FILE"
            return 1
        fi
    fi
    return 1
}

start_server() {
    if is_running; then
        echo -e "${YELLOW}Node-RED HTTP server is already running (PID: $(cat "$PID_FILE"))${NC}"
        return 1
    fi

    echo -e "${BLUE}Starting Node-RED HTTP server...${NC}"
    log "INFO" "Starting Node-RED HTTP server on port $PORT"

    # Start the server in background
    nohup node "$SERVER_FILE" "$NODE_RED_URL" "$NODE_RED_AUTH" "$PORT" >> "$LOG_FILE" 2>&1 &
    local pid=$!

    # Wait a moment for server to start
    sleep 2

    # Check if process is still running
    if ps -p "$pid" > /dev/null 2>&1; then
        echo "$pid" > "$PID_FILE"
        echo -e "${GREEN}Node-RED HTTP server started successfully (PID: $pid)${NC}"
        log "INFO" "Server started with PID $pid"
        return 0
    else
        echo -e "${RED}Failed to start Node-RED HTTP server${NC}"
        log "ERROR" "Failed to start server"
        return 1
    fi
}

stop_server() {
    if ! is_running; then
        echo -e "${YELLOW}Node-RED HTTP server is not running${NC}"
        return 1
    fi

    local pid=$(cat "$PID_FILE")
    echo -e "${BLUE}Stopping Node-RED HTTP server (PID: $pid)...${NC}"
    log "INFO" "Stopping server with PID $pid"

    # Try graceful shutdown first
    kill "$pid" 2>/dev/null

    # Wait up to 10 seconds for graceful shutdown
    local count=0
    while [ $count -lt 10 ] && ps -p "$pid" > /dev/null 2>&1; do
        sleep 1
        count=$((count + 1))
    done

    # Force kill if still running
    if ps -p "$pid" > /dev/null 2>&1; then
        echo -e "${YELLOW}Server didn't stop gracefully, force killing...${NC}"
        kill -9 "$pid" 2>/dev/null
        sleep 1
    fi

    if ps -p "$pid" > /dev/null 2>&1; then
        echo -e "${RED}Failed to stop Node-RED HTTP server${NC}"
        log "ERROR" "Failed to stop server"
        return 1
    else
        rm -f "$PID_FILE"
        echo -e "${GREEN}Node-RED HTTP server stopped successfully${NC}"
        log "INFO" "Server stopped"
        return 0
    fi
}

restart_server() {
    echo -e "${BLUE}Restarting Node-RED HTTP server...${NC}"
    stop_server
    sleep 2
    start_server
}

show_status() {
    if is_running; then
        local pid=$(cat "$PID_FILE")
        echo -e "${GREEN}Node-RED HTTP server is running (PID: $pid)${NC}"

        # Check if server is responding
        if curl -s -f "http://localhost:$PORT/health" > /dev/null 2>&1; then
            echo -e "${GREEN}Server is responding on http://localhost:$PORT${NC}"
        else
            echo -e "${YELLOW}Server process is running but not responding on port $PORT${NC}"
        fi
    else
        echo -e "${RED}Node-RED HTTP server is not running${NC}"
    fi
}

show_usage() {
    echo "Usage: $0 {start|stop|restart|status}"
    echo ""
    echo "Commands:"
    echo "  start   - Start the Node-RED HTTP server"
    echo "  stop    - Stop the Node-RED HTTP server"
    echo "  restart - Restart the Node-RED HTTP server"
    echo "  status  - Show server status"
    echo ""
    echo "Configuration:"
    echo "  Node-RED URL: $NODE_RED_URL"
    echo "  Port: $PORT"
    echo "  PID file: $PID_FILE"
    echo "  Log file: $LOG_FILE"
}

# Main script logic
case "${1:-}" in
    start)
        start_server
        ;;
    stop)
        stop_server
        ;;
    restart)
        restart_server
        ;;
    status)
        show_status
        ;;
    *)
        show_usage
        exit 1
        ;;
esac