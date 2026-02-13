#!/bin/bash
# DNS Diagnostic Script
# Last Updated: 01/09/2026 2:00:00 PM CDT
#
# This script performs exhaustive DNS diagnostics to determine where a DNS name is defined.
# It checks local DNS, forwarders, caches, and remote systems via SSH.
# Supports wildcard queries and provides detailed reporting.
#
# Usage: ./dns_diag.sh [-test] [-debug] <dns_name>
# Example: ./dns_diag.sh foo.divix.biz
# Example: ./dns_diag.sh "*.l1.divix.biz"

# Source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/logging.sh"

# Default flags
TEST_MODE=0
DEBUG_MODE=0
VERBOSE_MODE=0
VERBOSE_LEVEL=0
SSH_USER="divix"

# Function to display usage
usage() {
    echo "Usage: $0 [options] [dns_name]"
    echo "Options:"
    echo "  -test          Run in test mode (no remote connections)"
    echo "  -debug         Enable debug logging"
    echo "  -v|--verbose   Enable verbose output with command details"
    echo "  -vv|--verbose2 Enable extra verbose output with explanations"
    echo "  -help          Display this help message"
    echo ""
    echo "If no dns_name is provided and -v is used, shows local DNS config only."
    echo ""
    echo "Examples:"
    echo "  $0 foo.divix.biz"
    echo "  $0 \"*.l1.divix.biz\""
    echo "  $0 -debug foo.avctn.lan"
    echo "  $0 -v foo.divix.biz"
    echo "  $0 -vv foo.divix.biz"
    echo "  $0 -v  # Show local DNS config only"
}

# Function to check Pi-hole custom.list for a DNS name
check_pihole_custom_list() {
    local dns_name="$1"
    local pihole_ip="10.1.1.111"
    FOUND_TYPE=""
    
    # Check if we can reach Pi-hole server
    if ping -c 1 -W 2 "$pihole_ip" >/dev/null 2>&1; then
        log "DEBUG" "Checking Pi-hole custom.list on $pihole_ip for $dns_name..." >&2
        
        # SSH to Pi-hole server to check custom.list
        local ssh_cmd="ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o PasswordAuthentication=yes $SSH_USER@$pihole_ip"
        
# Calculate base domain locally
        local base_domain
        base_domain=$(echo "$dns_name" | sed 's/^[^\.]*\.//')
        
        # Check if Pi-hole is running and custom.list exists, and get the entry in one SSH call
        local check_result
        check_result=$($ssh_cmd "
            if systemctl is-active --quiet pihole-FTL 2>/dev/null && [[ -f /etc/pihole/custom.list ]]; then
                # Check for exact match first
                entry=\$(grep -i '^[^#]*$dns_name' /etc/pihole/custom.list 2>/dev/null | head -1)
                if [[ -n \"\$entry\" ]]; then
                    echo \"EXACT:\$entry\"
                    exit 0
                fi
                
                # Check for base domain wildcard
                if [[ '$base_domain' != '$dns_name' ]]; then
                    entry=\$(grep -i '^[^#]*$base_domain' /etc/pihole/custom.list 2>/dev/null | head -1)
                    if [[ -n \"\$entry\" ]]; then
                        echo \"WILDCARD:\$entry\"
                        exit 0
                    fi
                fi
                echo \"NOT_FOUND\"
            else
                echo \"NO_PIHOLE\"
            fi
        " 2>/dev/null)
        
        # Parse the result
        case "$check_result" in
            "NO_PIHOLE")
                log "DEBUG" "Pi-hole not accessible or custom.list not found on $pihole_ip" >&2
                ;;
            "NOT_FOUND")
                log "DEBUG" "Not found in Pi-hole custom.list" >&2
                ;;
            EXACT:*)
                local entry="${check_result#EXACT:}"
                log "DEBUG" "Found exact match in Pi-hole custom.list: $entry" >&2
                FOUND_TYPE="exact"
                return 0
                ;;
            WILDCARD:*)
                local entry="${check_result#WILDCARD:}"
                log "DEBUG" "Found base domain $(echo "$dns_name" | sed 's/^[^\.]*\.//') in Pi-hole custom.list: $entry (wildcard resolution)" >&2
                FOUND_TYPE="wildcard"
                return 0
                ;;
            *)
                log "DEBUG" "Unexpected result from Pi-hole check: $check_result" >&2
                ;;
        esac
    else
        log "DEBUG" "Cannot reach Pi-hole server at $pihole_ip" >&2
    fi
    return 1
}

# Function to get detailed local DNS information
get_local_dns_info() {
    log "DEBUG" "=== Local DNS Configuration Details ===" >&2

    # Check what DNS services are running
    log "DEBUG" "Checking active DNS services..." >&2
    local services=("systemd-resolved" "unbound" "bind9" "dnsmasq" "pihole-FTL")
    local active_services=()

    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            active_services+=("$service")
            log "DEBUG" "✓ $service is active" >&2
        else
            log "DEBUG" "✗ $service is not active" >&2
        fi
    done

    if [[ ${#active_services[@]} -eq 0 ]]; then
        log "WARN" "No local DNS services found active." >&2
        log "WARN" "DNS being handled by /etc/resolv.conf ONLY." >&2
    fi

    # Show /etc/resolv.conf
    log "DEBUG" "/etc/resolv.conf contents:" >&2
    if [[ -f /etc/resolv.conf ]]; then
        while IFS= read -r line; do
            log "DEBUG" "  $line" >&2
        done < /etc/resolv.conf
    else
        log "DEBUG" "  /etc/resolv.conf not found" >&2
    fi

    # Show systemd-resolved status if available and active
    if command -v resolvectl >/dev/null 2>&1 && systemctl is-active --quiet systemd-resolved 2>/dev/null; then
        log "DEBUG" "systemd-resolved status:" >&2
        local status_output
        status_output=$(resolvectl status 2>/dev/null | grep -v "Current Scopes: none" | grep -v "^$" | head -20)
        if [[ -n "$status_output" ]]; then
            echo "$status_output" | while IFS= read -r line; do
                log "DEBUG" "  $line" >&2
            done
        else
            log "DEBUG" "  No relevant status output available" >&2
        fi
    fi

    # Show Unbound config if running
    if systemctl is-active --quiet unbound 2>/dev/null; then
        log "DEBUG" "Unbound config (/etc/unbound/unbound.conf.d/pi-hole.conf):" >&2
        if [[ -f /etc/unbound/unbound.conf.d/pi-hole.conf ]]; then
            head -20 /etc/unbound/unbound.conf.d/pi-hole.conf | while IFS= read -r line; do
                log "DEBUG" "  $line" >&2
            done
            log "DEBUG" "  ... (truncated)" >&2
        fi
    fi

    log "DEBUG" "=== End Local DNS Configuration ===" >&2
}

# Function to check if a DNS server is authoritative for a domain
is_authoritative() {
    local domain="$1"
    local server="$2"
    
    # Extract the domain (remove subdomain)
    local base_domain
    base_domain=$(echo "$domain" | sed 's/^[^\.]*\.//')
    
    # Check if server returns SOA for the base domain
    local soa
    soa=$(dig SOA "$base_domain" "@$server" +short 2>/dev/null | head -1)
    if [[ -n "$soa" ]]; then
        echo "Authoritative for $base_domain"
        return 0
    fi
    return 1
}

# Function to check local DNS cache (if systemd-resolved)
check_local_cache() {
    local name="$1"
    local result=""

    log "INFO" "Checking local DNS cache..." >&2

    if command -v resolvectl >/dev/null 2>&1; then
        log "DEBUG" "Using resolvectl to check cache" >&2
        if [[ $TEST_MODE -eq 0 ]]; then
            if [[ $VERBOSE_MODE -eq 1 ]]; then
                log "DEBUG" "Running command: resolvectl query $name" >&2
                if [[ $VERBOSE_LEVEL -eq 2 ]]; then
                    log "DEBUG" "Reason: Checking local systemd-resolved cache first for fastest resolution" >&2
                fi
            fi
            result=$(resolvectl query "$name" 2>/dev/null | grep -v "NXDOMAIN" | head -1 || true)
        else
            log "INFO" "[TEST] Would run: resolvectl query $name" >&2
            # In test mode, simulate a found result for demonstration
            result="192.168.1.100"
        fi
    else
        log "DEBUG" "resolvectl not available, checking /etc/resolv.conf" >&2
        local nameservers
        nameservers=$(grep "^nameserver" /etc/resolv.conf | awk '{print $2}' | head -1)
        if [[ -n "$nameservers" ]]; then
            if [[ $TEST_MODE -eq 0 ]]; then
                if [[ $VERBOSE_MODE -eq 1 ]]; then
                    log "DEBUG" "Running command: dig +short $name @$nameservers" >&2
                    if [[ $VERBOSE_LEVEL -eq 2 ]]; then
                        log "DEBUG" "Reason: Fallback to direct DNS query using nameserver from /etc/resolv.conf" >&2
                    fi
                fi
                result=$(dns_lookup "$name" "$nameservers")
            else
                log "INFO" "[TEST] Would query nameserver $nameservers" >&2
                result="192.168.1.100"
            fi
        fi
    fi

    echo "$result"
}

# Function to perform DNS lookup using dig
dns_lookup() {
    local name="$1"
    local server="${2:-}"  # Optional server parameter
    
    if [[ -n "$server" ]]; then
        # Query specific server
        dig +short "$name" "@$server" 2>/dev/null | head -1
    else
        # Query default resolver
        dig +short "$name" 2>/dev/null | head -1
    fi
}

# Function to check Pi-hole DNS (common in this setup)
check_pihole() {
    local name="$1"
    local pihole_ip="10.1.1.111"  # From ADS setup script
    local result=""

    log "INFO" "Checking Pi-hole DNS at $pihole_ip..." >&2

    if [[ $TEST_MODE -eq 0 ]]; then
        if [[ $VERBOSE_MODE -eq 1 ]]; then
            log "DEBUG" "Running command: dig +short $name @$pihole_ip" >&2
            if [[ $VERBOSE_LEVEL -eq 2 ]]; then
                log "DEBUG" "Reason: Checking Pi-hole DNS server (common in this setup at $pihole_ip)" >&2
            fi
        fi
        result=$(dns_lookup "$name" "$pihole_ip")
    else
        log "INFO" "[TEST] Would query Pi-hole at $pihole_ip" >&2
        # Simulate not found in Pi-hole for test
        result=""
    fi

    echo "$result"
}

# Function to check remote DNS servers via SSH
check_remote_dns() {
    local name="$1"
    local remote_host="$2"
    local remote_ip="$3"
    local result=""

    log "INFO" "Checking remote DNS on $remote_host ($remote_ip)..." >&2

    if [[ $TEST_MODE -eq 0 ]]; then
        # Check if host is reachable
        if ping -c 1 -W 2 "$remote_ip" >/dev/null 2>&1; then
            log "DEBUG" "Host $remote_ip is reachable" >&2

            # SSH to check DNS configuration
            local ssh_cmd="ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no $SSH_USER@$remote_ip"

            # Check what DNS service is running
            local dns_service
            if [[ $VERBOSE_MODE -eq 1 ]]; then
                log "DEBUG" "Running command: ssh $SSH_USER@$remote_ip 'systemctl is-active systemd-resolved || ...'" >&2
                if [[ $VERBOSE_LEVEL -eq 2 ]]; then
                    log "DEBUG" "Reason: Determining what DNS service is running on remote host $remote_host" >&2
                fi
            fi
            dns_service=$($ssh_cmd "systemctl is-active systemd-resolved 2>/dev/null || systemctl is-active bind9 2>/dev/null || systemctl is-active unbound 2>/dev/null || echo 'unknown'" 2>/dev/null)

            log "DEBUG" "DNS service on $remote_host: $dns_service" >&2

            # Try DNS lookup on remote host
            if [[ $VERBOSE_MODE -eq 1 ]]; then
                log "DEBUG" "Running command: ssh $SSH_USER@$remote_ip 'dig +short $name'" >&2
                if [[ $VERBOSE_LEVEL -eq 2 ]]; then
                    log "DEBUG" "Reason: Testing DNS resolution directly on remote host $remote_host" >&2
                fi
            fi
            result=$($ssh_cmd "dig +short '$name' 2>/dev/null" 2>/dev/null)
        else
            log "WARN" "Host $remote_ip is not reachable" >&2
        fi
    else
        log "INFO" "[TEST] Would SSH to $remote_host ($remote_ip)" >&2
        # Simulate result for test
        result=""
    fi

    echo "$result"
}

# Function to check wildcard DNS
check_wildcard() {
    local wildcard="$1"
    local result=""

    log "INFO" "Checking wildcard DNS for $wildcard..." >&2

    # Remove the * and test a specific subdomain
    local test_name="${wildcard#*.}"
    test_name="test123.$test_name"

    log "DEBUG" "Testing with $test_name" >&2

    # Check local first
    result=$(check_local_cache "$test_name")
    if [[ -n "$result" ]]; then
        log "INFO" "Wildcard resolves locally: $test_name -> $result" >&2
        echo "$result"
        return 0
    fi

    # Check Pi-hole
    result=$(check_pihole "$test_name")
    if [[ -n "$result" ]]; then
        log "INFO" "Wildcard resolves via Pi-hole: $test_name -> $result" >&2
        echo "$result"
        return 0
    fi

    log "INFO" "Wildcard $wildcard does not resolve" >&2
    echo ""
}

# Main function
main() {
    local dns_name="$1"

    if [[ -z "$dns_name" ]]; then
        if [[ $VERBOSE_MODE -eq 1 ]]; then
            # Just show local DNS config and exit
            get_local_dns_info
            exit 0
        else
            log "ERROR" "DNS name is required (unless using -v for local config only)"
            usage
            exit 1
        fi
    fi

    log "HEAD" "=== DNS Diagnostic Report for: $dns_name ==="
    
    # Output detailed local DNS info if verbose
    if [[ $VERBOSE_MODE -eq 1 ]]; then
        get_local_dns_info
    fi
    
    log "INFO" "Starting DNS diagnostics..."

    local found_ip=""
    local found_location=""

    # Check if it's a wildcard query
    if [[ "$dns_name" == \** ]]; then
        log "INFO" "Detected wildcard query"
        found_ip=$(check_wildcard "$dns_name")
        if [[ -n "$found_ip" ]]; then
            found_location="Wildcard resolution"
        fi
    else
        # Regular DNS name lookup
        log "INFO" "Performing standard DNS lookup"

        # 1. Check local cache/systemd-resolved
        found_ip=$(check_local_cache "$dns_name")
        if [[ -n "$found_ip" ]]; then
            found_location="Local DNS cache/systemd-resolved"
            # If found locally and Pi-hole is running, check if it's in custom.list
            if systemctl is-active --quiet pihole-FTL 2>/dev/null; then
                if check_pihole_custom_list "$dns_name"; then
                    if [[ "$FOUND_TYPE" == "wildcard" ]]; then
                        found_location="Pi-hole custom.list (wildcard via base domain)"
                    else
                        found_location="Pi-hole custom.list (via local cache)"
                    fi
                else
                    # Check if primary DNS server is authoritative
                    local primary_ns
                    primary_ns=$(grep "^nameserver" /etc/resolv.conf | awk '{print $2}' | head -1)
                    if [[ -n "$primary_ns" ]] && is_authoritative "$dns_name" "$primary_ns" >/dev/null; then
                        found_location="Authoritative DNS server ($primary_ns)"
                    else
                        found_location="Upstream DNS (via local resolver)"
                    fi
                fi
            fi
        fi

        # 2. If not found locally, check Pi-hole
        if [[ -z "$found_ip" ]]; then
            found_ip=$(check_pihole "$dns_name")
            if [[ -n "$found_ip" ]]; then
                found_location="Pi-hole DNS server"
                # Check if it's in custom.list
                log "DEBUG" "Checking if DNS name is configured in Pi-hole custom.list..." >&2
                if check_pihole_custom_list "$dns_name"; then
                    if [[ "$FOUND_TYPE" == "wildcard" ]]; then
                        found_location="Pi-hole custom.list (wildcard)"
                    else
                        found_location="Pi-hole custom.list"
                    fi
                else
                    # Check if Pi-hole is authoritative for this domain
                    log "DEBUG" "Checking if Pi-hole is authoritative for this domain..." >&2
                    if is_authoritative "$dns_name" "10.1.1.111" >/dev/null; then
                        found_location="Pi-hole (authoritative)"
                    else
                        found_location="Upstream DNS via Pi-hole"
                    fi
                fi
            fi
        fi

        # 3. Check common remote systems (from divtools setup)
        if [[ -z "$found_ip" ]]; then
            # Check OPNsense (common gateway)
            found_ip=$(check_remote_dns "$dns_name" "opnsense" "10.1.1.1")
            if [[ -n "$found_ip" ]]; then
                found_location="OPNsense gateway"
            fi
        fi

        # 4. Check QNAP systems
        if [[ -z "$found_ip" ]]; then
            found_ip=$(check_remote_dns "$dns_name" "qnap" "10.1.1.10")  # Example IP
            if [[ -n "$found_ip" ]]; then
                found_location="QNAP NAS"
            fi
        fi

        # 5. Try public DNS as last resort
        if [[ -z "$found_ip" ]]; then
            log "INFO" "Checking public DNS (8.8.8.8)..."
            found_ip=$(dns_lookup "$dns_name" "8.8.8.8")
            if [[ -n "$found_ip" ]]; then
                found_location="Public DNS (external)"
            fi
        fi
    fi

    # Generate final report
    log "HEAD" "=== Final Report ==="
    if [[ -n "$found_ip" ]]; then
        log "INFO" "✅ DNS name '$dns_name' found!"
        log "INFO" "📍 Location: $found_location"
        log "INFO" "🌐 IP Address: $found_ip"
    else
        log "WARN" "❌ DNS name '$dns_name' not found anywhere"
        log "INFO" "This could mean:"
        log "INFO" "  - The name is not configured"
        log "INFO" "  - Network connectivity issues"
        log "INFO" "  - DNS server configuration problems"
    fi

    log "INFO" "DNS diagnostics complete"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -test|--test)
            TEST_MODE=1
            log "INFO" "Running in TEST mode - no actual connections will be made"
            shift
            ;;
        -debug|--debug)
            DEBUG_MODE=1
            log "DEBUG" "Debug mode enabled"
            shift
            ;;
        -v|--verbose)
            VERBOSE_MODE=1
            VERBOSE_LEVEL=1
            DEBUG_MODE=1  # Enable debug logging for verbose output
            log "INFO" "Verbose mode enabled"
            shift
            ;;
        -vv|--verbose2)
            VERBOSE_MODE=1
            VERBOSE_LEVEL=2
            DEBUG_MODE=1
            log "INFO" "Extra verbose mode enabled"
            shift
            ;;
        -help|--help)
            usage
            exit 0
            ;;
        -*)
            log "ERROR" "Unknown option: $1"
            usage
            exit 1
            ;;
        *)
            DNS_NAME="$1"
            shift
            ;;
    esac
done

# Run main function
main "$DNS_NAME"
