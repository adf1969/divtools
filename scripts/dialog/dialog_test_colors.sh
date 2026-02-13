#!/bin/bash
# Dialog Color Testing Script - Test all FG colors on selected BG in a menu
# Last Updated: 01/12/2026 11:20:00 PM CDT
#
# Uses dialog menu with specified background color and \Z escape codes
# for different foreground colors
#
# Usage:
#   ./dialog_test_colors.sh              # Test with CYAN background (default)
#   ./dialog_test_colors.sh -bg 1        # Test with BLACK background
#   ./dialog_test_colors.sh -bg 5        # Test with BLUE background
#
# Background Color Numbers:
#   1=BLACK, 2=RED, 3=GREEN, 4=YELLOW, 5=BLUE, 6=MAGENTA, 7=CYAN (default)

declare -A FG_NAMES=(
    [0]="BLACK"
    [1]="RED"
    [2]="GREEN"
    [3]="YELLOW"
    [4]="BLUE"
    [5]="MAGENTA"
    [6]="CYAN"
    [7]="WHITE"
)

declare -A BG_COLORS=(
    [1]="BLACK"
    [2]="RED"
    [3]="GREEN"
    [4]="YELLOW"
    [5]="BLUE"
    [6]="MAGENTA"
    [7]="CYAN"
)

BG_NUM=7  # Default CYAN

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -bg|--background)
            BG_NUM="$2"
            shift 2
            if ! [[ "$BG_NUM" =~ ^[1-7]$ ]]; then
                echo "ERROR: Invalid background number: $BG_NUM"
                echo "Valid: 1=BLACK, 2=RED, 3=GREEN, 4=YELLOW, 5=BLUE, 6=MAGENTA, 7=CYAN"
                exit 1
            fi
            ;;
        -h|--help)
            cat << EOF
Dialog Color Tester Menu - Test all FG colors on selected BG

USAGE: $0 [-bg NUM]

Background numbers:
  1=BLACK   2=RED     3=GREEN   4=YELLOW
  5=BLUE    6=MAGENTA 7=CYAN (default)

EXAMPLES:
  $0              # CYAN background (default)
  $0 -bg 1        # BLACK background  
  $0 -bg 5        # BLUE background

WHAT THIS DOES:
  Creates a dialog menu showing all 8 foreground colors on your
  selected background. Each menu item is displayed in its actual color.

FG Color Numbers (in menu):
  0=BLACK  1=RED  2=GREEN  3=YELLOW
  4=BLUE   5=MAGENTA  6=CYAN  7=WHITE

HOW TO USE:
  1. Run: ./dialog_test_colors.sh -bg 5  (or your chosen background)
  2. Look at the menu - each item shows a different foreground color
  3. Use UP/DOWN arrows to navigate and see all colors
  4. Report which color numbers are readable in the menu

EOF
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check dialog
if ! command -v dialog &> /dev/null; then
    echo "ERROR: dialog not found. Install: sudo apt install dialog"
    exit 1
fi

BG_COLOR="${BG_COLORS[$BG_NUM]}"

# Create DIALOGRC with selected background color for menu items
DIALOGRC="/tmp/.dialogrc.colortest.$$"

cat > "$DIALOGRC" << RCEOF
screen_color = (WHITE,BLACK,ON)
dialog_color = (WHITE,BLACK,OFF)
title_color = (CYAN,BLACK,ON)
border_color = (WHITE,BLACK,ON)
button_inactive_color = (BLACK,WHITE,OFF)
button_active_color = (WHITE,BLACK,ON)
button_label_active_color = (WHITE,BLACK,ON)
button_label_inactive_color = (BLACK,WHITE,OFF)
inputbox_color = (WHITE,BLACK,OFF)
inputbox_border_color = (WHITE,BLACK,ON)
searchbox_color = (WHITE,BLACK,OFF)
searchbox_title_color = (CYAN,BLACK,ON)
searchbox_border_color = (WHITE,BLACK,ON)
menubox_color = (WHITE,BLACK,OFF)
menubox_border_color = (WHITE,BLACK,ON)
item_color = (WHITE,BLACK,OFF)
tag_color = (CYAN,BLACK,ON)
tag_key_color = (CYAN,BLACK,ON)
check_color = (WHITE,BLACK,OFF)
position_indicator_color = (CYAN,BLACK,ON)
RCEOF

# Add the selected background color for menu items
case $BG_NUM in
    1) echo "item_selected_color = (WHITE,BLACK,ON)" >> "$DIALOGRC" ;;
    2) echo "item_selected_color = (WHITE,RED,ON)" >> "$DIALOGRC" ;;
    3) echo "item_selected_color = (WHITE,GREEN,ON)" >> "$DIALOGRC" ;;
    4) echo "item_selected_color = (BLACK,YELLOW,ON)" >> "$DIALOGRC" ;;
    5) echo "item_selected_color = (WHITE,BLUE,ON)" >> "$DIALOGRC" ;;
    6) echo "item_selected_color = (WHITE,MAGENTA,ON)" >> "$DIALOGRC" ;;
    7) echo "item_selected_color = (BLACK,CYAN,ON)" >> "$DIALOGRC" ;;
esac

# Build menu with \Z color codes for all foreground colors
declare -a menu_items=(
    "0" "\Z0████ Color 0: BLACK text \Z0"
    "1" "\Z1████ Color 1: RED text \Z0"
    "2" "\Z2████ Color 2: GREEN text \Z0"
    "3" "\Z3████ Color 3: YELLOW text \Z0"
    "4" "\Z4████ Color 4: BLUE text \Z0"
    "5" "\Z5████ Color 5: MAGENTA text \Z0"
    "6" "\Z6████ Color 6: CYAN text \Z0"
    "7" "\Z7████ Color 7: WHITE text \Z0"
    "" ""
    "0" "Exit"
)

# Show the menu with colors enabled and DIALOGRC set
export DIALOGRC="$DIALOGRC"

dialog --colors \
    --title "Dialog Color Menu Test - Background: #$BG_NUM ($BG_COLOR)" \
    --menu "Test all foreground colors on $BG_COLOR background.\nEach menu item shows a different foreground color.\nUse arrow keys to navigate. Report which colors are readable." \
    20 70 10 \
    "${menu_items[@]}" \
    2>&1

exit_code=$?

# Cleanup
rm -f "$DIALOGRC"
unset DIALOGRC

clear

if [[ $exit_code -eq 0 ]]; then
    echo "✓ Menu test completed"
else
    echo "Menu was cancelled"
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo "REPORT TO DEVELOPER:"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Terminal: [MobaXTerm / VS Code / other]"
echo "Background tested: #$BG_NUM ($BG_COLOR)"
echo ""
echo "In the menu, which color numbers were CLEARLY READABLE?"
echo "Clearly readable: #___, #___ (example: #3, #7)"
echo "Fair readability: #___, #___ (example: #1, #2)"
echo "Hard to read: #___, #___ (example: #4, #6)"
echo ""
echo "════════════════════════════════════════════════════════════"
echo "Test other backgrounds:"
echo "════════════════════════════════════════════════════════════"
for bg in {1..7}; do
    bg_name="${BG_COLORS[$bg]}"
    echo "  $0 -bg $bg       # Test with $bg_name background"
done
echo ""

exit 0
