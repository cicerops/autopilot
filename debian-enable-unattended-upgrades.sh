#!/bin/bash

STDIN=$(cat -)

apt-get --yes install unattended-upgrades apt-listchanges

#EMAIL_ADDRESS=test@example.org
EMAIL_ADDRESS=$STDIN
if [ ! -z ${EMAIL_ADDRESS} ]; then
printf "\nUnattended-Upgrade::Mail \"${EMAIL_ADDRESS}\";\n" >> /etc/apt/apt.conf.d/50unattended-upgrades
fi

echo unattended-upgrades unattended-upgrades/enable_auto_updates boolean true | debconf-set-selections
dpkg-reconfigure -f noninteractive unattended-upgrades
