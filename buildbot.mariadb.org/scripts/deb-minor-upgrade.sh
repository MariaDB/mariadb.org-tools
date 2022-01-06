#!/bin/bash
set -x

case "$branch" in
*galera*)
  if [[ "$test_mode" == "all" ]] ; then
    echo "Upgrade warning: the test in 'all' mode is not executed for galera branches"
    exit
  fi
  ;;
$development_branch)
  if [[ "$test_mode" != "server" ]] ; then
    echo "Upgrade warning: For non-stable branches the test is only run in 'test' mode"
    exit
  fi
  ;;
esac

if [[ "$arch" == "ppc64le" ]] ; then
  arch=ppc64el
elif [[ "$arch" == "x86" ]] ; then
  arch=i386
fi

prev_major_version=$major_version
# For now we rely on major_version being 10.1 or higher, can add a check later
if [[ "$test_type" == "major" ]] ; then
    minor_version_num=`echo $major_version | sed -e 's/10\.\([0-9]*\)/\\1/'`
    ((prev_minor_version_num = minor_version_num - 1))
    prev_major_version=10.$prev_minor_version_num
fi


echo "Architecture, distribution and version based on VM name: $arch $dist_name $version_name"
echo "Test properties"
echo "  Systemd capability $systemdCapability"
echo "  Major version $major_version"
echo "  Previous major version $prev_major_version"
#===============
# This test can be performed in four modes:
# - 'server' -- only mariadb-server is installed (with whatever dependencies it pulls) and upgraded.
# - 'all'    -- all provided packages are installed and upgraded, except for Columnstore
# - 'deps'   -- only a limited set of main packages is installed and upgraded,
#               to make sure upgrade does not require new dependencies
# - 'columnstore' -- mariadb-server and mariadb-plugin-columnstore are installed
#===============
echo "Current test mode: $test_mode"
#============
# Environment
#============
dpkg -l | grep -iE 'maria|mysql|galera'
lsb_release -a
uname -a
df -kT
#========================================
# Check whether a previous version exists
#========================================
if ! wget https://ftp.osuosl.org/mariadb/repo/$prev_major_version/$dist_name/dists/$version_name/main/binary-$arch/Packages
then
  echo "Upgrade warning: could not find the 'Packages' file for a previous version in MariaDB repo, skipping the test"
  exit 1
fi
#===============================================
# Define the list of packages to install/upgrade
#===============================================
case $test_mode in
all)
  if grep -i columnstore Packages > /dev/null ; then
    echo "Upgrade warning: Due to MCOL-4120 (Columnstore leaves the server shut down) and other bugs Columnstore upgrade is tested separately"
  fi
  package_list=`grep -B 1 'Source: mariadb-' Packages | grep 'Package:' | grep -vE 'galera|spider|columnstore' | awk '{print $2}' | sort | uniq | xargs`
  if grep -i spider Packages > /dev/null ; then
    echo "Upgrade warning: Due to MDEV-14622 Spider will be installed separately after the server"
    spider_package_list=`grep -B 1 'Source: mariadb-' Packages | grep 'Package:' | grep 'spider' | awk '{print $2}' | sort | uniq | xargs`
  fi
  if grep -i tokudb Packages > /dev/null ; then
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
  if ! grep columnstore Packages > /dev/null ; then
    echo "Upgrade warning: Columnstore was not found in packages, the test will not be run"
    exit
  fi
  package_list="mariadb-server "`grep -B 1 'Source: mariadb-' Packages | grep 'Package:' | grep 'columnstore' | awk '{print $2}' | sort | uniq | xargs`
  ;;
*)
  echo "ERROR: unknown test mode: $test_mode"
  exit 1
esac
echo "Package_list: $package_list"
#======================================================================
# Prepare apt source configuration for installation of the last release
#======================================================================
sudo sh -c "echo 'deb [trusted=yes] http://mirror.netinch.com/pub/mariadb/repo/$prev_major_version/$dist_name $version_name main' > /etc/apt/sources.list.d/mariadb_upgrade.list"
# We need to pin directory to ensure that installation happens from MariaDB repo
# rather than from the default distro repo
sudo sh -c "echo 'Package: *' > /etc/apt/preferences.d/release"
sudo sh -c "echo 'Pin: origin mirror.netinch.com' >> /etc/apt/preferences.d/release"
sudo sh -c "echo 'Pin-Priority: 1000' >> /etc/apt/preferences.d/release"
sudo cp /etc/apt/sources.list /etc/apt/sources.list.backup
sudo sh -c 'grep -v "^deb .*file" /etc/apt/sources.list.backup | grep -v "^deb-src .*file" > /etc/apt/sources.list'
# Sometimes apt-get update fails because the repo is being updated.
res=1
for i in 1 2 3 4 5 6 7 8 9 10 ; do
  if sudo apt-get update ; then
    res=0
    break
  fi
  echo "Upgrade warning: apt-get update failed, retrying ($i)"
  sleep 10
done
if [[ $res -ne 0 ]] ; then
  echo "ERROR: apt-get update failed"
  exit $res
fi
function get_columnstore_logs () {
  if [[ "$test_mode" == "columnstore" ]] ; then
    echo "Storing Columnstore logs in columnstore_logs"
    set +ex
    # It is done in such a weird way, because Columnstore currently makes its logs hard to read
    for f in `sudo ls /var/log/mariadb/columnstore | xargs` ; do
      f=/var/log/mariadb/columnstore/$f
      echo "----------- $f -----------" >> /home/buildbot/columnstore_logs
      sudo cat $f 1>> /home/buildbot/columnstore_logs 2>&1
    done
    for f in /tmp/columnstore_tmp_files/* ; do
      echo "----------- $f -----------" >> /home/buildbot/columnstore_logs
      sudo cat $f >> /home/buildbot/columnstore_logs 2>&1
    done
  fi
}
#=========================
# Install previous release
#=========================
# Debian installation/upgrade/startup always attempts to execute mysql_upgrade, and
# also run mysqlcheck and such. Due to MDEV-14622, they are subject to race condition,
# and can be executed later or even omitted.
# We will wait till they finish, to avoid any clashes with SQL we are going to execute
function wait_for_mysql_upgrade () {
  set +x
  res=1
  for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 ; do
    if ps -ef | grep -iE 'mysql_upgrade|mysqlcheck|mysqlrepair|mysqlanalyze|mysqloptimize|mariadb-upgrade|mariadb-check' | grep -v grep ; then
      sleep 2
    else
      res=0
      break
    fi
  done
  set -x
  if [[ $res -ne 0 ]] ; then
    echo "ERROR: mysql_upgrade or alike have not finished in reasonable time"
  fi
}
sudo sh -c "DEBIAN_FRONTEND=noninteractive MYSQLD_STARTUP_TIMEOUT=180 apt-get -o Dpkg::Options::=--force-confnew install --allow-unauthenticated -y $package_list"
if [[ $? -ne 0 ]] ; then
  echo "ERROR: Installation of a previous release failed, see the output above"
  exit 1
fi
wait_for_mysql_upgrade
if [ -n "$spider_package_list" ] ; then
  sudo sh -c "DEBIAN_FRONTEND=noninteractive MYSQLD_STARTUP_TIMEOUT=180 apt-get -o Dpkg::Options::=--force-confnew install --allow-unauthenticated -y $spider_package_list"
  if [[ $? -ne 0 ]] ; then
    echo "ERROR: Installation of Spider from the previous release failed, see the output above"
    exit 1
  fi
  wait_for_mysql_upgrade
fi
# To avoid confusing errors in further logic, do an explicit check
# whether the service is up and running
if [[ "$systemdCapability" == "yes" ]] ; then
  if ! sudo systemctl status mariadb --no-pager ; then
    sudo journalctl -xe --no-pager
    get_columnstore_logs
    echo "ERROR: mariadb service didn't start properly after installation"
    exit 1
  fi
fi
if [[ "$test_mode" == "all" ]] && [[ "$branch" == *"10."[5-9]* ]] ; then
  echo "Upgrade warning: Due to MDEV-23061, an extra server restart is needed"
  sudo systemctl restart mariadb
fi
#================================================================
# Check that the server is functioning and create some structures
#================================================================
if [[ "$branch" == *"10."[4-9]* ]] ; then
# 10.4+ uses unix_socket by default
  sudo mysql -e "set password=password('rootpass')"
else
# Even without unix_socket, on some of VMs the password might be not pre-created as expected. This command should normally fail.
  mysql -uroot -e "set password = password('rootpass')" >> /dev/null 2>&1
fi
# All the commands below should succeed
set -e
mysql -uroot -prootpass -e "CREATE DATABASE db"
mysql -uroot -prootpass -e "CREATE TABLE db.t_innodb(a1 SERIAL, c1 CHAR(8)) ENGINE=InnoDB; INSERT INTO db.t_innodb VALUES (1,'foo'),(2,'bar')"
mysql -uroot -prootpass -e "CREATE TABLE db.t_myisam(a2 SERIAL, c2 CHAR(8)) ENGINE=MyISAM; INSERT INTO db.t_myisam VALUES (1,'foo'),(2,'bar')"
mysql -uroot -prootpass -e "CREATE TABLE db.t_aria(a3 SERIAL, c3 CHAR(8)) ENGINE=Aria; INSERT INTO db.t_aria VALUES (1,'foo'),(2,'bar')"
mysql -uroot -prootpass -e "CREATE TABLE db.t_memory(a4 SERIAL, c4 CHAR(8)) ENGINE=MEMORY; INSERT INTO db.t_memory VALUES (1,'foo'),(2,'bar')"
mysql -uroot -prootpass -e "CREATE ALGORITHM=MERGE VIEW db.v_merge AS SELECT * FROM db.t_innodb, db.t_myisam, db.t_aria"
mysql -uroot -prootpass -e "CREATE ALGORITHM=TEMPTABLE VIEW db.v_temptable AS SELECT * FROM db.t_innodb, db.t_myisam, db.t_aria"
mysql -uroot -prootpass -e "CREATE PROCEDURE db.p() SELECT * FROM db.v_merge"
mysql -uroot -prootpass -e "CREATE FUNCTION db.f() RETURNS INT DETERMINISTIC RETURN 1"
if [[ "$test_mode" == "columnstore" ]] ; then
  if ! mysql -uroot -prootpass -e "CREATE TABLE db.t_columnstore(a INT, c VARCHAR(8)) ENGINE=ColumnStore; SHOW CREATE TABLE db.t_columnstore; INSERT INTO db.t_columnstore VALUES (1,'foo'),(2,'bar')" ; then
    get_columnstore_logs
    exit 1
  fi
fi
set +e
#====================================================================================
# Store information about server version and available plugins/engines before upgrade
#====================================================================================
if [[ "$test_mode" == "all" ]] ; then
  # Due to MDEV-14560, we have to restart the server to get the full list of engines
  # MDEV-14560 is fixed in 10.2
  if [[ "$prev_major_version" != *"10."[2-9]* ]] ; then
    case "$systemdCapability" in
    yes)
      sudo systemctl restart mariadb
      ;;
    no)
      sudo /etc/init.d/mysql restart
      ;;
    esac
  fi
fi
mysql -uroot -prootpass --skip-column-names -e "select @@version" | awk -F'-' '{ print $1 }' > /tmp/version.old
mysql -uroot -prootpass --skip-column-names -e "select engine, support, transactions, savepoints from information_schema.engines" | sort > /tmp/engines.old
case "$prev_major_version" in
5.5)
  mysql -uroot -prootpass --skip-column-names -e "show plugins" | sort > /tmp/plugins.old
  ;;
10.[0-9])
  mysql -uroot -prootpass --skip-column-names -e "select plugin_name, plugin_status, plugin_type, plugin_library, plugin_license from information_schema.all_plugins" | sort > /tmp/plugins.old
  ;;
*)
  echo "ERROR: unknown major version: $prev_major_version"
  exit 1
  ;;
esac
# Store dependency information for old binaries/libraries:
# - names starting with "mysql*" in the directory where mysqld is located;
# - names starting with "mysql*" in the directory where mysql is located;
# - everything in the plugin directories installed by any MariaDB packages
set +x
for i in `sudo which mysqld | sed -e 's/mysqld$/mysql\*/'` `which mysql | sed -e 's/mysql$/mysql\*/'` `dpkg-query -L \`dpkg -l | grep mariadb | awk '{print $2}' | xargs\` | grep -v 'mysql-test' | grep -v '/debug/' | grep '/plugin/' | sed -e 's/[^\/]*$/\*/' | sort | uniq | xargs` ; do echo "=== $i"; ldd $i | sort | sed 's/(.*)//' ; done > /buildbot/ldd.old
set -x

if ! wget http://yum.mariadb.org/galera/repo/deb/dists/$version_name
# Override the location of the library for versions which don't have their own
then
  if [ "$dist_name" == "debian" ] ; then
    sudo sh -c "echo 'deb [trusted=yes] http://yum.mariadb.org/galera/repo/deb stretch main' > /etc/apt/sources.list.d/galera-test-repo.list"
  else
    sudo sh -c "echo 'deb [trusted=yes] http://yum.mariadb.org/galera/repo/deb xenial main' > /etc/apt/sources.list.d/galera-test-repo.list"
  fi
else
  sudo sh -c "echo 'deb [trusted=yes] http://yum.mariadb.org/galera/repo/deb $version_name main' > /etc/apt/sources.list.d/galera-test-repo.list"
fi
# Update galera-test-repo.list to point at either the galera-3 or galera-4 test repo
case "$branch" in
*10.[1-3]*)
  sudo sed -i 's/repo/repo3/' /etc/apt/sources.list.d/galera-test-repo.list
  ;;
*10.[4-9]*)
  sudo sed -i 's/repo/repo4/' /etc/apt/sources.list.d/galera-test-repo.list
  ;;
esac

if [[ "$test_mode" == "deps" ]] ; then
  # For the dependency check, only keep the local repo
  sudo sh -c "grep -iE 'deb .*file|deb-src .*file' /etc/apt/sources.list.backup > /etc/apt/sources.list"
  sudo rm -rf /etc/apt/sources.list.d/*
else
  sudo cp /etc/apt/sources.list.backup /etc/apt/sources.list
  sudo rm /etc/apt/sources.list.d/mariadb_upgrade.list
fi
sudo rm /etc/apt/preferences.d/release
sudo sh -c "echo 'deb [trusted=yes] https://ci.mariadb.org/${tarbuildnum}/${parentbuildername}/debs .' >> /etc/apt/sources.list"
# Sometimes apt-get update fails because the repo is being updated.
res=1
for i in 1 2 3 4 5 6 7 8 9 10 ; do
  if sudo apt-get update ; then
    res=0
    break
  fi
  echo "Upgrade warning: apt-get update failed, retrying ($i)"
  sleep 10
done
if [[ $res -ne 0 ]] ; then
  echo "ERROR: apt-get update failed"
  exit $res
fi
#=========================
# Install the new packages
#=========================
sudo sh -c "DEBIAN_FRONTEND=noninteractive MYSQLD_STARTUP_TIMEOUT=180 apt-get -o Dpkg::Options::=--force-confnew install --allow-unauthenticated -y $package_list"
if [[ $? -ne 0 ]] ; then
  echo "ERROR: Installation of the new packages failed, see the output above"
  exit 1
fi
wait_for_mysql_upgrade
if [ -n "$spider_package_list" ] ; then
  sudo sh -c "DEBIAN_FRONTEND=noninteractive MYSQLD_STARTUP_TIMEOUT=180 apt-get -o Dpkg::Options::=--force-confnew install --allow-unauthenticated -y $spider_package_list"
  if [[ $? -ne 0 ]] ; then
    echo "ERROR: Installation of the new Spider packages failed, see the output above"
    exit 1
  fi
  wait_for_mysql_upgrade
fi
if [[ "$test_mode" == "columnstore" ]] ; then
  echo "Upgrade warning: Due to MCOL-4120 an extra server restart is needed"
  sudo systemctl restart mariadb
fi
#==========================================================
# Wait till mysql_upgrade, mysqlcheck and such are finished
#==========================================================
# Again, wait till mysql_upgrade is finished, to avoid clashes;
# and for non-stable versions, it might be necessary, so run it again
# just in case it was omitted
wait_for_mysql_upgrade
# run mysql_upgrade for non GA branches
if [[ "$major_version" == $development_branch ]] ; then
  mysql_upgrade -uroot -prootpass
fi
#================================
# Make sure that the new server is running
#================================
if mysql -uroot -prootpass -e "select @@version" | grep `cat /tmp/version.old` ; then
  echo "ERROR: The server was not upgraded or was not restarted after upgrade"
  exit 1
fi
#===================================================
# Check that no old packages have left after upgrade
#===================================================
# The check is only performed for all-package-upgrade, because
# for selective ones some implicitly installed packages might not be upgraded
if [[ "$test_mode" == "all" ]] ; then
  if dpkg -l | grep -iE 'mysql|maria' | grep `cat /tmp/version.old` ; then
    echo "ERROR: Old packages have been found after upgrade"
    exit 1
  fi
fi
#=====================================================================================
# Check that the server is functioning and previously created structures are available
#=====================================================================================
# All the commands below should succeed
set -e
mysql -uroot -prootpass -e "select @@version, @@version_comment"
mysql -uroot -prootpass -e "SHOW TABLES IN db"
mysql -uroot -prootpass -e "SELECT * FROM db.t_innodb; INSERT INTO db.t_innodb VALUES (3,'foo'),(4,'bar')"
mysql -uroot -prootpass -e "SELECT * FROM db.t_myisam; INSERT INTO db.t_myisam VALUES (3,'foo'),(4,'bar')"
mysql -uroot -prootpass -e "SELECT * FROM db.t_aria; INSERT INTO db.t_aria VALUES (3,'foo'),(4,'bar')"
echo "If the next INSERT fails with a duplicate key error,"
echo "it is likely because the server was not upgraded or restarted after upgrade"
mysql -uroot -prootpass -e "SELECT * FROM db.t_memory; INSERT INTO db.t_memory VALUES (1,'foo'),(2,'bar')"
mysql -uroot -prootpass -e "SELECT COUNT(*) FROM db.v_merge"
mysql -uroot -prootpass -e "SELECT COUNT(*) FROM db.v_temptable"
mysql -uroot -prootpass -e "CALL db.p()"
mysql -uroot -prootpass -e "SELECT db.f()"
if [[ "$test_mode" == "columnstore" ]] ; then
  if ! mysql -uroot -prootpass -e "SELECT * FROM db.t_columnstore; INSERT INTO db.t_columnstore VALUES (3,'foo'),(4,'bar')" ; then
    get_columnstore_logs
    exit 1
  fi
fi
set +e
#===================================================================================
# Store information about server version and available plugins/engines after upgrade
#===================================================================================
set -e
mysql -uroot -prootpass --skip-column-names -e "select @@version" | awk -F'-' '{ print $1 }' > /tmp/version.new
mysql -uroot -prootpass --skip-column-names -e "select engine, support, transactions, savepoints from information_schema.engines" | sort > /tmp/engines.new
case "$major_version" in
5.5)
  mysql -uroot -prootpass --skip-column-names -e "show plugins" | sort > /tmp/plugins.new
  ;;
10.[0-9])
  mysql -uroot -prootpass --skip-column-names -e "select plugin_name, plugin_status, plugin_type, plugin_library, plugin_license from information_schema.all_plugins" | sort > /tmp/plugins.new
  ;;
esac
# Dependency information for new binaries/libraries
set +x
for i in `sudo which mysqld | sed -e 's/mysqld$/mysql\*/'` `which mysql | sed -e 's/mysql$/mysql\*/'` `dpkg-query -L \`dpkg -l | grep mariadb | awk '{print $2}' | xargs\` | grep -v 'mysql-test' | grep -v '/debug/' | grep '/plugin/' | sed -e 's/[^\/]*$/\*/' | sort | uniq | xargs` ; do echo "=== $i"; ldd $i | sort | sed 's/(.*)//' ; done > /home/buildbot/ldd.new
set -x
case "$systemdCapability" in
yes)
  ls -l /lib/systemd/system/mariadb.service
  ls -l /etc/systemd/system/mariadb.service.d/migrated-from-my.cnf-settings.conf
  ls -l /etc/init.d/mysql || true
  systemctl --no-pager status mariadb.service
  systemctl --no-pager status mariadb
  systemctl --no-pager status mysql
  systemctl --no-pager status mysqld
  systemctl --no-pager is-enabled mariadb
  ;;
no)
  echo "Steps related to systemd will be skipped"
  ;;
*)
  echo "ERROR: It should never happen, check your configuration (systemdCapability property is not set or is set to a wrong value)"
  exit 1
  ;;
esac
set +e
# This output is for informational purposes
diff -u /tmp/engines.old /tmp/engines.new
diff -u /tmp/plugins.old /tmp/plugins.new
case "$branch" in
$development_branch)
  echo "Until $development_branch is GA, the list of plugins/engines might be unstable, skipping the check"
  ;;
*)
  # Only fail if there are any disappeared/changed engines or plugins
  disappeared_or_changed=`comm -23 /tmp/engines.old /tmp/engines.new | wc -l`
  if [[ $disappeared_or_changed -ne 0 ]] ; then
    echo "ERROR: the lists of engines in the old and new installations differ"
    exit 1
  fi
  if [[ "$test_type" == "minor" ]] ; then
  	disappeared_or_changed=`comm -23 /tmp/plugins.old /tmp/plugins.new | wc -l`
  	if [[ $disappeared_or_changed -ne 0 ]] ; then
    		echo "ERROR: the lists of plugins in the old and new installations differ"
    		exit 1
  	fi
  fi
  set -o pipefail
  if [ "$test_mode" == "all" ] ; then
    set -o pipefail
    if wget --timeout=20 --no-check-certificate https://raw.githubusercontent.com/MariaDB/mariadb.org-tools/master/buildbot/baselines/ldd.${major_version}.${version_name}.${arch} -O /tmp/ldd.baseline > /dev/null ; then
      ldd_baseline=/tmp/ldd.baseline
    else
      ldd_baseline=/buildbot/ldd.old
    fi
    diff -U1000 $ldd_baseline /home/buildbot/ldd.new | ( grep -E '^[-+]|^ =' || true )
    if [[ $? -ne 0 ]] ; then
      echo "ERROR: something has changed in the dependencies of binaries or libraries. See the diff above"
      exit 1
    fi
  fi
  set +o pipefail
  ;;
esac
diff -u /tmp/version.old /tmp/version.new
if [[ $? -eq 0 ]] ; then
  echo "ERROR: server version has not changed after upgrade"
  echo "It can be a false positive if we forgot to bump version after release,"
  echo "or if it is a development tree is based on an old version"
  exit 1
fi
