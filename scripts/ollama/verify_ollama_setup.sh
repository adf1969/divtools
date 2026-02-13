#!/bin/bash
# Verifies Ollama setup and volume mounts to prevent data loss
# Last Updated: 11/7/2025 5:30:00 PM CST

# Source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../util/logging.sh"

log "HEAD" "=== Ollama Setup Verification ==="

# Check if Ollama container is running
if ! docker ps --format '{{.Names}}' | grep -q "^ollama$"; then
    log "ERROR" "Ollama container is not running!"
    log "INFO" "Start it with: dcup --profile ollama"
    exit 1
fi

log "INFO" "✓ Ollama container is running"

# Check volume mounts
log "INFO" "Checking volume mounts..."
MOUNTS=$(docker inspect ollama --format '{{json .Mounts}}')

# Check models directory mount
MODELS_MOUNT=$(echo "$MOUNTS" | grep -o '"/root/.ollama"' || true)
if [ -z "$MODELS_MOUNT" ]; then
    log "ERROR" "Models directory is NOT mounted to /root/.ollama!"
    log "ERROR" "This means models will be lost on container restart!"
    exit 1
fi

MODELS_SOURCE=$(echo "$MOUNTS" | python3 -c "import sys, json; mounts = json.load(sys.stdin); print([m['Source'] for m in mounts if m['Destination'] == '/root/.ollama'][0])")
log "INFO" "✓ Models mounted from: $MODELS_SOURCE"

# Verify the source directory exists and is writable
if [ ! -d "$MODELS_SOURCE" ]; then
    log "ERROR" "Models source directory does not exist: $MODELS_SOURCE"
    exit 1
fi

if [ ! -w "$MODELS_SOURCE" ]; then
    log "WARN" "Models directory is not writable by current user"
    log "INFO" "Current permissions:"
    ls -ld "$MODELS_SOURCE"
fi

log "INFO" "✓ Models directory exists and is accessible"

# Check for existing models
log "INFO" "Checking for existing models..."
MODEL_COUNT=$(docker exec ollama ollama list | tail -n +2 | wc -l)

if [ "$MODEL_COUNT" -eq 0 ]; then
    log "WARN" "No models currently installed"
else
    log "INFO" "✓ Found $MODEL_COUNT model(s) installed:"
    docker exec ollama ollama list
fi

# Check disk space
log "INFO" "Checking available disk space..."
AVAILABLE=$(df -h "$MODELS_SOURCE" | tail -1 | awk '{print $4}')
log "INFO" "Available space at $MODELS_SOURCE: $AVAILABLE"

# Check if OLLAMA_MODELS env var is set correctly inside container
log "INFO" "Verifying OLLAMA_MODELS environment variable..."
OLLAMA_MODELS_VAR=$(docker exec ollama printenv OLLAMA_MODELS 2>/dev/null || echo "NOT SET")
if [ "$OLLAMA_MODELS_VAR" = "NOT SET" ]; then
    log "WARN" "OLLAMA_MODELS environment variable not set in container"
else
    log "INFO" "✓ OLLAMA_MODELS set to: $OLLAMA_MODELS_VAR"
fi

# Final verification - check if we can write to the models directory
log "INFO" "Testing write access to models directory..."
TEST_FILE="$MODELS_SOURCE/.write_test_$$"
if touch "$TEST_FILE" 2>/dev/null; then
    rm -f "$TEST_FILE"
    log "INFO" "✓ Write test successful"
else
    log "ERROR" "Cannot write to models directory: $MODELS_SOURCE"
    log "ERROR" "Downloaded models may not persist!"
    exit 1
fi

log "HEAD" "=== Verification Complete ==="
log "INFO" "Ollama setup is configured correctly for persistent storage"
log "INFO" "Models will be saved to: $MODELS_SOURCE"
log "INFO" "Models will survive container restarts and system reboots"

exit 0
