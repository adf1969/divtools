#!/bin/bash

NEW_OPT_LOC="/share/CACHEDEV1_DATA/opt"   # Set to location where you want /opt to be
DIVTOOLS="/opt/divtools"                  # Default DIVTOOLS path
DOCKERDATADIR="/opt"                      # Default DOCKERDATADIR path
DT_LOCAL_BIN_DIR="/usr/local/bin"         # Default binary installation directory

# Check if the script is run as root or a non-root user
function run_cmd() {
    if [[ $EUID -ne 0 ]]; then
        sudo $@
    else
        $@
    fi
}

# Set whiptail colors for better contrast and selection highlighting
# Last Updated: 9/7/2025 6:58:45 PM CDT
function set_whiptail_colors() {
    # Set whiptail color environment variables for a high-contrast theme with clear selection
    export NEWT_COLORS='
        root=,black
        window=,black
        border=white,black
        textbox=white,black
        button=black,white
        actbutton=black,yellow
        compactbutton=black,white
        title=cyan,black
        label=cyan,black
        entry=white,black
        checkbox=cyan,black
        actcheckbox=black,cyan
        listbox=white,black
        actlistbox=black,cyan
        sellistbox=black,cyan
        actsellistbox=black,yellow
    '
    echo "Applied custom whiptail color scheme with enhanced button highlighting."
} # set_whiptail_colors()


# Check if running on TrueNAS
function is_truenas() {
    if [ -f /etc/truenas_version ] || grep -q "TrueNAS" /etc/os-release; then
        echo "Detected TrueNAS system."
        return 0
    else
        return 1
    fi
}

# Check if /usr/local/bin is read-only
function is_readonly_usr_local_bin() {
    echo "Check /usr/local/bin is read-only."
    # Attempt to create a temporary file
    if ! sudo touch /usr/local/bin/.test_write 2>/dev/null; then
        echo "/usr/local/bin is read-only."
        return 0
    else
        sudo rm -f /usr/local/bin/.test_write
        return 1
    fi
}

# Initialize environment variables for sourced usage
function init_env_vars() {
    # Check if ~/.env exists for the current user
    local home_dir=$(getent passwd "$(whoami)" | cut -d: -f6)
    if [ -f "$home_dir/.env" ]; then
        source "$home_dir/.env"
        echo "Sourced environment variables from $home_dir/.env"
    fi

    # Source general .env file for InfluxDB settings
    local env_file="$DIVTOOLS/docker/.env"
    if [ -f "$env_file" ]; then
        source "$env_file"
        echo "Sourced InfluxDB settings from $env_file"
        if [ -z "$INFLUXDB_IP" ] || [ -z "$INFLUXDB_PORT" ] || [ -z "$INFLUXDB_API_TOKEN" ] || [ -z "$INFLUXDB_ORG" ] || [ -z "$INFLUXDB_BUCKET" ]; then
            echo_red "Missing required InfluxDB settings in $env_file. Falling back to defaults."
            export INFLUXDB_IP="<influxdb-ip>"
            export INFLUXDB_PORT="8086"
            export INFLUXDB_API_TOKEN="<your-influxdb-token>"
            export INFLUXDB_ORG="your-org"
            export INFLUXDB_BUCKET="proxmox"
        fi
    else
        echo_red "InfluxDB .env file not found at $env_file. Using defaults."
        export INFLUXDB_IP="<influxdb-ip>"
        export INFLUXDB_PORT="8086"
        export INFLUXDB_API_TOKEN="<your-influxdb-token>"
        export INFLUXDB_ORG="your-org"
        export INFLUXDB_BUCKET="proxmox"
    fi
    # Source host-specific .env.host file
    if [ -z "$DIVTOOLS" ]; then
        if is_truenas || is_readonly_usr_local_bin; then
            export DIVTOOLS="/mnt/tpool/NFS/opt/divtools"
        else
            export DIVTOOLS="/opt/divtools"
        fi
    fi

    local env_host_file="$DIVTOOLS/docker/.env.host"
    if [ -f "$env_host_file" ]; then
        source "$env_host_file"
        echo "Sourced host-specific settings from $env_host_file"
    else
        echo "Host-specific .env.host file not found at $env_host_file. Using hostname command for HOSTNAME."
        export HOSTNAME=$(hostname)
    fi    

    # Set default environment variables if not already set
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
        echo "Set default environment variables: DIVTOOLS=$DIVTOOLS, DOCKERDATADIR=$DOCKERDATADIR, DT_LOCAL_BIN_DIR=$DT_LOCAL_BIN_DIR"
    fi

    # Ensure PATH includes DT_LOCAL_BIN_DIR
    if [[ ! ":$PATH:" =~ ":$DT_LOCAL_BIN_DIR:" ]]; then
        export PATH="$DT_LOCAL_BIN_DIR:$PATH"
    fi
}

# Prompt for environment variables using whiptail only if not already set
# Last Updated: 9/7/2025 6:49:45 PM CDT
function prompt_env_vars() {  
    # Set suggested paths for TrueNAS
    if is_truenas || is_readonly_usr_local_bin; then
        SUGGESTED_DIVTOOLS="/mnt/tpool/NFS/opt/divtools"
        SUGGESTED_DOCKERDATADIR="/mnt/tpool/NFS/opt"
        SUGGESTED_DT_LOCAL_BIN_DIR="/mnt/tpool/NFS/opt/bin"
    else
        SUGGESTED_DIVTOOLS="/opt/divtools"
        SUGGESTED_DOCKERDATADIR="/opt"
        SUGGESTED_DT_LOCAL_BIN_DIR="/usr/local/bin"
    fi

    # Prompt for DIVTOOLS
    DIVTOOLS=$(whiptail --title "Set DIVTOOLS Path" --inputbox \
        "Enter the path for DIVTOOLS (default: $SUGGESTED_DIVTOOLS):" 10 60 \
        "$SUGGESTED_DIVTOOLS" 3>&1 1>&2 2>&3)
    if [[ -z "$DIVTOOLS" ]]; then
        DIVTOOLS="$SUGGESTED_DIVTOOLS"
    fi

    # Prompt for DOCKERDATADIR
    DOCKERDATADIR=$(whiptail --title "Set DOCKERDATADIR Path" --inputbox \
        "Enter the path for DOCKERDATADIR (default: $SUGGESTED_DOCKERDATADIR):" 10 60 \
        "$SUGGESTED_DOCKERDATADIR" 3>&1 1>&2 2>&3)
    if [[ -z "$DOCKERDATADIR" ]]; then
        DOCKERDATADIR="$SUGGESTED_DOCKERDATADIR"
    fi

    # Prompt for DT_LOCAL_BIN_DIR
    DT_LOCAL_BIN_DIR=$(whiptail --title "Set DT_LOCAL_BIN_DIR Path" --inputbox \
        "Enter the path for local binaries (default: $SUGGESTED_DT_LOCAL_BIN_DIR):" 10 60 \
        "$SUGGESTED_DT_LOCAL_BIN_DIR" 3>&1 1>&2 2>&3)
    if [[ -z "$DT_LOCAL_BIN_DIR" ]]; then
        DT_LOCAL_BIN_DIR="$SUGGESTED_DT_LOCAL_BIN_DIR"
    fi
}

# Write environment variables to .env files
function write_env_files() {
    local users=("root" "divix" "syncthing")
    for user in "${users[@]}"; do
        if id "$user" &>/dev/null; then
            local home_dir=$(getent passwd "$user" | cut -d: -f6)
            if [[ -z "$home_dir" ]]; then
                echo_red "Skipping user $user: No home directory found."
                continue
            fi
            echo "Writing .env file for user $user at $home_dir/.env"
            if ! run_cmd mkdir -p "$home_dir"; then
                echo_red "Failed to create directory $home_dir for user $user."
                continue
            fi
            if ! echo "# Local Env Overrides
export DIVTOOLS=\"$DIVTOOLS\"
export DOCKERDIR=\"\$DIVTOOLS/docker\"
export DOCKERDATADIR=\"$DOCKERDATADIR\"
export DT_LOCAL_BIN_DIR=\"$DT_LOCAL_BIN_DIR\"
export PATH=\"\$DT_LOCAL_BIN_DIR:\$PATH\"" | run_cmd tee "$home_dir/.env" > /dev/null; then
                echo_red "Failed to write $home_dir/.env for user $user."
                continue
            fi
            run_cmd chown "$user:$user" "$home_dir/.env"
            run_cmd chmod 600 "$home_dir/.env"
            echo_green "Successfully wrote $home_dir/.env for user $user."
        else
            echo "Skipping user $user: User does not exist."
        fi
    done
}


# Detect OS and set package manager
function detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
            PKG_MANAGER="apt"
        elif [[ "$OS" == "qts" ]]; then
            PKG_MANAGER="opkg" # Entware package manager on QNAP (QTS)
            qnap_pre_install  # Call pre-install check for QNAP systems
        else
            echo "Unsupported OS"
            exit 1
        fi
    else
        echo "Unable to detect OS"
        exit 1
    fi
}

# Function to check if a package is installed
function is_installed() {
    command -v $1 >/dev/null 2>&1
}

# QNAP pre-install check for Entware and whiptail
function qnap_pre_install() {
    echo "This is a QNAP/QTS system."
    
    # Check if whiptail is installed
    if is_installed whiptail; then
        echo "Whiptail is already installed."
        return
    fi

    # Check if Entware is installed (check if opkg is present)
    if ! is_installed opkg; then
        # Entware and whiptail are not installed
        echo "Entware and whiptail are required and need to be installed."
        read -p "Do you want to install them now? (y/n): " install_entware
        if [[ "$install_entware" == "y" || "$install_entware" == "Y" ]]; then
            # Install Entware
            echo "Installing Entware..."
            run_cmd /etc/init.d/optware.sh start
            run_cmd wget -O - http://bin.entware.net/x64-k3.2/installer/generic.sh | run_cmd sh
            run_cmd opkg update
        else
            echo "Entware installation declined. Exiting..."
            exit 1
        fi
    else
        # Only whiptail is missing
        echo "Whiptail is required and needs to be installed."
        read -p "Do you want to install whiptail now? (y/n): " install_whiptail
        if [[ "$install_whiptail" == "y" || "$install_whiptail" == "Y" ]]; then
            run_cmd opkg update
            run_cmd opkg install whiptail
        else
            echo "Whiptail installation declined. Exiting..."
            exit 1
        fi
    fi

    # Final check: Ensure whiptail is now installed
    if ! is_installed whiptail; then
        echo "Failed to install whiptail. Exiting..."
        exit 1
    fi
}

# Function to add a user, assign them to specified groups, and optionally set a specific UID
# Parameters:
# $1 - username
# $2 - space-delimited list of groups
# $3 - optional UID for the user
function add_user() {
    local username=$1
    local groups=$2
    local uid=$3

    # Check if the user already exists
    if id "$username" &>/dev/null; then
        echo "User $username already exists"
    else
        # Prompt for password input
        read -sp "Enter password for $username user: " user_passwd
        echo ""

        # Construct the useradd command with optional UID
        if [[ -n "$uid" ]]; then
            echo "Creating user $username with UID $uid..."
            run_cmd useradd -m -s /bin/bash -u "$uid" "$username"
        else
            echo "Creating user $username with default UID..."
            run_cmd useradd -m -s /bin/bash "$username"
        fi

        # Set the password for the user
        echo "Setting password for $username user..."
        echo -e "$user_passwd\n$user_passwd" | run_cmd passwd "$username"
    fi

    # Loop through each group and add the user to the group
    for group in $groups; do
        # Check if the group exists, if not, create it
        if ! getent group "$group" &>/dev/null; then
            echo "Group $group does not exist. Creating it..."
            if [[ "$OS" == "qts" ]]; then
                run_cmd addgroup "$group"
            else
                run_cmd groupadd "$group"
            fi
        fi

        # Add the user to the group
        run_cmd usermod -aG "$group" "$username"
        echo "User $username added to group $group"
    done
} # add_user


# Refactored add_divix_user using add_user
function add_divix_user() {
    local username="divix"
    local uid="1400"

    # Add divix user and assign to groups based on the OS
    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        add_user "$username" "sudo adm" "$uid"
    elif [[ "$OS" == "qts" ]]; then
        add_user "$username" "administrators adm" "$uid"
    else
        add_user "$username" "adm" "$uid"
    fi
} # add_divix_user





# Create divtools folder and set permissions
function create_divtools_folder() {
    # Create $DIVTOOLS if it doesn't exist
    if [ ! -d "$DIVTOOLS" ]; then
        run_cmd mkdir -p "$DIVTOOLS"
    fi

    # Set the ownership of $DIVTOOLS to the "adm" group
    run_cmd chown :adm "$DIVTOOLS"

    # Set the permissions of $DIVTOOLS to 775
    run_cmd chmod 775 "$DIVTOOLS"

    # Create a symbolic link in the divix home directory to $DIVTOOLS
    if [ -d /home/divix ]; then
        if [ ! -L /home/divix/divtools ]; then
            run_cmd ln -s "$DIVTOOLS" /home/divix/divtools
        fi
    fi
}


# Install Entware (if not already installed)
function install_entware() {
    if [[ "$OS" == "qts" ]]; then
        if ! is_installed opkg; then
            echo "Installing Entware on QNAP"
            run_cmd /etc/init.d/optware.sh start
            run_cmd wget -O - http://bin.entware.net/x64-k3.2/installer/generic.sh | run_cmd sh
        else
            echo "Entware already installed."
        fi
    fi
}

# Function to output in red text
function echo_red() {
    echo -e "\033[0;31m$1\033[0m"
}

# Function to output in green text
function echo_green() {
    echo -e "\033[0;32m$1\033[0m"
}


# Install Telegraf for SMART monitoring
function install_telegraf() {
    local rebuild_config="no"

    # Initialize environment variables
    init_env_vars

    # Check if lsb_release is installed, install if missing
    if ! command -v lsb_release >/dev/null 2>&1; then
        echo "lsb_release not found. Installing lsb-release package..."
        if ! run_cmd apt update 2>&1 | tee /tmp/lsb_release_install.log; then
            echo_red "Failed to run apt update for lsb-release. Check /tmp/lsb_release_install.log for details."
        fi
        if ! run_cmd apt install -y lsb-release 2>&1 | tee -a /tmp/lsb_release_install.log; then
            echo_red "lsb-release installation failed. Falling back to /etc/os-release for codename."
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                CODENAME=$VERSION_CODENAME
                if [ -z "$CODENAME" ]; then
                    echo_red "Could not determine Debian codename from /etc/os-release. Using 'bookworm' as default."
                    CODENAME="bookworm"
                fi
            else
                echo_red "No /etc/os-release found. Using 'bookworm' as default."
                CODENAME="bookworm"
            fi
        else
            CODENAME=$(lsb_release -cs)
        fi
    else
        CODENAME=$(lsb_release -cs)
    fi

    # Check if lsscsi is installed, install with retry logic
    if ! command -v lsscsi >/dev/null 2>&1; then
        echo "lsscsi not found. Installing lsscsi package..."
        if ! run_cmd apt update 2>&1 | tee /tmp/lsscsi_install.log; then
            echo_red "Failed to run apt update for lsscsi. Check /tmp/lsscsi_install.log for details."
        fi
        for attempt in {1..3}; do
            if run_cmd apt install -y lsscsi 2>&1 | tee -a /tmp/lsscsi_install.log; then
                if command -v lsscsi >/dev/null 2>&1; then
                    echo_green "lsscsi installed successfully."
                    break
                fi
            fi
            echo_red "Attempt $attempt: Failed to install lsscsi."
            if [ $attempt -lt 3 ]; then
                echo "Retrying in 5 seconds..."
                sleep 5
                run_cmd apt update 2>&1 | tee -a /tmp/lsscsi_install.log
            else
                echo_red "Failed to install lsscsi after 3 attempts. Falling back to lsblk for drive detection."
            fi
        done
    else
        echo "lsscsi is already installed."
    fi

    # Check if nvme-cli is installed if NVMe drives are present
    if lsblk -d -n -o NAME | grep -q '^nvme[0-9]n[0-9]$'; then
        if ! command -v nvme >/dev/null 2>&1; then
            echo "nvme-cli not found and NVMe drives detected. Installing nvme-cli package..."
            if ! run_cmd apt update 2>&1 | tee /tmp/nvme_cli_install.log; then
                echo_red "Failed to run apt update for nvme-cli. Check /tmp/nvme_cli_install.log for details."
            fi
            if ! run_cmd apt install -y nvme-cli 2>&1 | tee -a /tmp/nvme_cli_install.log; then
                echo_red "Failed to install nvme-cli. NVMe-specific attributes will not be collected."
            else
                echo_green "nvme-cli installed successfully."
            fi
        else
            echo "nvme-cli is already installed."
        fi
    fi

    if ! is_installed telegraf; then
        echo_green "Installing Telegraf..."

        # Clean up any existing malformed InfluxData repository file
        if [ -f /etc/apt/sources.list.d/influxdata.list ]; then
            echo "Removing existing /etc/apt/sources.list.d/influxdata.list to prevent errors..."
            run_cmd rm -f /etc/apt/sources.list.d/influxdata.list
        fi

        # Add InfluxData repository and import GPG key
        if ! run_cmd wget -q -O /tmp/influxdata-archive_compat.key https://repos.influxdata.com/influxdata-archive_compat.key 2>&1 | tee /tmp/influxdata_key.log; then
            echo_red "Failed to download InfluxData GPG key. Check /tmp/influxdata_key.log for details."
        fi
        run_cmd gpg --dearmor -o /etc/apt/trusted.gpg.d/influxdata-archive_compat.gpg /tmp/influxdata-archive_compat.key
        echo "deb [signed-by=/etc/apt/trusted.gpg.d/influxdata-archive_compat.gpg] https://repos.influxdata.com/debian $CODENAME stable" | run_cmd tee /etc/apt/sources.list.d/influxdata.list
        if ! run_cmd apt update 2>&1 | tee /tmp/influxdata_update.log; then
            echo_red "Failed to run apt update for InfluxData repository. Check /tmp/influxdata_update.log for details."
        fi

        # Install Telegraf
        if ! run_cmd apt install -y telegraf 2>&1 | tee /tmp/telegraf_install.log; then
            echo_red "Failed to install Telegraf. Check /tmp/telegraf_install.log for details."
            return 1
        fi
    else
        echo "Telegraf is already installed."
        # Prompt user to rebuild the config file
        if whiptail --title "Rebuild Telegraf Config" --yesno \
            "Telegraf is already installed. Would you like to rebuild the configuration file at $DIVTOOLS/config/telegraf/telegraf-$HOSTNAME.conf?" 10 60; then
            rebuild_config="yes"
        else
            echo "Skipping config rebuild."
            return 0
        fi
    fi

    # Create config directory in $DIVTOOLS
    run_cmd mkdir -p "$DIVTOOLS/config/telegraf"
    run_cmd chown :adm "$DIVTOOLS/config/telegraf"
    run_cmd chmod 775 "$DIVTOOLS/config/telegraf"

    # Generate or update Telegraf config if not exists or user chose to rebuild
    local config_file="$DIVTOOLS/config/telegraf/telegraf-$HOSTNAME.conf"
    if [ ! -f "$config_file" ] || [ "$rebuild_config" = "yes" ]; then
        echo_green "Creating new Telegraf config at $config_file..."

        # Dynamically detect drives for SMART monitoring
        local drives=()
        local root_device=$(findmnt -n -o SOURCE / | grep -o '/dev/sd[a-z]')
        if command -v lsscsi >/dev/null 2>&1; then
            while IFS= read -r line; do
                device=$(echo "$line" | awk '{print $NF}')
                # Include SATA and NVMe drives, exclude the root device
                if [[ "$device" != "$root_device" && "$device" =~ ^/dev/(sd[a-z]+|nvme[0-9]n[0-9])$ ]]; then
                    drives+=("$device")
                fi
            done < <(lsscsi | grep -E 'disk')
        else
            echo_red "lsscsi not available. Falling back to lsblk for drive detection."
            if command -v lsblk >/dev/null 2>&1; then
                while IFS= read -r line; do
                    device="/dev/$(echo "$line" | awk '{print $1}')"
                    # Include SATA and NVMe drives, exclude the root device
                    if [[ "$device" != "$root_device" && "$device" =~ ^/dev/(sd[a-z]+|nvme[0-9]n[0-9])$ ]]; then
                        drives+=("$device")
                    fi
                done < <(lsblk -d -n -o NAME | grep -E '^(sd[a-z]+|nvme[0-9]n[0-9])$')
            else
                echo_red "lsblk not available either. No drives will be monitored. Please install lsscsi or lsblk, or manually specify devices in $config_file."
            fi
        fi

        # Convert drives array to comma-separated string for Telegraf config
        drives_str=$(printf '"%s", ' "${drives[@]}" | sed 's/, $//')

        # Create Telegraf config with comments
        cat << EOF > "$config_file"
# Telegraf configuration for SMART monitoring on Proxmox host $HOSTNAME
# Edit this file in $DIVTOOLS/config/telegraf/ to manage via Git and VSCode
# After editing, restart Telegraf: sudo systemctl restart telegraf
# InfluxDB settings are sourced from $DIVTOOLS/docker/.env
# Drives are dynamically detected using lsscsi or lsblk, excluding the root device

[global_tags]
  # Host identifier for InfluxDB and Grafana
  host = "$HOSTNAME"
  role = "proxmox"

[[outputs.influxdb_v2]]
  # InfluxDB v2 output configuration
  urls = ["http://$INFLUXDB_IP:$INFLUXDB_PORT"]
  token = "$INFLUXDB_API_TOKEN"
  organization = "$INFLUXDB_ORG"
  bucket = "$INFLUXDB_BUCKET"

[[inputs.smart]]
  # Path to smartctl binary
  path_smartctl = "/usr/sbin/smartctl"
  # Drives to monitor (detected dynamically, excluding the root device)
  devices = [$drives_str]
  # Enable collection of all SMART attributes (e.g., Reallocated_Sector_Ct, Temperature_Celsius)
  attributes = true
  # Collection interval (5 minutes recommended to balance granularity and I/O load)
  interval = "5m"
  # Use sudo for smartctl (requires sudoers configuration)
  use_sudo = true
EOF

        run_cmd chown :adm "$config_file"
        run_cmd chmod 664 "$config_file"
        echo_green "Telegraf config created at $config_file"
    else
        echo "Telegraf config already exists at $config_file, skipping creation."
    fi

    # Create softlink to /etc/telegraf/telegraf.conf
    if [ ! -L /etc/telegraf/telegraf.conf ]; then
        run_cmd ln -sf "$config_file" /etc/telegraf/telegraf.conf
        echo_green "Created softlink /etc/telegraf/telegraf.conf -> $config_file"
    else
        echo "Softlink /etc/telegraf/telegraf.conf already exists."
    fi

    # Configure sudoers for Telegraf
    if [ ! -f /etc/sudoers.d/telegraf ]; then
        echo "telegraf ALL=(ALL) NOPASSWD: /usr/sbin/smartctl" | run_cmd tee /etc/sudoers.d/telegraf
        run_cmd chmod 0440 /etc/sudoers.d/telegraf
        echo_green "Configured sudoers for Telegraf"
    else
        echo "Sudoers configuration for Telegraf already exists."
    fi

    # Start and enable Telegraf
    run_cmd systemctl restart telegraf
    run_cmd systemctl enable telegraf
    echo_green "Telegraf service started and enabled."
} # install_telegraf



# Install necessary packages for Proxmox
function install_packages_proxmox() {
    packages=(sudo git syncthing)

    if [[ "$PKG_MANAGER" == "apt" ]]; then
        # Add syncthing repository if syncthing is not already installed
        if ! is_installed syncthing; then
            run_cmd curl -s https://syncthing.net/release-key.txt | run_cmd gpg --dearmor -o /usr/share/keyrings/syncthing-archive-keyring.gpg
            echo "deb [signed-by=/usr/share/keyrings/syncthing-archive-keyring.gpg] https://apt.syncthing.net/ syncthing stable" | run_cmd tee /etc/apt/sources.list.d/syncthing.list
            run_cmd apt update
        fi

        # Install each package one by one
        for package in "${packages[@]}"; do
            if ! is_installed "$package"; then
                echo_green "Installing $package..."
                if ! run_cmd apt install -y "$package"; then
                    echo_red "Failed to install $package. Continuing with the next package..."
                fi
            else
                echo "Package $package is already installed."
            fi
        done

        # Install Telegraf
        install_telegraf

    elif [[ "$PKG_MANAGER" == "opkg" ]]; then
        # Install each package one by one using opkg
        for package in "${packages[@]}"; do
            if ! is_installed "$package"; then
                echo_green "Installing $package..."
                if ! run_cmd opkg install "$package"; then
                    echo_red "Failed to install $package. Continuing with the next package..."
                fi
            else
                echo "Package $package is already installed."
            fi
        done
    fi
}


# Install necessary packages
function install_packages() {
    packages=(curl sudo whois xmlstarlet git git-http vim-nox rclone python3 libssl-dev ca-certificates openssh-client tmux net-tools ccze)

    if [[ "$PKG_MANAGER" == "apt" ]]; then
        # Install each package one by one
        for package in "${packages[@]}"; do
            echo_green "Installing $package..."
            if ! run_cmd apt install -y "$package"; then
                echo_red "Failed to install $package. Continuing with the next package..."
            fi
        done

    elif [[ "$PKG_MANAGER" == "opkg" ]]; then
        # Install each package one by one using opkg
        for package in "${packages[@]}"; do
            echo_green "Installing $package..."
            if ! run_cmd opkg install "$package"; then
                echo_red "Failed to install $package. Continuing with the next package..."
            fi
        done
    fi
}


# Install Syncthing
# Installs Syncthing on the system.
# Last Updated: 9/7/2025 1:37:45 PM CDT
function install_syncthing() {
    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        echo "Installing Syncthing on $OS"
        # Add Syncthing repository temporarily using modern signed-by method
        run_cmd sh -c "curl -s -o /usr/share/keyrings/syncthing-archive-keyring.gpg https://syncthing.net/release-key.gpg"
        run_cmd sh -c "echo \"deb [signed-by=/usr/share/keyrings/syncthing-archive-keyring.gpg] https://apt.syncthing.net/ syncthing stable\" > /etc/apt/sources.list.d/syncthing.list"
        run_cmd apt update
        run_cmd apt install -y syncthing
        # Remove the repository and key after installation to avoid future apt update errors
        run_cmd rm /etc/apt/sources.list.d/syncthing.list
        run_cmd rm /usr/share/keyrings/syncthing-archive-keyring.gpg
        run_cmd apt update  # Refresh package lists to clear any residual warnings
    elif [[ "$OS" == "qts" ]]; then
        echo "Installing Syncthing on QNAP"
        run_cmd opkg update
        run_cmd opkg install syncthing
    fi
}


# Function to install Docker
function install_docker() {
    # Comma-delimited list of users to add to the docker group
    local users_to_add="divix"

    # Check if Docker is already installed
    if command -v docker &> /dev/null; then
        echo_green "Docker is already installed."
        return
    fi

    echo "Installing Docker..."

    if [[ "$OS" == "debian" || "$OS" == "ubuntu" ]]; then
        # Clean APT cache to ensure fresh metadata
        echo "Cleaning APT cache..."
        run_cmd rm -rf /var/lib/apt/lists/*
        run_cmd apt update

        # Install prerequisites
        run_cmd apt install -y apt-transport-https ca-certificates curl gnupg

        # Remove any existing Docker repository file to prevent conflicts
        if [ -f /etc/apt/sources.list.d/docker.list ]; then
            echo "Removing existing Docker repository file to ensure correct configuration..."
            run_cmd rm /etc/apt/sources.list.d/docker.list
        fi

        # Add Docker’s official GPG key
        if ! run_cmd curl -fsSL https://download.docker.com/linux/$OS/gpg | run_cmd gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg; then
            echo_red "Failed to fetch Docker GPG key. Check network connectivity."
            return 1
        fi
        echo "Added Docker GPG key for $OS"

        # Add Docker repository based on OS
        local repo_url
        local codename
        local repo_file="/etc/apt/sources.list.d/docker.list"
        if [[ "$OS" == "debian" ]]; then
            repo_url="https://download.docker.com/linux/debian"
            codename=$(. /etc/os-release && echo $VERSION_CODENAME)
            echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] $repo_url $codename stable" | run_cmd tee $repo_file
            echo "Using Docker repository: $repo_url $codename stable"
        elif [[ "$OS" == "ubuntu" ]]; then
            repo_url="https://download.docker.com/linux/ubuntu"
            codename=$(lsb_release -cs)
            echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] $repo_url $codename stable" | run_cmd tee $repo_file
            echo "Using Docker repository: $repo_url $codename stable"
        fi

        # Set permissions for docker.list
        run_cmd chmod 644 $repo_file
        echo "Set permissions for $repo_file"

        # Verify repository file
        if [ ! -f $repo_file ]; then
            echo_red "Failed to create $repo_file. Check permissions or disk space."
            return 1
        fi
        echo "Contents of $repo_file:"
        cat $repo_file

        # Verify repository connectivity (non-fatal)
        local curl_url
        if [[ "$OS" == "debian" ]]; then
            curl_url="https://download.docker.com/linux/debian/dists/bookworm/stable/binary-amd64/Packages.gz"
        elif [[ "$OS" == "ubuntu" ]]; then
            curl_url="https://download.docker.com/linux/ubuntu/dists/$codename/stable/binary-amd64/Packages.gz"
        fi
        echo "Checking connectivity to $curl_url..."
        http_code=$(curl -I -s -o /dev/null -w "%{http_code}" "$curl_url" 2>&1)
        if [ "$http_code" -eq 200 ]; then
            echo "Successfully verified connectivity to $curl_url (HTTP $http_code)"
        else
            echo_red "Warning: Cannot reach Docker repository at $curl_url. HTTP code: $http_code"
            echo_red "Proceeding with apt update..."
        fi

        # Update package list with retry
        local max_attempts=3
        local attempt=1
        while [ $attempt -le $max_attempts ]; do
            if run_cmd apt update; then
                break
            else
                echo_red "apt update failed (attempt $attempt/$max_attempts). Retrying..."
                ((attempt++))
                sleep 5
            fi
        done
        if [ $attempt -gt $max_attempts ]; then
            echo_red "Failed to update package list after $max_attempts attempts. Check repository or network."
            return 1
        fi

        # Check available Docker versions
        echo "Checking available Docker versions..."
        run_cmd apt-cache madison docker-ce

        # Install Docker with version pinning
        local docker_version="5:24.0.5-1~${OS}.12~${codename}"
        if ! run_cmd apt install -y docker-ce=$docker_version docker-ce-cli=$docker_version containerd.io docker-buildx-plugin docker-compose-plugin; then
            echo_red "Failed to install Docker with version $docker_version. Trying without version pinning..."
            if ! run_cmd apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; then
                echo_red "Failed to install Docker. Check repository or network. Run 'apt-cache search docker-ce' for available packages."
                return 1
            fi
        fi

        # Enable Docker to start on boot and start the service
        run_cmd systemctl enable docker
        run_cmd systemctl start docker

        echo_green "Docker installed successfully."

        # Iterate over the comma-delimited list of users
        IFS=',' read -ra users <<< "$users_to_add"
        for user in "${users[@]}"; do
            # Check if the user exists and add them to the docker group
            if id "$user" &>/dev/null; then
                echo "User $user exists. Adding to docker group..."
                run_cmd usermod -aG docker "$user"
                echo_green "User $user added to docker group."
            else
                echo_red "User $user does not exist. Skipping docker group addition for $user."
            fi
        done
    elif [[ "$OS" == "qts" ]]; then
        echo_red "QNAP detected. Docker installation on QNAP must be done via App Center."
        return 1
    else
        echo_red "Unsupported OS for Docker installation."
        return 1
    fi
} # install_docker


# Function to install Cockpit and additional modules
function install_cockpit() {
    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        # Check if Cockpit is already installed
        if command -v cockpit &> /dev/null; then
            echo "Cockpit is already installed. Installing additional modules..."
            
            # Install Cockpit modules using --no-install-recommends
            run_cmd apt install -y --no-install-recommends cockpit-identities cockpit-file-sharing cockpit-navigator
            echo "Cockpit modules installed successfully."

        else
            # Install Cockpit using --no-install-recommends
            echo "Installing Cockpit..."
            run_cmd apt update
            run_cmd apt install -y --no-install-recommends cockpit

            # Enable and start the Cockpit service
            run_cmd systemctl enable cockpit
            run_cmd systemctl start cockpit

            # Install additional modules
            run_cmd apt install -y --no-install-recommends cockpit-identities cockpit-file-sharing cockpit-navigator

            echo "Cockpit and additional modules installed successfully."
        fi
    else
        echo "Cockpit installation is only supported on Ubuntu or Debian systems."
    fi
}

# Install eza
function install_eza() {
    echo "Installing eza..."

    if [[ "$OS" == "debian" || "$OS" == "ubuntu" ]]; then
        echo "Detected Debian-based system. Installing eza via APT..."
        run_cmd apt update
        run_cmd apt install -y gpg
        run_cmd mkdir -p /etc/apt/keyrings
        run_cmd wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | run_cmd gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
        echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | run_cmd tee /etc/apt/sources.list.d/gierens.list
        run_cmd chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
        run_cmd apt update
        run_cmd apt install -y eza
        # Move eza to DT_LOCAL_BIN_DIR if different from /usr/local/bin
        if [[ "$DT_LOCAL_BIN_DIR" != "/usr/local/bin" ]]; then
            run_cmd mv /usr/local/bin/eza "$DT_LOCAL_BIN_DIR/eza"
        fi
    elif [[ "$OS" == "qts" ]]; then
        echo "Detected QNAP QTS system. Installing eza via Entware..."
        run_cmd opkg install eza
        if [ ! -f "$DT_LOCAL_BIN_DIR/eza" ]; then
            run_cmd ln -s /opt/usr/bin/eza "$DT_LOCAL_BIN_DIR/eza"
        fi
    else
        echo "Unsupported operating system for eza installation."
        return 1
    fi

    echo "eza installation completed successfully."
} # install_eza


# Install NVIDIA Drivers (kernel drivers for the GPU)
# Last Updated: 9/7/2025 1:44:45 PM CDT
function install_nvidia_drivers() {
    echo "Installing NVIDIA drivers..."

    if [[ "$OS" == "debian" || "$OS" == "ubuntu" ]]; then
        # Install kernel headers and build tools
        echo "Installing kernel headers and build tools..."
        local kernel_version=$(uname -r)
        run_cmd apt install -y proxmox-headers-$kernel_version dkms gcc make

        # Check if NVIDIA drivers are already installed
        if command -v nvidia-smi &>/dev/null && lsmod | grep -q nvidia; then
            echo_green "NVIDIA drivers are already installed and loaded: $(nvidia-smi --query-gpu=name --format=csv)"
            read -p "Do you want to reinstall NVIDIA drivers (includes updating kernel headers)? (y/n): " reinstall_choice
            if [[ "$reinstall_choice" != "y" && "$reinstall_choice" != "Y" ]]; then
                echo "Skipping NVIDIA driver reinstallation."
                return 0
            else
                read -p "Do you want to purge existing NVIDIA packages before reinstalling? (y/n): " purge_choice
                if [[ "$purge_choice" == "y" || "$purge_choice" == "Y" ]]; then
                    echo "Purging existing NVIDIA packages..."
                    run_cmd apt purge -y nvidia-driver nvidia-settings nvidia-kernel* nvidia-modprobe libnvidia* || true
                    run_cmd apt autoremove -y
                else
                    echo "Skipping purge of existing NVIDIA packages."
                fi
            fi
        else
            read -p "Do you want to purge existing NVIDIA packages before installing? (y/n): " purge_choice
            if [[ "$purge_choice" == "y" || "$purge_choice" == "Y" ]]; then
                echo "Purging existing NVIDIA packages..."
                run_cmd apt purge -y nvidia-driver nvidia-settings nvidia-kernel* nvidia-modprobe libnvidia* || true
                run_cmd apt autoremove -y
            else
                echo "Skipping purge of existing NVIDIA packages."
            fi
        fi

        echo "Adding NVIDIA driver repository and installing drivers..."
        # Add NVIDIA CUDA repository
        distribution=$(. /etc/os-release;echo $ID$VERSION_ID | sed -e 's/\.//g')
        run_cmd wget https://developer.download.nvidia.com/compute/cuda/repos/$distribution/x86_64/cuda-keyring_1.1-1_all.deb
        run_cmd dpkg -i cuda-keyring_1.1-1_all.deb
        run_cmd apt update

        # Install NVIDIA driver and open-source kernel modules
        if ! run_cmd apt install -y nvidia-driver nvidia-open; then
            echo_red "Failed to install NVIDIA drivers. Check repository or network."
            run_cmd rm cuda-keyring_1.1-1_all.deb
            return 1
        else
            echo_green "NVIDIA drivers and open-source kernel modules installed successfully."
            # Clean up
            run_cmd rm cuda-keyring_1.1-1_all.deb
            # Force DKMS rebuild
            run_cmd dkms autoinstall
            # Verify kernel modules
            if ! ls /lib/modules/$kernel_version/updates/dkms/nvidia.ko &>/dev/null; then
                echo_red "NVIDIA kernel module not found in /lib/modules/$kernel_version/updates/dkms/"
                echo_red "Check DKMS logs: /var/log/dkms/nvidia-current/*/build/make.log"
            fi
            if ! lsmod | grep -q nvidia; then
                echo_red "NVIDIA kernel modules not loaded. Attempting to load..."
                run_cmd modprobe nvidia || echo_red "Failed to load NVIDIA kernel modules. Check dmesg: $(dmesg | grep -i nvidia | tail -n 5)"
            fi
            # Verify nvidia-smi
            if ! command -v nvidia-smi &>/dev/null; then
                echo_red "nvidia-smi not found after installation. Check /usr/bin/nvidia-smi or /var/log/dkms/nvidia-current/*/build/make.log"
                return 1
            fi
            echo "A system reboot is recommended to load NVIDIA kernel modules."
            read -p "Reboot now? (y/n): " reboot_choice
            if [[ "$reboot_choice" == "y" || "$reboot_choice" == "Y" ]]; then
                run_cmd reboot
            else
                echo "Continuing without reboot."
            fi
        fi

        # Verify installation
        if command -v nvidia-smi &>/dev/null && lsmod | grep -q nvidia; then
            echo_green "NVIDIA driver installation verified: $(nvidia-smi --query-gpu=name --format=csv)"
        else
            echo_red "NVIDIA drivers not fully functional. Check /usr/bin/nvidia-smi, lsmod, or dmesg."
            return 1
        fi
    elif [[ "$OS" == "qts" ]]; then
        echo_red "NVIDIA drivers on QNAP/QTS typically require installation via the QNAP App Center or manual driver packages."
        echo_red "Please install them manually if needed. Skipping automated installation."
        return 1
    else
        echo_red "NVIDIA driver installation is only supported on Ubuntu or Debian systems."
        return 1
    fi
} # install_nvidia_drivers

# Install NVIDIA Container Toolkit (for Docker GPU support) and nvidia-smi for testing
# Last Updated: 9/7/2025 4:11:00 PM CDT
function install_nvidia_container_toolkit() {
    echo "Installing NVIDIA Container Toolkit and nvidia-smi..."

    if [[ "$OS" == "debian" || "$OS" == "ubuntu" ]]; then
        # Check if NVIDIA Container Toolkit is already installed
        if command -v nvidia-ctk &>/dev/null; then
            echo_green "NVIDIA Container Toolkit is already installed."
            # Check if nvidia-smi is installed
            if command -v nvidia-smi &>/dev/null; then
                echo_green "nvidia-smi is already installed."
                # Verify nvidia-smi functionality
                if ! nvidia-smi &>/dev/null; then
                    echo_red "nvidia-smi failed to run. Check GPU device access or library dependencies."
                    echo_red "Device permissions: $(ls -l /dev/nvidia* 2>/dev/null || echo 'No NVIDIA devices found')"
                    local nvidia_smi_path
                    nvidia_smi_path=$(find /usr/bin /usr/lib/nvidia* -type f -name nvidia-smi 2>/dev/null | head -n 1)
                    echo_red "Library dependencies: $(ldd "$nvidia_smi_path" 2>/dev/null || echo 'No nvidia-smi binary found')"
                    echo_red "nvidia-smi error output: $(nvidia-smi 2>&1)"
                    return 1
                fi
                echo_green "nvidia-smi verified: $(nvidia-smi --query-gpu=name --format=csv,noheader)"
                # Configure Docker runtime
                run_cmd nvidia-ctk runtime configure --runtime=docker
                run_cmd systemctl restart docker
                echo_green "Docker configured for NVIDIA runtime."
                return 0
            fi
        fi

        # Check if Docker is installed
        if ! command -v docker &>/dev/null; then
            echo_red "Docker is required for NVIDIA Container Toolkit but not installed."
            read -p "Install Docker now? (y/n): " install_docker_choice
            if [[ "$install_docker_choice" == "y" || "$install_docker_choice" == "Y" ]]; then
                install_docker
            else
                echo_red "Docker not installed. Skipping NVIDIA Container Toolkit installation."
                return 1
            fi
        fi

        # Ensure the video group exists with GID 44 and add the current user
        if ! getent group video &>/dev/null; then
            echo "Creating video group with GID 44..."
            run_cmd groupadd -g 44 video
        elif [[ $(getent group video | cut -d: -f3) != "44" ]]; then
            echo_red "Video group exists but has incorrect GID. Expected 44, found $(getent group video | cut -d: -f3)."
            return 1
        fi
        local current_user=$(whoami)
        if [[ "$current_user" != "root" ]]; then
            echo "Adding user $current_user to video group for GPU access..."
            run_cmd usermod -aG video "$current_user"
        fi

        # Determine the NVIDIA driver version for nvidia-utils
        local driver_branch="580"  # Default to match host driver version
        local nvidia_utils_pkg="nvidia-utils-$driver_branch"
        if [[ -f "/proc/driver/nvidia/version" ]]; then
            driver_branch=$(grep -oP 'NVRM version: NVIDIA UNIX.*?(\d{3})\.' /proc/driver/nvidia/version | head -n 1 | grep -o '[0-9]\{3\}')
            if [[ -n "$driver_branch" ]]; then
                nvidia_utils_pkg="nvidia-utils-$driver_branch"
                echo "Detected NVIDIA driver branch $driver_branch from /proc/driver/nvidia/version. Attempting $nvidia_utils_pkg for nvidia-smi."
            else
                echo "Could not parse NVIDIA driver branch from /proc/driver/nvidia/version. Using $nvidia_utils_pkg."
            fi
        else
            echo "/proc/driver/nvidia/version not available. Using $nvidia_utils_pkg for nvidia-smi."
        fi

        echo "Adding NVIDIA CUDA repository for access to $nvidia_utils_pkg and cuda-drivers..."
        # Add NVIDIA CUDA repository
        distribution=$(. /etc/os-release;echo $ID$VERSION_ID | sed -e 's/\.//g')
        if run_cmd wget https://developer.download.nvidia.com/compute/cuda/repos/$distribution/x86_64/cuda-keyring_1.1-1_all.deb; then
            run_cmd dpkg -i cuda-keyring_1.1-1_all.deb
            run_cmd apt update
            run_cmd rm cuda-keyring_1.1-1_all.deb
        else
            echo_red "Failed to add NVIDIA CUDA repository. Attempting installation with default repos."
        fi

        echo "Installing NVIDIA Container Toolkit and nvidia-smi..."
        # Add NVIDIA Container Toolkit repository
        run_cmd curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | run_cmd gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
        run_cmd curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | run_cmd tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
        run_cmd apt update
        # Install NVIDIA Container Toolkit and nvidia-smi
        local install_pkg="$nvidia_utils_pkg"
        if run_cmd apt install -y nvidia-container-toolkit "$install_pkg"; then
            # Verify nvidia-smi installation
            local nvidia_smi_path
            nvidia_smi_path=$(find /usr/bin /usr/lib/nvidia* -type f -name nvidia-smi 2>/dev/null | head -n 1)
            if [ -n "$nvidia_smi_path" ]; then
                echo_green "nvidia-smi found at $nvidia_smi_path."
                if [ "$nvidia_smi_path" != "/usr/bin/nvidia-smi" ]; then
                    run_cmd ln -sf "$nvidia_smi_path" /usr/bin/nvidia-smi
                    echo_green "Created symlink for nvidia-smi at /usr/bin/nvidia-smi."
                fi
            else
                echo_red "nvidia-smi not found after installing $install_pkg. Checking package contents..."
                echo_red "Contents of $install_pkg: $(dpkg -L $install_pkg | grep -i nvidia-smi || echo 'No nvidia-smi found in package')"
                # Fall back to cuda-drivers
                install_pkg="cuda-drivers"
                echo "Falling back to $install_pkg..."
                if ! run_cmd apt install -y nvidia-container-toolkit "$install_pkg"; then
                    echo_red "Failed to install NVIDIA Container Toolkit or $install_pkg. Check repository, network, or package availability."
                    echo_red "Available nvidia-utils versions: $(apt-cache madison nvidia-utils | awk '{print $3}' | sort -u)"
                    echo_red "Available cuda-drivers versions: $(apt-cache madison cuda-drivers | awk '{print $3}' | sort -u)"
                    return 1
                fi
                nvidia_smi_path=$(find /usr/bin /usr/lib/nvidia* -type f -name nvidia-smi 2>/dev/null | head -n 1)
                if [ -n "$nvidia_smi_path" ]; then
                    echo_green "nvidia-smi found at $nvidia_smi_path."
                    if [ "$nvidia_smi_path" != "/usr/bin/nvidia-smi" ]; then
                        run_cmd ln -sf "$nvidia_smi_path" /usr/bin/nvidia-smi
                        echo_green "Created symlink for nvidia-smi at /usr/bin/nvidia-smi."
                    fi
                else
                    echo_red "nvidia-smi not found after installing $install_pkg."
                    echo_red "Contents of $install_pkg: $(dpkg -L $install_pkg | grep -i nvidia-smi || echo 'No nvidia-smi found in package')"
                    return 1
                fi
            fi
        else
            # Fall back to cuda-drivers
            install_pkg="cuda-drivers"
            echo "Falling back to $install_pkg..."
            if ! run_cmd apt install -y nvidia-container-toolkit "$install_pkg"; then
                echo_red "Failed to install NVIDIA Container Toolkit or $install_pkg. Check repository, network, or package availability."
                echo_red "Available nvidia-utils versions: $(apt-cache madison nvidia-utils | awk '{print $3}' | sort -u)"
                echo_red "Available cuda-drivers versions: $(apt-cache madison cuda-drivers | awk '{print $3}' | sort -u)"
                return 1
            fi
            nvidia_smi_path=$(find /usr/bin /usr/lib/nvidia* -type f -name nvidia-smi 2>/dev/null | head -n 1)
            if [ -n "$nvidia_smi_path" ]; then
                echo_green "nvidia-smi found at $nvidia_smi_path."
                if [ "$nvidia_smi_path" != "/usr/bin/nvidia-smi" ]; then
                    run_cmd ln -sf "$nvidia_smi_path" /usr/bin/nvidia-smi
                    echo_green "Created symlink for nvidia-smi at /usr/bin/nvidia-smi."
                fi
            else
                echo_red "nvidia-smi not found after installing $install_pkg."
                echo_red "Contents of $install_pkg: $(dpkg -L $install_pkg | grep -i nvidia-smi || echo 'No nvidia-smi found in package')"
                return 1
            fi
        fi

        # Ensure library dependencies are installed
        if [ -n "$nvidia_smi_path" ] && ! ldd "$nvidia_smi_path" | grep -q "not found"; then
            echo_green "All nvidia-smi library dependencies satisfied."
        else
            echo_red "Missing nvidia-smi library dependencies: $(ldd "$nvidia_smi_path" | grep 'not found' || echo 'No nvidia-smi binary found')"
            echo "Attempting to install libnvidia-compute-$driver_branch..."
            if ! run_cmd apt install -y "libnvidia-compute-$driver_branch"; then
                echo_red "Failed to install libnvidia-compute-$driver_branch."
                # Try cuda-drivers as fallback
                if ! run_cmd apt install -y cuda-drivers; then
                    echo_red "Failed to install cuda-drivers. Check repository or network."
                    return 1
                fi
            fi
            echo "Attempting to install libnvidia-ml-$driver_branch for NVIDIA Management Library..."
            if ! run_cmd apt install -y "libnvidia-ml-$driver_branch"; then
                echo_red "Failed to install libnvidia-ml-$driver_branch."
                # Try cuda-drivers as fallback
                if ! run_cmd apt install -y cuda-drivers; then
                    echo_red "Failed to install cuda-drivers. Check repository or network."
                    return 1
                fi
            fi
        fi

        # Check NVIDIA device permissions
        if ls /dev/nvidia* &>/dev/null; then
            echo_green "NVIDIA devices found: $(ls /dev/nvidia*)"
            if ! ls -l /dev/nvidia* | grep -v nvidia-modeset | grep -q "rw-rw.*video"; then
                echo_red "NVIDIA devices (excluding nvidia-modeset) lack sufficient permissions or incorrect group: $(ls -l /dev/nvidia*)"
                echo_red "Ensure LXC config maps devices correctly and host permissions allow access."
                return 1
            fi
            # Verify user access to devices
            local current_user=$(whoami)
            if [[ "$current_user" != "root" ]]; then
                if ! groups "$current_user" | grep -q "\bvideo\b"; then
                    echo_red "User $current_user is not in the video group. Cannot access NVIDIA devices."
                    return 1
                fi
                # Check if user can access devices
                if ! sudo -u "$current_user" test -r /dev/nvidia0 && ! sudo -u "$current_user" test -w /dev/nvidia0; then
                    echo_red "User $current_user cannot read/write /dev/nvidia0. Check LXC device passthrough or host permissions."
                    echo_red "Device permissions: $(ls -l /dev/nvidia*)"
                    return 1
                fi
            fi
        else
            echo_red "No NVIDIA devices found in /dev/nvidia*. Check LXC device passthrough."
            return 1
        fi

        # Configure Docker runtime
        run_cmd nvidia-ctk runtime configure --runtime=docker
        run_cmd systemctl restart docker
        echo_green "Docker configured for NVIDIA runtime."
        # Final nvidia-smi verification
        if ! command -v nvidia-smi &>/dev/null; then
            echo_red "nvidia-smi still not found after installation. Check /usr/bin/nvidia-smi, repository, or LXC device passthrough."
            echo_red "Checking library dependencies: $(find /usr/bin /usr/lib -name nvidia-smi -exec ldd {} \; 2>/dev/null || echo 'No nvidia-smi binary found')"
            return 1
        fi
        # Verify nvidia-smi functionality
        if ! nvidia-smi &>/dev/null; then
            echo_red "nvidia-smi failed to run. Check GPU device access or library dependencies."
            echo_red "Device permissions: $(ls -l /dev/nvidia* 2>/dev/null || echo 'No NVIDIA devices found')"
            echo_red "Library dependencies: $(ldd "$nvidia_smi_path" 2>/dev/null || echo 'No nvidia-smi binary found')"
            echo_red "nvidia-smi error output: $(nvidia-smi 2>&1)"
            return 1
        fi
        echo_green "nvidia-smi verified: $(nvidia-smi --query-gpu=name --format=csv,noheader)"
    elif [[ "$OS" == "qts" ]]; then
        echo_red "NVIDIA Container Toolkit on QNAP/QTS may require manual configuration via Container Station."
        echo_red "Please install and configure it manually if needed. Skipping automated installation."
        return 1
    else
        echo_red "NVIDIA Container Toolkit installation is only supported on Ubuntu or Debian systems."
        return 1
    fi
} # install_nvidia_container_toolkit() 


# Install Starship
function install_starship() {
    echo "Installing Starship..."
    if [[ "$OS" == "debian" || "$OS" == "ubuntu" || "$OS" == "qts" ]]; then
        # Ensure installation directory exists
        run_cmd mkdir -p "$DT_LOCAL_BIN_DIR"
        run_cmd chown 1401:1401 "$DT_LOCAL_BIN_DIR"
        run_cmd chmod 775 "$DT_LOCAL_BIN_DIR"

        # Install Starship
        run_cmd curl -sS https://starship.rs/install.sh | sh -s -- -b "$DT_LOCAL_BIN_DIR" -y

        # Verify installation
        if "$DT_LOCAL_BIN_DIR/starship" --version &> /dev/null; then
            echo_green "Starship installed successfully."
        else
            echo_red "Failed to install Starship."
            return 1
        fi
    else
        echo "Unsupported OS for Starship installation."
        return 1
    fi
}

# Function to add a Syncthing user
function add_syncthing_user() {
    local username="syncthing"
    local uid="1401"

    # Check if the OS is Ubuntu/Debian or QNAP and add the user with appropriate groups
    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        add_user "$username" "adm" "$uid"
    elif [[ "$OS" == "qts" ]]; then
        add_user "$username" "administrators adm" "$uid"
    else
        echo "Unsupported OS for adding the Syncthing user."
    fi
} # add_syncthing_user


# Configure Syncthing to start on boot and modify the config.xml file
function configure_syncthing_boot() {
    # Add syncthing user if it doesn't exist and add to appropriate groups
    add_syncthing_user

    # Path to the Syncthing configuration file
    syncthing_config="/home/syncthing/.local/state/syncthing/config.xml"

    # Determine the package manager
    if [[ "$PKG_MANAGER" == "apt" ]]; then
        install_cmd="apt install -y"
    elif [[ "$PKG_MANAGER" == "opkg" ]]; then
        install_cmd="opkg install"
    else
        echo "Unsupported package manager: $PKG_MANAGER"
        return 1
    fi

    # Check if mkpasswd (bcrypt) is installed
    if ! command -v mkpasswd &>/dev/null; then
        echo "mkpasswd is required but not installed. Installing whois..."
        run_cmd $install_cmd whois
    fi

    # If mkpasswd is still not found, try installing apache-utils for htpasswd
    if ! command -v mkpasswd &>/dev/null; then
        echo "mkpasswd not found. Installing apache-utils for htpasswd..."
        run_cmd $install_cmd apache-utils
    fi

    # Prompt for a new password
    read -sp "Enter a password for the Syncthing 'divix' user: " syncthing_password
    echo ""

    # Use mkpasswd or htpasswd to generate a bcrypt hash for the password
    if command -v mkpasswd &>/dev/null; then
        # Use mkpasswd for hashing
        hashed_password=$(mkpasswd --method=bcrypt --rounds=10 "$syncthing_password")
    elif command -v htpasswd &>/dev/null; then
        # Use htpasswd for hashing
        hashed_password=$(htpasswd -nbBC 10 "" "$syncthing_password" | cut -d ":" -f 2)
    else
        echo "Error: Neither mkpasswd nor htpasswd is available for password hashing."
        return 1
    fi

    # Modify the config.xml file using xmlstarlet
    if [ -f "$syncthing_config" ]; then
        # Backup the original file
        run_cmd cp "$syncthing_config" "$syncthing_config.bak"

        echo "Modifying Syncthing config file: $syncthing_config..."

        # Ensure the <gui> element exists
        if ! xmlstarlet sel -t -v "//gui" "$syncthing_config" &>/dev/null; then
            echo "Adding <gui> element to the config..."
            xmlstarlet ed -L -s "/configuration" -t elem -n "gui" -v "" "$syncthing_config"
        fi

        # Ensure <address> exists and update it
        if xmlstarlet sel -t -v "//gui/address" "$syncthing_config" &>/dev/null; then
            xmlstarlet ed -L -u "//gui/address" -v "0.0.0.0:8384" "$syncthing_config"
        else
            xmlstarlet ed -L -s "//gui" -t elem -n "address" -v "0.0.0.0:8384" "$syncthing_config"
        fi

        # Ensure <user> exists and update it, or add it if missing
        if xmlstarlet sel -t -v "//gui/user" "$syncthing_config" &>/dev/null; then
            xmlstarlet ed -L -u "//gui/user" -v "divix" "$syncthing_config"
        else
            xmlstarlet ed -L -s "//gui" -t elem -n "user" -v "divix" "$syncthing_config"
        fi

        # Ensure <password> exists and update it, or add it if missing
        if xmlstarlet sel -t -v "//gui/password" "$syncthing_config" &>/dev/null; then
            xmlstarlet ed -L -u "//gui/password" -v "$hashed_password" "$syncthing_config"
        else
            xmlstarlet ed -L -s "//gui" -t elem -n "password" -v "$hashed_password" "$syncthing_config"
        fi

        echo "Configuration updated. GUI is now set to listen on 0.0.0.0:8384 with user 'divix'."
    else
        echo "Syncthing configuration file not found: $syncthing_config"
        return 1
    fi

    # Proceed with configuration for Ubuntu or Debian
    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        # Create a systemd service file for Syncthing
        run_cmd tee /etc/systemd/system/syncthing.service > /dev/null <<EOL
[Unit]
Description=Syncthing - Open Source Continuous File Synchronization
Documentation=man:syncthing(1)
After=network.target

[Service]
User=syncthing
AmbientCapabilities=CAP_NET_ADMIN CAP_CHOWN CAP_FOWNER
ExecStartPre=/bin/sh -c 'sysctl -w net.core.rmem_max=8388608'
ExecStartPre=/bin/sh -c 'sysctl -w net.core.wmem_max=8388608'
ExecStart=/usr/bin/syncthing -no-browser -logflags=0
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOL

        # Reload systemd and enable the Syncthing service
        run_cmd systemctl daemon-reload
        run_cmd systemctl enable syncthing
        run_cmd systemctl start syncthing

        echo "Syncthing has been registered with systemctl and is starting."
    elif [[ "$OS" == "qts" ]]; then
        echo "QNAP autostart of syncthing must be configured manually."
    fi
}



# Update the git configuration for divix and root users
function update_git_config() {
    # Configure git for divix user
    run_cmd sudo -u divix git config --global user.name "Andrew Fields"
    run_cmd sudo -u divix git config --global user.email "andrew@avcorp.biz"
    run_cmd sudo -u divix git config --global url."git@github.com:".insteadOf https://github.com/
    
    # Mark $DIVTOOLS as a safe directory for the divix user
    run_cmd sudo -u divix git config --global --add safe.directory "$DIVTOOLS"

    # Configure git for root user
    git config --global user.name "Andrew Fields"
    git config --global user.email "andrew@avcorp.biz"
    git config --global url."git@github.com:".insteadOf https://github.com/
    
    # Mark $DIVTOOLS as a safe directory for the root user
    git config --global --add safe.directory "$DIVTOOLS"
}

# Function to git clone the divtools repository into $DIVTOOLS
function clone_divtools_repo() {
    # Check if the ~/.ssh directory exists, create it if not
    if [ ! -d ~/.ssh ]; then
        echo "~/.ssh directory does not exist. Creating it..."
        mkdir -p ~/.ssh
        chmod 700 ~/.ssh
    fi

    # Check if the ~/.ssh/id_ed25519 file exists
    if [ ! -f ~/.ssh/id_ed25519 ]; then
        echo "~/.ssh/id_ed25519 does not exist. You need to provide an SSH private key for Git operations."
        
        echo "Please paste your private SSH key (id_ed25519) below. Press Ctrl+D when finished:"
        
        # Read multi-line input (private SSH key)
        ssh_key=""
        while IFS= read -r line; do
            ssh_key+="$line"$'\n'
        done
        
        # Save the user's input into the id_ed25519 file
        echo -n "$ssh_key" > ~/.ssh/id_ed25519
        chmod 600 ~/.ssh/id_ed25519
        
        echo "SSH private key saved to ~/.ssh/id_ed25519."
    fi

    # Ensure there is a public key (if not already present)
    if [ ! -f ~/.ssh/id_ed25519.pub ]; then
        echo "Generating the public key..."
        ssh-keygen -y -f ~/.ssh/id_ed25519 > ~/.ssh/id_ed25519.pub
        echo "Public key generated at ~/.ssh/id_ed25519.pub."
    fi

    # Check if the $DIVTOOLS directory exists
    if [ ! -d "$DIVTOOLS" ]; then
        echo "$DIVTOOLS directory does not exist. Creating it first..."
        run_cmd mkdir -p "$DIVTOOLS"
        run_cmd chown :adm "$DIVTOOLS"
        run_cmd chmod 775 "$DIVTOOLS"
    fi

    # Check if the directory is empty
    if [ "$(ls -A "$DIVTOOLS")" ]; then
        echo "$DIVTOOLS is not empty. Aborting git clone."
        return 1
    fi

    echo "Cloning the divtools repository into $DIVTOOLS..."

    # Change directory to $DIVTOOLS and clone the repository into it
    (
        cd "$DIVTOOLS" || exit
        run_cmd git clone git@github.com:adf1969/divtools.git .
    )

    if [ $? -eq 0 ]; then
        echo "Repository cloned successfully into $DIVTOOLS."
    else
        echo "Failed to clone the repository."
    fi
}




# Update /etc/profile
# Added modifications to handle when DIVTOOLS is NOT in /opt/divtools
function update_profile() {
    if grep -q "#DIVTOOLS-BEFORE" /etc/profile; then
        # If the DIVTOOLS block exists, replace the content between BEFORE and AFTER
        echo "Updating Divtools entry in /etc/profile."
        run_cmd sed -i '/#DIVTOOLS-BEFORE/,/#DIVTOOLS-AFTER/c\
#DIVTOOLS-BEFORE\n\
# Source divtools profile\n\
if [ -f ~/.env ]; then\n\
    . ~/.env\n\
fi\n\
if [ -z "$DIVTOOLS" ]; then\n\
    export DIVTOOLS=/opt/divtools\n\
fi\n\
if [ -f "$DIVTOOLS/dotfiles/.bash_profile" ]; then\n\
    . "$DIVTOOLS/dotfiles/.bash_profile"\n\
fi\n\
#DIVTOOLS-AFTER' /etc/profile
    else
        # If the DIVTOOLS block doesn't exist, append it to the file
        echo "Adding Divtools entry to /etc/profile."
        run_cmd tee -a /etc/profile > /dev/null <<EOL

#DIVTOOLS-BEFORE
# Source divtools profile
if [ -f ~/.env ]; then
    . ~/.env
fi
if [ -z "\$DIVTOOLS" ]; then
    export DIVTOOLS=/opt/divtools
fi
if [ -f "\$DIVTOOLS/dotfiles/.bash_profile" ]; then
    . "\$DIVTOOLS/dotfiles/.bash_profile"
fi
#DIVTOOLS-AFTER
EOL
    fi
}


# Update /etc/init.d/container-station.sh
function update_qnap_container_station() {
    # Define the path to the startup script
    local STARTUP_SCRIPT_PATH="$NEW_OPT_LOC/divtools/qnap_cfg/etc/config/adf_custom_startup.sh"
    local INIT_SCRIPT="/etc/init.d/container-station.sh"

    # Check if the DIVTOOLS block already exists
    if grep -q "#DIVTOOLS-BEFORE" "$INIT_SCRIPT"; then
        echo "Updating Divtools Custom QNAP Startup entry in $INIT_SCRIPT."
        awk -v script_path="$STARTUP_SCRIPT_PATH" '
            BEGIN {found=0}
            /#DIVTOOLS-BEFORE/ {found=1; print "#DIVTOOLS-BEFORE"; next}
            /#DIVTOOLS-AFTER/ {found=1; print "#DIVTOOLS-AFTER"; next}
            {if (!found) print $0}
            END {
                if (found) {
                    print "#DIVTOOLS-BEFORE"
                    print "# Run Custom QNAP Startup"
                    print "if [ -f " script_path " ]; then"
                    print "    " script_path
                    print "fi"
                    print "#DIVTOOLS-AFTER"
                }
            }' "$INIT_SCRIPT" | tee "$INIT_SCRIPT.tmp" > /dev/null
        run_cmd mv "$INIT_SCRIPT.tmp" "$INIT_SCRIPT"
    else
        # Check if "exit 0" exists and insert before it, or append at the end
        if grep -q "exit 0" "$INIT_SCRIPT"; then
            echo "Inserting Divtools Custom QNAP Startup entry before 'exit 0' in $INIT_SCRIPT."
            awk -v script_path="$STARTUP_SCRIPT_PATH" '
                /exit 0/ {
                    print "#DIVTOOLS-BEFORE"
                    print "# Run Custom QNAP Startup"
                    print "if [ -f " script_path " ]; then"
                    print "    " script_path
                    print "fi"
                    print "#DIVTOOLS-AFTER"
                    print
                    next
                }
                {print}
            ' "$INIT_SCRIPT" | tee "$INIT_SCRIPT.tmp" > /dev/null
            run_cmd mv "$INIT_SCRIPT.tmp" "$INIT_SCRIPT"
        else
            echo "Adding Divtools Custom QNAP Startup entry to the end of $INIT_SCRIPT."
            tee -a "$INIT_SCRIPT" > /dev/null <<EOL

#DIVTOOLS-BEFORE
# Run Custom QNAP Startup
if [ -f ${STARTUP_SCRIPT_PATH} ]; then
    ${STARTUP_SCRIPT_PATH}
fi
#DIVTOOLS-AFTER
EOL
        fi
    fi
}



# Update authorized_keys
function update_authorized_keys() {
    authorized_keys_url="https://raw.githubusercontent.com/adf1969/divtools/main/.ssh/authorized_keys"
    for user in divix drupal syncthing; do
        if id "$user" &>/dev/null; then
            mkdir -p /home/$user/.ssh
            run_cmd curl -s $authorized_keys_url -o /home/$user/.ssh/authorized_keys
            run_cmd chown $user:$user /home/$user/.ssh/authorized_keys
            run_cmd chmod 600 /home/$user/.ssh/authorized_keys
        fi
    done
    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        run_cmd curl -s $authorized_keys_url -o /root/.ssh/authorized_keys
    elif [[ "$OS" == "qts" ]]; then
        run_cmd curl -s $authorized_keys_url -o /root/.ssh/authorized_keys
    fi
}


# Function to configure en_US.UTF-8 locale
function configure_utf8_locale() {
    echo "Configuring en_US.UTF-8 locale..."

    # see: https://github.com/starship/starship/issues/5881
    # Check if /etc/locale.gen exists
    if [ -f /etc/locale.gen ]; then
        # Uncomment the line for en_US.UTF-8
        run_cmd sed -i '/^# *en_US.UTF-8 UTF-8/s/^# *//' /etc/locale.gen
        echo "Uncommented en_US.UTF-8 in /etc/locale.gen."

        # Generate the locale
        run_cmd locale-gen en_US.UTF-8
        echo "Locale en_US.UTF-8 generated."

        # Set the default locale
        run_cmd update-locale LANG=en_US.UTF-8
        echo "Default locale set to en_US.UTF-8."
    else
        echo "Error: /etc/locale.gen not found. Unable to configure locale."
        return 1
    fi
}



# Use whiptail to present a checkbox menu to the user
function get_selections() {
    # Apply custom whiptail colors
    set_whiptail_colors

    # Check if container-station.sh exists
    if [ -f /etc/init.d/container-station.sh ]; then
        container_station_option="ON"
        container_station_text="Update QNAP Container Station"
    else
        container_station_option="OFF"
        container_station_text="Update QNAP Container Station (Container Station not installed)"
    fi

    selections=$(whiptail --fb --title "Select Tasks" --checklist \
    "Choose tasks to run. Use SPACE to select and ENTER to confirm." 20 78 22 \
    "SET_ENV_VARS" "Set Divtools Environment Variables" OFF \
    "ADD_DIVIX_USER" "Add Divix User" OFF \
    "ADD_SYNCTHING_USER" "Add Syncthing User" OFF \
    "CREATE_DIVTOOLS_FOLDER" "Create $DIVTOOLS Folder" OFF \
    "INSTALL_ENTWARE" "Install Entware (QNAP only)" OFF \
    "INSTALL_PACKAGES" "Install Software Packages" OFF \
    "INSTALL_PACKAGES_PROXMOX" "Install PROXMOX Software Packages" OFF \
    "INSTALL_DOCKER" "Install Docker" OFF \
    "INSTALL_COCKPIT" "Install Cockpit and Modules" OFF \
    "INSTALL_EZA" "Install eza (Modern ls Replacement)" OFF \
    "INSTALL_STARSHIP" "Install Starship Shell Prompt" OFF \
    "INSTALL_SYNCTHING" "Install SyncThing" OFF \
    "INSTALL_NVIDIA_DRIVERS" "Install NVIDIA Drivers" OFF \
    "INSTALL_NVIDIA_TOOLKIT" "Install NVIDIA Container Toolkit" OFF \
    "CONFIGURE_SYNCTHING_BOOT" "Configure Syncthing to Run on Boot" OFF \
    "UPDATE_GIT_CONFIG" "Update Git Config" OFF \
    "UPDATE_PROFILE" "Update /etc/profile" OFF \
    "UPDATE_AUTH_KEYS" "Update authorized_keys" OFF \
    "UPDATE_QNAP_CONTAINER" "$container_station_text" $container_station_option \
    "CLONE_DIVTOOLS_REPO" "Clone divtools Repository into $DIVTOOLS" OFF \
    "CONFIGURE_UTF8_LOCALE" "Configure en_US.UTF-8 Locale" OFF 3>&1 1>&2 2>&3)

    if [[ $? != 0 ]]; then
        echo "Task selection cancelled."
        exit 1
    fi

    # Return selected items as a list
    echo "$selections"
} # get_selections


# Run the selected tasks
function run_selected_tasks() {
    for selection in $selections; do
        case $selection in
            \"SET_ENV_VARS\") prompt_env_vars ;;
            \"ADD_DIVIX_USER\") add_divix_user ;;
            \"ADD_SYNCTHING_USER\") add_syncthing_user ;;
            \"CREATE_DIVTOOLS_FOLDER\") create_divtools_folder ;;
            \"INSTALL_ENTWARE\") install_entware ;;
            \"INSTALL_PACKAGES\") install_packages ;;
            \"INSTALL_PACKAGES_PROXMOX\") install_packages_proxmox ;;
            \"INSTALL_DOCKER\") install_docker ;;
            \"INSTALL_COCKPIT\") install_cockpit ;;
            \"INSTALL_EZA\") install_eza ;;
            \"INSTALL_STARSHIP\") install_starship ;;
            \"INSTALL_SYNCTHING\") install_syncthing ;;
            \"INSTALL_NVIDIA_DRIVERS\") install_nvidia_drivers ;;
            \"INSTALL_NVIDIA_TOOLKIT\") install_nvidia_container_toolkit ;;
            \"CONFIGURE_SYNCTHING_BOOT\") configure_syncthing_boot ;;
            \"UPDATE_GIT_CONFIG\") update_git_config ;;
            \"UPDATE_PROFILE\") update_profile ;;
            \"UPDATE_AUTH_KEYS\") update_authorized_keys ;;
            \"UPDATE_QNAP_CONTAINER\") update_qnap_container_station ;;
            \"CLONE_DIVTOOLS_REPO\") clone_divtools_repo ;;
            \"CONFIGURE_UTF8_LOCALE\") configure_utf8_locale ;;
        esac
    done
} # run_selected_tasks




# Main script execution
# Last Updated: 9/7/2025 6:49:45 PM CDT
function main() {
    detect_os
    # Only prompt for env vars if explicitly selected or not set
    if [[ -z "$DIVTOOLS" || -z "$DOCKERDATADIR" || -z "$DT_LOCAL_BIN_DIR" ]]; then
        prompt_env_vars
    fi
    write_env_files
    get_selections
    read -p "Are you sure you want to run the selected tasks? (y/n): " confirm_run
    if [[ "$confirm_run" == "y" || "$confirm_run" == "Y" ]]; then
        run_selected_tasks
    else
        echo "Tasks cancelled."
    fi
}

# Initialize environment variables when script is sourced or run
init_env_vars

# Only run main if the script is executed (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi

