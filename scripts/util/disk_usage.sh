#!/bin/bash

# Function to display usage
usage() {
    echo "Usage: $0 [-d days] <directory1> [directory2 ...]"
    echo "  -d days: Restrict to files/folders modified in the last <days> days"
    exit 1
}

# Function to display progress bar with current operation
show_progress() {
    local current=$1
    local total=$2
    local operation=$3
    local folder=$4
    local width=50
    local percent=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))
    local bar=$(printf "%${filled}s" | tr ' ' '#')
    bar+=$(printf "%${empty}s" | tr ' ' '-')
    printf "\r%s %s: [%s] %d%%" "$folder" "$operation" "$bar" "$percent"
}

# Function to format numbers with commas
format_number() {
    local num=$1
    printf "%'d" "$num"
}

# Parse options
days=""
while getopts "d:" opt; do
    case $opt in
        d)
            days="$OPTARG"
            # Validate that days is a positive integer
            if ! [[ "$days" =~ ^[0-9]+$ ]] || [ "$days" -le 0 ]; then
                echo "Error: -d requires a positive integer"
                usage
            fi
            ;;
        \?)
            usage
            ;;
    esac
done

# Shift past the options
shift $((OPTIND-1))

# Check if any directories are provided
if [ $# -eq 0 ]; then
    usage
fi

# Arrays to store results
declare -a names
declare -a sizes
declare -a files
declare -a folders
total_dirs=$#
total_steps=$((total_dirs * 3))  # 3 steps per directory: size, files, folders
current_step=0

# Show initial progress at 0%
show_progress $current_step $total_steps "initializing" ""

# Process each directory and store results
for dir in "$@"; do
    # Redirect errors to /dev/null
    exec 2>/dev/null

    # Get the directory name (basename)
    dir_name=$(basename "$dir")

    # Calculate size in GB (fully recursive, optionally restricted by days)
    show_progress $current_step $total_steps "estimating size" "$dir_name"
    if [ -n "$days" ]; then
        size=$(find "$dir" -type f -mtime -"$days" -exec du -s --block-size=1G {} + 2>/dev/null | awk '{sum+=$1} END {print sum}')
    else
        size=$(du -s --block-size=1G "$dir" | awk '{print $1}' 2>/dev/null)
    fi
    if [ -z "$size" ] || [ "$size" -eq 0 ]; then
        size="0"
    fi
    ((current_step++))
    show_progress $current_step $total_steps "estimating size" "$dir_name"

    # Count all files (fully recursive, optionally restricted by days)
    show_progress $current_step $total_steps "counting files" "$dir_name"
    if [ -n "$days" ]; then
        num_files=$(find "$dir" -type f -mtime -"$days" 2>/dev/null | wc -l)
    else
        num_files=$(find "$dir" -type f 2>/dev/null | wc -l)
    fi
    ((current_step++))
    show_progress $current_step $total_steps "counting files" "$dir_name"

    # Count all folders (fully recursive, excluding the root directory itself, optionally restricted by days)
    show_progress $current_step $total_steps "counting folders" "$dir_name"
    if [ -n "$days" ]; then
        num_folders=$(find "$dir" -type d -mtime -"$days" 2>/dev/null | wc -l)
        num_folders=$((num_folders - 1))  # Exclude the root directory itself
    else
        num_folders=$(find "$dir" -type d 2>/dev/null | wc -l)
        num_folders=$((num_folders - 1))
    fi
    ((current_step++))
    show_progress $current_step $total_steps "counting folders" "$dir_name"

    # Store results
    names+=("$dir_name")
    sizes+=("$size")
    files+=("$num_files")
    folders+=("$num_folders")
done

# Clear progress bar
printf "\r%*s\r" "$(tput cols)" ""

# Print pre-header if -d flag is used
if [ -n "$days" ]; then
    echo "Files/Folders Added/Changed in last $days days"
    echo
fi

# Print table header
printf "%-36s %12s %12s %12s\n" "Name" "Size (GB)" "# Files" "# Folders"
printf "%-36s %12s %12s %12s\n" "------------" "------------" "------------" "------------"

# Print all results at once
for ((i=0; i<${#names[@]}; i++)); do
    printf "%-36s %12s %12s %12s\n" "${names[i]}" "$(format_number ${sizes[i]})" "$(format_number ${files[i]})" "$(format_number ${folders[i]})"
done