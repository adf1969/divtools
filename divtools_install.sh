#!/bin/bash

NEW_OPT_LOC="/share/CACHEDEV1_DATA/opt"   # Set to location where you want /opt to be

# Check if the script is run as root or a non-root user
function run_cmd() {
    if [[ $EUID -ne 0 ]]; then
        sudo $@
    else
        $@
    fi
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
    # Create /opt/divtools if it doesn't exist
    if [ ! -d /opt/divtools ]; then
        run_cmd mkdir -p /opt/divtools
    fi

    # Set the ownership of /opt/divtools to the "adm" group
    run_cmd chown :adm /opt/divtools

    # Set the permissions of /opt/divtools to 775
    run_cmd chmod 775 /opt/divtools

    # Create a symbolic link in the divix home directory to /opt/divtools
    if [ -d /home/divix ]; then
        if [ ! -L /home/divix/divtools ]; then
            run_cmd ln -s /opt/divtools /home/divix/divtools
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

# Install necessary packages
function install_packages_proxmox() {
    packages=(sudo git syncthing)

    if [[ "$PKG_MANAGER" == "apt" ]]; then
        # Add syncthing repository if syncthing is not already installed
        if ! command -v syncthing &>/dev/null; then
            run_cmd curl -s https://syncthing.net/release-key.txt | run_cmd gpg --dearmor -o /usr/share/keyrings/syncthing-archive-keyring.gpg
            echo "deb [signed-by=/usr/share/keyrings/syncthing-archive-keyring.gpg] https://apt.syncthing.net/ syncthing stable" | run_cmd tee /etc/apt/sources.list.d/syncthing.list
            run_cmd apt update
        fi

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


# Install necessary packages
function install_packages() {
    packages=(curl sudo whois syncthing xmlstarlet git git-http vim-nox rclone python3 libssl-dev ca-certificates openssh-client tmux net-tools ccze)

    if [[ "$PKG_MANAGER" == "apt" ]]; then
        # Add syncthing repository if syncthing is not already installed
        if ! command -v syncthing &>/dev/null; then
            run_cmd curl -s https://syncthing.net/release-key.txt | run_cmd gpg --dearmor -o /usr/share/keyrings/syncthing-archive-keyring.gpg
            echo "deb [signed-by=/usr/share/keyrings/syncthing-archive-keyring.gpg] https://apt.syncthing.net/ syncthing stable" | run_cmd tee /etc/apt/sources.list.d/syncthing.list
            run_cmd apt update
        fi

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




# Function to install Docker
function install_docker() {
    # Comma-delimited list of users to add to the docker group
    local users_to_add="divix"

    # Check if Docker is already installed
    if command -v docker &> /dev/null; then
        echo "Docker is already installed."
        return
    fi

    echo "Installing Docker..."

    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        # Update package list and install prerequisites
        run_cmd apt update
        run_cmd apt install -y apt-transport-https ca-certificates curl software-properties-common

        # Add Docker’s official GPG key
        run_cmd curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

        # Add Docker repository
        run_cmd add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

        # Update package list again
        run_cmd apt update

        # Install Docker
        run_cmd apt install -y docker-ce

        # Enable Docker to start on boot and start the service
        run_cmd systemctl enable docker
        run_cmd systemctl start docker

        echo "Docker installed successfully."

        # Iterate over the comma-delimited list of users
        IFS=',' read -ra users <<< "$users_to_add"
        for user in "${users[@]}"; do
            # Check if the user exists and add them to the docker group
            if id "$user" &>/dev/null; then
                echo "User $user exists. Adding to docker group..."
                run_cmd usermod -aG docker "$user"
                echo "User $user added to docker group."
            else
                echo "User $user does not exist. Skipping docker group addition for $user."
            fi
        done

    elif [[ "$OS" == "qts" ]]; then
        echo "QNAP detected. Docker installation on QNAP must be done via App Center."
        return 1
    else
        echo "Unsupported OS for Docker installation."
        return 1
    fi
}


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

# Function to install eza
function install_eza() {
    echo "Installing eza..."

    if [[ "$OS" == "debian" || "$OS" == "ubuntu" ]]; then
        echo "Detected Debian-based system. Installing eza via APT..."
        sudo apt update
        sudo apt install -y gpg
        sudo mkdir -p /etc/apt/keyrings
        wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
        echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list
        sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
        sudo apt update
        sudo apt install -y eza
    elif [[ "$OS" == "qts" ]]; then
        echo "Detected QNAP QTS system. Installing eza via Entware..."
        run_cmd opkg install eza
        if [ ! -f /opt/bin/eza ]; then
            ln -s /opt/usr/bin/eza /opt/bin/eza
        fi
    else
        echo "Unsupported operating system for eza installation."
        return 1
    fi

    echo "eza installation completed successfully."
} # install_eza


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
    
    # Mark /opt/divtools as a safe directory for the divix user
    run_cmd sudo -u divix git config --global --add safe.directory /opt/divtools

    # Configure git for root user
    git config --global user.name "Andrew Fields"
    git config --global user.email "andrew@avcorp.biz"
    git config --global url."git@github.com:".insteadOf https://github.com/
    
    # Mark /opt/divtools as a safe directory for the root user
    git config --global --add safe.directory /opt/divtools
}

# Function to git clone the divtools repository into /opt/divtools
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

    # Check if the /opt/divtools directory exists
    if [ ! -d /opt/divtools ]; then
        echo "/opt/divtools directory does not exist. Creating it first..."
        run_cmd mkdir -p /opt/divtools
        run_cmd chown :adm /opt/divtools
        run_cmd chmod 775 /opt/divtools
    fi

    # Check if the directory is empty
    if [ "$(ls -A /opt/divtools)" ]; then
        echo "/opt/divtools is not empty. Aborting git clone."
        return 1
    fi

    echo "Cloning the divtools repository into /opt/divtools..."

    # Change directory to /opt/divtools and clone the repository into it
    (
        cd /opt/divtools || exit
        run_cmd git clone git@github.com:adf1969/divtools.git .
    )

    if [ $? -eq 0 ]; then
        echo "Repository cloned successfully into /opt/divtools."
    else
        echo "Failed to clone the repository."
    fi
}




# Update /etc/profile
function update_profile() {
    if grep -q "#DIVTOOLS-BEFORE" /etc/profile; then
        # If the DIVTOOLS block exists, replace the content between BEFORE and AFTER
        echo "Updating Divtools entry in /etc/profile."
        run_cmd sed -i '/#DIVTOOLS-BEFORE/,/#DIVTOOLS-AFTER/c\
#DIVTOOLS-BEFORE\n\
# Source divtools profile\n\
if [ -f /opt/divtools/dotfiles/.bash_profile ]; then\n\
    . /opt/divtools/dotfiles/.bash_profile\n\
fi\n\
#DIVTOOLS-AFTER' /etc/profile
    else
        # If the DIVTOOLS block doesn't exist, append it to the file
        echo "Adding Divtools entry to /etc/profile."
        run_cmd tee -a /etc/profile > /dev/null <<EOL

#DIVTOOLS-BEFORE
# Source divtools profile
if [ -f /opt/divtools/dotfiles/.bash_profile ]; then
    . /opt/divtools/dotfiles/.bash_profile
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
    # Check if container-station.sh exists
    if [ -f /etc/init.d/container-station.sh ]; then
        container_station_option="ON"
        container_station_text="Update QNAP Container Station"
    else
        container_station_option="OFF"
        container_station_text="Update QNAP Container Station (Container Station not installed)"
    fi

    selections=$(whiptail --title "Select Tasks" --checklist \
    "Choose tasks to run. Use SPACE to select and ENTER to confirm." 20 78 17 \
    "ADD_DIVIX_USER" "Add Divix User" OFF \
    "ADD_SYNCTHING_USER" "Add Syncthing User" OFF \
    "CREATE_DIVTOOLS_FOLDER" "Create /opt/divtools Folder" OFF \
    "INSTALL_ENTWARE" "Install Entware (QNAP only)" OFF \
    "INSTALL_PACKAGES" "Install Software Packages" OFF \
    "INSTALL_PACKAGES_PROXMOX" "Install PROXMOX Software Packages" OFF \
    "INSTALL_DOCKER" "Install Docker" OFF \
    "INSTALL_COCKPIT" "Install Cockpit and Modules" OFF \
    "INSTALL_EZA" "Install eza (Modern ls Replacement)" OFF \
    "CONFIGURE_SYNCTHING_BOOT" "Configure Syncthing to Run on Boot" OFF \
    "UPDATE_GIT_CONFIG" "Update Git Config" OFF \
    "UPDATE_PROFILE" "Update /etc/profile" OFF \
    "UPDATE_AUTH_KEYS" "Update authorized_keys" OFF \
    "UPDATE_QNAP_CONTAINER" "$container_station_text" $container_station_option \
    "CLONE_DIVTOOLS_REPO" "Clone divtools Repository into /opt/divtools" OFF \
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
            \"ADD_DIVIX_USER\") add_divix_user ;;
            \"ADD_SYNCTHING_USER\") add_syncthing_user ;;
            \"CREATE_DIVTOOLS_FOLDER\") create_divtools_folder ;;
            \"INSTALL_ENTWARE\") install_entware ;;
            \"INSTALL_PACKAGES\") install_packages ;;
            \"INSTALL_PACKAGES_PROXMOX\") install_packages_proxmox ;;
            \"INSTALL_DOCKER\") install_docker ;;
            \"INSTALL_COCKPIT\") install_cockpit ;;
            \"INSTALL_EZA\") install_eza ;;
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
function main() {
    detect_os
    get_selections
    read -p "Are you sure you want to run the selected tasks? (y/n): " confirm_run
    if [[ "$confirm_run" == "y" || "$confirm_run" == "Y" ]]; then
        run_selected_tasks
    else
        echo "Tasks cancelled."
    fi
}

# Run the script
main

