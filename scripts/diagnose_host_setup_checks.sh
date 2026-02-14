#!/bin/bash
# diagnose_host_setup_checks.sh - Diagnose why host_setup_checks isn't running
# Last Updated: 11/11/2025 8:30:00 PM CDT

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  HOST SETUP CHECKS - DIAGNOSTIC SCRIPT                       ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

echo "System Information:"
echo "  Hostname: $(hostname)"
echo "  User: $(whoami)"
echo "  Home: $HOME"
echo "  Shell: $SHELL"
echo "  Interactive: $-"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "CHECK 1: Is this an interactive shell?"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ $- == *i* ]]; then
    echo "  ✅ YES - This is an interactive shell"
    echo "     The checks SHOULD run"
else
    echo "  ❌ NO - This is NOT an interactive shell"
    echo "     The checks will NOT run (by design)"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "CHECK 2: DIVTOOLS variable"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ -n "$DIVTOOLS" ]; then
    echo "  ✅ DIVTOOLS is set: $DIVTOOLS"
    if [ -d "$DIVTOOLS" ]; then
        echo "     ✅ Directory exists"
    else
        echo "     ❌ Directory does NOT exist!"
    fi
else
    echo "  ❌ DIVTOOLS is NOT set"
    echo "     Will try fallback: /opt/divtools"
    DIVTOOLS="/opt/divtools"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "CHECK 3: host_setup_checks.sh script exists?"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
SCRIPT_PATH="$DIVTOOLS/scripts/util/host_setup_checks.sh"
if [ -f "$SCRIPT_PATH" ]; then
    echo "  ✅ Script found: $SCRIPT_PATH"
    ls -lh "$SCRIPT_PATH" | awk '{print "     Permissions: " $1 ", Size: " $5}'
else
    echo "  ❌ Script NOT found at: $SCRIPT_PATH"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "CHECK 4: Required environment variables"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  DT_INCLUDE_HOST_SETUP: ${DT_INCLUDE_HOST_SETUP:-NOT SET}"
if [ "${DT_INCLUDE_HOST_SETUP:-0}" == "1" ] || [ "${DT_INCLUDE_HOST_SETUP:-0}" == "true" ]; then
    echo "     ✅ ENABLED - dt_host_setup checks will run"
else
    echo "     ❌ DISABLED - dt_host_setup checks will NOT run"
fi
echo ""

echo "  DT_INCLUDE_HOST_CHANGE_LOG: ${DT_INCLUDE_HOST_CHANGE_LOG:-NOT SET}"
if [ "${DT_INCLUDE_HOST_CHANGE_LOG:-0}" == "1" ] || [ "${DT_INCLUDE_HOST_CHANGE_LOG:-0}" == "true" ]; then
    echo "     ✅ ENABLED - host_change_log checks will run"
else
    echo "     ❌ DISABLED - host_change_log checks will NOT run"
fi
echo ""

echo "  DIVTOOLS_SKIP_CHECKS: ${DIVTOOLS_SKIP_CHECKS:-NOT SET}"
if [ "${DIVTOOLS_SKIP_CHECKS:-0}" == "1" ]; then
    echo "     ⚠️  ALL CHECKS SKIPPED (DIVTOOLS_SKIP_CHECKS=1)"
else
    echo "     ✅ Not skipping (checks can run if enabled)"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "CHECK 5: Check .env files for variables"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check user .env
if [ -f ~/.env ]; then
    echo "  User .env (~/.env):"
    echo "     ✅ File exists"
    if grep -q "DT_INCLUDE_HOST_SETUP" ~/.env 2>/dev/null; then
        grep "DT_INCLUDE_HOST_SETUP" ~/.env | head -1 | sed 's/^/        /'
    else
        echo "        (DT_INCLUDE_HOST_SETUP not set)"
    fi
    if grep -q "DT_INCLUDE_HOST_CHANGE_LOG" ~/.env 2>/dev/null; then
        grep "DT_INCLUDE_HOST_CHANGE_LOG" ~/.env | head -1 | sed 's/^/        /'
    else
        echo "        (DT_INCLUDE_HOST_CHANGE_LOG not set)"
    fi
else
    echo "  User .env (~/.env): ❌ NOT FOUND"
fi
echo ""

# Check shared .env
SHARED_ENV="$DIVTOOLS/docker/sites/s00-shared/.env.s00-shared"
if [ -f "$SHARED_ENV" ]; then
    echo "  Shared .env: $SHARED_ENV"
    echo "     ✅ File exists"
    if grep -q "DT_INCLUDE_HOST_SETUP" "$SHARED_ENV" 2>/dev/null; then
        grep "DT_INCLUDE_HOST_SETUP" "$SHARED_ENV" | head -1 | sed 's/^/        /'
    else
        echo "        (DT_INCLUDE_HOST_SETUP not set)"
    fi
    if grep -q "DT_INCLUDE_HOST_CHANGE_LOG" "$SHARED_ENV" 2>/dev/null; then
        grep "DT_INCLUDE_HOST_CHANGE_LOG" "$SHARED_ENV" | head -1 | sed 's/^/        /'
    else
        echo "        (DT_INCLUDE_HOST_CHANGE_LOG not set)"
    fi
else
    echo "  Shared .env: ❌ NOT FOUND at $SHARED_ENV"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "CHECK 6: Has host_setup_checks.sh been sourced?"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ -n "$HOST_SETUP_CHECKS_SOURCED" ]; then
    echo "  ✅ YES - host_setup_checks.sh has been sourced"
    echo "     HOST_SETUP_CHECKS_SOURCED=$HOST_SETUP_CHECKS_SOURCED"
else
    echo "  ❌ NO - host_setup_checks.sh has NOT been sourced"
fi
echo ""

if declare -f host_setup_checks >/dev/null 2>&1; then
    echo "  ✅ Function 'host_setup_checks' is defined"
else
    echo "  ❌ Function 'host_setup_checks' is NOT defined"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "CHECK 7: Setup completion status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check dt_host_setup
echo "  dt_host_setup status:"
if [ -f ~/.env ]; then
    if grep -q "SITE_NAME=" ~/.env; then
        echo "     ✅ COMPLETE - ~/.env exists with SITE_NAME"
        grep "SITE_NAME=" ~/.env | head -1 | sed 's/^/        /'
    else
        echo "     ❌ INCOMPLETE - ~/.env exists but no SITE_NAME"
    fi
else
    echo "     ❌ INCOMPLETE - ~/.env does not exist"
fi
echo ""

# Check host_change_log
echo "  host_change_log status:"
LOG_DIR="${DT_LOG_DIR:-/var/log/divtools/monitor}"
if [ -f "$LOG_DIR/monitoring_manifest.json" ]; then
    echo "     ✅ COMPLETE - manifest exists at $LOG_DIR/monitoring_manifest.json"
else
    echo "     ❌ INCOMPLETE - manifest not found at $LOG_DIR/monitoring_manifest.json"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "SUMMARY & RECOMMENDATIONS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Determine if checks should run
SHOULD_RUN=0
REASONS=()

if [[ ! $- == *i* ]]; then
    REASONS+=("❌ Not an interactive shell")
else
    if [ ! -f "$SCRIPT_PATH" ]; then
        REASONS+=("❌ host_setup_checks.sh script not found")
    fi
    
    if [ "${DT_INCLUDE_HOST_SETUP:-0}" != "1" ] && [ "${DT_INCLUDE_HOST_SETUP:-0}" != "true" ] && \
       [ "${DT_INCLUDE_HOST_CHANGE_LOG:-0}" != "1" ] && [ "${DT_INCLUDE_HOST_CHANGE_LOG:-0}" != "true" ]; then
        REASONS+=("❌ No DT_INCLUDE_* variables are enabled")
    fi
    
    if [ "${DIVTOOLS_SKIP_CHECKS:-0}" == "1" ]; then
        REASONS+=("❌ DIVTOOLS_SKIP_CHECKS is set to 1")
    fi
    
    if [ ${#REASONS[@]} -eq 0 ]; then
        SHOULD_RUN=1
    fi
fi

if [ $SHOULD_RUN -eq 1 ]; then
    echo "✅ Host setup checks SHOULD be running!"
    echo ""
    echo "If you're not seeing the menu, try:"
    echo "  1. Open a new shell: bash -i"
    echo "  2. Check for errors in .bash_profile"
    echo "  3. Run manually:"
    echo "     source $SCRIPT_PATH"
    echo "     host_setup_checks"
else
    echo "❌ Host setup checks will NOT run because:"
    for reason in "${REASONS[@]}"; do
        echo "   $reason"
    done
    echo ""
    echo "To enable the checks:"
    echo ""
    echo "  1. Enable at least one check variable:"
    echo "     echo 'export DT_INCLUDE_HOST_SETUP=1' >> ~/.env"
    echo "     echo 'export DT_INCLUDE_HOST_CHANGE_LOG=1' >> ~/.env"
    echo ""
    echo "  2. Open a new interactive shell:"
    echo "     bash -i"
    echo ""
    echo "  3. The menu should appear automatically"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "DIAGNOSTIC COMPLETE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
