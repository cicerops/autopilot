###############################
Tools for autoupdate procedures
###############################


Setup::

    bash <(curl -s https://gist.githubusercontent.com/amotl/5097e39b065ec495e42ec6982c99f930/raw/debian-enable-unattended-upgrades.sh)


Testing::

    docker run -it --rm --volume $PWD:/src debian:bullseye bash
    bash /src/debian-enable-unattended-upgrades.sh
