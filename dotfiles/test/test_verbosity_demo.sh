#!/bin/bash
# DivTools Verbosity Control System - Quick Test Demo
# Last Updated: 11/11/2025
#
# This script demonstrates the verbosity control system in action
# Usage: ./test_verbosity_demo.sh

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  DivTools Verbosity Control System - Demo                      ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Source the bash profile to get the log_msg function and DT_VERBOSITY_LEVELS
source /etc/profile 2>/dev/null || source ~/.bash_profile 2>/dev/null

echo "Current settings:"
echo "  DT_VERBOSE=${DT_VERBOSE:-not set}"
echo "  DT_VERBOSITY_LEVELS array:"
for key in "${!DT_VERBOSITY_LEVELS[@]}"; do
    printf "    [%-6s] = %d\n" "$key" "${DT_VERBOSITY_LEVELS[$key]}"
done
echo ""
echo "════════════════════════════════════════════════════════════════"
echo ""

# Test 1: Normal verbosity (2)
echo "TEST 1: DT_VERBOSE=2 (Normal - Default)"
echo "─────────────────────────────────────────"
export DT_VERBOSE=2
log_msg "STAR" "Starship message (threshold=2, shown)"
log_msg "INFO" "Info message (threshold=2, shown)"
log_msg "SAMBA" "Samba message (threshold=2, shown)"
log_msg "DEBUG" "Debug message (threshold=3, hidden)"
log_msg "ERROR" "Error message (threshold=0, always shown)"
echo ""
echo "════════════════════════════════════════════════════════════════"
echo ""

# Test 2: Silent mode (0)
echo "TEST 2: DT_VERBOSE=0 (Silent)"
echo "─────────────────────────────────────────"
export DT_VERBOSE=0
log_msg "STAR" "Starship message (hidden)"
log_msg "INFO" "Info message (hidden)"
log_msg "SAMBA" "Samba message (hidden)"
log_msg "WARN" "Warning message (threshold=1, hidden)"
log_msg "ERROR" "Error message (threshold=0, always shown)"
echo ""
echo "════════════════════════════════════════════════════════════════"
echo ""

# Test 3: Verbose mode (3)
echo "TEST 3: DT_VERBOSE=3 (Verbose)"
echo "─────────────────────────────────────────"
export DT_VERBOSE=3
log_msg "STAR" "Starship message (shown)"
log_msg "INFO" "Info message (shown)"
log_msg "SAMBA" "Samba message (shown)"
log_msg "DEBUG" "Debug message (threshold=3, shown)"
log_msg "ERROR" "Error message (always shown)"
echo ""
echo "════════════════════════════════════════════════════════════════"
echo ""

# Test 4: Minimal mode (1)
echo "TEST 4: DT_VERBOSE=1 (Minimal)"
echo "─────────────────────────────────────────"
export DT_VERBOSE=1
log_msg "STAR" "Starship message (hidden)"
log_msg "INFO" "Info message (hidden)"
log_msg "WARN" "Warning message (threshold=1, shown)"
log_msg "ERROR" "Error message (always shown)"
echo ""
echo "════════════════════════════════════════════════════════════════"
echo ""

# Test 5: Custom thresholds
echo "TEST 5: Custom thresholds (STAR=999 to silence it)"
echo "─────────────────────────────────────────"
export DT_VERBOSE=2
declare -gxA DT_VERBOSITY_LEVELS=(
    ["STAR"]=999         # Never show
    ["SAMBA"]=2          # Show at normal level
    ["INFO"]=2
    ["WARN"]=1
    ["ERROR"]=0
    ["DEBUG"]=3
)
log_msg "STAR" "Starship message (threshold=999, hidden)"
log_msg "SAMBA" "Samba message (threshold=2, shown)"
log_msg "INFO" "Info message (shown)"
echo ""
echo "════════════════════════════════════════════════════════════════"
echo ""

echo "✅ Demo complete!"
echo ""
echo "Quick reference for usage:"
echo "  Normal:     sep                       (or: source /etc/profile)"
echo "  Silent:     export DT_VERBOSE=0 && sep"
echo "  Verbose:    export DT_VERBOSE=3 && sep"
echo "  Debug:      export DT_VERBOSE=4 && sep"
echo ""
echo "See VERBOSITY_CONTROL.md for detailed documentation."
