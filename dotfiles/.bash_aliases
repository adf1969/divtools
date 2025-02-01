# aliases
echo "$(date): Running $DIVTOOLS/dotfiles/.bash_aliases"

# Global Env Vars
export DOCKERDIR=/opt/divtools/docker
export DOCKERFILE=$DOCKERDIR/docker-compose-$HOSTNAME.yml
export DOCKERDATADIR=/opt

force_color_prompt=yes

### FUNCTIONS ###

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

# Source Dotfiles
alias sep='source /etc/profile'
alias sbrc='source ~/.bashrc'
alias sba='source $DIVTOOLS/dotfiles/.bash_aliases'
alias sbp='source $DIVTOOLS/dotfiles/.bash_profile'

# Script Folder Aliases
alias chgid='$DIVTOOLS/scripts/chgid.sh'
alias ffugid='$DIVTOOLS/scripts/find_ugid_files.sh'

# GENERAL QOL ALIASES
# navigation
alias ..='cd ..'
alias ...='cd ../..'
alias .3='cd ../../..'
alias .4='cd ../../../..'
alias .5='cd ../../../../..'
# adding flags
alias df='df -h'               # human-readable sizes
alias free='free -m'           # show sizes in MB

# ps
alias psa="ps auxf"
alias psgrep="ps aux | grep -v grep | grep -i -e VSZ -e"
alias psmem='ps auxf | sort -nr -k 4'
alias pscpu='ps auxf | sort -nr -k 3'




# DIVTOOL QOL ALIASES
alias dt='cd $DIVTOOLS'
alias dtd='cd $DOCKERDIR'
alias pdiv='sudo chown -R divix $DOCKERDIR $DIVTOOLS/config $DIVTOOLS/scripts $DIVTOOLS/dotfiles $DIVTOOLS/.git'

# Utility Aliases
#alias su='sudo -u admin sh'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias grep='grep --color=auto'
alias ls='ls --color=auto -la'
alias l='ls -CF'
alias la='ls -al'
alias ll='ls -alF'
alias h='history'
alias gid='getent group'
alias alg='alias | grep -i '
# Match all files and color everything after the #. This is to allow ARGS to be shown for the various aliases and found with: "algg <char>"
alias algg="cat $DIVTOOLS/dotfiles/.bash_aliases $DIVTOOLS/dotfiles/.bash_profile | grep --color=always -E '#.*$' | grep alias | grep -i "

# EZA

# Changing "ls" to "eza"
if has_eza; then
  alias ls='eza -al --color=always --group --group-directories-first' # my preferred listing
  alias la='eza -a --color=always --group --group-directories-first'  # all files and dirs
  alias ll='eza -l --color=always --group --group-directories-first'  # long format
  alias lt='eza -aT --color=always --group --group-directories-first' # tree listing
  alias l.='eza -al --color=always --group --group-directories-first ../' # ls on the PARENT directory
  alias l..='eza -al --color=always --group --group-directories-first ../../' # ls on directory 2 levels up
  alias l...='eza -al --color=always --group --group-directories-first ../../../' # ls on directory 3 levels up
fi

# Title Aliases
alias settitle='source $DIVTOOLS/scripts/settitle'
alias gitpon='gitpon_func'
alias gitpoff='gitpoff_func'

# Generic Docker Aliases
alias dils='docker image ls'
alias dpsn='docker container ls --format '\''table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.RunningFor}}\t{{.Status}}\t{{.Size}}'\''' 
alias dps='$DIVTOOLS/scripts/docker_ps.sh'
alias dlistrp='$DIVTOOLS/scripts/list_restart_policies.sh'

# Syncthing
alias stfc='find . -type f -not -path "*/.stversions/*" -name "*sync-conflict*"'

# DASHY
alias fdicon='find $DOCKERDIR/appdata/dashy/dashboard-icons/png -printf "%f\n" | grep -i ' # Find Dashy Icons, Usage: dicon <icon name>
alias fdicons=fdicon

# VIM Aliases
#alias vi='nvim'
#alias vim='nvim'

# Set Aliases based upon DOCKER_LOCALFILE or not
if [ -f $DOCKERFILE ] ; then
  # We have a Local DockerFile - All settings are for that config

  # DOCKER - All Docker commands start with "d" AND Docker Compose commands start with "dc"
  alias dstop='sudo docker stop $(sudo docker ps -a -q)' # usage: dstop container_name
  alias dstopall='sudo docker stop $(sudo docker ps -aq)' # stop all containers
  alias drm='sudo docker rm $(sudo docker ps -a -q)' # usage: drm container_name
  alias dprunevol='sudo docker volume prune' # remove unused volumes
  alias dprunesys='sudo docker system prune -a' # remove unsed docker data
  alias ddelimages='sudo docker rmi $(sudo docker images -q)' # remove unused docker images
  alias derase='dstopcont ; drmcont ; ddelimages ; dvolprune ; dsysprune' # WARNING: removes everything! 
  alias dprune='ddelimages ; dprunevol ; dprunesys' # remove unused data, volumes, and images (perfect for safe clean up)
  alias dexec='sudo docker exec -ti' # usage: dexec container_name (to access container terminal)
  alias dpss='sudo docker ps -a' # running docker processes
  #alias dpss='sudo docker ps -a --format "table {{.Names}}\t{{.State}}\t{{.Status}}\t{{.Image}}" | (sed -u 1q; sort)' # running docker processes as nicer table
  alias ddf='sudo docker system df' # docker data usage (/var/lib/docker)
  alias dlogs='sudo docker logs -tf --tail="50" ' # usage: dlogs container_name
  alias dlogsize='sudo du -ch $(sudo docker inspect --format='{{.LogPath}}' $(sudo docker ps -qa)) | sort -h' # see the size of docker containers
  alias dips="sudo docker ps -q | xargs -n 1 sudo docker inspect -f '{{.Name}}%tab%{{range .NetworkSettings.Networks}}{{.IPAddress}}%tab%{{end}}' | sed 's#%tab%#\t#g' | sed 's#/##g' | sort | column -t -N NAME,IP\(s\) -o $'\t'"

  alias dp600='sudo chown -R root:root $DOCKERDIR/secrets ; sudo chmod -R 600 $DOCKERDIR/secrets ; sudo chown -R root:root $DOCKERDIR/.env ; sudo chmod -R 600 $DOCKERDIR/.env' # re-lock permissions
  alias dp777='sudo chown -R $USER:$USER $DOCKERDIR/secrets ; sudo chmod -R 777 $DOCKERDIR/secrets ; sudo chown -R $USER:$USER $DOCKERDIR/.env ; sudo chmod -R 777 $DOCKERDIR/.env' # open permissions for editing

  # DOCKER COMPOSE TRAEFIK 2 - All docker-compose commands start with "dc" 
  case "${ID}" in
    ds918): # synology at this point uses an old version of docker. Therefore, 'docker-compose' instead of 'docker compose'
      alias dcrun='source $DOCKERDIR/.env.host && sudo docker-compose -f $DOCKERDIR/docker-compose-$HOSTNAME.yml' # /volume1/docker symlinked to /var/services/homes/user/docker
    ;;
    *):     # Every Other Normal Server
      # Original dcrun
      #alias dcrun='sudo docker compose --profile all -f $DOCKERDIR/docker-compose-$HOSTNAME.yml'      

      # Add hostname explictly
      #alias dcrun='HOSTNAME=$(hostname) sudo docker compose --profile all -f $DOCKERDIR/docker-compose-$HOSTNAME.yml'      

      # Pass user .env.host to sudo/dc. This gets $HOSTNAME into the global dc-$HOSTNAME.yml file
      alias dcrun='source $DOCKERDIR/.env.host && sudo -E docker compose --profile all -f $DOCKERDIR/docker-compose-$HOSTNAME.yml'
      #alias dcrun='source $DOCKERDIR/.env.host && sudo -E docker compose -f $DOCKERDIR/docker-compose-$HOSTNAME.yml'      
      #alias dcrun='sudo docker compose --profile all -f $DOCKERDIR/docker-compose-$HOSTNAME.yml'
      
    ;;
  esac

  alias dclogs='dcrun logs -tf --tail="50" ' # usage: dclogs container_name
  alias dcup='dcrun up -d --build --remove-orphans' # up the stack
  alias dcdown='dcrun down --remove-orphans' # down the stack
  alias dcrec='dcrun up -d --force-recreate --remove-orphans' # usage: dcrec container_name
  alias dcstop='dcrun stop' # usage: dcstop container_name
  alias dcrestart='dcrun restart ' # usage: dcrestart container_name
  alias dcstart='dcrun start ' # usage: dcstart container_name
  alias dcpull='dcrun pull' # usage: dcpull to pull all new images or dcpull container_name
  alias traefiklogs='tail -f /opt/traefik/logs/traefik.log' # tail traefik logs
  alias dcchk='$DIVTOOLS/scripts/dt_yamlcheck.sh -show-errors $DOCKERDIR/docker-compose-$HOSTNAME.yml'

  # Manage "core" services as defined by profiles in docker compose
  alias startcore='sudo docker compose --profile core -f $DOCKERDIR/docker-compose-$HOSTNAME.yml start'
  alias createcore='sudo docker compose --profile core -f $DOCKERDIR/docker-compose-$HOSTNAME.yml up -d --build --remove-orphans'
  alias stopcore='sudo docker compose --profile core -f $DOCKERDIR/docker-compose-$HOSTNAME.yml stop'
  # Manage "media" services as defined by profiles in docker compose
  alias stopmedia='sudo docker compose --profile media -f $DOCKERDIR/docker-compose-$HOSTNAME.yml stop'
  alias createmedia='sudo docker compose --profile media -f $DOCKERDIR/docker-compose-$HOSTNAME.yml up -d --build --remove-orphans'
  alias startmedia='sudo docker compose --profile media -f $DOCKERDIR/docker-compose-$HOSTNAME.yml start'
  # Manage "diwkiads" services as defined by profiles in docker compose
  alias stopdownloads='sudo docker compose --profile downloads -f $DOCKERDIR/docker-compose-$HOSTNAME.yml stop'
  alias createdownloads='sudo docker compose --profile downloads -f $DOCKERDIR/docker-compose-$HOSTNAME.yml up -d --build --remove-orphans'
  alias startdownloads='sudo docker compose --profile downloads -f $DOCKERDIR/docker-compose-$HOSTNAME.yml start'
  # Manage Starr apps as defined by profiles in docker compose
  alias stoparrs='sudo docker compose --profile arrs -f $DOCKERDIR/docker-compose-$HOSTNAME.yml stop'
  alias startarrs='sudo docker compose --profile arrs -f $DOCKERDIR/docker-compose-$HOSTNAME.yml start'
  alias createarrs='sudo docker compose --profile arrs -f $DOCKERDIR/docker-compose-$HOSTNAME.yml up -d --build --remove-orphans'
  # Manage "dbs" (database) services as defined by profiles in docker compose
  alias stopdbs='sudo docker compose --profile dbs -f $DOCKERDIR/docker-compose-$HOSTNAME.yml stop'
  alias createdbs='sudo docker compose --profile dbs -f $DOCKERDIR/docker-compose-$HOSTNAME.yml up -d --build --remove-orphans'
  alias startdbs='sudo docker compose --profile dbs -f $DOCKERDIR/docker-compose-$HOSTNAME.yml start'
  
  # Generic Docker Compose Aliaes
  alias dc='docker compose'
else
  # No DOCKER_LOCALFILE - docker files all run according to folder
  alias docker-compose='docker compose'
  alias dc='docker compose'
  alias dcup='docker compose up -d'
  alias distartpolicy='docker inspect --format '{{.HostConfig.RestartPolicy.Name}}'' #name#
  alias dstart='docker start' #name#
  alias dsetrestart='docker update --restart unless-stopped' #name#  
fi


# GIT
alias greset='git fetch origin && git reset --hard origin/main'
alias ggraph='git log --all --decorate --oneline --graph'

# SSH
alias ssha='eval $(ssh-agent) && ssh-add'

# UFW FIREWALL
alias ufwenable='sudo ufw enable'
alias ufwdisable='sudo ufw disable'
alias ufwallow='sudo ufw allow'
alias ufwlimit='sudo ufw limit'
alias ufwlist='sudo ufw status numbered'
alias ufwdelete='sudo ufw delete'
alias ufwreload='sudo ufw reload'

# JOURNALCTL
alias jcu='journalctl -u'
alias jceu='journalctl -eu'
alias jcfu='journalctl -fu'

# SYSTEMD START, STOP AND RESTART | sc
alias screload='sudo systemctl daemon-reload'
alias scstart='sudo systemctl start'
alias scstop='sudo systemctl stop'
alias screstart='sudo systemctl restart'
alias scstatus='sudo systemctl status'
alias scenable='sudo systemctl enable'
alias scdisable='sudo systemctl disable'
alias scactive='sudo systemctl is-active'

# SYSTEMD START, STOP AND RESTART | ctl
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

# Syncthing Aliases
if container_exists "syncthing"; then
  # Syncthing loaded in a Container
  alias ststart='dcstart syncthing'
  alias strestart='dcrestart syncthing'
  alias ststop='dcstop syncthing'
  alias ststatus='dpsn | grep syncthing'
  alias stlogs='docker logs -f syncthing'

else
  # Syncthing loaded locally using systemd  
  alias ststart='sudo systemctl start syncthing'
  alias strestart='sudo systemctl restart syncthing'
  alias ststop='sudo systemctl stop syncthing'
  alias ststatus='sudo systemctl status syncthing'
  alias stlogs='journalctl -eu syncthing'
fi

# Samba
if [ -f ~/.smb_credentials ]; then
  alias smbcacls="smbcacls --authentication-file=$HOME/.smb_credentials "
fi

# Starship
if has_starship; then
  alias bsst="build_starship_toml"
fi

if has_zfs; then
  alias sslsz="zfs list -t snapshot"
fi

if has_qm; then
  alias ssqmstop="qm stop" # <VMID>
  alias ssqmstart="qm start" # <VMID>

  alias qmstop="qm stop" # <VMID>  | Power Off
  alias qmshut="qm shutdown" # <VMID> | Clean Shutdown
  alias qmstart="qm start" # <VMID>
  alias qms="qm status" # <VMID> |--verbose|  
  alias qmrb="qm rollback" # <VMID> <SNAPSHOT-NAME> |--start|

  # QM Functions
  qmid() { # alias function: qmid <vmid>
      if [ $# -eq 0 ]; then
          echo "Usage: qmid <vmid>"
          return 1
      fi

      local vmid="$1"
      local vm_name

      vm_name=$(qm config "$vmid" 2>/dev/null | grep '^name:' | awk '{print $2}')
      if [ -z "$vm_name" ]; then
          echo "Error: Could not find VM with ID $vmid"
          return 1
      fi

      echo "$vm_name"
  }

  qmls() { # alias function: qmls <vmid>
      if [ $# -eq 0 ]; then
          echo "Usage: qmls <vmid>"
          return 1
      fi

      local vmid="$1"
      local vm_name
      local snapshots

      # Get the VM name
      vm_name=$(qm config "$vmid" 2>/dev/null | grep '^name:' | awk '{print $2}')
      if [ -z "$vm_name" ]; then
          echo "Error: Could not find VM with ID $vmid"
          return 1
      fi

      echo "VM Name: $vm_name"

      # Get the list of snapshots
      snapshots=$(qm listsnapshot "$vmid" 2>/dev/null)
      if [ $? -ne 0 ]; then
          echo "Error: Unable to list snapshots for VM ID $vmid"
          return 1
      fi

      echo "Snapshots:"
      echo "$snapshots"
  }



fi

# HOSTNAME Specific Aliases

case "${HOSTNAME_U}" in
  EDMS):
    alias dtm='cd ${DOCKERDIR}/include/edms/mayan'
    # For managing the docker-compose file in mayan folder
    alias docker-compose='docker compose'
    alias dc='docker compose'
    alias dcup='docker compose up -d'
    alias distartpolicy='docker inspect --format '{{.HostConfig.RestartPolicy.Name}}'' #name#
    alias dstart='docker start' #name#
    alias dsetrestart='docker update --restart unless-stopped' #name#  
  ;;
  TRAEFIK):
    alias dashyvc='dexec dashy yarn validate-config'
    alias dashyb='dexec dashy yarn build'
  ;;
esac

# OS Specific Aliases
case "${ID}" in
  debian|ubuntu):
    alias updalted='update-alternatives --config editor'
    alias sup='sudo -u root bash --rcfile /etc/profile'

  ;;
  qts):     # QNAP
    #alias su='sudo -u admin -i'
    alias su='sudo -u admin bash --rcfile /etc/profile'
    alias sup='sudo -u admin bash --rcfile /etc/profile'
  ;;
esac
