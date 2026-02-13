#!/usr/bin/env bash
# Installs the Comfy systemd service from the example file
# Last Updated: 12/15/2025 09:20:00 PM CST

set -euo pipefail

SERVICE_NAME="comfy.service"
EXAMPLE_FILE="$(dirname "${BASH_SOURCE[0]}")/comfy.service.example"
DEST_FILE="/etc/systemd/system/$SERVICE_NAME"

if [[ $EUID -ne 0 ]]; then
    echo "This script requires root. Re-run with sudo."
    exit 1
fi

if [[ ! -f "$EXAMPLE_FILE" ]]; then
    echo "Example service file not found: $EXAMPLE_FILE"
    exit 1
fi

cp "$EXAMPLE_FILE" "$DEST_FILE"
chmod 644 "$DEST_FILE"
systemctl daemon-reload
systemctl enable --now "$SERVICE_NAME"
echo "Installed and started $SERVICE_NAME"
echo "View logs with: sudo journalctl -u $SERVICE_NAME -f"
