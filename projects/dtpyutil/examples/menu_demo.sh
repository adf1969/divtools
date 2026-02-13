#!/bin/bash
# demo_menu.sh - Interactive Menu Demo for dtpmenu
# Allows user to select which tests to run
# Last Updated: 01/14/2026 12:30:00 PM CDT

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "$DIVTOOLS" ] && export DIVTOOLS="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$DIVTOOLS/scripts/util/dt_pmenu_lib.sh"
source "$DIVTOOLS/scripts/util/logging.sh"

# Configuration
DEBUG_MODE=0
export PMENU_H_CENTER=1
export PMENU_V_CENTER=1

# ============================================================================
# MENU MODE TESTS
# ============================================================================

test_menu_basic() {
    clear
    log "INFO" "Testing: Basic Menu Selection"
    log "DEBUG" "Run menu and capture selection..."
    
    local selection
    selection=$(pmenu_menu "Choose a Fruit" \
        "apple" "🍎 Red Apple" \
        "banana" "🍌 Yellow Banana" \
        "cherry" "🍒 Red Cherry" \
        "grape" "🍇 Purple Grapes" \
        "orange" "🍊 Orange")
    
    local result=$?
    
    clear
    log "HEAD" "MENU TEST RESULT"
    log "INFO" "Exit Code: $result"
    
    if [[ $result -eq 0 ]]; then
        log "SUCCESS" "✅ User selected an option (exit code 0)"
        log "INFO" "Selected: $selection"
    elif [[ $result -eq 1 ]]; then
        log "INFO" "ℹ️  User cancelled menu (exit code 1)"
    fi
    
    read -p "Press Enter to return..."
}

test_menu_complex() {
    clear
    log "INFO" "Testing: Complex System Admin Menu"
    
    pmenu_menu "System Administration" \
        "users" "👤 Manage Users" \
        "services" "⚙️  Manage Services" \
        "network" "🌐 Network Settings" \
        "security" "🔒 Security Settings" \
        "backup" "💾 Backup & Restore"
    
    local result=$?
    
    clear
    log "HEAD" "COMPLEX MENU TEST RESULT"
    log "INFO" "Exit Code: $result"
    
    if [[ $result -eq 0 ]]; then
        log "SUCCESS" "✅ User made selection (exit code 0)"
    else
        log "INFO" "ℹ️  User cancelled (exit code 1)"
    fi
    
    read -p "Press Enter to return..."
}

# ============================================================================
# MESSAGE BOX TESTS
# ============================================================================

test_msgbox_simple() {
    clear
    log "INFO" "Testing: Simple Message Box"
    
    pmenu_msgbox "Operation Complete" \
        "The file has been saved successfully.\\nAll changes are now stored in the database."
    
    local result=$?
    
    clear
    log "HEAD" "MESSAGE BOX TEST RESULT"
    log "INFO" "Exit Code: $result"
    
    if [[ $result -eq 0 ]]; then
        log "SUCCESS" "✅ Message acknowledged (exit code 0)"
    fi
    
    read -p "Press Enter to return..."
}

test_msgbox_multiline() {
    clear
    log "INFO" "Testing: Multi-line Message Box"
    
    pmenu_msgbox "System Information" \
        "System Name: $(hostname)\\nCurrent User: $(whoami)\\nCurrent Time: $(date '+%Y-%m-%d %H:%M:%S')\\n\\nThis demonstrates multi-line message support."
    
    local result=$?
    
    clear
    log "HEAD" "MULTILINE MESSAGE BOX TEST RESULT"
    log "INFO" "Exit Code: $result"
    log "SUCCESS" "✅ Multi-line message displayed (exit code $result)"
    
    read -p "Press Enter to return..."
}

# ============================================================================
# YES/NO DIALOG TESTS
# ============================================================================

test_yesno_simple() {
    clear
    log "INFO" "Testing: Yes/No Dialog with Return Value Capture"
    
    pmenu_yesno "Confirm Action" "Do you want to proceed with this operation?"
    
    local result=$?
    
    clear
    log "HEAD" "YES/NO DIALOG TEST RESULT"
    log "INFO" "Exit Code: $result"
    
    if [[ $result -eq 0 ]]; then
        log "SUCCESS" "✅ User clicked YES (exit code 0)"
        log "INFO" "Action would be: PROCEED"
    elif [[ $result -eq 1 ]]; then
        log "INFO" "ℹ️  User clicked NO (exit code 1)"
        log "INFO" "Action would be: CANCEL"
    fi
    
    read -p "Press Enter to return..."
}

test_yesno_destructive() {
    clear
    log "INFO" "Testing: Destructive Operation Confirmation"
    
    pmenu_yesno "WARNING: Destructive Operation" \
        "This action CANNOT be undone.\\n\\nDo you want to permanently delete the selected items?"
    
    local result=$?
    
    clear
    log "HEAD" "DESTRUCTIVE OPERATION TEST RESULT"
    log "INFO" "Exit Code: $result"
    
    if [[ $result -eq 0 ]]; then
        log "SUCCESS" "✅ User confirmed deletion (exit code 0)"
        log "INFO" "Would execute: DELETE operation"
    else
        log "INFO" "ℹ️  User cancelled (exit code 1)"
        log "INFO" "Action: Preservation of data"
    fi
    
    read -p "Press Enter to return..."
}

# ============================================================================
# INPUT BOX TESTS
# ============================================================================

test_inputbox_simple() {
    clear
    log "INFO" "Testing: Simple Input Box"
    log "DEBUG" "User input will appear on-screen as they type..."
    
    # Capture the user's input text
    local input_text
    input_text=$(pmenu_inputbox "User Registration" "Enter your full name:" "John Doe")
    local result=$?
    
    clear
    log "HEAD" "INPUT BOX TEST RESULT"
    log "INFO" "Exit Code: $result"
    
    if [[ $result -eq 0 ]]; then
        log "SUCCESS" "✅ User confirmed input (exit code 0)"
        log "INFO" "Input was: '$input_text'"
    else
        log "INFO" "ℹ️  User cancelled input (exit code 1)"
    fi
    
    read -p "Press Enter to return..."
}

test_inputbox_hostname() {
    clear
    log "INFO" "Testing: Hostname Configuration Input"
    
    # Capture the hostname input
    local hostname_input
    hostname_input=$(pmenu_inputbox "System Configuration" "Enter the system hostname:" "$(hostname)")
    local result=$?
    
    clear
    log "HEAD" "HOSTNAME INPUT TEST RESULT"
    log "INFO" "Exit Code: $result"
    
    if [[ $result -eq 0 ]]; then
        log "SUCCESS" "✅ Hostname entry confirmed (exit code 0)"
        log "INFO" "Hostname entered: '$hostname_input'"
    else
        log "INFO" "ℹ️  Configuration cancelled (exit code 1)"
    fi
    
    read -p "Press Enter to return..."
}

# ============================================================================
# SUBMENU FUNCTIONS
# ============================================================================

submenu_menu_tests() {
    while true; do
        clear
        log "HEAD" "MENU MODE TESTS"
        log "INFO" ""
        
        pmenu_menu "Menu Test Options" \
            "basic" "Basic Fruit Selection" \
            "complex" "Complex System Admin Menu" \
            "back" "Return to Main Menu"
        
        local result=$?
        if [[ $result -ne 0 ]]; then return; fi
        
        # Note: Since we can't capture menu selection directly,
        # we run the tests. For production use, you'd need to 
        # implement a workaround pattern
        test_menu_basic
    done
}

submenu_msgbox_tests() {
    while true; do
        clear
        log "HEAD" "MESSAGE BOX TESTS"
        log "INFO" ""
        
        pmenu_menu "Message Box Test Options" \
            "simple" "Simple Message" \
            "multiline" "Multi-line Message" \
            "back" "Return to Main Menu"
        
        local result=$?
        if [[ $result -ne 0 ]]; then return; fi
        
        # Run tests
        test_msgbox_simple
    done
}

submenu_yesno_tests() {
    while true; do
        clear
        log "HEAD" "YES/NO DIALOG TESTS"
        log "INFO" ""
        
        pmenu_menu "Yes/No Test Options" \
            "simple" "Simple Confirmation" \
            "destructive" "Destructive Operation" \
            "back" "Return to Main Menu"
        
        local result=$?
        if [[ $result -ne 0 ]]; then return; fi
        
        # Run tests
        test_yesno_simple
    done
}

submenu_input_tests() {
    while true; do
        clear
        log "HEAD" "INPUT BOX TESTS"
        log "INFO" ""
        
        pmenu_menu "Input Box Test Options" \
            "simple" "Simple Text Input" \
            "hostname" "Hostname Configuration" \
            "back" "Return to Main Menu"
        
        local result=$?
        if [[ $result -ne 0 ]]; then return; fi
        
        # Run the input box test
        test_inputbox_simple
    done
}

# ============================================================================
# MAIN MENU
# ============================================================================

main_menu() {
    while true; do
        clear
        log "HEAD" "DTPMENU COMPREHENSIVE TEST SUITE"
        log "INFO" "Select a test category to verify dtpmenu functionality"
        log "DEBUG" "Centering: H_CENTER=$PMENU_H_CENTER, V_CENTER=$PMENU_V_CENTER"
        log "INFO" ""
        
        local menu_selection
        menu_selection=$(pmenu_menu "Main Test Menu" \
            "menu" "🗂️  Menu Mode Tests" \
            "msgbox" "💬 Message Box Tests" \
            "yesno" "❓ Yes/No Dialog Tests" \
            "input" "⌨️  Input Box Tests" \
            "exit" "Exit Test Suite")
        
        local menu_result=$?
        
        if [[ $menu_result -ne 0 ]]; then
            # User cancelled
            clear
            log "INFO" "Exiting test suite..."
            exit 0
        fi
        
        # Route to appropriate submenu based on selection
        case "$menu_selection" in
            menu)
                submenu_menu_tests
                ;;
            msgbox)
                submenu_msgbox_tests
                ;;
            yesno)
                submenu_yesno_tests
                ;;
            input)
                submenu_input_tests
                ;;
            exit)
                clear
                log "INFO" "Exiting test suite..."
                exit 0
                ;;
        esac
    done
}

# ============================================================================
# ENVIRONMENT CHECK
# ============================================================================

if ! check_dtpmenu_deps; then
    log "ERROR" "Dependencies not met."
    log "ERROR" "Run: bash projects/dtpmenu/install_dtpmenu_deps.sh"
    exit 1
fi

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main_menu
