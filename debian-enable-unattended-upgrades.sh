#!/bin/bash

set +e

# Get target email address from STDIN
STDIN=$(cat -)

# File to place custom configuration parameters into
CUSTOM_CONFIG_FILE=/etc/apt/apt.conf.d/80custom

# Install prerequisites
apt-get --yes install unattended-upgrades apt-listchanges

#EMAIL_ADDRESS=test@example.org

# Configure email address
EMAIL_ADDRESS=$STDIN
if [ ! -z ${EMAIL_ADDRESS} ]; then
  cat ${CUSTOM_CONFIG_FILE} | grep ${EMAIL_ADDRESS}
  if [ $? -gt 0 ]; then
    printf "\nUnattended-Upgrade::Mail \"${EMAIL_ADDRESS}\";\n" >> ${CUSTOM_CONFIG_FILE}
  fi
fi

# Activate unattended upgrades
echo unattended-upgrades unattended-upgrades/enable_auto_updates boolean true | debconf-set-selections
dpkg-reconfigure -f noninteractive unattended-upgrades

# Manually run unattended upgrades once
apt-get update && unattended-upgrade -d
