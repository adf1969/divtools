# dtpmenu - Return Values & Exit Codes

## Quick Summary

| Operation | Can Capture | How | Notes |
|-----------|-------------|-----|-------|
| **Exit Code** | ✅ YES | Check `$?` after call | Always available for all modes |
| **Menu Selection** | ❌ NO (during execution) | Dialog appears on screen | User interaction happens in TUI |
| **Yes/No Decision** | ✅ YES | Check `$?` (0=Yes, 1=No) | Perfect for decision dialogs |
| **User Input** | ⚠️ PARTIAL | Direct execution only | Typed into TUI, visible to user |
| **Message** | N/A | Message only | No return value needed |

---

## Exit Codes (Always Available)

All dtpmenu functions set the exit code:

### Exit Code 0 - Success
- User made a selection (menu, yesno, inputbox)
- User clicked OK (msgbox)
- Operation completed successfully

### Exit Code 1 - Cancel/Error
- User clicked Cancel
- Dialog was closed without action
- Dependencies missing or error occurred

### Exit Code 127 - Critical Error
- Dependencies not found
- Python venv missing
- Textual library not installed

**Capturing Exit Code:**
```bash
pmenu_yesno "Title" "Question?"
exit_code=$?

if [[ $exit_code -eq 0 ]]; then
    echo "User said YES"
elif [[ $exit_code -eq 1 ]]; then
    echo "User said NO"
elif [[ $exit_code -eq 127 ]]; then
    echo "CRITICAL: dtpmenu dependencies not found"
fi
```

---

## Mode-Specific Return Behavior

### Mode: MENU
```bash
pmenu_menu "Select Option" "a" "Apple" "b" "Banana" "c" "Cherry"
```

**Returns:**
- Exit code 0: Selection was made
- Exit code 1: User cancelled

**Output (if selection made):**
- Selected tag is printed to stdout
- Example: User selects "Banana" → prints `b`

**Capturing the Selection:**
❌ **WRONG** - Breaks centering:
```bash
choice=$(pmenu_menu "Title" "a" "Apple" "b" "Banana")
```

✅ **CORRECT** - Direct execution:
```bash
pmenu_menu "Select Option" "a" "Apple" "b" "Banana" "c" "Cherry"
if [[ $? -eq 0 ]]; then
    echo "User selected an option"
else
    echo "User cancelled"
fi
```

⚠️ **ADVANCED** - If you absolutely must capture output:
```bash
# This is a workaround - not recommended for normal use
# Write your own wrapper that uses --output-file flag (requires dtpmenu.py modification)
RESULT_FILE="/tmp/dtpmenu_result_$$.txt"
pmenu_menu "Title" "a" "Apple" "b" "Banana" > "$RESULT_FILE"
# Read result after TUI exits (not during execution)
selection=$(cat "$RESULT_FILE")
rm "$RESULT_FILE"
```

### Mode: MESSAGE BOX
```bash
pmenu_msgbox "Notification" "Operation completed successfully"
```

**Returns:**
- Exit code 0: OK button clicked
- Exit code 1: Dialog closed without action

**Output:**
- None (informational only)

**Pattern:**
```bash
pmenu_msgbox "Success" "File saved to /home/user/document.txt"
if [[ $? -eq 0 ]]; then
    echo "User acknowledged the message"
fi
```

### Mode: YES/NO DIALOG
```bash
pmenu_yesno "Confirm Action" "Delete this file permanently?"
```

**Returns:**
- Exit code 0: User clicked "Yes"
- Exit code 1: User clicked "No"

**Output:**
- None (decision determined by exit code)

**Pattern 1 - Inline Decision:**
```bash
if pmenu_yesno "Confirm" "Delete file?"; then
    rm /path/to/file
    pmenu_msgbox "Success" "File deleted"
else
    pmenu_msgbox "Cancelled" "File was not deleted"
fi
```

**Pattern 2 - Store Decision for Later:**
```bash
pmenu_yesno "Backup" "Create backup?"
user_confirmed=$?

# Do other work here...

if [[ $user_confirmed -eq 0 ]]; then
    perform_backup
fi
```

**Pattern 3 - Loop Until Confirmation:**
```bash
while true; do
    pmenu_yesno "Warning" "This will delete everything. Are you sure?"
    if [[ $? -eq 0 ]]; then
        # Double confirmation
        pmenu_yesno "Final Warning" "This is permanent. Absolutely sure?"
        if [[ $? -eq 0 ]]; then
            delete_everything
            break
        fi
    else
        echo "Cancelled"
        break
    fi
done
```

### Mode: INPUT BOX
```bash
pmenu_inputbox "Setup" "Enter your name:" "DefaultName"
```

**Returns:**
- Exit code 0: User clicked "OK" (input captured in TUI)
- Exit code 1: User clicked "Cancel"

**Output:**
- User-entered text is printed to stdout during TUI execution
- Text is visible on screen as user types

**Pattern 1 - Acknowledge Input:**
```bash
pmenu_inputbox "Configuration" "Enter hostname:" "localhost"
if [[ $? -eq 0 ]]; then
    pmenu_msgbox "Saved" "Hostname configuration saved"
else
    pmenu_msgbox "Cancelled" "Configuration not saved"
fi
```

**Pattern 2 - Store Interaction Result:**
```bash
pmenu_inputbox "Account" "Enter username:" "admin"
input_result=$?

if [[ $input_result -eq 0 ]]; then
    # User confirmed input (was typed in TUI)
    echo "User provided input"
else
    # User cancelled
    echo "User cancelled input"
fi
```

**NOTE ON INPUT CAPTURE:**
Unlike menu selections, user input in inputbox is visible on-screen during typing. To capture the actual typed text programmatically (rather than just knowing if user clicked OK), you would need to modify dtpmenu.py to support an `--output-file` flag that writes the result to a file after dialog closes.

---

## Chaining Multiple Dialogs

### Pattern: Menu → Action → Confirmation
```bash
#!/bin/bash
source "$DIVTOOLS/scripts/util/dt_pmenu_lib.sh"
export PMENU_H_CENTER=1 PMENU_V_CENTER=1

# Main menu
pmenu_menu "System Manager" \
    "backup" "Create Backup" \
    "restore" "Restore From Backup" \
    "settings" "Configure Settings" \
    "exit" "Exit"

menu_result=$?

if [[ $menu_result -eq 0 ]]; then
    # User made a selection (menu printed the tag)
    
    # Show confirmation based on selection
    pmenu_yesno "Confirm Action" "Proceed with operation?"
    if [[ $? -eq 0 ]]; then
        pmenu_msgbox "Success" "Operation completed"
    else
        pmenu_msgbox "Cancelled" "Operation was not performed"
    fi
else
    # User cancelled menu
    pmenu_msgbox "Exit" "Exiting system manager"
fi
```

### Pattern: Input → Validation → Confirmation
```bash
#!/bin/bash
source "$DIVTOOLS/scripts/util/dt_pmenu_lib.sh"
export PMENU_H_CENTER=1 PMENU_V_CENTER=1

# Get user input
pmenu_inputbox "Account Setup" "Enter new username:" "newuser"
input_status=$?

if [[ $input_status -eq 0 ]]; then
    # User provided input
    
    # Confirm the choice
    pmenu_yesno "Confirm" "Create account with this username?"
    if [[ $? -eq 0 ]]; then
        pmenu_msgbox "Success" "Account created successfully"
    else
        # Go back to input
        pmenu_msgbox "Cancelled" "Please try again"
    fi
else
    pmenu_msgbox "Error" "Username entry cancelled"
fi
```

---

## Real-World Examples

### Example 1: System Administration Menu
```bash
#!/bin/bash
source "$DIVTOOLS/scripts/util/dt_pmenu_lib.sh"
export PMENU_H_CENTER=1 PMENU_V_CENTER=1

main_menu() {
    while true; do
        pmenu_menu "System Manager" \
            "users" "Manage Users" \
            "services" "Manage Services" \
            "logs" "View System Logs" \
            "exit" "Exit"
        
        # Check if user made a selection
        if [[ $? -ne 0 ]]; then
            break  # User cancelled
        fi
    done
    
    pmenu_msgbox "Goodbye" "Exiting system manager"
}

main_menu
```

### Example 2: Destructive Operation Warning
```bash
#!/bin/bash
source "$DIVTOOLS/scripts/util/dt_pmenu_lib.sh"
export PMENU_H_CENTER=1 PMENU_V_CENTER=1

delete_user_account() {
    local username="$1"
    
    # First confirmation
    pmenu_yesno "Warning" "Delete account: $username?"
    [[ $? -ne 0 ]] && return 1
    
    # Second confirmation
    pmenu_yesno "FINAL WARNING" "This cannot be undone. Are you absolutely sure?"
    [[ $? -ne 0 ]] && return 1
    
    # Proceed with deletion
    userdel -r "$username"
    pmenu_msgbox "Success" "Account $username has been deleted"
    return 0
}

# Main script
pmenu_yesno "Account Deletion" "Delete a user account?"
if [[ $? -eq 0 ]]; then
    pmenu_inputbox "Enter Username" "Which account to delete?" "testuser"
    if [[ $? -eq 0 ]]; then
        # User provided username (visible in TUI)
        # In real script, you'd parse the input differently
        delete_user_account "testuser"
    fi
fi
```

### Example 3: Configuration Wizard
```bash
#!/bin/bash
source "$DIVTOOLS/scripts/util/dt_pmenu_lib.sh"
export PMENU_H_CENTER=1 PMENU_V_CENTER=1

setup_wizard() {
    pmenu_msgbox "Welcome" "System Configuration Wizard"
    
    # Network configuration
    pmenu_yesno "Network" "Configure network settings?"
    if [[ $? -eq 0 ]]; then
        pmenu_inputbox "Hostname" "Enter hostname:" "localhost"
        # User types hostname in TUI
        pmenu_msgbox "Network" "Network configuration saved"
    fi
    
    # User creation
    pmenu_yesno "Users" "Create new user account?"
    if [[ $? -eq 0 ]]; then
        pmenu_inputbox "Username" "Enter username:" "newuser"
        # User types username in TUI
        pmenu_msgbox "Users" "User account created"
    fi
    
    # Final confirmation
    pmenu_yesno "Complete" "Configuration complete. Apply changes?"
    if [[ $? -eq 0 ]]; then
        pmenu_msgbox "Success" "System configured successfully"
    else
        pmenu_msgbox "Cancelled" "Changes were not applied"
    fi
}

setup_wizard
```

---

## Important Notes on Return Values

1. **Exit codes are always captured** - Use `$?` immediately after calling dtpmenu function
2. **Menu selection output requires special handling** - Cannot use standard command substitution without breaking centering
3. **Yes/No is most reliable** - Exit code directly maps to user choice
4. **Message boxes are informational** - No decision is being made, just acknowledgement
5. **Input boxes require workaround** - Would need dtpmenu.py `--output-file` feature for programmatic text capture
6. **Never use pipes or redirection** - These break Textual's terminal control

---

## Testing Exit Codes

```bash
#!/bin/bash
source "$DIVTOOLS/scripts/util/dt_pmenu_lib.sh"
export PMENU_H_CENTER=1 PMENU_V_CENTER=1

# Test each exit code scenario
echo "Testing pmenu_yesno exit codes..."

pmenu_yesno "Test" "Click YES"
echo "Exit code (should be 0): $?"

pmenu_yesno "Test" "Click NO"
echo "Exit code (should be 1): $?"

# Test menu selection
echo -e "\nTesting pmenu_menu exit codes..."

pmenu_menu "Test Menu" "a" "Option A" "b" "Option B"
echo "Exit code (should be 0 if selected, 1 if cancelled): $?"
```
