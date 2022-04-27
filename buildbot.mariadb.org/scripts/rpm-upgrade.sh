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

package_version=${mariadb_version/mariadb-/}
distro=$version_name

if [[ $distro == "sles123" ]]; then
  distro="sles12"
fi

repo_dist_arch=$distro-$arch
bb_log_info "Architecture and distribution based on VM name: $repo_dist_arch"
bb_log_info "Test properties"
bb_log_info "  Systemd capability     $systemdCapability"
bb_log_info "  Test type              $test_type"
bb_log_info "  Test mode              $test_mode"
bb_log_info "  Major version          $major_version"
bb_log_info "  Previous major version $prev_major_version"

# This test can be performed in four modes:
# - 'server' -- only mariadb-server is installed (with whatever dependencies it pulls) and upgraded.
# - 'all'    -- all provided packages are installed and upgraded, except for Columnstore
# - 'deps'   -- only a limited set of main packages is installed and upgraded,
#               to make sure upgrade does not require new dependencies
# - 'columnstore' -- mariadb-server and mariadb-plugin-columnstore are installed
bb_log_info "Current test mode: $test_mode"

# Environment
set +e
rpm -qa | grep -iE 'maria|mysql|galera'
cat /etc/*release
uname -a
df -kT
set -e

# Check whether a previous version exists
if ! wget "https://yum.mariadb.org/$prev_major_version/$repo_dist_arch/repodata" -O repodata.list; then
  bb_log_warn "could not find the 'repodata' folder for a previous version in MariaDB repo, skipping the test"
  exit
fi

# Define the list of packages to install/upgrade
case $test_mode in
  all | deps | columnstore)
    primary_xml=$(grep 'primary.xml.gz' repodata.list | sed -e 's/.*href="\(.*-primary.xml\)\.gz\".*/\\1/')
    if ! wget "https://yum.mariadb.org/$prev_major_version/$repo_dist_arch/repodata/$primary_xml.gz"; then
      bb_log_err "Couldn't download primary.xml.gz from the repository"
      exit 1
    fi
    gunzip "$primary_xml.gz"
    if [[ $test_mode == "all" ]]; then
      if grep -qi columnstore "$primary_xml"; then
        bb_log_warn "due to MCOL-4120 and other issues, Columnstore upgrade will be tested separately"
      fi
      package_list=$(grep -A 1 '<package type="rpm"' "$primary_xml" | grep MariaDB | grep -viE 'galera|columnstore' | sed -e 's/<name>//' | sed -e 's/<\/name>//' | sort | uniq | xargs)
    elif [[ $test_mode == "deps" ]]; then
      package_list=$(grep -A 1 '<package type="rpm"' "$primary_xml" | grep -iE 'MariaDB-server|MariaDB-test|MariaDB-client|MariaDB-common|MariaDB-compat' | sed -e 's/<name>//' | sed -e 's/<\/name>//' | sort | uniq | xargs)
    elif [[ $test_mode == "columnstore" ]]; then
      if ! grep -q columnstore "$primary_xml"; then
        bb_log_warn "columnstore was not found in the released packages, the test will not be run"
        exit
      fi
      package_list="MariaDB-server MariaDB-columnstore-engine"
    fi

    if [[ $arch == ppc* ]]; then
      package_list=$(echo "$package_list" | xargs -n1 | sed -e 's/MariaDB-compat//gi' | xargs)
    fi
    ;;
  server)
    package_list="MariaDB-server MariaDB-client"
    ;;
  *)
    bb_log_err "unknown test mode: $test_mode"
    exit 1
    ;;
esac

bb_log_info "Package_list: $package_list"

# Prepare yum/zypper configuration for installation of the last release
if which zypper; then
  repo_location=/etc/zypp/repos.d
  install_command="zypper --no-gpg-checks install --from mariadb -y"
  cleanup_command="zypper clean --all"
  remove_command="zypper remove -y"
  # Since there is no reasonable "upgrade" command in zypper which would
  # pick up RPM files needed to upgrade existing packages, we have to use "install".
  # However, if we run "install *.rpm", it will install all packages, regardless
  # the test mode, and we will get a lot of differences in contents after upgrade
  # (more plugins, etc.). So, instead for each package that we are going to install,
  # we'll also find an RPM file which provides it, and will use its name in
  # in the "upgrade" (second install) command
  if [[ $test_mode == "all" ]]; then
    rm -f rpms/*columnstore*.rpm
    rpms_for_upgrade="rpms/*.rpm"
  else
    rpms_for_upgrade=""
    for p in $package_list; do
      for f in rpms/*.rpm; do
        if rpm -qp "$f" --provides | grep -i "^$p ="; then
          rpms_for_upgrade="$rpms_for_upgrade $f"
          break
        fi
      done
    done
  fi
  upgrade_command="zypper --no-gpg-checks install -y $rpms_for_upgrade"

# As of now (February 2018), RPM packages do not support major upgrade.
# To imitate it, we will remove previous packages and install new ones.
elif which yum; then
  repo_location=/etc/yum.repos.d
  install_command="yum -y --nogpgcheck install"
  cleanup_command="yum clean all"
  upgrade_command="yum -y --nogpgcheck upgrade rpms/*.rpm"
  if [[ $test_type == "major" ]]; then
    upgrade_command="yum -y --nogpgcheck install rpms/*.rpm"
  fi
  if yum autoremove 2>&1 | grep -q 'need to be root'; then
    remove_command="yum -y autoremove"
  else
    remove_command="yum -y remove"
  fi
else
  bb_log_err "could not find package manager"
  exit 1
fi

sudo sh -c "echo '[mariadb]
name=MariaDB
baseurl=https://yum.mariadb.org/$prev_major_version/$repo_dist_arch
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1' > $repo_location/MariaDB.repo"

# Add fix for MDEV-20673 to rhel8/centos8 repo
case $HOSTNAME in
  rhel8* | centos8*) sudo sh -c "echo 'module_hotfixes = 1' >> $repo_location/MariaDB.repo" ;;
esac

# Workaround for TODO-1479 (errors upon reading from SUSE repos):
# sudo rm -rf
# /etc/zypp/repos.d/SUSE_Linux_Enterprise_Server_12_SP3_x86_64:SLES12-SP3-Updates.repo
# /etc/zypp/repos.d/SUSE_Linux_Enterprise_Server_12_SP3_x86_64:SLES12-SP3-Pool.repo
sudo sh -c "$cleanup_command"

# Install previous release
if ! sudo sh -c "$install_command $package_list"; then
  bb_log_err "installation of a previous release failed, see the output above"
  exit 1
fi

# Start the server, check that it is working and create some structures
case $(expr "$prev_major_version" '<' "10.1")"$systemdCapability" in
  0yes)
    sudo systemctl start mariadb
    if [[ $distro != *"sles"* ]] && [[ $distro != *"suse"* ]]; then
      sudo systemctl enable mariadb
    else
      bb_log_warn "due to MDEV-23044 mariadb service won't be enabled in the test"
    fi
    sudo systemctl status mariadb --no-pager
    ;;
  *)
    sudo /etc/init.d/mysql start
    ;;
esac

# shellcheck disable=SC2181
if (($? != 0)); then
  bb_log_err "Server startup failed"
  sudo cat /var/log/messages | grep -iE 'mysqld|mariadb'
  sudo cat /var/lib/mysql/*.err
  exit 1
fi

check_mariadb_server_and_create_structures

# Store information about server version and available plugins/engines before
# upgrade
store_mariadb_server_info old

# If the tested branch has the same version as the public repository,
# upgrade won't work properly. For releasable branches, we will return an error
# urging to bump the version number. For other branches, we will abort the test
# with a warning (which nobody will read). This is done upon request from
# development, as temporary branches might not be rebased in a timely manner
[[ -f /tmp/version.old ]] && old_version=$(cat /tmp/version.old)
if [[ $package_version == "$old_version" ]]; then
  bb_log_err "server version $package_version has already been released. Bump the version number!"
  for b in $releasable_branches; do
    if [[ $b == "$branch" ]]; then
      exit 1
    fi
  done
  bb_log_warn "the test will be skipped, as upgrade will not work properly"
  exit
fi

# # Store dependency information for old binaries/libraries:
# # - names starting with "mysql*" in the directory where mysqld is located;
# # - names starting with "mysql*" in the directory where mysql is located;
# # - everything in the plugin directories installed by any MariaDB packages
# set +x
# for i in $(sudo which mysqld | sed -e 's/mysqld$/mysql\*/') $(which mysql | sed -e 's/mysql$/mysql\*/') $(rpm -ql $(rpm -qa | grep MariaDB | xargs) | grep -v 'mysql-test' | grep -v '/debug/' | grep '/plugin/' | sed -e 's/[^\/]*$/\*/' | sort | uniq | xargs); do
#   echo "=== $i"
#   ldd $i | sort | sed 's/(.*)//'
# done >/home/buildbot/ldd.old
# set -x

# Prepare yum/zypper configuration for installation of the new packages
set -e
if [[ $test_type == "major" ]]; then
  bb_log_info "remove old packages for major upgrade"
  packages_to_remove=$(rpm -qa | grep 'MariaDB-' | awk -F'-' '{print $1"-"$2}' | xargs)
  sudo sh -c "$remove_command $packages_to_remove"
  rpm -qa | grep -iE 'maria|mysql' || true
fi
if [[ $test_mode == "deps" ]]; then
  sudo mv $repo_location/MariaDB.repo /tmp
  sudo rm -rf $repo_location/*
  sudo mv /tmp/MariaDB.repo $repo_location/
  sudo sh -c "$cleanup_command"
fi

# Install the new packages:
# Between 10.3 and 10.4(.2), required galera version changed from galera(-3) to galera-4.
# It means that there will be no galera-4 in the "old" repo, and it's not among the local RPMs.
# So, we need to add a repo for it
# //TEMP this needs to be fixed
# if [[ $test_type == "major" ]] && ((${major_version/10./} >= 3)) && ((${prev_major_version/10./} <= 4)); then
#   sudo sh -c "echo '[galera]
# name=Galera
# baseurl=https://yum.mariadb.org/galera/repo4/rpm/$repo_dist_arch
# gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
# gpgcheck=1' > $repo_location/galera.repo"
# fi
sudo sh -c "$upgrade_command"
set +e

# Check that no old packages have left after upgrade
# The check is only performed for all-package-upgrade, because
# for selective ones some implicitly installed packages might not be upgraded
if [[ $test_mode == "all" ]]; then
  if [[ $is_main_tree == "yes" ]]; then
    rpm -qa | grep -iE 'mysql|maria' | grep "$(cat /tmp/version.old)"
  else
    rpm -qa | grep -iE 'mysql|maria' | grep "$(cat /tmp/version.old)" | grep -v debuginfo
  fi
  # shellcheck disable=SC2181
  if (($? == 0)); then
    bb_log_err "old packages have been found after upgrade"
    exit 1
  fi
fi

# Optionally (re)start the server
set -e
if [[ $test_type == "major" ]]; then
  control_mariadb_server restart
fi

# Make sure that the new server is running
if mysql -uroot -prootpass -e "select @@version" | grep "$old_version"; then
  bb_log_err "the server was not upgraded or was not restarted after upgrade"
  exit 1
fi

# Run mysql_upgrade for non-GA branches (minor upgrades in GA branches shouldn't need it)
if [[ $major_version == "$development_branch" ]] || [[ $test_type == "major" ]]; then
  sudo -u mysql mysql_upgrade -uroot -prootpass
fi
set +e

# Check that the server is functioning and previously created structures are available
check_mariadb_server_and_verify_structures

# Store information about server version and available plugins/engines after upgrade
store_mariadb_server_info new

# # Dependency information for new binaries/libraries
# set +x
# for i in $(sudo which mysqld | sed -e 's/mysqld$/mysql\*/') $(which mysql | sed -e 's/mysql$/mysql\*/') $(rpm -ql $(rpm -qa | grep MariaDB | xargs) | grep -v 'mysql-test' | grep -v '/debug/' | grep '/plugin/' | sed -e 's/[^\/]*$/\*/' | sort | uniq | xargs); do
#   echo "=== $i"
#   ldd "$i" | sort | sed 's/(.*)//'
# done >/home/buildbot/ldd.new
# set -x
# case "$systemdCapability" in
#   yes)
#     ls -l /usr/lib/systemd/system/mariadb.service
#     ls -l /etc/systemd/system/mariadb.service.d/migrated-from-my.cnf-settings.conf
#     ls -l /etc/init.d/mysql || true
#     systemctl status mariadb.service --no-pager
#     systemctl status mariadb --no-pager
#     # Not done for SUSE due to MDEV-23044
#     if [[ "$distro" != *"sles"* ]] && [[ "$distro" != *"suse"* ]]; then
#       # Major upgrade for RPMs is remove / install, so previous configuration
#       # could well be lost
#       if [[ "$test_type" == "major" ]]; then
#         sudo systemctl enable mariadb
#       fi
#       systemctl is-enabled mariadb
#       systemctl status mysql --no-pager
#       systemctl status mysqld --no-pager
#     fi
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

# # Until $development_branch is GA, the list of plugins/engines might be unstable, skipping the check
# # For major upgrade, no point to do the check at all
# if [[ $major_version != "$development_branch" ]] && [[ $test_type != "major" ]]; then
#   # This output is for informational purposes
#   diff -u /tmp/engines.old /tmp/engines.new
#   diff -u /tmp/plugins.old /tmp/plugins.new
#   # Only fail if there are any disappeared/changed engines or plugins
#   disappeared_or_changed=$(comm -23 /tmp/engines.old /tmp/engines.new | wc -l)
#   if ((disappeared_or_changed != 0)); then
#     bb_log_err "the lists of engines in the old and new installations differ"
#     exit 1
#   fi
#   disappeared_or_changed=$(comm -23 /tmp/plugins.old /tmp/plugins.new | wc -l)
#   if ((disappeared_or_changed != 0)); then
#     bb_log_err "the lists of available plugins in the old and new installations differ"
#     exit 1
#   fi
#   if [[ $test_mode == "all" ]]; then
#     set -o pipefail
#     if wget -q --timeout=20 --no-check-certificate "https://raw.githubusercontent.com/MariaDB/mariadb.org-tools/master/buildbot/baselines/ldd.${major_version}.${distro}.${arch}" -O /tmp/ldd.baseline; then
#       ldd_baseline=/tmp/ldd.baseline
#     else
#       ldd_baseline=/home/buildbot/ldd.old
#     fi
#     if ! diff -U1000 $ldd_baseline /home/buildbot/ldd.new | (grep -E '^[-+]|^ =' || true); then
#       bb_log_err "something has changed in the dependencies of binaries or libraries. See the diff above"
#       exit 1
#     fi
#   fi
#   set +o pipefail
# fi

check_upgraded_versions

bb_log_ok "all done"
