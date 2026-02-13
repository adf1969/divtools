#!/bin/bash
# Quick check to verify Ollama models are persisted
# Last Updated: 11/7/2025 5:50:00 PM CST

# Source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../util/logging.sh"

log "HEAD" "=== Ollama Model Persistence Check ==="

# Check models in container
log "INFO" "Models visible in Ollama:"
docker exec ollama ollama list

echo ""

# Check actual files on host
log "INFO" "Files on host filesystem:"
if sudo test -d /opt/ollama/models/blobs; then
    MODEL_COUNT=$(sudo find /opt/ollama/models/blobs -type f 2>/dev/null | wc -l)
    DISK_USAGE=$(sudo du -sh /opt/ollama/models 2>/dev/null | awk '{print $1}')
    log "INFO" "  Blob files: $MODEL_COUNT"
    log "INFO" "  Disk usage: $DISK_USAGE"
    
    if [ "$MODEL_COUNT" -gt 2 ]; then
        log "INFO" "✓ Models are persisted on host filesystem"
    else
        log "WARN" "Only metadata files found - no actual models"
    fi
else
    log "WARN" "Blobs directory not found"
fi

echo ""

# Check available space
AVAILABLE=$(df -h /opt | tail -1 | awk '{print $4}')
log "INFO" "Available disk space: $AVAILABLE"

exit 0
