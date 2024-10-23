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


# UFW FIREWALL
alias ufwenable='sudo ufw enable'
alias ufwdisable='sudo ufw disable'
alias ufwallow='sudo ufw allow'
alias ufwlimit='sudo ufw limit'
alias ufwlist='sudo ufw status numbered'
alias ufwdelete='sudo ufw delete'
alias ufwreload='sudo ufw reload'

# SYSTEMD START, STOP AND RESTART
alias ctlreload='sudo systemctl daemon-reload'
alias ctlstart='sudo systemctl start'
alias ctlstop='sudo systemctl stop'
alias ctlrestart='sudo systemctl restart'
alias ctlstatus='sudo systemctl status'
alias ctlenable='sudo systemctl enable'
alias ctldisable='sudo systemctl disable'
alias ctlactive='sudo systemctl is-active'

alias shellstart='ctlstart shellinabox'
alias shellstop='ctlstop shellinabox'
alias shellrestart='ctlrestart shellinabox'
alias shellstatus='ctlstatus shellinabox'

alias sshstart='ctlstart ssh'
alias sshstop='ctlstop ssh'
alias sshrestart='ctlrestart ssh'
alias sshstatus='ctlstatus ssh'

alias ufwstart='ctlstart ufw'
alias ufwstop='ctlstop ufw'
alias ufwrestart='ctlrestart ufw'
alias ufwstatus='ctlstatus ufw'

alias webminstart='ctlstart webmin'
alias webminstop='ctlstop webmin'
alias webminrestart='ctlrestart webmin'
alias webminstatus='ctlstatus webmin'

alias sambastart='ctlstart smbd'
alias sambastop='ctlstop smbd'
alias sambarestart='ctlrestart smbd'
alias sambastatus='ctlstatus smbd'

alias nfsstart='ctlstart nfs-kernel-server'
alias nfsstop='ctlstop nfs-kernel-server'
alias nfsrestart='ctlrestart nfs-kernel-server'
alias nfsstatus='ctlstatus nfs-kernel-server'
alias nfsreload='sudo exportfs -a'


# INSTALLATION AND UPGRADE
alias update='sudo apt-get update'
alias upgrade='sudo apt-get update && sudo apt-get upgrade'
alias install='sudo apt-get install'
alias finstall='sudo apt-get -f install'
alias rinstall='sudo apt-get -f install --reinstall'
alias uninstall='sudo apt-get remove'
alias search='sudo apt-cache search'
alias addkey='sudo apt-key adv --recv-keys --keyserver keyserver.ubuntu.com'


# NETWORKING
alias portsused='sudo netstat -tulpn | grep LISTEN'
alias showports='netstat -lnptu'
alias showlistening='lsof -i -n | egrep "COMMAND|LISTEN"'
alias ping='ping -c 5'
alias ipe='curl ipinfo.io/ip' # external ip
alias ipi='ifconfig eth0' # internal ip
alias header='curl -I' # get web server headers 


# OS Specific Aliases
case "${ID}" in
  debian|ubuntu):
    alias updalted='update-alternatives --config editor'
  ;;
  qts):     # QNAP
    alias su='sudo -u admin -i'
  ;;
esac
