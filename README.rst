##################
cicerops autopilot
##################


*****
About
*****

Just some humble programs to assist in systems maintenance.


*****
Usage
*****

Setup::

    # Prepare.
    apt-get update && apt-get install --yes bash curl

    # Initial system configuration.
    bash <(curl -s https://raw.githubusercontent.com/cicerops/autopilot/main/debian-bootstrap.sh)

    # Enable unattended package updates.
    bash <(curl -s https://raw.githubusercontent.com/cicerops/autopilot/main/debian-enable-unattended-upgrades.sh)


*******
Testing
*******
::

    docker run -it --rm --volume $PWD:/src debian:bullseye bash
    bash /src/debian-bootstrap.sh
    bash /src/debian-enable-unattended-upgrades.sh
