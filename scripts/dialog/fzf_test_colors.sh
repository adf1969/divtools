#!/bin/bash
# FZF Color Testing Script - Test all FG colors on selected BG in FZF menu
# Last Updated: 01/12/2026 11:25:00 PM CDT
#
# Uses FZF with ANSI color codes for proper color rendering and contrast
# FZF has MUCH better color support than dialog
#
# Usage:
#   ./fzf_test_colors.sh              # Test with CYAN background (default)
#   ./fzf_test_colors.sh -bg 1        # Test with BLACK background
#   ./fzf_test_colors.sh -bg 5        # Test with BLUE background
#
# Background Color Numbers:
#   1=BLACK, 2=RED, 3=GREEN, 4=YELLOW, 5=BLUE, 6=MAGENTA, 7=CYAN (default)

# ANSI color codes
declare -A ANSI_FG=(
    [0]="30"      # BLACK
    [1]="31"      # RED
    [2]="32"      # GREEN
    [3]="33"      # YELLOW
    [4]="34"      # BLUE
    [5]="35"      # MAGENTA
    [6]="36"      # CYAN
    [7]="37"      # WHITE
)

declare -A ANSI_BG=(
    [1]="40"      # BLACK
    [2]="41"      # RED
    [3]="42"      # GREEN
    [4]="43"      # YELLOW
    [5]="44"      # BLUE
    [6]="45"      # MAGENTA
    [7]="46"      # CYAN
)

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

declare -A BG_NAMES=(
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
FZF Color Tester Menu - Test all FG colors on selected BG

USAGE: $0 [-bg NUM]

Background numbers:
  1=BLACK   2=RED     3=GREEN   4=YELLOW
  5=BLUE    6=MAGENTA 7=CYAN (default)

EXAMPLES:
  $0              # CYAN background (default)
  $0 -bg 1        # BLACK background  
  $0 -bg 5        # BLUE background

WHAT THIS DOES:
  Creates an FZF menu showing all 8 foreground colors on your
  selected background using proper ANSI color codes.
  FZF has MUCH better color support than dialog.

FG Color Numbers (in menu):
  0=BLACK  1=RED  2=GREEN  3=YELLOW
  4=BLUE   5=MAGENTA  6=CYAN  7=WHITE

HOW TO USE:
  1. Run: ./fzf_test_colors.sh -bg 5  (or your chosen background)
  2. Look at the FZF menu - each item shows a different foreground color
  3. Use UP/DOWN arrows or J/K to navigate and see all colors
  4. Press ESC or CTRL-C to exit
  5. Report which color numbers are readable in the menu

EOF
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check if fzf is installed
if ! command -v fzf &> /dev/null; then
    echo "ERROR: fzf not found. Install with: sudo apt install fzf"
    exit 1
fi

BG_COLOR="${BG_NAMES[$BG_NUM]}"
BG_CODE="${ANSI_BG[$BG_NUM]}"

# Build menu items with ANSI color codes
# Format: \033[FG;BG;BRIGHTm text \033[0m
declare -a menu_items

for fg_num in {0..7}; do
    fg_name="${FG_NAMES[$fg_num]}"
    fg_code="${ANSI_FG[$fg_num]}"
    
    # Create menu item with ANSI colors
    # Using bright (1) for better visibility
    menu_item="\033[${fg_code};${BG_CODE};1m████ Color #$fg_num: $fg_name on $BG_COLOR \033[0m"
    menu_items+=("$menu_item")
done

# Add exit option
menu_items+=("\033[37;40;1m====== Exit Test ======\033[0m")

clear

echo "╔════════════════════════════════════════════════════════════╗"
echo "║          FZF COLOR TEST MENU"
echo "║   Foreground Colors on Background: #$BG_NUM ($BG_COLOR)"
echo "║"
echo "║   Use arrow keys or J/K to navigate"
echo "║   Press ENTER to select, ESC to exit"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Pipe to FZF with explicit TTY access
selected=$(printf '%b\n' "${menu_items[@]}" | fzf \
    --ansi \
    --no-sort \
    --height 15 \
    --border \
    --preview-window hidden \
    --header "Evaluate each color's readability on $BG_COLOR background" \
    --footer "ESC=Exit | Use arrow keys or j/k to navigate" \
    < /dev/tty 2>&1)

exit_code=$?

clear

echo ""
echo "════════════════════════════════════════════════════════════"
echo "FZF COLOR TEST COMPLETE"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Background tested: #$BG_NUM ($BG_COLOR)"
echo ""
echo "════════════════════════════════════════════════════════════"
echo "REPORT TO DEVELOPER:"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Terminal: [MobaXTerm / VS Code / other]"
echo "Background tested: #$BG_NUM ($BG_COLOR)"
echo ""
echo "In the FZF menu, which color numbers were CLEARLY READABLE?"
echo "Clearly readable: #___, #___ (example: #3, #7)"
echo "Fair readability: #___, #___ (example: #1, #2)"
echo "Hard to read: #___, #___ (example: #4, #6)"
echo ""
echo "════════════════════════════════════════════════════════════"
echo "Test other backgrounds:"
echo "════════════════════════════════════════════════════════════"
for bg in {1..7}; do
    bg_name="${BG_NAMES[$bg]}"
    echo "  $0 -bg $bg       # Test with $bg_name background"
done
echo ""

exit 0
