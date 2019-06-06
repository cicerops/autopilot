#!/bin/bash

# Get target email address from STDIN
STDIN=$(cat -)

# Install prerequisites
apt-get --yes install unattended-upgrades apt-listchanges

#EMAIL_ADDRESS=test@example.org

# Configure email address
EMAIL_ADDRESS=$STDIN
if [ ! -z ${EMAIL_ADDRESS} ]; then
  cat /etc/apt/apt.conf.d/50unattended-upgrades | grep ${EMAIL_ADDRESS}
  if [ $? -gt 0 ]; then
    printf "\nUnattended-Upgrade::Mail \"${EMAIL_ADDRESS}\";\n" >> /etc/apt/apt.conf.d/50unattended-upgrades
  fi
fi

# Activate unattended upgrades
echo unattended-upgrades unattended-upgrades/enable_auto_updates boolean true | debconf-set-selections
dpkg-reconfigure -f noninteractive unattended-upgrades

# Manully run unattended upgrades once
unattended-upgrade -d
