#!/bin/bash
# Gum Utility Functions for Divtools
# Last Updated: 01/13/2026 10:58:00 AM CDT
#
# Complete menu system using Charm's gum utility
# Requires: gum v0.17.0+ (install with scripts/charm/gum_install.sh)

# Default color scheme (Cyan background theme)
GUM_HEADER_FG="${GUM_HEADER_FG:-255}"      # White header text
GUM_HEADER_BG="${GUM_HEADER_BG:-51}"       # Cyan header background
GUM_SELECTED_FG="${GUM_SELECTED_FG:-255}"  # White selected text
GUM_SELECTED_BG="${GUM_SELECTED_BG:-51}"   # Cyan selected background
GUM_ITEM_FG="${GUM_ITEM_FG:-250}"          # Light gray unselected text
GUM_BORDER_FG="${GUM_BORDER_FG:-51}"       # Cyan border

# Check if gum is available
check_gum_available() {
    if ! command -v gum &>/dev/null; then
        return 1
    fi
    return 0
}

# Show installation instructions
show_gum_install_instructions() {
    cat << 'EOF'
ERROR: The 'gum' command is not installed.

To install gum:
    /home/divix/divtools/scripts/charm/gum_install.sh

EOF
}

# Set custom color scheme
# Usage: set_gum_colors HEADER_FG HEADER_BG SELECTED_FG SELECTED_BG ITEM_FG BORDER_FG
set_gum_colors() {
    [[ -n "$1" ]] && GUM_HEADER_FG="$1"
    [[ -n "$2" ]] && GUM_HEADER_BG="$2"
    [[ -n "$3" ]] && GUM_SELECTED_FG="$3"
    [[ -n "$4" ]] && GUM_SELECTED_BG="$4"
    [[ -n "$5" ]] && GUM_ITEM_FG="$5"
    [[ -n "$6" ]] && GUM_BORDER_FG="$6"
}

# Display menu with arrow key selection
# Usage: choice=$(gum_menu "Title" "Description" "${menu_items[@]}")
# menu_items format: ("tag1" "desc1" "tag2" "desc2" ...)
# Empty tag = section header (not selectable)
# Returns: selected tag on stdout, exit code 1 on ESC
gum_menu() {
    local title="$1"
    local description="$2"
    shift 2
    local -a menu_items=("$@")
    
    # Build numbered display items
    local -a display_items=()
    local -a display_debug=()
    local -a return_tags=()
    local item_num=1
    local line_num=0
    local total_lines=0
    
    for ((i=0; i<${#menu_items[@]}; i+=2)); do
        local tag="${menu_items[i]}"
        local desc="${menu_items[i+1]}"
        
        if [[ -z "$tag" ]]; then
            # Section header (not selectable)
            display_items+=("$desc")
            display_debug+=("[$(printf '%3d' $line_num)] $desc")
            return_tags+=("")
            ((total_lines++))
            ((line_num++))
        else
            # Regular menu item with number
            display_items+=("$item_num) $desc")
            display_debug+=("[$(printf '%3d' $line_num)] $item_num) $desc")
            return_tags+=("$tag")
            ((item_num++))
            ((total_lines++))
            ((line_num++))
        fi
    done
    
    # Build title with line count if DEBUG
    local full_title="$title"
    if [[ "${DEBUG_MODE:-0}" == "1" ]]; then
        full_title="$title ($total_lines lines)"
    fi
    
    # Display header box
    clear
    echo ""
    echo "$full_title" | gum style \
        --border double \
        --padding "0 2" \
        --foreground "$GUM_HEADER_FG" \
        --background "$GUM_HEADER_BG" \
        --border-foreground "$GUM_BORDER_FG" \
        --align center \
        --width 80
    
    if [[ -n "$description" ]]; then
        echo "$description" | gum style \
            --border rounded \
            --padding "0 2" \
            --foreground 250 \
            --border-foreground "$GUM_BORDER_FG" \
            --width 80
    fi
    
    # Choose which items array to display (debug or normal)
    local -a items_to_display=()
    if [[ "${DEBUG_MODE:-0}" == "1" ]]; then
        items_to_display=("${display_debug[@]}")
    else
        items_to_display=("${display_items[@]}")
    fi
    
    # Display menu
    # Note: Removed static box as it confuses the interactive display
    
    # Now run the interactive selection
    local selected
    selected=$(gum choose \
        --cursor "> " \
        --cursor.foreground "$GUM_SELECTED_FG" \
        --cursor.background "$GUM_SELECTED_BG" \
        --selected.foreground "$GUM_SELECTED_FG" \
        --selected.background "$GUM_SELECTED_BG" \
        --item.foreground "$GUM_ITEM_FG" \
        --header "Select an option:" \
        "${items_to_display[@]}")
    
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]] || [[ -z "$selected" ]]; then
        return 1
    fi
    
    # Extract the actual display item (remove debug line numbers if present)
    local search_item="$selected"
    if [[ "${DEBUG_MODE:-0}" == "1" ]]; then
        # Remove debug prefix: "[NNN] " to get the actual item
        search_item="${selected#\[*\] }"
    fi
    
    # Try to find matching tag by display item
    for ((i=0; i<${#display_items[@]}; i++)); do
        if [[ "${display_items[i]}" == "$search_item" ]]; then
            echo "${return_tags[i]}"
            return 0
        fi
    done
    
    return 1
}

# Display message box with OK button
# Usage: gum_msgbox "Title" "Message"
gum_msgbox() {
    local title="$1"
    local message="$2"
    
    clear
    echo ""
    echo "$title" | gum style \
        --border double \
        --padding "0 2" \
        --foreground "$GUM_HEADER_FG" \
        --background "$GUM_HEADER_BG" \
        --border-foreground "$GUM_BORDER_FG" \
        --align center \
        --width 80
    
    echo ""
    # Use printf to handle \n properly, wrap message at reasonable width
    printf '%b' "$message" | gum style \
        --border rounded \
        --padding "1 2" \
        --foreground 250 \
        --border-foreground "$GUM_BORDER_FG" \
        --width 80
    
    echo ""
    echo "[OK]" | gum choose \
        --cursor "> " \
        --cursor.foreground "$GUM_SELECTED_FG" \
        --cursor.background "$GUM_SELECTED_BG" \
        --item.foreground "$GUM_ITEM_FG" > /dev/null
    
    return 0
}

# Display yes/no confirmation
# Usage: if gum_yesno "Title" "Question"; then ...
# Returns: 0 for Yes, 1 for No/Cancel
gum_yesno() {
    local title="$1"
    local question="$2"
    
    clear
    echo ""
    echo "$title" | gum style \
        --border double \
        --padding "0 2" \
        --foreground "$GUM_HEADER_FG" \
        --background "$GUM_HEADER_BG" \
        --border-foreground "$GUM_BORDER_FG" \
        --align center \
        --width 80
    
    echo ""
    echo "$question" | gum style \
        --padding "1 2" \
        --foreground 250 \
        --width 80
    
    echo ""
    local choice
    choice=$(echo -e "[Yes]\n[No]" | gum choose \
        --cursor "> " \
        --cursor.foreground "$GUM_SELECTED_FG" \
        --cursor.background "$GUM_SELECTED_BG" \
        --selected.foreground "$GUM_SELECTED_FG" \
        --selected.background "$GUM_SELECTED_BG" \
        --item.foreground "$GUM_ITEM_FG")
    
    [[ "$choice" == "[Yes]" ]] && return 0 || return 1
}

# Display yes/no/cancel confirmation
# Usage: result=$(gum_yesnocancel "Title" "Question") # Returns: yes, no, or cancel
gum_yesnocancel() {
    local title="$1"
    local question="$2"
    
    clear
    echo ""
    echo "$title" | gum style \
        --border double \
        --padding "0 2" \
        --foreground "$GUM_HEADER_FG" \
        --background "$GUM_HEADER_BG" \
        --border-foreground "$GUM_BORDER_FG" \
        --align center \
        --width 80
    
    echo ""
    echo "$question" | gum style \
        --padding "1 2" \
        --foreground 250 \
        --width 80
    
    echo ""
    local choice
    choice=$(echo -e "[Yes]\n[No]\n[Cancel]" | gum choose \
        --cursor "> " \
        --cursor.foreground "$GUM_SELECTED_FG" \
        --cursor.background "$GUM_SELECTED_BG" \
        --selected.foreground "$GUM_SELECTED_FG" \
        --selected.background "$GUM_SELECTED_BG" \
        --item.foreground "$GUM_ITEM_FG")
    
    case "$choice" in
        "[Yes]") echo "yes" ;;
        "[No]") echo "no" ;;
        "[Cancel]") echo "cancel" ;;
    esac
}

# Display OK/Cancel confirmation
# Usage: if gum_okcancel "Title" "Message"; then ...
# Returns: 0 for OK, 1 for Cancel
gum_okcancel() {
    local title="$1"
    local message="$2"
    
    clear
    echo ""
    echo "$title" | gum style \
        --border double \
        --padding "0 2" \
        --foreground "$GUM_HEADER_FG" \
        --background "$GUM_HEADER_BG" \
        --border-foreground "$GUM_BORDER_FG" \
        --align center \
        --width 80
    
    echo ""
    printf '%b' "$message" | gum style \
        --padding "1 2" \
        --foreground 250 \
        --width 80
    
    echo ""
    local choice
    choice=$(echo -e "[OK]\n[Cancel]" | gum choose \
        --cursor "> " \
        --cursor.foreground "$GUM_SELECTED_FG" \
        --cursor.background "$GUM_SELECTED_BG" \
        --selected.foreground "$GUM_SELECTED_FG" \
        --selected.background "$GUM_SELECTED_BG" \
        --item.foreground "$GUM_ITEM_FG")
    
    [[ "$choice" == "[OK]" ]] && return 0 || return 1
}

# Display text input box
# Usage: result=$(gum_inputbox "Title" "Prompt" "DefaultValue")
gum_inputbox() {
    local title="$1"
    local prompt="$2"
    local default="${3:-}"
    
    clear
    echo ""
    echo "$title" | gum style \
        --border double \
        --padding "0 2" \
        --foreground "$GUM_HEADER_FG" \
        --background "$GUM_HEADER_BG" \
        --border-foreground "$GUM_BORDER_FG" \
        --align center \
        --width 80
    
    echo ""
    echo "$prompt" | gum style \
        --padding "0 2" \
        --foreground 250
    
    echo ""
    gum input \
        --placeholder "$default" \
        --width 60
}

# Export all functions for library use
export -f check_gum_available
export -f show_gum_install_instructions
export -f set_gum_colors
export -f gum_menu
export -f gum_msgbox
export -f gum_yesno
export -f gum_yesnocancel
export -f gum_okcancel
export -f gum_inputbox
