#!/bin/bash

# ANSI color codes and their names (basic 16 colors)
declare -A COLORS=(
    ["C_BLACK"]="30"
    ["C_RED"]="31"
    ["C_GREEN"]="32"
    ["C_YELLOW"]="33"
    ["C_BLUE"]="34"
    ["C_MAGENTA"]="35"
    ["C_CYAN"]="36"
    ["C_WHITE"]="37"
    ["C_BRIGHTBLACK"]="90"
    ["C_BRIGHTRED"]="91"
    ["C_BRIGHTGREEN"]="92"
    ["C_BRIGHTYELLOW"]="93"
    ["C_BRIGHTBLUE"]="94"
    ["C_BRIGHTMAGENTA"]="95"
    ["C_BRIGHTCYAN"]="96"
    ["C_BRIGHTWHITE"]="97"
)

declare -A BACKGROUND_COLORS=(
    ["C_BG_BLACK"]="40"
    ["C_BG_RED"]="41"
    ["C_BG_GREEN"]="42"
    ["C_BG_YELLOW"]="43"
    ["C_BG_BLUE"]="44"
    ["C_BG_MAGENTA"]="45"
    ["C_BG_CYAN"]="46"
    ["C_BG_WHITE"]="47"
    ["C_BG_BRIGHTBLACK"]="100"
    ["C_BG_BRIGHTRED"]="101"
    ["C_BG_BRIGHTGREEN"]="102"
    ["C_BG_BRIGHTYELLOW"]="103"
    ["C_BG_BRIGHTBLUE"]="104"
    ["C_BG_BRIGHTMAGENTA"]="105"
    ["C_BG_BRIGHTCYAN"]="106"
    ["C_BG_BRIGHTWHITE"]="107"
)

# Adding 256-color palette examples (for more diverse color range)
declare -A ALTERNATIVE_COLORS=(
    ["C_PINK"]="38;5;13"
    ["C_ORANGE"]="38;5;214"
    ["C_LIGHTGREEN"]="38;5;119"
    ["C_PURPLE"]="38;5;129"
    ["C_LIGHTBLUE"]="38;5;123"
    ["C_BROWN"]="38;5;130"
    ["C_LIGHTCYAN"]="38;5;152"
    ["C_GOLD"]="38;5;220"
    ["C_LIGHTPURPLE"]="38;5;177"
    ["C_DARKBLUE"]="38;5;19"
    ["C_LIGHTYELLOW"]="38;5;229"
    ["C_TEAL"]="38;5;37"
    ["C_SALMON"]="38;5;210"
    ["C_VIOLET"]="38;5;171"
    ["C_LIME"]="38;5;154"
    ["C_DARKGRAY"]="38;5;236"
)

# Function to display color examples
display_colors() {
    local color_type=$1
    declare -n colors=$2
    for name in "${!colors[@]}"; do
        code=${colors[$name]}
        echo -e "${name}: \e[${code}mThis is an example of color code ${code}\e[0m"
    done
}

echo "Regular Colors:"
display_colors "Foreground" COLORS

echo -e "\nBright Colors:"
display_colors "Foreground" COLORS

echo -e "\nBackground Colors:"
display_colors "Background" BACKGROUND_COLORS

echo -e "\nBright Background Colors:"
display_colors "Background" BACKGROUND_COLORS

# Display alternative colors from the 256-color palette
echo -e "\nAlternative Colors (256-color mode):"
display_colors "Foreground" ALTERNATIVE_COLORS

