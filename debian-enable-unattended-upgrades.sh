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


# ---------------------
# Configuration section
# ---------------------

# Path to configuration file which enables unattended upgrades.
AUTOUPGRADE_CONFIG_FILE=/etc/apt/apt.conf.d/20auto-upgrades

# Path to configuration file for custom parameters.
CUSTOM_CONFIG_FILE=/etc/apt/apt.conf.d/50unattended-upgrades-custom

# Community repositories to enable upgrading packages from.
COMMUNITY_REPOSITORIES_ENABLED="packages.sury.org deb.nodesource.com dl.yarnpkg.com download.docker.com packages.icinga.com packages.icinga.org download.proxmox.com enterprise.proxmox.com"
COMMUNITY_REPOSITORIES_DISABLED="packages.grafana.com repo.mosquitto.org repos.influxdata.com repo.mongodb.org packages.gitlab.com download.jitsi.org packages.x2go.org rspamd.com"


# ---------------
# Program section
# ---------------

function setup_unattended {

  # Install prerequisites.
  apt-get update
  apt-get --yes install systemd unattended-upgrades # apt-listchanges

  # Activate unattended upgrades.
  echo unattended-upgrades unattended-upgrades/enable_auto_updates boolean true | debconf-set-selections
  dpkg-reconfigure -f noninteractive unattended-upgrades

  add_comment "Debian Unattended Upgrade configuration from https://github.com/cicerops/autopilot"

}


function enable_unattended {

  # Enable automatic package upgrades.
  apt-config dump | grep "APT::Periodic::Unattended-Upgrade" > /dev/null 2>&1
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


function enable_unattended_repositories {

  # Enable non-vanilla baseline repositories.
  if [[ $(command -v lsb_release) && $(lsb_release --id --short) == "Raspbian" ]]; then
    activate_repository "site=raspbian.raspberrypi.org"
    activate_repository "archive=stable"
  fi

  add_comment "Enable urgent non-security updates and updates from backports."
  activate_repository 'codename=${distro_codename}-updates'
  activate_repository 'archive=${distro_codename}-backports'

  add_comment "Updates from community repositories (enabled)."
  for repository in ${COMMUNITY_REPOSITORIES_ENABLED}; do
    activate_repository "site=${repository}"
  done
  add_comment "Updates from community repositories (disabled)."
  for repository in ${COMMUNITY_REPOSITORIES_DISABLED}; do
    activate_repository "site=${repository}" true
  done

}

function configure_email {
  # Configure email address.
  if [ ! -z "${UNATTENDED_EMAIL_ADDRESS}" ]; then
    if infile "${UNATTENDED_EMAIL_ADDRESS}" ${CUSTOM_CONFIG_FILE}; then
      return
    fi
    add_comment "Email address for notifying on any actions."
    printf "Unattended-Upgrade::Mail \"${UNATTENDED_EMAIL_ADDRESS}\";\n" >> "${CUSTOM_CONFIG_FILE}"
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

  if infile "Unattended-Upgrade::Automatic-Reboot" ${CUSTOM_CONFIG_FILE}; then
    return
  fi
  cat << EOF >> "${CUSTOM_CONFIG_FILE}"

# Automatically reboot *WITHOUT CONFIRMATION* if the file "/var/run/reboot-required" is found after the upgrade.
Unattended-Upgrade::Automatic-Reboot "${UNATTENDED_REBOOT_ENABLE:-false}";

# If automatic reboot is enabled and needed, reboot at the specific time.
Unattended-Upgrade::Automatic-Reboot-Time "${UNATTENDED_REBOOT_TIME:-04:00}";

# Do not automatically reboot when there are users currently logged in.
Unattended-Upgrade::Automatic-Reboot-WithUsers "false";

EOF
}


function configure_cleanup {

  if infile "Unattended-Upgrade::Remove-Unused" ${CUSTOM_CONFIG_FILE}; then
    return
  fi

  cat << EOF >> "${CUSTOM_CONFIG_FILE}"

# Remove unused packages from system, using "apt autoremove".
# Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
# Unattended-Upgrade::Remove-Unused-Dependencies "true";
# Unattended-Upgrade::Remove-New-Unused-Dependencies "true";

EOF
}


function oneshot {
  # Manually run unattended upgrades once.
  apt-get update && unattended-upgrade --dry-run --debug
}


# -----------------
# Utility functions
# -----------------

function infile {
  line="$1"
  file="$2"
  if ! grep "${line}" ${file} > /dev/null 2>&1; then
    return 1
  fi
}

function add_comment {
  comment="$1"
  add_line "# ${comment}" true
}

function add_line {
  line="$1"
  newline="$2"
  if infile "${line}" ${CUSTOM_CONFIG_FILE}; then
    return
  fi

  if [ ! -z ${newline} ]; then
    line="\n${line}"
  fi
  printf "${line}\n" >> "${CUSTOM_CONFIG_FILE}"
}

function activate_repository {
  repository="$1"
  disabled="$2"

  line="Unattended-Upgrade::Origins-Pattern:: \"${repository}\";"
  if infile "${line}" ${CUSTOM_CONFIG_FILE}; then
    return
  fi
  if [ ! -z ${disabled} ]; then
    line="# ${line}"
  fi

  add_line "${line}"
}



# ------------------
# Program entrypoint
# ------------------

function main {
  setup_unattended
  enable_unattended
  configure_email
  configure_reboot
  configure_cleanup
  enable_unattended_repositories
  configure_schedule
  oneshot
}

function ready {
  hostname=$(hostname -f)
  echo
  echo "The system on \"${hostname}\" has been configured, the output above"
  echo "is from \`unattended-upgrade --dry-run --debug\`."
  echo
  echo "Please run \`ssh root@${hostname} unattended-upgrade --verbose\` in order to apply the changes."
  echo

}

main
ready
