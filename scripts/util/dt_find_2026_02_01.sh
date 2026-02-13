#!/bin/bash
# dt_find_2026_02_01.sh - Find files modified or changed around 2026-02-01 14:05
# Last Updated: 2/12/2026 12:00:00 PM CDT

# Search directory
SEARCH_DIR="/opt/divtools"

# Time range: 5 min before and after 14:05 on 2026-02-01
START_TIME="2026-02-01 14:00"
END_TIME="2026-02-01 14:10"

# Default flags
BACKUP_MODE=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -bk)
            BACKUP_MODE=1
            shift
            ;;
        *)
            echo "Usage: $0 [-bk]"
            echo "  -bk: Create backup copies of matching files with .2026-02-12 extension"
            exit 1
            ;;
    esac
done

echo "Searching for files in $SEARCH_DIR modified or changed between $START_TIME and $END_TIME"
if [ "$BACKUP_MODE" -eq 1 ]; then
    echo "Backup mode enabled: Creating .2026-02-12 copies of matching files"
fi
echo "Format: name | full path | modify date/time | size"
echo "--------------------------------------------------------------------------------"

# Find files where modify time or change time is in range
find "$SEARCH_DIR" -type f \( \
    \( -newermt "$START_TIME" ! -newermt "$END_TIME" \) \
    -o \
    \( -newerct "$START_TIME" ! -newerct "$END_TIME" \) \
\) -not -path "*/.stversions/*" -not -path "*/.git/*" -print0 | while IFS= read -r -d '' file; do
    # Create backup if enabled
    if [ "$BACKUP_MODE" -eq 1 ]; then
        cp "$file" "$file.2026-02-12"
    fi
    
    # Get basename
    name=$(basename "$file")
    # Full path
    fullpath="$file"
    # Modify time
    modtime=$(stat -c %y "$file" 2>/dev/null || echo "N/A")
    # Human readable size
    size=$(ls -lh "$file" 2>/dev/null | awk '{print $5}' || echo "N/A")
    
    echo "$name | $fullpath | $modtime | $size"
done
