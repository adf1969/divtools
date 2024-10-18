# Exports
export DIVTOOLS="/opt/divtools"
export HOSTNAME_U=$(hostname -s | tr '[:lower:]' '[:upper:]')

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

fi

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
      PS1_ROOT="${C_BG_RED}ROOT${C_RESET} "
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
    FHM4x8)
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
      HOST_COL=${C_WHITE}
      #PS1_PROMPT="${C_WHITE}[\u@\h \w]${PS1_CHAR}${C_RESET}"
      ;;
  esac

  # Single-Line PS1
  #PS1="${PS1_ROOT}$(check_git_sync)${PS1_PROMPT} "

  # Multi-line PS1
  PS1="${HOST_COL}┌──(${C_BOLD}\u@\h${C_BOLD_OFF})-[\w]\n${HOST_COL}└─${PS1_ROOT}${GIT_CHAR}$(check_git_sync) ${HOST_COL}${PS1_CHAR}${C_RESET} "  

}

if [[ $- == *i* ]]; then
  # interactive shell
  PROMPT_COMMAND="set_title; build_prompt"

  # Apply changes
  source ${DIVTOOLS}/dotfiles/.bash_aliases
fi

