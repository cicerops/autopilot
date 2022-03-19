#!/bin/bash
#
# About:
#
#   Setup and configuration program for Debian Unattended Upgrades.
#
# Configuration (optional):
#
#   # Configure update schedule. Default is `7,16:00`.
#   export UNATTENDED_PACKAGE_TIME=21:00
#
#   # Enable automatic reboots. Default is `false`.
#   export UNATTENDED_REBOOT_ENABLE=true
#
#   # Configure reboot time. Default is `04:00`.
#   export UNATTENDED_REBOOT_TIME=22:00
#
#   # Configure email notifications. Default is `no emails`.
#   export UNATTENDED_EMAIL_ADDRESS=test@example.org
#
# Usage:
#
#   apt-get update && apt-get install --yes bash curl
#   bash <(curl -s https://raw.githubusercontent.com/cicerops/autopilot/main/debian-enable-unattended-upgrades.sh)
#
# License:
#
#   GNU Affero General Public License, version 3
#
# References:
#
#   - https://wiki.debian.org/UnattendedUpgrades
#   - https://askubuntu.com/questions/824718/ubuntu-16-04-unattended-upgrades-runs-at-random-times
#   - https://unix.stackexchange.com/questions/342663/how-is-unattended-upgrades-started-and-how-can-i-modify-its-schedule
#
set +ex


# Path to configuration file which enables unattended upgrades.
AUTOUPGRADE_CONFIG_FILE=/etc/apt/apt.conf.d/20auto-upgrades

# Path to configuration file for custom parameters.
CUSTOM_CONFIG_FILE=/etc/apt/apt.conf.d/80custom


function setup_unattended {

  # Install prerequisites.
  apt-get update
  apt-get --yes install systemd unattended-upgrades # apt-listchanges

  # Activate unattended upgrades.
  echo unattended-upgrades unattended-upgrades/enable_auto_updates boolean true | debconf-set-selections
  dpkg-reconfigure -f noninteractive unattended-upgrades

}


function enable_unattended {

  # Enable automatic package upgrades.
  apt-config dump | grep "APT::Periodic::Unattended-Upgrade"
  if [ $? -gt 0 ]; then
    cat << EOF >> "${AUTOUPGRADE_CONFIG_FILE}"
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
  fi

  # Reconfigure the minimal interval between runs, expressed in days, to "not
  # limited". That means, always perform the requested action, regardless of the
  # time that has passed since the last time. With apt versions above 1.5
  # (Debian 10 buster) you can change the APT::Periodic values from "1" to "always".
  apt_version=$(dpkg-query -f='${Version}\n' --show apt)
  if $(dpkg --compare-versions "$apt_version" "lt" "1.5"); then
    return
  fi
  sed -i 's|APT::Periodic::Update-Package-Lists "1";|APT::Periodic::Update-Package-Lists "always";|g' "${AUTOUPGRADE_CONFIG_FILE}"
  sed -i 's|APT::Periodic::Unattended-Upgrade "1";|APT::Periodic::Unattended-Upgrade "always";|g' "${AUTOUPGRADE_CONFIG_FILE}"
  return

}


function configure_email {
  # Configure email address.
  if [ ! -z "${UNATTENDED_EMAIL_ADDRESS}" ]; then
    apt-config dump | grep "${UNATTENDED_EMAIL_ADDRESS}"
    if [ $? -gt 0 ]; then
      printf "\n// Email address for notifying on any actions.\n" >> "${CUSTOM_CONFIG_FILE}"
      printf "Unattended-Upgrade::Mail \"${UNATTENDED_EMAIL_ADDRESS}\";\n" >> "${CUSTOM_CONFIG_FILE}"
    fi
  fi
}


function configure_schedule {

  # Reconfigure unattended-upgrade schedule.

  mkdir -p /etc/systemd/system/apt-daily-upgrade.timer.d
  cat << EOF > /etc/systemd/system/apt-daily-upgrade.timer.d/override.conf
[Timer]
OnCalendar=
OnCalendar=*-*-* ${UNATTENDED_PACKAGE_TIME:-7,16:00}
RandomizedDelaySec=15m
EOF

  mkdir -p /etc/systemd/system/apt-daily-upgrade.service.d
  cat << EOF > /etc/systemd/system/apt-daily-upgrade.service.d/override.conf
[Unit]
After=

[Service]
ExecStart=
ExecStart=/usr/lib/apt/apt.systemd.daily
EOF

  # Turn off apt-daily.timer altogether
  systemctl stop apt-daily.timer
  systemctl disable apt-daily.timer

  # Reload systemd configuration.
  systemctl daemon-reload

  # Display timer schedule.
  # systemctl list-timers
}


function configure_reboot {
  apt-config dump | grep "Unattended-Upgrade::Automatic-Reboot"
  if [ $? -gt 0 ]; then
    cat << EOF >> "${CUSTOM_CONFIG_FILE}"

// Automatically reboot *WITHOUT CONFIRMATION* if the file `/var/run/reboot-required` is found after the upgrade.
Unattended-Upgrade::Automatic-Reboot "${UNATTENDED_REBOOT_ENABLE:-false}";

// If automatic reboot is enabled and needed, reboot at the specific time.
Unattended-Upgrade::Automatic-Reboot-Time "${UNATTENDED_REBOOT_TIME:-04:00}";

// When set to `true`, automatically reboot even if there are users currently logged in.
Unattended-Upgrade::Automatic-Reboot-WithUsers "false";
EOF
  fi
}


function oneshot {
  # Manually run unattended upgrades once.
  apt-get update && unattended-upgrade --debug
}


function main {
  setup_unattended
  enable_unattended
  configure_email
  configure_schedule
  configure_reboot
  oneshot
}


main
