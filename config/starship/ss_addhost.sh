#!/bin/bash

# Default Environment Variables
DIVTOOLS="/opt/divtools"
DT_STARSHIP_DIR="$DIVTOOLS/config/starship"
DT_STARSHIP_PRESET_DIR="$DT_STARSHIP_DIR/presets"
DT_STARSHIP_OVERRIDE_DIR="$DT_STARSHIP_DIR/overrides"
DT_STARSHIP_PALETTES_DIR="$DT_STARSHIP_DIR/palettes"
DEFAULT_PRESET="divtools"

# Parse Arguments
while getopts "h:p:" opt; do
    case "$opt" in
        h) CUSTOM_HOSTNAME="$OPTARG" ;;
        p) PRESET="$OPTARG" ;;
        *) echo "Usage: $0 [-p <preset>] [-h <hostname>]" && exit 1 ;;
    esac
done

# Use custom hostname if provided, otherwise use OS-defined HOSTNAME
HOSTNAME=${CUSTOM_HOSTNAME:-$HOSTNAME}
PRESET=${PRESET:-$DEFAULT_PRESET}

# Create Override File
override_file="$DT_STARSHIP_OVERRIDE_DIR/$HOSTNAME.toml"
if [ ! -f "$override_file" ]; then
    echo "Creating override file: $override_file"
    latest_override=$(find "$DT_STARSHIP_OVERRIDE_DIR" -name "*.toml" -type f -printf "%T+ %p\n" | sort | tail -n 1 | cut -d' ' -f2-)
    if [ -n "$latest_override" ]; then
        cp "$latest_override" "$override_file"
        echo "Copied from: $latest_override"
    else
        echo "# Override settings for $HOSTNAME" > "$override_file"
        echo "Created a blank override file as no recent file exists."
    fi
else
    echo "Override file already exists: $override_file"
fi

# Create Palette File
palette_file="$DT_STARSHIP_PALETTES_DIR/$PRESET-$HOSTNAME.toml"
if [ ! -f "$palette_file" ]; then
    echo "Creating palette file: $palette_file"
    latest_palette=$(find "$DT_STARSHIP_PALETTES_DIR" -name "$PRESET-*.toml" -type f -printf "%T+ %p\n" | sort | tail -n 1 | cut -d' ' -f2-)
    if [ -n "$latest_palette" ]; then
        cp "$latest_palette" "$palette_file"
        echo "Copied from: $latest_palette"
    else
        echo "# Palette settings for $HOSTNAME using preset $PRESET" > "$palette_file"
        echo "Created a blank palette file as no recent file exists."
    fi
else
    echo "Palette file already exists: $palette_file"
fi

echo "Host configuration completed."
