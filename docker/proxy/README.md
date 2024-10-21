# Pihole
Check and ensure that the host is not running anything on port 53.
This can be done with:
lsof -i :53
or
ss -tuln | grep :53
If there is something running there, disable it.
For example, to disable systemd-resolved:
Stop the systemd service
$ sudo systemctl stop systemd-resolved
Disable the service from starting on reboot
$ sudo systemctl disable systemd-resolved


# Unbound
Copy all of the files in the ./unbound folder to /opt/unbound/
This will cause Unbound to use the /opt/unbound/*.conf files as the startup-config