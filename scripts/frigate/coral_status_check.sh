#!/bin/bash
# Coral USB TPU Status Check
# Last Updated: 11/11/2025 12:20:00 PM CST
#
# Quick status check to verify Coral is working and autosuspend is disabled

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║         Coral USB TPU Status Check                        ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
echo "Timestamp: $(date)"
echo "Hostname: $(hostname)"
echo ""

# === SECTION 1: USB Autosuspend Setting ===
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║ USB Autosuspend Setting                                   ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

AUTOSUSPEND=$(cat /sys/module/usbcore/parameters/autosuspend 2>/dev/null)
echo "usbcore.autosuspend: $AUTOSUSPEND"

if [[ "$AUTOSUSPEND" == "-1" ]]; then
    echo "✓ Status: DISABLED (good for Coral)"
else
    echo "✗ Status: ENABLED (bad for Coral - disconnections likely)"
fi
echo ""

# === SECTION 2: Coral Device Detection ===
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║ Coral Device Detection                                    ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

if lsusb -d 18d1:9302 2>/dev/null | grep -q "18d1:9302"; then
    echo "✓ Coral TPU DETECTED"
    lsusb -d 18d1:9302
else
    echo "✗ Coral TPU NOT DETECTED"
    echo "  (Device may be disconnected or in reset state)"
fi
echo ""

# === SECTION 3: Frigate Container Status ===
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║ Frigate Container Status                                  ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

if docker ps --filter name=frigate --format "{{.ID}}" 2>/dev/null | grep -q .; then
    STATUS=$(docker inspect frigate --format='{{.State.Status}}' 2>/dev/null)
    HEALTH=$(docker inspect frigate --format='{{.State.Health.Status}}' 2>/dev/null)
    
    echo "Container: $STATUS"
    echo "Health: $HEALTH"
    
    if [[ "$STATUS" == "running" ]]; then
        echo "✓ Frigate is RUNNING"
    else
        echo "✗ Frigate is NOT running"
    fi
else
    echo "✗ Frigate container not found"
fi
echo ""

# === SECTION 4: Recent Coral Errors ===
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║ Recent Coral Errors (Last 1 Hour)                         ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

ERRORS=$(docker logs frigate --since 1h 2>/dev/null | grep -i "coral\|edgetpu" | grep -i "error\|failed" | wc -l)

if [[ -z "$ERRORS" ]]; then
    ERRORS=0
fi

echo "Error count: $ERRORS"

if [[ $ERRORS -eq 0 ]]; then
    echo "✓ No recent errors"
else
    echo "⚠ Found errors - showing last 3:"
    echo ""
    docker logs frigate --since 1h 2>/dev/null | grep -i "coral\|edgetpu" | grep -i "error\|failed" | tail -3
fi
echo ""

# === SECTION 5: System Uptime ===
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║ System Information                                        ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

UPTIME=$(uptime | awk -F'up' '{print $2}' | xargs)
echo "Uptime: $UPTIME"
echo ""

# === FINAL SUMMARY ===
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║ Summary                                                   ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

STATUS_OK=0

if [[ "$AUTOSUSPEND" == "-1" ]]; then
    echo "✓ Autosuspend disabled"
    ((STATUS_OK++))
else
    echo "✗ Autosuspend ENABLED - FIX NEEDED"
fi

if lsusb -d 18d1:9302 2>/dev/null | grep -q "18d1:9302"; then
    echo "✓ Coral device visible"
    ((STATUS_OK++))
else
    echo "✗ Coral device NOT visible"
fi

if docker ps --filter name=frigate --format "{{.ID}}" 2>/dev/null | grep -q . && \
   [[ "$(docker inspect frigate --format='{{.State.Status}}' 2>/dev/null)" == "running" ]]; then
    echo "✓ Frigate running"
    ((STATUS_OK++))
else
    echo "✗ Frigate not running"
fi

if [[ $ERRORS -eq 0 ]]; then
    echo "✓ No recent errors"
    ((STATUS_OK++))
else
    echo "⚠ Errors detected ($ERRORS in last hour)"
fi

echo ""
echo "Overall Status: $STATUS_OK/4 checks passed"

if [[ $STATUS_OK -eq 4 ]]; then
    echo "✓ SYSTEM HEALTHY"
    exit 0
elif [[ $STATUS_OK -ge 3 ]]; then
    echo "⚠ MOSTLY OK (minor issues)"
    exit 0
else
    echo "✗ ISSUES DETECTED"
    exit 1
fi
