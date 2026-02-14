#!/bin/bash

set -e

# Variables
OLD_NETPLAN_FILE="/etc/netplan/50-cloud-init.yaml"
NEW_NETPLAN_FILE="/etc/netplan/01-netcfg.yaml"
DISABLE_CLOUDINIT_FILE="/etc/cloud/cloud.cfg.d/99-disable-network-config.cfg"

# Step 0: Check if cloud-init related files exist
if [ ! -f "$OLD_NETPLAN_FILE" ]; then
    echo "[INFO] No $OLD_NETPLAN_FILE found. Cloud-init netplan file does not exist."
    echo "[INFO] No changes necessary."
    exit 0
fi

# Confirm with user before proceeding
echo "[CONFIRM] Cloud-init Netplan file detected at $OLD_NETPLAN_FILE."
echo "[CONFIRM] This script will disable cloud-init network management and create a new Netplan file."
echo -n "Do you want to proceed? [y/N]: "
read -r confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "[ABORTED] No changes were made."
    exit 0
fi

# Step 1: Disable cloud-init network configuration
echo "[INFO] Disabling cloud-init network configuration..."
sudo mkdir -p /etc/cloud/cloud.cfg.d
if [ ! -f "$DISABLE_CLOUDINIT_FILE" ]; then
    echo "network: {config: disabled}" | sudo tee "$DISABLE_CLOUDINIT_FILE" > /dev/null
    echo "[INFO] Created $DISABLE_CLOUDINIT_FILE"
else
    echo "[INFO] $DISABLE_CLOUDINIT_FILE already exists. Skipping."
fi

# Step 2: Backup old netplan file if it exists
if [ -f "$OLD_NETPLAN_FILE" ]; then
    echo "[INFO] Found existing $OLD_NETPLAN_FILE. Preparing new Netplan config."

    # Copy but strip comment lines from the top
    sudo awk 'BEGIN {copy=0} /^[^#]/ {copy=1} {if (copy) print}' "$OLD_NETPLAN_FILE" | \
    sudo tee "$NEW_NETPLAN_FILE" > /dev/null

    # Insert a comment header
    sudo sed -i "1i# This file was created by cloudinit_cleanup.sh\n# Based on original $OLD_NETPLAN_FILE\n# cloud-init network config has been disabled." "$NEW_NETPLAN_FILE"

    echo "[INFO] Created new Netplan file: $NEW_NETPLAN_FILE"

    # Step 3: Set correct permissions
    sudo chmod 600 "$NEW_NETPLAN_FILE"
    echo "[INFO] Set permissions to 600 on $NEW_NETPLAN_FILE"

else
    echo "[WARNING] No $OLD_NETPLAN_FILE found. Skipping Netplan file copy."
fi

# Step 4: Help text
echo
echo "[NEXT STEPS]"
echo "1. Review and edit $NEW_NETPLAN_FILE if needed."
echo "2. Run:   sudo netplan generate"
echo "3. Then:  sudo netplan apply"
echo "4. Verify: ip addr show, ip route show"
echo ""
echo "[DONE]"
