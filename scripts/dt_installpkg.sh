#!/bin/sh

# I need to modify this script so I can just run it and have it use
# whiptail to provide a menu where I can select what to install.
# For now, I will just record the installation steps

# Install starship
# This install to /usr/local/bin. For QNAP we then want to COPY it to /opt/bin/starship
sudo curl -sS https://starship.rs/install.sh | sh
sudo cp /usr/local/bin/starship /opt/bin/starship


# Install yq
sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq
sudo chmod +x /usr/local/bin/yq
