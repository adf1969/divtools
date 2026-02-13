#!/bin/bash
# Helper script for running pytest test packages in the ADS project
# Last Updated: 01/16/2026 03:30:00 PM CDT

# Source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(dirname "$SCRIPT_DIR")/util/logging.sh"

# Default values
VERBOSITY="normal"
TEST_PACKAGES=()
RUN_ALL=false

# Available test packages
# Format: [package_name]="test_file_path|project_name"
# If no project specified, defaults to ads project
declare -A TEST_PACKAGES_MAP=(
    [env]="test_env_loading.py|dtpyutil"
    [bash]="test_bash_integration.py|ads"
    [features]="test_dt_ads_features.py|ads"
    [native]="test_dt_ads_native.py|ads"
    [menu]="test_menu_structure.py|ads"
)

# Available test packages (for help display)
TEST_PACKAGES_LIST=(
    "env              - Environment variable loading tests (9 tests)"
    "bash             - Bash integration tests (7 tests)"
    "features         - ADS feature tests (23 tests)"
    "native           - dt_ads_native app tests (16 tests)"
    "menu             - Menu structure tests (5 tests)"
    "all              - Run all test packages (55 tests total)"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

show_help() {
    cat << 'EOF'
╔════════════════════════════════════════════════════════════════════════════╗
║                                                                            ║
║              ADS PROJECT TEST RUNNER - run_tests.sh                        ║
║                                                                            ║
║  Helper script for running pytest test packages in the ADS (Samba AD DC)  ║
║  project. Supports running individual test packages or all tests.         ║
║                                                                            ║
╚════════════════════════════════════════════════════════════════════════════╝

USAGE:
    run_tests.sh [OPTIONS] [PACKAGES...]

SYNOPSIS:
    Run all tests with normal output:
        $ run_tests.sh all
    
    Run specific tests with short output:
        $ run_tests.sh -short env bash
    
    Run all tests with verbose output:
        $ run_tests.sh -verbose all
    
    Show help with list of available packages:
        $ run_tests.sh --help

OPTIONS:
    -short, --short           Minimal output (test results only, no details)
    -normal, --normal         Normal output (standard pytest output - DEFAULT)
    -verbose, -v, --verbose   Verbose output (all debug info and details)
    -help, --help             Show this help message and available packages
    -test, --test             Run in test mode (shows what would run, doesn't execute)
    -debug, --debug           Enable debug output for script itself

PACKAGES (positional arguments):
    env                 Environment variable loading tests (9 tests)
    bash                Bash integration tests (7 tests)  
    features            ADS feature tests (23 tests)
    native              dt_ads_native app tests (16 tests)
    menu                Menu structure tests (5 tests)
    all                 Run all test packages (55 tests total)

EXAMPLES:

    # Run specific test packages
    run_tests.sh env bash
    run_tests.sh env features native

    # Run with different verbosity levels
    run_tests.sh -short all              # Minimal output
    run_tests.sh -normal all             # Standard output (default)
    run_tests.sh -verbose all            # Full debug output

    # Run single package with verbosity
    run_tests.sh -verbose features       # Run features tests verbosely
    run_tests.sh -short env menu         # Run env + menu tests with minimal output

    # Test mode (show what would run)
    run_tests.sh -test all               # Show test command without executing

    # Debug the script itself
    run_tests.sh -debug env              # Show debug output from run_tests.sh

DEFAULT BEHAVIOR:
    If no packages specified, shows this help message.
    Default verbosity: normal (same as pytest default output)

TEST STRUCTURE:
    ├── test_env_loading.py         [9 tests]  Environment loading
    ├── test_bash_integration.py    [7 tests]  Bash integration
    ├── test_dt_ads_features.py    [23 tests]  Feature implementations
    ├── test_dt_ads_native.py      [16 tests]  Main app tests
    └── test_menu_structure.py      [5 tests]  Menu structure

    Total: 55 tests

RETURN CODES:
    0   All tests passed
    1   One or more tests failed
    2   Invalid arguments or options

ENVIRONMENT:
    PYTHON_CMD      Python executable (default: dtpyutil venv python3)
    ADS_PROJECT_DIR Project directory (detected automatically)
    
NOTES:
    - Tests use the dtpyutil Python virtual environment
    - Test output is color-coded for easier reading
    - Failures are highlighted in red
    - Passes are highlighted in green
    - Run with -verbose for debugging test failures
    
For more information, see:
    /home/divix/divtools/projects/ads/test/

EOF
}

show_packages() {
    cat << 'EOF'

AVAILABLE TEST PACKAGES:
────────────────────────────────────────────────────────────────────────────

EOF
    for pkg in "${TEST_PACKAGES_LIST[@]}"; do
        printf "  %-35s %s\n" "$(echo "$pkg" | cut -d' ' -f1)" "$(echo "$pkg" | cut -d'-' -f2-)"
    done
    cat << 'EOF'

TOTAL: 55 tests across 5 packages

────────────────────────────────────────────────────────────────────────────

EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -short|--short)
                VERBOSITY="short"
                shift
                ;;
            -normal|--normal)
                VERBOSITY="normal"
                shift
                ;;
            -verbose|-v|--verbose)
                VERBOSITY="verbose"
                shift
                ;;
            -help|--help|-h|--usage)
                show_help
                show_packages
                exit 0
                ;;
            -test|--test)
                TEST_MODE=1
                log "INFO" "Running in TEST mode - commands will be shown but not executed"
                shift
                ;;
            -debug|--debug)
                DEBUG_MODE=1
                shift
                ;;
            all)
                RUN_ALL=true
                TEST_PACKAGES=("env" "bash" "features" "native" "menu")
                shift
                ;;
            env|bash|features|native|menu)
                TEST_PACKAGES+=("$1")
                shift
                ;;
            *)
                log "ERROR" "Unknown option or package: $1"
                echo "Run '$0 --help' for usage information"
                return 1
                ;;
        esac
    done
    
    return 0
}

run_pytest() {
    local package=$1
    local test_file="${TEST_PACKAGES_MAP[$package]}"
    
    if [[ -z "$test_file" ]]; then
        log "ERROR" "Unknown package: $package"
        return 1
    fi
    
    # Parse test file and project
    local test_name=$(echo "$test_file" | cut -d'|' -f1)
    local project_name=$(echo "$test_file" | cut -d'|' -f2)
    project_name=${project_name:-"ads"}  # Default to ads if not specified
    
    # Determine project directory
    local project_dir
    if [[ "$project_name" == "dtpyutil" ]]; then
        project_dir="/home/divix/divtools/projects/dtpyutil"
    else
        project_dir="$ADS_PROJECT_DIR"
    fi
    
    # Build pytest command based on verbosity
    local pytest_args="-v"
    case "$VERBOSITY" in
        short)
            pytest_args="-q"
            ;;
        normal)
            pytest_args="-v"
            ;;
        verbose)
            pytest_args="-vv --tb=long"
            ;;
    esac
    
    local test_path="$project_dir/test/${test_name}"
    
    if [[ ! -f "$test_path" ]]; then
        log "WARN" "Test file not found: $test_path"
        return 1
    fi
    
    local cmd="cd '$project_dir' && \
        '$PYTHON_CMD' -m pytest '$test_path' $pytest_args"
    
    if [[ $DEBUG_MODE -eq 1 ]]; then
        log "DEBUG" "Running: $cmd"
    fi
    
    if [[ $TEST_MODE -eq 1 ]]; then
        log "INFO" "Would run: $cmd"
        return 0
    fi
    
    # Run the actual command
    eval "$cmd"
    return $?
}

main() {
    # Defaults
    TEST_MODE=0
    DEBUG_MODE=0
    
    # Detect ADS project directory
    ADS_PROJECT_DIR="$(cd "$(dirname "$SCRIPT_DIR")/../projects/ads" 2>/dev/null && pwd)"
    if [[ -z "$ADS_PROJECT_DIR" || ! -d "$ADS_PROJECT_DIR" ]]; then
        ADS_PROJECT_DIR="$(cd "$SCRIPT_DIR/../../projects/ads" 2>/dev/null && pwd)"
    fi
    
    if [[ ! -d "$ADS_PROJECT_DIR" ]]; then
        log "ERROR" "Could not locate ADS project directory"
        return 1
    fi
    
    # Find Python executable from dtpyutil venv
    PYTHON_CMD="/home/divix/divtools/scripts/venvs/dtpyutil/bin/python"
    if [[ ! -f "$PYTHON_CMD" ]]; then
        log "WARN" "dtpyutil venv not found, trying system python3"
        PYTHON_CMD="python3"
    fi
    
    # Parse arguments
    if ! parse_args "$@"; then
        return 2
    fi
    
    # If no packages specified, show help
    if [[ ${#TEST_PACKAGES[@]} -eq 0 ]]; then
        show_help
        show_packages
        return 0
    fi
    
    if [[ $DEBUG_MODE -eq 1 ]]; then
        log "DEBUG" "ADS Project Dir: $ADS_PROJECT_DIR"
        log "DEBUG" "Python Command: $PYTHON_CMD"
        log "DEBUG" "Verbosity: $VERBOSITY"
        log "DEBUG" "Test Packages: ${TEST_PACKAGES[*]}"
    fi
    
    # Run tests
    log "HEAD" "╔════════════════════════════════════════════════════════════════╗"
    log "HEAD" "║              Running ADS Tests (${#TEST_PACKAGES[@]} packages)                ║"
    log "HEAD" "╚════════════════════════════════════════════════════════════════╝"
    
    local total_exit_code=0
    for package in "${TEST_PACKAGES[@]}"; do
        log "INFO" "Running tests for: $package"
        if ! run_pytest "$package"; then
            total_exit_code=1
        fi
        echo ""
    done
    
    if [[ $total_exit_code -eq 0 ]]; then
        log "HEAD" "✅ All test packages passed!"
    else
        log "ERROR" "❌ Some test packages failed"
    fi
    
    return $total_exit_code
}

# Run main if script is executed (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
