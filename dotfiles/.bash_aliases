# aliases
echo "$(date): Running $DIVTOOLS/dotfiles/.bash_aliases"

# Utility Aliases
#alias su='sudo -u admin sh'
#alias egrep='egrep --color=auto'
#alias fgrep='fgrep --color=auto'
#alias grep='grep --color=auto'
alias ls='ls --color=auto -la'
alias l='ls -CF'
alias la='ls -A'
alias ll='ls -alF'
alias h='history'

# Title Aliases
alias settitle='source $DIVTOOLS/scripts/settitle'
alias gitpon='gitpon_func'
alias gitpoff='gitpoff_func'

# Docker Aliases
alias dils='docker image ls'
alias dpsn='docker container ls --format '\''table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.RunningFor}}\t{{.Status}}\t{{.Size}}'\'''
force_color_prompt=yes
alias dps='$DIVTOOLS/scripts/docker_ps.sh'

# VIM Aliases
#alias vi='nvim'
#alias vim='nvim'
alias docker-compose='docker compose'
alias dc='docker-compose'
alias dcup='docker-compose up -d'
alias distartpolicy='docker inspect --format '{{.HostConfig.RestartPolicy.Name}}'' #name#
alias dstart='docker start' #name#
alias dsetrestart='docker update --restart unless-stopped' #name#
alias dlistrp='$DIVTOOLS/scripts/list_restart_policies.sh'


# OS Specific Aliases
case "${ID}" in
  debian|ubuntu):
    alias updalted='update-alternatives --config editor'
  ;;
  qts):     # QNAP
    alias su='sudo -u admin -i'
  ;;
esac
