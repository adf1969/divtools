#!/bin/bash

# Load Frigate URL from environment (fallback default)
FRIGATE_URL="${FRIGATE_URL:-http://192.168.9.234:5000}"
OFFLINE_PAGE="/home/frigatekiosk/offline.html"

echo "[watchdog] Waiting for Frigate at $FRIGATE_URL..."

timeout=60
elapsed=0

while ! curl -s --head --fail "$FRIGATE_URL" >/dev/null; do
    sleep 5
    elapsed=$((elapsed + 5))
    echo "[watchdog] Still waiting... ($elapsed/$timeout sec)"
    if [ "$elapsed" -ge "$timeout" ]; then
        echo "[watchdog] Timeout reached. Showing offline page instead."
        chromium --kiosk "file://$OFFLINE_PAGE" --incognito &
        exit 0
    fi
done

echo "[watchdog] Frigate is online. Launching Chromium."
chromium --noerrdialogs --kiosk "$FRIGATE_URL" --incognito &
