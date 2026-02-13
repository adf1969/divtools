#!/bin/bash

# Script to set ACLs for AD users/groups on either TrueNAS Scale or QNAP
# Default domain: avctn
# Usage: set_ads_acls.sh [options] "user:group" "perms" <path>
# Example: set_ads_acls.sh "divix:fieldsfamily" "rwx" /mnt/tpool/testshare
#   Sets avctn\\divix:rwx and avctn\\fieldsfamily:rwx on the path recursively
# Perms: "rwx" (both same), or "rwx:r-x" (user rwx, group r-x)
# Options:
#   --domain <domain> : Override default domain (avctn)
#   --add-syncthing   : Add Syncthing UID 1401 with rwx
#   --include-unix    : Also set Unix ownership/permissions with chown/chmod
#   --test            : Echo commands without running them
#   --usage, --help   : Show this usage information

# Function to print usage
print_usage() {
    echo "Usage: $0 [options] \"user:group\" \"perms\" <path>"
    echo "Sets ACLs for AD users/groups on TrueNAS Scale or QNAP."
    echo "Default domain: avctn"
    echo
    echo "Arguments:"
    echo "  user:group  Specify AD user and/or group (e.g., \"divix:fieldsfamily\", \"divix:\", or \":fieldsfamily\")"
    echo "  perms       Permissions for user:group (e.g., \"rwx\", \"rwx:r-x\")"
    echo "  path        Target directory or file (e.g., \"/mnt/tpool/testshare\" on TrueNAS or \"/share/CACHEDEV1_DATA/testshare\" on QNAP)"
    echo
    echo "Options:"
    echo "  --domain <domain>  Override default domain (avctn)"
    echo "  --add-syncthing    Add Syncthing UID 1401 with rwx"
    echo "  --include-unix     Also set Unix ownership/permissions with chown/chmod"
    echo "  --test             Echo commands without running them"
    echo "  --usage, --help    Show this usage information"
    echo
    echo "Examples:"
    echo "  $0 \"divix:fieldsfamily\" \"rwx\" /mnt/tpool/testshare"
    echo "  $0 --add-syncthing \"divix:\" \"rwx\" ."
    echo "  $0 --include-unix --domain other.lan \"divix:fieldsfamily\" \"rwx:r-x\" /share/CACHEDEV1_DATA/testshare"
    echo "  $0 --test \"divix:fieldsfamily\" \"rwx\" ."
    exit 0
}

# Portable realpath replacement
get_absolute_path() {
    local path="$1"
    if [ -d "$path" ]; then
        (cd "$path" && pwd)
    else
        (cd "$(dirname "$path")" && echo "$(pwd)/$(basename "$path")")
    fi
}

# Defaults
DOMAIN="avctn"
ADD_SYNCTHING=false
INCLUDE_UNIX=false
TEST_MODE=false
SYNCTHING_UID="1401"
SYSTEM="unknown"

# Detect system based on hostname
HOSTNAME=$(hostname)
if [ "$HOSTNAME" = "NAS1-1" ]; then
    SYSTEM="truenas"
elif [ "$HOSTNAME" = "FHMTN1" ]; then
    SYSTEM="qnap"
else
    echo "Error: Unknown system (hostname: $HOSTNAME). Script supports NAS1-1 (TrueNAS) or FHMTN1 (QNAP)."
    exit 1
fi

# Check for no args or --usage/--help
if [ "$#" -eq 0 ] || [ "$1" = "--usage" ] || [ "$1" = "--help" ]; then
    print_usage
fi

# Parse options
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --domain) DOMAIN="$2"; shift ;;
        --add-syncthing) ADD_SYNCTHING=true ;;
        --include-unix) INCLUDE_UNIX=true ;;
        --test) TEST_MODE=true ;;
        --usage|--help) print_usage ;;
        *) break ;;
    esac
    shift
done

# Positional arguments
if [ "$#" -ne 3 ]; then
    echo "Error: Incorrect number of arguments."
    print_usage
fi

USER_GROUP="$1"
PERMS="$2"
TARGET_PATH="$3"

# Indicate test mode
if $TEST_MODE; then
    echo "TEST MODE: Commands will be echoed but NOT executed."
fi

# Validate path
if [ ! -e "$TARGET_PATH" ]; then
    echo "Error: Path $TARGET_PATH does not exist."
    exit 1
fi

# Resolve absolute path
TARGET_PATH=$(get_absolute_path "$TARGET_PATH")

# Determine ACL type
ACL_TYPE="none"
ACL_SUPPORTED=false

if [ "$SYSTEM" = "truenas" ]; then
    if command -v zfs >/dev/null; then
        ACL_TYPE=$(zfs get -H -o value acltype "$(zfs list -o name -H "$TARGET_PATH" 2>/dev/null | head -n 1)")
        if [ -z "$ACL_TYPE" ]; then
            echo "Warning: Could not determine ACL type for $TARGET_PATH on TrueNAS. Assuming POSIX."
            ACL_TYPE="posix"
        fi
        ACL_SUPPORTED=true
    else
        echo "Error: zfs command not found on TrueNAS system."
        exit 1
    fi
elif [ "$SYSTEM" = "qnap" ]; then
    MOUNT_POINT=$(awk -v path="$TARGET_PATH" '$2 != "/dev" && path ~ $2 {print $2}' /proc/mounts | head -n 1)
    if [ -n "$MOUNT_POINT" ] && grep -q " acl" /proc/mounts; then
        ACL_SUPPORTED=true
        getfacl "$TARGET_PATH" >/dev/null 2>&1 || ACL_SUPPORTED=false
    fi
    if $ACL_SUPPORTED; then
        ACL_TYPE="posix"
        echo "POSIX ACLs supported on $TARGET_PATH."
    else
        echo "Warning: POSIX ACLs not supported on $TARGET_PATH on QNAP. Check QNAP UI (Shared Folders > Edit > disable Windows ACLs) or enable 'acl' mount option. Falling back to Unix permissions if --include-unix is set."
    fi
fi

# Split user:group
IFS=':' read -r USER GROUP <<< "$USER_GROUP"
if [ -z "$USER" ] && [ -z "$GROUP" ]; then
    echo "Error: Must specify at least user or group in \"user:group\"."
    exit 1
fi

# Split perms: if one, apply to both; if two, user and group separately
IFS=':' read -r USER_PERMS GROUP_PERMS <<< "$PERMS"
if [ -z "$GROUP_PERMS" ]; then
    GROUP_PERMS="$USER_PERMS"
fi
if [ -n "$USER" ] && [ -z "$USER_PERMS" ]; then
    echo "Error: Perms required for user."
    exit 1
fi
if [ -n "$GROUP" ] && [ -z "$GROUP_PERMS" ]; then
    echo "Error: Perms required for group."
    exit 1
fi

# Resolve AD user/group to UID/GID
if [ -n "$USER" ]; then
    AD_USER="${DOMAIN}\\${USER}"
    USER_UID=$(id -u "$AD_USER" 2>/dev/null)
    if [ -z "$USER_UID" ]; then
        echo "Error: Cannot resolve user $AD_USER."
        exit 1
    fi
fi
if [ -n "$GROUP" ]; then
    AD_GROUP="${DOMAIN}\\${GROUP}"
    GROUP_GID=$(getent group "$AD_GROUP" | cut -d: -f3)
    if [ -z "$GROUP_GID" ]; then
        echo "Error: Cannot resolve group $AD_GROUP."
        exit 1
    fi
fi

# Convert rwx perms to NFSv4 format (for TrueNAS NFSv4)
convert_to_nfsv4_perms() {
    local perms="$1"
    local nfsv4_perms=""
    [[ "$perms" == *r* ]] && nfsv4_perms="${nfsv4_perms}r"
    [[ "$perms" == *w* ]] && nfsv4_perms="${nfsv4_perms}waD"  # w includes write, append, delete
    [[ "$perms" == *x* ]] && nfsv4_perms="${nfsv4_perms}x"
    echo "$nfsv4_perms"
}

# Function to set ACLs
set_acls() {
    local path="$1"

    if [ "$ACL_TYPE" = "none" ]; then
        echo "No ACL support detected. Skipping ACLs."
        return
    fi

    if [ "$SYSTEM" = "truenas" ] && [ "$ACL_TYPE" = "nfsv4" ]; then
        # NFSv4 on TrueNAS
        if ! command -v nfs4_setfacl >/dev/null 2>&1; then
            if $TEST_MODE; then
                echo "Would run: sudo apt update && sudo apt install -y nfs4-acl-tools"
            else
                echo "Installing nfs4-acl-tools on TrueNAS..."
                sudo apt update && sudo apt install -y nfs4-acl-tools
            fi
        fi

        local acl_cmds=()
        if [ -n "$USER" ]; then
            acl_cmds+=("A:fd@${USER_UID}:$(convert_to_nfsv4_perms "$USER_PERMS")")
        fi
        if [ -n "$GROUP" ]; then
            acl_cmds+=("A:fd@${GROUP_GID}:$(convert_to_nfsv4_perms "$GROUP_PERMS")")
        fi
        if $ADD_SYNCTHING; then
            acl_cmds+=("A:fd@${SYNCTHING_UID}:rwx")
        fi

        if [ ${#acl_cmds[@]} -eq 0 ]; then
            echo "No ACLs to set."
            return
        fi

        local acl_str=$(IFS=' '; echo "${acl_cmds[*]}")
        cmd_files="sudo find \"$path\" -exec nfs4_setfacl -a \"$acl_str\" {} \;"
        cmd_dirs="sudo find \"$path\" -type d -exec nfs4_setfacl -a \"$acl_str\" {} \;"

        if $TEST_MODE; then
            echo "Would run (NFSv4): $cmd_files"
            echo "Would run (NFSv4): $cmd_dirs"
        else
            echo "Setting NFSv4 ACLs on $path: $acl_str"
            eval "$cmd_files"
            eval "$cmd_dirs"
        fi
    else
        # POSIX on either system
        local acl_cmds=()
        if [ -n "$USER" ]; then
            acl_cmds+=("u:${USER_UID}:${USER_PERMS}")
        fi
        if [ -n "$GROUP" ]; then
            acl_cmds+=("g:${GROUP_GID}:${GROUP_PERMS}")
        fi
        if $ADD_SYNCTHING; then
            acl_cmds+=("u:${SYNCTHING_UID}:rwx")
        fi

        if [ ${#acl_cmds[@]} -eq 0 ]; then
            echo "No ACLs to set."
            return
        fi

        acl_str=$(IFS=','; echo "${acl_cmds[*]}")
        cmd_files="sudo find \"$path\" -exec setfacl -m \"$acl_str\" {} \;"
        cmd_dirs="sudo find \"$path\" -type d -exec setfacl -m \"d:${acl_str//,/:d,}\" {} \;"

        if $TEST_MODE; then
            echo "Would run (POSIX): $cmd_files"
            echo "Would run (POSIX): $cmd_dirs"
        else
            if $ACL_SUPPORTED; then
                echo "Setting POSIX ACLs on $path: $acl_str"
                eval "$cmd_files"
                eval "$cmd_dirs"
            else
                echo "Skipping POSIX ACLs: Not supported on $path."
            fi
        fi
    fi
}

# Function to set Unix perms
set_unix() {
    local path="$1"

    if [ -z "$USER" ] || [ -z "$GROUP" ]; then
        echo "Skipping Unix perms: Need both user and group for chown."
        return
    fi

    cmd_chown="sudo chown -R ${USER_UID}:${GROUP_GID} \"$path\""
    U_PERMS=$(echo "$USER_PERMS" | sed 's/r/r/; s/w/w/; s/x/x/; s/-/ - /g' | tr -d ' ')
    G_PERMS=$(echo "$GROUP_PERMS" | sed 's/r/r/; s/w/w/; s/x/x/; s/-/ - /g' | tr -d ' ')
    cmd_chmod="sudo chmod -R u=$U_PERMS,g=$G_PERMS,o=rx \"$path\""

    if $TEST_MODE; then
        echo "Would run: $cmd_chown"
        echo "Would run: $cmd_chmod"
    else
        echo "Setting Unix ownership to $AD_USER:$AD_GROUP on $path..."
        eval "$cmd_chown"
        echo "Setting Unix permissions u=$U_PERMS,g=$G_PERMS,o=rx on $path..."
        eval "$cmd_chmod"
    fi
}

# Apply
set_acls "$TARGET_PATH"
if $INCLUDE_UNIX; then
    set_unix "$TARGET_PATH"
fi

if $TEST_MODE; then
    echo "2TEST MODE: No commands were executed."
else
    echo "Done."
fi