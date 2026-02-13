#!/bin/bash
# test_bash_integration.sh - Test dtpyutil menu system with file-based IPC
# Last Updated: 01/14/2026 6:00:00 PM CDT

# Set DIVTOOLS if not set
export DIVTOOLS="${DIVTOOLS:-/opt/divtools}"

# Source the bash wrapper
source "$DIVTOOLS/projects/dtpyutil/src/dtpyutil/menu/bash_wrapper.sh"

# Enable centering
export PMENU_H_CENTER=1
export PMENU_V_CENTER=1

# Global result variable for use between functions
MENU_RESULT=""

echo "=== Testing dtpyutil Menu System ==="
echo ""

# Test function for Fruit submenu
test_fruit_submenu() {
    echo "✅ User selected: Fruit - Testing Fruit Submenu"
    echo ""
    
    # Show message box (direct call, no command substitution)
    echo "Displaying fruit selection message..."
    pmenu_msgbox "Fruit Selection" "You selected the Fruit option.\n\nThis demonstrates the MsgBox dialog mode.\n\nClick OK to continue to fruit selection menu."
    
    # Show fruit choice menu (direct call, no command substitution)
    echo ""
    echo "Displaying fruit choice menu..."
    pmenu_menu "Choose a Fruit" \
        "apple" "🍎 Apple" \
        "banana" "🍌 Banana" \
        "cherry" "🍒 Cherry" \
        "back" "◀️ Back to Main Menu"
    
    local fruit_result=$?
    echo "Fruit menu returned with exit code: $fruit_result"
}

# Test function for Registration submenu  
test_registration_submenu() {
    echo "✅ User selected: Registration - Testing Registration Flow"
    echo ""
    
    # Get username via input box (direct call, no command substitution)
    echo "Step 1: Enter username"
    pmenu_inputbox "User Registration" "Enter username:" "admin"
    local user_result=$?
    echo "Username input returned with exit code: $user_result"
    
    if [[ $user_result -ne 0 ]]; then
        echo "❌ Registration cancelled by user"
        return 1
    fi
    
    echo ""
    
    # Get email via input box (direct call, no command substitution)
    echo "Step 2: Enter email"
    pmenu_inputbox "User Registration" "Enter email address:" "user@example.com"
    local email_result=$?
    echo "Email input returned with exit code: $email_result"
    
    if [[ $email_result -ne 0 ]]; then
        echo "❌ Registration cancelled by user"
        return 1
    fi
    
    echo ""
    
    # Confirm registration (direct call, no command substitution)
    echo "Step 3: Confirm registration details"
    pmenu_yesno "Confirm Registration" "Create account with the provided details?\n\nClick YES to confirm or NO to cancel."
    local confirm_result=$?
    
    if [[ $confirm_result -eq 0 ]]; then
        echo "✅ Registration confirmed"
        echo ""
        echo "Displaying success message..."
        pmenu_msgbox "Success" "Account created successfully!"
        echo "✅ Success message displayed"
    else
        echo "❌ Registration cancelled by user at confirmation step"
        return 1
    fi
}

# Main loop
while true; do
    echo ""
    echo "Test 1: Main Menu (with centering)"
    choice=$(pmenu_menu "Main Menu" \
        "fruit" "🍎 Choose a Fruit" \
        "reg" "📝 User Registration" \
        "yesno" "🤔 YesNo Dialog Test" \
        "inputbox" "📝 InputBox Dialog Test" \
        "msgbox" "ℹ️ Message Box Test" \
        "exit" "❌ Exit")
    
    exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        echo "❌ Menu cancelled"
        exit 1
    fi
    
    echo "✅ Main menu returned: $choice"
    
    # Branch based on user selection
    case "$choice" in
        "exit")
            echo "✅ User selected: Exit - Test Complete"
            exit 0
            ;;
        "fruit")
            echo "Calling test_fruit_submenu function..."
            test_fruit_submenu
            local submenu_exit=$?
            echo "Submenu returned exit code: $submenu_exit"
            ;;
        "reg")
            echo "Calling test_registration_submenu function..."
            test_registration_submenu
            local submenu_exit=$?
            echo "Submenu returned exit code: $submenu_exit"
            ;;
        "yesno")
            echo "✅ Testing YesNo Dialog"
            pmenu_yesno "Confirmation" "Do you want to continue testing?"
            if [[ $? -eq 0 ]]; then
                echo "✅ User clicked Yes"
            else
                echo "✅ User clicked No"
            fi
            ;;
        "inputbox")
            echo "✅ Testing InputBox Dialog"
            user_input=$(pmenu_inputbox "Test InputBox" "Enter your name:" "John Doe")
            if [[ $? -eq 0 ]]; then
                echo "✅ InputBox returned: $user_input"
            else
                echo "❌ InputBox cancelled"
            fi
            ;;
        "msgbox")
            echo "✅ Testing Message Box"
            pmenu_msgbox "Information" "This is a message box.\n\nIt displays information and requires user acknowledgment.\n\nClick OK to continue."
            if [[ $? -eq 0 ]]; then
                echo "✅ Message box completed"
            fi
            ;;
        *)
            echo "❌ Unknown selection: $choice"
            ;;
    esac
    
    # Ask if user wants to continue testing
    echo ""
    pmenu_yesno "Continue Testing?" "Would you like to test another menu?"
    if [[ $? -ne 0 ]]; then
        echo "✅ Test session ended by user"
        break
    fi
done

echo ""
echo "=== All tests complete ==="

