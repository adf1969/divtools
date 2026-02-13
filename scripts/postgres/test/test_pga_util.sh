#!/bin/bash
# test_pga_util.sh - Test suite for pga_util.sh
# Last Updated: 2/13/2026 12:00:00 PM CDT
#
# This test suite validates pga_util.sh functionality without modifying the production database.
# - Read operations (--list, --list-locked) use the real pgadmin4.db
# - Write operations (--unlock) use a copy of the database created in a temporary directory

source "$(dirname "$0")/../../util/logging.sh"

# Script paths
SCRIPT_UNDER_TEST="$(dirname "$0")/../pga_util.sh"
REAL_DB="/opt/pgadmin/pgadmin4.db"
TEST_DIR="/tmp/pga_util_tests_$$"
TEST_DB="$TEST_DIR/pgadmin4.db"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Cleanup on exit
cleanup() {
    log "INFO" "Cleaning up test directory: $TEST_DIR"
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# Setup test environment
setup_tests() {
    log "INFO" "Setting up test environment..."
    
    # Check if the main script exists
    if [[ ! -f "$SCRIPT_UNDER_TEST" ]]; then
        log "ERROR" "pga_util.sh not found at $SCRIPT_UNDER_TEST"
        exit 1
    fi
    
    # Check if the real DB exists
    if [[ ! -f "$REAL_DB" ]]; then
        log "ERROR" "PGAdmin database not found at $REAL_DB"
        exit 1
    fi
    
    # Create test directory
    mkdir -p "$TEST_DIR"
    
    # Copy the real database for write testing
    log "INFO" "Creating test database copy..."
    cp "$REAL_DB" "$TEST_DB"
    
    if [[ $? -ne 0 ]]; then
        log "ERROR" "Failed to copy database to $TEST_DB"
        exit 1
    fi
    
    log "INFO" "Test environment ready"
}

# Test helper functions
run_test() {
    local test_name="$1"
    local expected_result="$2"
    shift 2
    local cmd=("$@")
    
    ((TESTS_RUN++))
    
    log "INFO" "Running test: $test_name"
    
    # Execute command and capture output and exit code
    output=$("${cmd[@]}" 2>&1)
    exit_code=$?
    
    # Check if result matches expectation
    if [[ "$exit_code" == "$expected_result" ]]; then
        log "INFO" "[✔] PASSED: $test_name"
        ((TESTS_PASSED++))
    else
        log "ERROR" "[✘] FAILED: $test_name"
        log "ERROR" "Expected exit code: $expected_result, Got: $exit_code"
        log "ERROR" "Output: $output"
        ((TESTS_FAILED++))
    fi
}

# Test: List all users from real database
test_list_all_users() {
    log "INFO" "=== Test Suite: List Operations (using real DB) ==="
    
    run_test "List all users" 0 \
        "$SCRIPT_UNDER_TEST" "-l"
    
    # Verify output contains expected columns
    output=$("$SCRIPT_UNDER_TEST" "-l" 2>&1)
    if echo "$output" | grep -q "username\|email\|status"; then
        log "INFO" "[✔] Output contains expected columns"
        ((TESTS_PASSED++))
    else
        log "ERROR" "[✘] Output missing expected columns"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

# Test: List locked users from real database
test_list_locked_users() {
    run_test "List locked users" 0 \
        "$SCRIPT_UNDER_TEST" "-ll"
}

# Test: List with test flag (should not fail on locked users)
test_list_with_test_flag() {
    run_test "List all users (test mode)" 0 \
        "$SCRIPT_UNDER_TEST" "-l" "-t"
}

# Test: Unlock operation with test database
test_unlock_user() {
    log "INFO" "=== Test Suite: Unlock Operations (using test DB copy) ==="
    
    # Get a user from the test database
    local test_user=$(sqlite3 "$TEST_DB" "SELECT username FROM \"user\" LIMIT 1;" 2>/dev/null)
    
    if [[ -z "$test_user" ]]; then
        log "WARN" "No users in test database, skipping unlock test"
        return
    fi
    
    log "INFO" "Using test user: $test_user"
    
    # First, lock the user in the test database
    sqlite3 "$TEST_DB" "UPDATE \"user\" SET locked = 1 WHERE username = '$test_user';" 2>/dev/null
    
    # Verify user is locked
    locked=$(sqlite3 "$TEST_DB" "SELECT locked FROM \"user\" WHERE username = '$test_user';" 2>/dev/null)
    if [[ "$locked" == "1" ]]; then
        log "INFO" "User locked successfully for testing"
    fi
    
    # Now unlock using a wrapper that uses test DB
    # Create a temporary wrapper script that uses the test DB
    local wrapper_script="$TEST_DIR/pga_util_wrapper.sh"
    cat > "$wrapper_script" <<'WRAPPER_EOF'
#!/bin/bash
# Wrapper that redirects DB path to test database
PGADMIN_DB="$TEST_DB" exec "$SCRIPT_UNDER_TEST" "$@"
WRAPPER_EOF
    chmod +x "$wrapper_script"
    
    # Export variables for the wrapper
    export TEST_DB
    export SCRIPT_UNDER_TEST
    
    run_test "Unlock specific user (test mode)" 0 \
        bash -c "PGADMIN_DB='$TEST_DB' '$SCRIPT_UNDER_TEST' -u '$test_user' -t"
    
    # Verify user is still locked (test mode should not change anything)
    locked_after=$(sqlite3 "$TEST_DB" "SELECT locked FROM \"user\" WHERE username = '$test_user';" 2>/dev/null)
    if [[ "$locked_after" == "1" ]]; then
        log "INFO" "[✔] Test mode verified - user remains locked"
        ((TESTS_PASSED++))
    else
        log "ERROR" "[✘] Test mode failed - user was modified"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
    
    # Now test actual unlock (without -t flag) on test database
    run_test "Unlock specific user (actual)" 0 \
        bash -c "PGADMIN_DB='$TEST_DB' '$SCRIPT_UNDER_TEST' -u '$test_user'"
    
    # Verify user is now unlocked in test database
    locked_final=$(sqlite3 "$TEST_DB" "SELECT locked FROM \"user\" WHERE username = '$test_user';" 2>/dev/null)
    if [[ "$locked_final" == "0" ]]; then
        log "INFO" "[✔] User successfully unlocked in test DB"
        ((TESTS_PASSED++))
    else
        log "ERROR" "[✘] User unlock failed"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

# Test: Unlock all locked users on test database
test_unlock_all_users() {
    # Lock a test user first
    local test_user=$(sqlite3 "$TEST_DB" "SELECT username FROM \"user\" LIMIT 1;" 2>/dev/null)
    
    if [[ -z "$test_user" ]]; then
        log "WARN" "No users in test database, skipping unlock all test"
        return
    fi
    
    sqlite3 "$TEST_DB" "UPDATE \"user\" SET locked = 1 WHERE username = '$test_user';" 2>/dev/null
    
    run_test "Unlock all locked users (test mode)" 0 \
        bash -c "PGADMIN_DB='$TEST_DB' '$SCRIPT_UNDER_TEST' --unlock -t"
    
    run_test "Unlock all locked users (actual)" 0 \
        bash -c "PGADMIN_DB='$TEST_DB' '$SCRIPT_UNDER_TEST' --unlock"
    
    # Verify all users are now unlocked
    locked_count=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM \"user\" WHERE locked = 1;" 2>/dev/null)
    if [[ "$locked_count" == "0" ]]; then
        log "INFO" "[✔] All users successfully unlocked in test DB"
        ((TESTS_PASSED++))
    else
        log "ERROR" "[✘] Some users remain locked"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

# Test: Help and version information
test_help() {
    log "INFO" "=== Test Suite: Help and Usage ==="
    
    run_test "Help flag (-h)" 0 \
        "$SCRIPT_UNDER_TEST" "-h"
    
    run_test "Help flag (--help)" 0 \
        "$SCRIPT_UNDER_TEST" "--help"
}

# Test: Invalid arguments
test_invalid_args() {
    log "INFO" "=== Test Suite: Error Handling ==="
    
    run_test "Invalid argument handling" 1 \
        "$SCRIPT_UNDER_TEST" "--invalid-flag"
}

# Test: No action specified
test_no_action() {
    run_test "No action specified" 1 \
        "$SCRIPT_UNDER_TEST"
}

# Print test summary
print_summary() {
    echo ""
    log "INFO" "==============================================="
    log "INFO" "Test Summary"
    log "INFO" "==============================================="
    log "INFO" "Total Tests Run:  $TESTS_RUN"
    log "INFO" "Tests Passed:     $TESTS_PASSED"
    log "INFO" "Tests Failed:     $TESTS_FAILED"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        log "INFO" "Result: ✔ ALL TESTS PASSED"
        return 0
    else
        log "ERROR" "Result: ✘ SOME TESTS FAILED"
        return 1
    fi
}

# Main test execution
main() {
    log "INFO" "Starting pga_util.sh test suite..."
    log "INFO" "Real DB: $REAL_DB"
    log "INFO" "Test DB: $TEST_DB"
    log "INFO" "Script:  $SCRIPT_UNDER_TEST"
    echo ""
    
    setup_tests
    
    # Run all tests
    test_help
    test_list_all_users
    test_list_locked_users
    test_list_with_test_flag
    test_invalid_args
    test_no_action
    test_unlock_user
    test_unlock_all_users
    
    # Print summary and exit with appropriate code
    print_summary
    exit $?
}

# Run tests
main "$@"
