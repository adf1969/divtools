#!/bin/bash
# Samba AD DC Native Installation Bash Aliases
# Last Updated: 01/10/2026 10:50:00 PM CST
#
# These aliases provide convenient shortcuts for native Samba operations
# (no docker exec needed - direct samba-tool commands)

# Check if samba-tool exists before creating aliases
if command -v samba-tool &> /dev/null; then
    # Service Management
    alias ads-status='sudo systemctl status samba-ad-dc'
    alias ads-start='sudo systemctl start samba-ad-dc'
    alias ads-stop='sudo systemctl stop samba-ad-dc'
    alias ads-restart='sudo systemctl restart samba-ad-dc'
    alias ads-logs='sudo journalctl -u samba-ad-dc -f'
    alias ads-logs-recent='sudo journalctl -u samba-ad-dc -n 100 --no-pager'

    # Health Checks
    alias ads-health='sudo samba-tool domain info 127.0.0.1'
    alias ads-fsmo='sudo samba-tool fsmo show'
    alias ads-replication='sudo samba-tool drs showrepl'
    alias ads-testparm='sudo testparm'

    # User Management
    alias ads-users='sudo samba-tool user list'
    alias ads-adduser='sudo samba-tool user add'
    alias ads-deluser='sudo samba-tool user delete'
    alias ads-resetpass='sudo samba-tool user setpassword'
    alias ads-showuser='sudo samba-tool user show'

    # Group Management
    alias ads-groups='sudo samba-tool group list'
    alias ads-addgroup='sudo samba-tool group add'
    alias ads-delgroup='sudo samba-tool group delete'
    alias ads-groupmembers='sudo samba-tool group listmembers'
    alias ads-addtogroup='sudo samba-tool group addmembers'

    # Computer Management
    alias ads-computers='sudo samba-tool computer list'
    alias ads-delcomputer='sudo samba-tool computer delete'

    # DNS Management
    alias ads-dns-list='sudo samba-tool dns zonelist localhost -U administrator'
    alias ads-dns-query='sudo samba-tool dns query'
    alias ads-dns-add='sudo samba-tool dns add'
    alias ads-dns-delete='sudo samba-tool dns delete'

    # Testing
    alias ads-kinit='kinit administrator@${ADS_REALM:-AVCTN.LAN}'
    alias ads-klist='klist'
    alias ads-smbclient='smbclient -L localhost -U administrator'

    # Configuration
    alias ads-editconf='sudo nano /etc/samba/smb.conf'
    alias ads-editkrb5='sudo nano /etc/krb5.conf'
    alias ads-viewconf='sudo cat /etc/samba/smb.conf'

    # Logs and Diagnostics
    alias ads-dbcheck='sudo samba-tool dbcheck'
    alias ads-dbcheck-fix='sudo samba-tool dbcheck --fix'
    alias ads-level='sudo samba-tool domain level show'

    echo "Samba AD DC Native Aliases loaded (no docker - direct commands)"
#else
    # echo "Warning: samba-tool not found - Samba aliases not loaded"
    # echo "Install Samba first: sudo apt-get install samba"
fi

