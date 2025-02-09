#!/bin/bash

# Define variables
DIVTOOLS=/opt/divtools
HOSTNAME=$(hostname)
PXAR_FILE="${HOSTNAME}.pxar"
USER="root" # root | backupUser
REALM="pam" # pbs | pam
SERVER="192.168.9.101"
DATASTORE="fhmtn1-pbs"
NAMESPACE="nodes"
export PBS_PASSWORD=3mpms3

# Backup the local config first for later comparison
$DIVTOOLS/scripts/pbs/pbs-node-config.sh

# Backup both the root filesystem and /etc/pve
proxmox-backup-client backup \
  ${PXAR_FILE}:/ \
  etc-pve.pxar:/etc/pve \
  --repository ${USER}@${REALM}@${SERVER}:${DATASTORE} \
  --ns ${NAMESPACE} \
  --exclude /mnt


# Steps for recovery:
# 1) Reinstall Proxmox VE, same version, same NW access, etc.

# 2) Install proxmox-backup-client:
# apt update
# apt install proxmox-backup-client
#
# 3) Restore root filesystem
# To restore the base root filesystem (not including /etc/pve):
# proxmox-backup-client restore ${HOSTNAME}.pxar / --repository ${USER}@${REALM}@${SERVER}:${DATASTORE} --ns ${NAMESPACE}
# 
# 4) Restore /etc/pve 
# To restore the etc-pve backup, do the following:
# proxmox-backup-client restore etc-pve.pxar /restore-target/etc-pve \
#   --repository ${USER}@${REALM}@${SERVER}:${DATASTORE} \
#   --ns ${NAMESPACE}
# 5) Reinstall Bootloader (if necessary)
# grub-install /dev/sdX
# update-grub
#
# 6) Reboot the system
#
# Verify the restore
# systemctl status pve-cluster
# systemctl status pvedaemon
# systemctl status pveproxy
# Verify Cluster Memberrship
# pvecm status
# Verify VM/Container Status
# qm list
# pct list







