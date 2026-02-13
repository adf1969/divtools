#!/bin/bash
# test_dtpmenu_returns.sh - Automated Test Suite for dtpmenu Return Values
# Demonstrates that EVERY dtpmenu mode can be called from bash and return proper values
# Last Updated: 01/14/2026 04:00:00 AM CDT

set -euo pipefail

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "$DIVTOOLS" ] && export DIVTOOLS="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$DIVTOOLS/scripts/util/dt_pmenu_lib.sh"
source "$DIVTOOLS/scripts/util/logging.sh"

# Configuration
export PMENU_H_CENTER=1
export PMENU_V_CENTER=1
export DEBUG_MODE=0

TEST_PASSED=0
TEST_FAILED=0

# ============================================================================
# TEST UTILITIES
# ============================================================================

test_result() {
    local test_name="$1"
    local expected_code="$2"
    local actual_code="$3"
    local description="${4:-}"
    
    if [[ $actual_code -eq $expected_code ]]; then
        log "SUCCESS" "✅ PASS: $test_name"
        [[ -n "$description" ]] && log "INFO" "   Detail: $description"
        ((TEST_PASSED++))
        return 0
    else
        log "ERROR" "❌ FAIL: $test_name"
        log "ERROR" "   Expected exit code: $expected_code"
        log "ERROR" "   Actual exit code: $actual_code"
        [[ -n "$description" ]] && log "ERROR" "   Detail: $description"
        ((TEST_FAILED++))
        return 1
    fi
}

pause_test() {
    read -p "Press Enter to continue to next test..."
    clear
}

# ============================================================================
# YES/NO DIALOG TESTS (Most reliable for testing)
# ============================================================================

test_yesno_capture() {
    clear
    log "HEAD" "TEST 1: Yes/No Dialog - Return Value Capture"
    log "INFO" "This test demonstrates that pmenu_yesno properly returns exit codes"
    log "INFO" ""
    log "INFO" "Instructions:"
    log "INFO" "1. Click the YES button in the dialog"
    log "INFO" "2. The script will verify exit code 0 was returned"
    log "INFO" ""
    log "WARN" "⚠️  This test REQUIRES your interaction!"
    log "INFO" ""
    
    read -p "Ready? Press Enter to show the YES/NO dialog..."
    
    # Test: User clicks YES (should return 0)
    pmenu_yesno "Test: Click YES" "Do you see this dialog? Click YES button."
    local yes_code=$?
    
    test_result "pmenu_yesno with YES selection" "0" "$yes_code" \
        "Dialog should have returned exit code 0"
    
    pause_test
}

test_yesno_cancel() {
    clear
    log "HEAD" "TEST 2: Yes/No Dialog - Cancel Behavior"
    log "INFO" "This test demonstrates that pmenu_yesno returns exit code 1 when cancelled"
    log "INFO" ""
    log "INFO" "Instructions:"
    log "INFO" "1. Click the NO button in the dialog"
    log "INFO" "2. The script will verify exit code 1 was returned"
    log "INFO" ""
    
    read -p "Ready? Press Enter to show the dialog..."
    
    # Test: User clicks NO (should return 1)
    pmenu_yesno "Test: Click NO" "Please click the NO button this time."
    local no_code=$?
    
    test_result "pmenu_yesno with NO selection" "1" "$no_code" \
        "Dialog should have returned exit code 1"
    
    pause_test
}

# ============================================================================
# MESSAGE BOX TESTS
# ============================================================================

test_msgbox_simple() {
    clear
    log "HEAD" "TEST 3: Message Box - Basic Functionality"
    log "INFO" "This test demonstrates that pmenu_msgbox returns proper exit code"
    log "INFO" ""
    
    read -p "Press Enter to show message box..."
    
    pmenu_msgbox "Test Message" "This is a test message.\\nClick OK to continue."
    local msgbox_code=$?
    
    test_result "pmenu_msgbox return code" "0" "$msgbox_code" \
        "Message box should return exit code 0"
    
    pause_test
}

# ============================================================================
# MENU MODE TESTS
# ============================================================================

test_menu_selection() {
    clear
    log "HEAD" "TEST 4: Menu Selection - Return Value"
    log "INFO" "This test demonstrates that pmenu_menu returns proper exit code"
    log "INFO" ""
    log "INFO" "Instructions:"
    log "INFO" "1. Select any option from the menu"
    log "INFO" "2. Click OK to confirm selection"
    log "INFO" "3. The script will verify exit code 0 was returned"
    log "INFO" ""
    
    read -p "Ready? Press Enter to show the menu..."
    
    pmenu_menu "Test Menu" \
        "opt1" "Option One" \
        "opt2" "Option Two" \
        "opt3" "Option Three"
    
    local menu_code=$?
    
    test_result "pmenu_menu selection" "0" "$menu_code" \
        "Menu should return exit code 0 when option selected"
    
    pause_test
}

test_menu_cancel() {
    clear
    log "HEAD" "TEST 5: Menu Cancellation - Return Value"
    log "INFO" "This test demonstrates pmenu_menu return code when cancelled"
    log "INFO" ""
    log "INFO" "Instructions:"
    log "INFO" "1. Close the menu without selecting (click X or press Escape)"
    log "INFO" "2. The script will verify exit code 1 was returned"
    log "INFO" ""
    
    read -p "Ready? Press Enter to show the menu..."
    
    pmenu_menu "Test Menu - Try to Close Without Selecting" \
        "opt1" "Option One" \
        "opt2" "Option Two"
    
    local menu_cancel_code=$?
    
    test_result "pmenu_menu cancellation" "1" "$menu_cancel_code" \
        "Menu should return exit code 1 when cancelled"
    
    pause_test
}

# ============================================================================
# INPUT BOX TESTS
# ============================================================================

test_inputbox_confirm() {
    clear
    log "HEAD" "TEST 6: Input Box - Confirmation"
    log "INFO" "This test demonstrates that pmenu_inputbox returns exit code 0 on OK"
    log "INFO" ""
    log "INFO" "Instructions:"
    log "INFO" "1. Type something in the input field (or use the default)"
    log "INFO" "2. Click OK to confirm"
    log "INFO" "3. The script will verify exit code 0 was returned"
    log "INFO" ""
    
    read -p "Ready? Press Enter to show the input box..."
    
    pmenu_inputbox "Test Input" "Enter some text:" "default input"
    local input_code=$?
    
    test_result "pmenu_inputbox confirmation" "0" "$input_code" \
        "Input box should return exit code 0 when confirmed"
    
    pause_test
}

test_inputbox_cancel() {
    clear
    log "HEAD" "TEST 7: Input Box - Cancellation"
    log "INFO" "This test demonstrates pmenu_inputbox return code when cancelled"
    log "INFO" ""
    log "INFO" "Instructions:"
    log "INFO" "1. Click Cancel or close the dialog"
    log "INFO" "2. The script will verify exit code 1 was returned"
    log "INFO" ""
    
    read -p "Ready? Press Enter to show the input box..."
    
    pmenu_inputbox "Test Input - Try to Cancel" "Enter text or cancel:" "default"
    local input_cancel_code=$?
    
    test_result "pmenu_inputbox cancellation" "1" "$input_cancel_code" \
        "Input box should return exit code 1 when cancelled"
    
    pause_test
}

# ============================================================================
# AUTOMATED EXIT CODE VERIFICATION
# ============================================================================

test_automated_yesno() {
    clear
    log "HEAD" "TEST 8: Automated Yes/No Verification"
    log "INFO" "Testing that we can reliably use Yes/No exit codes in conditionals"
    log "INFO" ""
    
    log "INFO" "Running: if pmenu_yesno ... (waiting for your input)"
    
    if pmenu_yesno "Conditional Test" "Does this conditional work? Click YES."; then
        test_result "Automated if statement with pmenu_yesno" "0" "0" \
            "Conditional executed YES branch"
    else
        test_result "Automated if statement with pmenu_yesno" "0" "1" \
            "ERROR: Should have executed YES branch!"
    fi
    
    pause_test
}

test_automated_menu_success() {
    clear
    log "HEAD" "TEST 9: Automated Menu Success Detection"
    log "INFO" "Testing that we can reliably detect menu selection"
    log "INFO" ""
    
    log "INFO" "Running: if pmenu_menu ... (waiting for your selection)"
    
    if pmenu_menu "Conditional Test" "a" "Option A" "b" "Option B"; then
        test_result "Automated menu success detection" "0" "0" \
            "Menu selection properly detected"
    else
        test_result "Automated menu success detection" "0" "1" \
            "Menu was cancelled"
    fi
    
    pause_test
}

# ============================================================================
# DEMONSTRATION: CHAINED OPERATIONS
# ============================================================================

test_chained_workflow() {
    clear
    log "HEAD" "TEST 10: Chained Dialog Workflow"
    log "INFO" "Demonstrating a realistic workflow using multiple dialogs"
    log "INFO" ""
    log "INFO" "Workflow:"
    log "INFO" "1. Show menu for user to select action"
    log "INFO" "2. Ask for confirmation (Yes/No)"
    log "INFO" "3. Show result message"
    log "INFO" ""
    
    read -p "Press Enter to start the workflow..."
    
    # Step 1: Show menu
    pmenu_menu "What would you like to do?" \
        "export" "📤 Export Data" \
        "import" "📥 Import Data" \
        "analyze" "📊 Analyze Data"
    
    if [[ $? -ne 0 ]]; then
        log "INFO" "User cancelled at menu step"
        pause_test
        return
    fi
    
    log "INFO" "User selected an option"
    
    # Step 2: Confirm action
    pmenu_yesno "Confirm" "Proceed with the selected operation?"
    
    if [[ $? -ne 0 ]]; then
        log "INFO" "User declined confirmation"
        pause_test
        return
    fi
    
    log "INFO" "User confirmed action"
    
    # Step 3: Show result
    pmenu_msgbox "Success" "Operation completed successfully!"
    
    test_result "Chained dialog workflow" "0" "0" \
        "All dialogs in sequence completed successfully"
    
    pause_test
}

# ============================================================================
# SUMMARY REPORT
# ============================================================================

print_summary() {
    clear
    log "HEAD" "TEST SUMMARY REPORT"
    log "INFO" "========================================"
    log "SUCCESS" "Tests Passed:  $TEST_PASSED"
    log "ERROR" "Tests Failed:  $TEST_FAILED"
    log "INFO" "========================================"
    
    local total=$((TEST_PASSED + TEST_FAILED))
    if [[ $total -gt 0 ]]; then
        local percentage=$((TEST_PASSED * 100 / total))
        log "INFO" "Pass Rate: ${percentage}%"
    fi
    
    log "INFO" ""
    log "HEAD" "CONCLUSION"
    
    if [[ $TEST_FAILED -eq 0 ]]; then
        log "SUCCESS" "✅ ALL TESTS PASSED!"
        log "SUCCESS" "dtpmenu IS usable from bash and DOES return proper values"
    else
        log "ERROR" "❌ Some tests failed"
        log "ERROR" "Please review failures above"
    fi
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    clear
    log "HEAD" "DTPMENU RETURN VALUE TEST SUITE"
    log "INFO" "This script tests that dtpmenu can be called from bash"
    log "INFO" "and properly return exit codes for all modes."
    log "INFO" ""
    log "INFO" "You will be asked to interact with dialogs."
    log "INFO" "The script will verify that exit codes are returned correctly."
    log "INFO" ""
    
    # Check dependencies
    if ! check_dtpmenu_deps; then
        log "ERROR" "Dependencies not found"
        log "ERROR" "Run: bash projects/dtpmenu/install_dtpmenu_deps.sh"
        exit 1
    fi
    
    read -p "Press Enter to begin testing..."
    
    # Run all tests
    test_yesno_capture
    test_yesno_cancel
    test_msgbox_simple
    test_menu_selection
    test_menu_cancel
    test_inputbox_confirm
    test_inputbox_cancel
    test_automated_yesno
    test_automated_menu_success
    test_chained_workflow
    
    # Print summary
    print_summary
}

main "$@"
