#!/bin/bash

# Load variables from .env if present
if [ -f "/opt/divtools/dotfiles/.bash_profile" ]; then
  set -a
  source "/opt/divtools/dotfiles/.bash_profile" 2>/dev/null  # Redirect stderr to suppress warnings
  set +a
fi

# Fallback for DIVTOOLS if not set
if [ -z "$DIVTOOLS" ]; then
  DIVTOOLS="/opt/divtools"
  echo "⚠️ DIVTOOLS not set in .bash_profile, defaulting to $DIVTOOLS"
fi

# Function to set ownership and permissions on a file or directory
set_perm() {
  local arg="$1"
  local user="$2"
  local group="$3"
  local perm="$4"
  local fpath="$5"

  if [ -z "$fpath" ]; then
    echo "❌ Missing path for set_perm: $fpath"
    return 1
  fi

  if [ -n "$user" ]; then
    if [ -n "$group" ]; then
      echo "Chg Ownership: $arg, $user:$group for $fpath"
      chown $arg "$user:$group" "$fpath"
    else
      echo "Chg Ownership: $arg, $user for $fpath"
      chown $arg "$user" "$fpath"
    fi
  fi

  if [ -n "$perm" ]; then
    echo "Chg Perms: $arg, $perm for $fpath"
    chmod $arg "$perm" "$fpath"
  fi
}

# Set group ownership to syncthing for all files and directories in DIVTOOLS
echo "Setting group syncthing on $DIVTOOLS"
chgrp -R syncthing "$DIVTOOLS"

# Add group read/write for files
echo "Adding g+rw for files in $DIVTOOLS"
find "$DIVTOOLS" -type f -exec chmod g+rw {} \;

# Add group read/write/execute for directories
echo "Adding g+rwx for directories in $DIVTOOLS"
find "$DIVTOOLS" -type d -exec chmod g+rwx {} \;

# Set SetGID bit on directories for group inheritance
echo "Setting SetGID bit on directories in $DIVTOOLS"
find "$DIVTOOLS" -type d -exec chmod g+s {} \;

# Ensure *.sh files have u+x,g+x
echo "Adding u+x,g+x for *.sh files in $DIVTOOLS"
find "$DIVTOOLS" -type f -name "*.sh" -exec chmod u+x,g+x {} \;

# Existing folder permissions from your script
set_perm "-R" "divix" "" "" "$DOCKERDIR"
set_perm "-R" "divix" "" "" "$DIVTOOLS/config"
set_perm "-R" "divix" "" "" "$DIVTOOLS/scripts"
set_perm "-R" "divix" "" "" "$DIVTOOLS/dotfiles"
#set_perm "-R" "divix" "" "" "$DIVTOOLS/.git"

# TRAEFIK
#set_perm "" "divix" "divix" "0600" "$DOCKERDIR/appdata/traefik3/acme/acme.json"
#set_perm "" "root" "root" "0400" "$DOCKERDIR/secrets/basic_auth_credentials"
#set_perm "" "root" "root" "0400" "$DOCKERDIR/secrets/cf_dns_api_token_traefik3_divix_biz"