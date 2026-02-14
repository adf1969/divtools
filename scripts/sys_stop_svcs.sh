#!/bin/bash
# stop_non_essential_services.sh

# List of essential services to keep running
ESSENTIAL_SERVICES=(
    "systemd-journald.service"
    "systemd-logind.service"
    "ssh.service"
    "sshd.service"
    "systemd-networkd.service"
    "networking.service"
    "systemd-udev.service"
)

# Get all running services, excluding essentials
mapfile -t SERVICES < <(systemctl list-units --type=service --state=running --no-legend | awk '{print $1}' | grep -vE "$(IFS='|'; echo "${ESSENTIAL_SERVICES[*]}")")

# Stop non-essential services
for service in "${SERVICES[@]}"; do
    echo "Stopping $service..."
    sudo systemctl stop "$service"
done

echo "Non-essential services stopped. Active services:"
sudo systemctl list-units --type=service --state=running