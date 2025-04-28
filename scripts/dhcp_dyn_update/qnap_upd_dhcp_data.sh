#!/bin/bash

# ChatGPT Project for this:
# https://chatgpt.com/c/680e695e-7bc0-8005-b304-92ec925f560f

# 📁 Path Setup
SOURCE_ROOT="/etc/config"   # << ✅ Change here if needed
TARGET_DIR="/opt/divtools/scripts/dhcp_dyn_update/data"
HASH_FILE="$TARGET_DIR/qnap_dhcp.hashes"

# 📄 Files relative to $SOURCE_ROOT
FILES=("nm_dhcpd.conf" "dhcp/dhcpd_eth0.leases")

mkdir -p "$TARGET_DIR"

# 🧹 Load Previous Hashes
declare -A old_hashes
if [[ -f "$HASH_FILE" ]]; then
    while IFS="=" read -r filename checksum; do
        old_hashes["$filename"]="$checksum"
    done < "$HASH_FILE"
fi

# 🧹 Initialize new hashes
declare -A new_hashes
changed=false

for relative_path in "${FILES[@]}"; do
    full_path="$SOURCE_ROOT/$relative_path"
    basename_only=$(basename "$relative_path")

    if [[ -f "$full_path" ]]; then
        checksum=$(sha256sum "$full_path" | awk '{print $1}')
        new_hashes["$relative_path"]="$checksum"

        if [[ "${old_hashes[$relative_path]}" != "$checksum" ]]; then
            echo "📄 $relative_path changed, copying to $TARGET_DIR/$basename_only"
            cp "$full_path" "$TARGET_DIR/$basename_only"
            changed=true
        else
            echo "✅ $relative_path unchanged, skipping copy."
        fi
    else
        echo "⚠️ Warning: $full_path not found!"
    fi
done

# 🛡️ Save updated hashes if anything changed
if [[ "$changed" == true ]]; then
    {
        for file in "${FILES[@]}"; do
            echo "$file=${new_hashes[$file]}"
        done
    } > "$HASH_FILE"
fi
