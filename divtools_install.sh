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
        fi
    fi
}


# Create divtools folder
function create_divtools_folder() {
    divix_home=$(getent passwd divix | cut -d: -f6)
    
    if [ ! -d /opt/divtools ]; then
        run_cmd mkdir -p /opt/divtools
        run_cmd chmod 775 /opt/divtools
    fi
    
    if [ -d "$divix_home" ]; then
        if [ ! -L "$divix_home/divtools" ]; then
            run_cmd ln -s /opt/divtools "$divix_home/divtools"
            run_cmd chown divix:divix "$divix_home/divtools"
        fi
    else
        echo "divix home directory not found!"
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
    packages=(sudo syncthing git git-http vim rclone python3 libssl-dev curl ca-certificates openssh-client)
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

# Update git config
function update_git_config() {
    run_cmd git config --global user.name "Andrew Fields"
    run_cmd git config --global user.email "andrew@avcorp.biz"
    run_cmd git config --global url."git@github.com:".insteadOf "https://github.com/"
}

# Update /etc/profile
function update_profile() {
    if grep -q "#DIVTOOLS-BEFORE" /etc/profile; then
        # If the DIVTOOLS block exists, replace the content between BEFORE and AFTER
        echo "Updating Divtools entry in /etc/profile."
        run_cmd sed -i '/#DIVTOOLS-BEFORE/,/#DIVTOOLS-AFTER/c\
#DIVTOOLS-BEFORE\n\
# Source divtools profile\n\
if [ -f /opt/divtools/common/.bash_profile ]; then\n\
    . /opt/divtools/common/.bash_profile\n\
fi\n\
#DIVTOOLS-AFTER' /etc/profile
    else
        # If the DIVTOOLS block doesn't exist, append it to the file
        echo "Adding Divtools entry to /etc/profile."
        run_cmd tee -a /etc/profile > /dev/null <<EOL

#DIVTOOLS-BEFORE
# Source divtools profile
if [ -f /opt/divtools/common/.bash_profile ]; then
    . /opt/divtools/common/.bash_profile
fi
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
    selections=$(whiptail --title "Select Tasks" --checklist \
    "Choose tasks to run. Use SPACE to select and ENTER to confirm." 20 78 10 \
    "1" "Add Divix User" OFF \
    "2" "Create divtools Folder" OFF \
    "3" "Install Entware (QNAP only)" OFF \
    "4" "Install Software Packages" OFF \
    "5" "Configure Syncthing to Run on Boot" OFF \
    "6" "Update Git Config" OFF \
    "7" "Update /etc/profile" OFF \
    "8" "Update authorized_keys" OFF 3>&1 1>&2 2>&3)

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
            \"1\") add_divix_user;;
            \"2\") create_divtools_folder;;
            \"3\") install_entware;;
            \"4\") install_packages;;
            \"5\") configure_syncthing_boot;;
            \"6\") update_git_config;;
            \"7\") update_profile;;
            \"8\") update_authorized_keys;;
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

