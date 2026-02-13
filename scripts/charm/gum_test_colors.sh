#!/bin/bash
# Gum Color Test Script - Comprehensive menu system testing
# Last Updated: 01/13/2026 09:25:00 AM CDT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/gum_util.sh"
source "$SCRIPT_DIR/../util/logging.sh"

# Color scheme definitions
# Format: HEADER_FG HEADER_BG SELECTED_FG SELECTED_BG ITEM_FG BORDER_FG
declare -A COLOR_SCHEMES=(
    ["Cyan"]="255 51 255 51 250 51"
    ["Blue"]="255 33 255 33 250 33"
    ["Green"]="255 34 255 34 250 34"
    ["Magenta"]="255 201 255 201 250 201"
    ["Red"]="255 196 255 196 250 196"
    ["Yellow"]="0 226 0 226 240 226"
)

# Default scheme
CURRENT_SCHEME="Cyan"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--scheme)
            CURRENT_SCHEME="$2"
            shift 2
            ;;
        -d|--debug)
            DEBUG_MODE=1
            export DEBUG_MODE
            shift
            ;;
        -h|--help)
            cat << 'EOF'
Usage: gum_test_colors.sh [OPTIONS]

Test gum menu system with various color schemes

Options:
  -s, --scheme NAME     Use specific color scheme (default: Cyan)
  -d, --debug           Enable debug mode (show line counts)
  -h, --help            Show this help

Available Schemes:
  Cyan, Blue, Green, Magenta, Red, Yellow

Examples:
  gum_test_colors.sh                # Use default Cyan scheme
  gum_test_colors.sh -s Blue        # Use Blue scheme
  gum_test_colors.sh -d -s Green    # Debug mode with Green scheme

EOF
            exit 0
            ;;
        *)
            log "ERROR" "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Apply selected color scheme
apply_color_scheme() {
    local scheme="$1"
    local colors="${COLOR_SCHEMES[$scheme]}"
    
    if [[ -z "$colors" ]]; then
        log "ERROR" "Unknown color scheme: $scheme"
        log "INFO" "Available: ${!COLOR_SCHEMES[@]}"
        exit 1
    fi
    
    read -r h_fg h_bg s_fg s_bg i_fg b_fg <<< "$colors"
    set_gum_colors "$h_fg" "$h_bg" "$s_fg" "$s_bg" "$i_fg" "$b_fg"
    
    log "INFO" "Applied color scheme: $scheme"
}

# Test menu function
test_menu() {
    local -a menu_items=(
        "" "═══ MENU TESTS ═══"
        "1" "Test Message Box (OK)"
        "2" "Test Yes/No Dialog"
        "3" "Test Yes/No/Cancel Dialog"
        "4" "Test OK/Cancel Dialog"
        "5" "Test Input Box"
        "" "═══ COLOR SCHEMES ═══"
        "6" "Change Color Scheme"
        "" "═══════════════════"
        "0" "Exit Test"
    )
    
    local choice
    choice=$(gum_menu "Gum Test Menu - $CURRENT_SCHEME Theme" "Select a test to run" "${menu_items[@]}")
    
    if [[ $? -ne 0 ]] || [[ "$choice" == "0" ]]; then
        log "INFO" "Exiting test suite"
        return 1
    fi
    
    case "$choice" in
        1)
            test_msgbox
            ;;
        2)
            test_yesno
            ;;
        3)
            test_yesnocancel
            ;;
        4)
            test_okcancel
            ;;
        5)
            test_inputbox
            ;;
        6)
            select_color_scheme
            ;;
        *)
            gum_msgbox "Error" "Invalid selection: $choice"
            ;;
    esac
    
    return 0
}

# Test message box
test_msgbox() {
    gum_msgbox "Message Box Test" "This is a sample message box.\n\nIt displays information to the user.\nPress any key to return to main menu."
}

# Test yes/no dialog
test_yesno() {
    if gum_yesno "Yes/No Test" "Do you like this gum menu system?"; then
        gum_msgbox "Result" "You selected: YES"
    else
        gum_msgbox "Result" "You selected: NO"
    fi
}

# Test yes/no/cancel dialog
test_yesnocancel() {
    local result
    result=$(gum_yesnocancel "Yes/No/Cancel Test" "Would you recommend this to others?")
    
    case "$result" in
        yes) gum_msgbox "Result" "You selected: YES" ;;
        no) gum_msgbox "Result" "You selected: NO" ;;
        cancel) gum_msgbox "Result" "You selected: CANCEL" ;;
    esac
}

# Test OK/Cancel dialog
test_okcancel() {
    if gum_okcancel "OK/Cancel Test" "Proceed with the operation?"; then
        gum_msgbox "Result" "You selected: OK"
    else
        gum_msgbox "Result" "You selected: CANCEL"
    fi
}

# Test input box
test_inputbox() {
    local result
    result=$(gum_inputbox "Input Box Test" "Enter your name:" "John Doe")
    
    if [[ -n "$result" ]]; then
        gum_msgbox "Result" "You entered: $result"
    else
        gum_msgbox "Result" "No input provided"
    fi
}

# Select color scheme
select_color_scheme() {
    local -a scheme_menu=()
    local num=1
    
    for scheme in "${!COLOR_SCHEMES[@]}"; do
        scheme_menu+=("$num" "$scheme Theme")
        ((num++))
    done
    
    scheme_menu+=("" "═══════════════════")
    scheme_menu+=("0" "Cancel")
    
    local choice
    choice=$(gum_menu "Select Color Scheme" "Choose a color scheme to apply" "${scheme_menu[@]}")
    
    if [[ $? -ne 0 ]] || [[ "$choice" == "0" ]]; then
        return 0
    fi
    
    # Map choice to scheme name
    local selected_scheme=""
    num=1
    for scheme in "${!COLOR_SCHEMES[@]}"; do
        if [[ "$choice" == "$num" ]]; then
            selected_scheme="$scheme"
            break
        fi
        ((num++))
    done
    
    if [[ -n "$selected_scheme" ]]; then
        CURRENT_SCHEME="$selected_scheme"
        apply_color_scheme "$CURRENT_SCHEME"
        gum_msgbox "Color Scheme Changed" "Now using: $CURRENT_SCHEME theme"
    fi
}

# Main execution
if ! check_gum_available; then
    show_gum_install_instructions
    exit 1
fi

log "INFO" "Starting gum test suite with $CURRENT_SCHEME color scheme"
apply_color_scheme "$CURRENT_SCHEME"

# Main loop
while test_menu; do
    :
done

log "INFO" "Test suite completed"
exit 0
