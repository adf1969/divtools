#!/bin/bash
# Comprehensive resource check script for Frigate VM and container
# Last Updated: 11/5/2025 12:30:00 AM CDT

# Source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../util/logging.sh" 2>/dev/null || {
    log() { echo "[$1] $2"; }
}

# Default flags
DEBUG_MODE=0
WATCH_MODE=0
DURATION=60

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -debug|--debug)
            DEBUG_MODE=1
            log "DEBUG" "Debug mode enabled"
            shift
            ;;
        -watch|--watch)
            WATCH_MODE=1
            shift
            ;;
        -duration|--duration)
            DURATION="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [-debug] [-watch] [-duration SECONDS]"
            echo "  -debug: Enable debug output"
            echo "  -watch: Continuous monitoring mode"
            echo "  -duration: How long to monitor in watch mode (default: 60 seconds)"
            exit 0
            ;;
        *)
            log "ERROR" "Unknown option: $1"
            exit 1
            ;;
    esac
done

log "INFO" "=== Frigate Resource Check Script ==="
log "INFO" "Date: $(date)"
echo ""

# Function to check VM resources
check_vm_resources() {
    log "INFO" "=== VM Resources ==="
    
    # CPU Info
    log "INFO" "CPU Information:"
    local cpu_count=$(nproc)
    local cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
    log "INFO:!ts" "  CPU Cores: $cpu_count"
    log "INFO:!ts" "  CPU Model: $cpu_model"
    
    # Load Average
    local load=$(uptime | awk -F'load average:' '{print $2}')
    log "INFO:!ts" "  Load Average:$load"
    
    # CPU Usage
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')
    log "INFO:!ts" "  Current CPU Usage: $cpu_usage"
    echo ""
    
    # Memory Info
    log "INFO" "Memory Information:"
    free -h | grep -E "^Mem:|^Swap:" | while read line; do
        log "INFO:!ts" "  $line"
    done
    
    local mem_percent=$(free | grep Mem | awk '{printf("%.1f%%", $3/$2 * 100.0)}')
    log "INFO:!ts" "  Memory Usage: $mem_percent"
    echo ""
    
    # Disk Info
    log "INFO" "Disk Usage:"
    df -h / | tail -1 | awk '{printf "  Root: %s / %s (%s used)\n", $3, $2, $5}'
    echo ""
}

# Function to check Docker container resources
check_container_resources() {
    log "INFO" "=== Frigate Container Resources ==="
    
    # Check if Frigate is running
    if ! docker ps --filter name=frigate --format '{{.Names}}' | grep -q frigate; then
        log "ERROR" "Frigate container is not running!"
        return 1
    fi
    
    # Container status
    local status=$(docker ps --filter name=frigate --format '{{.Status}}')
    log "INFO:!ts" "  Status: $status"
    
    # Get container stats
    docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}' $(docker ps --filter name=frigate -q)
    echo ""
    
    # Check container resource limits
    log "INFO" "Container Resource Limits:"
    local mem_limit=$(docker inspect frigate --format '{{.HostConfig.Memory}}')
    local cpu_limit=$(docker inspect frigate --format '{{.HostConfig.NanoCpus}}')
    
    if [ "$mem_limit" = "0" ]; then
        log "WARN" "  Memory Limit: UNLIMITED (using host memory)"
    else
        local mem_limit_gb=$(echo "scale=2; $mem_limit/1024/1024/1024" | bc)
        log "INFO:!ts" "  Memory Limit: ${mem_limit_gb}GB"
    fi
    
    if [ "$cpu_limit" = "0" ]; then
        log "WARN" "  CPU Limit: UNLIMITED (using all host CPUs)"
    else
        local cpu_cores=$(echo "scale=2; $cpu_limit/1000000000" | bc)
        log "INFO:!ts" "  CPU Limit: ${cpu_cores} cores"
    fi
    echo ""
}

# Function to check GPU resources (if applicable)
check_gpu_resources() {
    if command -v nvidia-smi &> /dev/null; then
        log "INFO" "=== NVIDIA GPU Resources ==="
        nvidia-smi --query-gpu=gpu_name,memory.total,memory.used,memory.free,utilization.gpu --format=csv,noheader | \
        while IFS=, read name total used free util; do
            log "INFO:!ts" "  GPU: $name"
            log "INFO:!ts" "  Memory: $used / $total (Free: $free)"
            log "INFO:!ts" "  Utilization: $util"
        done
        echo ""
        
        # Check if Frigate is using GPU
        log "INFO" "Frigate GPU Usage:"
        docker exec frigate nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv,noheader 2>/dev/null || \
            log "WARN" "  GPU not accessible or not in use by Frigate"
        echo ""
    fi
}

# Function to check Frigate-specific metrics
check_frigate_metrics() {
    log "INFO" "=== Frigate Process Information ==="
    
    # Check processes inside container
    log "INFO" "Top processes in Frigate container:"
    docker exec frigate ps aux --sort=-%cpu | head -10
    echo ""
    
    # Check Frigate logs for performance warnings
    log "INFO" "Recent Frigate warnings/errors (last 50 lines):"
    docker logs frigate --tail 50 2>&1 | grep -E "WARNING|ERROR|performance|fps|latency" | tail -10
    echo ""
}

# Function to check network I/O
check_network_io() {
    log "INFO" "=== Network I/O ==="
    
    # Get network stats for Frigate container
    local net_rx=$(docker stats --no-stream --format '{{.NetIO}}' frigate | cut -d'/' -f1)
    local net_tx=$(docker stats --no-stream --format '{{.NetIO}}' frigate | cut -d'/' -f2)
    
    log "INFO:!ts" "  Frigate Network: RX: $net_rx / TX: $net_tx"
    echo ""
}

# Function to provide recommendations
provide_recommendations() {
    log "INFO" "=== Resource Recommendations ==="
    
    local cpu_count=$(nproc)
    local total_mem_gb=$(free -g | grep Mem | awk '{print $2}')
    local used_mem_gb=$(free -g | grep Mem | awk '{print $3}')
    local frigate_cpu=$(docker stats --no-stream --format '{{.CPUPerc}}' frigate | sed 's/%//')
    local frigate_mem_percent=$(docker stats --no-stream --format '{{.MemPerc}}' frigate | sed 's/%//')
    
    # CPU recommendations
    local cpu_per_core=$(echo "scale=2; $frigate_cpu / $cpu_count" | bc)
    if (( $(echo "$cpu_per_core > 80" | bc -l) )); then
        log "WARN" "  CPU: High usage per core (${cpu_per_core}%). Consider adding more CPU cores."
    elif (( $(echo "$frigate_cpu > 600" | bc -l) )); then
        log "INFO:!ts" "  CPU: Using ~6 cores efficiently. Current: ${frigate_cpu}%"
    else
        log "INFO:!ts" "  CPU: Normal usage (${frigate_cpu}%)"
    fi
    
    # Memory recommendations
    if (( $(echo "$frigate_mem_percent > 80" | bc -l) )); then
        log "WARN" "  Memory: High usage (${frigate_mem_percent}%). Consider adding more RAM."
    else
        log "INFO:!ts" "  Memory: Adequate (${frigate_mem_percent}% used)"
    fi
    
    # General recommendations
    echo ""
    log "INFO" "Recommended Resources for Frigate:"
    log "INFO:!ts" "  Minimum: 4 CPU cores, 8GB RAM"
    log "INFO:!ts" "  Recommended: 8-12 CPU cores, 16-32GB RAM"
    log "INFO:!ts" "  Your Current: $cpu_count cores, ${total_mem_gb}GB RAM"
    echo ""
    
    log "INFO" "For optimal performance:"
    log "INFO:!ts" "  - 1-2 CPU cores per camera stream"
    log "INFO:!ts" "  - 2-4GB RAM base + 1GB per camera"
    log "INFO:!ts" "  - SSD/NVMe storage for recordings"
    log "INFO:!ts" "  - GPU acceleration for object detection (if available)"
    echo ""
}

# Main execution
if [ "$WATCH_MODE" -eq 1 ]; then
    log "INFO" "Starting continuous monitoring for $DURATION seconds..."
    log "INFO" "Press Ctrl+C to stop early"
    echo ""
    
    end_time=$(($(date +%s) + DURATION))
    while [ $(date +%s) -lt $end_time ]; do
        clear
        log "INFO" "=== Monitoring at $(date +%H:%M:%S) ==="
        check_vm_resources
        check_container_resources
        check_gpu_resources
        check_network_io
        echo ""
        log "INFO" "Refreshing in 5 seconds... ($(( end_time - $(date +%s) ))s remaining)"
        sleep 5
    done
    
    log "INFO" "Monitoring complete."
else
    # Single snapshot
    check_vm_resources
    check_container_resources
    check_gpu_resources
    check_frigate_metrics
    check_network_io
    provide_recommendations
fi

log "INFO" "=== Resource Check Complete ==="
