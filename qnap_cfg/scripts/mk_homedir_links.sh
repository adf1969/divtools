#!/bin/bash
LOGFILE="/etc/logs/mk_homedir_links.log"

# Define the source and destination directories
HOME_SRC="/opt/divtools/dotfiles"
HOME_DEST="/root"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') : $1" >> $LOGFILE
}

# Check if HOME_SRC and HOME_DEST are directories
if [ ! -d "$HOME_SRC" ]; then
  log "Source directory $HOME_SRC does not exist."
  exit 1
fi

if [ ! -d "$HOME_DEST" ]; then
  log "Destination directory $HOME_DEST does not exist."
  exit 1
fi

# Array of folders/files to skip
SKIP_ITEMS=("." ".." ".git" ".bashrc")  # Add more items to skip as needed

# Function to check if an item is in the SKIP_ITEMS array
is_skip_item() {
    local item="$1"
    for skip_item in "${SKIP_ITEMS[@]}"; do
        if [[ "$item" == "$skip_item" ]]; then
            return 0  # Found, should skip
        fi
    done
    return 1  # Not found, should not skip
}

log "START: Processing SRC=$HOME_SRC and DEST=$HOME_DEST"
# Process files and directories in HOME_SRC, excluding items in SKIP_ITEMS
for src_file in "$HOME_SRC"/{,.}*; do
    # Extract the filename from the path
    filename=$(basename "$src_file")

    # Skip items in the SKIP_ITEMS array
    if is_skip_item "$filename"; then
        log "Skipping $filename"
        continue
    fi

    log "Processing $filename"

    # Define the corresponding destination path
    dest_file="$HOME_DEST/$filename"

    # Check if the symbolic link already exists and points to the correct source file
    if [ -L "$dest_file" ] && [ "$(readlink "$dest_file")" = "$src_file" ]; then
        log "- Symbolic link already exists and points to the correct source: $dest_file"
        continue
    fi

    # Check if the path exists in HOME_DEST and delete it
    if [ -e "$dest_file" ]; then
        rm -rf "$dest_file"
        log "- Deleted $dest_file"
    fi

    # Create the symbolic link from HOME_SRC to HOME_DEST
    ln -s "$src_file" "$dest_file"
    log "- Created symbolic link $dest_file -> $src_file"
done

log "END: All files processed."

