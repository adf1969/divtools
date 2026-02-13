#!/bin/bash
# test_host_setup_checks.sh - Quick test script for host_setup_checks.sh
# Run this on a fresh system (like TNHL01) to verify the checks are working
# Usage: ./test_host_setup_checks.sh [-debug] [-test]

# Parse flags
DEBUG_MODE=0
TEST_MODE=0

while [[ $# -gt 0 ]]; do
    case $1 in
        -debug|--debug)
            DEBUG_MODE=1
            shift
            ;;
        -test|--test)
            TEST_MODE=1
            shift
            ;;
        *)
            shift
            ;;
    esac
done

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  HOST SETUP CHECKS - TEST SCRIPT                              ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Show test configuration
echo "Test Configuration:"
echo "  System: $(hostname)"
echo "  User: $(whoami)"
echo "  Home: $HOME"
echo "  Date: $(date)"
echo ""

# Step 1: Check if dt_host_setup has been run
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 1: Check dt_host_setup Completion Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Checking for ~/.env..."
if [ -f ~/.env ]; then
    echo "  ✓ ~/.env exists"
    echo "    Location: $(ls -lh ~/.env | awk '{print $9, $5}')"
    
    if grep -q "SITE_NAME=" ~/.env; then
        site_name=$(grep "SITE_NAME=" ~/.env | head -1 | cut -d= -f2)
        echo "  ✓ SITE_NAME found in ~/.env: $site_name"
        echo "  ✓ dt_host_setup appears COMPLETE"
    else
        echo "  ✗ SITE_NAME NOT found in ~/.env"
        echo "  ✗ dt_host_setup appears INCOMPLETE"
    fi
else
    echo "  ✗ ~/.env does NOT exist"
    echo "  ✗ dt_host_setup appears INCOMPLETE"
fi
echo ""

# Step 2: Check if host_change_log has been run
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 2: Check host_change_log Completion Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

log_dir="${DT_LOG_DIR:-/var/log/divtools/monitor}"
echo "Checking for manifest at: $log_dir/monitoring_manifest.json"

if [ -f "${log_dir}/monitoring_manifest.json" ]; then
    echo "  ✓ Manifest exists"
    echo "    Location: $(ls -lh ${log_dir}/monitoring_manifest.json | awk '{print $9, $5}')"
    echo "  ✓ host_change_log appears COMPLETE"
else
    if [ ! -d "$log_dir" ]; then
        echo "  ✗ Log directory does NOT exist: $log_dir"
    fi
    echo "  ✗ Manifest NOT found"
    echo "  ✗ host_change_log appears INCOMPLETE"
fi
echo ""

# Step 3: Source the script and run checks
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 3: Run host_setup_checks() with Environment Variables"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Enable both checks
export DT_INCLUDE_HOST_SETUP=1
export DT_INCLUDE_HOST_CHANGE_LOG=1

echo "Environment Variables Set:"
echo "  DT_INCLUDE_HOST_SETUP=$DT_INCLUDE_HOST_SETUP"
echo "  DT_INCLUDE_HOST_CHANGE_LOG=$DT_INCLUDE_HOST_CHANGE_LOG"
echo "  DIVTOOLS=${DIVTOOLS:-/opt/divtools}"
echo ""

# Source the script
script_path="${DIVTOOLS:-/home/divix/divtools}/scripts/util/host_setup_checks.sh"
if [ ! -f "$script_path" ]; then
    script_path="/opt/divtools/scripts/util/host_setup_checks.sh"
fi

if [ ! -f "$script_path" ]; then
    echo "❌ ERROR: host_setup_checks.sh not found!"
    echo "   Checked: ${DIVTOOLS:-/home/divix/divtools}/scripts/util/host_setup_checks.sh"
    echo "   Checked: /opt/divtools/scripts/util/host_setup_checks.sh"
    exit 1
fi

echo "Sourcing: $script_path"
source "$script_path" -debug -test

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 4: Execute host_setup_checks() Function"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Call the function with debug/test flags
host_setup_checks

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST COMPLETE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Summary:"
echo "  If you saw the menu above with both setups listed, the script IS working!"
echo "  If you saw [TEST MODE] messages, no actual changes were made."
echo "  If you saw [DEBUG] messages, debug output is enabled."
echo ""
echo "Next Steps:"
echo "  1. To enable checks permanently, add to ~/.env:"
echo "     echo 'export DT_INCLUDE_HOST_SETUP=1' >> ~/.env"
echo "     echo 'export DT_INCLUDE_HOST_CHANGE_LOG=1' >> ~/.env"
echo ""
echo "  2. Open a new interactive shell:"
echo "     bash -i"
echo ""
echo "  3. You should see the setup menu automatically!"
echo ""
