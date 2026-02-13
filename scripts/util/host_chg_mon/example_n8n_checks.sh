#!/bin/bash
#
# example_n8n_checks.sh - Example SSH commands for n8n to monitor host changes
#
# These are example commands that can be used in n8n SSH nodes to check for
# various types of changes on a host. Copy and adapt as needed for your n8n workflows.
#

# ==============================================================================
# SETUP & STATUS CHECKS
# ==============================================================================

# Check if monitoring is configured
check_monitoring_configured() {
    if [[ -f /var/log/divtools/monitor/monitoring_manifest.json ]]; then
        echo "✓ Monitoring configured"
        cat /var/log/divtools/monitor/monitoring_manifest.json
        return 0
    else
        echo "✗ Monitoring not configured. Run: sudo /home/divix/divtools/scripts/util/host_change_log.sh setup"
        return 1
    fi
}

# Get monitoring status
get_status() {
    /home/divix/divtools/scripts/util/host_change_log.sh status
}

# ==============================================================================
# BASH HISTORY MONITORING
# ==============================================================================

# Get recent root commands (last 50)
get_root_history() {
    if [[ -f /var/log/divtools/monitor/history/root.bash_history.latest ]]; then
        echo "=== Recent Root Commands ==="
        tail -50 /var/log/divtools/monitor/history/root.bash_history.latest
    else
        echo "No root history found"
    fi
}

# Get recent divix commands (last 50)
get_divix_history() {
    if [[ -f /var/log/divtools/monitor/history/divix.bash_history.latest ]]; then
        echo "=== Recent Divix Commands ==="
        tail -50 /var/log/divtools/monitor/history/divix.bash_history.latest
    else
        echo "No divix history found"
    fi
}

# Get commands from specific date (yesterday)
get_history_by_date() {
    local target_date="${1:-$(date -d 'yesterday' +%Y-%m-%d)}"
    echo "=== Commands from ${target_date} ==="
    
    for histfile in /var/log/divtools/monitor/history/*.latest; do
        if [[ -f "$histfile" ]]; then
            local user=$(basename "$histfile" .bash_history.latest)
            echo "--- User: $user ---"
            grep "^${target_date}" "$histfile" || echo "  No commands found"
        fi
    done
}

# Get suspicious commands (common dangerous patterns)
check_suspicious_commands() {
    echo "=== Checking for Suspicious Commands ==="
    
    local patterns=(
        "rm -rf"
        "chmod 777"
        "curl.*|.*sh"
        "wget.*|.*sh"
        "nc -l"
        "ncat -l"
        "/dev/tcp"
        "base64.*decode"
        "eval"
        "mkfifo"
    )
    
    for pattern in "${patterns[@]}"; do
        echo "Checking pattern: $pattern"
        grep -h -E "$pattern" /var/log/divtools/monitor/history/*.latest 2>/dev/null | tail -5
    done
}

# ==============================================================================
# APT PACKAGE MONITORING
# ==============================================================================

# Get recent package operations
get_recent_apt_activity() {
    echo "=== Recent APT Activity ==="
    grep "^Start-Date:" /var/log/apt/history.log 2>/dev/null | tail -20
}

# Get packages installed in last N days
get_packages_installed() {
    local days="${1:-7}"
    local cutoff_date=$(date -d "${days} days ago" +%Y-%m-%d)
    
    echo "=== Packages Installed Since ${cutoff_date} ==="
    awk -v date="$cutoff_date" '
        /^Start-Date:/ {
            if ($0 > date) {
                print_block=1
            } else {
                print_block=0
            }
        }
        print_block {print}
        /^End-Date:/ {print_block=0; print "---"}
    ' /var/log/apt/history.log 2>/dev/null
}

# Get list of manually installed packages (useful for drift detection)
get_manually_installed_packages() {
    echo "=== Manually Installed Packages ==="
    comm -23 \
        <(apt-mark showmanual | sort) \
        <(gzip -dc /var/log/installer/initial-status.gz 2>/dev/null | \
          sed -n 's/^Package: //p' | sort) 2>/dev/null
}

# Check for pending updates
check_pending_updates() {
    echo "=== Pending Updates ==="
    apt list --upgradable 2>/dev/null | grep -v "^Listing"
}

# ==============================================================================
# DOCKER CONFIG MONITORING
# ==============================================================================

# Check docker-compose file integrity
check_docker_configs() {
    echo "=== Docker Configuration Integrity Check ==="
    
    if [[ -f /var/log/divtools/monitor/checksums/docker_configs.sha256 ]]; then
        cd /home/divix/divtools 2>/dev/null || return 1
        
        if sha256sum -c /var/log/divtools/monitor/checksums/docker_configs.sha256 2>&1 | grep -v "OK$"; then
            echo "⚠ Some docker config files have changed!"
            return 1
        else
            echo "✓ All docker configs match checksums"
            return 0
        fi
    else
        echo "✗ Docker checksum file not found"
        return 1
    fi
}

# List changed docker files
list_changed_docker_files() {
    echo "=== Changed Docker Files ==="
    
    cd /home/divix/divtools 2>/dev/null || return 1
    
    # If in git repo, show git status
    if [[ -d .git ]]; then
        git status --short docker/
    fi
    
    # Check against checksums
    if [[ -f /var/log/divtools/monitor/checksums/docker_configs.sha256 ]]; then
        sha256sum -c /var/log/divtools/monitor/checksums/docker_configs.sha256 2>&1 | \
            grep -v "OK$" | \
            awk '{print $1}'
    fi
}

# Get running containers
get_running_containers() {
    echo "=== Running Docker Containers ==="
    if command -v docker &>/dev/null; then
        docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
    else
        echo "Docker not installed"
    fi
}

# Get recent docker events
get_docker_events() {
    echo "=== Docker Events (Last 24 Hours) ==="
    if command -v docker &>/dev/null; then
        docker events --since 24h --until 1s 2>/dev/null | tail -50
    else
        echo "Docker not available"
    fi
}

# ==============================================================================
# SYSTEM LOG MONITORING
# ==============================================================================

# Get critical system errors
get_critical_errors() {
    echo "=== Critical System Errors (Last 24 Hours) ==="
    journalctl --since "24 hours ago" --priority=err --no-pager 2>/dev/null | tail -50
}

# Check authentication failures
check_auth_failures() {
    echo "=== Failed Authentication Attempts ==="
    grep "Failed password" /var/log/auth.log 2>/dev/null | tail -20
}

# Check sudo usage
check_sudo_usage() {
    echo "=== Recent Sudo Usage ==="
    grep "sudo:" /var/log/auth.log 2>/dev/null | tail -30
}

# Check for service failures
check_service_failures() {
    echo "=== Failed Services (Last 24 Hours) ==="
    systemctl --failed
    echo ""
    journalctl --since "24 hours ago" -u "*.service" --no-pager 2>/dev/null | \
        grep -i "failed\|error" | tail -20
}

# Check disk space
check_disk_space() {
    echo "=== Disk Space Usage ==="
    df -h | awk '$5+0 > 80 {print "⚠ " $0; next} {print $0}'
}

# Check memory usage
check_memory_usage() {
    echo "=== Memory Usage ==="
    free -h
}

# ==============================================================================
# SECURITY CHECKS
# ==============================================================================

# Check for new users
check_new_users() {
    echo "=== User Accounts ==="
    awk -F: '$3 >= 1000 {print $1 " (UID: " $3 ")"}' /etc/passwd
}

# Check SSH configuration changes
check_ssh_config_changes() {
    echo "=== SSH Configuration ==="
    stat -c "%y %n" /etc/ssh/sshd_config /etc/ssh/ssh_config 2>/dev/null
    
    echo ""
    echo "Listening on:"
    ss -tlnp | grep ":22"
}

# Check for suspicious cron jobs
check_cron_jobs() {
    echo "=== Cron Jobs ==="
    
    # Root crontab
    echo "--- Root Crontab ---"
    crontab -l 2>/dev/null || echo "No root crontab"
    
    # System cron
    echo ""
    echo "--- System Cron Directories ---"
    ls -la /etc/cron.* 2>/dev/null | grep -v "^total"
}

# Check open ports
check_open_ports() {
    echo "=== Open Network Ports ==="
    ss -tlnp | grep LISTEN
}

# ==============================================================================
# COMPREHENSIVE CHECK (Run All)
# ==============================================================================

run_all_checks() {
    echo "========================================================================"
    echo "HOST CHANGE MONITORING REPORT"
    echo "Host: $(hostname)"
    echo "Date: $(date)"
    echo "========================================================================"
    echo ""
    
    get_status
    echo ""
    
    get_recent_apt_activity
    echo ""
    
    check_docker_configs
    echo ""
    
    get_root_history
    echo ""
    
    check_suspicious_commands
    echo ""
    
    get_critical_errors
    echo ""
    
    check_auth_failures
    echo ""
    
    check_disk_space
    echo ""
    
    check_service_failures
    echo ""
    
    echo "========================================================================"
    echo "END OF REPORT"
    echo "========================================================================"
}

# ==============================================================================
# N8N-FRIENDLY JSON OUTPUT
# ==============================================================================

# Generate JSON report for n8n AI processing
generate_json_report() {
    cat <<EOF
{
  "hostname": "$(hostname)",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "checks": {
    "apt_activity": $(get_recent_apt_activity | tail -5 | jq -R . | jq -s .),
    "docker_integrity": $(check_docker_configs 2>&1 | jq -R . | jq -s .),
    "root_history": $(get_root_history | tail -20 | jq -R . | jq -s .),
    "critical_errors": $(get_critical_errors | tail -10 | jq -R . | jq -s .),
    "auth_failures": $(check_auth_failures | tail -10 | jq -R . | jq -s .),
    "disk_space": $(df -h | jq -R . | jq -s .),
    "failed_services": $(systemctl --failed --no-pager | jq -R . | jq -s .)
  }
}
EOF
}

# ==============================================================================
# USAGE
# ==============================================================================

show_usage() {
    cat <<EOF
Usage: $0 <command>

Available commands:
  all                    - Run all checks
  json                   - Generate JSON report for n8n
  
  History Checks:
    root-history         - Recent root commands
    divix-history        - Recent divix commands
    history-date [DATE]  - Commands from specific date
    suspicious           - Check for suspicious commands
  
  APT Checks:
    apt-recent           - Recent APT activity
    apt-installed [DAYS] - Packages installed in last N days
    apt-manual           - Manually installed packages
    apt-updates          - Pending updates
  
  Docker Checks:
    docker-check         - Verify docker config integrity
    docker-changed       - List changed docker files
    docker-containers    - Running containers
    docker-events        - Recent docker events
  
  System Checks:
    errors               - Critical system errors
    auth-failures        - Authentication failures
    sudo-usage           - Recent sudo usage
    services             - Failed services
    disk                 - Disk space usage
    memory               - Memory usage
  
  Security Checks:
    users                - User accounts
    ssh-config           - SSH configuration
    cron                 - Cron jobs
    ports                - Open network ports

Examples:
  $0 all
  $0 root-history
  $0 apt-installed 7
  $0 json | jq .
EOF
}

# Main command handler
main() {
    case "${1:-all}" in
        # Setup
        status) get_status ;;
        
        # History
        root-history) get_root_history ;;
        divix-history) get_divix_history ;;
        history-date) get_history_by_date "$2" ;;
        suspicious) check_suspicious_commands ;;
        
        # APT
        apt-recent) get_recent_apt_activity ;;
        apt-installed) get_packages_installed "$2" ;;
        apt-manual) get_manually_installed_packages ;;
        apt-updates) check_pending_updates ;;
        
        # Docker
        docker-check) check_docker_configs ;;
        docker-changed) list_changed_docker_files ;;
        docker-containers) get_running_containers ;;
        docker-events) get_docker_events ;;
        
        # System
        errors) get_critical_errors ;;
        auth-failures) check_auth_failures ;;
        sudo-usage) check_sudo_usage ;;
        services) check_service_failures ;;
        disk) check_disk_space ;;
        memory) check_memory_usage ;;
        
        # Security
        users) check_new_users ;;
        ssh-config) check_ssh_config_changes ;;
        cron) check_cron_jobs ;;
        ports) check_open_ports ;;
        
        # Reports
        all) run_all_checks ;;
        json) generate_json_report ;;
        
        # Help
        help|--help|-h) show_usage ;;
        
        *)
            echo "Unknown command: $1"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
