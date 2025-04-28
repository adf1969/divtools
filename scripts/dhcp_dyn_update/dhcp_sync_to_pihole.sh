#!/bin/bash

# SETTINGS
DATA_PATH="/opt/divtools/scripts/dhcp_dyn_update/data"
RESERVATIONS_FILE="${DATA_PATH}/qnap_nm_dhcpd.conf"
LEASES_FILE="${DATA_PATH}/qnap_eth0_leases.txt"
TIMESTAMP_FILE="${DATA_PATH}/.last_processed"
PIHOLE_CUSTOM_LIST="/etc/pihole/custom.list"
BACKUP_PATH="/opt/divtools/scripts/dhcp_dyn_update/backups"
DOMAIN_SUFFIX="dyn-avctn.lan"
RETENTION_DAYS=30

# DEFAULT FLAGS
DEBUG=0
TESTMODE=0
ADD_DOMAIN=0
FORCE=0
BACKUP_ONLY=0

# LOG FUNCTION
log() {
    if [[ $DEBUG -eq 1 ]]; then
        echo "DEBUG: $1"
    fi
}

# PARSE ARGUMENTS
while [[ $# -gt 0 ]]; do
    case "$1" in
        -debug)
            DEBUG=1
            shift
            ;;
        -test)
            TESTMODE=1
            shift
            ;;
        -add-domain)
            ADD_DOMAIN=1
            shift
            ;;
        -domain)
            DOMAIN_SUFFIX="$2"
            shift 2
            ;;
        -force)
            FORCE=1
            shift
            ;;
        -backup)
            BACKUP_ONLY=1
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

log "Starting DHCP sync script. TESTMODE=$TESTMODE, DEBUG=$DEBUG, ADD_DOMAIN=$ADD_DOMAIN, FORCE=$FORCE, BACKUP_ONLY=$BACKUP_ONLY, DOMAIN_SUFFIX=$DOMAIN_SUFFIX"

# Ensure backup path exists
mkdir -p "$BACKUP_PATH"

# Perform backup cleanup first
find "$BACKUP_PATH" -type f -mtime +$RETENTION_DAYS -exec rm -f {} \;

# If only backup is requested
if [[ "$BACKUP_ONLY" -eq 1 ]]; then
    BACKUP_FILE="$BACKUP_PATH/custom.list.$(date +%Y%m%d%H%M%S)"
    cp "$PIHOLE_CUSTOM_LIST" "$BACKUP_FILE"
    echo "✔️ Backup of Pi-hole list saved: $BACKUP_FILE"
    exit 0
fi

# Check if data files exist
if [[ ! -f "$RESERVATIONS_FILE" ]]; then
    echo "❌ Reservation file missing: $RESERVATIONS_FILE"
    exit 1
fi

# Check if processing is necessary
CURRENT_TIMESTAMP=$(stat -c %Y "$RESERVATIONS_FILE")
LAST_TIMESTAMP=0
if [[ -f "$TIMESTAMP_FILE" ]]; then
    LAST_TIMESTAMP=$(cat "$TIMESTAMP_FILE")
fi

if [[ "$FORCE" -eq 0 && "$CURRENT_TIMESTAMP" -le "$LAST_TIMESTAMP" ]]; then
    echo "✔️ No changes detected based on timestamp. Exiting after backup cleanup."
    exit 0
fi

# Extract JSON array from reservations
log "Extracting reservation JSON..."
grep 'reserved_ip =' "$RESERVATIONS_FILE" | \
    sed -e 's/^.*reserved_ip = //' > /tmp/qnap_reservations.json

# Validate JSON extraction
if [[ ! -s /tmp/qnap_reservations.json ]]; then
    echo "❌ Failed to extract reservation JSON."
    exit 1
fi

# Parse QNAP reservations into temporary file
TMP_OUTPUT="/tmp/qnap_dns_entries.txt"
log "Parsing reservations into $TMP_OUTPUT..."
> "$TMP_OUTPUT"
jq -r '.[] | "\(.IP_address) \(.Device_name).'"${DOMAIN_SUFFIX}"'"' /tmp/qnap_reservations.json > "$TMP_OUTPUT"

# Merge old and new entries
log "Merging old Pi-hole entries with QNAP DHCP entries..."
cp "${PIHOLE_CUSTOM_LIST}" "${PIHOLE_CUSTOM_LIST}.bak"
cat "$TMP_OUTPUT" "${PIHOLE_CUSTOM_LIST}.bak" | sort -u > /tmp/merged_input.txt

# If -add-domain is set, add domain-suffixed versions for domainless names
if [[ $ADD_DOMAIN -eq 1 ]]; then
    log "Adding domain suffix to bare hostnames..."
    > /tmp/merged_with_domains.txt

    while read -r IP NAME; do
        echo "$IP $NAME" >> /tmp/merged_with_domains.txt

        if [[ "$NAME" != *.* ]]; then
            NEWNAME="${NAME}.${DOMAIN_SUFFIX}"
            echo "$IP $NEWNAME" >> /tmp/merged_with_domains.txt
            log "Added domain entry: $IP $NEWNAME"
        fi
    done < /tmp/merged_input.txt

    FINAL_OUTPUT="/tmp/merged_with_domains.txt"
else
    FINAL_OUTPUT="/tmp/merged_input.txt"
fi

# Apply changes
if [[ $TESTMODE -eq 1 ]]; then
    cp "$FINAL_OUTPUT" /tmp/pihole_custom_merged.test
    echo "✔️ Test mode complete. Merged output saved to: /tmp/pihole_custom_merged.test"
    echo "$CURRENT_TIMESTAMP" > "$TIMESTAMP_FILE"
else
    if cmp -s "$FINAL_OUTPUT" "$PIHOLE_CUSTOM_LIST"; then
        echo "✔️ No changes detected compared to live Pi-hole list."
    else
        BACKUP_FILE="$BACKUP_PATH/custom.list.$(date +%Y%m%d%H%M%S)"
        cp "$PIHOLE_CUSTOM_LIST" "$BACKUP_FILE"
        echo "✔️ Backup of Pi-hole list saved: $BACKUP_FILE"

        cp "$FINAL_OUTPUT" "$PIHOLE_CUSTOM_LIST"
        chown pihole:pihole "$PIHOLE_CUSTOM_LIST"
        pihole restartdns reload-lists
        echo "✔️ DHCP Reservations synced to Pi-hole successfully."
    fi
    echo "$CURRENT_TIMESTAMP" > "$TIMESTAMP_FILE"
fi

# Clean up temp files (optional, can comment if debugging)
rm -f /tmp/qnap_reservations.json /tmp/qnap_dns_entries.txt /tmp/merged_input.txt

exit 0
