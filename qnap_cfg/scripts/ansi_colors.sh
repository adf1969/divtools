#!/bin/bash

# ANSI color codes and their names
COLOR_NAMES=("C_BLACK" "C_RED" "C_GREEN" "C_YELLOW" "C_BLUE" "C_MAGENTA" "C_CYAN" "C_WHITE" "C_BRIGHTBLACK" "C_BRIGHTRED" "C_BRIGHTGREEN" "C_BRIGHTYELLOW" "C_BRIGHTBLUE" "C_BRIGHTMAGENTA" "C_BRIGHTCYAN" "C_BRIGHTWHITE")
COLORS=("30" "31" "32" "33" "34" "35" "36" "37" "90" "91" "92" "93" "94" "95" "96" "97")

BACKGROUND_COLOR_NAMES=("C_BG_BLACK" "C_BG_RED" "C_BG_GREEN" "C_BG_YELLOW" "C_BG_BLUE" "C_BG_MAGENTA" "C_BG_CYAN" "C_BG_WHITE" "C_BG_BRIGHTBLACK" "C_BG_BRIGHTRED" "C_BG_BRIGHTGREEN" "C_BG_BRIGHTYELLOW" "C_BG_BRIGHTBLUE" "C_BG_BRIGHTMAGENTA" "C_BG_BRIGHTCYAN" "C_BG_BRIGHTWHITE")
BACKGROUND_COLORS=("40" "41" "42" "43" "44" "45" "46" "47" "100" "101" "102" "103" "104" "105" "106" "107")

# Function to display color examples
display_colors() {
    local names=("${!1}")
    local codes=("${!2}")
    for i in "${!names[@]}"; do
        name="${names[$i]}"
        code="${codes[$i]}"
        echo -e "${name}: \e[${code}mThis is an example of color code ${code}\e[0m"
    done
}

echo "Regular and Bright Colors:"
display_colors COLOR_NAMES[@] COLORS[@]

echo -e "\nBackground and Bright Background Colors:"
display_colors BACKGROUND_COLOR_NAMES[@] BACKGROUND_COLORS[@]

