#!/bin/bash
# Test Menu for dthostmon - Interactive Test Selection
# Last Updated: 1/16/2025 12:30:00 PM CST
#
# Provides an interactive menu for running unit tests using Whiptail/Dialog/YAD.
# Supports both external (docker exec) and internal (inside container) modes.

# Determine execution mode
if [ -f /.dockerenv ] || grep -q docker /proc/1/cgroup 2>/dev/null; then
    EXECUTION_MODE="internal"
else
    EXECUTION_MODE="external"
fi

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Detect which dialog tool is available
detect_dialog_tool() {
    if command -v whiptail &> /dev/null; then
        echo "whiptail"
    elif command -v dialog &> /dev/null; then
        echo "dialog"
    elif command -v yad &> /dev/null; then
        echo "yad"
    else
        echo "none"
    fi
}

DIALOG_TOOL=$(detect_dialog_tool)

# Display message
msg() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

msg_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

msg_error() {
    echo -e "${RED}[✗]${NC} $1"
}

msg_warn() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

# Test structure - organized by section
# Format: "test_file.py::TestClass::test_method|Display Name"
declare -A TEST_SECTIONS=(
    ["Core Functionality"]="
        test_config.py|Configuration Loading
        test_database.py|Database Models
        test_ssh_client.py|SSH Client
    "
    ["AI Analysis"]="
        test_ai_analyzer.py|AI Analyzer
    "
    ["Reporting"]="
        test_host_report.py|Host Report Generator
        test_site_report.py|Site Report Generator
    "
    ["Alerting"]="
        test_email_alert.py|Email Alerts
    "
)

# Function to run pytest command
run_pytest() {
    local test_path="$1"
    local test_name="$2"
    
    msg "Running test: $test_name"
    
    if [ "$EXECUTION_MODE" = "external" ]; then
        # Check if Docker container is running
        if ! docker ps --format '{{.Names}}' | grep -q "dthostmon"; then
            msg_error "dthostmon container is not running"
            return 1
        fi
        
        msg "Executing via docker exec..."
        docker exec dthostmon pytest "/app/tests/unit/$test_path" -v
    else
        # Running inside container
        cd "$PROJECT_ROOT" || return 1
        pytest "tests/unit/$test_path" -v
    fi
    
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        msg_success "Test passed: $test_name"
    else
        msg_error "Test failed: $test_name (exit code: $exit_code)"
    fi
    
    return $exit_code
}

# Function to run all tests in a section
run_section_tests() {
    local section="$1"
    local tests="${TEST_SECTIONS[$section]}"
    
    msg "Running all tests in section: $section"
    
    local failed=0
    while IFS='|' read -r test_file test_name; do
        # Skip empty lines
        [[ -z "$test_file" ]] && continue
        
        # Trim whitespace
        test_file=$(echo "$test_file" | xargs)
        test_name=$(echo "$test_name" | xargs)
        
        run_pytest "$test_file" "$test_name"
        [ $? -ne 0 ] && ((failed++))
    done <<< "$tests"
    
    if [ $failed -eq 0 ]; then
        msg_success "All tests in section '$section' passed"
    else
        msg_error "$failed test(s) failed in section '$section'"
    fi
}

# Function to run all tests
run_all_tests() {
    msg "Running ALL unit tests"
    
    if [ "$EXECUTION_MODE" = "external" ]; then
        docker exec dthostmon pytest /app/tests/unit -v
    else
        cd "$PROJECT_ROOT" || return 1
        pytest tests/unit -v
    fi
}

# Whiptail menu
show_whiptail_menu() {
    local options=()
    local section_num=1
    
    # Add "Run All Tests" option
    options+=("ALL" "Run All Unit Tests" "OFF")
    
    # Build section options
    for section in "${!TEST_SECTIONS[@]}"; do
        options+=("SECTION_$section_num" "$section (Run All)" "OFF")
        
        # Add individual tests in section
        local tests="${TEST_SECTIONS[$section]}"
        while IFS='|' read -r test_file test_name; do
            [[ -z "$test_file" ]] && continue
            test_file=$(echo "$test_file" | xargs)
            test_name=$(echo "$test_name" | xargs)
            options+=("$test_file" "  └─ $test_name" "OFF")
        done <<< "$tests"
        
        ((section_num++))
    done
    
    # Show checklist
    local choices
    choices=$(whiptail --title "dthostmon Test Menu" \
        --checklist "\nExecution Mode: $EXECUTION_MODE\n\nSelect tests to run (SPACE to select, ENTER to confirm):" \
        25 80 15 \
        "${options[@]}" \
        3>&1 1>&2 2>&3)
    
    if [ $? -ne 0 ]; then
        msg "Test execution cancelled"
        exit 0
    fi
    
    # Remove quotes from choices
    choices=$(echo "$choices" | tr -d '"')
    
    # Execute selected tests
    local failed=0
    for choice in $choices; do
        if [ "$choice" = "ALL" ]; then
            run_all_tests
            [ $? -ne 0 ] && ((failed++))
        elif [[ "$choice" =~ ^SECTION_ ]]; then
            # Extract section name
            local section_idx="${choice#SECTION_}"
            local section_name=$(echo "${!TEST_SECTIONS[@]}" | cut -d' ' -f"$section_idx")
            run_section_tests "$section_name"
        else
            # Individual test
            local test_file="$choice"
            local test_name=$(grep -h "$test_file" <<< "${TEST_SECTIONS[@]}" | cut -d'|' -f2 | head -1 | xargs)
            run_pytest "$test_file" "$test_name"
            [ $? -ne 0 ] && ((failed++))
        fi
    done
    
    echo ""
    if [ $failed -eq 0 ]; then
        msg_success "All selected tests passed"
    else
        msg_error "$failed test(s) failed"
    fi
}

# Dialog menu (similar to whiptail)
show_dialog_menu() {
    msg "Dialog interface not yet implemented, falling back to whiptail"
    show_whiptail_menu
}

# YAD menu
show_yad_menu() {
    msg "YAD interface not yet implemented, falling back to whiptail"
    show_whiptail_menu
}

# Fallback text menu (no GUI)
show_text_menu() {
    echo ""
    echo "====================================="
    echo "  dthostmon Test Menu"
    echo "  Execution Mode: $EXECUTION_MODE"
    echo "====================================="
    echo ""
    echo "Test Sections:"
    echo ""
    
    local section_num=1
    for section in "${!TEST_SECTIONS[@]}"; do
        echo "[$section_num] $section"
        ((section_num++))
    done
    
    echo ""
    echo "[A] Run All Tests"
    echo "[Q] Quit"
    echo ""
    read -p "Select option: " choice
    
    case "$choice" in
        [Qq])
            msg "Exiting"
            exit 0
            ;;
        [Aa])
            run_all_tests
            ;;
        [1-9])
            local section_name=$(echo "${!TEST_SECTIONS[@]}" | cut -d' ' -f"$choice")
            if [ -n "$section_name" ]; then
                run_section_tests "$section_name"
            else
                msg_error "Invalid section number"
            fi
            ;;
        *)
            msg_error "Invalid option"
            ;;
    esac
}

# Main menu dispatcher
show_menu() {
    case "$DIALOG_TOOL" in
        whiptail)
            show_whiptail_menu
            ;;
        dialog)
            show_dialog_menu
            ;;
        yad)
            show_yad_menu
            ;;
        none)
            msg_warn "No dialog tool found (whiptail, dialog, or yad)"
            msg "Falling back to text menu"
            show_text_menu
            ;;
    esac
}

# Display execution mode
msg "Test Menu Execution Mode: $EXECUTION_MODE"
if [ "$EXECUTION_MODE" = "external" ]; then
    msg "Tests will run via 'docker exec dthostmon pytest ...'"
else
    msg "Tests will run directly inside the container"
fi
msg "Using dialog tool: $DIALOG_TOOL"
echo ""

# Show menu
show_menu
