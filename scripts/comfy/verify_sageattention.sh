#!/bin/bash
# Verify SageAttention is enabled in ComfyUI service
# Last Updated: 01/27/2026 11:30:00 AM CST

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../util/logging.sh"

echo "🔍 Checking if ComfyUI is running with SageAttention..."
echo

# Check 1: Service status
echo "1. Service Status:"
if systemctl is-active --quiet comfy.service; then
    echo "   ✅ ComfyUI service is running"
else
    echo "   ❌ ComfyUI service is not running"
    exit 1
fi
echo

# Check 2: Environment variable
echo "2. Environment Configuration:"
if [[ -f "/opt/comfy/.env.comfy" ]]; then
    if grep -q "COMFY_USE_SAGE_ATTENTION=1" "/opt/comfy/.env.comfy"; then
        echo "   ✅ COMFY_USE_SAGE_ATTENTION=1 found in .env.comfy"
    else
        echo "   ⚠️  COMFY_USE_SAGE_ATTENTION not set to 1 in .env.comfy"
    fi
else
    echo "   ❌ .env.comfy file not found at /opt/comfy/.env.comfy"
fi
echo

# Check 3: Process command line
echo "3. Process Command Line:"
COMFY_PID=$(pgrep -f "comfy launch" | head -1)
if [[ -n "$COMFY_PID" ]]; then
    CMDLINE=$(ps -p "$COMFY_PID" -o cmd= 2>/dev/null)
    if echo "$CMDLINE" | grep -q -- "--use-sage-attention"; then
        echo "   ✅ --use-sage-attention flag found in process: $COMFY_PID"
        echo "   Command: $CMDLINE"
    else
        echo "   ❌ --use-sage-attention flag NOT found in process: $COMFY_PID"
        echo "   Command: $CMDLINE"
    fi
else
    echo "   ❌ No comfy launch process found"
fi
echo

# Check 4: Recent logs
echo "4. Recent Service Logs (SageAttention mentions):"
LOGS=$(sudo journalctl -u comfy.service -n 100 --no-pager 2>/dev/null | grep -i "sage" | tail -5)
if [[ -n "$LOGS" ]]; then
    echo "   ✅ Found SageAttention in logs:"
    echo "$LOGS" | sed 's/^/      /'
else
    echo "   ⚠️  No SageAttention mentions in recent logs (may be normal)"
fi
echo

# Check 5: ComfyUI startup logs
echo "5. ComfyUI Startup Logs (last 20 lines):"
STARTUP_LOGS=$(sudo journalctl -u comfy.service -n 20 --no-pager 2>/dev/null | grep -v "systemd")
if [[ -n "$STARTUP_LOGS" ]]; then
    echo "$STARTUP_LOGS" | sed 's/^/   /'
else
    echo "   ❌ No ComfyUI logs found"
fi

echo
echo "💡 Tips:"
echo "   - If SageAttention isn't working, try: sudo systemctl restart comfy.service"
echo "   - Check ComfyUI web interface console for SageAttention initialization messages"
echo "   - Look for improved performance in video generation workflows"