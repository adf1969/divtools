#!/bin/bash
# Dialog Utility Functions for Divtools
# Last Updated: 01/12/2026 6:30:00 PM CDT
#
# Provides reusable helper functions for dialog dialogs:
# - Automatic width/height calculation based on content
# - Enhanced color scheme management with custom colors
# - Text measurement and formatting
# - Common dialog wrappers (msgbox, yesno, inputbox, menu, etc.)
# - Debug mode: Adds line numbers to detect truncated content
# - Colored menu items support for improved readability
#
# Mirrors functionality from util/whiptail.sh but uses 'dialog' for enhanced features

# Check if dialog command is available
# Returns: 0 if available, 1 if not
check_dialog_available() {
    if ! command -v dialog &>/dev/null; then
        return 1
    fi
    return 0
}

# Display installation instructions if dialog is not available
# Should be called from main script before attempting to use dialog functions
show_dialog_install_instructions() {
    cat << 'EOF'
ERROR: The 'dialog' command is not installed.

This script requires the 'dialog' utility for interactive menus and dialogs.

To install on Ubuntu/Debian:
    sudo apt-get update && sudo apt-get install -y dialog

To install on RHEL/CentOS/Fedora:
    sudo yum install dialog
    # or
    sudo dnf install dialog

After installation, re-run this script.

EOF
}

# Add line numbers to text if DEBUG_MODE is set
# IMPORTANT: Every line must have a number, including empty lines
# Usage: result=$(add_line_numbers "$message")
# Returns: message with line numbers prefixed (if DEBUG_MODE=1), or original message
# Sets LINENUM_WIDTH_ADJUST for width calculation
add_line_numbers() {
    local text="$1"
    
    if [[ "${DEBUG_MODE:-0}" != "1" ]]; then
        LINENUM_WIDTH_ADJUST=0
        echo "$text"
        return 0
    fi
    
    # Count lines to determine how many digits we need
    local line_count=$(echo "$text" | wc -l)
    local max_line_digits=${#line_count}
    
    # Add line numbers to EVERY line (including empty lines)
    local result=""
    local line_num=1
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Format line number with leading zeros if needed, followed by colon and space
        # For empty lines, still add the line number
        printf -v formatted_line "%${max_line_digits}d: %s" "$line_num" "$line"
        result+="$formatted_line"$'\n'
        ((line_num++))
    done <<< "$text"
    
    # Remove trailing newline that was added
    result="${result%$'\n'}"
    
    # Calculate width adjustment: max_line_digits + colon + space
    LINENUM_WIDTH_ADJUST=$((max_line_digits + 2))
    
    echo "$result"
}

# Set standard dialog colors for all divtools scripts
# Last Updated: 01/12/2026 8:35:00 PM CDT
# Dialog uses DIALOGRC environment variable or ~/.dialogrc for color config
set_dialog_colors() {
    # Create temporary dialogrc config for color settings
    # Dialog color format: element = (foreground,background,highlight)
    export DIALOGRC="${DIALOGRC:-/tmp/.dialogrc.$$}"
    
    cat > "$DIALOGRC" << 'EOF'
# Dialog color configuration for divtools
# High-contrast color scheme with clear button selection

# Screen colors (main window background)
screen_color = (WHITE,BLACK,ON)

# Dialog box colors
dialog_color = (WHITE,BLACK,OFF)

# Title colors
title_color = (CYAN,BLACK,ON)

# Border colors
border_color = (WHITE,BLACK,ON)

# Button colors (inactive)
button_inactive_color = (BLACK,WHITE,OFF)

# Button colors (active/selected) - WHITE text on BLACK for visibility
button_active_color = (WHITE,BLACK,ON)

# Button label colors
button_label_active_color = (WHITE,BLACK,ON)
button_label_inactive_color = (BLACK,WHITE,OFF)

# Input field colors
inputbox_color = (WHITE,BLACK,OFF)
inputbox_border_color = (WHITE,BLACK,ON)

# Search box colors
searchbox_color = (WHITE,BLACK,OFF)
searchbox_title_color = (CYAN,BLACK,ON)
searchbox_border_color = (WHITE,BLACK,ON)

# Menu item colors
menubox_color = (WHITE,BLACK,OFF)
menubox_border_color = (WHITE,BLACK,ON)

# Selected menu item - WHITE text on BLUE background for maximum visibility across all terminals
item_selected_color = (WHITE,BLUE,ON)

# Menu tag (label) colors
tag_color = (CYAN,BLACK,ON)
tag_selected_color = (WHITE,BLUE,ON)
tag_key_color = (CYAN,BLACK,ON)
tag_key_selected_color = (WHITE,BLUE,ON)

# Checkbox/radiolist colors
check_color = (WHITE,BLACK,OFF)
check_selected_color = (BLACK,CYAN,ON)

# Text display colors
item_color = (WHITE,BLACK,OFF)

# Help line colors
position_indicator_color = (CYAN,BLACK,ON)
EOF
}

# Calculate the width needed for given text
# Handles multi-line text by finding the longest line
# Usage: width=$(calculate_text_width "text")
# Returns: minimum width in characters
calculate_text_width() {
    local text="$1"
    local max_width=0
    local line_width
    
    while IFS= read -r line; do
        # Remove ANSI color codes if present
        line="${line//\\033\[[0-9;]*m/}"
        line_width=${#line}
        if (( line_width > max_width )); then
            max_width=$line_width
        fi
    done <<< "$text"
    
    echo "$max_width"
}

# Calculate height needed for given text (number of lines)
# Usage: height=$(calculate_text_height "text" 9)
# Args: text, padding (default 9 accounts for borders, margins, and button area)
# Returns: number of lines + padding
# IMPORTANT: Padding accounts for top/bottom borders, margins, and button area in dialogs
calculate_text_height() {
    local text="$1"
    local padding=${2:-9}  # Default 9 lines: borders (2), margins (2), button area (5)
    local line_count=0
    
    # Simply count the newlines in the text as-is
    # This handles actual newlines in multi-line strings correctly
    
    # Method: use awk to count lines - most reliable across bash versions
    line_count=$(echo "$text" | awk 'END {print NR}')
    
    # Ensure minimum of 1
    (( line_count < 1 )) && line_count=1
    
    echo $((line_count + padding))
}

# Calculate dimensions for dialog, ensuring minimum/maximum constraints
# Usage: dims=$(calculate_dimensions "text" 8 20 60 100)
#   Args: text, min_height, min_width, max_width, max_height
# Returns: "height width"
calculate_dimensions() {
    local text="$1"
    local min_height=${2:-8}
    local min_width=${3:-20}
    local max_width=${4:-120}
    local max_height=${5:-40}
    
    local width=$(calculate_text_width "$text")
    local height=$(calculate_text_height "$text")
    
    # Apply minimum constraints
    (( width < min_width )) && width=$min_width
    (( height < min_height )) && height=$min_height
    
    # Apply maximum constraints
    (( width > max_width )) && width=$max_width
    (( height > max_height )) && height=$max_height
    
    echo "$height $width"
}

# Create a msgbox with automatic sizing
# Usage: dlg_msgbox "Title" "Message text"
dlg_msgbox() {
    local title="$1"
    local message="$2"
    
    set_dialog_colors
    
    # Count lines by loading into array (most reliable method)
    local line_count=0
    if [[ "${DEBUG_MODE:-0}" == "1" ]]; then
        local -a msg_lines
        readarray -t msg_lines <<< "$message"
        line_count=${#msg_lines[@]}
        title="$title ($line_count)"
    fi
    
    # Add line numbers if in debug mode
    message=$(add_line_numbers "$message")
    
    local dims
    # Calculate dimensions with width adjustment for line numbers if DEBUG_MODE is set
    dims=$(calculate_dimensions "$message" 8 80 $((130 + LINENUM_WIDTH_ADJUST)) 50)
    local height width
    read height width <<< "$dims"
    
    # Use textbox instead of msgbox to enable text selection with mouse
    # Write message to temporary file for textbox to read
    local tmpfile=$(mktemp)
    echo -e "$message" > "$tmpfile"
    
    # Use textbox with OK button instead of msgbox for better mouse support
    dialog --output-fd 1 --title "$title" --textbox "$tmpfile" "$height" "$width" </dev/tty >/dev/tty 2>&1
    
    rm -f "$tmpfile"
}

# Create a yesno dialog with automatic sizing
# Usage: dlg_yesno "Title" "Question text"
# Returns: 0 (yes) or 1 (no)
dlg_yesno() {
    local title="$1"
    local message="$2"
    
    set_dialog_colors
    
    # Count lines by loading into array (most reliable method)
    local line_count=0
    if [[ "${DEBUG_MODE:-0}" == "1" ]]; then
        local -a msg_lines
        readarray -t msg_lines <<< "$message"
        line_count=${#msg_lines[@]}
        title="$title ($line_count)"
    fi
    
    # Add line numbers if in debug mode
    message=$(add_line_numbers "$message")
    
    local dims
    # Calculate dimensions with width adjustment for line numbers if DEBUG_MODE is set
    dims=$(calculate_dimensions "$message" 10 80 $((130 + LINENUM_WIDTH_ADJUST)) 50)
    local height width
    read height width <<< "$dims"
    
    dialog --output-fd 1 --title "$title" --yesno "$message" "$height" "$width" </dev/tty >/dev/tty 2>&1
    return $?
}

# Create an inputbox with automatic sizing
# Usage: result=$(dlg_inputbox "Title" "Prompt" "Default value")
# Returns: User input or default value
dlg_inputbox() {
    local title="$1"
    local prompt="$2"
    local default=${3:-""}
    
    set_dialog_colors
    
    # Count lines by loading into array (most reliable method)
    local line_count=0
    if [[ "${DEBUG_MODE:-0}" == "1" ]]; then
        local -a prompt_lines
        readarray -t prompt_lines <<< "$prompt"
        line_count=${#prompt_lines[@]}
        title="$title ($line_count)"
    fi
    
    # Add line numbers if in debug mode
    prompt=$(add_line_numbers "$prompt")
    
    local dims
    # Calculate dimensions with width adjustment for line numbers if DEBUG_MODE is set
    dims=$(calculate_dimensions "$prompt" 10 80 $((130 + LINENUM_WIDTH_ADJUST)) 50)
    local height width
    read height width <<< "$dims"
    
    # Capture input using /dev/tty for proper terminal handling
    local result
    exec 3>&1
    result=$(dialog --output-fd 1 --title "$title" --inputbox "$prompt" "$height" "$width" "$default" \
        2>&1 1>&3 </dev/tty)
    local exit_code=$?
    exec 3>&-
    
    if [[ $exit_code -eq 0 ]]; then
        echo "$result"
    fi
    
    return $exit_code
}

# Create a textbox for displaying file contents
# Usage: dlg_textbox "Title" "/path/to/file"
dlg_textbox() {
    local title="$1"
    local file="$2"
    
    set_dialog_colors
    
    # For files, use a reasonable default (most terminals are wider than tall)
    dialog --output-fd 1 --title "$title" --textbox "$file" 30 100 </dev/tty >/dev/tty 2>&1
}

# Create a menu with automatic sizing based on items
# This is the main function for building menus with proper dimensions
# Usage: choice=$(dlg_menu "Title" "Prompt" "${menu_items[@]}")
# Args: title, prompt, item1_label, item1_desc, item2_label, item2_desc, ...
# Returns: Selected menu item key
dlg_menu() {
    local title="$1"
    local prompt="$2"
    shift 2
    local menu_items=("$@")
    
    set_dialog_colors
    
    # Find the longest menu item for width calculation
    local max_width=0
    local item_width
    local i
    
    for ((i=0; i < ${#menu_items[@]}; i+=2)); do
        local label="${menu_items[$i]}"
        local desc="${menu_items[$((i+1))]}"
        local full_item="$label - $desc"
        item_width=${#full_item}
        (( item_width > max_width )) && max_width=$item_width
    done
    
    # Minimum menu width is 60, maximum 120
    local width=$((max_width + 4))
    (( width < 60 )) && width=60
    (( width > 120 )) && width=120
    
    # Height: number of items + prompt/header + borders
    local height=$((${#menu_items[@]} / 2 + 8))
    (( height < 15 )) && height=15
    (( height > 40 )) && height=40
    
    # Build the menu and capture selection using /dev/tty
    local result
    exec 3>&1
    result=$(dialog --output-fd 1 --title "$title" --menu "$prompt" "$height" "$width" "$((height - 8))" \
        "${menu_items[@]}" \
        2>&1 1>&3 </dev/tty)
    local exit_code=$?
    exec 3>&-
    
    if [[ $exit_code -eq 0 ]]; then
        echo "$result"
    fi
    
    return $exit_code
}

# Wrapper for passwords with automatic sizing
# Usage: pwd=$(dlg_passwordbox "Title" "Prompt")
dlg_passwordbox() {
    local title="$1"
    local prompt="$2"
    
    set_dialog_colors
    
    local dims
    dims=$(calculate_dimensions "$prompt" 10 50 100 22)
    local height width
    read height width <<< "$dims"
    
    # Capture password using /dev/tty for proper terminal handling
    local result
    exec 3>&1
    result=$(dialog --output-fd 1 --title "$title" --passwordbox "$prompt" "$height" "$width" \
        2>&1 1>&3 </dev/tty)
    local exit_code=$?
    exec 3>&-
    
    if [[ $exit_code -eq 0 ]]; then
        echo "$result"
    fi
    
    return $exit_code
}

# Export functions so they can be used in sourced scripts
export -f check_dialog_available
export -f show_dialog_install_instructions
export -f set_dialog_colors
export -f add_line_numbers
export -f calculate_text_width
export -f calculate_text_height
export -f calculate_dimensions
export -f dlg_msgbox
export -f dlg_yesno
export -f dlg_inputbox
export -f dlg_textbox
export -f dlg_menu
export -f dlg_passwordbox
