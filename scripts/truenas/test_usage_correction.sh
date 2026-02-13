#!/bin/bash
# Test script to verify TrueNAS usage correction setup
# Last Updated: 11/4/2025 9:55:00 PM CST

echo "=== TrueNAS Usage Correction Test ==="
echo ""

# Colors for output
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
RESET="\e[m"

success() { echo -e "${GREEN}✓${RESET} $1"; }
error() { echo -e "${RED}✗${RESET} $1"; }
warn() { echo -e "${YELLOW}⚠${RESET} $1"; }

# Check 1: Helper script exists
echo "Checking helper script..."
if [[ -f "$DIVTOOLS/scripts/util/truenas_usage.sh" ]]; then
    success "truenas_usage.sh found"
else
    error "truenas_usage.sh not found at $DIVTOOLS/scripts/util/"
    exit 1
fi

# Check 2: Can source helper script
echo "Testing helper script..."
if source "$DIVTOOLS/scripts/util/truenas_usage.sh" 2>/dev/null; then
    success "truenas_usage.sh loads successfully"
else
    error "Failed to source truenas_usage.sh"
    exit 1
fi

# Check 3: Functions are available
echo "Checking functions..."
if type -t get_truenas_usage &>/dev/null; then
    success "get_truenas_usage() function available"
else
    error "get_truenas_usage() function not found"
fi

if type -t is_remote_mount &>/dev/null; then
    success "is_remote_mount() function available"
else
    error "is_remote_mount() function not found"
fi

# Check 4: Look for remote mounts
echo ""
echo "Searching for remote NFS/SMB mounts..."
found_remote=0
while IFS= read -r line; do
    [[ "$line" =~ ^Filesystem ]] && continue  # Skip header
    
    fs=$(echo "$line" | awk '{print $1}')
    mount=$(echo "$line" | awk '{print $6}')
    type=$(echo "$line" | awk '{print $2}')
    
    case "$type" in
        nfs|nfs4|cifs|smb|smbfs)
            found_remote=1
            success "Found remote mount: $mount (type: $type)"
            
            # Check for usage file
            usage_file="$mount/.zfs_usage_info"
            if [[ -r "$usage_file" ]]; then
                success "  Usage file exists and is readable: $usage_file"
                
                # Show snippet
                echo "  First 5 lines:"
                head -n 5 "$usage_file" | sed 's/^/    /'
                
                # Test the get_truenas_usage function
                echo "  Testing usage extraction..."
                if result=$(get_truenas_usage "$mount" "$usage_file" 0 2>&1); then
                    IFS='|' read -r used avail total <<< "$result"
                    success "  Extracted: Used=$used, Avail=$avail, Total=$total"
                else
                    error "  Failed to extract usage data"
                fi
            else
                warn "  No usage file found at: $usage_file"
                echo "  This mount will show standard df values"
            fi
            echo ""
            ;;
    esac
done < <(df -T -h -x overlay -x tmpfs 2>/dev/null)

if [[ $found_remote -eq 0 ]]; then
    warn "No remote NFS/SMB mounts found"
    echo "This is normal if you're testing on a system without remote mounts"
fi

# Check 5: Test df_color function
echo ""
echo "Testing enhanced df_color() function..."
if type -t df_color &>/dev/null; then
    success "df_color() function is available"
    echo ""
    echo "Running: dfc -debug"
    echo "=========================="
    dfc -debug
else
    error "df_color() function not found"
    echo "Make sure to reload your .bash_profile:"
    echo "  source ~/.bash_profile"
fi

echo ""
echo "=== Test Complete ==="
