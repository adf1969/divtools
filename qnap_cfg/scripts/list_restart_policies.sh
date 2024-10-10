#!/bin/bash

# Temporary file to store docker inspect output
TMP_FILE=$(mktemp)

# Get detailed container information
docker inspect $(docker ps -aq) > "$TMP_FILE"

# Parse the information and format output
awk '
BEGIN { FS = "[ \":,]+"; OFS = ": " }
/"Name"/ { name = $3 }
/"RestartPolicy"/ { getline; print name, $3 }
' "$TMP_FILE"

# Clean up temporary file
rm "$TMP_FILE"

