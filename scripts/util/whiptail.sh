#!/bin/bash
# Whiptail Utility Functions for Divtools
# Last Updated: 01/09/2026 9:10:00 PM CDT
#
# Provides reusable helper functions for whiptail dialogs:
# - Automatic width/height calculation based on content
# - Color scheme management
# - Text measurement and formatting
# - Common dialog wrappers
# - Debug mode: Adds simple line numbers to detect truncated content


# Add line numbers to text if DEBUG_MODE is set
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
    
    # Add line numbers to each line
    local result=""
    local line_num=1
    while IFS= read -r line; do
        # Format line number with leading zeros if needed, followed by colon and space
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

# Set standard whiptail colors for all divtools scripts
# Last Updated: 01/09/2026 1:30:00 PM CDT
set_whiptail_colors() {
    # High-contrast color scheme with clear button selection
    export NEWT_COLORS='
        root=,black
        window=,black
        border=white,black
        textbox=white,black
        button=black,white
        actbutton=white,blue
        compactbutton=black,white
        title=cyan,black
        label=cyan,black
        entry=white,black
        checkbox=cyan,black
        actcheckbox=black,cyan
        listbox=white,black
        actlistbox=black,cyan
        sellistbox=black,cyan
        actsellistbox=white,blue
    '
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

# Format menu array into whiptail-compatible string
# Usage: menu_string=$(build_menu_items "${menu_array[@]}")
# Args: Variable number of arguments in pairs: (label description label description ...)
# Returns: Formatted string for whiptail --menu
build_menu_items() {
    local items=("$@")
    local output=""
    
    for item in "${items[@]}"; do
        output="$output \"$item\""
    done
    
    echo "$output"
}

# Build complete menu string with automatic width calculation
# Usage: dims=$(measure_menu_width "${menu_items[@]}")
# Returns: recommended width based on longest menu item
measure_menu_width() {
    local items=("$@")
    local max_width=0
    local item_width
    
    for item in "${items[@]}"; do
        # Remove escape sequences and count actual characters
        item="${item//\\033\[[0-9;]*m/}"
        item_width=${#item}
        (( item_width > max_width )) && max_width=$item_width
    done
    
    # Add padding for menu formatting (arrow, spacing)
    echo $((max_width + 4))
}

# Create a msgbox with automatic sizing
# Usage: wt_msgbox "Title" "Message text"
wt_msgbox() {
    local title="$1"
    local message="$2"
    local button_text=${3:-"OK"}
    
    set_whiptail_colors
    
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
    
    whiptail --fb --title "$title" --msgbox "$message" "$height" "$width"
}

# Create a yesno dialog with automatic sizing
# Usage: wt_yesno "Title" "Question text"
# Returns: 0 (yes) or 1 (no)
wt_yesno() {
    local title="$1"
    local message="$2"
    
    set_whiptail_colors
    
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
    
    whiptail --fb --title "$title" --yesno "$message" "$height" "$width"
}

# Create an inputbox with automatic sizing
# Usage: result=$(wt_inputbox "Title" "Prompt" "Default value")
# Returns: User input or default value
wt_inputbox() {
    local title="$1"
    local prompt="$2"
    local default=${3:-""}
    
    set_whiptail_colors
    
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
    
    whiptail --fb --title "$title" --inputbox "$prompt" "$height" "$width" "$default" 3>&1 1>&2 2>&3
}

# Create a textbox for displaying file contents
# Usage: wt_textbox "Title" "/path/to/file"
wt_textbox() {
    local title="$1"
    local file="$2"
    
    set_whiptail_colors
    
    # For files, use a reasonable default (most terminals are wider than tall)
    whiptail --fb --title "$title" --textbox "$file" 30 100
}

# Create a menu with automatic sizing based on items
# This is the main function for building menus with proper dimensions
# Usage: choice=$(wt_menu "Title" "Prompt" "${menu_items[@]}")
# Args: title, prompt, item1_label, item1_desc, item2_label, item2_desc, ...
# Returns: Selected menu item key
wt_menu() {
    local title="$1"
    local prompt="$2"
    shift 2
    local menu_items=("$@")
    
    set_whiptail_colors
    
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
    
    # Build the menu array format for whiptail
    whiptail --fb --title "$title" --menu "$prompt" "$height" "$width" "$((height - 8))" \
        "${menu_items[@]}" \
        3>&1 1>&2 2>&3
}

# Wrapper for passwords with automatic sizing
# Usage: pwd=$(wt_passwordbox "Title" "Prompt")
wt_passwordbox() {
    local title="$1"
    local prompt="$2"
    
    set_whiptail_colors
    
    local dims
    dims=$(calculate_dimensions "$prompt" 10 50 100 22)
    local height width
    read height width <<< "$dims"
    
    whiptail --fb --title "$title" --passwordbox "$prompt" "$height" "$width" 3>&1 1>&2 2>&3
}

# Export functions so they can be used in sourced scripts
export -f set_whiptail_colors
export -f calculate_text_width
export -f calculate_text_height
export -f calculate_dimensions
export -f build_menu_items
export -f measure_menu_width
export -f wt_msgbox
export -f wt_yesno
export -f wt_inputbox
export -f wt_textbox
export -f wt_menu
export -f wt_passwordbox
