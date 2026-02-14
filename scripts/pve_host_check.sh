#!/bin/bash

# proxmox_host_check.sh
# Collects concise Proxmox host hardware and config info: IOMMU status, GPUs, CPU, memory, storage.
# Last Updated: 10/18/2025 2:30:00 PM CDT

# Logging function with color-coded output
log() {
    local level="$1"
    local message="$2"
    local color

    case "$level" in
        DEBUG) color="\e[37m" ;; # White
        INFO)  color="\e[36m" ;; # Cyan
        WARN)  color="\e[33m" ;; # Yellow
        ERROR) color="\e[31m" ;; # Red
        *)     color="\e[37m" ;; # Default to white
    esac

    echo -e "${color}[${level}] ${message}\e[m"
    if [ "$DEBUG_MODE" -eq 1 ]; then
        echo -e "\e[37m[DEBUG] ${level}: ${message}\e[m"
    fi
} # log

# Parse command-line flags
parse_flags() {
    TEST_MODE=0
    DEBUG_MODE=0
    while [[ $# -gt 0 ]]; do
        case $1 in
            -test)
                TEST_MODE=1
                shift
                ;;
            -debug)
                DEBUG_MODE=1
                shift
                ;;
            *)
                log "ERROR" "Unknown option: $1"
                exit 1
                ;;
        esac
    done
} # parse_flags

# Check IOMMU status
get_iommu_status() {
    log "INFO" "=== IOMMU Status ==="
    local iommu_enabled=0
    local iommu_type=""

    # Check for IOMMU groups directory (most reliable indicator)
    if [ -d "/sys/kernel/iommu_groups" ] && [ "$(ls -A /sys/kernel/iommu_groups 2>/dev/null | wc -l)" -gt 0 ]; then
        iommu_enabled=1
        log "INFO" "IOMMU: Enabled (IOMMU groups detected)"
    else
        log "WARN" "IOMMU: Disabled (No IOMMU groups found)"
    fi

    # Check kernel cmdline as secondary (for completeness)
    if grep -qE "(intel_iommu=on|amd_iommu=on)" /proc/cmdline; then
        local cmdline_type=$(grep -oE "(intel|amd)_iommu=on" /proc/cmdline)
        if [ -z "$iommu_type" ]; then
            iommu_type="$cmdline_type"
        fi
    fi

    # Check dmesg for IOMMU initialization (Intel DMAR or AMD-Vi)
    if [ "$iommu_enabled" -eq 1 ]; then
        if dmesg | grep -q "DMAR: Intel(R) Virtualization Technology for Directed I/O"; then
            iommu_type="Intel (DMAR)"
        elif dmesg | grep -q "AMD-Vi:"; then
            iommu_type="AMD (AMD-Vi)"
        fi
        if [ -n "$iommu_type" ]; then
            log "INFO" "IOMMU Type: $iommu_type"
        fi
    fi

    if [ "$DEBUG_MODE" -eq 1 ]; then
        log "DEBUG" "IOMMU kernel cmdline: $(cat /proc/cmdline)"
        log "DEBUG" "IOMMU groups dir: $(ls -la /sys/kernel/iommu_groups/ 2>/dev/null || echo 'Not found')"
        log "DEBUG" "Relevant dmesg lines: $(dmesg | grep -E 'DMAR|IOMMU|AMD-Vi' | head -5)"
    fi
} # get_iommu_status

# List available GPUs
get_gpus() {
    log "INFO" "=== GPUs Available ==="
    if command -v lspci >/dev/null 2>&1; then
        local gpus=$(lspci | grep -iE "vga|3d|display")
        if [ -n "$gpus" ]; then
            echo "$gpus"
        else
            log "INFO" "No GPUs detected via lspci"
        fi
    fi
    if command -v nvidia-smi >/dev/null 2>&1; then
        log "INFO" "NVIDIA GPUs:"
        nvidia-smi --query-gpu=name --format=csv,noheader,nounits
    fi
    if [ "$DEBUG_MODE" -eq 1 ]; then
        log "DEBUG" "Full lspci VGA output: $(lspci | grep -i vga 2>/dev/null || echo 'None')"
    fi
} # get_gpus

# CPU info
get_cpu_info() {
    log "INFO" "=== CPU Info ==="
    if command -v lscpu >/dev/null 2>&1; then
        lscpu | grep -E "Model name|CPU\(s\)|Socket|Core|Thread"
    else
        log "WARN" "lscpu not available; using /proc/cpuinfo summary"
        grep -E "model name|cpu cores|siblings" /proc/cpuinfo | head -4
    fi
    if [ "$DEBUG_MODE" -eq 1 ]; then
        log "DEBUG" "Full CPU model: $(grep 'model name' /proc/cpuinfo | head -1)"
    fi
} # get_cpu_info

# Memory info
get_memory_info() {
    log "INFO" "=== Memory Info ==="
    if command -v free >/dev/null 2>&1; then
        free -h | grep -E "Mem|Swap"
    else
        log "WARN" "free not available; using /proc/meminfo summary"
        awk '/MemTotal/ {print "Total: " $2 " kB"} /MemAvailable/ {print "Available: " $2 " kB"}' /proc/meminfo
    fi
    if [ "$DEBUG_MODE" -eq 1 ]; then
        log "DEBUG" "Total memory: $(awk '/MemTotal/ {print $2}' /proc/meminfo) kB"
    fi
} # get_memory_info

# HD Storage info
get_storage_info() {
    log "INFO" "=== HD Storage ==="
    if command -v lsblk >/dev/null 2>&1; then
        lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE | grep -v loop
    elif command -v pvesm >/dev/null 2>&1; then
        log "INFO" "Proxmox storage summary:"
        pvesm status --content none
    else
        log "WARN" "lsblk/pvesm not available; using df summary"
        df -h | grep -v tmpfs
    fi
    if [ "$DEBUG_MODE" -eq 1 ]; then
        log "DEBUG" "Full lsblk output: $(lsblk 2>/dev/null || echo 'None')"
    fi
} # get_storage_info

# Main execution
main() {
    parse_flags "$@"
    if [ "$TEST_MODE" -eq 1 ]; then
        log "INFO" "TEST MODE: No actions performed; would collect host info"
        return 0
    fi
    get_iommu_status
    get_gpus
    get_cpu_info
    get_memory_info
    get_storage_info
    log "INFO" "Proxmox host check complete."
} # main

# Run main if script is executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi