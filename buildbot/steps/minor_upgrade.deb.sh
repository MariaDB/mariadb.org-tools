########################################################################
# Debian minor package upgrade test
########################################################################

#===============
# This test can be performed in four modes:
# - 'server' -- only mariadb-server is installed (with whatever dependencies it pulls) and upgraded.
#               It also tests compatibility with available 3rd-party connectors
# - 'all'    -- all provided packages are installed and upgraded, except for Columnstore
# - 'deps'   -- only a limited set of main packages is installed and upgraded,
#               to make sure upgrade does not require new dependencies
# - 'columnstore' -- mariadb-server and mariadb-plugin-columnstore are installed
#===============

# Mandatory variables
for var in test_mode branch arch dist_name version_name major_version systemd_capability ; do
  if [ -z "${!var}" ] ; then
    echo "ERROR: $var variable is not defined"
    exit 1
  fi
done

case $branch in
*"$development_branch"*)
  if [[ "$test_mode" != "server" ]] ; then
    echo "Upgrade warning: For non-stable branches the test is only run in 'test' mode"
    exit
  fi
  ;;
esac

echo "Architecture, distribution and version based on VM name: $arch $dist_name $version_name"

echo "Test properties"
echo "  Systemd capability $systemd_capability"
echo "  Major version $major_version"
echo "Current test mode: $test_mode"

script_path=`readlink -f $0`
script_home=`dirname $script_path`

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

if ! wget http://mirror.netinch.com/pub/mariadb/repo/$major_version/$dist_name/dists/$version_name/main/binary-$arch/Packages
then
  echo "Upgrade warning: could not find the 'Packages' file for a previous version in MariaDB repo, skipping the test"
  exit
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
  elif [[ "$version_name" == "sid" ]] ; then
    echo "Upgrade warning: Columnstore isn't necessarily built on Sid, thte test will be skipped"
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

for m in "mirrors.xtom.ee" "mirror.kumi.systems" "mirror.23m.com" "mirrors.xtom.nl" "mirror.mva-n.net" "mirrors.gigenet.com" ; do
  if ping -W 1 -c 5 -i 1 $m ; then
    mirror=$m
    break
  else
    echo "WARNING: Mirror $m seems to be having troubles"
  fi
done

if [ -z "$mirror" ] ; then
  echo "ERROR: Could not find a mirror to download the release from"
  exit 1
fi

sudo sh -c "echo 'deb http://$mirror/mariadb/repo/$major_version/$dist_name $version_name main' > /etc/apt/sources.list.d/mariadb_upgrade.list"

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

get_columnstore_logs () {
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

wait_for_mysql_upgrade () {
  res=1
  for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 ; do
    sleep 3
    if ! ps -ef | grep -iE 'mysql_upgrade|mysqlcheck|mysqlrepair|mysqlanalyze|mysqloptimize|mariadb-upgrade|mariadb-check' | grep -v grep ; then
      # Check once again, to make sure we didn't hit the moment between the scripts
      sleep 2
      if ! ps -ef | grep -iE 'mysql_upgrade|mysqlcheck|mysqlrepair|mysqlanalyze|mysqloptimize|mariadb-upgrade|mariadb-check' | grep -v grep ; then
        res=0
        break
      fi
    fi
  done
  if [[ $res -ne 0 ]] ; then
    echo "Upgrade warning: mysql_upgrade or alike have not finished in reasonable time, different problems may occur"
  fi
}

if ! sudo sh -c "DEBIAN_FRONTEND=noninteractive MYSQLD_STARTUP_TIMEOUT=180 apt-get -o Dpkg::Options::=--force-confnew install --allow-unauthenticated -y $package_list" ; then
  get_columnstore_logs
  echo "ERROR: Installation of a previous release failed, see the output above"
  exit 1
fi

wait_for_mysql_upgrade

if [ -n "$spider_package_list" ] ; then
  if ! sudo sh -c "DEBIAN_FRONTEND=noninteractive MYSQLD_STARTUP_TIMEOUT=180 apt-get -o Dpkg::Options::=--force-confnew install --allow-unauthenticated -y $spider_package_list" ; then
    echo "ERROR: Installation of Spider from the previous release failed, see the output above"
    exit 1
  fi
  wait_for_mysql_upgrade
fi

# To avoid confusing errors in further logic, do an explicit check
# whether the service is up and running
if [[ "$systemd_capability" == "yes" ]] ; then
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

# Print "have_xx" capabilitites for the old server

mysql -uroot -prootpass -e "select 'Stat' t, variable_name name, variable_value val from information_schema.global_status where variable_name like '%have%' union select 'Vars' t, variable_name name, variable_value val from information_schema.global_variables where variable_name like '%have%' order by t, name"

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
# Run protocol (3rd-party connectors) tests and store results BEFORE upgrade
#====================================================================================

connectors_tests () {
  # The function expects a parameter with a value either 'old' or 'new'
  #
  # Each runner script is expected to extract the important part
  # of the test results into /tmp/test.out file

  for script in $script_home/steps/3rd-party-client-tests/*.deb.sh; do
    script=`basename $script`
    # The outside directory is used to prevent too long socket paths in tests
    rm -rf $HOME/3rd-party
    mkdir $HOME/3rd-party
    cd $HOME/3rd-party
    if apt-get --assume-yes --only-source source ${script%.deb.sh}; then
      $script_home/steps/3rd-party-client-tests/${script}
      mv /tmp/test.out /tmp/${script}.test.out.$1
    else
      echo "Upgrade warning: source package for connector ${script%.deb.sh} could not be installed with the $1 server"
    fi
  done
}

if [[ "$test_mode" == "server" ]] ; then
  sudo sed -ie 's/^# deb-src/deb-src/' /etc/apt/sources.list
  sudo apt-get update
  sudo sh -c "DEBIAN_FRONTEND=noninteractive apt-get install -y debhelper dpkg-dev"
  connectors_tests "old"
fi

#====================================================================================
# Store information about server version and available plugins/engines BEFORE upgrade
#====================================================================================

if [[ "$test_mode" == "all" ]] ; then
  # Due to MDEV-14560, we have to restart the server to get the full list of engines
  # MDEV-14560 is fixed in 10.2
  if [[ "$major_version" != *"10."[2-9]* ]] ; then
    case "$systemd_capability" in
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

case "$major_version" in
5.5)
  mysql -uroot -prootpass --skip-column-names -e "show plugins" | sort > /tmp/plugins.old
  ;;
10.[0-9])
  mysql -uroot -prootpass --skip-column-names -e "select plugin_name, plugin_status, plugin_type, plugin_library, plugin_license from information_schema.all_plugins" | sort > /tmp/plugins.old
  ;;
*)
  echo "ERROR: unknown major version: $major_version"
  exit 1
  ;;
esac

# Store dependency information for old binaries/libraries:
# - names starting with "mysql*" in the directory where mysqld is located;
# - names starting with "mysql*" in the directory where mysql is located;
# - everything in the plugin directories installed by any MariaDB packages

set +x
for i in `sudo which mysqld | sed -e 's/mysqld$/mysql\*/'` `which mysql | sed -e 's/mysql$/mysql\*/'` `dpkg-query -L \`dpkg -l | grep mariadb | awk '{print $2}' | xargs\` | grep -v 'mysql-test' | grep -v '/debug/' | grep '/plugin/' | sed -e 's/[^\/]*$/\*/' | sort | uniq | xargs` ; do echo "=== $i"; ldd $i | sort | sed 's/(.*)//' ; done > /home/buildbot/ldd.old
set -x

#=========================================
# Restore apt configuration for local repo
#=========================================

chmod -cR go+r ~/buildbot/debs

if [[ "$test_mode" == "deps" ]] ; then
  # For the dependency check, only keep the local repo
  sudo sh -c "grep -iE 'deb .*file|deb-src .*file' /etc/apt/sources.list.backup > /etc/apt/sources.list"
  sudo rm -rf /etc/apt/sources.list.d/*
else
  sudo cp /etc/apt/sources.list.backup /etc/apt/sources.list
  sudo rm /etc/apt/sources.list.d/mariadb_upgrade.list
fi
sudo rm /etc/apt/preferences.d/release

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

#==================================================================
# Download Galera library for the new packages and prepare the repo
#==================================================================

case "$major_version" in
*10.[1-3]*)
  GALERA_VERSION=3
  ;;
*10.[4-9]*)
  GALERA_VERSION=4
  ;;
*)
  echo "ERROR: Unknown server version: $major_version"
  exit 1
  ;;
esac

mkdir galera_download
cd galera_download
if ! wget https://hasky.askmonty.org/builds/mariadb-${GALERA_VERSION}.x/latest/kvm-deb-${version_name}-${arch}-gal/debs/ --recursive -np -R "index.html*" -nH --cut-dirs=4 --no-check-certificate ; then
  echo "ERROR: Could not download the Galera library"
  exit 1
fi
mv debs ../buildbot/galera-debs
cd ..
rm -rf galera_download
sudo sh -c 'echo "deb [trusted=yes allow-insecure=yes] file:///home/buildbot/buildbot/galera-debs binary/" >> /etc/apt/sources.list'
sudo sh -c 'echo "deb-src [trusted=yes allow-insecure=yes] file:///home/buildbot/buildbot/debs source/" >> /etc/apt/sources.list'

cd buildbot
chmod -cR go+r debs galera-debs

if [ -e debs/binary/Packages.gz ] ; then
    gunzip debs/binary/Packages.gz
fi
if [ -e galera-debs/binary/Packages.gz ] ; then
    gunzip galera-debs/binary/Packages.gz
fi

#=========================
# Install the new packages
#=========================

sudo sh -c "DEBIAN_FRONTEND=noninteractive MYSQLD_STARTUP_TIMEOUT=180 apt-get -o Debug::pkgProblemResolver=1 -o Dpkg::Options::=--force-confnew install --allow-unauthenticated -y $package_list"
if [[ $? -ne 0 ]] ; then
  get_columnstore_logs
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
if [[ "$major_version" == "$development_branch" ]] ; then
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
# Check that no old packages have left AFTER upgrade
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

# Print "have_xx" capabilitites for the new server

mysql -uroot -prootpass -e "select 'Stat' t, variable_name name, variable_value val from information_schema.global_status where variable_name like '%have%' union select 'Vars' t, variable_name name, variable_value val from information_schema.global_variables where variable_name like '%have%' order by t, name"

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
# Store information about server version and available plugins/engines AFTER upgrade
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

case "$systemd_capability" in
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
res=0

# This output is for informational purposes
diff -u /tmp/engines.old /tmp/engines.new
diff -u /tmp/plugins.old /tmp/plugins.new

case "$branch" in
*"$development_branch"*)
  echo "Until $development_branch is GA, the list of plugins/engines might be unstable, skipping the check"
  ;;
*)
  # Only fail if there are any disappeared/changed engines or plugins
  disappeared_or_changed=`comm -23 /tmp/engines.old /tmp/engines.new | wc -l`
  if [[ $disappeared_or_changed -ne 0 ]] ; then
    echo "ERROR: the lists of engines in the old and new installations differ"
    res=1
  fi
  disappeared_or_changed=`comm -23 /tmp/plugins.old /tmp/plugins.new | wc -l`
  if [[ $disappeared_or_changed -ne 0 ]] ; then
    echo "ERROR: the lists of plugins in the old and new installations differ"
    res=1
  fi
  set -o pipefail
  if [ "$test_mode" == "all" ] ; then
    set -o pipefail
    if [ -e $script_home/baselines/ldd.${major_version}.${version_name}.${arch} ]; then
      ldd_baseline=$script_home/baselines/ldd.${major_version}.${version_name}.${arch}
    else
      ldd_baseline=/home/buildbot/ldd.old
    fi
    diff -U1000 $ldd_baseline /home/buildbot/ldd.new | ( grep -E '^[-+]|^ =' || true )
    if [[ $? -ne 0 ]] ; then
      if [[ "$version_name" == "sid" ]] ; then
        echo "Upgrade warning: something has changed in the dependencies of binaries or libraries. See the diff"
      else
        echo "ERROR: something has changed in the dependencies of binaries or libraries. See the diff above"
        res=1
      fi
    fi
  fi
  set +o pipefail
  ;;
esac

#====================================================================================
# Run protocol (3rd-party connectors) tests and store results AFTER upgrade
#====================================================================================

if [[ "$test_mode" == "server" ]] ; then
  sudo sed -ie 's/^# deb-src/deb-src/' /etc/apt/sources.list
  sudo apt-get update
  connectors_tests "new"
fi

if [[ "$test_mode" == "server" ]] ; then
  cd $HOME/3rd-party
  for old_result in /tmp/*.deb.sh.test.out.old ; do
    if [ -f $old_result ] ; then
      new_result=${old_result%.old}.new
      if ! diff -u $old_result $new_result ; then
        echo "ERROR: Results for ${script%.deb.sh} connector differ"
#        res=1
      fi
    fi
  done
fi

#====================================================================================
# Check that the server version was modified by the server upgrade
#====================================================================================

diff -u /tmp/version.old /tmp/version.new
if [[ $? -eq 0 ]] ; then
  echo "ERROR: server version has not changed after upgrade"
  echo "It can be a false positive if we forgot to bump version after release,"
  echo "or if it is a development tree is based on an old version"
  res=1
fi

exit $res

########################################################################
# End of debian minor package upgrade test
########################################################################
