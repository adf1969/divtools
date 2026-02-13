#!/bin/bash
# example_real_world_usage.sh - Practical Examples of Using dtpmenu in Bash
# Shows patterns for real-world applications
# Last Updated: 01/14/2026 04:05:00 AM CDT

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "$DIVTOOLS" ] && export DIVTOOLS="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$DIVTOOLS/scripts/util/dt_pmenu_lib.sh"
source "$DIVTOOLS/scripts/util/logging.sh"

# Configuration
export PMENU_H_CENTER=1
export PMENU_V_CENTER=1

# ============================================================================
# EXAMPLE 1: Simple User Confirmation
# ============================================================================

example_simple_confirmation() {
    log "HEAD" "EXAMPLE 1: Simple Confirmation Dialog"
    
    # Simple pattern: Use if statement with exit code
    if pmenu_yesno "Confirm Action" "Do you want to delete the backup file?"; then
        log "INFO" "User confirmed - would delete backup"
        # perform_delete_backup
    else
        log "INFO" "User declined - backup preserved"
    fi
}

# ============================================================================
# EXAMPLE 2: User Selection with Branching
# ============================================================================

example_selection_with_branching() {
    log "HEAD" "EXAMPLE 2: User Selection with Branching"
    
    # Menu shows options, user selects something
    pmenu_menu "Select Operation" \
        "create" "🆕 Create New Item" \
        "edit" "✏️  Edit Existing Item" \
        "delete" "🗑️  Delete Item" \
        "backup" "💾 Backup All Items"
    
    local menu_result=$?
    
    # After TUI closes, we can check if selection was made
    if [[ $menu_result -eq 0 ]]; then
        log "INFO" "✅ User selected an option (exit code 0)"
        # For capturing WHICH option was selected, you would need:
        # 1. A more complex workflow (separate TUI executions for each option)
        # 2. Or modify dtpmenu to support --output-file flag
    else
        log "INFO" "ℹ️  User cancelled menu (exit code 1)"
    fi
}

# ============================================================================
# EXAMPLE 3: Destructive Operation with Double-Confirmation
# ============================================================================

example_destructive_operation() {
    log "HEAD" "EXAMPLE 3: Destructive Operation (Double-Confirmation)"
    
    # First confirmation
    if ! pmenu_yesno "Warning" "Delete all data in this volume?"; then
        log "INFO" "User cancelled at first confirmation"
        return
    fi
    
    # Second confirmation (for critical operations)
    pmenu_msgbox "WARNING" "This action CANNOT be undone!\\n\\nYou are about to permanently delete all data."
    
    if ! pmenu_yesno "FINAL CONFIRMATION" "Are you absolutely certain you want to proceed?"; then
        log "INFO" "User cancelled at final confirmation"
        return
    fi
    
    log "SUCCESS" "✅ Double confirmation passed"
    log "INFO" "Would execute: DELETE ENTIRE VOLUME"
}

# ============================================================================
# EXAMPLE 4: Multi-Step Configuration Wizard
# ============================================================================

example_configuration_wizard() {
    log "HEAD" "EXAMPLE 4: Configuration Wizard (Multi-Step)"
    
    # Step 1: Confirm wizard start
    pmenu_msgbox "Setup Wizard" "This wizard will guide you through system setup.\\n\\nClick OK to continue."
    
    # Step 2: Ask about network
    if pmenu_yesno "Network" "Configure network settings now?"; then
        pmenu_msgbox "Network Config" "Network configuration skipped for this example."
        # network_config
    fi
    
    # Step 3: Ask about users
    if pmenu_yesno "User Management" "Create new user accounts?"; then
        pmenu_msgbox "User Setup" "User account creation skipped for this example."
        # create_users
    fi
    
    # Step 4: Final confirmation
    if pmenu_yesno "Complete" "Apply all configuration changes?"; then
        pmenu_msgbox "Success" "System configuration completed successfully!"
        log "SUCCESS" "✅ Setup wizard completed"
    else
        pmenu_msgbox "Cancelled" "Setup was cancelled - no changes applied"
        log "INFO" "User cancelled configuration"
    fi
}

# ============================================================================
# EXAMPLE 5: Error Handling with User Notification
# ============================================================================

example_error_handling() {
    log "HEAD" "EXAMPLE 5: Error Handling with User Notification"
    
    # Simulate an operation that might fail
    local operation_result=1  # Pretend it failed
    
    if [[ $operation_result -ne 0 ]]; then
        # Show error to user
        pmenu_msgbox "Error" "The operation failed due to insufficient disk space.\\n\\nPlease free up some space and try again."
        
        # Ask if they want to retry
        if pmenu_yesno "Retry?" "Do you want to try the operation again?"; then
            log "INFO" "User chose to retry"
            # retry_operation
        else
            log "INFO" "User declined retry"
        fi
    fi
}

# ============================================================================
# EXAMPLE 6: Conditional Branching Based on User Decision
# ============================================================================

example_conditional_branching() {
    log "HEAD" "EXAMPLE 6: Conditional Branching"
    
    # Check if user wants verbose logging
    local verbose_mode=0
    if pmenu_yesno "Settings" "Enable verbose logging?"; then
        verbose_mode=1
    fi
    
    log "DEBUG" "Verbose mode: $verbose_mode"
    
    # Check if user wants to proceed with operation
    local proceed=0
    if pmenu_yesno "Execute" "Proceed with the operation?"; then
        proceed=1
    fi
    
    if [[ $proceed -eq 1 ]]; then
        if [[ $verbose_mode -eq 1 ]]; then
            log "INFO" "Would execute with verbose output"
        else
            log "INFO" "Would execute in normal mode"
        fi
    else
        log "INFO" "Operation cancelled"
    fi
}

# ============================================================================
# EXAMPLE 7: Loop Until User Cancels
# ============================================================================

example_menu_loop() {
    log "HEAD" "EXAMPLE 7: Menu Loop Until User Cancels"
    
    local iteration=0
    while true; do
        ((iteration++))
        
        if ! pmenu_yesno "Continue?" "Iteration $iteration - Continue looping?"; then
            log "INFO" "User cancelled after $iteration iterations"
            break
        fi
        
        log "INFO" "Iteration $iteration - proceeding"
    done
}

# ============================================================================
# EXAMPLE 8: Batch Operations with Progress Feedback
# ============================================================================

example_batch_with_confirmation() {
    log "HEAD" "EXAMPLE 8: Batch Operations with Confirmation"
    
    # Ask which items to process
    pmenu_msgbox "Batch Processing" "This will process 5 files.\\n\\nEach file will require confirmation."
    
    local process_all=0
    if pmenu_yesno "Batch Mode" "Process all files without confirmation?"; then
        process_all=1
    fi
    
    # Simulate processing files
    for i in {1..3}; do
        log "INFO" "Processing file $i..."
        
        if [[ $process_all -ne 1 ]]; then
            if ! pmenu_yesno "Confirm" "Process file $i?"; then
                log "INFO" "Skipping file $i"
                continue
            fi
        fi
        
        log "SUCCESS" "✅ File $i processed"
    done
    
    pmenu_msgbox "Complete" "Batch processing finished!"
}

# ============================================================================
# MENU: SELECT WHICH EXAMPLE TO RUN
# ============================================================================

select_example() {
    while true; do
        pmenu_menu "Select Example to Run" \
            "1" "Simple Confirmation Dialog" \
            "2" "User Selection with Branching" \
            "3" "Destructive Operation (Double-Confirmation)" \
            "4" "Configuration Wizard (Multi-Step)" \
            "5" "Error Handling & Retry" \
            "6" "Conditional Branching" \
            "7" "Menu Loop Until User Cancels" \
            "8" "Batch Operations with Confirmation" \
            "exit" "Exit Examples"
        
        if [[ $? -ne 0 ]]; then
            # User cancelled - exit
            break
        fi
        
        # Note: Since we can't easily capture menu selection without output redirection,
        # the examples are run with a simpler approach.
        # For production, you might use separate scripts per option.
    done
}

# ============================================================================
# MAIN: RUN ALL EXAMPLES IN SEQUENCE
# ============================================================================

main() {
    clear
    log "HEAD" "DTPMENU - Real-World Usage Examples"
    log "INFO" "These examples demonstrate practical patterns for using dtpmenu"
    log "INFO" "in bash scripts with proper return value handling."
    log "INFO" ""
    
    # Check dependencies
    if ! check_dtpmenu_deps; then
        log "ERROR" "Dependencies not found"
        exit 1
    fi
    
    read -p "Press Enter to run all examples in sequence..."
    
    # Run examples
    clear && example_simple_confirmation && read -p "Press Enter for next example..."
    clear && example_selection_with_branching && read -p "Press Enter for next example..."
    clear && example_destructive_operation && read -p "Press Enter for next example..."
    clear && example_configuration_wizard && read -p "Press Enter for next example..."
    clear && example_error_handling && read -p "Press Enter for next example..."
    clear && example_conditional_branching && read -p "Press Enter for next example..."
    clear && example_menu_loop && read -p "Press Enter for next example..."
    clear && example_batch_with_confirmation && read -p "Press Enter to finish..."
    
    clear
    log "HEAD" "All Examples Completed"
    log "SUCCESS" "✅ You have seen 8 practical usage patterns for dtpmenu"
    log "INFO" ""
    log "INFO" "Key Takeaway:"
    log "INFO" "dtpmenu IS fully usable from bash and DOES return proper exit codes"
}

main "$@"
