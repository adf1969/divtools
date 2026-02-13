# Samba AD DC Bash Aliases for Containerized Commands
# Deploy Location: Add to /home/divix/.bash_aliases or include in divtools/dotfiles/.bash_aliases
# Last Updated: 12/5/2025 8:00:00 AM CST
#
# These aliases make working with Samba in a container transparent.
# Instead of typing: docker exec -it samba-ads1 samba-tool user list
# You can just type: samba-tool user list

# Detect if Samba container exists on this host
# Container name: samba-ads
SAMBA_CONTAINER=$(docker ps --format '{{.Names}}' 2>/dev/null | grep '^samba-ads$' | head -n1)

if [ -n "$SAMBA_CONTAINER" ]; then
    # Core Samba Administrative Tools
    alias samba-tool="docker exec -it $SAMBA_CONTAINER samba-tool"
    alias smbclient="docker exec -it $SAMBA_CONTAINER smbclient"
    alias smbstatus="docker exec -it $SAMBA_CONTAINER smbstatus"
    alias wbinfo="docker exec -it $SAMBA_CONTAINER wbinfo"
    alias net="docker exec -it $SAMBA_CONTAINER net"
    alias nmblookup="docker exec -it $SAMBA_CONTAINER nmblookup"
    alias testparm="docker exec -it $SAMBA_CONTAINER testparm"
    
    # LDAP Tools (for directory queries)
    alias ldapsearch="docker exec -it $SAMBA_CONTAINER ldapsearch"
    alias ldapadd="docker exec -it $SAMBA_CONTAINER ldapadd"
    alias ldapmodify="docker exec -it $SAMBA_CONTAINER ldapmodify"
    alias ldapdelete="docker exec -it $SAMBA_CONTAINER ldapdelete"
    alias ldapwhoami="docker exec -it $SAMBA_CONTAINER ldapwhoami"
    
    # Kerberos Tools (for authentication)
    alias kinit="docker exec -it $SAMBA_CONTAINER kinit"
    alias klist="docker exec -it $SAMBA_CONTAINER klist"
    alias kdestroy="docker exec -it $SAMBA_CONTAINER kdestroy"
    alias ktutil="docker exec -it $SAMBA_CONTAINER ktutil"
    
    # DNS Tools (for DNS management within Samba)
    alias samba-dns="docker exec -it $SAMBA_CONTAINER samba-tool dns"
    
    # Management Shortcuts
    alias ads-shell="docker exec -it $SAMBA_CONTAINER /bin/bash"
    alias ads-logs="docker logs -f $SAMBA_CONTAINER"
    alias ads-restart="docker restart $SAMBA_CONTAINER"
    alias ads-stop="docker stop $SAMBA_CONTAINER"
    alias ads-start="docker start $SAMBA_CONTAINER"
    alias ads-status="docker exec -it $SAMBA_CONTAINER samba-tool domain info 127.0.0.1"
    alias ads-fsmo="docker exec -it $SAMBA_CONTAINER samba-tool fsmo show"
    alias ads-repl="docker exec -it $SAMBA_CONTAINER samba-tool drs showrepl"
    alias ads-health="docker exec -it $SAMBA_CONTAINER samba-tool domain info 127.0.0.1 && docker exec -it $SAMBA_CONTAINER samba-tool drs showrepl"
    
    # Quick access to common operations
    alias ads-users="docker exec -it $SAMBA_CONTAINER samba-tool user list"
    alias ads-groups="docker exec -it $SAMBA_CONTAINER samba-tool group list"
    alias ads-computers="docker exec -it $SAMBA_CONTAINER samba-tool computer list"
    alias ads-dns-zones="docker exec -it $SAMBA_CONTAINER samba-tool dns zonelist localhost -U Administrator"
    
    # Functions for more complex operations
    
    # Execute arbitrary command in Samba container
    ads-exec() {
        docker exec -it "$SAMBA_CONTAINER" "$@"
    }
    
    # Create a new user with common defaults
    ads-user-create() {
        if [ -z "$1" ]; then
            echo "Usage: ads-user-create <username> [password]"
            echo "If password not provided, you will be prompted."
            return 1
        fi
        
        local username="$1"
        local password="${2}"
        
        if [ -z "$password" ]; then
            docker exec -it "$SAMBA_CONTAINER" samba-tool user create "$username" --must-change-at-next-login
        else
            docker exec -it "$SAMBA_CONTAINER" samba-tool user create "$username" "$password"
        fi
    }
    
    # Reset user password
    ads-user-resetpw() {
        if [ -z "$1" ]; then
            echo "Usage: ads-user-resetpw <username> [new_password]"
            echo "If password not provided, you will be prompted."
            return 1
        fi
        
        local username="$1"
        local password="${2}"
        
        if [ -z "$password" ]; then
            docker exec -it "$SAMBA_CONTAINER" samba-tool user setpassword "$username"
        else
            docker exec -it "$SAMBA_CONTAINER" samba-tool user setpassword "$username" --newpassword="$password"
        fi
    }
    
    # Disable user account
    ads-user-disable() {
        if [ -z "$1" ]; then
            echo "Usage: ads-user-disable <username>"
            return 1
        fi
        docker exec -it "$SAMBA_CONTAINER" samba-tool user disable "$1"
    }
    
    # Enable user account
    ads-user-enable() {
        if [ -z "$1" ]; then
            echo "Usage: ads-user-enable <username>"
            return 1
        fi
        docker exec -it "$SAMBA_CONTAINER" samba-tool user enable "$1"
    }
    
    # Add user to group
    ads-group-addmember() {
        if [ -z "$1" ] || [ -z "$2" ]; then
            echo "Usage: ads-group-addmember <groupname> <username>"
            return 1
        fi
        docker exec -it "$SAMBA_CONTAINER" samba-tool group addmembers "$1" "$2"
    }
    
    # View Samba configuration
    ads-config() {
        docker exec -it "$SAMBA_CONTAINER" cat /etc/samba/smb.conf
    }
    
    # View Samba logs with optional filtering
    ads-log() {
        local logfile="${1:-log.samba}"
        docker exec -it "$SAMBA_CONTAINER" tail -f "/var/log/samba/$logfile"
    }
    
    # Backup Samba data (offline backup)
    ads-backup() {
        local backup_dir="${1:-/tmp/samba-backup-$(date +%Y%m%d-%H%M%S)}"
        echo "Creating backup to: $backup_dir"
        docker exec -it "$SAMBA_CONTAINER" samba-tool domain backup offline --targetdir=/tmp/backup
        docker cp "$SAMBA_CONTAINER:/tmp/backup" "$backup_dir"
        echo "Backup completed: $backup_dir"
    }
    
    # Display helpful message
    echo "Samba AD DC aliases loaded for container: $SAMBA_CONTAINER"
    echo "Try: ads-status, ads-users, ads-shell, ads-logs, or any samba-tool command"
fi
