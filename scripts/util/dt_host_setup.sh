#!/bin/bash

# dt_host_setup.sh
# Script to create host-specific Starship configuration files and update local ENV vars for the current machine.
# Run with: sudo ./dt_host_setup.sh [default_host]
# Example: sudo ./dt_host_setup.sh TNHL01
# Supports -test (stubs permanent actions with logs) and -debug (adds debug output).
# Last Updated: 12/6/2025 3:30:00 PM CST

# Global vars for users to update (comma-delimited; easy to edit)
UPDATE_USERS="root,divix"

# Parse flags
TEST_MODE=0
DEBUG_MODE=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        -t|-test) TEST_MODE=1; shift ;;
        -d|-debug) DEBUG_MODE=1; shift ;;
        *) break ;;
    esac
done

# Set environment variables
export DIVTOOLS="/opt/divtools"
export HOSTNAME_U=$(hostname -s | tr '[:lower:]' '[:upper:]')
# Load Local Overrides, if they exist
if [ -f ~/.env ]; then
    . ~/.env
    [ "$DEBUG_MODE" -eq 1 ] && echo -e "\e[37m[DEBUG] Loaded ~/.env for initial overrides.\e[m" >&2
fi

export DT_STARSHIP_DIR="$DIVTOOLS/config/starship"
export DT_STARSHIP_PALETTE_DIR="$DT_STARSHIP_DIR/palettes"
export DT_STARSHIP_OVERRIDE_DIR="$DT_STARSHIP_DIR/overrides"

# Logging function with color-coded output
log() {
    local level="$1"
    local message="$2"
    local color

    # Default colors for logging
    case "$level" in
        DEBUG) color="\e[37m" ;; # White
        INFO)  color="\e[36m" ;; # Cyan
        WARN)  color="\e[33m" ;; # Yellow
        ERROR) color="\e[31m" ;; # Red
        *)     color="\e[37m" ;; # Default to white
    esac

    echo -e "${color}[${level}] ${message}\e[m" >&2
    [ "$DEBUG_MODE" -eq 1 ] && echo -e "\e[37m[DEBUG] ${message}\e[m" >&2
} # log

# Debug log helper
debug_log() {
    [ "$DEBUG_MODE" -eq 1 ] && log "DEBUG" "$1"
} # debug_log

# Function to convert IP to integer
# Last Updated: 10/22/2025 12:32:00 PM CDT
ip_to_int() {
    local ip="$1"
    debug_log "Converting IP to integer: $ip"
    if [[ "$ip" =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$ ]]; then
        local a=${BASH_REMATCH[1]}
        local b=${BASH_REMATCH[2]}
        local c=${BASH_REMATCH[3]}
        local d=${BASH_REMATCH[4]}
        # Validate each octet
        for octet in "$a" "$b" "$c" "$d"; do
            if [ "$octet" -lt 0 ] || [ "$octet" -gt 255 ]; then
                log "ERROR" "Invalid IP octet in $ip: $octet"
                return 1
            fi
        done
        # Use printf to compute integer value
        local result=$(( (a * 16777216) + (b * 65536) + (c * 256) + d ))
        debug_log "IP $ip converted to $result"
        echo "$result"
    else
        log "ERROR" "Invalid IP address: $ip"
        return 1
    fi
} # ip_to_int

# Function to convert integer to IP
# Last Updated: 10/22/2025 12:32:00 PM CDT
int_to_ip() {
    local int="$1"
    debug_log "Converting integer $int to IP"
    echo "$((int >> 24 & 255)).$((int >> 16 & 255)).$((int >> 8 & 255)).$((int & 255))"
} # int_to_ip

# Function to check if IP is in CIDR
# Last Updated: 10/22/2025 12:32:00 PM CDT
ip_in_cidr() {
    local ip="$1"
    local cidr="$2"
    debug_log "Checking if IP $ip is in CIDR $cidr"
    if [ -z "$cidr" ]; then
        debug_log "Empty CIDR; skipping."
        return 1
    fi
    IFS='/' read -r net mask <<< "$cidr"
    if [ -z "$mask" ] || ! [[ "$mask" =~ ^[0-9]+$ ]] || [ "$mask" -gt 32 ] || [ "$mask" -lt 0 ]; then
        debug_log "Invalid CIDR: $cidr"
        return 1
    fi
    local ip_int
    ip_int=$(ip_to_int "$ip") || { debug_log "Failed to convert IP $ip to integer"; return 1; }
    local net_int
    net_int=$(ip_to_int "$net") || { debug_log "Failed to convert network $net to integer"; return 1; }
    local mask_int=$(echo "2^32 - 2^(32 - $mask)" | bc)
    debug_log "IP int: $ip_int, Net int: $net_int, Mask int: $mask_int"
    if [ $((ip_int & mask_int)) -eq $((net_int & mask_int)) ]; then
        debug_log "IP $ip is in network $cidr"
        return 0
    else
        debug_log "IP $ip is not in network $cidr"
        return 1
    fi
} # ip_in_cidr

# Function to check if Starship is installed
has_starship() {
    command -v starship &> /dev/null
}

# Function to show interactive menu for setup selection
# Last Updated: 12/6/2025 3:30:00 PM CST
show_setup_menu() {
    local menu_options=(
        "HOST" "Update Host .env files" ON
        "STARSHIP" "Update Starship Palette Files" ON
        "VSCODE" "Update VS Code Color Files" OFF
    )
    
    local selected=$(whiptail --fb --title "Select Setup Sections" --checklist \
        "Choose which sections to setup:" 12 60 3 \
        "${menu_options[@]}" 3>&1 1>&2 2>&3)
    
    if [ $? -ne 0 ]; then
        log "INFO" "Setup canceled."
        exit 0
    fi
    
    # Parse selected items (result is quoted strings)
    echo "$selected" | tr -d '"'
} # show_setup_menu

# Function to set whiptail colors
# Last Updated: 10/22/2025 12:50:00 PM CDT
set_whiptail_colors() {
    # Set whiptail color environment variables for high-contrast theme with clear button selection
    export NEWT_COLORS='
        root=,black
        window=,black
        border=white,black
        textbox=white,black
        button=black,white
        actbutton=white,blue
        compactbutton=black,white
        title=cyan,black
        label=cyan,black
        entry=white,black
        checkbox=cyan,black
        actcheckbox=black,cyan
        listbox=white,black
        actlistbox=black,cyan
        sellistbox=black,cyan
        actsellistbox=white,blue
    '
    log "INFO" "Applied custom whiptail color scheme with enhanced button highlighting."
} # set_whiptail_colors

# Function to update local ENV vars across users
# Last Updated: 10/22/2025 12:50:00 PM CDT
update_local_env_vars() {
    # Defaults (easy to edit)
    local DEFAULT_DIVTOOLS="/opt/divtools"
    local DEFAULT_DOCKERDATADIR="/opt"
    local DEFAULT_DT_LOCAL_BIN_DIR="/usr/local/bin"
    local DEFAULT_SITE_NUM=""
    local DEFAULT_SITE_NAME=""
    local DEFAULT_NEW_SITE_NUM=""
    local DEFAULT_NEW_SITE_NAME=""
    local DEFAULT_NEW_SITE_NETWORK=""

    # Load existing .env files in order of $UPDATE_USERS for local defaults
    IFS=',' read -r -a users <<< "$UPDATE_USERS"
    for user in "${users[@]}"; do
        if id "$user" &>/dev/null; then
            local home_dir=$(getent passwd "$user" | cut -d: -f6)
            local env_file="$home_dir/.env"
            if [ -f "$env_file" ]; then
                . "$env_file"
                debug_log "Loaded existing defaults from $env_file for user $user."
                break  # Stop after first found to prioritize order
            else
                debug_log "No .env file found for $user at $env_file."
            fi
        else
            debug_log "User $user does not exist."
        fi
    done

    # Set prompted values to loaded defaults or script defaults
    DIVTOOLS="${DIVTOOLS:-$DEFAULT_DIVTOOLS}"
    DOCKERDATADIR="${DOCKERDATADIR:-$DEFAULT_DOCKERDATADIR}"
    DT_LOCAL_BIN_DIR="${DT_LOCAL_BIN_DIR:-$DEFAULT_DT_LOCAL_BIN_DIR}"
    SITE_NUM="${SITE_NUM:-$DEFAULT_SITE_NUM}"
    SITE_NAME="${SITE_NAME:-$DEFAULT_SITE_NAME}"
    debug_log "Initial values: DIVTOOLS=$DIVTOOLS, DOCKERDATADIR=$DOCKERDATADIR, DT_LOCAL_BIN_DIR=$DT_LOCAL_BIN_DIR, SITE_NUM=$SITE_NUM, SITE_NAME=$SITE_NAME"

    # Determine primary IP
    local primary_ip=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '^127\.' | head -n 1)
    if [ -z "$primary_ip" ]; then
        log "WARN" "Could not determine primary IP; using 0.0.0.0 for site matching."
        primary_ip="0.0.0.0"
    fi
    debug_log "Primary IP: $primary_ip"

    # Set sites_dir
    local sites_dir="$DIVTOOLS/docker/sites"
    debug_log "Searching for site directories in: $sites_dir"

    # Build menu options and site info
    declare -A site_info
    local menu_options=()
    local default_index=0
    local index=0
    # Initialize defaults explicitly to avoid overwriting
    local matched_site_name=""
    local matched_site_num=""
    if [ -d "$sites_dir" ]; then
        shopt -s nullglob  # Prevent glob from returning pattern if no matches
        for site_dir in "$sites_dir"/s[0-9][0-9]-*; do
            if [[ -d "$site_dir" && "$site_dir" != *s00-shared* ]]; then
                local site_name=$(basename "$site_dir")
                local site_num=$(basename "$site_dir" | sed 's/^s0*\([0-9]\+\)-.*/\1/')
                local env_file="$site_dir/.env.${site_name}"
                debug_log "Processing site directory: $site_dir"
                if [ -f "$env_file" ]; then
                    debug_log "Found env file: $env_file"
                    source "$env_file"
                    if [[ -n "$SITE_NAME" && -n "$SITE_NUM" && -n "$SITE_NETWORK" ]]; then
                        debug_log "Loaded SITE_NAME: $SITE_NAME, SITE_NUM: $SITE_NUM, SITE_NETWORK: $SITE_NETWORK"
                        site_info["$SITE_NAME"]="$SITE_NUM"
                        if ip_in_cidr "$primary_ip" "$SITE_NETWORK"; then
                            debug_log "Match found for $SITE_NAME with network $SITE_NETWORK"
                            matched_site_name="$SITE_NAME"
                            matched_site_num="$SITE_NUM"
                            DEFAULT_SITE_NAME="$SITE_NAME"
                            DEFAULT_SITE_NUM="$SITE_NUM"
                            default_index=$index
                        fi
                    else
                        debug_log "Skipping $env_file: Missing SITE_NAME, SITE_NUM, or SITE_NETWORK."
                        site_info["$site_name"]="$site_num"
                    fi
                else
                    debug_log "No env file found for $site_dir; using directory-based defaults."
                    site_info["$site_name"]="$site_num"
                fi
                menu_options+=("$site_name" "")
                ((index++))
            fi
        done
        shopt -u nullglob  # Reset nullglob
    else
        debug_log "Sites directory $sites_dir does not exist."
    fi
    if [ ${#menu_options[@]} -eq 0 ]; then
        debug_log "No valid site directories found in $sites_dir."
    fi
    menu_options+=("New Site" "")
    # Ensure DEFAULT_SITE_NAME is set if a match was found
    if [ -n "$matched_site_name" ]; then
        debug_log "Setting default site: $matched_site_name with num: $matched_site_num"
        DEFAULT_SITE_NAME="$matched_site_name"
        DEFAULT_SITE_NUM="$matched_site_num"
    fi

    # Prompt for ENV vars using whiptail
    set_whiptail_colors

    DIVTOOLS=$(whiptail --fb --title "Set DIVTOOLS Path" --inputbox "Enter the path for DIVTOOLS (default: $DEFAULT_DIVTOOLS):" 12 60 "$DIVTOOLS" 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then
        log "INFO" "DIVTOOLS input canceled."
        return
    fi
    DIVTOOLS="${DIVTOOLS:-$DEFAULT_DIVTOOLS}"
    debug_log "Set DIVTOOLS: $DIVTOOLS"

    DOCKERDATADIR=$(whiptail --fb --title "Set DOCKERDATADIR Path" --inputbox "Enter the path for DOCKERDATADIR (default: $DEFAULT_DOCKERDATADIR):" 12 60 "$DOCKERDATADIR" 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then
        log "INFO" "DOCKERDATADIR input canceled."
        return
    fi
    DOCKERDATADIR="${DOCKERDATADIR:-$DEFAULT_DOCKERDATADIR}"
    debug_log "Set DOCKERDATADIR: $DOCKERDATADIR"

    DT_LOCAL_BIN_DIR=$(whiptail --fb --title "Set DT_LOCAL_BIN_DIR Path" --inputbox "Enter the path for local binaries (default: $DEFAULT_DT_LOCAL_BIN_DIR):" 12 60 "$DT_LOCAL_BIN_DIR" 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then
        log "INFO" "DT_LOCAL_BIN_DIR input canceled."
        return
    fi
    DT_LOCAL_BIN_DIR="${DT_LOCAL_BIN_DIR:-$DEFAULT_DT_LOCAL_BIN_DIR}"
    debug_log "Set DT_LOCAL_BIN_DIR: $DT_LOCAL_BIN_DIR"

    # Site selection loop
    while true; do
        SITE_NAME=$(whiptail --fb --title "Select SITE_NAME" --menu "Choose SITE_NAME (default: $DEFAULT_SITE_NAME):" 20 60 10 "${menu_options[@]}" 3>&1 1>&2 2>&3 --default-item "$DEFAULT_SITE_NAME")
        if [ $? -ne 0 ] || [ -z "$SITE_NAME" ]; then
            log "INFO" "Site selection canceled."
            SITE_NAME=""
            SITE_NUM=""
            debug_log "Set SITE_NAME and SITE_NUM to empty due to cancellation."
            break
        fi
        debug_log "Selected SITE_NAME: $SITE_NAME"
        if [[ "$SITE_NAME" == "New Site" ]]; then
            SITE_NUM=$(whiptail --fb --title "New SITE_NUM" --inputbox "Enter SITE_NUM (e.g., 1):" 12 60 "$DEFAULT_NEW_SITE_NUM" 3>&1 1>&2 2>&3)
            if [ $? -ne 0 ] || [ -z "$SITE_NUM" ]; then
                log "INFO" "New SITE_NUM input canceled."
                DEFAULT_NEW_SITE_NUM=""
                continue  # Return to site selection menu
            fi
            # Validate SITE_NUM as a non-prefixed number
            if ! [[ "$SITE_NUM" =~ ^[0-9]+$ ]]; then
                log "ERROR" "Invalid SITE_NUM: $SITE_NUM; must be a non-prefixed number."
                continue  # Return to site selection menu
            fi
            debug_log "New SITE_NUM: $SITE_NUM"
            DEFAULT_NEW_SITE_NUM="$SITE_NUM"
            SITE_NAME=$(whiptail --fb --title "New SITE_NAME" --inputbox "Enter SITE_NAME for s$(printf "%02d" $SITE_NUM)-:\n(Only enter the name, all lower-case, the s$(printf "%02d" $SITE_NUM)- will be prepended automatically)" 14 60 "$DEFAULT_NEW_SITE_NAME" 3>&1 1>&2 2>&3)
            if [ $? -ne 0 ] || [ -z "$SITE_NAME" ]; then
                log "INFO" "New SITE_NAME input canceled."
                DEFAULT_NEW_SITE_NAME=""
                continue  # Return to site selection menu
            fi
            debug_log "New SITE_NAME input: $SITE_NAME"
            DEFAULT_NEW_SITE_NAME="$SITE_NAME"
            # Construct full SITE_NAME with zero-padded SITE_NUM
            SITE_NAME="s$(printf "%02d" $SITE_NUM)-${SITE_NAME}"
            debug_log "Constructed SITE_NAME: $SITE_NAME"
            # Set default SITE_NETWORK based on non-prefixed SITE_NUM
            local default_network="10.${SITE_NUM}.0.0/20"
            debug_log "Default network: $default_network"
            SITE_NETWORK=$(whiptail --fb --title "New SITE_NETWORK" --inputbox "Enter SITE_NETWORK (default: $default_network):" 12 60 "${DEFAULT_NEW_SITE_NETWORK:-$default_network}" 3>&1 1>&2 2>&3)
            if [ $? -ne 0 ]; then
                log "INFO" "SITE_NETWORK input canceled."
                DEFAULT_NEW_SITE_NETWORK=""
                continue  # Return to site selection menu
            fi
            debug_log "New SITE_NETWORK: $SITE_NETWORK"
            DEFAULT_NEW_SITE_NETWORK="$SITE_NETWORK"
            # Confirm new site creation
            local site_display="Proposed new site:\n"
            site_display+="SITE_NUM=$SITE_NUM\n"
            site_display+="SITE_NAME=$SITE_NAME\n"
            site_display+="SITE_NETWORK=$SITE_NETWORK\n\nCreate this site?"
            if ! whiptail --fb --title "Confirm New Site" --yesno "$site_display" 12 60; then
                log "INFO" "New site creation canceled."
                continue  # Return to site selection menu
            fi
            debug_log "Confirmed new site creation."
            # Create new site dir and .env file
            local new_site_dir="$sites_dir/$SITE_NAME"
            local new_env_file="$new_site_dir/.env.$SITE_NAME"
            if [ "$TEST_MODE" -eq 1 ]; then
                log "INFO" "TEST MODE: Would create $new_site_dir and $new_env_file with SITE vars."
            else
                mkdir -p "$new_site_dir"
                echo "####" > "$new_env_file"
                echo "#### SITE SPECIFIC ENV VARS for $SITE_NAME" >> "$new_env_file"
                echo "####" >> "$new_env_file"
                echo "SITE_NUM=$SITE_NUM" >> "$new_env_file"
                echo "SITE_NAME=$SITE_NAME" >> "$new_env_file"
                echo "SITE_NETWORK=$SITE_NETWORK" >> "$new_env_file"
                chmod 775 "$new_site_dir"
                chmod 664 "$new_env_file"
                chown -R divix:syncthing "$new_site_dir"
                log "INFO" "Created new site: $new_site_dir and $new_env_file with ownership divix:syncthing and permissions 775."
            fi
            break  # Exit loop after successful site creation
        else
            SITE_NUM="${site_info[$SITE_NAME]}"
            if [ -z "$SITE_NUM" ]; then
                log "WARN" "No SITE_NUM found for SITE_NAME=$SITE_NAME; setting to empty."
                SITE_NUM=""
            fi
            debug_log "Set SITE_NUM from selected site: $SITE_NUM"
            break  # Exit loop after selecting existing site
        fi
    done

    # Display values for confirmation
    log "INFO" "Proposed ENV updates:"
    local env_display="Proposed ENV updates:\n"
    env_display+="DIVTOOLS=$DIVTOOLS\n"
    env_display+="DOCKERDATADIR=$DOCKERDATADIR\n"
    env_display+="DT_LOCAL_BIN_DIR=$DT_LOCAL_BIN_DIR\n"
    env_display+="SITE_NUM=$SITE_NUM\n"
    env_display+="SITE_NAME=$SITE_NAME"
    if ! whiptail --fb --title "Confirm ENV Updates" --yesno "$env_display\n\nProceed with updating .env files?" 15 60; then
        log "INFO" "ENV updates canceled."
        return
    fi
    debug_log "Confirmed ENV updates."
    for user in "${users[@]}"; do
        if id "$user" &>/dev/null; then
            local home_dir=$(getent passwd "$user" | cut -d: -f6)
            local env_file="$home_dir/.env"
            if [ "$TEST_MODE" -eq 1 ]; then
                log "INFO" "TEST MODE: Would update $env_file for $user."
                continue
            fi
            mkdir -p "$home_dir"
            local temp_file="$env_file.tmp"
            if [ -f "$env_file" ]; then
                # Check if markers exist
                if grep -q "#HOST-BEFORE" "$env_file" && grep -q "#HOST-AFTER" "$env_file"; then
                    debug_log "Found #HOST-BEFORE and #HOST-AFTER in $env_file; updating between markers."
                    awk '/#HOST-BEFORE/{p=1;print;print "# Do not make changes between these markers; they will be overwritten by dt_host_setup.sh";next}/#HOST-AFTER/{p=0;print;next}!p{print}' "$env_file" > "$temp_file"
                else
                    debug_log "No markers found in $env_file; appending markers."
                    cat "$env_file" > "$temp_file"
                    echo "" >> "$temp_file"
                    echo "#HOST-BEFORE" >> "$temp_file"
                    echo "# Do not make changes between these markers; they will be overwritten by dt_host_setup.sh" >> "$temp_file"
                    echo "#HOST-AFTER" >> "$temp_file"
                fi
            else
                debug_log "Creating new $env_file with markers."
                echo "#HOST-BEFORE" > "$temp_file"
                echo "# Do not make changes between these markers; they will be overwritten by dt_host_setup.sh" >> "$temp_file"
                echo "#HOST-AFTER" >> "$temp_file"
            fi
            # Insert new ENV vars between markers
            awk -v vars="export DIVTOOLS=\"$DIVTOOLS\"\nexport DOCKERDATADIR=\"$DOCKERDATADIR\"\nexport DT_LOCAL_BIN_DIR=\"$DT_LOCAL_BIN_DIR\"\nexport SITE_NUM=\"$SITE_NUM\"\nexport SITE_NAME=\"$SITE_NAME\"\nexport PATH=\"\$DT_LOCAL_BIN_DIR:\$PATH\"" \
                '/#HOST-BEFORE/{print;print vars;next}/#HOST-AFTER/{print;next}{print}' "$temp_file" > "$env_file.new"
            mv "$env_file.new" "$env_file"
            chown "$user:$user" "$env_file"
            chmod 640 "$env_file"
            rm -f "$temp_file"
            log "INFO" "Updated $env_file for $user."
        else
            log "WARN" "User $user does not exist; skipping .env update."
        fi
    done
} # update_local_env_vars


# Function to update Starship configs (refactored from original)
# Now sources DT_COLOR_* from env and injects into palette files
# Last Updated: 12/6/2025 3:30:00 PM CST
update_starship_cfg() {
    local default_host="${1:-DEFAULT}"  # Use provided default hostname or fallback to "DEFAULT"
    local hostname="$HOSTNAME_U"  # Use uppercase hostname from environment

    # Load environment to get DT_COLOR_* variables
    if declare -f load_env_files >/dev/null 2>&1; then
        debug_log "load_env_files already available; invoking..."
        load_env_files
    elif [ -f "$HOME/.bash_profile" ]; then
        debug_log "Sourcing ~/.bash_profile to get load_env_files..."
        source "$HOME/.bash_profile" 2>/dev/null
        if declare -f load_env_files >/dev/null 2>&1; then
            load_env_files
        fi
    fi
    
    # Second fallback: try DIVTOOLS/.bash_profile if DIVTOOLS is set and load_env_files still not found
    if ! declare -f load_env_files >/dev/null 2>&1 && [ -n "$DIVTOOLS" ] && [ -f "$DIVTOOLS/dotfiles/.bash_profile" ]; then
        debug_log "Sourcing $DIVTOOLS/dotfiles/.bash_profile for load_env_files..."
        source "$DIVTOOLS/dotfiles/.bash_profile" 2>/dev/null
        if declare -f load_env_files >/dev/null 2>&1; then
            debug_log "Found load_env_files in DIVTOOLS; invoking..."
            load_env_files
        fi
    fi
    
    # Get color values from environment (fallbacks to empty if not set)
    local color_status_bg="${DT_COLOR_STATUS_BG:-}"
    local color_activity_bg="${DT_COLOR_ACTIVITY_BG:-}"
    local color_term_bg="${DT_COLOR_TERM_BG:-}"
    
    # Strip alpha channel if colors have transparency (8-digit hex like #RRGGBBaa)
    if [[ "$color_status_bg" =~ ^#[0-9a-fA-F]{8}$ ]]; then
        color_status_bg="${color_status_bg:0:7}"
        debug_log "Stripped alpha from DT_COLOR_STATUS_BG → $color_status_bg"
    fi
    if [[ "$color_activity_bg" =~ ^#[0-9a-fA-F]{8}$ ]]; then
        color_activity_bg="${color_activity_bg:0:7}"
        debug_log "Stripped alpha from DT_COLOR_ACTIVITY_BG → $color_activity_bg"
    fi
    if [[ "$color_term_bg" =~ ^#[0-9a-fA-F]{8}$ ]]; then
        color_term_bg="${color_term_bg:0:7}"
        debug_log "Stripped alpha from DT_COLOR_TERM_BG → $color_term_bg"
    fi
    
    debug_log "Checking for DT_COLOR_* variables..."
    debug_log "DT_COLOR_STATUS_BG=${DT_COLOR_STATUS_BG}"
    debug_log "DT_COLOR_ACTIVITY_BG=${DT_COLOR_ACTIVITY_BG}"
    debug_log "DT_COLOR_TERM_BG=${DT_COLOR_TERM_BG}"
    
    if [ -n "$color_status_bg" ] || [ -n "$color_activity_bg" ] || [ -n "$color_term_bg" ]; then
        debug_log "Loaded colors: STATUS_BG=$color_status_bg, ACTIVITY_BG=$color_activity_bg, TERM_BG=$color_term_bg"
    else
        debug_log "No DT_COLOR_* variables found in environment"
    fi

    # Define paths for Starship palette and override files
    local default_palette_file="$DT_STARSHIP_PALETTE_DIR/divtools-${default_host}.toml"
    local host_palette_file="$DT_STARSHIP_PALETTE_DIR/divtools-${hostname}.toml"
    local fallback_palette_file="$DT_STARSHIP_PALETTE_DIR/divtools.toml"
    local default_override_file="$DT_STARSHIP_OVERRIDE_DIR/${default_host}.toml"
    local host_override_file="$DT_STARSHIP_OVERRIDE_DIR/${hostname}.toml"
    local fallback_override_file="$DT_STARSHIP_OVERRIDE_DIR/DEFAULT.toml"

    # Check for existing files
    local starship_display="Starship configuration files:\n\n"
    starship_display+="📁 PALETTES (Colors):\n"
    if [ -f "$host_palette_file" ]; then
        starship_display+="  ✓ palettes/divtools-${hostname}.toml (exists - may be updated)\n"
    else
        starship_display+="  ○ palettes/divtools-${hostname}.toml (will be created)\n"
    fi
    starship_display+="\n📁 OVERRIDES (Layout):\n"
    if [ -f "$host_override_file" ]; then
        starship_display+="  ✓ overrides/${hostname}.toml (exists - will NOT be overwritten)\n"
    else
        starship_display+="  ○ overrides/${hostname}.toml (will be created)\n"
    fi
    starship_display+="\nProceed with Starship setup?"

    # Confirm Starship updates
    if ! whiptail --fb --title "Confirm Starship Updates" --yesno "$starship_display" 16 80; then
        log "INFO" "Starship updates canceled."
        return
    fi
    debug_log "Confirmed Starship updates."

    # Ensure palette and override directories exist
    if [ ! -d "$DT_STARSHIP_PALETTE_DIR" ]; then
        log "INFO" "Creating Starship palette directory: $DT_STARSHIP_PALETTE_DIR"
        if [ "$TEST_MODE" -eq 1 ]; then
            debug_log "TEST MODE: Would create $DT_STARSHIP_PALETTE_DIR."
        else
            mkdir -p "$DT_STARSHIP_PALETTE_DIR"
            chmod 775 "$DT_STARSHIP_PALETTE_DIR"
        fi
    fi
    if [ ! -d "$DT_STARSHIP_OVERRIDE_DIR" ]; then
        log "INFO" "Creating Starship override directory: $DT_STARSHIP_OVERRIDE_DIR"
        if [ "$TEST_MODE" -eq 1 ]; then
            debug_log "TEST MODE: Would create $DT_STARSHIP_OVERRIDE_DIR."
        else
            mkdir -p "$DT_STARSHIP_OVERRIDE_DIR"
            chmod 775 "$DT_STARSHIP_OVERRIDE_DIR"
        fi
    fi

    # Check if the default palette file exists; if not, create a fallback divtools.toml
    if [ ! -f "$default_palette_file" ]; then
        log "INFO" "Default palette file does not exist: $default_palette_file"
        if [ "$default_host" != "DEFAULT" ]; then
            log "INFO" "Falling back to create or use $fallback_palette_file"
            if [ ! -f "$fallback_palette_file" ]; then
                log "INFO" "Creating default palette file: $fallback_palette_file"
                if [ "$TEST_MODE" -eq 1 ]; then
                    debug_log "TEST MODE: Would create $fallback_palette_file with default content."
                else
                    cat > "$fallback_palette_file" <<'PALETTE_EOF'
# Starship palette for divtools
# This file is automatically updated by dt_host_setup.sh with DT_COLOR_* values from .env files
# Do not manually edit color values; instead, update .env.$HOSTNAME or .env.$SITE_NAME
# See: $DIVTOOLS/docker/sites/$SITE_NAME/$HOSTNAME/.env.$HOSTNAME

[palettes.divtools]
# Default Starship palette for divtools
background = "#282c34"  # Dark background
foreground = "#abb2bf"  # Light foreground
accent = "#61afef"      # Blue accent
error = "#e06c75"       # Red error
success = "#98c379"     # Green success
warning = "#e5c07b"     # Yellow warning
PALETTE_EOF
                    chmod 664 "$fallback_palette_file"
                    log "INFO" "Successfully created default palette file: $fallback_palette_file"
                fi
            fi
            default_palette_file="$fallback_palette_file"
        else
            log "ERROR" "Cannot create host-specific palette file without a default. Please create $default_palette_file manually."
            exit 1
        fi
    fi

    # Create host-specific palette file if it doesn't exist
    # If it does exist, ask the user if they want to override it with updated colors
    should_update_palette=1
    
    if [ -f "$host_palette_file" ]; then
        # File exists - ask user if they want to update colors from ENV
        log "INFO" "Existing Starship palette file found: $host_palette_file"
        
        if [ "$TEST_MODE" -eq 1 ]; then
            debug_log "TEST MODE: File exists at $host_palette_file. In interactive mode, would ask for override."
            should_update_palette=1
        elif [ -t 0 ]; then
            # Interactive mode - ask user with whiptail about COLORS ONLY (not layout)
            if whiptail --fb --title "Update Starship Palette (Colors)" \
                --yesno "Existing color palette file found:\n\n  palettes/divtools-${hostname}.toml\n\nDo you want to UPDATE the COLORS from DT_COLOR_* env variables?\n\n(Recommended if you recently changed DT_COLOR_* settings)\n\nNote: This does NOT affect the layout file (overrides/)" \
                13 75 3>&1 1>&2 2>&3; then
                log "INFO" "User chose to override existing palette file"
                should_update_palette=1
            else
                log "INFO" "User chose to keep existing palette file unchanged"
                should_update_palette=0
            fi
        else
            # Non-interactive mode - keep existing file by default
            log "INFO" "Non-interactive mode detected. Keeping existing palette file unchanged."
            should_update_palette=0
        fi
    else
        # File doesn't exist - create it
        log "INFO" "Creating host-specific Starship palette file: $host_palette_file"
        if [ "$TEST_MODE" -eq 1 ]; then
            debug_log "TEST MODE: Would copy $default_palette_file to $host_palette_file and inject colors."
        else
            cp "$default_palette_file" "$host_palette_file"
            if [ $? -eq 0 ]; then
                chmod 664 "$host_palette_file"
                log "INFO" "Successfully created $host_palette_file from $default_palette_file"
            else
                log "ERROR" "Failed to create $host_palette_file"
                exit 1
            fi
        fi
    fi
    
    # NOW inject DT_COLOR_* values into the host palette file only if user wants to update
    debug_log "should_update_palette=$should_update_palette"
    if [ "$should_update_palette" -eq 1 ]; then
        if [ -z "$color_status_bg" ] && [ -z "$color_activity_bg" ] && [ -z "$color_term_bg" ]; then
            log "WARN" "No DT_COLOR_* variables found. Skipping color injection."
        else
            debug_log "Injecting: hostc_user=$color_status_bg, dir_bg=$color_activity_bg, term_bg=$color_term_bg into $host_palette_file"
            # Use awk to update or insert color values in the [palettes.divtools] section
            awk -v sb="$color_status_bg" -v ab="$color_activity_bg" -v tb="$color_term_bg" '
                /^\[palettes\.divtools\]/ { in_section=1; print; next }
                in_section && /^hostc_user[[:space:]]*=/ {
                    if (sb != "") { print "hostc_user = \"" sb "\""; next }
                    else { print; next }
                }
                in_section && /^dir_bg[[:space:]]*=/ {
                    if (ab != "") { print "dir_bg = \"" ab "\""; next }
                    else { print; next }
                }
                in_section && /^term_bg[[:space:]]*=/ {
                    if (tb != "") { print "term_bg = \"" tb "\""; next }
                    else { print; next }
                }
                /^\[/ && !/^\[palettes\.divtools\]/ { in_section=0 }
                { print }
            ' "$host_palette_file" > "$host_palette_file.tmp" && mv "$host_palette_file.tmp" "$host_palette_file"
            
            # If colors were not found in file, append them
            if ! grep -q "hostc_user" "$host_palette_file" && [ -n "$color_status_bg" ]; then
                echo "hostc_user = \"$color_status_bg\"" >> "$host_palette_file"
            fi
            if ! grep -q "dir_bg" "$host_palette_file" && [ -n "$color_activity_bg" ]; then
                echo "dir_bg = \"$color_activity_bg\"" >> "$host_palette_file"
            fi
            if ! grep -q "term_bg" "$host_palette_file" && [ -n "$color_term_bg" ]; then
                echo "term_bg = \"$color_term_bg\"" >> "$host_palette_file"
            fi
            log "INFO" "Successfully updated colors in $host_palette_file"
        fi
    elif [ "$should_update_palette" -eq 0 ]; then
        log "INFO" "Skipping palette file update (user declined or non-interactive mode)"
    fi

    # Check if the default override file exists; if not, create a fallback DEFAULT.toml
    if [ ! -f "$default_override_file" ]; then
        log "INFO" "Default override file does not exist: $default_override_file"
        if [ "$default_host" != "DEFAULT" ]; then
            log "INFO" "Falling back to create or use $fallback_override_file"
            if [ ! -f "$fallback_override_file" ]; then
                log "INFO" "Creating default override file: $fallback_override_file"
                if [ "$TEST_MODE" -eq 1 ]; then
                    debug_log "TEST MODE: Would create $fallback_override_file with default content."
                else
                    cat > "$fallback_override_file" <<'OVERRIDE_EOF'
# Starship override configuration for divtools
# This file is automatically managed by dt_host_setup.sh
# Do not manually edit unless you know what you're doing

[hostname]
style = "bold green"
format = "[$hostname]($style) "

[username]
style_user = "bold cyan"
format = "[$user]($style_user)@"
OVERRIDE_EOF
                    chmod 664 "$fallback_override_file"
                    log "INFO" "Successfully created default override file: $fallback_override_file"
                fi
            fi
            default_override_file="$fallback_override_file"
        else
            log "ERROR" "Cannot create host-specific override file without a default. Please create $default_override_file manually."
            exit 1
        fi
    fi

    # Create host-specific override file if it doesn't exist
    if [ ! -f "$host_override_file" ]; then
        log "INFO" "Creating host-specific Starship override file: $host_override_file"
        if [ "$TEST_MODE" -eq 1 ]; then
            debug_log "TEST MODE: Would copy $default_override_file to $host_override_file."
        else
            cp "$default_override_file" "$host_override_file"
            if [ $? -eq 0 ]; then
                chmod 664 "$host_override_file"
                log "INFO" "Successfully created $host_override_file from $default_override_file"
            else
                log "ERROR" "Failed to create $host_override_file"
                exit 1
            fi
        fi
    else
        log "INFO" "Host-specific Starship override file already exists: $host_override_file"
    fi

    # Rebuild starship.toml to incorporate the new files
    if has_starship; then
        log "INFO" "Rebuilding Starship configuration..."
        # Source the build_starship_toml function from .bash_profile if available
        if [ -f "$DIVTOOLS/dotfiles/.bash_profile" ]; then
            source "$DIVTOOLS/dotfiles/.bash_profile"
            build_starship_toml
        else
            log "WARN" "$DIVTOOLS/dotfiles/.bash_profile not found. Cannot rebuild starship.toml."
        fi
    else
        log "INFO" "Starship is not installed; skipping starship.toml rebuild."
    fi
} # update_starship_cfg

# Function to setup the local host by creating host-specific files if they do not exist
dt_host_setup() {
    local default_host="$1"  # Use provided default hostname or fallback to "DEFAULT" (handled in sub-functions)
    local hostname="$HOSTNAME_U"  # Use uppercase hostname from environment

    log "INFO" "Starting host setup for $hostname..."
    
    # Show menu and get selected sections
    set_whiptail_colors
    local selected_sections=$(show_setup_menu)
    
    if [ -z "$selected_sections" ]; then
        log "INFO" "No sections selected. Exiting."
        exit 0
    fi

    ########################################
    ### ENV Vars Section                 ###
    ########################################
    if echo "$selected_sections" | grep -q "HOST"; then
        log "INFO" "Running HOST .env setup..."
        update_local_env_vars
    fi

    ########################################
    ### Starship Section                 ###
    ########################################
    if echo "$selected_sections" | grep -q "STARSHIP"; then
        log "INFO" "Running STARSHIP palette setup..."
        update_starship_cfg "$default_host"
    fi

    ########################################
    ### VS Code Section                  ###
    ########################################
    if echo "$selected_sections" | grep -q "VSCODE"; then
        log "INFO" "Running VS Code color setup..."
        local vscode_script="$DIVTOOLS/scripts/vscode/vscode_host_colors.sh"
        if [ -f "$vscode_script" ]; then
            log "INFO" "Calling $vscode_script..."
            if [ "$TEST_MODE" -eq 1 ]; then
                log "INFO" "TEST MODE: Would execute $vscode_script"
            else
                bash "$vscode_script"
                if [ $? -eq 0 ]; then
                    log "INFO" "VS Code color setup completed successfully."
                else
                    log "WARN" "VS Code color setup returned non-zero exit code."
                fi
            fi
        else
            log "WARN" "VS Code color script not found at $vscode_script. Skipping."
        fi
    fi

    log "INFO" "Local host setup completed for $hostname."
}

# Execute the function with the provided argument (if any)
dt_host_setup "$@"