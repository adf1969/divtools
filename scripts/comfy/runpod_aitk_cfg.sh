#!/usr/bin/env bash
# =============================================================================
# /mnt/scripts/runpod_aitk_cfg.sh
#
# One-time setup script for new RunPod pods running ai-toolkit.
#
# Run this manually after every new pod starts:
#
#   cd /mnt/scripts
#   chmod +x runpod_aitk_cfg.sh
#   ./runpod_aitk_cfg.sh
#
# What it does:
#   1. Installs vim
#   2. Creates the persistent backup script /mnt/scripts/aitk_bk.sh
#      (automatically backs up ./aitk_db.db → /mnt/ai-toolkit every 5 min)
#   3. Adds alias 'aitk_bk' to ~/.bashrc that runs the persistent backup script
# =============================================================================

set -euo pipefail

echo "======================================"
echo "  RunPod ai-toolkit setup script"
echo "  Location: /mnt/scripts/runpod_aitk_cfg.sh"
echo "======================================"

# ──────────────────────────────────────────────────────────────────────────────
# 1. Install vim
# ──────────────────────────────────────────────────────────────────────────────

echo "→ Installing vim..."
sudo apt update -qq
sudo apt install -y vim

echo "→ vim installed. You can now use: vim filename"

# ──────────────────────────────────────────────────────────────────────────────
# 2. Create the persistent backup script: /mnt/scripts/aitk_bk.sh
# ──────────────────────────────────────────────────────────────────────────────

BACKUP_SCRIPT="/mnt/scripts/aitk_bk.sh"

echo "→ Creating persistent backup script: $BACKUP_SCRIPT"

cat > "$BACKUP_SCRIPT" << 'INNER_EOF'
#!/usr/bin/env bash
# =============================================================================
# /mnt/scripts/aitk_bk.sh
# Automatically backups ./aitk_db.db → /mnt/ai-toolkit every 5 minutes
# Started via alias: aitk_bk
# Keeps 10 timestamped backups with rotation
# =============================================================================

set -euo pipefail

SOURCE_DB="./aitk_db.db"
DEST_DIR="/mnt/ai-toolkit"
DEST_DB="$DEST_DIR/aitk_db.db"
BACKUP_INTERVAL=300          # 5 minutes
MAX_BACKUPS=10

PID_FILE="/tmp/aitk_bk.pid"
LOG_FILE="$DEST_DIR/aitk_bk.log"

# ─── Check if already running ────────────────────────────────────────────────

if [ -f "$PID_FILE" ]; then
  OLD_PID=$(cat "$PID_FILE")
  if kill -0 "$OLD_PID" 2>/dev/null; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Already running (PID $OLD_PID). Restarting..." | tee -a "$LOG_FILE"
    kill "$OLD_PID" 2>/dev/null || true
    sleep 1
  fi
fi

echo $$ > "$PID_FILE"

echo "$(date '+%Y-%m-%d %H:%M:%S') - Backup loop starting" | tee -a "$LOG_FILE"

while true; do
  if [ -f "$SOURCE_DB" ]; then
    cp -f "$SOURCE_DB" "$DEST_DB"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Copied to $DEST_DB" | tee -a "$LOG_FILE"

    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    cp -f "$SOURCE_DB" "$DEST_DIR/aitk_db_backup_$TIMESTAMP.db"

    cd "$DEST_DIR" || exit 1
    ls -t aitk_db_backup_*.db 2>/dev/null | tail -n +$((MAX_BACKUPS + 1)) | xargs -r rm -f
  else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - DB not found: $SOURCE_DB" | tee -a "$LOG_FILE"
  fi

  sleep "$BACKUP_INTERVAL"
done
INNER_EOF

chmod +x "$BACKUP_SCRIPT"

echo "→ Backup script created and made executable at $BACKUP_SCRIPT"

# ──────────────────────────────────────────────────────────────────────────────
# 3. Add alias to ~/.bashrc (points to the persistent script)
# ──────────────────────────────────────────────────────────────────────────────

ALIAS_LINE='alias aitk_bk="bash /mnt/scripts/aitk_bk.sh &"'

if ! grep -q "alias aitk_bk=" ~/.bashrc; then
  echo "$ALIAS_LINE" >> ~/.bashrc
  echo "→ Added alias 'aitk_bk' to ~/.bashrc (points to /mnt/scripts/aitk_bk.sh)"
else
  echo "→ Alias 'aitk_bk' already exists in ~/.bashrc"
fi

# ──────────────────────────────────────────────────────────────────────────────
# 4. Final instructions
# ──────────────────────────────────────────────────────────────────────────────

echo ""
echo "Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Reload shell aliases:   source ~/.bashrc"
echo "  2. Start the backup:       aitk_bk"
echo "  3. Watch logs:             tail -f /mnt/ai-toolkit/aitk_bk.log"
echo ""
echo "Backups are written to:"
echo "  Live mirror:     /mnt/ai-toolkit/aitk_db.db"
echo "  Timestamped:     /mnt/ai-toolkit/aitk_db_backup_*.db (last 10 kept)"
echo ""
echo "You only need to run this script once per new pod."
echo "Happy training!"
SCRIPT_EOF

# Make the main script executable
chmod +x /mnt/scripts/runpod_aitk_cfg.sh

echo ""
echo "Script saved to /mnt/scripts/runpod_aitk_cfg.sh"
echo "Run it now:"
echo "  /mnt/scripts/runpod_aitk_cfg.sh"
echo ""
echo "After it finishes, you can use 'aitk_bk' to start the background backup."