#!/bin/bash

# ANSI color codes and their names
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

