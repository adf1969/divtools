#!/bin/bash
# Create Immich folders and .immich files based on immich.yml and .env
# Last Updated: 9/14/2025 8:18:45 PM CDT

# Source logging.sh
if [ -f "$DIVTOOLS/scripts/util/logging.sh" ]; then
    source "$DIVTOOLS/scripts/util/logging.sh"
else
    log ERROR "logging.sh not found at $DIVTOOLS/scripts/util/logging.sh"
    exit 1
fi

# Usage function
usage() {
    log INFO "Usage: $0 [-t] [-d] [-p] [-l] [-y <ymlfile>]"
    log INFO "  -t: Test mode, check folders and .immich files without creating"
    log INFO "  -d: Debug mode, enable verbose output"
    log INFO "  -p: Set permissions on folders using PUID:PGID from immich.yml"
    log INFO "  -l: List mode, show container and host folder mappings only"
    log INFO "  -y <ymlfile>: Specify custom immich.yml file (default: $DIVTOOLS/docker/include/$HOSTNAME/immich.yml)"
    exit 1
}

# Default yml file
YML_FILE="$DIVTOOLS/docker/include/$HOSTNAME/immich.yml"

TEST_MODE=0
DEBUG_MODE=0
SET_PERMS=0
LIST_MODE=0

while getopts "tdply:" opt; do
    case $opt in
        t) TEST_MODE=1 ;;
        d) DEBUG_MODE=1 ;;
        p) SET_PERMS=1 ;;
        l) LIST_MODE=1 ;;
        y) YML_FILE="$OPTARG" ;;
        \?) usage ;;
    esac
done

# Source .env files
if [ -f "$DIVTOOLS/docker/.env" ]; then
    source "$DIVTOOLS/docker/.env"
    log DEBUG "Sourced $DIVTOOLS/docker/.env"
else
    log ERROR "$DIVTOOLS/docker/.env not found"
    exit 1
fi

if [ -f "$DIVTOOLS/docker/secrets/env/.env.$HOSTNAME" ]; then
    source "$DIVTOOLS/docker/secrets/env/.env.$HOSTNAME"
    log DEBUG "Sourced $DIVTOOLS/docker/secrets/env/.env.$HOSTNAME"
else
    log ERROR "$DIVTOOLS/docker/secrets/env/.env.$HOSTNAME not found"
    exit 1
fi

# Check if yml file exists
if [ -f "$YML_FILE" ]; then
    log DEBUG "YML file found: $YML_FILE"
else
    log ERROR "YML file $YML_FILE not found"
    exit 1
fi

# Parse yml for environment variables from immich-server service
get_env_var() {
    local var_name="$1"
    local result
    result=$(awk '/immich-server:/,/^ *$/ {if (/environment:/) {in_env=1} else if (in_env && /^[^ -]/) {exit} else if (in_env && / - '"$var_name"'=/) {print}}' "$YML_FILE" | sed -n 's/.* - '"$var_name"'=//p' | head -n 1)
    if [[ -n "$result" ]]; then
        log DEBUG "Parsed $var_name from $YML_FILE: '$result'"
        echo "$result"
    else
        log DEBUG "No value found for $var_name in $YML_FILE"
        echo ""
    fi
}

# Parse all volume mounts from immich-server service into an associative array
declare -A volume_map
parse_volumes() {
    local in_server=0
    local in_volumes=0
    local line
    while IFS= read -r line; do
        # Remove leading/trailing whitespace
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        # Detect immich-server section
        if [[ "$line" == "immich-server:" ]]; then
            in_server=1
            continue
        fi
        # Within immich-server section
        if [[ "$in_server" == 1 ]]; then
            # Detect volumes section start
            if [[ "$line" == "volumes:" ]]; then
                in_volumes=1
                log DEBUG "Found volumes section"
                continue
            fi
            # Detect end of volumes section (next top-level key)
            if [[ "$in_volumes" == 1 && "$line" =~ ^[a-zA-Z_-]+: ]]; then
                in_volumes=0
                in_server=0
                continue
            fi
            # Process volume lines
            if [[ "$in_volumes" == 1 && "$line" =~ ^- ]]; then
                local vol_line=$(echo "$line" | sed 's/^- //;s/ *#.*$//')
                log DEBUG "Raw volume line: '$vol_line'"
                if [[ "$vol_line" =~ ^([^:]+):([^:]+)(:[rw]*)?$ ]]; then
                    local host_path="${BASH_REMATCH[1]}"
                    local container_path="${BASH_REMATCH[2]}"
                    local container_path_actual=$(resolve_path "$container_path")
                    volume_map["$container_path_actual"]="$host_path"
                    log DEBUG "Mapped expanded container path '$container_path_actual' to host path '$host_path'"
                else
                    log DEBUG "Skipped invalid volume line: '$vol_line'"
                fi
            fi
        fi
    done < "$YML_FILE"
    if [[ "${#volume_map[@]}" == 0 ]]; then
        log WARN "No volume mounts parsed from $YML_FILE"
    fi
}

# Get host path for a container path from volume map, with longest prefix matching for sub-paths
# Last Updated: 9/14/2025 9:45:00 PM CDT
get_host_path() {
    local container_path="$1"
    local container_path_actual=$(resolve_path "$container_path")
    local max_prefix_length=0
    local host_path=""
    
    # Normalize path to remove trailing slash
    local path="$container_path_actual"
    path="${path%/}"
    
    # Check each parent directory, starting with the full path
    while [[ -n "$path" && "$path" != "/" ]]; do
        if [[ -n "${volume_map[$path]}" ]]; then
            local prefix_length=${#path}
            if [[ $prefix_length -gt $max_prefix_length ]]; then
                max_prefix_length=$prefix_length
                local sub_path="${container_path_actual#$path}"
                host_path="${volume_map[$path]}$sub_path"
            fi
        fi
        # Move up to parent directory
        path="${path%/*}"
        [[ -z "$path" ]] && path="/"
    done
    
    if [[ -n "$host_path" ]]; then
        log DEBUG "Found host path '$host_path' for expanded container path '$container_path_actual' via prefix match"
        echo "$host_path"
    else
        log DEBUG "No host path found for expanded container path '$container_path_actual'"
        echo "container only"
    fi
}

# Fix container-only host paths by checking parent directories in volume_map
# Last Updated: 9/14/2025 9:30:00 PM CDT
fix_container_only_paths() {
    log INFO "Checking for container-only paths to resolve via parent directory mappings"
    for dir in "${!host_locations_actual[@]}"; do
        if [[ "${host_locations_actual[$dir]}" == "container only" ]]; then
            local container_path="${locations_actual[$dir]}"
            log DEBUG "Processing container-only path for $dir: $container_path"
            local path="$container_path"
            local max_prefix_length=0
            local resolved_host_path=""
            
            # Normalize path to remove trailing slash
            path="${path%/}"
            
            # Check each parent directory, starting with the full path
            while [[ -n "$path" && "$path" != "/" ]]; do
                if [[ -n "${volume_map[$path]}" ]]; then
                    local prefix_length=${#path}
                    if [[ $prefix_length -gt $max_prefix_length ]]; then
                        max_prefix_length=$prefix_length
                        local sub_path="${container_path#$path}"
                        resolved_host_path="${volume_map[$path]}$sub_path"
                        log DEBUG "Found parent mapping for '$path' -> '${volume_map[$path]}', constructing host path: '$resolved_host_path'"
                    fi
                fi
                # Move up to parent directory
                path="${path%/*}"
                [[ -z "$path" ]] && path="/"
            done
            
            if [[ -n "$resolved_host_path" ]]; then
                # Update host_locations and host_locations_actual
                host_locations[$dir]="$resolved_host_path"
                host_locations_actual[$dir]=$(resolve_path "$resolved_host_path")
                log DEBUG "Updated $dir: HOST_LOCATION: ${host_locations[$dir]}, HOST Actual Folder: ${host_locations_actual[$dir]}"
            else
                log DEBUG "No parent directory mapping found for $dir: $container_path, leaving as container only"
            fi
        fi
    done
}

# Resolve variables in paths
resolve_path() {
    local path="$1"
    if [[ -z "$path" || "$path" == "container only" ]]; then
        log DEBUG "Path '$path' is empty or container only, returning as is"
        echo "$path"
        return
    fi
    local resolved
    resolved=$(eval echo "$path" 2>/dev/null)
    if [[ $? -eq 0 && -n "$resolved" ]]; then
        log DEBUG "Resolved path '$path' to '$resolved'"
        echo "$resolved"
    else
        log DEBUG "Failed to resolve path '$path', returning original"
        echo "$path"
    fi
}

# Parse volume mounts
parse_volumes
log INFO "Volume map contents:"
for container_path in "${!volume_map[@]}"; do
    log DEBUG "  $container_path: ${volume_map[$container_path]}"
done

# Get PUID and PGID from yml, fallback to 1400:1400
PUID=$(get_env_var "PUID")
PUID_ACTUAL=$(resolve_path "$PUID")
if [[ -z "$PUID_ACTUAL" || "$PUID_ACTUAL" == "$PUID" ]]; then
    PUID_ACTUAL="1400"
    log WARN "PUID not found or unresolvable in $YML_FILE, using default 1400"
fi
PGID=$(get_env_var "PGID")
PGID_ACTUAL=$(resolve_path "$PGID")
if [[ -z "$PGID_ACTUAL" || "$PGID_ACTUAL" == "$PGID" ]]; then
    PGID_ACTUAL="1400"
    log WARN "PGID not found or unresolvable in $YML_FILE, using default 1400"
fi
log DEBUG "PUID: $PUID (actual: $PUID_ACTUAL)"
log DEBUG "PGID: $PGID (actual: $PGID_ACTUAL)"

# Default locations (per https://immich.app/docs/install/environment-variables)
DEFAULT_UPLOAD_LOCATION="/data"
DEFAULT_THUMBNAIL_LOCATION="/usr/src/app/thumbnails"
DEFAULT_PROFILE_LOCATION="/usr/src/app/profile"
DEFAULT_ENCODED_VIDEO_LOCATION="/usr/src/app/encoded-video"
DEFAULT_MAP_CACHE_LOCATION="/usr/src/app/map-cache"
DEFAULT_BACKUP_LOCATION="/usr/src/app/backups"

# Default locations (per https://immich.app/docs/install/environment-variables)
# Last Updated: 9/14/2025 11:15:00 PM CDT
DEFAULT_UPLOAD_LOCATION="/data"
DEFAULT_PROFILE_LOCATION="/usr/src/app/profile"
DEFAULT_ENCODED_VIDEO_LOCATION="/usr/src/app/encoded-video"
DEFAULT_MAP_CACHE_LOCATION="/usr/src/app/map-cache"
DEFAULT_BACKUP_LOCATION="/usr/src/app/backups"

# Get locations from yml or defaults
# Last Updated: 9/14/2025 11:15:00 PM CDT
CT_UPLOAD_LOCATION=$(get_env_var "UPLOAD_LOCATION")
if [[ -z "$CT_UPLOAD_LOCATION" ]]; then
    CT_UPLOAD_LOCATION="$DEFAULT_UPLOAD_LOCATION"
fi
CT_PROFILE_LOCATION=$(get_env_var "PROFILE_LOCATION")
if [[ -z "$CT_PROFILE_LOCATION" ]]; then
    CT_PROFILE_LOCATION="$DEFAULT_PROFILE_LOCATION"
fi
CT_ENCODED_VIDEO_LOCATION=$(get_env_var "ENCODED_VIDEO_LOCATION")
if [[ -z "$CT_ENCODED_VIDEO_LOCATION" ]]; then
    CT_ENCODED_VIDEO_LOCATION="$DEFAULT_ENCODED_VIDEO_LOCATION"
fi
CT_MAP_CACHE_LOCATION=$(get_env_var "MAP_CACHE_LOCATION")
if [[ -z "$CT_MAP_CACHE_LOCATION" ]]; then
    CT_MAP_CACHE_LOCATION="$DEFAULT_MAP_CACHE_LOCATION"
fi
CT_BACKUP_LOCATION=$(get_env_var "BACKUP_LOCATION")
if [[ -z "$CT_BACKUP_LOCATION" ]]; then
    CT_BACKUP_LOCATION="$DEFAULT_BACKUP_LOCATION"
fi
CT_THUMB_LOCATION=$(get_env_var "THUMB_LOCATION")
if [[ -z "$CT_THUMB_LOCATION" ]]; then
    CT_THUMB_LOCATION="$CT_UPLOAD_LOCATION/thumbs"
fi

# Resolve paths
# Last Updated: 9/14/2025 11:15:00 PM CDT
CT_UPLOAD_LOCATION_ACTUAL=$(resolve_path "$CT_UPLOAD_LOCATION")
CT_PROFILE_LOCATION_ACTUAL=$(resolve_path "$CT_PROFILE_LOCATION")
CT_ENCODED_VIDEO_LOCATION_ACTUAL=$(resolve_path "$CT_ENCODED_VIDEO_LOCATION")
CT_MAP_CACHE_LOCATION_ACTUAL=$(resolve_path "$CT_MAP_CACHE_LOCATION")
CT_BACKUP_LOCATION_ACTUAL=$(resolve_path "$CT_BACKUP_LOCATION")
CT_THUMB_LOCATION_ACTUAL=$(resolve_path "$CT_THUMB_LOCATION")

# Library is a subdirectory of UPLOAD_LOCATION
CT_LIBRARY_LOCATION="$CT_UPLOAD_LOCATION/library"
CT_LIBRARY_LOCATION_ACTUAL=$(resolve_path "$CT_LIBRARY_LOCATION")

# Get host paths from volume map
# Last Updated: 9/14/2025 11:15:00 PM CDT
HOST_UPLOAD_LOCATION=$(get_host_path "$CT_UPLOAD_LOCATION")
HOST_LIBRARY_LOCATION=$(get_host_path "$CT_LIBRARY_LOCATION")
HOST_PROFILE_LOCATION=$(get_host_path "$CT_PROFILE_LOCATION")
HOST_ENCODED_VIDEO_LOCATION=$(get_host_path "$CT_ENCODED_VIDEO_LOCATION")
HOST_MAP_CACHE_LOCATION=$(get_host_path "$CT_MAP_CACHE_LOCATION")
HOST_BACKUP_LOCATION=$(get_host_path "$CT_BACKUP_LOCATION")
HOST_THUMB_LOCATION=$(get_host_path "$CT_THUMB_LOCATION")

# Resolve host paths
# Last Updated: 9/14/2025 11:15:00 PM CDT
HOST_UPLOAD_LOCATION_ACTUAL=$(resolve_path "$HOST_UPLOAD_LOCATION")
HOST_LIBRARY_LOCATION_ACTUAL=$(resolve_path "$HOST_LIBRARY_LOCATION")
HOST_PROFILE_LOCATION_ACTUAL=$(resolve_path "$HOST_PROFILE_LOCATION")
HOST_ENCODED_VIDEO_LOCATION_ACTUAL=$(resolve_path "$HOST_ENCODED_VIDEO_LOCATION")
HOST_MAP_CACHE_LOCATION_ACTUAL=$(resolve_path "$HOST_MAP_CACHE_LOCATION")
HOST_BACKUP_LOCATION_ACTUAL=$(resolve_path "$HOST_BACKUP_LOCATION")
HOST_THUMB_LOCATION_ACTUAL=$(resolve_path "$HOST_THUMB_LOCATION")

# Map locations
# Last Updated: 9/14/2025 11:15:00 PM CDT
declare -A locations
locations["BACKUPS"]="$CT_BACKUP_LOCATION"
locations["ENCODED-VIDEO"]="$CT_ENCODED_VIDEO_LOCATION"
locations["LIBRARY"]="$CT_LIBRARY_LOCATION"
locations["MAP-CACHE"]="$CT_MAP_CACHE_LOCATION"
locations["PROFILE"]="$CT_PROFILE_LOCATION"
locations["THUMBS"]="$CT_THUMB_LOCATION"
locations["UPLOAD"]="$CT_UPLOAD_LOCATION"

declare -A locations_actual
locations_actual["BACKUPS"]="$CT_BACKUP_LOCATION_ACTUAL"
locations_actual["ENCODED-VIDEO"]="$CT_ENCODED_VIDEO_LOCATION_ACTUAL"
locations_actual["LIBRARY"]="$CT_LIBRARY_LOCATION_ACTUAL"
locations_actual["MAP-CACHE"]="$CT_MAP_CACHE_LOCATION_ACTUAL"
locations_actual["PROFILE"]="$CT_PROFILE_LOCATION_ACTUAL"
locations_actual["THUMBS"]="$CT_THUMB_LOCATION_ACTUAL"
locations_actual["UPLOAD"]="$CT_UPLOAD_LOCATION_ACTUAL"

declare -A host_locations
host_locations["BACKUPS"]="$HOST_BACKUP_LOCATION"
host_locations["ENCODED-VIDEO"]="$HOST_ENCODED_VIDEO_LOCATION"
host_locations["LIBRARY"]="$HOST_LIBRARY_LOCATION"
host_locations["MAP-CACHE"]="$HOST_MAP_CACHE_LOCATION"
host_locations["PROFILE"]="$HOST_PROFILE_LOCATION"
host_locations["THUMBS"]="$HOST_THUMB_LOCATION"
host_locations["UPLOAD"]="$HOST_UPLOAD_LOCATION"

declare -A host_locations_actual
host_locations_actual["BACKUPS"]="$HOST_BACKUP_LOCATION_ACTUAL"
host_locations_actual["ENCODED-VIDEO"]="$HOST_ENCODED_VIDEO_LOCATION_ACTUAL"
host_locations_actual["LIBRARY"]="$HOST_LIBRARY_LOCATION_ACTUAL"
host_locations_actual["MAP-CACHE"]="$HOST_MAP_CACHE_LOCATION_ACTUAL"
host_locations_actual["PROFILE"]="$HOST_PROFILE_LOCATION_ACTUAL"
host_locations_actual["THUMBS"]="$HOST_THUMB_LOCATION_ACTUAL"
host_locations_actual["UPLOAD"]="$HOST_UPLOAD_LOCATION_ACTUAL"

# Map location keys to environment variable names
# Last Updated: 9/14/2025 11:15:00 PM CDT
declare -A location_names
location_names["BACKUPS"]="BACKUP_LOCATION"
location_names["ENCODED-VIDEO"]="ENCODED_VIDEO_LOCATION"
location_names["LIBRARY"]="LIBRARY"
location_names["MAP-CACHE"]="MAP_CACHE_LOCATION"
location_names["PROFILE"]="PROFILE_LOCATION"
location_names["THUMBS"]="THUMB_LOCATION"
location_names["UPLOAD"]="UPLOAD_LOCATION"

# Log host locations actual for debugging
# Last Updated: 9/14/2025 11:15:00 PM CDT
log INFO "Host locations actual contents:"
for dir in $(for key in "${!host_locations_actual[@]}"; do echo "$key"; done | sort); do
    log DEBUG "$dir: ${host_locations_actual[$dir]}" >&2
done


if [[ "$LIST_MODE" == "1" ]]; then
    for dir in $(for key in "${!locations_actual[@]}"; do echo "$key"; done | sort); do
        display_name="${location_names[$dir]}"
        if [[ "${host_locations_actual[$dir]}" != "container only" ]]; then
            log "LIST:GREEN" "${display_name}: ${locations_actual[$dir]} -> ${host_locations_actual[$dir]}"
        else
            log "LIST:YELLOW" "${display_name}: CT: ${locations_actual[$dir]}"
        fi
    done
else
    log INFO "Immich folder locations (container):"
    for dir in $(for key in "${!locations[@]}"; do echo "$key"; done | sort); do
        log DEBUG "${location_names[$dir]}: ${locations[$dir]} (actual: ${locations_actual[$dir]})"
    done

    log INFO "Immich folder locations (host):"
    for dir in $(for key in "${!host_locations[@]}"; do echo "$key"; done | sort); do
        log DEBUG "${location_names[$dir]}: ${host_locations[$dir]} (actual: ${host_locations_actual[$dir]})"
    done

    if [[ "$TEST_MODE" == "1" ]]; then
        log INFO "TEST MODE: Checking folders and .immich files"
    else
        log INFO "Creating folders and .immich files"
    fi

    for dir in $(for key in "${!host_locations[@]}"; do echo "$key"; done | sort); do
        log "INFO:HEAD" "Processing ${location_names[$dir]} directory:"
        host_path="${host_locations[$dir]}"
        host_path_actual="${host_locations_actual[$dir]}"
        container_path="${locations[$dir]}"
        container_path_actual="${locations_actual[$dir]}"
        if [[ "$host_path_actual" == "container only" ]]; then
            log WARN "${location_names[$dir]} is container only (${container_path_actual}), cannot create on host"
            continue
        fi
        log INFO "> CT ${location_names[$dir]}_LOCATION: $container_path"
        log INFO "> CT Actual Folder: $container_path_actual"
        log INFO "> HOST ${location_names[$dir]}_LOCATION: $host_path"
        if [[ -d "$host_path_actual" ]]; then
            owner_group=$(stat -c "%U:%G" "$host_path_actual")
            perms=$(stat -c "%A" "$host_path_actual")
            log "INFO:HEAD" "> HOST Actual Folder: $host_path_actual EXISTS, $owner_group, $perms"
        else
            log INFO "> HOST Actual Folder: $host_path_actual"
        fi
        if [[ "$TEST_MODE" == "1" ]]; then
            if [[ -d "$host_path_actual" ]]; then
                log DEBUG "> ${location_names[$dir]} directory exists"
            else
                log WARN "> ${location_names[$dir]} directory ($host_path_actual) missing"
            fi
            if [[ -f "$host_path_actual/.immich" ]]; then
                file_owner_group=$(stat -c "%U:%G" "$host_path_actual/.immich")
                file_perms=$(stat -c "%A" "$host_path_actual/.immich")
                log "INFO:HEAD" "> ${location_names[$dir]} immich file ($host_path_actual/.immich) exists, $file_owner_group, $file_perms"
            else
                log WARN "> ${location_names[$dir]} immich file ($host_path_actual/.immich) missing"
            fi
        else
            mkdir -p "$host_path_actual"
            touch "$host_path_actual/.immich"
            log DEBUG "> Created $host_path_actual/.immich"
            if [[ "$SET_PERMS" == "1" ]]; then
                sudo chown -R "$PUID_ACTUAL":"$PGID_ACTUAL" "$host_path_actual"
                sudo chmod -R 775 "$host_path_actual"
                log DEBUG "> Permissions set for $host_path_actual to $PUID_ACTUAL:$PGID_ACTUAL"
            fi
        fi
    done

    # Output warnings for missing environment variables after folder processing
    # Last Updated: 9/14/2025 11:15:00 PM CDT
    if [[ "$CT_UPLOAD_LOCATION" == "$DEFAULT_UPLOAD_LOCATION" ]]; then
        log WARN "UPLOAD_LOCATION not found in $YML_FILE, used default $DEFAULT_UPLOAD_LOCATION" >&2
    fi
    if [[ "$CT_PROFILE_LOCATION" == "$DEFAULT_PROFILE_LOCATION" ]]; then
        log WARN "PROFILE_LOCATION not found in $YML_FILE, used default $DEFAULT_PROFILE_LOCATION" >&2
    fi
    if [[ "$CT_ENCODED_VIDEO_LOCATION" == "$DEFAULT_ENCODED_VIDEO_LOCATION" ]]; then
        log WARN "ENCODED_VIDEO_LOCATION not found in $YML_FILE, used default $DEFAULT_ENCODED_VIDEO_LOCATION" >&2
    fi
    if [[ "$CT_MAP_CACHE_LOCATION" == "$DEFAULT_MAP_CACHE_LOCATION" ]]; then
        log WARN "MAP_CACHE_LOCATION not found in $YML_FILE, used default $DEFAULT_MAP_CACHE_LOCATION" >&2
    fi
    if [[ "$CT_BACKUP_LOCATION" == "$DEFAULT_BACKUP_LOCATION" ]]; then
        log WARN "BACKUP_LOCATION not found in $YML_FILE, used default $DEFAULT_BACKUP_LOCATION" >&2
    fi
    if [[ "$CT_THUMB_LOCATION" == "$CT_UPLOAD_LOCATION/thumbs" ]]; then
        log WARN "THUMB_LOCATION not found in $YML_FILE, used default $CT_UPLOAD_LOCATION/thumbs" >&2
    fi
fi