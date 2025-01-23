# Exports
export DIVTOOLS="/opt/divtools"
export HOSTNAME_U=$(hostname -s | tr '[:lower:]' '[:upper:]')


# Function to check if Starship is installed
has_starship() {
  command -v starship &> /dev/null
}

# Function to check if Starship is installed
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

    # Check if the directory exists
    if [[ -d "$dir" ]]; then
        # Check if it's already in PATH
        if [[ ":$PATH:" != *":$dir:"* ]]; then
            export PATH="$dir:$PATH"
            echo "Added $dir to PATH."
        else
            echo "$dir is already in PATH."
        fi
    else
        echo "Directory $dir does not exist."
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
    echo "Starship configuration built successfully at: $STARSHIP_CONFIG_FILE"
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

    echo "DT_STARSHIP_PRESET is set to '$DT_STARSHIP_PRESET'"

    # Check if the preset file exists and process it
    local preset_file="$DT_STARSHIP_PRESET_DIR/$DT_STARSHIP_PRESET.toml"
    if [ -f "$preset_file" ]; then
        echo "Processing preset file: $preset_file"

        # Add palette reference to the starship.toml file
        cat <<EOF >> "$STARSHIP_CONFIG_FILE"
###
### Palette: 
palette = "${DT_STARSHIP_PALETTE}"
###

EOF

        # Extract and handle override sections as before
        local override_file="$DT_STARSHIP_OVERRIDE_DIR/$HOSTNAME.toml"
        local override_sections=()
        if [ -f "$override_file" ]; then
            echo "Processing override file: $override_file"
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
            echo "Removed sections from preset file: $removed_sections"
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
        echo "Added filtered preset file to $STARSHIP_CONFIG_FILE"
        rm "$tmp_preset_file"
    fi

    # Append the override file directly to the starship.toml
    if [ -f "$override_file" ]; then
        echo "Appending override file: $override_file to $STARSHIP_CONFIG_FILE"
        cat <<EOF >> "$STARSHIP_CONFIG_FILE"
###
### Source: $override_file
###
EOF
        cat "$override_file" >> "$STARSHIP_CONFIG_FILE"
        echo "Added override file to $STARSHIP_CONFIG_FILE"
    fi
} # build_starship_toml_preset




function build_starship_toml_palette() {
    local STARSHIP_CONFIG_FILE=$1
    local hostname=$(hostname)
    local palette_file="$DT_STARSHIP_PALETTE_DIR/$DT_STARSHIP_PALETTE.toml"
    local hostname_palette_file="$DT_STARSHIP_PALETTE_DIR/$DT_STARSHIP_PALETTE-${hostname}.toml"

    # Associative arrays to hold palette entries and comments per section
    declare -A palette_sections
    declare -A palette_comments
    declare -A palette_sources

    # Function to parse a palette file and store entries under the correct section
    parse_palette_file() {
        local file=$1
        local source_label=$2
        local current_section=""
        echo "Parsing palette file: $file"

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
                echo "Detected palette section: $current_section"
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
                echo "Line did not match expected pattern: $line"
            fi
        done < "$file"
    }

    # Parse the main palette file
    if [ -f "$palette_file" ]; then
        echo "Processing main palette file: $palette_file"
        parse_palette_file "$palette_file" "divtools"
    else
        echo "Main palette file not found: $palette_file"
    fi

    # Parse the hostname-specific palette file and override entries
    if [ -f "$hostname_palette_file" ] && [ -s "$hostname_palette_file" ]; then
        echo "Processing hostname-specific palette file: $hostname_palette_file"
        parse_palette_file "$hostname_palette_file" "$hostname"
    else
        echo "Hostname-specific palette file not found or empty: $hostname_palette_file"
    fi

    # Write the combined palette to the starship.toml file
    if [ ${#palette_sections[@]} -eq 0 ]; then
        echo "No palette entries found to write to $STARSHIP_CONFIG_FILE"
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
            echo "Written entries for section: $section"
        done

        echo "Combined and written palette entries to $STARSHIP_CONFIG_FILE"
    fi
} # build_starship_toml_palette



### INIT CODE ###

if [[ $- == *i* ]]; then
  # interactive shell
	echo "$(date): Running $DIVTOOLS/dotfiles/.bash_profile"

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

  add_to_path "/usr/local/samba/bin"

  # Load any Local Env
  if [ -f ~/.bash_local_env ] ; then
    . ~/.bash_local_env
  fi
fi


# Usage example in your script
if [[ $- == *i* ]]; then
  # interactive shell
  if ! has_starship; then
    # Only set PROMPT_COMMAND if Starship is not installed
    PROMPT_COMMAND="set_title; build_prompt"
  fi

  # set locale
  export LANG=en_US.UTF-8

  # Apply changes
  source ${DIVTOOLS}/dotfiles/.bash_aliases
fi

if has_starship; then
  # Call Starship if it is installed
  eval "$(starship init bash)"

  # Build the ~/.config/starship.toml file
  build_starship_toml
fi

