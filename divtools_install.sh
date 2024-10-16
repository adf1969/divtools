#!/bin/bash

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

# Add divix user and set password
# Add divix user and set password
function add_divix_user() {
    if id "divix" &>/dev/null; then
        echo "User divix already exists"
    else
        # Prompt for password input only if the user doesn't exist
        read -sp "Enter password for divix user: " divix_passwd
        echo ""
        
        # Add the divix user
        run_cmd useradd -m -s /bin/bash divix
        
        # Set the password for divix user (compatible with systems without chpasswd)
        echo "Setting password for divix user..."
        echo -e "$divix_passwd\n$divix_passwd" | run_cmd passwd divix
        
        # Add divix to appropriate groups
        if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
            run_cmd usermod -aG sudo divix
        elif [[ "$OS" == "qts" ]]; then
            run_cmd usermod -aG administrators divix
            # Create the "adm" group if it doesn't exist on QNAP
            if ! getent group adm &>/dev/null; then
                run_cmd groupadd adm
            fi
        fi

        # Add the "divix" user to the "adm" group on all systems
        run_cmd usermod -aG adm divix
    fi
}



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

# Install necessary packages
function install_packages() {
    packages=(sudo syncthing git git-http vim-nox rclone python3 libssl-dev curl ca-certificates openssh-client tmux)
    if [[ "$PKG_MANAGER" == "apt" ]]; then
        # Add syncthing repository
        if ! command -v syncthing &>/dev/null; then
            run_cmd curl -s https://syncthing.net/release-key.txt | run_cmd gpg --dearmor -o /usr/share/keyrings/syncthing-archive-keyring.gpg
            echo "deb [signed-by=/usr/share/keyrings/syncthing-archive-keyring.gpg] https://apt.syncthing.net/ syncthing stable" | run_cmd tee /etc/apt/sources.list.d/syncthing.list
            run_cmd apt update
        fi
        run_cmd apt install -y ${packages[@]}
    elif [[ "$PKG_MANAGER" == "opkg" ]]; then
        run_cmd opkg install ${packages[@]}
    fi
}

# Function to install Docker
function install_docker() {
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


# Configure Syncthing to start on boot
function configure_syncthing_boot() {
    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        # Create a systemd service file for Syncthing
        run_cmd tee /etc/systemd/system/syncthing.service > /dev/null <<EOL
[Unit]
Description=Syncthing - Open Source Continuous File Synchronization
Documentation=man:syncthing(1)
After=network.target

[Service]
User=syncthing
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
    if grep -q "#DIVTOOLS-BEFORE" /etc/init.d/container-station.sh; then
        # If the DIVTOOLS block exists, replace the content between BEFORE and AFTER
        echo "Updating Divtools Custom QNAP Startup entry in /etc/init.d/container-station.sh."
        run_cmd sed -i '/#DIVTOOLS-BEFORE/,/#DIVTOOLS-AFTER/c\
#DIVTOOLS-BEFORE\n\
# Run Custom QNAP Startup\n\
if [ -f /opt/divtools/qnap_cfg/etc/config/adf_custom_startup.sh ]; then\n\
    /opt/divtools/qnap_cfg/etc/config/adf_custom_startup.sh\n\
fi\n\
#DIVTOOLS-AFTER' /etc/profile
    else
        # If the DIVTOOLS block doesn't exist, append it to the file
        echo "Adding Divtools Custom QNAP Startup entry to /etc/init.d/container-station.sh."
        run_cmd tee -a /etc/init.d/container-station.sh > /dev/null <<EOL

#DIVTOOLS-BEFORE
# Run Custom QNAP Startup\n\
if [ -f /opt/divtools/qnap_cfg/etc/config/adf_custom_startup.sh ]; then\n\
    /opt/divtools/qnap_cfg/etc/config/adf_custom_startup.sh\n\
fi\n\
#DIVTOOLS-AFTER
EOL
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
    "Choose tasks to run. Use SPACE to select and ENTER to confirm." 20 78 14 \
    "ADD_DIVIX_USER" "Add Divix User" OFF \
    "CREATE_DIVTOOLS_FOLDER" "Create /opt/divtools Folder" OFF \
    "INSTALL_ENTWARE" "Install Entware (QNAP only)" OFF \
    "INSTALL_PACKAGES" "Install Software Packages" OFF \
    "INSTALL_DOCKER" "Install Docker" OFF \
    "INSTALL_COCKPIT" "Install Cockpit and Modules" OFF \
    "CONFIGURE_SYNCTHING_BOOT" "Configure Syncthing to Run on Boot" OFF \
    "UPDATE_GIT_CONFIG" "Update Git Config" OFF \
    "UPDATE_PROFILE" "Update /etc/profile" OFF \
    "UPDATE_AUTH_KEYS" "Update authorized_keys" OFF \
    "UPDATE_QNAP_CONTAINER" "$container_station_text" $container_station_option \
    "CLONE_DIVTOOLS_REPO" "Clone divtools Repository into /opt/divtools" OFF 3>&1 1>&2 2>&3)

    if [[ $? != 0 ]]; then
        echo "Task selection cancelled."
        exit 1
    fi

    # Return selected items as a list
    echo "$selections"
}


# Run the selected tasks
function run_selected_tasks() {
    for selection in $selections; do
        case $selection in
            \"ADD_DIVIX_USER\") add_divix_user;;
            \"CREATE_DIVTOOLS_FOLDER\") create_divtools_folder;;
            \"INSTALL_ENTWARE\") install_entware;;
            \"INSTALL_PACKAGES\") install_packages;;
            \"INSTALL_DOCKER\") install_docker;;
            \"INSTALL_COCKPIT\") install_cockpit;;
            \"CONFIGURE_SYNCTHING_BOOT\") configure_syncthing_boot;;
            \"UPDATE_GIT_CONFIG\") update_git_config;;
            \"UPDATE_PROFILE\") update_profile;;
            \"UPDATE_AUTH_KEYS\") update_authorized_keys;;
            \"UPDATE_QNAP_CONTAINER\") update_qnap_container_station;;
            \"CLONE_DIVTOOLS_REPO\") clone_divtools_repo;;
        esac
    done
}




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

