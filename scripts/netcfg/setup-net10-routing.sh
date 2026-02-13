#!/bin/bash

SERVICE_NAME="net10-routing.service"
SERVICE_PATH="/etc/systemd/system/$SERVICE_NAME"
SCRIPT_PATH="/usr/local/sbin/setup-net10-routing.sh"

install_mode=false

# === Handle CLI args ===
if [[ "$1" == "-install" ]]; then
    install_mode=true
fi

# === Step 1: Ensure /etc/iproute2/rt_tables contains 'net10' ===
if ! grep -q '^100[[:space:]]\+net10' /etc/iproute2/rt_tables; then
    echo "100 net10" >> /etc/iproute2/rt_tables
    echo "[+] Added routing table 'net10'"
fi

# === Step 2: Determine 10.1.x.x source IP ===
SRC_IP=$(ip -4 addr show | grep -oP '10\.1\.\d+\.\d+' | head -n 1)

if [[ -z "$SRC_IP" ]]; then
    echo "[-] ERROR: No 10.1.x.x IP found on any interface. Aborting rule setup."
    exit 1
fi

echo "[+] Detected 10.1.x.x source IP: $SRC_IP"

# === Step 3: Add default and fallback routes ===
ip route replace default via 192.168.8.1 dev eth0 metric 10
ip route replace default via 10.1.1.1 dev net1 metric 100

# === Step 4: Add custom net10 table routes ===
ip route replace 10.1.0.0/20 dev net1 table net10
ip route replace default via 10.1.1.1 dev net1 table net10

# === Step 5: Add ip rule for detected IP ===
if ! ip rule list | grep -q "from $SRC_IP.*table net10"; then
    ip rule add from "$SRC_IP"/32 table net10 priority 99
    echo "[+] Added ip rule for $SRC_IP via net10"
else
    echo "[i] Rule for $SRC_IP via net10 already exists"
fi

# === Step 6: If -install flag passed, create systemd service ===
if $install_mode; then
    echo "[*] Installing systemd unit..."

    cat > "$SERVICE_PATH" <<EOF
[Unit]
Description=Custom net10 routing rules
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=$SCRIPT_PATH
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

    chmod 644 "$SERVICE_PATH"
    echo "[+] Created $SERVICE_PATH"

    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME"
    echo "[+] Enabled $SERVICE_NAME to run at boot"
fi

exit 0
