# aliases
echo "$(date): Running /opt/etc/config/.bash_aliases"

# Utility Aliases
#alias su='sudo -u admin sh'
alias su='sudo -u admin -i'
#alias egrep='egrep --color=auto'
#alias fgrep='fgrep --color=auto'
#alias grep='grep --color=auto'
alias ls='ls --color=auto -la'
alias l='ls -CF'
alias la='ls -A'
alias ll='ls -alF'
alias h='history'

# Title Aliases
alias settitle='source /opt/home/root/scripts/settitle'
alias gitpon='GIT_SET_PROMPT=1'
alias gitpoff='GIT_SET_PROMPT=0'

# Docker Aliases
alias dils='docker image ls'
alias dpsn='docker container ls --format '\''table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.RunningFor}}\t{{.Status}}\t{{.Size}}'\'''
force_color_prompt=yes
alias dps='/opt/home/root/scripts/docker_ps.sh'

# VIM Aliases
#alias vi='nvim'
#alias vim='nvim'
cker-compose='docker compose'
alias dc='docker-compose'
alias dcup='docker-compose up -d'
alias distartpolicy='docker inspect --format '{{.HostConfig.RestartPolicy.Name}}'' #name#
alias dstart='docker start' #name#
alias dsetrestart='docker update --restart unless-stopped' #name#
alias dlistrp='/opt/home/root/scripts/list_restart_policies.sh'


