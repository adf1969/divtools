# Set flag to prevent double-sourcing when .bashrc loads .bash_profile for VSCode
# Last Updated: 11/11/2025 9:35:00 PM CDT
export BASH_PROFILE_LOADED=1

# Exports
export DIVTOOLS="/opt/divtools"
export HOSTNAME_U=$(hostname -s | tr '[:lower:]' '[:upper:]')

# Global Env Vars
export DOCKERDIR=/opt/divtools/docker
export DOCKERDATADIR=/opt

################################################################################
# DIVTOOLS VERBOSITY CONTROL SYSTEM
# Last Updated: 11/11/2025
#
# OVERVIEW:
#   This system provides fine-grained control over output verbosity during
#   profile initialization. It uses a global DT_VERBOSE level combined with
#   section-specific thresholds to control which messages are displayed.
#
# GLOBAL VERBOSITY LEVEL (DT_VERBOSE):
#   0 = Silent       (only errors/critical output)
#   1 = Minimal      (errors + warnings)
#   2 = Normal       (errors + warnings + info/key operations)
#   3 = Verbose      (errors + warnings + info + debug messages)
#   4 = Debug        (everything, including low-level details)
#
# USAGE:
#   Default behavior (DT_VERBOSE=2):
#     source /etc/profile
#     sep              (using alias)
#
#   Silent mode (suppress STAR, SAMBA, etc.):
#     export DT_VERBOSE=0 && source /etc/profile
#     export DT_VERBOSE=0 && sep
#
#   Debug mode (see everything):
#     export DT_VERBOSE=4 && source /etc/profile
#     export DT_VERBOSE=4 && sep
#
# SECTION-LEVEL THRESHOLDS:
#   Each section (STAR, SAMBA, INFO, etc.) has a minimum DT_VERBOSE level
#   required for its messages to display. These are defined in DT_VERBOSITY_LEVELS
#   and can be overridden in .env files at the site or host level.
#
# CUSTOMIZATION:
#   To change defaults, either:
#   1. Set DT_VERBOSE in your shell before sourcing this file
#   2. Add to ~/.env or site/.env.hostname files:
#        export DT_VERBOSE=1
#        declare -gxA DT_VERBOSITY_LEVELS=(["STAR"]=3 ["SAMBA"]=1 ...)
#
# EXAMPLES:
#   Silence just Starship output:
#     Add to ~/.env: declare -gxA DT_VERBOSITY_LEVELS=(["STAR"]=999)
#
#   Only show errors:
#     export DT_VERBOSE=0 && sep
#
#   Full debug output:
#     export DT_VERBOSE=4 && sep
#
################################################################################

export DT_VERBOSE=${DT_VERBOSE:-2}

# Section-level verbosity thresholds (minimum DT_VERBOSE level to output)
# Set these to control output per section (STAR, SAMBA, etc.)
# Lower numbers = more restrictive (0=always, 1=only if DT_VERBOSE>=1, etc.)
declare -gxA DT_VERBOSITY_LEVELS=(
    ["STAR"]=2           # Starship build messages
    ["SAMBA"]=2          # Samba-related messages
    ["TMUX"]=2           # Tmux configuration messages
    ["INFO"]=2           # General info messages
    ["WARN"]=1           # Warning messages (show at higher levels)
    ["ERROR"]=0          # Error messages (always show)
    ["DEBUG"]=3          # Debug messages (only at DT_VERBOSE=3+)
)

################################################################################

# Load Local Overrides, if they exist
if [ -f ~/.env ]; then
    . ~/.env
fi

# Check for SITE_NAME and warn if missing
# Last Updated: 11/5/2025 2:45:00 PM CST
if [ -z "$SITE_NAME" ]; then
    # Try /root/.env if running as root
    if [ "$HOME" = "/root" ] && [ -f "/root/.env" ]; then
        . /root/.env
    fi
    # Try /home/divix/.env as fallback
    if [ -z "$SITE_NAME" ] && [ -f "/home/divix/.env" ]; then
        . /home/divix/.env
    fi
    
    # If still not set, display prominent warning
    if [ -z "$SITE_NAME" ]; then
        echo -e "\e[48;5;52m\e[97m╔═════════════════════════════════════════════════════════════════════════════╗\e[m" >&2
        echo -e "\e[48;5;52m\e[97m║                            ⚠️  CRITICAL WARNING ⚠️                           ║\e[m" >&2
        echo -e "\e[48;5;52m\e[97m╠═════════════════════════════════════════════════════════════════════════════╣\e[m" >&2
        echo -e "\e[48;5;52m\e[97m║  SITE_NAME environment variable is NOT SET!                                ║\e[m" >&2
        echo -e "\e[48;5;52m\e[97m║                                                                             ║\e[m" >&2
        echo -e "\e[48;5;52m\e[97m║  This will cause ALL docker compose scripts to FAIL!                       ║\e[m" >&2
        echo -e "\e[48;5;52m\e[97m║                                                                             ║\e[m" >&2
        echo -e "\e[48;5;52m\e[97m║  To fix this issue:                                                         ║\e[m" >&2
        echo -e "\e[48;5;52m\e[97m║  1. Run: \$DIVTOOLS/scripts/dt_host_setup.sh                                ║\e[m" >&2
        echo -e "\e[48;5;52m\e[97m║     OR                                                                      ║\e[m" >&2
        echo -e "\e[48;5;52m\e[97m║  2. Add to ~/.env:  export SITE_NAME=<your-site-name>                      ║\e[m" >&2
        echo -e "\e[48;5;52m\e[97m╚═════════════════════════════════════════════════════════════════════════════╝\e[m" >&2
        echo "" >&2
    fi
fi

# Clear any residual Starship environment variables
unset STARSHIP_START_TIME STARSHIP_PREEXEC_READY STARSHIP_SHELL STARSHIP_SESSION_KEY

# Initialize prompt with fallback
unset PS1
unset PROMPT_COMMAND
PROMPT_COMMAND="set_title; build_prompt"

export DOCKERFILE=$DOCKERDIR/docker-compose-$HOSTNAME.yml

# Global UID Vars for LXCs. These are what the local LXC UIDs become when read by the HOST.
# This is because ALL uids in an LXC container are "mapped" to the host as LXC uid + 100000
# So UID 1400 in the LXC becomes 101400 at the host (proxmox).
# And UID 0 (root) in the LXC, becomes 100000 at the host (proxmox)
export LXC_UID_ROOT=100000
export LXC_UID_DIVIX=101400


### LOGGING FUNCTION ###
# Function to log messages with color-coded output based on section
function log_msg_tput() {
    local section="$1"
    local text="$2"
    local color

    # Map human-readable color names to tput setaf numbers (256-color palette)
    declare -A color_map=(
        ["red"]="1"           # Standard red (ERROR)
        ["yellow"]="3"        # Standard yellow (WARNING)
        ["green"]="2"         # Standard green (INFO)
        ["cyan"]="6"          # Standard cyan (DEBUG)
        ["white"]="7"         # Standard white (default)
        ["pink"]="13"         # From C_PINK
        ["orange"]="214"      # From C_ORANGE
        ["lightgreen"]="119"  # From C_LIGHTGREEN
        ["purple"]="129"      # From C_PURPLE
        ["lightblue"]="123"   # From C_LIGHTBLUE
        ["brown"]="130"       # From C_BROWN
        ["lightcyan"]="152"   # From C_LIGHTCYAN
        ["gold"]="220"        # From C_GOLD
        ["lightpurple"]="177" # From C_LIGHTPURPLE
        ["darkblue"]="19"     # From C_DARKBLUE
        ["lightyellow"]="229" # From C_LIGHTYELLOW
        ["teal"]="37"         # From C_TEAL
        ["salmon"]="210"      # From C_SALMON
        ["violet"]="171"      # From C_VIOLET
        ["lime"]="154"        # From C_LIME
        ["darkgray"]="236"    # From C_DARKGRAY
    )

    # Set color based on section
    case "$section" in
        STAR)
            color_name="yellow"
            ;;
        TMUX)
            color="cyan"
            ;;            
        ERROR)
            color_name="red"
            ;;
        WARNING)
            color_name="yellow"
            ;;
        INFO)
            color_name="green"
            ;;
        DEBUG)
            color_name="cyan"
            ;;
        *)
            color_name="white"
            ;;
    esac

    # Get the tput color code
    color=$(tput setaf "${color_map[$color_name]}")

    # Output the message with section and text, resetting color afterward
    echo -e "${color}[${section}] ${text}$(tput sgr0)"
}

# Function to log messages with color-coded output based on section
# Respects DT_VERBOSE and DT_VERBOSITY_LEVELS settings
# Last Updated: 11/11/2025
#
# USAGE:
#   log_msg "SECTION" "message"           # Basic usage
#   log_msg "SECTION:TAG" "message"       # Use custom color tag (TAG becomes color_tag)
#   log_msg "SECTION:!ts" "message"       # Suppress timestamp (for use in .bash_profile)
#   log_msg "SECTION:raw" "message"       # Raw output (no timestamp, no section tag)
#
# EXAMPLES:
#   log_msg "INFO" "Starting initialization"
#   log_msg "STAR:cyan" "Using cyan instead of yellow"
#   log_msg "INFO:!ts" "No timestamp on this message"
#   log_msg "ERROR:raw" "Just the message, no extras"
#
# IMPORTANT: Sync Notes
# ═══════════════════════════════════════════════════════════════════════════
# This is the PRIMARY logging implementation used throughout the codebase.
# When adding new sections or colors, update BOTH:
# 1. This function: /home/divix/divtools/dotfiles/.bash_profile (log_msg)
# 2. Fallback function: /home/divix/divtools/scripts/util/logging.sh (log)
# 
# The logging.sh script will prefer this implementation when .bash_profile
# is already sourced, but falls back to log() if not available.
# ═══════════════════════════════════════════════════════════════════════════
function log_msg() {
    local section_str="$1"
    local text="$2"
    local color
    local color_name="white"
    local section=""
    local no_timestamp=0
    local no_tag=0
    local prefix_str=""
    
    # Parse section string by splitting on :
    # Supports: "SECTION", "SECTION:TAG", "SECTION:!ts", "SECTION:raw"
    IFS=':' read -r -a parts <<< "$section_str"
    section="${parts[0]}"
    color_name="$section"  # Default to section for color
    
    # Process additional parts as modifiers
    for (( i=1; i<${#parts[@]}; i++ )); do
        local part="${parts[i]}"
        local part_lower="${part,,}"
        if [[ "$part_lower" == "!ts" ]]; then
            no_timestamp=1
        elif [[ "$part_lower" == "raw" ]]; then
            no_timestamp=1
            no_tag=1
        else
            # Use as custom color tag
            color_name="$part"
        fi
    done
    
    # Ensure DT_VERBOSE is set
    if [ -z "$DT_VERBOSE" ]; then
        export DT_VERBOSE=2
    fi
    
    # Check if this section's verbosity threshold is met
    # DT_VERBOSITY_LEVELS is an associative array with thresholds for each section
    local verbosity_threshold=${DT_VERBOSITY_LEVELS[$section]:-2}
    
    # Only output if current verbosity level >= section's threshold
    if [ "$DT_VERBOSE" -lt "$verbosity_threshold" ]; then
        return 0  # Silently return without outputting
    fi

    # Map human-readable color names to ANSI escape codes (256-color palette)
    declare -A color_map=(
        ["red"]="\e[31m"          # Standard red (matches C_RED)
        ["yellow"]="\e[33m"       # Standard yellow (matches C_YELLOW)
        ["green"]="\e[32m"        # Standard green (matches C_GREEN)
        ["cyan"]="\e[36m"         # Standard cyan (matches C_CYAN)
        ["white"]="\e[37m"        # Standard white (matches C_WHITE)
        ["pink"]="\e[38;5;13m"    # Matches C_PINK
        ["orange"]="\e[38;5;214m" # Matches C_ORANGE
        ["lightgreen"]="\e[38;5;119m" # Matches C_LIGHTGREEN
        ["purple"]="\e[38;5;129m" # Matches C_PURPLE
        ["lightblue"]="\e[38;5;123m" # Matches C_LIGHTBLUE
        ["brown"]="\e[38;5;130m"  # Matches C_BROWN
        ["lightcyan"]="\e[38;5;152m" # Matches C_LIGHTCYAN
        ["gold"]="\e[38;5;220m"   # Matches C_GOLD
        ["lightpurple"]="\e[38;5;177m" # Matches C_LIGHTPURPLE
        ["darkblue"]="\e[38;5;19m" # Matches C_DARKBLUE
        ["lightyellow"]="\e[38;5;229m" # Matches C_LIGHTYELLOW
        ["teal"]="\e[38;5;37m"    # Matches C_TEAL
        ["salmon"]="\e[38;5;210m" # Matches C_SALMON
        ["violet"]="\e[38;5;171m" # Matches C_VIOLET
        ["lime"]="\e[38;5;154m"   # Matches C_LIME
        ["darkgray"]="\e[38;5;236m" # Matches C_DARKGRAY
    )

    # Set color based on color_name (which is either section or custom tag)
    case "$color_name" in
        SAMBA|samba)
            color="\e[38;5;123m"  # Light blue
            ;;
        STAR|star)
            color="\e[33m"        # Yellow
            ;;            
        TMUX|tmux)        
            color="\e[36m"        # Cyan
            ;;
        ERROR|error)
            color="\e[31m"        # Red
            ;;
        WARN|WARNING|warn|warning)
            color="\e[33m"        # Yellow
            ;;
        INFO|info)
            color="\e[32m"        # Green
            ;;
        DEBUG|debug)
            color="\e[36m"        # Cyan
            ;;
        *)
            # Try to look up in color_map as fallback
            color="${color_map[$color_name]:-\e[37m}"  # Default to white
            ;;
    esac

    # Build the output
    local output=""
    if [[ $no_tag -eq 0 ]]; then
        prefix_str="[$section] "
    fi
    output="${prefix_str}${text}"

    # Output the message with color, resetting color afterward
    echo -e "${color}${output}\e[m" >&2
}


update_profile_timestamp() {
    # Update profile sourced timestamp
    # This tracks when this profile was LAST sourced so I can update starship with this data
    mkdir -p "$HOME/.config"
    date +%s > "$HOME/.config/profile_sourced_timestamp"
}

# Function to check if Starship is installed and functional
# has_starship() {
#     command -v starship &> /dev/null && starship --version &> /dev/null
# }

# Function to check if Starship is installed and functional
has_starship() {
    local starship_bin
    # Search for starship in PATH or common QNAP locations
    starship_bin=$(command -v starship 2>/dev/null || find /mnt/tpool/local/bin /opt/bin -type f -name starship 2>/dev/null | head -n 1)
    [ -n "$starship_bin" ] && [ -x "$starship_bin" ] && "$starship_bin" --version &>/dev/null
}

# Function to check if ZFS filesystem
has_opencode() {
  command -v opencode &> /dev/null
}

# Function to check if EZA is installed
has_eza() {
  command -v eza &> /dev/null
}

# Function to check if ZFS filesystem
has_zfs() {
  command -v zfs &> /dev/null
}

# Function to check if ZFS filesystem
has_qm() {
  command -v qm &> /dev/null
}

# Function to add a directory to PATH if it exists
function add_to_path() {
    local dir="$1"
    local section="${2:-INFO}"  # Default section is INFO
    local silent="${3:-0}"      # Default is verbose (0 = verbose, 1 = silent)

    # Check if the directory exists
    if [[ -d "$dir" ]]; then
        # Check if it's already in PATH
        if [[ ":$PATH:" != *":$dir:"* ]]; then
            export PATH="$dir:$PATH"
            if [[ "$silent" -eq 0 ]]; then
                log_msg "$section" "Added $dir to PATH."
            fi
            return 0
        else
            if [[ "$silent" -eq 0 ]]; then
                log_msg "$section" "$dir is already in PATH."
            fi
            return 0
        fi
    else
        if [[ "$silent" -eq 0 ]]; then
            log_msg "$section" "Directory $dir does not exist."
        fi
        return 1
    fi
}



# Function to set PuTTY window title
# Format: HOST:port - user@host [path]
function set_title {
  local tty_num=$(tty | sed 's:/dev/pts/::')
  local host_ip=$(hostname -s)
  local hostname_u=$(echo "$host_ip" | tr '[:lower:]' '[:upper:]')
  local user=$(whoami)
  local path=$(pwd)
  
  local title="${tty_num}"
  # Include TTY_TITLE if it is set
  if [ -n "$TTY_TITLE" ]; then
    title="$title:${TTY_TITLE}"
  fi
  title="${hostname_u}:${title}"
  #echo -ne "\033]0;${title} - ${user}@${host_ip} [${path}]\007"
  echo -ne "\033]0;${title} - ${user}@${host_ip} [${path}]\007"
}

check_git_repo() {
    if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        echo "G"
    fi
}


# Function to check Git sync status
check_git_sync() {    
    local FETCH=$1

    # Only run if GIT_SET_PROMPT is set to 1 or FETCH is set to 1
    if [ "$GIT_SET_PROMPT" = "1" ] || [ "$FETCH" = "1" ]; then
        # Check if we are in a Git repository        
        if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
            # Check if the remote repository 'origin' exists            
            if git remote | grep -q '^origin$'; then            
                # Only fetch if FETCH is set to 1
                if [ "$FETCH" = "1" ]; then
                    git fetch origin -q
                    echo -e "Fetched Origin"
                else                              
                  # Get the current branch name
                  local branch=$(git rev-parse --abbrev-ref HEAD)

                  # Compare local and remote branches
                  local local_commit=$(git rev-parse $branch)
                  local remote_commit=$(git rev-parse origin/$branch)
                  local base_commit=$(git merge-base $branch origin/$branch)

                  if [ "$local_commit" = "$remote_commit" ]; then
                      # In sync
                      echo -e "${C_GREEN}✔${C_RESET}" # Green check mark
                  elif [ "$local_commit" = "$base_commit" ]; then
                      # Behind
                      echo -e "${C_RED}✘${C_RESET}" # Red cross mark
                  elif [ "$remote_commit" = "$base_commit" ]; then
                      # Ahead
                      echo -e "${C_YELLOW}⇡${C_RESET}" # Yellow arrow
                  else
                      # Diverged
                      echo -e "${C_RED}⚠${C_RESET}" # Red warning
                  fi
                fi
            fi
        fi
    fi
}


check_git_sync_quick() {
    # Check if we are in a Git repository
    if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        # Get the current branch name
        local branch=$(git rev-parse --abbrev-ref HEAD)

        # Check if the branch is in sync with the remote
        local status=$(git status -sb)
        
        if [[ $status == *"behind"* ]]; then
            echo -e "\[\033[0;31m\] âœ˜ " # Red cross mark (behind)
        elif [[ $status == *"ahead"* ]]; then
            echo -e "\[\033[0;33m\] > " # Yellow arrow (ahead)
        elif [[ $status == *"diverged"* ]]; then
            echo -e "\[\033[0;31m\] ! " # Red warning (diverged)
        else
            echo -e "\[\033[0;32m\] âœ” " # Green check mark (in sync)
        fi
    else
        echo ""
    fi
}

gitpon_func() {
    export GIT_SET_PROMPT=1
    check_git_sync 1
}

gitpoff_func() {
    export GIT_SET_PROMPT=0
    check_git_sync 1
}


# Function to dynamically build the PS1 prompt
build_prompt() {
  local PS1_ROOT=""
  local PS1_CHAR=""
  case "$(whoami)" in
    admin|root)
      PS1_ROOT="${C_BG_RED}${C_WHITE}ROOT${C_RESET} "
      PS1_CHAR="#"
      ;;
    *)
      PS1_CHAR="\$"
      ;;
  esac

  # Git Repo
  GIT_CHAR=$(check_git_repo)
  if [ -n "$GIT_CHAR" ]; then
      GIT_CHAR="${C_BG_BRIGHTBLUE}${C_BLACK}${GIT_CHAR}${C_RESET}"      
  fi  

  local PS1_PROMPT=""
  #case "$(hostname -s | tr '[:lower:]' '[:upper:]')" in
  
  case "${HOSTNAME_U}" in
    FHM4X8)
      HOST_COL=${C_GREEN}
      #PS1_PROMPT="${C_GREEN}[\u@\h \w]${PS1_CHAR}${C_RESET}"
      ;;
    FHMTN1)
      HOST_COL=${C_BRIGHTBLUE}
      #PS1_PROMPT="${C_BRIGHTBLUE}[\u@\h \w]${PS1_CHAR}${C_RESET}"
      ;;
    CVGNAS1)
      HOST_COL=${C_CYAN}
      #PS1_PROMPT="${C_CYAN}[\u@\h \w]${PS1_CHAR}${C_RESET}"
      ;;
    TNHL01)
      HOST_COL=${C_ORANGE}
      #PS1_PROMPT="${C_ORANGE}[\u@\h \w]${PS1_CHAR}${C_RESET}"      
      ;;
    *)
    # Only set HOST_COL to ${C_WHITE} if it is not already set
      : "${HOST_COL:=${C_WHITE}}"
      #HOST_COL=${C_WHITE}
      #PS1_PROMPT="${C_WHITE}[\u@\h \w]${PS1_CHAR}${C_RESET}"
      ;;
  esac

  # Single-Line PS1
  #PS1="${PS1_ROOT}$(check_git_sync)${PS1_PROMPT} "

  # Multi-line PS1
  PS1="${HOST_COL}┌──(${C_BOLD}\u@\h${C_BOLD_OFF})-[\w]\n${HOST_COL}└─${PS1_ROOT}${GIT_CHAR}$(check_git_sync) ${HOST_COL}${PS1_CHAR}${C_RESET} "  

}

### STARSHIP FUNCTIONS ###

function build_starship_toml() {
    local DT_STARSHIP_DIR="$DIVTOOLS/config/starship"
    local DT_STARSHIP_PRESET_DIR="$DT_STARSHIP_DIR/presets"
    local DT_STARSHIP_OVERRIDE_DIR="$DT_STARSHIP_DIR/overrides"
    local DT_STARSHIP_PALETTE_DIR="$DT_STARSHIP_DIR/palettes"
    local STARSHIP_CONFIG_DIR="$HOME/.config"
    local STARSHIP_CONFIG_FILE="$STARSHIP_CONFIG_DIR/starship.toml"

    # Set default preset if not set
    if [ -z "$DT_STARSHIP_PRESET" ]; then
        DT_STARSHIP_PRESET="pastel-powerline-dt"
    fi

    # Set default palette if not set
    if [ -z "$DT_STARSHIP_PALETTE" ]; then
        DT_STARSHIP_PALETTE="divtools"
    fi

    # Create .config directory if it doesn't exist
    mkdir -p "$STARSHIP_CONFIG_DIR"

    # Build starship.toml file
    build_starship_toml_header "$STARSHIP_CONFIG_FILE"
    build_starship_toml_preset "$STARSHIP_CONFIG_FILE" "$DT_STARSHIP_PRESET_DIR" "$DT_STARSHIP_OVERRIDE_DIR"
    build_starship_toml_palette "$STARSHIP_CONFIG_FILE" "$DT_STARSHIP_PALETTE_DIR"

    # Output the location of the generated file
    #echo "Starship configuration built successfully at: $STARSHIP_CONFIG_FILE"
    log_msg "STAR" "Starship configuration built successfully at: $STARSHIP_CONFIG_FILE"
} # build_starship_toml



function build_starship_toml_header() {
    local STARSHIP_CONFIG_FILE="$1"
    local build_date=$(date)

    # Create header for the starship.toml file
    cat > "$STARSHIP_CONFIG_FILE" <<EOF
###########################################################
###             DO NOT EDIT THIS FILE                   ###
###  EDIT THE FILES USED TO BUILD IT INDICATED BELOW    ###
###                                                     ###
###  After editing, run build_starship_toml to rebuild  ###
###  Build Date: $build_date
###########################################################

EOF
} # build_starship_toml_header

function build_starship_toml_preset() {
    local STARSHIP_CONFIG_FILE="$1"
    local DT_STARSHIP_PRESET_DIR="$2"
    local DT_STARSHIP_OVERRIDE_DIR="$3"
    local hostname=$(hostname)
    log_msg "STAR" "DT_STARSHIP_PRESET is set to '$DT_STARSHIP_PRESET'"

    # Check if the preset file exists and process it
    local preset_file="$DT_STARSHIP_PRESET_DIR/$DT_STARSHIP_PRESET.toml"
    if [ -f "$preset_file" ]; then
        log_msg "STAR" "Processing preset file: $preset_file"

        # Add palette reference to the starship.toml file
        cat <<EOF >> "$STARSHIP_CONFIG_FILE"
###
### Palette: 
palette = "${DT_STARSHIP_PALETTE}"
###

EOF

        # Extract and handle override sections as before
        local hostname_override_file=$(find "$DT_STARSHIP_OVERRIDE_DIR" -maxdepth 1 -type f -iname "${hostname}.toml" | head -n 1)
        # Fallback to exact case if find doesn't return a result
        if [ -z "$hostname_override_file" ]; then
            hostname_override_file="$DT_STARSHIP_OVERRIDE_DIR/${hostname}.toml"
        fi            

        #local override_file="$DT_STARSHIP_OVERRIDE_DIR/$HOSTNAME.toml"
        local override_file="$hostname_override_file"        
        local override_sections=()
        if [ -f "$override_file" ]; then
            log_msg "STAR" "Processing override file: $override_file"
            override_sections=($(grep -oP '^\[\K[^]]+' "$override_file"))
        fi

        # Track sections removed from the preset
        declare -A removed_sections_map

        # Generate unique temporary file names
        local tmp_preset_file=$(mktemp)
        local tmp_removed_sections_file=$(mktemp)

        # Filter out sections from the preset file that exist in the override file
        awk -v sections="${override_sections[*]}" '
        BEGIN {
            split(sections, section_array)
            for (i in section_array) section_map[section_array[i]] = 1
        }
        /^\[.*\]/ {
            section = substr($0, 2, length($0) - 2)
        }
        section_map[section] {
            if (!removed_sections_map[section]++) {
                removed_sections = removed_sections ? removed_sections "," section : section
            }
            next
        }
        { print }
        END { print removed_sections > "'"$tmp_removed_sections_file"'" }
        ' "$preset_file" > "$tmp_preset_file"

        # Read and log removed sections
        local removed_sections=""
        if [ -s "$tmp_removed_sections_file" ]; then
            removed_sections=$(cat "$tmp_removed_sections_file")
            log_msg "STAR" "Removed sections from preset file: $removed_sections"
            rm "$tmp_removed_sections_file"
        fi

        # Append the filtered preset file to the starship.toml
        cat <<EOF >> "$STARSHIP_CONFIG_FILE"
###
### Source: $preset_file
### Sections overridden: ${removed_sections:-None}
###
EOF
        cat "$tmp_preset_file" >> "$STARSHIP_CONFIG_FILE"
        log_msg "STAR" "Added filtered preset file to $STARSHIP_CONFIG_FILE"
        rm "$tmp_preset_file"
    fi

    # Append the override file directly to the starship.toml
    if [ -f "$override_file" ]; then
        log_msg "STAR" "Appending override file: $override_file to $STARSHIP_CONFIG_FILE"
        cat <<EOF >> "$STARSHIP_CONFIG_FILE"
###
### Source: $override_file
###
EOF
        cat "$override_file" >> "$STARSHIP_CONFIG_FILE"
        log_msg "STAR" "Added override file to $STARSHIP_CONFIG_FILE"
    fi
} # build_starship_toml_preset




function build_starship_toml_palette() {
    local STARSHIP_CONFIG_FILE=$1
    local hostname=$(hostname)
    local palette_file="$DT_STARSHIP_PALETTE_DIR/$DT_STARSHIP_PALETTE.toml"
    #local hostname_palette_file="$DT_STARSHIP_PALETTE_DIR/$DT_STARSHIP_PALETTE-${hostname}.toml"
    local hostname_palette_file=$(find "$DT_STARSHIP_PALETTE_DIR" -maxdepth 1 -type f -iname "divtools-${hostname}.toml" | head -n 1)
    # Fallback to exact case if find doesn't return a result
    if [ -z "$hostname_palette_file" ]; then
        hostname_palette_file="$DT_STARSHIP_PALETTE_DIR/divtools-${hostname}.toml"
    fi    

    # Associative arrays to hold palette entries and comments per section
    declare -A palette_sections
    declare -A palette_comments
    declare -A palette_sources

    # Function to parse a palette file and store entries under the correct section
    parse_palette_file() {
        local file=$1
        local source_label=$2
        local current_section=""
        log_msg "STAR" "Parsing palette file: $file"

        while IFS= read -r line; do
            #echo "Reading line: $line"  # Debug: Output each line

            # Skip comment lines and empty lines
            if [[ $line =~ ^# ]] || [[ -z $line ]]; then
                #echo "Skipping comment/empty line: $line"
                continue
            fi

            # Detect the palette section
            if [[ $line =~ ^\[palettes\.(.*)\]$ ]]; then
                current_section="${BASH_REMATCH[1]}"
                log_msg "STAR" "Detected palette section: $current_section"
                continue
            fi

            # Only process lines within a recognized section
            if [[ -n "$current_section" && $line =~ ^[[:space:]]*([a-zA-Z0-9_-]+)[[:space:]]*=[[:space:]]*\"(#[0-9a-fA-F]{6})\"[[:space:]]*(#.*)?$ ]]; then
                local key="${BASH_REMATCH[1]}"
                local value="${BASH_REMATCH[2]}"
                local comment="${BASH_REMATCH[3]:-}"

                # If the comment exists, strip the leading "# " and any extra spaces
                if [[ -n "$comment" ]]; then
                    comment="${comment#"#"}"  # Remove leading "#"
                    comment="${comment#"${comment%%[![:space:]]*}"}"  # Trim any leading spaces
                fi

                # Override or add the entry
                if [[ -z "${palette_sections[$current_section,$key]}" || "$source_label" == "$hostname" ]]; then
                    palette_sections[$current_section,$key]=$value
                    palette_comments[$current_section,$key]=$comment
                    palette_sources[$current_section,$key]=$source_label
                    #echo "Stored color entry: $key = $value from $source_label with comment: $comment"
                fi
            else
                log_msg "STAR" "Line did not match expected pattern: $line"
            fi
        done < "$file"
    }

    # Parse the main palette file
    if [ -f "$palette_file" ]; then
        log_msg "STAR" "Processing main palette file: $palette_file"
        parse_palette_file "$palette_file" "divtools"
    else
        log_msg "STAR" "Main palette file not found: $palette_file"
    fi

    # Parse the hostname-specific palette file and override entries
    if [ -f "$hostname_palette_file" ] && [ -s "$hostname_palette_file" ]; then
        log_msg "STAR" "Processing hostname-specific palette file: $hostname_palette_file"
        parse_palette_file "$hostname_palette_file" "$hostname"
    else
        log_msg "STAR" "Hostname-specific palette file not found or empty: $hostname_palette_file"
    fi

    # Write the combined palette to the starship.toml file
    if [ ${#palette_sections[@]} -eq 0 ]; then
        log_msg "STAR" "No palette entries found to write to $STARSHIP_CONFIG_FILE"
    else
        echo -e "\n# Color Palette: $DT_STARSHIP_PALETTE" >> "$STARSHIP_CONFIG_FILE"
        echo -e "\n###\n### Source:   $palette_file" >> "$STARSHIP_CONFIG_FILE"
        echo -e "### Override: $hostname_palette_file\n###" >> "$STARSHIP_CONFIG_FILE"

        # Output each palette section separately
        for section in $(printf "%s\n" "${!palette_sections[@]}" | awk -F',' '{print $1}' | sort -u); do
            echo -e "\n[palettes.$section]" >> "$STARSHIP_CONFIG_FILE"
            for key in $(printf "%s\n" "${!palette_sections[@]}" | grep "^$section," | awk -F',' '{print $2}' | sort); do
                local value="${palette_sections[$section,$key]}"
                local comment="${palette_comments[$section,$key]}"
                local source="${palette_sources[$section,$key]}"

                # Construct the full comment
                if [[ -n "$comment" ]]; then
                    echo "$key = \"$value\" # $source: $comment" >> "$STARSHIP_CONFIG_FILE"
                else
                    echo "$key = \"$value\" # $source" >> "$STARSHIP_CONFIG_FILE"
                fi
            done
            log_msg "STAR" "Written entries for section: $section"
        done

        log_msg "STAR" "Combined and written palette entries to $STARSHIP_CONFIG_FILE"
    fi
} # build_starship_toml_palette

update_link() {
    local SOURCE="$1"
    local TARGET="$2"
    local SECTION="${3:-INFO}"  # Default section is INFO, can be overridden

    # Check if the source file exists
    if [[ -f "$SOURCE" || -d "$SOURCE" ]]; then
        # Check if the target is already a symbolic link
        if [[ -L "$TARGET" ]]; then
            log_msg "$SECTION" "Soft link for $TARGET already exists."
        else
            # Create the symbolic link
            ln -s "$SOURCE" "$TARGET"
            log_msg "$SECTION" "Soft link created: $TARGET -> $SOURCE"
        fi
    else
        log_msg "WARN" "Source file or directory does not exist: $SOURCE"
    fi    
}


# Create Directory/File Links
# ~/.tmux.conf -> $DIVTOOLS/config/tmux/.tmux.conf
# ~/.tmux/ -> $DIVTOOLS/config/tmux
# ~/.config/tmux -> $DIVTOOLS/config/tmux       # this is a dupe of ~/.tmux/
#
tmux_config() {
    # Where are the tmux config files stored in divtools
    TM_SOURCE="$DIVTOOLS/config/tmux"

    # ~/.tmux.conf
    # Define Source/Target of the files to be created in home dir for .tmux.conf
    CFG_SOURCE="$TM_SOURCE/.tmux.conf"
    CFG_TARGET="$HOME/.tmux.conf"
    update_link "$CFG_SOURCE" "$CFG_TARGET" "TMUX"


    # ~/.tmux/
    DTM_TARGET="$HOME/.tmux"
    update_link "$TM_SOURCE" "$DTM_TARGET" "TMUX"

    # ~/.config/tmux
    CTM_TARGET="$HOME/.config/tmux"
    # Ensure the .config folder exists
    mkdir -p "$HOME/.config"
    # Map the .config/tmux -> $DIVTOOLS/config/tmux
    update_link "$TM_SOURCE" "$CTM_TARGET" "TMUX"
}



### DOCKER FUNCTIONS ###


### ENV VAR FUNCTIONS ###

# Function to check InfluxDB environment variables and set defaults if missing
# Last Updated: 11/5/2025 12:55:00 AM CDT
confirm_influxdb_vars() {
    # Check if all required InfluxDB variables are set
    if [ -z "$INFLUXDB_IP" ] || [ -z "$INFLUXDB_PORT" ] || [ -z "$INFLUXDB_API_TOKEN" ] || [ -z "$INFLUXDB_ORG" ] || [ -z "$INFLUXDB_BUCKET" ]; then
        [ "${DT_DEBUG,,}" == "1" -o "${DT_DEBUG,,}" == "true" ] && log_msg "WARNING" "Missing required InfluxDB settings in environment (expected in ${DOCKERDIR}/sites/s00-shared/.env.s00-shared). Falling back to defaults." >&2
        export INFLUXDB_IP="<influxdb-ip>"
        export INFLUXDB_PORT="8086"
        export INFLUXDB_API_TOKEN="<your-influxdb-token>"
        export INFLUXDB_ORG="your-org"
        export INFLUXDB_BUCKET="proxmox"
    else
        [ "${DT_DEBUG,,}" == "1" -o "${DT_DEBUG,,}" == "true" ] && log_msg "DEBUG" "InfluxDB variables set: INFLUXDB_IP=${INFLUXDB_IP}, INFLUXDB_PORT=${INFLUXDB_PORT}, INFLUXDB_API_TOKEN=****, INFLUXDB_ORG=${INFLUXDB_ORG}, INFLUXDB_BUCKET=${INFLUXDB_BUCKET}" >&2
    fi
    return 0
} # confirm_influxdb_vars


# Function to find file with case-insensitive variations
# Last Updated: 10/22/2025 8:35:00 PM CDT
find_file_case_insensitive() {
    local dir="$1"
    local prefix="$2"
    local var="$3"
    local suffix="$4"
    local candidates=()

    if [ -z "${var}" ]; then
        local filename="${prefix}${suffix}"
        local upper_filename=$(echo "${filename}" | tr '[:lower:]' '[:upper:]')
        local lower_filename=$(echo "${filename}" | tr '[:upper:]' '[:lower:]')
        candidates=("${dir}/${filename}" "${dir}/${upper_filename}" "${dir}/${lower_filename}")
    else
        local exact="${dir}/${prefix}${var}${suffix}"
        local upper_var=$(echo "${var}" | tr '[:lower:]' '[:upper:]')
        local lower_var=$(echo "${var}" | tr '[:upper:]' '[:lower:]')
        local upper="${dir}/${prefix}${upper_var}${suffix}"
        local lower="${dir}/${prefix}${lower_var}${suffix}"
        candidates=("${exact}" "${upper}" "${lower}")
    fi

    for candidate in "${candidates[@]}"; do
        if [ -f "${candidate}" ]; then
            echo "${candidate}"
            return 0
        fi
    done

    return 1
} # find_file_case_insensitive


# Function to check for required environment variables
# Last Updated: 11/5/2025 12:50:00 AM CDT
check_required_env_vars() {
    local missing_vars=()
    
    # Try to load ~/.env if it exists (for the actual user, not root)
    # Check both current user's home and /home/divix
    local env_file="$HOME/.env"
    local divix_env="/home/divix/.env"
    
    if [ -f "$env_file" ] && [ "$env_file" != "/root/.env" ]; then
        source "$env_file"
    elif [ -f "$divix_env" ] && [ "$HOME" = "/root" ]; then
        # If running as root, try divix's .env file
        source "$divix_env"
    fi
    
    # Check for SITE_NAME - this is CRITICAL and must exist
    if [ -z "$SITE_NAME" ]; then
        missing_vars+=("SITE_NAME")
    fi
    
    # If any required vars are missing, alert user and guide them to dt_host_setup.sh
    if [ ${#missing_vars[@]} -gt 0 ]; then
        log_msg "ERROR" "Required environment variable(s) missing: ${missing_vars[*]}" >&2
        log_msg "ERROR" "SITE_NAME is required for proper docker compose file location." >&2
        log_msg "INFO" "Please run: \$DIVTOOLS/scripts/dt_host_setup.sh to configure your environment." >&2
        log_msg "INFO" "Or manually add 'export SITE_NAME=<your-site-name>' to ~/.env" >&2
        return 1
    fi
    
    return 0
} # check_required_env_vars

# Function to load .env files with support for both V1 and V2 configuration modes
# Last Updated: 11/5/2025 12:15:00 AM CDT
load_env_files() {
    # Ensure HOSTNAME is set
    if [ -z "$HOSTNAME" ]; then
        export HOSTNAME=$(hostname)
        [ "${DT_DEBUG,,}" == "1" -o "${DT_DEBUG,,}" == "true" ] && log_msg "DEBUG" "Set HOSTNAME=${HOSTNAME}" >&2
    fi
    
    # Define base paths - use known locations
    # Last Updated: 11/11/2025 9:15:00 PM CDT
    local docker_dir="${DOCKERDIR:-/opt/divtools/docker}"
    local shared_dir="${docker_dir}/sites/s00-shared"
    
    # === ALWAYS LOAD SHARED .env FIRST ===
    # The shared .env is at a KNOWN location and should always be loaded if it exists
    # This provides DT_INCLUDE_* and other shared configuration variables
    # Last Updated: 11/11/2025 9:15:00 PM CDT
    local shared_env_file
    shared_env_file=$(find_file_case_insensitive "${shared_dir}" ".env." "s00-shared" "")
    if [ -n "$shared_env_file" ]; then
        source "$shared_env_file" || {
            log_msg "ERROR" "Failed to source shared settings from $shared_env_file" >&2
            return 1
        }
        log_msg "INFO" "Sourced shared settings from $shared_env_file" >&2
    else
        [ "${DT_DEBUG,,}" == "1" -o "${DT_DEBUG,,}" == "true" ] && log_msg "WARNING" "Shared .env not found in $shared_dir" >&2
    fi
    
    # Check for required environment variables in ~/.env
    # This may fail if SITE_NAME isn't set, which is OK - shared vars are already loaded
    # We'll continue to try loading site/host envs even if this check fails
    if ! check_required_env_vars; then
        [ "${DT_DEBUG,,}" == "1" -o "${DT_DEBUG,,}" == "true" ] && log_msg "DEBUG" "Required vars check failed, but continuing to attempt site/host loading" >&2
        # Don't return - let it try to load site/host envs even if SITE_NAME missing
        # They will gracefully handle missing variables
    fi

    # Now we can use SITE_NAME for site/host specific paths
    local site_name="${SITE_NAME:-default}"
    local site_dir="${docker_dir}/sites/${site_name}"
    local host_dir="${site_dir}/${HOSTNAME}"

    # === DETECT CONFIG MODE (V1 or V2) ===
    local selected_compose
    selected_compose=$(get_docker_compose_file 2>/dev/null || echo "")
    if [[ "$selected_compose" == *"/docker-compose-"* ]]; then
        export CFG_MODE=1
        [ "${DT_DEBUG,,}" == "1" -o "${DT_DEBUG,,}" == "true" ] && log_msg "DEBUG" "CFG_MODE=1 (V1) - Using compose file: $selected_compose" >&2
    elif [[ "$selected_compose" == *"/dc-"* ]]; then
        export CFG_MODE=2
        [ "${DT_DEBUG,,}" == "1" -o "${DT_DEBUG,,}" == "true" ] && log_msg "DEBUG" "CFG_MODE=2 (V2) - Using compose file: $selected_compose" >&2
    else
        export CFG_MODE=2  # Default to V2 if no compose file found
        [ "${DT_DEBUG,,}" == "1" -o "${DT_DEBUG,,}" == "true" ] && log_msg "WARN" "No compose file found; defaulting to CFG_MODE=2 (V2)" >&2
    fi

    # === LOAD .env FILES BASED ON CFG_MODE ===

    if [[ "$CFG_MODE" == "1" ]]; then
        # --- V1: Load $DOCKERDIR/.env ---
        if [ -f "${docker_dir}/.env" ]; then
            source "${docker_dir}/.env"
            log_msg "INFO" "Sourced V1 general settings from ${docker_dir}/.env" >&2
            [ "${DT_DEBUG,,}" == "1" -o "${DT_DEBUG,,}" == "true" ] && log_msg "DEBUG" "Loaded V1 general env" >&2
        else
            [ "${DT_DEBUG,,}" == "1" -o "${DT_DEBUG,,}" == "true" ] && log_msg "WARNING" "V1 general .env not found at ${docker_dir}/.env" >&2
        fi

        # --- V1: Load $DOCKERDIR/secrets/env/.env.$HOSTNAME (case-insensitive) ---
        local v1_host_env
        v1_host_env=$(find_file_case_insensitive "${docker_dir}/secrets/env" ".env." "$HOSTNAME" "")
        if [ -n "$v1_host_env" ]; then
            source "$v1_host_env"
            log_msg "INFO" "Sourced V1 host-specific settings from $v1_host_env" >&2
            [ "${DT_DEBUG,,}" == "1" -o "${DT_DEBUG,,}" == "true" ] && log_msg "DEBUG" "Loaded V1 host env: $v1_host_env" >&2
        else
            [ "${DT_DEBUG,,}" == "1" -o "${DT_DEBUG,,}" == "true" ] && log_msg "WARNING" "V1 host-specific .env not found in ${docker_dir}/secrets/env for $HOSTNAME" >&2
        fi

    elif [[ "$CFG_MODE" == "2" ]]; then
        # --- V2: Load site and host .env files ---
        # Note: Shared .env was already loaded at the top of this function
        # Last Updated: 11/11/2025 9:15:00 PM CDT
        local site_env_file host_env_file

        site_env_file=$(find_file_case_insensitive "${site_dir}" ".env." "$site_name" "")
        if [ -n "$site_env_file" ]; then
            source "$site_env_file" || {
                log_msg "ERROR" "Failed to source V2 site-specific settings from $site_env_file" >&2
                return 1
            }
            log_msg "INFO" "Sourced V2 site-specific settings from $site_env_file" >&2
        else
            [ "${DT_DEBUG,,}" == "1" -o "${DT_DEBUG,,}" == "true" ] && log_msg "WARNING" "V2 site-specific .env not found in $site_dir" >&2
        fi

        host_env_file=$(find_file_case_insensitive "${host_dir}" ".env." "$HOSTNAME" "")
        if [ -n "$host_env_file" ]; then
            source "$host_env_file" || {
                log_msg "ERROR" "Failed to source V2 host-specific settings from $host_env_file" >&2
                return 1
            }
            log_msg "INFO" "Sourced V2 host-specific settings from $host_env_file" >&2
        else
            [ "${DT_DEBUG,,}" == "1" -o "${DT_DEBUG,,}" == "true" ] && log_msg "WARNING" "V2 host-specific .env not found in $host_dir" >&2
        fi
    fi

    # === DEFAULTS & PATH ===
    if [ -z "$DIVTOOLS" ]; then
        if is_truenas || is_readonly_usr_local_bin; then
            export DIVTOOLS="/mnt/tpool/NFS/opt/divtools"
            export DOCKERDATADIR="/mnt/tpool/NFS/opt"
            export DT_LOCAL_BIN_DIR="/mnt/tpool/NFS/opt/bin"
        else
            export DIVTOOLS="/opt/divtools"
            export DOCKERDATADIR="/opt"
            export DT_LOCAL_BIN_DIR="/usr/local/bin"
        fi
        log_msg "INFO" "Set default environment variables: DIVTOOLS=$DIVTOOLS" >&2
    fi

    if [[ ! ":$PATH:" =~ ":$DT_LOCAL_BIN_DIR:" ]]; then
        export PATH="$DT_LOCAL_BIN_DIR:$PATH"
        log_msg "INFO" "Added $DT_LOCAL_BIN_DIR to PATH." >&2
    fi

    # === DOCKER DIRECTORY VARIABLES ===
    # Export Docker directory variables (used by dcrun and other docker scripts)
    # Last Updated: 11/5/2025 3:15:00 PM CST
    export DOCKER_SHAREDDIR="${DOCKERDIR}/sites/s00-shared"
    export DOCKER_SITEDIR="${DOCKERDIR}/sites/${SITE_NAME:-default}"
    export DOCKER_HOSTDIR="${DOCKER_SITEDIR}/${HOSTNAME}"
    [ "${DT_DEBUG,,}" == "1" -o "${DT_DEBUG,,}" == "true" ] && log_msg "DEBUG" "Exported: DOCKER_SHAREDDIR=${DOCKER_SHAREDDIR}, DOCKER_SITEDIR=${DOCKER_SITEDIR}, DOCKER_HOSTDIR=${DOCKER_HOSTDIR}" >&2

    # === INFLUXDB CHECK (always, after all .env loading) ===
    confirm_influxdb_vars
    
    # Explicit success return
    return 0
} # load_env_files



container_exists() {
  local container_name=$1

  # Check if Docker is installed
  if ! command -v docker &> /dev/null; then
    return 1
  fi

  # Check if the container exists (in any state)
  if docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
    return 0  # Container exists
  else
    return 1  # Container does not exist
  fi
}


#### DCRUN_F FUNCTIONS: BEGIN

# Function to locate the Docker Compose file (V1 or V2 structure)
# Last Updated: 10/22/2025 8:35:00 PM CDT
get_docker_compose_file() {
    local selected_compose
    local hostname="${HOSTNAME:-$(hostname)}"
    #local hostname=$(hostname)}
    local docker_dir="${DOCKERDIR:-/opt/divtools/docker}"
    local site_name="${SITE_NAME:-default}"
    local docker_sitedir="${docker_dir}/sites/${site_name}"
    local docker_hostdir="${docker_sitedir}/${hostname}"

    [ "${DT_DEBUG,,}" == "1" -o "${DT_DEBUG,,}" == "true" ] && log_msg "DEBUG" "Checking V1: ${docker_dir}/docker-compose-${hostname}.yml, V2: ${docker_hostdir}/dc-${hostname}.yml with HOSTNAME=${hostname}, SITE_NAME=${site_name}" >&2

    # Check V1 location
    selected_compose=$(find_file_case_insensitive "${docker_dir}" "docker-compose-" "${hostname}" ".yml")
    if [ -n "${selected_compose}" ]; then
        [ "${DT_DEBUG,,}" == "1" -o "${DT_DEBUG,,}" == "true" ] && log_msg "DEBUG" "Detected V1 compose file: ${selected_compose}" >&2
        echo "${selected_compose}"
        return 0
    fi

    # Check V2 location
    selected_compose=$(find_file_case_insensitive "${docker_hostdir}" "dc-" "${hostname}" ".yml")
    if [ -n "${selected_compose}" ]; then
        [ "${DT_DEBUG,,}" == "1" -o "${DT_DEBUG,,}" == "true" ] && log_msg "DEBUG" "Detected V2 compose file: ${selected_compose}" >&2
        echo "${selected_compose}"
        return 0
    fi

    log_msg "ERROR" "No docker compose file found in V1 (${docker_dir}/docker-compose-${hostname}.yml) or V2 (${docker_hostdir}/dc-${hostname}.yml) locations." >&2
    return 1
} # get_docker_compose_file



# Function for dcrun to handle docker compose execution with environment setup
# Last Updated: 10/22/2025 8:35:00 PM CDT
dcrun_f() {
    # Set defaults
    TEST_MODE=0
    DEBUG_MODE=0
    if [[ "${DT_DEBUG,,}" == "1" || "${DT_DEBUG,,}" == "true" ]]; then
        DEBUG_MODE=1
        log_msg "DEBUG" "Debug mode enabled via DT_DEBUG=${DT_DEBUG}" >&2
    fi

    # Parse and filter custom flags (-test, -dt-debug, --profile)
    local profile_args=""
    local filtered_args=()
    local skip_next=0
    for arg in "$@"; do
        if [[ "${arg}" == "-test" ]]; then
            TEST_MODE=1
            log_msg "DEBUG" "Test mode enabled via -test flag" >&2
            continue
        elif [[ "${arg}" == "-dt-debug" ]]; then
            DEBUG_MODE=1
            log_msg "DEBUG" "Debug mode enabled via -dt-debug flag" >&2
            continue
        elif [[ "${arg}" == "--profile" ]]; then
            profile_args="${arg}"
            skip_next=1
            continue
        elif [[ ${skip_next} -eq 1 ]]; then
            profile_args="${profile_args} ${arg}"
            skip_next=0
            continue
        fi
        filtered_args+=("${arg}")
    done

    # Log initial state
    [ ${DEBUG_MODE} -eq 1 ] && log_msg "DEBUG" "Initial args: $@, Filtered args: ${filtered_args[*]}, Profile args: ${profile_args}, TEST_MODE=${TEST_MODE}, DEBUG_MODE=${DEBUG_MODE}" >&2

    # Rely on load_env_files() for environment setup
    # This now also sets DOCKER_SHAREDDIR, DOCKER_SITEDIR, and DOCKER_HOSTDIR
    if ! declare -f load_env_files >/dev/null; then
        log_msg "ERROR" "load_env_files function not found. Ensure it is defined in .bash_aliases." >&2
        return 1
    fi
    if ! load_env_files; then
        log_msg "ERROR" "Environment setup failed. Cannot proceed with docker compose command." >&2
        return 1
    fi
    [ ${DEBUG_MODE} -eq 1 ] && log_msg "DEBUG" "After load_env_files: HOSTNAME=${HOSTNAME}, SITE_NAME=${SITE_NAME}, DOCKER_HOSTDIR=${DOCKER_HOSTDIR}" >&2

    # Get docker compose file
    local selected_compose
    selected_compose=$(get_docker_compose_file)
    if [ -z "${selected_compose}" ]; then
        log_msg "ERROR" "Failed to locate docker compose file." >&2
        return 1
    fi
    log_msg "INFO" "Using compose file: ${selected_compose}" >&2
    [ ${DEBUG_MODE} -eq 1 ] && log_msg "DEBUG" "Selected compose file: ${selected_compose}" >&2

    # Build docker compose command
    local compose_cmd=""
    if [ -n "${profile_args}" ]; then
        compose_cmd="sudo -E docker compose -f ${selected_compose} ${profile_args} ${filtered_args[*]}"
    else
        compose_cmd="sudo -E docker compose --profile all -f ${selected_compose} ${filtered_args[*]}"
    fi

    log_msg "INFO" "Executing command: ${compose_cmd}" >&2
    [ ${DEBUG_MODE} -eq 1 ] && log_msg "DEBUG" "Full command: ${compose_cmd}" >&2

    if [ "${TEST_MODE}" -eq 1 ]; then
        log_msg "INFO" "TEST MODE: Would execute: ${compose_cmd}" >&2
    else
        eval "${compose_cmd}"
    fi
} # dcrun_f

# Function to reset containers (stop, remove, recreate)
# Useful for fixing containers that belong to wrong docker-compose projects
# Last Updated: 11/4/2025 7:30:00 PM CDT
dcreset_f() {
    # Handles containers that might be orphaned from other projects
    # Usage: dcreset container_name [container_name2 ...]
    
    if [ $# -eq 0 ]; then
        log_msg "ERROR" "Usage: dcreset <container_name> [container_name2 ...]" >&2
        return 1
    fi
    
    local containers=("$@")
    local failed_containers=()
    
    log_msg "INFO" "Resetting containers: ${containers[*]}" >&2
    
    # Stop and remove each container
    for container in "${containers[@]}"; do
        log_msg "INFO" "Stopping container: ${container}" >&2
        if sudo docker stop "${container}" 2>/dev/null; then
            log_msg "INFO" "Successfully stopped: ${container}" >&2
        else
            log_msg "WARN" "Could not stop ${container} (may not be running)" >&2
        fi
        
        log_msg "INFO" "Removing container: ${container}" >&2
        if sudo docker rm "${container}" 2>/dev/null; then
            log_msg "INFO" "Successfully removed: ${container}" >&2
        else
            log_msg "WARN" "Could not remove ${container} (may not exist)" >&2
        fi
    done
    
    # Recreate containers using dcup
    log_msg "INFO" "Recreating containers with dcup..." >&2
    dcrun up -d --build --remove-orphans "${containers[@]}"
    
    if [ $? -eq 0 ]; then
        log_msg "INFO" "Successfully recreated containers: ${containers[*]}" >&2
    else
        log_msg "ERROR" "Failed to recreate some containers" >&2
        return 1
    fi
} # dcreset_f

# Function to check which docker-compose project containers belong to
# Useful for diagnosing orphaned containers from other projects
# Last Updated: 11/4/2025 8:00:00 PM CDT
dcproject() {
    # Shows the docker-compose project name for running containers
    # Highlights mismatched projects in RED and shows container health status
    # Usage: dcproject [container_name ...]
    #        dcproject (shows all running containers and their projects)
    
    # ANSI color codes
    local RED='\033[0;31m'
    local GREEN='\033[0;32m'
    local YELLOW='\033[0;33m'
    local BLUE='\033[0;36m'
    local NC='\033[0m' # No Color
    
    local current_hostname="${HOSTNAME:-$(hostname)}"
    local mismatched_containers=()
    
    if [ $# -eq 0 ]; then
        # Show all containers
        log_msg "INFO" "Showing all running containers and their projects (Current host: ${current_hostname}):" >&2
        echo ""
        printf "%-20s %-20s %-30s %-30s\n" "CONTAINER" "PROJECT" "COMPOSE_SERVICE" "STATUS"
        printf "%-20s %-20s %-30s %-30s\n" "--------------------" "--------------------" "------------------------------" "------------------------------"
        
        sudo docker ps --format "{{.Names}}" | while read -r container; do
            local project=$(sudo docker inspect "${container}" --format '{{index .Config.Labels "com.docker.compose.project"}}' 2>/dev/null || echo "N/A")
            local service=$(sudo docker inspect "${container}" --format '{{index .Config.Labels "com.docker.compose.service"}}' 2>/dev/null || echo "N/A")
            local health=$(sudo docker inspect "${container}" --format '{{.State.Health.Status}}' 2>/dev/null || echo "")
            local status=$(sudo docker inspect "${container}" --format '{{.State.Status}}' 2>/dev/null || echo "unknown")
            
            # Track mismatched containers
            if [ "${project}" != "${current_hostname}" ] && [ "${project}" != "N/A" ]; then
                echo "${container}" >> /tmp/dcproject_mismatches_$$
            fi
            
            # Determine status message
            local status_msg=""
            if [ "${project}" != "${current_hostname}" ] && [ "${project}" != "N/A" ]; then
                status_msg="${RED}Project Mismatch${NC}"
            elif [ -n "${health}" ]; then
                case "${health}" in
                    healthy)
                        status_msg="${GREEN}${status} (${health})${NC}"
                        ;;
                    unhealthy)
                        status_msg="${RED}${status} (${health})${NC}"
                        ;;
                    starting)
                        status_msg="${YELLOW}${status} (${health})${NC}"
                        ;;
                    *)
                        status_msg="${status} (${health})"
                        ;;
                esac
            else
                case "${status}" in
                    running)
                        status_msg="${GREEN}${status}${NC}"
                        ;;
                    exited|dead)
                        status_msg="${RED}${status}${NC}"
                        ;;
                    *)
                        status_msg="${status}"
                        ;;
                esac
            fi
            
            # Color the entire line red if project doesn't match hostname
            if [ "${project}" != "${current_hostname}" ] && [ "${project}" != "N/A" ]; then
                printf "${RED}%-20s %-20s %-30s${NC} %-30b\n" "${container}" "${project}" "${service}" "${status_msg}"
            else
                printf "%-20s %-20s %-30s %-30b\n" "${container}" "${project}" "${service}" "${status_msg}"
            fi
        done
        
        # Check if there were any mismatches and print resolution message
        if [ -f /tmp/dcproject_mismatches_$$ ]; then
            local mismatched=$(cat /tmp/dcproject_mismatches_$$)
            rm -f /tmp/dcproject_mismatches_$$
            
            if [ -n "${mismatched}" ]; then
                echo ""
                echo -e "${YELLOW}╔════════════════════════════════════════════════════════════════════════╗${NC}"
                echo -e "${YELLOW}║${NC} ${RED}WARNING: Project Mismatches Detected${NC}                                   ${YELLOW}║${NC}"
                echo -e "${YELLOW}╚════════════════════════════════════════════════════════════════════════╝${NC}"
                echo ""
                echo -e "${BLUE}The following containers belong to a different docker-compose project:${NC}"
                echo -e "${RED}${mismatched}${NC}"
                echo ""
                echo -e "${BLUE}To fix these containers, run:${NC}"
                echo -e "  ${GREEN}dcreset ${mismatched//$'\n'/ }${NC}"
                echo ""
                echo -e "${BLUE}This will:${NC}"
                echo "  1. Stop the mismatched containers"
                echo "  2. Remove them from the old project"
                echo "  3. Recreate them using the current host's compose file"
                echo ""
            fi
        fi
    else
        # Show specific containers
        local has_mismatch=false
        for container in "$@"; do
            local project=$(sudo docker inspect "${container}" --format '{{index .Config.Labels "com.docker.compose.project"}}' 2>/dev/null)
            local service=$(sudo docker inspect "${container}" --format '{{index .Config.Labels "com.docker.compose.service"}}' 2>/dev/null)
            local health=$(sudo docker inspect "${container}" --format '{{.State.Health.Status}}' 2>/dev/null || echo "")
            local status=$(sudo docker inspect "${container}" --format '{{.State.Status}}' 2>/dev/null || echo "unknown")
            
            if [ -n "${project}" ]; then
                # Determine if there's a project mismatch
                local mismatch=""
                if [ "${project}" != "${current_hostname}" ]; then
                    mismatch=" ${RED}(MISMATCH: expected ${current_hostname})${NC}"
                    has_mismatch=true
                    mismatched_containers+=("${container}")
                fi
                
                echo -e "Container: ${container}"
                echo -e "  Project: ${project}${mismatch}"
                echo -e "  Service: ${service}"
                
                # Show health status
                if [ -n "${health}" ]; then
                    case "${health}" in
                        healthy)
                            echo -e "  Status: ${GREEN}${status} (${health})${NC}"
                            ;;
                        unhealthy)
                            echo -e "  Status: ${RED}${status} (${health})${NC}"
                            ;;
                        starting)
                            echo -e "  Status: ${YELLOW}${status} (${health})${NC}"
                            ;;
                        *)
                            echo -e "  Status: ${status} (${health})"
                            ;;
                    esac
                else
                    case "${status}" in
                        running)
                            echo -e "  Status: ${GREEN}${status}${NC}"
                            ;;
                        exited|dead)
                            echo -e "  Status: ${RED}${status}${NC}"
                            ;;
                        *)
                            echo -e "  Status: ${status}"
                            ;;
                    esac
                fi
                echo ""
            else
                log_msg "ERROR" "Container '${container}' not found or not a compose container" >&2
            fi
        done
        
        # Print resolution message if there were mismatches
        if [ "${has_mismatch}" = true ]; then
            echo -e "${YELLOW}╔════════════════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${YELLOW}║${NC} ${RED}WARNING: Project Mismatch Detected${NC}                                     ${YELLOW}║${NC}"
            echo -e "${YELLOW}╚════════════════════════════════════════════════════════════════════════╝${NC}"
            echo ""
            echo -e "${BLUE}To fix these containers, run:${NC}"
            echo -e "  ${GREEN}dcreset ${mismatched_containers[*]}${NC}"
            echo ""
        fi
    fi
} # dcproject

#### DCRUN_F FUNCTIONS: END


# Last Updated: 11/4/2025 9:45:00 PM CST
# Colorizes df output with configurable usage ranges and styled header
# Enhanced with TrueNAS ZFS usage correction for remote mounts
df_color() {
    # Display disk usage with color highlighting for configurable usage ranges
    # Header in bright black background with dark blue foreground
    # Supports -debug flag for detailed output
    # Excludes overlay and tmpfs filesystems
    # Corrects usage for remote NFS/SMB mounts from TrueNAS using .zfs_usage_info file
    local YELLOW="\e[33m"          # Matches C_YELLOW in .bash_profile
    local RED="\e[31m"             # Matches C_RED
    local GREEN="\e[32m"           # Matches C_GREEN
    local ORANGE="\e[38;5;214m"    # Matches C_ORANGE
    local WHITE="\e[37m"           # Matches C_WHITE
    local RESET="\e[m"
    local HEADER_BG="\e[100m"      # Bright black background (C_BG_BRIGHTBLACK)
    local HEADER_FG="\e[38;5;19m"  # Dark blue foreground (C_DARKBLUE)
    local DEBUG=0
    local df_output
    local lines
    local i

    # Parse optional -debug flag
    if [[ "$1" == "-debug" ]]; then
        DEBUG=1
        shift
    fi

    # Source TrueNAS usage helper functions if available
    if [[ -f "$DIVTOOLS/scripts/util/truenas_usage.sh" ]]; then
        source "$DIVTOOLS/scripts/util/truenas_usage.sh"
        if [[ $DEBUG -eq 1 ]]; then
            echo "[DEBUG] Loaded TrueNAS usage helper functions"
        fi
    fi

    # Debug: Log start of df execution
    if [[ $DEBUG -eq 1 ]]; then
        echo "[DEBUG] Starting df command execution"
    fi

    # Run df with sudo and timeout to prevent hanging
    if ! df_output=$(timeout --signal=SIGTERM 10 df -h -x overlay -x tmpfs 2>/dev/null); then
        echo "Error: Failed to execute df command, timed out after 10 seconds, or sudo authentication failed."
        if [[ $DEBUG -eq 1 ]]; then
            echo "[DEBUG] df command failed or timed out"
        fi
        return 1
    fi

    # Debug: Log raw df output
    if [[ $DEBUG -eq 1 ]]; then
        echo "[DEBUG] Raw df output:"
        echo "$df_output"
    fi

    # Split output into an array of lines
    if [[ $DEBUG -eq 1 ]]; then
        echo "[DEBUG] Splitting df output into lines"
    fi
    mapfile -t lines <<< "$df_output"

    # Check if output is empty
    if [[ ${#lines[@]} -eq 0 ]]; then
        echo "Error: No output from df command."
        if [[ $DEBUG -eq 1 ]]; then
            echo "[DEBUG] No lines in df output"
        fi
        return 1
    fi

    # Print header (first line) with bright black background and dark blue foreground
    if [[ $DEBUG -eq 1 ]]; then
        echo "[DEBUG] Printing header: ${lines[0]}"
    fi
    echo -e "${HEADER_BG}${HEADER_FG}${lines[0]}${RESET}"

    # Define usage ranges and colors
    declare -A USAGE_RANGES=(
        ["Excellent"]="0-30:$GREEN"
        ["Normal"]="31-69:$WHITE"
        ["Warn"]="70-79:$YELLOW"
        ["Error"]="80-89:$ORANGE"
        ["Critical"]="90-100:$RED"
    )

    # Process each line (skip header)
    for ((i=1; i<${#lines[@]}; i++)); do
        local line="${lines[i]}"
        local filesystem mountpoint usage_file corrected_usage usage
        
        # Extract components from the line
        filesystem=$(echo "$line" | awk '{print $1}')
        mountpoint=$(echo "$line" | awk '{print $6}')
        
        if [[ $DEBUG -eq 1 ]]; then
            echo "[DEBUG] Processing line $i: filesystem=$filesystem, mountpoint=$mountpoint"
        fi
        
        # Check if this is a remote mount and has usage info file
        local corrected_line="$line"
        if type -t is_remote_mount &>/dev/null && type -t get_truenas_usage &>/dev/null; then
            if is_remote_mount "$mountpoint" 2>/dev/null; then
                usage_file=$(get_usage_file_for_mount "$mountpoint" 2>/dev/null)
                if [[ -n "$usage_file" ]]; then
                    if [[ $DEBUG -eq 1 ]]; then
                        echo "[DEBUG] Remote mount detected with usage file: $usage_file"
                    fi
                    
                    # Get corrected usage from TrueNAS
                    if corrected_usage=$(get_truenas_usage "$mountpoint" "$usage_file" "$DEBUG" 2>&1); then
                        IFS='|' read -r tns_used tns_avail tns_total <<< "$corrected_usage"
                        
                        if [[ $DEBUG -eq 1 ]]; then
                            echo "[DEBUG] TrueNAS corrected values: used=$tns_used, avail=$tns_avail, total=$tns_total"
                        fi
                        
                        # Calculate corrected usage percentage
                        local used_bytes avail_bytes total_bytes usage_pct
                        used_bytes=$(numfmt --from=iec "$tns_used" 2>/dev/null) || used_bytes=0
                        avail_bytes=$(numfmt --from=iec "$tns_avail" 2>/dev/null) || avail_bytes=0
                        total_bytes=$((used_bytes + avail_bytes))
                        
                        if [[ $total_bytes -gt 0 ]]; then
                            usage_pct=$((used_bytes * 100 / total_bytes))
                        else
                            usage_pct=0
                        fi
                        
                        # Reconstruct the line with corrected values
                        corrected_line=$(printf "%-48s %5s %5s %5s %4s%% %s" \
                            "$filesystem" "$tns_total" "$tns_used" "$tns_avail" "$usage_pct" "$mountpoint")
                        
                        if [[ $DEBUG -eq 1 ]]; then
                            echo "[DEBUG] Corrected line: $corrected_line"
                        fi
                        
                        # Update usage for coloring
                        usage=$usage_pct
                    fi
                fi
            fi
        fi
        
        # Extract usage percentage (5th column, removing % sign)
        if [[ -z "$usage" ]]; then
            usage=$(echo "$corrected_line" | awk '{print $5}' | tr -d '%')
        fi
        
        # Debug: Log parsed usage
        if [[ $DEBUG -eq 1 ]]; then
            echo "[DEBUG] Line $i: Usage=$usage"
        fi

        # Skip lines with invalid usage values
        if [[ -z "$usage" || ! "$usage" =~ ^[0-9]+$ ]]; then
            if [[ $DEBUG -eq 1 ]]; then
                echo "[DEBUG] Skipping invalid usage for line $i"
            fi
            echo "$corrected_line"
            continue
        fi

        # Determine color based on usage range
        local color=""
        for range in "${!USAGE_RANGES[@]}"; do
            IFS=':-' read -r min max col <<< "${USAGE_RANGES[$range]}"
            if [[ "$usage" -ge "$min" && "$usage" -le "$max" ]]; then
                color="$col"
                if [[ $DEBUG -eq 1 ]]; then
                    echo "[DEBUG] Line $i: Usage $usage falls in range $range ($min-$max), using color $color"
                fi
                break
            fi
        done

        # Apply color if found, otherwise print without color
        if [[ -n "$color" ]]; then
            echo -e "${color}${corrected_line}${RESET}"
        else
            echo "$corrected_line"
        fi
    done
} # df_color

### PYTHON FUNCTIONS ###

export VENV_DIR="$DIVTOOLS/scripts/venvs"

# Helper function to check if python venv module is available
function _check_python_venv_installed() {
    local auto_install="$1"  # -y or -n for automation
    
    # Check if python3 -m venv works
    if python3 -m venv --help &>/dev/null; then
        return 0  # venv is available
    fi
    
    # Determine Python version
    local py_version=$(python3 --version 2>&1 | grep -oP 'Python \K[0-9]+\.[0-9]+' | head -1)
    local py_major=$(echo "$py_version" | cut -d. -f1)
    local py_minor=$(echo "$py_version" | cut -d. -f2)
    local venv_package="python${py_major}.${py_minor}-venv"
    
    echo "⚠️ [WARNING] python${py_major}.${py_minor} venv module not installed"
    echo "📦 Required package: $venv_package"
    echo "💡 Install command: sudo apt install $venv_package"
    echo ""
    
    # Handle automation flags
    if [[ "$auto_install" == "-y" ]]; then
        echo "🚀 Auto-install enabled, installing $venv_package..."
        sudo apt install -y "$venv_package"
        return $?
    elif [[ "$auto_install" == "-n" ]]; then
        echo "❌ Auto-install disabled, exiting..."
        return 1
    fi
    
    # Interactive mode
    read -r -p "❓ Would you like to install $venv_package now? (y/N) " response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo "🚀 Installing $venv_package..."
        sudo apt install -y "$venv_package"
        if [[ $? -eq 0 ]]; then
            echo "✅ $venv_package installed successfully!"
            return 0
        else
            echo "❌ Failed to install $venv_package"
            return 1
        fi
    else
        echo "❌ Installation canceled."
        return 1
    fi
}

# Function to create a virtual environment
# Usage: python_venv_create <venv_name> [-y|-n]
function python_venv_create() {
    local venv_name=""
    local auto_flag=""
    
    # Parse arguments
    for arg in "$@"; do
        case "$arg" in
            -y|-n)
                auto_flag="$arg"
                ;;
            *)
                if [[ -z "$venv_name" ]]; then
                    venv_name="$arg"
                fi
                ;;
        esac
    done
    
    # Default to 'venv' if no name is given
    venv_name="${venv_name:-venv}"
    local venv_path="$VENV_DIR/$venv_name"
    
    # Check if python venv module is available
    if ! _check_python_venv_installed "$auto_flag"; then
        return 1
    fi

    if [[ -d "$venv_path" ]]; then
        echo "❌ Virtual environment '$venv_name' already exists at $venv_path"
        return 1
    fi

    echo "🚀 Creating virtual environment: $venv_name..."
    python3 -m venv "$venv_path"

    if [[ $? -eq 0 ]]; then
        echo "✅ Virtual environment '$venv_name' created successfully!"
    else
        echo "❌ Failed to create virtual environment."
        return 1
    fi
}

# Function to delete a virtual environment
# Usage: python_venv_delete <venv_name> [-y|-n]
function python_venv_delete() {
    local venv_name=""
    local auto_flag=""
    
    # Parse arguments
    for arg in "$@"; do
        case "$arg" in
            -y|-n)
                auto_flag="$arg"
                ;;
            *)
                if [[ -z "$venv_name" ]]; then
                    venv_name="$arg"
                fi
                ;;
        esac
    done
    
    if [[ -z "$venv_name" ]]; then
        echo "❌ Usage: python_venv_delete <venv_name> [-y|-n]"
        return 1
    fi

    local venv_path="$VENV_DIR/$venv_name"

    if [[ ! -d "$venv_path" ]]; then
        echo "❌ Virtual environment '$venv_name' not found at $venv_path"
        return 1
    fi

    # Handle automation flags
    if [[ "$auto_flag" == "-y" ]]; then
        rm -rf "$venv_path"
        echo "✅ Virtual environment '$venv_name' deleted."
        return 0
    elif [[ "$auto_flag" == "-n" ]]; then
        echo "❌ Deletion canceled (auto-flag: -n)"
        return 1
    fi
    
    # Interactive mode
    echo "⚠️ Are you sure you want to delete the virtual environment '$venv_name'? (y/N)"
    read -r confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        rm -rf "$venv_path"
        echo "✅ Virtual environment '$venv_name' deleted."
    else
        echo "❌ Deletion canceled."
    fi
}

# Function to activate a virtual environment
# Usage: python_venv_activate <venv_name> [-y|-n]
function python_venv_activate() {
    local venv_name=""
    local auto_flag=""
    
    # Parse arguments
    for arg in "$@"; do
        case "$arg" in
            -y|-n)
                auto_flag="$arg"
                ;;
            *)
                if [[ -z "$venv_name" ]]; then
                    venv_name="$arg"
                fi
                ;;
        esac
    done
    
    # Default to 'venv' if no name is given
    venv_name="${venv_name:-venv}"
    local venv_path="$VENV_DIR/$venv_name"

    if [[ ! -d "$venv_path" ]]; then
        echo "❌ Virtual environment '$venv_name' not found at $venv_path"
        return 1
    fi

    echo "🔗 Activating virtual environment: $venv_name..."
    source "$venv_path/bin/activate"
}

# Function to list available virtual environments
# Usage: python_venv_ls [-y|-n]
function python_venv_ls() {
    local auto_flag=""
    
    # Parse arguments
    for arg in "$@"; do
        case "$arg" in
            -y|-n)
                auto_flag="$arg"
                ;;
        esac
    done
    
    # Check venv availability (but don't block execution)
    if ! python3 -m venv --help &>/dev/null; then
        local py_version=$(python3 --version 2>&1 | grep -oP 'Python \K[0-9]+\.[0-9]+' | head -1)
        local py_major=$(echo "$py_version" | cut -d. -f1)
        local py_minor=$(echo "$py_version" | cut -d. -f2)
        local venv_package="python${py_major}.${py_minor}-venv"
        echo "⚠️ [WARNING] python${py_major}.${py_minor} venv module not installed"
        echo "💡 Install with: sudo apt install $venv_package"
        echo ""
    fi
    
    if [[ ! -d "$VENV_DIR" ]]; then
        echo "❌ Virtual environment directory '$VENV_DIR' not found!"
        return 1
    fi

    local venvs=()
    for dir in "$VENV_DIR"/*/; do
        [[ -d "$dir" ]] && venvs+=("$(basename "$dir")")
    done

    if [[ ${#venvs[@]} -eq 0 ]]; then
        echo "📂 No virtual environments found in '$VENV_DIR'"
        return 0
    fi

    echo "📂 Available Virtual Environments in '$VENV_DIR':"
    for venv in "${venvs[@]}"; do
        echo "  - $venv"
    done
}



### INIT CODE ###

if [[ $- == *i* ]]; then
  # interactive shell
	log_msg "INFO" "Running $DIVTOOLS/dotfiles/.bash_profile"

	# Existing ANSI Color Variables
	C_BLACK='\[\e[30m\]'
	C_RED='\[\e[31m\]'
	C_GREEN='\[\e[32m\]'
	C_YELLOW='\[\e[33m\]'
	C_BLUE='\[\e[34m\]'
	C_MAGENTA='\[\e[35m\]'
	C_CYAN='\[\e[36m\]'
	C_WHITE='\[\e[37m\]'

	# Bright Colors
	C_BRIGHTBLACK='\[\e[90m\]'
	C_BRIGHTRED='\[\e[91m\]'
	C_BRIGHTGREEN='\[\e[92m\]'
	C_BRIGHTYELLOW='\[\e[93m\]'
	C_BRIGHTBLUE='\[\e[94m\]'
	C_BRIGHTMAGENTA='\[\e[95m\]'
	C_BRIGHTCYAN='\[\e[96m\]'
	C_BRIGHTWHITE='\[\e[97m\]'

	# Background Colors
	C_BG_BLACK='\[\e[40m\]'
	C_BG_RED='\[\e[41m\]'
	C_BG_GREEN='\[\e[42m\]'
	C_BG_YELLOW='\[\e[43m\]'
	C_BG_BLUE='\[\e[44m\]'
	C_BG_MAGENTA='\[\e[45m\]'
	C_BG_CYAN='\[\e[46m\]'
	C_BG_WHITE='\[\e[47m\]'

	# Bright Background Colors
	C_BG_BRIGHTBLACK='\[\e[100m\]'
	C_BG_BRIGHTRED='\[\e[101m\]'
	C_BG_BRIGHTGREEN='\[\e[102m\]'
	C_BG_BRIGHTYELLOW='\[\e[103m\]'
	C_BG_BRIGHTBLUE='\[\e[104m\]'
	C_BG_BRIGHTMAGENTA='\[\e[105m\]'
	C_BG_BRIGHTCYAN='\[\e[106m\]'
	C_BG_BRIGHTWHITE='\[\e[107m\]'


	# Add 256-color palette definitions
	C_PINK='\[\e[38;5;13m\]'
	C_ORANGE='\[\e[38;5;214m\]'
	C_LIGHTGREEN='\[\e[38;5;119m\]'
	C_PURPLE='\[\e[38;5;129m\]'
	C_LIGHTBLUE='\[\e[38;5;123m\]'
	C_BROWN='\[\e[38;5;130m\]'
	C_LIGHTCYAN='\[\e[38;5;152m\]'
	C_GOLD='\[\e[38;5;220m\]'
	C_LIGHTPURPLE='\[\e[38;5;177m\]'
	C_DARKBLUE='\[\e[38;5;19m\]'
	C_LIGHTYELLOW='\[\e[38;5;229m\]'
	C_TEAL='\[\e[38;5;37m\]'
	C_SALMON='\[\e[38;5;210m\]'
	C_VIOLET='\[\e[38;5;171m\]'
	C_LIME='\[\e[38;5;154m\]'
	C_DARKGRAY='\[\e[38;5;236m\]'

  # Bold and bold off
  C_BOLD='\[\e[1m\]'
  C_BOLD_OFF='\[\e[22m\]'

  # Underline and underline off
  C_UNDERLINE='\[\e[4m\]'
  C_UNDERLINE_OFF='\[\e[24m\]'

  # Italic and italic off (if supported)
  C_ITALIC='\[\e[3m\]'
  C_ITALIC_OFF='\[\e[23m\]'

  # Inverse (reverse colors) and inverse off
  C_INVERSE='\[\e[7m\]'
  C_INVERSE_OFF='\[\e[27m\]'

	# Reset Color
	C_RESET='\[\e[m\]'

  # Get the OS. It will be contained in $ID
  . /etc/os-release

  # UPDATE PATH
  # Add /opt paths
  if [ -d /opt/bin ]; then
	  PATH=/opt/bin:$PATH
  fi
  if [ -d /opt/sbin ]; then
	  PATH=/opt/sbin:$PATH
  fi

  # Check for Samba with custom output
  if ! add_to_path "/usr/local/samba/bin" "SAMBA" 1; then
      log_msg "SAMBA" "Samba not installed on this system."
  fi

  # Load any Local Env
  if [ -f ~/.bash_local_env ] ; then
    . ~/.bash_local_env
  fi
fi


# # Usage example in your script
# if [[ $- == *i* ]]; then
#   # interactive shell
#   if ! has_starship; then
#     # Only set PROMPT_COMMAND if Starship is not installed
#     PROMPT_COMMAND="set_title; build_prompt"
#   fi

#   # set locale
#   export LANG=en_US.UTF-8

#   # Apply changes
#   source ${DIVTOOLS}/dotfiles/.bash_aliases
# fi

# if has_starship; then
#   # Call Starship if it is installed
#   eval "$(starship init bash)"

#   # Build the ~/.config/starship.toml file
#   build_starship_toml
# fi

# # TMUX Config
# tmux_config

# Usage example in your script
if [[ $- == *i* ]]; then
    # interactive shell
    # Set locale
    export LANG=en_US.UTF-8

    # Apply changes
    source ${DIVTOOLS}/dotfiles/.bash_aliases

    # Clear any residual Starship environment variables
    unset STARSHIP_START_TIME STARSHIP_PREEXEC_READY STARSHIP_SHELL STARSHIP_SESSION_KEY

    # Initialize prompt with fallback
    unset PS1  # Clear PS1 to avoid conflicts
    PROMPT_COMMAND="set_title; build_prompt"  # Default to custom prompt

    # Attempt Starship initialization if available
    if has_starship; then
        log_msg "STAR" "Starship detected and initializing"
        # Run starship init in a subshell and capture output
        starship_output=$(starship init bash 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$starship_output" ]; then
            eval "$starship_output"
            # Only build starship.toml if initialization succeeded
            build_starship_toml
            log_msg "INFO" "Starship initialized successfully."
        else
            log_msg "WARNING" "Starship initialization failed; falling back to custom prompt."
            unset PS1
            PROMPT_COMMAND="set_title; build_prompt"
        fi
    else
        log_msg "INFO" "Starship not installed; using custom prompt."
        unset PS1
        PROMPT_COMMAND="set_title; build_prompt"
    fi

    # TMUX Config
    tmux_config

    # Load environment files BEFORE host setup checks
    # This ensures DT_INCLUDE_* variables are available for host_setup_checks
    # Last Updated: 11/11/2025 9:30:00 PM CDT
    if declare -f load_env_files >/dev/null 2>&1; then
        load_env_files  # Don't suppress output - we want exported variables to be available
    fi

    # Host Setup Checks - MUST BE LAST in interactive shell initialization
    # Check if host setup tasks need to be completed and prompt user if configured
    # Last Updated: 11/18/2025 10:45:00 PM CST
    #
    # Note: This will only run if DT_INCLUDE_* variables are set
    # Set in .env files at user/host/site/shared level
    HOST_SETUP_CHECKS_SCRIPT="${DIVTOOLS:-/opt/divtools}/scripts/util/host_setup_checks.sh"
    if [ -f "$HOST_SETUP_CHECKS_SCRIPT" ]; then
        # Source the script (it will prevent double-sourcing)
        source "$HOST_SETUP_CHECKS_SCRIPT"
        # Call the function to perform checks (only if function is defined)
        if declare -f host_setup_checks >/dev/null 2>&1; then
            host_setup_checks
        fi
    fi
fi

# Now that we are done building things, update the Profile Timestamp.
update_profile_timestamp
