#!/bin/sh

# You basically want the lines in the file to look like this:
#                    if (res === null || res === undefined || !res || res
#                        .data.status.toLowerCase() == 'NoMoreNagging') {
# the below does something simlar
sed -i.backup -z "s/res === null || res === undefined || \!res || res\n\t\t\t.data.status.toLowerCase() \!== 'active'/false/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js 
systemctl restart pveproxy.service