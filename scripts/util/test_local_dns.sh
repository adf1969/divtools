#!/bin/bash

# test_local_dns.sh - Diagnose DNS for a specific host
# Usage: ./test_local_dns.sh <host>
# Outputs to stdout; redirect to file for logging.

if [ $# -ne 1 ]; then
    echo "Usage: $0 <host>"
    exit 1
fi

HOST="$1"
LOG_FILE="${HOME}/dns_test_$(date +%Y%m%d_%H%M%S).log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Function to log with timestamp
log() {
    echo "[$TIMESTAMP] $*" | tee -a "$LOG_FILE"
}

log "=== DNS Test for Host: $HOST ==="
log "System: $(hostname) ($(uname -a))"

# Step 1: Basic ping test
log "\n--- Step 1: Ping Test ---"
if ping -c 3 -W 5 "$HOST" &> /dev/null; then
    log "SUCCESS: Ping to $HOST succeeded (DNS resolved)."
    log "No further diagnosis needed."
    exit 0
else
    log "FAIL: Ping to $HOST failed (Temporary failure in name resolution)."
fi

# Step 2: Check DNS Config
log "\n--- Step 2: DNS Configuration ---"
log "Contents of /etc/resolv.conf:"
cat /etc/resolv.conf | sed 's/^/  /' 2>/dev/null || log "  Error reading /etc/resolv.conf"
log "\nresolvectl status (summary):"
resolvectl status 2>/dev/null | head -20 | sed 's/^/  /' || log "  Error: resolvectl not available (systemd-resolved?)"

# Step 3: Resolution Tests
log "\n--- Step 3: Resolution Attempts ---"
log "dig $HOST @127.0.0.53 (local stub resolver):"
dig +short +time=5 "$HOST" @127.0.0.53 2>&1 | sed 's/^/  /' || log "  dig failed or timed out."

log "\nnslookup $HOST (system default):"
nslookup "$HOST" 2>&1 | sed 's/^/  /' || log "  nslookup failed (install dnsutils?)."

# Assume common OPNsense LAN IP; adjust if needed
#OPNSENSE_DNS="10.1.1.1"  # Replace with your OPNsense LAN IP
#log "\ndig $HOST @$OPNSENSE_DNS (direct to OPNsense DNS):"
#dig +short +time=5 "$HOST" @"$OPNSENSE_DNS" 2>&1 | sed 's/^/  /' || log "  Direct dig to OPNsense failed."

# Step 4: Suggestions
log "\n--- Step 4: Diagnosis & Suggestions ---"
if grep -q "search \." /etc/resolv.conf 2>/dev/null; then
    log "  ISSUE: Empty search domain (search .). Try pinging $HOST.avctn.lan (or your domain)."
    log "  FIX: Add domain to /etc/systemd/resolved.conf (Domains=avctn.lan) and restart systemd-resolved."
fi

log "  ISSUE: Possible upstream DNS missing. Check 'resolvectl status' for servers."
log "  FIX: Ensure DHCP from OPNsense provides DNS/domain. Run: sudo systemctl restart systemd-resolved"

log "  Next: Share this output ($LOG_FILE) for review. Test full domain: ping $HOST.avctn.lan"

log "\n=== End Test ==="
log "Log saved to: $LOG_FILE"