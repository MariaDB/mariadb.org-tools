#!/usr/bin/env bash
# shellcheck disable=SC2154

set -e

# Buildbot minor upgrade test script
# this script can be called manually by providing the build URL as argument:
# ./script.sh "https://buildbot.mariadb.org/#/builders/171/builds/7351"

# load common functions
# shellcheck disable=SC1091
. ./bash_lib.sh

# function to be able to run the script manually (see bash_lib.sh)
manual_run_switch "$1"

set -x

upgrade_type_mode
upgrade_test_type

if [[ $arch == "ppc64le" ]]; then
  arch=ppc64el
elif [[ $arch == "x86" ]]; then
  arch=i386
fi

bb_log_info "Architecture, distribution and version based on VM name: $arch $dist_name $version_name"
bb_log_info "Test properties"
bb_log_info "  Systemd capability $systemdCapability"
bb_log_info "  Major version $major_version"
bb_log_info "  Previous major version $prev_major_version"

# This test can be performed in four modes:
# - 'server' -- only mariadb-server is installed (with whatever dependencies it pulls) and upgraded.
# - 'all'    -- all provided packages are installed and upgraded, except for Columnstore
# - 'deps'   -- only a limited set of main packages is installed and upgraded,
#               to make sure upgrade does not require new dependencies
# - 'columnstore' -- mariadb-server and mariadb-plugin-columnstore are installed
bb_log_info "Current test mode: $test_mode"

# Environment
dpkg -l | grep -iE 'maria|mysql|galera' || true
lsb_release -a
uname -a
df -kT

# Check whether a previous version exists
if ! wget "https://deb.mariadb.org/$prev_major_version/$dist_name/dists/$version_name/main/binary-$arch/Packages"; then
  bb_log_warn "could not find the 'Packages' file for a previous version in MariaDB repo, skipping the test"
  exit
fi

# Define the list of packages to install/upgrade
case $test_mode in
  all)
    if grep -qi columnstore Packages; then
      bb_log_warn "due to MCOL-4120 (Columnstore leaves the server shut down) and other bugs Columnstore upgrade is tested separately"
    fi
    package_list=$(grep -B 1 'Source: mariadb-' Packages | grep 'Package:' | grep -vE 'galera|spider|columnstore' | awk '{print $2}' | sort | uniq | xargs)
    if grep -qi spider Packages; then
      bb_log_warn "due to MDEV-14622 Spider will be installed separately after the server"
      spider_package_list=$(grep -B 1 'Source: mariadb-' Packages | grep 'Package:' | grep 'spider' | awk '{print $2}' | sort | uniq | xargs)
    fi
    if grep -si tokudb Packages; then
      # For the sake of installing TokuDB, disable hugepages
      sudo sh -c "echo never > /sys/kernel/mm/transparent_hugepage/enabled" || true
    fi
    ;;
  deps)
    package_list="mariadb-server mariadb-client mariadb-common mariadb-test mysql-common libmysqlclient18"
    ;;
  server)
    package_list=mariadb-server
    ;;
  columnstore)
    if ! grep columnstore Packages >/dev/null; then
      bb_log_warn "Columnstore was not found in packages, the test will not be run"
      exit
    elif [[ $version_name == "sid" ]]; then
      bb_log_warn "Columnstore isn't necessarily built on Sid, the test will be skipped"
      exit
    fi
    package_list="mariadb-server "$(grep -B 1 'Source: mariadb-' Packages | grep 'Package:' | grep 'columnstore' | awk '{print $2}' | sort | uniq | xargs)
    ;;
  *)
    bb_log_err "unknown test mode: $test_mode"
    exit 1
    ;;
esac
bb_log_info "Package_list: $package_list"

# Prepare apt repository configuration for installation of the previous major
# version
deb_setup_mariadb_mirror "$prev_major_version"

# We need to pin directory to ensure that installation happens from MariaDB
# repo rather than from the default distro repo
sudo sh -c "echo 'Package: *' > /etc/apt/preferences.d/release"
sudo sh -c "echo 'Pin: origin deb.mariadb.org' >> /etc/apt/preferences.d/release"
sudo sh -c "echo 'Pin-Priority: 1000' >> /etc/apt/preferences.d/release"

# apt get update may be running in the background (Ubuntu start).
apt_get_update

# //TEMP this is called from bash_lib, not good.
get_columnstore_logs() {
  if [[ $test_mode == "columnstore" ]]; then
    bb_log_info "storing Columnstore logs in columnstore_logs"
    set +ex
    # It is done in such a weird way, because Columnstore currently makes its logs hard to read
    # //TEMP this is fragile and weird (test that /var/log/mariadb/columnstore exist)
    for f in $(sudo ls /var/log/mariadb/columnstore | xargs); do
      f=/var/log/mariadb/columnstore/$f
      echo "----------- $f -----------" >>/home/buildbot/columnstore_logs
      sudo cat "$f" 1>>/home/buildbot/columnstore_logs 2>&1
    done
    for f in /tmp/columnstore_tmp_files/*; do
      echo "----------- $f -----------" >>/home/buildbot/columnstore_logs
      sudo cat "$f" | sudo tee -a /home/buildbot/columnstore_logs 2>&1
    done
  fi
}

# Install previous release
# Debian installation/upgrade/startup always attempts to execute mysql_upgrade, and
# also run mysqlcheck and such. Due to MDEV-14622, they are subject to race condition,
# and can be executed later or even omitted.
# We will wait till they finish, to avoid any clashes with SQL we are going to execute
wait_for_mariadb_upgrade

if ! sudo sh -c "DEBIAN_FRONTEND=noninteractive MYSQLD_STARTUP_TIMEOUT=180 apt-get -o Dpkg::Options::=--force-confnew install --allow-unauthenticated -y $package_list"; then
  bb_log_err "Installation of a previous release failed, see the output above"
  exit 1
fi

wait_for_mariadb_upgrade

if [[ -n $spider_package_list ]]; then
  if ! sudo sh -c "DEBIAN_FRONTEND=noninteractive MYSQLD_STARTUP_TIMEOUT=180 apt-get -o Dpkg::Options::=--force-confnew install --allow-unauthenticated -y $spider_package_list"; then
    bb_log_err "Installation of Spider from the previous release failed, see the output above"
    exit 1
  fi
  wait_for_mariadb_upgrade
fi

# To avoid confusing errors in further logic, do an explicit check
# whether the service is up and running
if [[ $systemdCapability == "yes" ]]; then
  if ! sudo systemctl status mariadb --no-pager; then
    sudo journalctl -xe --no-pager
    get_columnstore_logs
    bb_log_err "mariadb service didn't start properly after installation"
    exit 1
  fi
fi

if [[ $test_mode == "all" ]] && [[ $branch == *"10."[5-9]* ]]; then
  bb_log_warn "Due to MDEV-23061, an extra server restart is needed"
  control_mariadb_server restart
fi

# Check that the server is functioning and create some structures
check_mariadb_server_and_create_structures

# Store information about server version and available plugins/engines before upgrade
if [[ $test_mode == "all" ]]; then
  # Due to MDEV-14560, we have to restart the server to get the full list of engines
  # MDEV-14560 is fixed in 10.2
  if ((${prev_major_version/10./} > 2)); then
    control_mariadb_server restart
  fi
fi

store_mariadb_server_info old

# //TEMP todo, see below
# # Store dependency information for old binaries/libraries:
# # - names starting with "mysql*" in the directory where mysqld is located;
# # - names starting with "mysql*" in the directory where mysql is located;
# # - everything in the plugin directories installed by any MariaDB packages
# set +x
# for i in $(sudo which mysqld | sed -e 's/mysqld$/mysql\*/') $(which mysql | sed -e 's/mysql$/mysql\*/') $(dpkg-query -L $(dpkg -l | grep mariadb | awk '{print $2}' | xargs) | grep -v 'mysql-test' | grep -v '/debug/' | grep '/plugin/' | sed -e 's/[^\/]*$/\*/' | sort | uniq | xargs); do
#   echo "=== $i"
#   ldd "$i" | sort | sed 's/(.*)//'
# done >/buildbot/ldd.old
# set -x

# # setup repository
# sudo sh -c "echo 'deb [trusted=yes] https://deb.mariadb.org/$master_branch/$dist_name $version_name main' >/etc/apt/sources.list.d/galera-test-repo.list"
# # Update galera-test-repo.list to point at either the galera-3 or galera-4 test repo
# //TEMP
# case "$branch" in
#   *10.[1-3]*)
#     sudo sed -i 's/repo/repo3/' /etc/apt/sources.list.d/galera-test-repo.list
#     ;;
#   *10.[4-9]*)
#     sudo sed -i 's/repo/repo4/' /etc/apt/sources.list.d/galera-test-repo.list
#     ;;
# esac

if [[ $test_mode == "deps" ]]; then
  # For the dependency check, only keep the local repo //TEMP what does this do???
  sudo sh -c "grep -iE 'deb .*file|deb-src .*file' /etc/apt/sources.list.backup >/etc/apt/sources.list"
  sudo rm -f /etc/apt/sources.list.d/*
else
  sudo cp /etc/apt/sources.list.backup /etc/apt/sources.list
  sudo rm /etc/apt/sources.list.d/mariadb.list
fi
sudo rm /etc/apt/preferences.d/release

# We also need official mirror for dependencies not available in BB artifacts
# (Galera)
deb_setup_mariadb_mirror "$master_branch"
deb_setup_bb_artifacts_mirror
apt_get_update

# Install the new packages
if ! sudo sh -c "DEBIAN_FRONTEND=noninteractive MYSQLD_STARTUP_TIMEOUT=180 apt-get -o Dpkg::Options::=--force-confnew install --allow-unauthenticated -y $package_list"; then
  bb_log_err "installation of the new packages failed, see the output above"
  exit 1
fi
wait_for_mariadb_upgrade

if [[ -n $spider_package_list ]]; then
  if ! sudo sh -c "DEBIAN_FRONTEND=noninteractive MYSQLD_STARTUP_TIMEOUT=180 apt-get -o Dpkg::Options::=--force-confnew install --allow-unauthenticated -y $spider_package_list"; then
    bb_log_err "Installation of the new Spider packages failed, see the output above"
    exit 1
  fi
  wait_for_mariadb_upgrade
fi
if [[ $test_mode == "columnstore" ]]; then
  bb_log_warn "Due to MCOL-4120 an extra server restart is needed"
  control_mariadb_server restart
fi

# Wait till mysql_upgrade, mysqlcheck and such are finished:
# Again, wait till mysql_upgrade is finished, to avoid clashes; and for
# non-stable versions, it might be necessary, so run it again just in case it
# was omitted
wait_for_mariadb_upgrade

# run mysql_upgrade for non GA branches
if [[ $major_version == "$development_branch" ]]; then
  sudo -u mysql mysql_upgrade -uroot -prootpass
fi

# Make sure that the new server is running
if mysql -uroot -prootpass -e "select @@version" | grep "$(cat /tmp/version.old)"; then
  bb_log_err "the server was not upgraded or was not restarted after upgrade"
  exit 1
fi

# Check that no old packages have left after upgrade:
# The check is only performed for all-package-upgrade, because for selective
# ones some implicitly installed packages might not be upgraded
if [[ $test_mode == "all" ]]; then
  if dpkg -l | grep -iE 'mysql|maria' | grep "$(cat /tmp/version.old)"; then
    bb_log_err "old packages have been found after upgrade"
    exit 1
  fi
fi

# Check that the server is functioning and previously created structures are
# available
check_mariadb_server_and_verify_structures

# Store information about server version and available plugins/engines after
# upgrade
store_mariadb_server_info new

# //TEMP what needs to be done here?
# # Dependency information for new binaries/libraries
# set +x
# for i in $(sudo which mysqld | sed -e 's/mysqld$/mysql\*/') $(which mysql | sed -e 's/mysql$/mysql\*/') $(dpkg-query -L $(dpkg -l | grep mariadb | awk '{print $2}' | xargs) | grep -v 'mysql-test' | grep -v '/debug/' | grep '/plugin/' | sed -e 's/[^\/]*$/\*/' | sort | uniq | xargs); do
#   echo "=== $i"
#   ldd $i | sort | sed 's/(.*)//'
# done >/home/buildbot/ldd.new
# set -x
# case "$systemdCapability" in
#   yes)
#     ls -l /lib/systemd/system/mariadb.service
#     ls -l /etc/systemd/system/mariadb.service.d/migrated-from-my.cnf-settings.conf
#     ls -l /etc/init.d/mysql || true
#     systemctl --no-pager status mariadb.service
#     systemctl --no-pager status mariadb
#     systemctl --no-pager status mysql
#     systemctl --no-pager status mysqld
#     systemctl --no-pager is-enabled mariadb
#     ;;
#   no)
#     bb_log_info "Steps related to systemd will be skipped"
#     ;;
#   *)
#     bb_log_err "It should never happen, check your configuration (systemdCapability property is not set or is set to a wrong value)"
#     exit 1
#     ;;
# esac
# set +e
# # This output is for informational purposes
# diff -u /tmp/engines.old /tmp/engines.new
# diff -u /tmp/plugins.old /tmp/plugins.new
# case "$branch" in
#   "$development_branch")
#     bb_log_info "Until $development_branch is GA, the list of plugins/engines might be unstable, skipping the check"
#     ;;
#   *)
#     # Only fail if there are any disappeared/changed engines or plugins
#     disappeared_or_changed=$(comm -23 /tmp/engines.old /tmp/engines.new | wc -l)
#     if ((disappeared_or_changed != 0)); then
#       bb_log_err "the lists of engines in the old and new installations differ"
#       exit 1
#     fi
#     if [[ $test_type == "minor" ]]; then
#       disappeared_or_changed=$(comm -23 /tmp/plugins.old /tmp/plugins.new | wc -l)
#       if ((disappeared_or_changed != 0)); then
#         bb_log_err "the lists of plugins in the old and new installations differ"
#         exit 1
#       fi
#     fi
#     set -o pipefail
#     if [[ $test_mode == "all" ]]; then
#       set -o pipefail
#       if wget -q --timeout=20 --no-check-certificate "https://raw.githubusercontent.com/MariaDB/mariadb.org-tools/master/buildbot/baselines/ldd.${major_version}.${version_name}.${arch}" -O /tmp/ldd.baseline; then
#         ldd_baseline=/tmp/ldd.baseline
#       else
#         ldd_baseline=/buildbot/ldd.old
#       fi
#       if ! diff -U1000 $ldd_baseline /home/buildbot/ldd.new | (grep -E '^[-+]|^ =' || true); then
#         bb_log_err "something has changed in the dependencies of binaries or libraries. See the diff above"
#         exit 1
#       fi
#     fi
#     set +o pipefail
#     ;;
# esac

check_upgraded_versions

bb_log_ok "all done"
