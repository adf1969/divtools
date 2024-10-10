#!/bin/bash
#
# This script processes the current directory and creates symbolic links
# for each file in the directory. The symbolic links are created in a directory
# specified by removing a defined PATH_ROOT from the current logical path.
# The actual file paths are resolved using the physical path (i.e., symlinks are resolved).
# Example:
#   if run in /opt/home/root/etc/config, it will create symlinks from
#   /etc/config/<file> -> <physical-dir>/<file>

# Define the path root to be removed
PATH_ROOT="/opt/home/root"

# Get the current logical path (might include symlinks)
LOGICAL_DIR=$(pwd)

# Get the current physical path (resolved symlinks)
PHYSICAL_DIR=$(pwd -P)

# Ensure the logical directory starts with PATH_ROOT
if [[ "$LOGICAL_DIR" != "$PATH_ROOT"* ]]; then
    echo "Error: The current directory is not within the PATH_ROOT ($PATH_ROOT)"
    exit 1
fi

# Determine the SYMLINK_DIR by removing the PATH_ROOT prefix from the logical path
SYMLINK_DIR="${LOGICAL_DIR#$PATH_ROOT}"

# Ensure the symlink directory exists
mkdir -p "$SYMLINK_DIR"

# Process each file in the physical directory
for file in "$PHYSICAL_DIR"/*; do
    # Check if the item is a file
    if [ -f "$file" ]; then
        # Get the basename of the file
        BASENAME=$(basename "$file")
        
        # Check if the symlink or file already exists in SYMLINK_DIR
        if [ -e "$SYMLINK_DIR/$BASENAME" ]; then
            echo "Skipping $file: $SYMLINK_DIR/$BASENAME already exists"
        else
            # Create the symbolic link in the SYMLINK_DIR
            ln -s "$file" "$SYMLINK_DIR/$BASENAME"
            echo "Created symlink for $file at $SYMLINK_DIR/$BASENAME"
        fi
    fi
done

