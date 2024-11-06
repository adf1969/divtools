  #!/bin/sh
  LOGFILE="/etc/logs/adf_custom_startup.log"
  NEW_OPT_LOC="/share/CACHEDEV1_DATA/opt"   # Set to location where you want /opt to be

  log() {
      echo "$(date '+%Y-%m-%d %H:%M:%S') : $1" >> $LOGFILE
  }

# Check if the script is run as root or a non-root user
function run_cmd() {
    if [[ $EUID -ne 0 ]]; then
        sudo $@
    else
        $@
    fi
}

# Update /etc/profile
function update_profile() {
    if grep -q "#DIVTOOLS-BEFORE" /etc/profile; then
        # If the DIVTOOLS block exists, replace the content between BEFORE and AFTER
        echo "Updating Divtools entry in /etc/profile."
        run_cmd sed -i '/#DIVTOOLS-BEFORE/,/#DIVTOOLS-AFTER/c\
#DIVTOOLS-BEFORE\n\
# Source divtools profile\n\
if [ -f /opt/divtools/dotfiles/.bash_profile ]; then\n\
    . /opt/divtools/dotfiles/.bash_profile\n\
fi\n\
#DIVTOOLS-AFTER' /etc/profile
    else
        # If the DIVTOOLS block doesn't exist, append it to the file
        echo "Adding Divtools entry to /etc/profile."
        run_cmd tee -a /etc/profile > /dev/null <<EOL

#DIVTOOLS-BEFORE
# Source divtools profile
if [ -f /opt/divtools/dotfiles/.bash_profile ]; then
    . /opt/divtools/dotfiles/.bash_profile
fi
#DIVTOOLS-AFTER
EOL
    fi
}

  log "START: Executing adf_custom_startup.sh"

  log "** Fix /opt"
  if [ -L /opt ]; then
      log "/opt is already a symbolic link"
  else
    # Remove the existing /opt directory if it exists
    rm -rf /opt
    log "/opt directory removed"

    # Create a symbolic link to the new /opt location
    ln -s  $NEW_OPT_LOC /opt
    log "Created symbolic link /opt -> $NEW_OPT_LOC"
  fi

#log "** Start opkg scripts. Running /opt/etc/init.d/rc.unslung start"
#/opt/etc/init.d/rc.unslung start

# Fix the /etc/profile
log "** Fix /etc/profile"
update_profile

# Fix the /root homedir
log "** Fix /root files"
/opt/divtools/qnap_cfg/scripts/mk_homedir_links.sh

# Copy this file to /opt/etc/config/. This backs up this file
#cp /etc/config/adf_custom_startup.sh /opt/etc/config/adf_custom_startup.sh

log "END: Custom startup script executed successfully"

