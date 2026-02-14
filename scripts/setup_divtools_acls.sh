#!/bin/bash

# ===============================================
# divtools_setup_acls.sh
# Apply ACLs for LXC-mapped users to a shared folder (e.g., /opt/divtools)
# ===============================================

# Ensure script is run on Proxmox host, not inside an LXC
if [ ! -f /etc/pve/.version ]; then
  echo "[ERROR] This script must be run on a Proxmox host, not inside a container or VM."
  exit 1
fi


# Set environment variables if not already defined
: "${LXC_UID_ROOT:=100000}"
: "${LXC_UID_DIVIX:=101400}"

# Function to apply ACLs to a given path
apply_lxc_acls() {
  local target_path="$1"

  if [ ! -d "$target_path" ]; then
    echo "[ERROR] Path '$target_path' does not exist or is not a directory."
    return 1
  fi

  echo "[INFO] Applying ACLs to '$target_path'..."

  # Apply immediate ACLs
  echo "[INFO] Setting immediate ACLs for users $LXC_UID_ROOT and $LXC_UID_DIVIX"
  setfacl -R -m u:${LXC_UID_ROOT}:rwx "$target_path"
  setfacl -R -m u:${LXC_UID_DIVIX}:rwx "$target_path"

  # Apply default ACLs (for future files)
  echo "[INFO] Setting default ACLs for users $LXC_UID_ROOT and $LXC_UID_DIVIX"
  setfacl -R -d -m u:${LXC_UID_ROOT}:rwx "$target_path"
  setfacl -R -d -m u:${LXC_UID_DIVIX}:rwx "$target_path"

  echo "[SUCCESS] ACLs applied successfully to '$target_path'."
}

# ========================
# Main Execution
# ========================

TARGET_DIR="/opt/divtools"

apply_lxc_acls "$TARGET_DIR"

# End of script
