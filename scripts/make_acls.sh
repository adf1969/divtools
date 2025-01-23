#!/bin/bash

# Variables
ACL_BACKUP_DIR=~divix/ACL.backup
DATE=$(date +%Y-%m-%d)
LOGFILE="$ACL_BACKUP_DIR/make_acls.log"
QUIET=0

# Usage function
usage() {
    echo "Usage: $0 [-q]"
    echo "  -q : Output the commands without executing them"
    exit 1
}

# Logging function
log() {
    local message="$1"
    if [ $QUIET -eq 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a "$LOGFILE"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOGFILE"
    fi
}

# Parse arguments
while getopts "q" opt; do
    case $opt in
        q)
            QUIET=1
            ;;
        *)
            usage
            ;;
    esac
done

# Create backup directory if not exists
if [ $QUIET -eq 0 ]; then
    mkdir -p "$ACL_BACKUP_DIR"
fi

# Paths to backup
paths=(
    "/share/CACHEDEV1_DATA/Web"
    "/share/CACHEDEV1_DATA/Public"
    "/share/CACHEDEV1_DATA/homes"
    "/share/CACHEDEV1_DATA/AVCSHARE"
    "/share/CACHEDEV1_DATA/Google"
    "/share/CACHEDEV1_DATA/AVCSHARE/Company"
    "/share/CACHEDEV1_DATA/Google/avcorp.km"
    "/share/CACHEDEV3_DATA/SHARE"
    "/share/CACHEDEV1_DATA/Google/avcorp.km/AVC-SW/SOFTWARE"
    "/share/CACHEDEV1_DATA/Google/avcorp.km/AVC-SW/HARDWARE"
    "/share/CACHEDEV1_DATA/Multimedia"
    "/share/CACHEDEV1_DATA/Container"
    "/share/CACHEDEV1_DATA/AVCSHARE/PropMgmt"
    "/share/CACHEDEV1_DATA/AVCSHARE/Company-PMOnly"
    "/share/CACHEDEV1_DATA/AVCSHARE/Company/AVC/SharedDocs-AVC/PropMgmt/NWPublic"
    "/share/CACHEDEV1_DATA/AVCSHARE/AVC-Users"
)

# Process each path
for path in "${paths[@]}"; do
    if [ -d "$path" ]; then
        backup_file="$ACL_BACKUP_DIR/$(basename "$path")-$DATE.acl"
        command="getfacl -R \"$path\" > \"$backup_file\""
        
        log "Processing path: $path"
        log "Command: $command"

        if [ $QUIET -eq 0 ]; then
            eval $command
            if [ $? -eq 0 ]; then
                log "Backup successful: $backup_file"
                gzip_command="gzip \"$backup_file\""
                log "Compressing: $gzip_command"
                eval $gzip_command
                if [ $? -eq 0 ]; then
                    log "Compression successful: ${backup_file}.gz"
                else
                    log "Error compressing: $backup_file"
                fi
            else
                log "Error backing up: $path"
            fi
        fi
    else
        log "Path not found or not a directory: $path"
    fi
done

log "Script execution completed."

# End of script

