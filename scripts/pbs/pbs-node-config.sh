#!/bin/bash

# ================================
# Proxmox Node Configuration Capture Script
# ================================
#
# This script captures the current Proxmox node configuration, 
# including system service status, cluster membership, and VM/container status.
# The output is saved in the ~root/.config/pve_config/ directory.
#
# **Retention Policy:**
# - Default retention is 60 days of logs.
# - Older logs will be automatically deleted.

# Define variables
HOSTNAME=$(hostname)
DATE=$(date +%F)  # YYYY-MM-DD format
CONFIG_DIR="/root/.config/pve_config"
CONFIG_FILE="${CONFIG_DIR}/${HOSTNAME}.${DATE}.pve_config.log"
LAST_FILE="${CONFIG_DIR}/${HOSTNAME}.last.pve_config.log"
RETENTION_DAYS=60  # Default retention period

# Function to write command output to the log
write_config() {
  local cmd="$1"
  echo "===== Command: ${cmd} =====" >> "${CONFIG_FILE}"
  eval ${cmd} >> "${CONFIG_FILE}" 2>&1
  echo "" >> "${CONFIG_FILE}"
}

# Create config directory if it doesn't exist
mkdir -p ${CONFIG_DIR}

# Collect configuration data and save to log file
echo "===== Proxmox Node Configuration - ${DATE} =====" > "${CONFIG_FILE}"

# System Service Status
write_config "systemctl status pve-cluster"
write_config "systemctl status pvedaemon"
write_config "systemctl status pveproxy"

# Cluster Membership
write_config "pvecm status"

# VM Status
write_config "qm list"

# LXC Container Status
write_config "pct list"

# Update the latest configuration log
cp "${CONFIG_FILE}" "${LAST_FILE}"

# Remove logs older than the retention period
find ${CONFIG_DIR} -name "*.pve_config.log" -type f -mtime +${RETENTION_DAYS} -exec rm -f {} \;

# Confirmation message
echo "Configuration snapshot saved to: ${CONFIG_FILE}"
