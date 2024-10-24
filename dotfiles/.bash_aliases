# aliases
echo "$(date): Running $DIVTOOLS/dotfiles/.bash_aliases"

# Global Env Vars
export DOCKER_LOCALDIR=/opt/divtools/docker/local
export DOCKER_LOCALFILE=$DOCKER_LOCALDIR/docker-compose-$HOSTNAME.yml

force_color_prompt=yes

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

# Generic Docker Aliases
alias dils='docker image ls'
alias dpsn='docker container ls --format '\''table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.RunningFor}}\t{{.Status}}\t{{.Size}}'\''' 
alias dps='$DIVTOOLS/scripts/docker_ps.sh'
alias dlistrp='$DIVTOOLS/scripts/list_restart_policies.sh'

# VIM Aliases
#alias vi='nvim'
#alias vim='nvim'

# Set Aliases based upon DOCKER_LOCALFILE or not
if [ -f $DOCKER_LOCALFILE ] ; then
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

  alias dp600='sudo chown -R root:root $DOCKER_LOCALDIR/secrets ; sudo chmod -R 600 $DOCKER_LOCALDIR/secrets ; sudo chown -R root:root $DOCKER_LOCALDIR/.env ; sudo chmod -R 600 $DOCKER_LOCALDIR/.env' # re-lock permissions
  alias dp777='sudo chown -R $USER:$USER $DOCKER_LOCALDIR/secrets ; sudo chmod -R 777 $DOCKER_LOCALDIR/secrets ; sudo chown -R $USER:$USER $DOCKER_LOCALDIR/.env ; sudo chmod -R 777 $DOCKER_LOCALDIR/.env' # open permissions for editing

  # DOCKER COMPOSE TRAEFIK 2 - All docker-compose commands start with "dc" 
  case "${ID}" in
    ds918): # synology at this point uses an old version of docker. Therefore, 'docker-compose' instead of 'docker compose'
      alias dcrun='sudo docker-compose -f $DOCKER_LOCALDIR/docker-compose-$HOSTNAME.yml' # /volume1/docker symlinked to /var/services/homes/user/docker
    ;;
    *):     # Every Other Normal Server
      alias dcrun='sudo docker compose --profile all -f $DOCKER_LOCALDIR/docker-compose-$HOSTNAME.yml'
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
  alias traefiklogs='tail -f $DOCKER_LOCALDIR/logs/$HOSTNAME/traefik/traefik.log' # tail traefik logs

  # Manage "core" services as defined by profiles in docker compose
  alias startcore='sudo docker compose --profile core -f $DOCKER_LOCALDIR/docker-compose-$HOSTNAME.yml start'
  alias createcore='sudo docker compose --profile core -f $DOCKER_LOCALDIR/docker-compose-$HOSTNAME.yml up -d --build --remove-orphans'
  alias stopcore='sudo docker compose --profile core -f $DOCKER_LOCALDIR/docker-compose-$HOSTNAME.yml stop'
  # Manage "media" services as defined by profiles in docker compose
  alias stopmedia='sudo docker compose --profile media -f $DOCKER_LOCALDIR/docker-compose-$HOSTNAME.yml stop'
  alias createmedia='sudo docker compose --profile media -f $DOCKER_LOCALDIR/docker-compose-$HOSTNAME.yml up -d --build --remove-orphans'
  alias startmedia='sudo docker compose --profile media -f $DOCKER_LOCALDIR/docker-compose-$HOSTNAME.yml start'
  # Manage "diwkiads" services as defined by profiles in docker compose
  alias stopdownloads='sudo docker compose --profile downloads -f $DOCKER_LOCALDIR/docker-compose-$HOSTNAME.yml stop'
  alias createdownloads='sudo docker compose --profile downloads -f $DOCKER_LOCALDIR/docker-compose-$HOSTNAME.yml up -d --build --remove-orphans'
  alias startdownloads='sudo docker compose --profile downloads -f $DOCKER_LOCALDIR/docker-compose-$HOSTNAME.yml start'
  # Manage Starr apps as defined by profiles in docker compose
  alias stoparrs='sudo docker compose --profile arrs -f $DOCKER_LOCALDIR/docker-compose-$HOSTNAME.yml stop'
  alias startarrs='sudo docker compose --profile arrs -f $DOCKER_LOCALDIR/docker-compose-$HOSTNAME.yml start'
  alias createarrs='sudo docker compose --profile arrs -f $DOCKER_LOCALDIR/docker-compose-$HOSTNAME.yml up -d --build --remove-orphans'
  # Manage "dbs" (database) services as defined by profiles in docker compose
  alias stopdbs='sudo docker compose --profile dbs -f $DOCKER_LOCALDIR/docker-compose-$HOSTNAME.yml stop'
  alias createdbs='sudo docker compose --profile dbs -f $DOCKER_LOCALDIR/docker-compose-$HOSTNAME.yml up -d --build --remove-orphans'
  alias startdbs='sudo docker compose --profile dbs -f $DOCKER_LOCALDIR/docker-compose-$HOSTNAME.yml start'

else
  # No DOCKER_LOCALFILE - docker files all run according to folder
  alias docker-compose='docker compose'
  alias dc='docker compose'
  alias dcup='docker compose up -d'
  alias distartpolicy='docker inspect --format '{{.HostConfig.RestartPolicy.Name}}'' #name#
  alias dstart='docker start' #name#
  alias dsetrestart='docker update --restart unless-stopped' #name#  
fi

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
