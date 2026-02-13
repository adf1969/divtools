#!/bin/bash

# Define variables
HOSTNAME=$(hostname)
PXAR_FILE="${HOSTNAME}.pxar"
USER="root" # root | backupUser
REALM="pam" # pbs | pam
SERVER="192.168.9.101"
DATASTORE="fhmtn1-pbs"
NAMESPACE="nodes"
export PBS_PASSWORD=3mpms3

proxmox-backup-client backup ${PXAR_FILE}:/ --repository ${USER}@${REALM}@${SERVER}:${DATASTORE} --ns ${NAMESPACE} --exclude /mnt
