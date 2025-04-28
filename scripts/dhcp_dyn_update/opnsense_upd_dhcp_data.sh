#!/bin/sh

# OPNSense DHCP Static Mapping Exporter and Copier to Pi-hole

# Settings
PIHOLE_USER="divix"
PIHOLE_HOST="pihole.dyn-avctn.lan"
REMOTE_DIR="/opt/divtools/scripts/dhcp_dyn_update/data"
BASE_DIR="/home/divix/bin/dhcp_dyn_update"
DATA_DIR="$BASE_DIR/data"
OUTPUT_FILE="$DATA_DIR/opnsense_staticmap.txt"
CONFIG_FILE="/conf/config.xml"
EXPORT_SNAPSHOT="$DATA_DIR/opnsense_staticmap_last.xml"
CURRENT_XML="$DATA_DIR/opnsense_staticmap_current.xml"
SSH_KEY="/home/divix/.ssh/id_ed25519"

# Flags
TESTMODE=0
FORCE=0
DEBUG=0

# Ensure data directory exists
mkdir -p "$DATA_DIR"

# Parse Arguments
while [ $# -gt 0 ]; do
  case "$1" in
    -test)
      TESTMODE=1
      ;;
    -force)
      FORCE=1
      ;;
    -debug)
      DEBUG=1
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
  shift
done

log() {
  if [ "$DEBUG" -eq 1 ]; then
    echo "DEBUG: $1"
  fi
}

# Check if xmllint exists
if ! command -v xmllint >/dev/null 2>&1; then
  echo "❌ Error: xmllint is not installed."
  exit 1
fi

# Check if config.xml exists
if [ ! -f "$CONFIG_FILE" ]; then
  echo "❌ Error: OPNSense config file not found at $CONFIG_FILE."
  exit 1
fi

# Check if SSH key exists
if [ ! -f "$SSH_KEY" ]; then
  echo "❌ Error: SSH key not found at $SSH_KEY."
  exit 1
fi

# Extract current staticmap XML section with wrapper
echo "📋 Extracting static DHCP mappings from $CONFIG_FILE..."
{
  echo "<staticmaps>"
  xmllint --xpath '//dhcpd/lan/staticmap' "$CONFIG_FILE" 2>/dev/null
  echo "</staticmaps>"
} > "$CURRENT_XML"

if [ ! -s "$CURRENT_XML" ]; then
  echo "❌ Error: No static mappings found in XML."
  exit 1
fi

# Compare with previous snapshot
if [ "$FORCE" -eq 0 ] && [ -f "$EXPORT_SNAPSHOT" ]; then
  if cmp -s "$CURRENT_XML" "$EXPORT_SNAPSHOT"; then
    echo "✔️ No changes detected in static DHCP mappings."
    if [ "$TESTMODE" -eq 0 ]; then
      rm -f "$CURRENT_XML"
    fi
    exit 0
  else
    log "Changes detected in static DHCP mappings. Proceeding with export."
  fi
else
  log "Force enabled or no previous snapshot. Proceeding with export."
fi

# Save current snapshot as new baseline
cp "$CURRENT_XML" "$EXPORT_SNAPSHOT"

# Extract IP and sanitize Hostname
xmllint --format "$CURRENT_XML" | \
  awk -F'[<>]' '/<ipaddr>/ {ip=$3} /<hostname>/ {host=$3; gsub(/[^A-Za-z0-9-]/, "-", host); print ip, host}' > "$OUTPUT_FILE"

# Verify Output File
if [ ! -s "$OUTPUT_FILE" ]; then
  echo "❌ Error: No static mappings parsed or output file is empty."
  exit 1
fi

# Display for Debugging
if [ "$DEBUG" -eq 1 ]; then
  echo "✅ Extracted DHCP entries:"
  cat "$OUTPUT_FILE"
fi

# Copy to Pi-hole if not in test mode
if [ "$TESTMODE" -eq 1 ]; then
  echo "🧪 Test mode enabled. Skipping SCP to Pi-hole."
else
  echo "🚀 Copying $OUTPUT_FILE to $PIHOLE_USER@$PIHOLE_HOST:$REMOTE_DIR..."
  scp -i "$SSH_KEY" "$OUTPUT_FILE" "${PIHOLE_USER}@${PIHOLE_HOST}:${REMOTE_DIR}/"
  if [ $? -eq 0 ]; then
    echo "✔️ Successfully copied to Pi-hole."
  else
    echo "❌ Error copying file to Pi-hole."
    exit 1
  fi
fi

# Clean up
rm -f "$CURRENT_XML"

exit 0
