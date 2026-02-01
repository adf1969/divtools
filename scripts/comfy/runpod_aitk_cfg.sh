#!/usr/bin/env bash

# /mnt/scripts/runpod_aitk_cfg.sh
# Run once per new pod: chmod +x /mnt/scripts/runpod_aitk_cfg.sh && ./runpod_aitk_cfg.sh

set -euo pipefail

# Install vim (no sudo)
apt update -qq
apt install -y vim

# Create backup script in persistent location
BACKUP_SCRIPT="/mnt/scripts/aitk_bk.sh"

cat > "$BACKUP_SCRIPT" << 'EOF'
#!/usr/bin/env bash

# /mnt/scripts/aitk_bk.sh - Backup ./aitk_db.db to /mnt/ai-toolkit every 5 min

set -euo pipefail

SOURCE_DB="./aitk_db.db"
DEST_DIR="/mnt/ai-toolkit"
DEST_DB="$DEST_DIR/aitk_db.db"
INTERVAL=300
MAX_BACKUPS=10

PID_FILE="/tmp/aitk_bk.pid"
LOG_FILE="$DEST_DIR/aitk_bk.log"

# Restart if already running
if [ -f "$PID_FILE" ]; then
  OLD_PID=$(cat "$PID_FILE")
  if kill -0 "$OLD_PID" 2>/dev/null; then
    kill "$OLD_PID" 2>/dev/null
    sleep 1
  fi
fi

echo $$ > "$PID_FILE"

while true; do
  if [ -f "$SOURCE_DB" ]; then
    cp -f "$SOURCE_DB" "$DEST_DB"
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    cp -f "$SOURCE_DB" "$DEST_DIR/aitk_db_backup_$TIMESTAMP.db"
    cd "$DEST_DIR"
    ls -t aitk_db_backup_*.db 2>/dev/null | tail -n +$((MAX_BACKUPS+1)) | xargs -r rm -f
  fi
  sleep "$INTERVAL"
done
EOF

chmod +x "$BACKUP_SCRIPT"

# Add alias
ALIAS='alias aitk_bk="bash /mnt/scripts/aitk_bk.sh &"'
if ! grep -q "alias aitk_bk=" ~/.bashrc; then
  echo "$ALIAS" >> ~/.bashrc
fi

echo "Done. Run 'source ~/.bashrc' then 'aitk_bk' to start backup."
echo "Logs: tail -f /mnt/ai-toolkit/aitk_bk.log"