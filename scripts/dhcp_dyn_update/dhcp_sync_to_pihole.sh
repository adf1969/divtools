#!/bin/bash

# SETTINGS
DATA_PATH="/opt/divtools/scripts/dhcp_dyn_update/data"
RESERVATIONS_FILE="${DATA_PATH}/qnap_nm_dhcpd.conf"
LEASES_FILE="${DATA_PATH}/qnap_eth0_leases.txt"
OPNSENSE_STATICMAP_FILE="${DATA_PATH}/opnsense_staticmap.txt"
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
REPLACE=0
NOQNAP=0
NOOPN=0

# USAGE FUNCTION
usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -debug         Enable debug logging"
    echo "  -test          Run in test mode (no live changes to Pi-hole)"
    echo "  -add-domain    Add domain suffix to entries without a domain"
    echo "  -domain <sfx>  Override default domain suffix"
    echo "  -force         Force processing regardless of timestamps"
    echo "  -backup        Only perform a backup of Pi-hole custom.list"
    echo "  -replace       Replace existing entries if hostname conflicts"
    echo "  -noqnap        Skip processing QNAP DHCP files"
    echo "  -noopn         Skip processing OPNsense static map file"
    echo "  -help          Display this help message"
    echo
    echo "Summary of expected input files and sources:"
    echo "  - QNAP Systems:" 
    echo "      * qnap_nm_dhcpd.conf   (reserved IP mappings)"
    echo "      * qnap_eth0_leases.txt (current DHCP leases)"
    echo "    These files are created by qnap_upd_dhcp_data.sh, which copies the DHCP reservation and "
    echo "      lease files from /etc/config/ on the QNAP into the data directory if changes are detected, "
    echo "      based on SHA256 hashes."
    echo "  - OPNsense Systems:"
    echo "      * opnsense_staticmap.txt (static DHCP mappings)"
    echo "    This file is created by opnsense_upd_dhcp_data.sh, which extracts the staticmap entries "
    echo "      from /conf/config.xml using xmllint, and copies sanitized IP-hostname pairs into the data "
    echo "      directory if changes are detected."
    echo
    echo "This script merges these sources into Pi-hole's /etc/pihole/custom.list file."
    echo "If conflicts occur, newer entries overwrite older ones (OPNsense preferred)."
}

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
        -replace)
            REPLACE=1
            shift
            ;;
        -noqnap)
            NOQNAP=1
            shift
            ;;
        -noopn)
            NOOPN=1
            shift
            ;;
        -help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

log "Starting DHCP sync script. TESTMODE=$TESTMODE, DEBUG=$DEBUG, ADD_DOMAIN=$ADD_DOMAIN, FORCE=$FORCE, BACKUP_ONLY=$BACKUP_ONLY, REPLACE=$REPLACE, NOQNAP=$NOQNAP, NOOPN=$NOOPN, DOMAIN_SUFFIX=$DOMAIN_SUFFIX"

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

# Check for missing files
MISSING=0
if [[ "$NOQNAP" -eq 0 ]]; then
    for f in "$RESERVATIONS_FILE" "$LEASES_FILE"; do
        if [[ ! -f "$f" ]]; then
            echo "⚠️ Warning: Missing QNAP file: $f"
            MISSING=1
        fi
    done
fi
if [[ "$NOOPN" -eq 0 ]]; then
    if [[ ! -f "$OPNSENSE_STATICMAP_FILE" ]]; then
        echo "⚠️ Warning: Missing OPNsense static map file: $OPNSENSE_STATICMAP_FILE"
        MISSING=1
    fi
fi

if [[ "$MISSING" -eq 1 && "$NOQNAP" -eq 0 && "$NOOPN" -eq 0 ]]; then
    echo "❌ Critical files missing and not skipped. Exiting."
    exit 1
fi

# Check if processing is necessary based on timestamps
TIMESTAMP_FILES=()
[[ "$NOQNAP" -eq 0 && -f "$RESERVATIONS_FILE" ]] && TIMESTAMP_FILES+=("$RESERVATIONS_FILE")
[[ "$NOQNAP" -eq 0 && -f "$LEASES_FILE" ]] && TIMESTAMP_FILES+=("$LEASES_FILE")
[[ "$NOOPN" -eq 0 && -f "$OPNSENSE_STATICMAP_FILE" ]] && TIMESTAMP_FILES+=("$OPNSENSE_STATICMAP_FILE")

CURRENT_TIMESTAMP=$(find "${TIMESTAMP_FILES[@]}" -printf "%T@\n" | sort -n | tail -1)
LAST_TIMESTAMP=0
if [[ -f "$TIMESTAMP_FILE" ]]; then
    LAST_TIMESTAMP=$(cat "$TIMESTAMP_FILE")
fi

if [[ "$FORCE" -eq 0 && "${CURRENT_TIMESTAMP%%.*}" -le "$LAST_TIMESTAMP" ]]; then
    echo "✔️ No changes detected based on timestamps. Exiting after backup cleanup."
    exit 0
fi

# Parse entries
> /tmp/all_entries.txt

if [[ "$NOQNAP" -eq 0 ]]; then
    if [[ -f "$RESERVATIONS_FILE" ]]; then
        TMP_QNAP_OUTPUT="/tmp/qnap_dns_entries.txt"
        log "Parsing QNAP reservations into $TMP_QNAP_OUTPUT..."
        > "$TMP_QNAP_OUTPUT"
        grep 'reserved_ip =' "$RESERVATIONS_FILE" | sed -e 's/^.*reserved_ip = //' > /tmp/qnap_reservations.json
        jq -r '.[] | "\(.IP_address) \(.Device_name).'"${DOMAIN_SUFFIX}"'"' /tmp/qnap_reservations.json >> /tmp/all_entries.txt
    fi
    if [[ -f "$LEASES_FILE" ]]; then
        TMP_LEASES_OUTPUT="/tmp/qnap_leases_entries.txt"
        log "Parsing QNAP leases into $TMP_LEASES_OUTPUT..."
        > "$TMP_LEASES_OUTPUT"
        awk '/lease /{IP=$2} /client-hostname/{gsub("\"", "", $2); gsub(";", "", $2); printf("%s %s.%s\n", IP, $2, "'${DOMAIN_SUFFIX}'")}' "$LEASES_FILE" >> /tmp/all_entries.txt
    fi
fi

if [[ "$NOOPN" -eq 0 ]]; then
    if [[ -f "$OPNSENSE_STATICMAP_FILE" ]]; then
        TMP_OPNSENSE_OUTPUT="/tmp/opnsense_entries.txt"
        log "Parsing OPNsense static maps into $TMP_OPNSENSE_OUTPUT..."
        > "$TMP_OPNSENSE_OUTPUT"
        awk '{ printf("%s %s.%s\n", $1, $2, "'${DOMAIN_SUFFIX}'") }' "$OPNSENSE_STATICMAP_FILE" >> /tmp/all_entries.txt
    fi
fi

# If replace is set, only keep the latest entry for each hostname
if [[ "$REPLACE" -eq 1 ]]; then
    log "Deduplicating by hostname (replace mode)..."
    tac /tmp/all_entries.txt | awk '!a[$2]++' | tac > /tmp/all_entries_deduped.txt
else
    sort -u /tmp/all_entries.txt > /tmp/all_entries_deduped.txt
fi

FINAL_OUTPUT="/tmp/all_entries_deduped.txt"

# Apply changes
if [[ "$TESTMODE" -eq 1 ]]; then
    cp "$FINAL_OUTPUT" /tmp/pihole_custom_merged.test
    echo "✔️ Test mode complete. Merged output saved to: /tmp/pihole_custom_merged.test"
    echo "${CURRENT_TIMESTAMP%%.*}" > "$TIMESTAMP_FILE"
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
        echo "✔️ DHCP + Static Maps synced to Pi-hole successfully."
    fi
    echo "${CURRENT_TIMESTAMP%%.*}" > "$TIMESTAMP_FILE"
fi

# Clean up
rm -f /tmp/qnap_reservations.json /tmp/qnap_dns_entries.txt /tmp/qnap_leases_entries.txt /tmp/opnsense_entries.txt /tmp/all_entries.txt /tmp/all_entries_deduped.txt

exit 0
