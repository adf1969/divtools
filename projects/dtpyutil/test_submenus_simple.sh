#!/bin/bash
# test_submenus_simple.sh - Simple submenu test with centered dialogs
# Last Updated: 01/14/2026 6:31:00 PM CDT

export DIVTOOLS="${DIVTOOLS:-/opt/divtools}"
source "$DIVTOOLS/projects/dtpyutil/src/dtpyutil/menu/bash_wrapper.sh"

# Enable centering
export PMENU_H_CENTER=1
export PMENU_V_CENTER=1

echo "=== dtpyutil Menu Test Suite ==="
echo ""

# Test Menu Dialog with output
test_menu_with_output() {
    echo "Running: Menu Dialog with Output"
    pmenu_menu "Select Fruit" \
        "apple" "🍎 Apple" \
        "banana" "🍌 Banana" \
        "orange" "🍊 Orange" \
        "grape" "🍇 Grape"
    echo "Menu returned: $?"
    echo ""
}

# Test Menu Dialog silent
test_menu_silent() {
    echo "Running: Menu Dialog (silent)"
    pmenu_menu "Select Fruit" \
        "apple" "🍎 Apple" \
        "banana" "🍌 Banana" \
        "orange" "🍊 Orange" \
        "grape" "🍇 Grape"
    # No output - silent mode
}

# Test InputBox with output
test_inputbox_with_output() {
    echo "Running: Input Box with Output"
    pmenu_inputbox "Your Information" "Enter your name:" "John Doe"
    echo "InputBox returned: $?"
    echo ""
}

# Test InputBox silent
test_inputbox_silent() {
    echo "Running: Input Box (silent)"
    pmenu_inputbox "Your Information" "Enter your name:" "John Doe"
    # No output - silent mode
}

# Test MsgBox with output
test_msgbox_with_output() {
    echo "Running: Message Box with Output"
    pmenu_msgbox "Information" "This is a message box.\n\nIt displays information and requires acknowledgment.\n\nClick OK to continue."
    echo "MsgBox returned: $?"
    echo ""
}

# Test MsgBox silent
test_msgbox_silent() {
    echo "Running: Message Box (silent)"
    pmenu_msgbox "Information" "This is a message box.\n\nIt displays information and requires acknowledgment.\n\nClick OK to continue."
    # No output - silent mode
}

# Test YesNo with output
test_yesno_with_output() {
    echo "Running: Yes/No Dialog with Output"
    pmenu_yesno "Confirmation" "Do you want to proceed?"
    local result=$?
    echo "YesNo returned: $result (0=Yes, 1=No)"
    echo ""
}

# Test YesNo silent
test_yesno_silent() {
    echo "Running: Yes/No Dialog (silent)"
    pmenu_yesno "Confirmation" "Do you want to proceed?"
    # No output - silent mode
}

# Submenu for Menu Dialog tests
menu_tests_submenu() {
    while true; do
        echo ""
        echo "=== Menu Dialog Tests ==="
        
        # Direct call - NO command substitution!
        pmenu_menu "Menu Dialog Tests" \
            "output" "✏️ With Output" \
            "silent" "🤐 Silent Mode" \
            "back" "◀️ Back to Main Menu"
        
        case "$?" in
            1)
                # User cancelled or escaped
                break
                ;;
            0)
                # Menu was accepted - but we need to capture output file
                # The pmenu_menu wrote to PMENU_OUTPUT_FILE
                if [[ -f "$PMENU_OUTPUT_FILE" ]]; then
                    local choice=$(cat "$PMENU_OUTPUT_FILE")
                    rm -f "$PMENU_OUTPUT_FILE"
                    
                    case "$choice" in
                        "output")
                            test_menu_with_output
                            ;;
                        "silent")
                            test_menu_silent
                            echo "Menu test complete (silent mode)"
                            echo ""
                            ;;
                        "back")
                            break
                            ;;
                    esac
                fi
                ;;
        esac
    done
}

# Submenu for Input Box tests
input_tests_submenu() {
    while true; do
        echo ""
        echo "=== Input Box Tests ==="
        
        # Direct call - NO command substitution!
        pmenu_menu "Input Box Tests" \
            "output" "✏️ With Output" \
            "silent" "🤐 Silent Mode" \
            "back" "◀️ Back to Main Menu"
        
        case "$?" in
            1)
                break
                ;;
            0)
                if [[ -f "$PMENU_OUTPUT_FILE" ]]; then
                    local choice=$(cat "$PMENU_OUTPUT_FILE")
                    rm -f "$PMENU_OUTPUT_FILE"
                    
                    case "$choice" in
                        "output")
                            test_inputbox_with_output
                            ;;
                        "silent")
                            test_inputbox_silent
                            echo "Input box test complete (silent mode)"
                            echo ""
                            ;;
                        "back")
                            break
                            ;;
                    esac
                fi
                ;;
        esac
    done
}

# Submenu for Message Box tests
msg_tests_submenu() {
    while true; do
        echo ""
        echo "=== Message Box Tests ==="
        
        # Direct call - NO command substitution!
        pmenu_menu "Message Box Tests" \
            "output" "✏️ With Output" \
            "silent" "🤐 Silent Mode" \
            "back" "◀️ Back to Main Menu"
        
        case "$?" in
            1)
                break
                ;;
            0)
                if [[ -f "$PMENU_OUTPUT_FILE" ]]; then
                    local choice=$(cat "$PMENU_OUTPUT_FILE")
                    rm -f "$PMENU_OUTPUT_FILE"
                    
                    case "$choice" in
                        "output")
                            test_msgbox_with_output
                            ;;
                        "silent")
                            test_msgbox_silent
                            echo "Message box test complete (silent mode)"
                            echo ""
                            ;;
                        "back")
                            break
                            ;;
                    esac
                fi
                ;;
        esac
    done
}

# Submenu for Yes/No Dialog tests
yesno_tests_submenu() {
    while true; do
        echo ""
        echo "=== Yes/No Dialog Tests ==="
        
        # Direct call - NO command substitution!
        pmenu_menu "Yes/No Dialog Tests" \
            "output" "✏️ With Output" \
            "silent" "🤐 Silent Mode" \
            "back" "◀️ Back to Main Menu"
        
        case "$?" in
            1)
                break
                ;;
            0)
                if [[ -f "$PMENU_OUTPUT_FILE" ]]; then
                    local choice=$(cat "$PMENU_OUTPUT_FILE")
                    rm -f "$PMENU_OUTPUT_FILE"
                    
                    case "$choice" in
                        "output")
                            test_yesno_with_output
                            ;;
                        "silent")
                            test_yesno_silent
                            echo "Yes/No dialog test complete (silent mode)"
                            echo ""
                            ;;
                        "back")
                            break
                            ;;
                    esac
                fi
                ;;
        esac
    done
}

# Main menu loop - NO command substitution!
while true; do
    echo ""
    
    # Direct call - result goes to file, NOT command substitution!
    pmenu_menu "Test Suite Main Menu" \
        "menu" "📋 Menu Dialog Tests" \
        "input" "📝 Input Box Tests" \
        "msg" "ℹ️ Message Box Tests" \
        "yesno" "🤔 Yes/No Dialog Tests" \
        "exit" "❌ Exit"
    
    if [[ $? -ne 0 ]]; then
        echo "Test aborted"
        exit 1
    fi
    
    # Read the choice from the output file created by bash_wrapper.sh
    if [[ -f "$PMENU_OUTPUT_FILE" ]]; then
        choice=$(cat "$PMENU_OUTPUT_FILE")
        rm -f "$PMENU_OUTPUT_FILE"
        
        case "$choice" in
            "menu")
                menu_tests_submenu
                ;;
            "input")
                input_tests_submenu
                ;;
            "msg")
                msg_tests_submenu
                ;;
            "yesno")
                yesno_tests_submenu
                ;;
            "exit")
                echo "Exiting test suite"
                break
                ;;
        esac
    fi
done

echo ""
echo "=== Test Suite Complete ==="

