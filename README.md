# divtools
**Divix Linux Config Tools**

To Execute/Install:<br>
`bash <(wget -qO- https://raw.githubusercontent.com/adf1969/divtools/main/divtools_install.sh)`

To Download the `divtools_install.sh` file:<br>
`wget https://raw.githubusercontent.com/adf1969/divtools/main/divtools_install.sh -O divtools_install.sh`

To Install Starship manually:
 $ sudo curl -sS https://starship.rs/install.sh | sh

The structure for the divtools files are as follows:
- **\\**: Root files
  - **divtools_install.sh**: Install Bash script that installs all the divtools and configures a system for use.

- **.ssh**: contains the **PUBLIC** `authorized_keys` to be installed on all servers for SSH access.
  - **authorized_keys**: file to be installed in `~/.ssh` folders for access.

- **config**: Contains various configs used for standalone installs
  - **unbound**: contains unbound configuration files

- **scripts**: Contains common scripts for use on all systems.

- **docker**: contains docker compose files for the local docker instance
  - **appdata**
  - **archive**
  - **include**: folder contains docker-compose yml files for including in main docker-compose-<HOSTNAME>.yml file
    These docker-compose files are NOT site-specific, they are HOSTNAME specific.
    For site-specific, store those as indicated below in the SITE_NAME folder
    - **<HOSTNAME>**: folder contains <HOSTNAME> folders which each contain host-specific yml files
      - **<app>**: folder contains host specific full docker-compose yml files. 
        These docker-compose files are NOT called by the main docker-compose-<HOSTNAME>.yml file.
        These must be run by being in this dir and running docker compose, or by calling an alias defined to do that.
    - **shared**: folder contains common shared docker-compose yml files.
  - **local**: folder contains files used for local docker use.
  - **secrets**: folder contains secret files.
  - **secrets_example**: folder that contains examples of secrets files.
  - **sites**: folder that contains site-specific config
    - **<SITE_NAME>**: folder contains SITE specific data/config for one site
      - **<HOSTNAME>: folder contains HOST specific data/config for one site:host
        - **<APP>: folder contains APP specific data/config for a site:host:app
          Example: s01-7692nh/tnapp01/postgres: contains postgres app data, on the server named "tnapp01" at the siate named "s01-7692nh".
          This folder could contain:
          - postgres-compose.yml: the postgres YML Docker-Compose file
          - .\config: this would be configuration data for the specific app, sometimes this folder may be named differently, to fit with the standard naming conventions of the app.
  - **docker-compose-<HOSTNAME>.yml**: This is the local docker file, run by the alias dcrun.

- **dotfiles**: contains various login/.* files used for configuring shells:
  - **.bash_aliases**
  - **.bash_profile**
  - **.bashrc**: This is a QNAP `.bashrc`. Currently, it is **NOT** used since it is in the `$skipfiles`.

- **qnap_cfg**: Contains QNAP/QTS specific scripts/files to handle QNAP configuration.
  - **dotfiles**: files that could be used by QNAP. These are defaults for QNAP.
  - **etc**: files used for boot and configuration of the QNAP system.
  - **scripts**: scripts for managing QNAP.

