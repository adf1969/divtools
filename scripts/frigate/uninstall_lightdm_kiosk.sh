#!/bin/bash
# uninstall_lightdm_kiosk.sh
# Uninstalls LightDM Kiosk Mode setup

set -e


echo "This script will uninstall the LightDM kiosk environment."
echo "It will:"
echo " - Stop and remove LightDM, Chromium, Openbox, and X11"
echo " - Remove autostart configs"
echo " - Leave the user 'frigatekiosk' intact"
echo ""
read -rp "Continue with uninstallation? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Uninstallation cancelled."
    exit 1
fi


echo "Stopping LightDM if running..."
systemctl stop lightdm || true

echo "Disabling LightDM service..."
systemctl disable lightdm || true

echo "Removing installed packages..."
apt purge -y lightdm openbox chromium xserver-xorg x11-xserver-utils xinit

echo "Autoremove unnecessary packages..."
apt autoremove -y

echo "Removing user autostart settings..."
rm -rf /home/root/.config/openbox

echo "Restoring original LightDM config if backup exists..."
if [ -f /etc/lightdm/lightdm.conf.bak ]; then
    mv /etc/lightdm/lightdm.conf.bak /etc/lightdm/lightdm.conf
fi

echo "Uninstallation complete. Reboot recommended."
