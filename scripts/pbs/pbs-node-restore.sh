#!/bin/bash

# ================================
# Proxmox Node Restore Script
# ================================
#
# **PRE-RESTORE STEPS:**
# 1. Ensure the target node is booted into a safe environment (Live ISO or Proxmox rescue mode).
# 2. Verify network connectivity to the Proxmox Backup Server (PBS).
# 3. Ensure `proxmox-backup-client` is installed:
#    apt update && apt install proxmox-backup-client -y
# 4. Mount the target filesystem if restoring to a mounted partition:
#    mount /dev/sdX1 /mnt
# 5. Set the PBS password environment variable if required:
#    export PBS_PASSWORD=your_password
#
# **POST-RESTORE STEPS:**
# 1. Verify the restored files and configurations:
#    - Check /etc/pve for restored configurations.
#    - Verify VM and container configurations with `qm list` and `pct list`.
# 2. Reinstall bootloader if required:
#    grub-install /dev/sdX && update-grub
# 3. Reboot the system:
#    reboot
# 4. Check Proxmox services after reboot:
#    systemctl status pve-cluster pvedaemon pveproxy
# 5. Verify cluster membership (if applicable):
#    pvecm status

# Define variables
HOSTNAME=$(hostname)
PXAR_FILE="${HOSTNAME}.pxar"
USER="root"       # root | backupUser
REALM="pam"       # pbs | pam
SERVER="192.168.9.101"
DATASTORE="fhmtn1-pbs"
NAMESPACE="nodes"
export PBS_PASSWORD=3mpms3  # Replace with actual PBS password if needed

# Restore root filesystem
proxmox-backup-client restore \
  ${PXAR_FILE}:/ \
  / \
  --repository ${USER}@${REALM}@${SERVER}:${DATASTORE} \
  --ns ${NAMESPACE}

# Restore /etc/pve directory
proxmox-backup-client restore \
  etc-pve.pxar:/etc/pve \
  /etc/pve \
  --repository ${USER}@${REALM}@${SERVER}:${DATASTORE} \
  --ns ${NAMESPACE}

# Confirmation message
echo "Restore process completed. Please follow the POST-RESTORE STEPS to verify the system integrity."
