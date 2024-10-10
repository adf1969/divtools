  #!/bin/sh
  LOGFILE="/etc/logs/adf_custom_startup.log"
  NEW_OPT_LOC="/share/CACHEDEV1_DATA/opt"

  log() {
      echo "$(date '+%Y-%m-%d %H:%M:%S') : $1" >> $LOGFILE
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
cat <<EOF >> /etc/profile
# Call Custom Profiles
echo "Running /etc/profile"
#if [ -f ~/.bash_profile_cust ]; then
#  . ~/.bash_profile_cust
#fi
if [ -f /opt/home/root/.bash_profile ]; then
  . /opt/home/root/.bash_profile
fi
EOF

# Fix the /root homedir
log "** Fix /root files"
/opt/home/root/scripts/mk_homedir_links.sh

# Copy this file to /opt/etc/config/. This backs up this file
#cp /etc/config/adf_custom_startup.sh /opt/etc/config/adf_custom_startup.sh

log "END: Custom startup script executed successfully"

