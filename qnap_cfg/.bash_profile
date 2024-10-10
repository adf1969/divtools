if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
	echo "$(date): Running /opt/home/root/.bash_profile"


	# Color Variables
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

	# Reset Color
	C_RESET='\[\e[m\]'

	PATH=/opt/bin:/opt/sbin:$PATH

fi

# Function to set PuTTY window title
function set_title {
  local tty_num=$(tty | sed 's:/dev/pts/::')
  local host_ip=$(hostname -s)
  local user=$(whoami)
  local path=$(pwd)

  local title="${tty_num}"
  # Include TTY_TITLE if it is set
  if [ -n "$TTY_TITLE" ]; then
    title="$title:${TTY_TITLE}"
  fi
  echo -ne "\033]0;${title} - ${user}@${host_ip} [${path}]\007"
}

# Function to check Git sync status
check_git_sync() {
    # Only run if GIT_SET_PROMPT is set to 1
    if [ "$GIT_SET_PROMPT" = "1" ]; then
        # Check if we are in a Git repository
        if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
            # Check if the remote repository 'origin' exists
            if git remote | grep -q '^origin$'; then
                # Fetch the latest changes from the remote repository
                git fetch origin -q

                # Get the current branch name
                local branch=$(git rev-parse --abbrev-ref HEAD)

                # Compare local and remote branches
                local local_commit=$(git rev-parse $branch)
                local remote_commit=$(git rev-parse origin/$branch)
                local base_commit=$(git merge-base $branch origin/$branch)

                if [ "$local_commit" = "$remote_commit" ]; then
                    echo -e "\[\033[0;32m\]✔ " # Green check mark (in sync)
                elif [ "$local_commit" = "$base_commit" ]; then
                    echo -e "\[\033[0;31m\]✘ " # Red cross mark (behind)
                elif [ "$remote_commit" = "$base_commit" ]; then
                    echo -e "\[\033[0;33m\]➜ " # Yellow arrow (ahead)
                else
                    echo -e "\[\033[0;31m\]⚠ " # Red warning (diverged)
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
            echo -e "\[\033[0;31m\] ✘ " # Red cross mark (behind)
        elif [[ $status == *"ahead"* ]]; then
            echo -e "\[\033[0;33m\] > " # Yellow arrow (ahead)
        elif [[ $status == *"diverged"* ]]; then
            echo -e "\[\033[0;31m\] ! " # Red warning (diverged)
        else
            echo -e "\[\033[0;32m\] ✔ " # Green check mark (in sync)
        fi
    else
        echo ""
    fi
}



# Function to dynamically build the PS1 prompt
build_prompt() {
  local PS1_ROOT=""
  local PS1_CHAR=""
  case "$(whoami)" in
    admin)
      PS1_ROOT="${C_BG_RED}ROOT${C_RESET} "
      PS1_CHAR="#"
      ;;
    *)
      PS1_CHAR="\$"
      ;;
  esac

  local PS1_PROMPT=""
  case "$(hostname -s)" in
    FHM4x8)
      PS1_PROMPT="${C_GREEN}[\u@\h \w]${PS1_CHAR}${C_RESET}"
      ;;
    FHMTN1)
      PS1_PROMPT="${C_BRIGHTBLUE}[\u@\h \w]${PS1_CHAR}${C_RESET}"
      ;;
    CVGNAS1)
      PS1_PROMPT="${C_CYAN}[\u@\h \w]${PS1_CHAR}${C_RESET}"
      ;;
    *)
      PS1_PROMPT="${C_WHITE}[\u@\h \w]${PS1_CHAR}${C_RESET}"
      ;;
  esac

  PS1="${PS1_ROOT}$(check_git_sync)${PS1_PROMPT} "
}

if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
  # Preserve the existing PROMPT_COMMAND if set
  if [ -n "$PROMPT_COMMAND" ]; then
    PROMPT_COMMAND="$PROMPT_COMMAND; set_title; build_prompt"
  else
    PROMPT_COMMAND="set_title; build_prompt"
  fi

  # Apply changes
  source /opt/home/root/.bash_aliases
fi
