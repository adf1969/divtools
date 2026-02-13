#!/bin/bash
# Test script to verify Ollama models persist correctly
# Last Updated: 11/7/2025 7:15:00 PM CST

# Source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../util/logging.sh"

log "HEAD" "=== Ollama Persistence Verification Test ==="

# Step 1: Verify configuration
log "INFO" "Step 1: Verifying configuration..."

# Check OLLAMA_MODELS is NOT set (should use default /root/.ollama)
OLLAMA_MODELS_VAR=$(docker exec ollama printenv OLLAMA_MODELS 2>/dev/null || echo "")
if [ -z "$OLLAMA_MODELS_VAR" ]; then
    log "INFO" "✓ OLLAMA_MODELS not set (using default /root/.ollama)"
else
    log "ERROR" "✗ OLLAMA_MODELS is set to: $OLLAMA_MODELS_VAR"
    log "ERROR" "This will cause persistence issues!"
    exit 1
fi

# Check volume mount
MOUNT_CHECK=$(docker inspect ollama --format '{{range .Mounts}}{{if eq .Destination "/root/.ollama"}}{{.Source}}{{end}}{{end}}')
if [ -n "$MOUNT_CHECK" ]; then
    log "INFO" "✓ Volume mounted: $MOUNT_CHECK -> /root/.ollama"
else
    log "ERROR" "✗ /root/.ollama is NOT mounted!"
    exit 1
fi

# Step 2: Check current models
log "INFO" "Step 2: Checking current models..."
BEFORE_COUNT=$(docker exec ollama ollama list 2>/dev/null | tail -n +2 | wc -l)
log "INFO" "Models currently installed: $BEFORE_COUNT"

# Step 3: Download a small test model
log "INFO" "Step 3: Downloading small test model (qwen2.5:0.5b - ~397MB)..."
log "WARN" "This will download ~397MB. Press Ctrl+C to cancel, or wait 5 seconds..."
sleep 5

docker exec ollama ollama pull qwen2.5:0.5b
if [ $? -ne 0 ]; then
    log "ERROR" "Failed to download test model"
    exit 1
fi

log "INFO" "✓ Test model downloaded"

# Step 4: Verify model appears in Ollama
log "INFO" "Step 4: Verifying model appears in Ollama..."
if docker exec ollama ollama list | grep -q "qwen2.5:0.5b"; then
    log "INFO" "✓ Model appears in Ollama list"
else
    log "ERROR" "✗ Model NOT in Ollama list!"
    exit 1
fi

# Step 5: Check files on host filesystem
log "INFO" "Step 5: Checking files on host filesystem..."
HOST_BLOBS=$(sudo find /opt/ollama/models/blobs -type f 2>/dev/null | wc -l)
HOST_SIZE=$(sudo du -sh /opt/ollama/models 2>/dev/null | awk '{print $1}')

log "INFO" "Files in /opt/ollama/models/blobs: $HOST_BLOBS"
log "INFO" "Disk usage: $HOST_SIZE"

if [ "$HOST_BLOBS" -gt 2 ]; then
    log "INFO" "✓ Model files found on host filesystem"
else
    log "ERROR" "✗ No model files on host! Models in container only!"
    exit 1
fi

# Step 6: Restart container and verify model persists
log "INFO" "Step 6: Restarting container to test persistence..."
log "WARN" "Restarting Ollama container..."

docker restart ollama
sleep 5

# Wait for container to be healthy
log "INFO" "Waiting for container to be ready..."
for i in {1..30}; do
    if docker exec ollama ollama list &>/dev/null; then
        break
    fi
    sleep 1
done

# Step 7: Verify model still exists after restart
log "INFO" "Step 7: Verifying model survived restart..."
if docker exec ollama ollama list | grep -q "qwen2.5:0.5b"; then
    log "INFO" "✓✓✓ Model PERSISTED after container restart!"
else
    log "ERROR" "✗✗✗ Model LOST after restart!"
    exit 1
fi

# Step 8: Clean up test model
log "INFO" "Step 8: Cleaning up test model..."
docker exec ollama ollama rm qwen2.5:0.5b
log "INFO" "✓ Test model removed"

# Final summary
log "HEAD" "=== TEST PASSED ==="
log "INFO" "✓ Configuration is correct"
log "INFO" "✓ Models are saved to host filesystem"
log "INFO" "✓ Models persist across container restarts"
log "INFO" ""
log "INFO" "It is now SAFE to download your production models."
log "INFO" "They WILL persist across reboots and restarts."
log "INFO" ""
log "INFO" "Recommended models to download:"
log "INFO" "  - docker exec -it ollama ollama pull qwen2.5-vl:7b"
log "INFO" "  - docker exec -it ollama ollama pull deepseek-r1:8b"
log "INFO" "  - docker exec -it ollama ollama pull llama3.1:8b"

exit 0
