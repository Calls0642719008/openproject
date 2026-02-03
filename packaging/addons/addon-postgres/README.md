# addon-postgres

PostgreSQL addon for pkgr.

If autoinstall mode is selected, it will attempt to setup a PostgreSQL v17 cluster, using the packages from https://www.postgresql.org/download/linux/.

Supported distributions:

- SLES12
- Enterprise Linux 7, Enterprise Linux 7
- Ubuntu 14.04, 16.04, 18.04, 20.04
- Debian 7, 8, 9, 10

## Development

    sudo apt-get update -qq && sudo apt-get install dialog -y

    export APP_NAME="testapp"
    export APP_SAFE_NAME="testapp"
    export INSTALLER_DIR="/path/to/pkgr-installer-dir"
    sudo useradd "$APP_NAME"
    sudo mkdir -p /etc/testapp/conf.d

    sudo -E INSTALLER_DEBUG=no WIZ_RECONFIGURE=no DATABASE=/tmp/test1 ./bin/configure
    sudo -E INSTALLER_DEBUG=no WIZ_RECONFIGURE=no DATABASE=/tmp/test1 ./bin/preinstall
