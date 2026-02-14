#!/bin/bash

# Script to set the timezone on an Ubuntu server.
# Displays common US timezones, with the current as default if Enter is pressed.

# Function to get the current timezone
get_current_tz() {
    timedatectl status | grep "Time zone" | awk '{print $3}'
}

# Check if the script is run with sufficient privileges
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script with sudo or as root."
    exit 1
fi

# Get current timezone
current_tz=$(get_current_tz)
echo "Current Timezone: $current_tz"

# List of common US timezones (label and actual TZ value)
declare -A timezones
timezones[1]="Eastern - America/New_York"
timezones[2]="Central - America/Chicago"
timezones[3]="Mountain - America/Denver"
timezones[4]="Pacific - America/Los_Angeles"
timezones[5]="Alaska - America/Anchorage"
timezones[6]="Hawaii - Pacific/Honolulu"
timezones[7]="Arizona (no DST) - America/Phoenix"

# Display the menu
echo "Select a timezone (or press Enter to keep current):"
for i in "${!timezones[@]}"; do
    echo "$i) ${timezones[$i]}"
done

# Read user input
read -p "Enter your choice (1-7): " choice

# If input is empty, keep current
if [ -z "$choice" ]; then
    echo "No change made. Keeping current timezone: $current_tz"
    exit 0
fi

# Validate choice
if [[ ! "${!timezones[@]}" =~ "$choice" ]]; then
    echo "Invalid choice. Exiting without changes."
    exit 1
fi

# Extract the selected timezone value (after the dash)
selected_tz=$(echo "${timezones[$choice]}" | awk -F ' - ' '{print $2}')

# Set the timezone
timedatectl set-timezone "$selected_tz"

# Confirm the change
new_tz=$(get_current_tz)
echo "Timezone updated to: $new_tz"