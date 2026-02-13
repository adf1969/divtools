#!/bin/bash
# install_lightdm_kiosk.sh
# Installs LightDM + X11 + Chromium browser for Proxmox Kiosk Mode using user 'frigatekiosk' (UID 1410)

set -e

KIOSK_USER="frigatekiosk"
KIOSK_UID="1410"
KIOSK_HOME="/home/${KIOSK_USER}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"  # directory where this install script is located
FRIGATE_URL_DEFAULT="http://192.168.9.234:5000"

echo "This script will install a kiosk environment using LightDM, Openbox, and Chromium."
echo "It will:"
echo " - Create or reuse user 'frigatekiosk' with UID 1410"
echo " - Install required packages"
echo " - Configure autologin and kiosk display of Frigate"
echo " - Copy local files: kiosk_watchdog.sh and offline.html"
echo ""
read -rp "Continue with installation? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Installation cancelled."
    exit 1
fi

echo "Updating package lists..."
apt update

echo "Installing required packages..."
apt install -y --no-install-recommends \
    xserver-xorg \
    x11-xserver-utils \
    xinit \
    openbox \
    lightdm \
    chromium

echo "Ensuring user '${KIOSK_USER}' (UID ${KIOSK_UID}) exists..."
if id "${KIOSK_USER}" >/dev/null 2>&1; then
    echo "User ${KIOSK_USER} already exists. Skipping creation."
else
    useradd -m -u "${KIOSK_UID}" -s /bin/bash "${KIOSK_USER}"
    echo "Created user ${KIOSK_USER} with UID ${KIOSK_UID}."
fi

echo "Setting FRIGATE_URL in user profile (~/.profile)..."
grep -q "FRIGATE_URL=" "${KIOSK_HOME}/.profile" || echo "export FRIGATE_URL=${FRIGATE_URL_DEFAULT}" >> "${KIOSK_HOME}/.profile"
chown "${KIOSK_USER}:${KIOSK_USER}" "${KIOSK_HOME}/.profile"

echo "Creating autostart config for openbox..."
mkdir -p "${KIOSK_HOME}/.config/openbox"

cat <<'EOF' > "${KIOSK_HOME}/.config/openbox/autostart"
#!/bin/bash
xset s off
xset -dpms
xset s noblank

# Run watchdog that waits for Frigate
/home/frigatekiosk/kiosk_watchdog.sh &
EOF

chown "${KIOSK_USER}:${KIOSK_USER}" "${KIOSK_HOME}/.config/openbox/autostart"
chmod +x "${KIOSK_HOME}/.config/openbox/autostart"

echo "Copying watchdog script and offline page to ${KIOSK_HOME}..."

install -m 755 "${SCRIPT_DIR}/kiosk_watchdog.sh" "${KIOSK_HOME}/kiosk_watchdog.sh"
install -m 644 "${SCRIPT_DIR}/offline.html" "${KIOSK_HOME}/offline.html"
chown "${KIOSK_USER}:${KIOSK_USER}" "${KIOSK_HOME}/kiosk_watchdog.sh" "${KIOSK_HOME}/offline.html"

echo "Configuring LightDM autologin for ${KIOSK_USER}..."
cp /etc/lightdm/lightdm.conf /etc/lightdm/lightdm.conf.bak 2>/dev/null || true
sed -i "s/^#*autologin-user=.*/autologin-user=${KIOSK_USER}/" /etc/lightdm/lightdm.conf
sed -i "s/^#*autologin-session=.*/autologin-session=openbox/" /etc/lightdm/lightdm.conf

echo "Installation complete. Reboot to activate kiosk mode."
