#!/bin/bash
# Reset Moodle installation for clean reinstall
# Last Updated: 11/8/2025 10:35:00 PM CDT

# Source environment to get dcup/dcdown commands
source /etc/profile

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "This will completely remove all Moodle data and reset to a clean installation."
echo "Data directories to be removed:"
echo "  - /opt/moodle/html"
echo "  - /opt/moodle/moodledata"
echo "  - /opt/moodle/pgdata"
echo ""
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

# Stop containers
echo "Stopping Moodle containers..."
dcdown moodle

# Remove data directories
echo "Removing Moodle data directories..."
sudo rm -rf /opt/moodle/html/*
sudo rm -rf /opt/moodle/moodledata/*
sudo rm -rf /opt/moodle/pgdata/*

# Recreate directory structure with correct permissions
echo "Recreating directory structure..."
sudo mkdir -p /opt/moodle/html
sudo mkdir -p /opt/moodle/moodledata
sudo mkdir -p /opt/moodle/pgdata
sudo chown -R 33:33 /opt/moodle/moodledata  # www-data UID:GID
sudo chown -R 999:999 /opt/moodle/pgdata     # postgres UID:GID

# Start containers
echo "Starting Moodle containers..."
dcup moodle

echo ""
echo "Moodle has been reset. Wait a few seconds for containers to start, then access:"
echo "  http://10.1.1.74:9090"
echo ""
echo "The installation should proceed automatically with pre-configured database settings."
