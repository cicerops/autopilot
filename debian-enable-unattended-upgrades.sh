#!/bin/bash
#
# About:
#
#   Wash & go setup and configuration program for Debian Unattended Upgrades.
#
# Configuration:
#
#   # Optionally configure email notifications.
#   export EMAIL_ADDRESS=test@example.org
#
# Usage:
#
#   bash <(curl -s https://gist.githubusercontent.com/amotl/5097e39b065ec495e42ec6982c99f930/raw/debian-enable-unattended-upgrades.sh)
#
# License:
#
#   GNU General Public License, version 3
#
# References:
#
#   - https://wiki.debian.org/UnattendedUpgrades
#   - https://askubuntu.com/questions/824718/ubuntu-16-04-unattended-upgrades-runs-at-random-times
#   - https://unix.stackexchange.com/questions/342663/how-is-unattended-upgrades-started-and-how-can-i-modify-its-schedule
#
set +ex

# File to place custom configuration parameters into.
AUTOUPGRADE_CONFIG_FILE=/etc/apt/apt.conf.d/20auto-upgrades
CUSTOM_CONFIG_FILE=/etc/apt/apt.conf.d/80custom


function setup_unattended {

  # Install prerequisites.
  apt-get update
  apt-get --yes install systemd unattended-upgrades # apt-listchanges

  # Activate unattended upgrades.
  echo unattended-upgrades unattended-upgrades/enable_auto_updates boolean true | debconf-set-selections
  dpkg-reconfigure -f noninteractive unattended-upgrades

}


function configure_email {
  # Configure email address.
  if [ ! -z "${EMAIL_ADDRESS}" ]; then
    apt-config dump | grep "${EMAIL_ADDRESS}"
    if [ $? -gt 0 ]; then
      printf "\n// Email address for notifying on any actions.\n" >> "${CUSTOM_CONFIG_FILE}"
      printf "Unattended-Upgrade::Mail \"${EMAIL_ADDRESS}\";\n" >> "${CUSTOM_CONFIG_FILE}"
    fi
  fi
}


function oneshot {
  # Manually run unattended upgrades once.
  apt-get update && unattended-upgrade -d
}


function main {
  setup_unattended
  configure_email
  oneshot
}

main
