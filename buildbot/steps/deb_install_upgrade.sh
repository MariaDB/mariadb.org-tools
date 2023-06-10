########################################################################
# Debian package installation/upgrade test
########################################################################

#===============
# This test can be performed in three modes:
# - 'install' -- clean installation of all packages (and galera)
# - 'server'  -- only mariadb-server is installed (with whatever dependencies it pulls) and upgraded.
# - 'all'     -- all provided packages and a new galera are installed and upgraded, except for Columnstore
# - 'columnstore' -- mariadb-server and mariadb-plugin-columnstore are installed
#===============

#####################
# Functions
#####################

get_latest_galera()
{
  if [ -z "$major_version" ] ; then
    echo "ERROR: server major version (major_version) is not defined"
    exit 1
  fi

  if [ -z "$arch" ] ; then
    echo "ERROR: server architecture (arch) is not defined"
    exit 1
  fi

  if [ -z "$version_name" ] ; then
    echo "ERROR: debian/ubuntu version name (version_name) is not defined"
    exit 1
  fi

  galera_arch=$arch

  case "$major_version" in
  *10.3*)
    GALERA_VERSION=3
    ;;
  *)
    GALERA_VERSION=4
    ;;
  esac

  cd $HOME
  mkdir galera_download
  cd galera_download
  if ! wget https://buildbot.mariadb.net/archive/builds/mariadb-${GALERA_VERSION}.x/latest/kvm-deb-${version_name}-${galera_arch}-gal/debs/ --recursive -np -R "index.html*" -nH --cut-dirs=5 --no-check-certificate ; then
    echo "Test warning"": wget exited with a non-zero code, but it may be bogus"
    if ! ls debs/binary/galera-[34]_*.deb ; then
      echo "ERROR: Could not download the Galera library"
      exit 1
    fi
  fi
  mv debs ../buildbot/galera-debs
  cd ..
  rm -rf galera_download
  cd buildbot
  if [ -e galera-debs/binary/Packages.gz ] ; then
      gunzip galera-debs/binary/Packages.gz
  fi
  sudo sh -c 'echo "deb [trusted=yes allow-insecure=yes] file:///home/buildbot/buildbot/galera-debs binary/" >> /etc/apt/sources.list'
  sudo sh -c 'echo "deb-src [trusted=yes allow-insecure=yes] file:///home/buildbot/buildbot/galera-debs source/" >> /etc/apt/sources.list'
}

#==================================================================
# In releases and otherwise stored builds architecture may look
# different from the buildbot configuration
#==================================================================

set_server_arch()
{
  if [[ "$arch" == "ppc64le" ]] ; then
    server_arch=ppc64el
  elif [[ "$arch" == "x86" ]] ; then
    server_arch=i386
  elif [[ "$arch" == "aarch64" ]] ; then
    server_arch=arm64
  else
    server_arch=$arch
  fi
}

#==================================================================
# Extract list of packages to install from Packages file
# Path to the file is provided as an argument
# Sets 'package_list' and possibly 'spider_package_list' variables
#==================================================================

get_package_list()
{
  packages_file=$1
  if grep -i columnstore $packages_file > /dev/null ; then
    echo "Upgrade warning"": Due to instability Columnstore upgrade is tested separately"
  fi
  package_list=`grep -B 1 'Source: mariadb' $packages_file | grep 'Package:' | grep -vE 'galera|spider|columnstore' | awk '{print $2}' | sort | uniq | xargs`
  if grep -i spider $packages_file > /dev/null ; then
    echo "Upgrade warning"": Due to MDEV-14622 Spider will be installed separately after the server"
    spider_package_list=`grep -B 1 'Source: mariadb' $packages_file | grep 'Package:' | grep 'spider' | awk '{print $2}' | sort | uniq | xargs`
  fi
  if grep -i tokudb $packages_file > /dev/null ; then
    # For the sake of installing TokuDB, disable hugepages
    sudo sh -c "echo never > /sys/kernel/mm/transparent_hugepage/enabled" || true
  fi
}

#==================================================================
# Extract list of packages to install from Packages file
# Path to the file is provided as an argument
# Sets 'columnstore_package_list'
#==================================================================

get_columnstore_package_list()
{
  packages_file=$1
  if grep columnstore $packages_file > /dev/null ; then
    columnstore_package_list=`grep -B 1 'Source: mariadb' $packages_file | grep 'Package:' | grep 'columnstore' | awk '{print $2}' | sort | uniq | xargs`
  fi
}

#==================================================================
# Sometimes apt-get update fails e.g. because the repo is being updated
#==================================================================

run_apt_get_update()
{
  res=1
  for i in 1 2 3 4 5 6 7 8 9 10 ; do
    if sudo apt-get update ; then
      res=0
      break
    fi
    echo "Upgrade warning"": apt-get update failed, retrying ($i)"
    sleep 10
  done
  if [[ $res -ne 0 ]] ; then
    echo "ERROR: apt-get update failed"
    exit $res
  fi
}

#==================================================================
# Collect columnstore logs
#==================================================================

get_columnstore_logs()
{
  if [ -n "$columnstore_package_list" ] ; then
    sudo ls -l /dev/shm/
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

#==================================================================
# Collect information about the server and its files
# - version
# - engine list
# - plugin list
# - dependencies from all binaries
#   - names starting with "mysql*" in the directory where mysqld is located;
#   - names starting with "mysql*" in the directory where mysql is located;
#   - everything in the plugin directories installed by any MariaDB packages

# First argument is "old" or "new"
#==================================================================

get_server_info()
{
  new_or_old=$1

  set -e
  mysql -uroot -prootpass --skip-column-names -e "select @@version" | awk -F'-' '{ print $1 }' > /tmp/version.$new_or_old
  mysql -uroot -prootpass --skip-column-names -e "select engine, support, transactions, savepoints from information_schema.engines" | sort > /tmp/engines.$new_or_old
  mysql -uroot -prootpass --skip-column-names -e "select plugin_name, plugin_status, plugin_type, plugin_library, plugin_license from information_schema.all_plugins" | sort > /home/buildbot/plugins.$new_or_old

  rm -f /home/buildbot/ldd.$new_or_old
  set +x
  for i in `sudo which mysqld | sed -e 's/mysqld$/mysql\*/'` `which mysql | sed -e 's/mysql$/mysql\*/'` `dpkg-query -L \`dpkg -l | grep mariadb | awk '{print $2}' | xargs\` | grep -v 'mysql-test' | grep -v '/debug/' | grep '/plugin/' | sed -e 's/[^\/]*$/\*/' | sort | uniq | xargs`
  do
    # Q3 2023 workaround, MDEV-30483
    if [ "$new_or_old" == "new" ] && [[ $i =~ type_mysql_timestamp.so ]] && grep -E "10.6.14|10.8.8|10.9.7|10.10.5|10.11.4|11.0.2|11.1.1" /tmp/version.old ; then
      echo "Skipping the new type_mysql_timestamp.so which isn't present in the previous version"
      continue
    fi
    echo "=== $i" >> /home/buildbot/ldd.$new_or_old
    ldd $i | sort | sed 's/(.*)//' >> /home/buildbot/ldd.$new_or_old
  done
  set -x
}

#==================================================================
# Some information about the machine, can be useful for diagnostics
#==================================================================

check_environment()
{
  dpkg -l | grep -iE 'maria|mysql|galera' || true
  lsb_release -a
  uname -a
  df -kT
}

#==================================================================
# Debian installation/upgrade/startup always attempts to execute
# mysql_upgrade, and also run mysqlcheck and such. Due to MDEV-14622,
# they are subject to race condition, and can be executed too late
# or even omitted. We will wait till they finish, to avoid any clashes
# with SQL we are going to execute
#==================================================================

wait_for_mysql_upgrade()
{
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
    echo "Upgrade warning"": mysql_upgrade or alike have not finished in reasonable time, different problems may occur"
  fi
}

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
      echo "Upgrade warning"": source package for connector ${script%.deb.sh} could not be installed with the $1 server"
    fi
  done
}

################################
# End of functions
################################

cd $HOME/buildbot
chmod -cR go+r debs
if [ -e debs/binary/Packages.gz ] ; then
  gunzip debs/binary/Packages.gz
fi
if [ -e debs/source/Sources.gz ] ; then
  gunzip debs/source/Sources.gz
fi

# Mandatory variables
for var in test_mode branch arch dist_name version_name major_version ; do
  if [ -z "${!var}" ] ; then
    echo "ERROR: $var variable is not defined"
    exit 1
  fi
done

test_mode=`echo $test_mode | sed -e 's/minor-upgrade-//'`

if [ "$test_mode" != "install" ] && [[ "$branch" =~ "$development_branch" ]] ; then
  echo "Test warning"": minor upgrade is not executed for development branches (nothing to upgrade from)"
  exit
  ;;
fi

set_server_arch

echo "Architecture, distribution and version based on VM name: $arch ($server_arch) $dist_name $version_name"

echo "Major version $major_version"
echo "Current test mode: $test_mode"

script_path=`readlink -f $0`
script_home=`dirname $script_path`

check_environment

#========================================
# For upgrade, choose a mirror
# containing the old server
#========================================

if [ "$test_mode" != "install" ] ; then
  # We do it this way because ping to mirrors does not work on some VMs
  for m in "mirrors.xtom.ee" "mirror.kumi.systems" "mirror.23m.com" "mirrors.xtom.nl" "mirror.mva-n.net" "mirrors.gigenet.com" ; do
    if wget http://$m/mariadb/repo ; then
      mirror=$m
      break
    fi
  done

  if [ -z "$mirror" ] ; then
    echo "ERROR: Couldn't find a working mirror containing MariaDB repo, giving up"
    exit 1
  else
    echo "Mirror $mirror will be used"
    rm -f index.html
  fi

  #========================================
  # Check whether a previous version exists
  #========================================

  if ! wget http://$mirror/mariadb/repo/$major_version/$dist_name/dists/$version_name/main/binary-${server_arch}/Packages
  then
    echo "ERROR: could not find the 'Packages' file for a previous version. Maybe $version_name-${server_arch} is a new platform, or $major_version was not released yet?"
    exit 1
  fi
fi

#===============================================
# Define the list of packages to install/upgrade
# For installation test we use Packages file from the scp-ed package set,
# for upgrade -- earlier downloaded one from the old server repository
#===============================================

case $test_mode in
install)
  get_package_list "debs/binary/Packages"
  get_columnstore_package_list "debs/binary/Packages"
  ;;
all)
  # Sets 'package_list' and possibly 'spider_package_list' variables
  get_package_list "Packages"
  ;;
server)
  package_list=mariadb-server
  ;;
columnstore)
  # Sets 'columnstore_package_list'
  get_columnstore_package_list "Packages"
  if [ -z "$columnstore_package_list" ] ; then
    echo "Test warning"": Columnstore was not found in packages"
    exit
  fi
  package_list="mariadb-server $columnstore_package_list"
  ;;
*)
  echo "ERROR: unknown test mode: $test_mode"
  exit 1
esac

echo "Package_list: $package_list"


#######################################################
# Preliminary stage
# (installation of the old server for upgrade
#  or ensuring clean environment for installation test)
#######################################################
if [ "$test_mode" == "install" ] ; then
  # We want a clean installation here
  dpkg -l | grep -iE 'maria|mysql|galera' | awk '{print $2}' | xargs sudo apt-get remove -y
  dpkg -l | grep -iE 'maria|mysql|galera' | awk '{print $2}' | xargs sudo apt-get purge -y
else
  #======================================================================
  # Prepare apt source configuration for installation of the last release
  #======================================================================

  sudo sh -c "echo 'deb http://$mirror/mariadb/repo/$major_version/$dist_name $version_name main' > /etc/apt/sources.list.d/mariadb_upgrade.list"

  # We need to pin directory to ensure that installation happens from MariaDB repo
  # rather than from the default distro repo

  sudo sh -c "echo 'Package: *' > /etc/apt/preferences.d/release"
  sudo sh -c "echo 'Pin: origin $mirror' >> /etc/apt/preferences.d/release"
  sudo sh -c "echo 'Pin-Priority: 1000' >> /etc/apt/preferences.d/release"

  sudo cp /etc/apt/sources.list /etc/apt/sources.list.backup
  sudo sh -c 'grep -v "^deb .*file" /etc/apt/sources.list.backup | grep -v "^deb-src .*file" > /etc/apt/sources.list'

  run_apt_get_update

  #=========================
  # Install previous release
  #=========================

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
  if ! sudo systemctl -l status mariadb --no-pager ; then
    sudo journalctl -xe --no-pager
    get_columnstore_logs
    echo "ERROR: mariadb service didn't start properly after installation"
    exit 1
  fi

  if [[ "$test_mode" == "all" ]] && [[ "$branch" != *"10."[234]* ]] ; then
    echo "Upgrade warning"": Due to MDEV-23061, an extra server restart is needed"
    sudo systemctl restart mariadb
  fi

  #================================================================
  # Check that the server is functioning and create some structures
  #================================================================

  if [[ "$branch" != *"10."[23]* ]] ; then
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

  #if [[ "$test_mode" == "server" ]] ; then
  if [[ "$test_mode" == "never" ]] ; then
    sudo sed -ie 's/^# deb-src/deb-src/' /etc/apt/sources.list
    sudo apt-get update
    sudo sh -c "DEBIAN_FRONTEND=noninteractive apt-get install -y debhelper dpkg-dev"
    connectors_tests "old"
  fi

  #====================================================================================
  # Store information about server BEFORE upgrade
  # (version, plugins, engines, dependencies)
  #====================================================================================

  get_server_info "old"

  #=========================================
  # Restore apt configuration for local repo
  #=========================================

  chmod -cR go+r ~/buildbot/debs

  sudo cp /etc/apt/sources.list.backup /etc/apt/sources.list
  sudo rm /etc/apt/sources.list.d/mariadb_upgrade.list
  sudo rm /etc/apt/preferences.d/release

fi
#
# End of the preliminary stage (installation of the old server)
#

if [ "$test_mode" == "all" ] || [ "$test_mode" == "install" ] ; then
  get_latest_galera
fi

run_apt_get_update

##################################
# Main stage 
# Installation of the new packages
##################################

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

#==========================================================
# Wait till mysql_upgrade, mysqlcheck and such are finished
#==========================================================

# Again, wait till mysql_upgrade is finished, to avoid clashes;
# and for non-stable versions, it might be necessary, so run it again
# just in case it was omitted

wait_for_mysql_upgrade

# run mysql_upgrade for non GA branches
if [[ "$major_version" == "$development_branch" ]] ; then
  sudo mysql_upgrade -uroot -prootpass
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

#====================================================================================
# Store information about server AFTER upgrade
# (version, plugins, engines, dependencies)
#====================================================================================

get_server_info "new"

#====================================================================================
# Some more service checks
#====================================================================================

set -e

ls -l /lib/systemd/system/mariadb.service
ls -l /etc/systemd/system/mariadb.service.d/migrated-from-my.cnf-settings.conf
ls -l /etc/init.d/mysql || true
systemctl -l --no-pager status mariadb.service
systemctl -l --no-pager status mariadb
systemctl -l --no-pager status mysql
systemctl -l --no-pager status mysqld
systemctl --no-pager is-enabled mariadb

set +e
res=0

#====================================================================================
# Comparisons (for upgrade tests)
#====================================================================================

if [ "$test_mode" != "install" ] ; then

  # This output is for informational purposes
  diff -u /tmp/engines.old /tmp/engines.new
  diff -u /home/buildbot/plugins.old /home/buildbot/plugins.new

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
    disappeared_or_changed=`comm -23 /home/buildbot/plugins.old /home/buildbot/plugins.new | wc -l`
    if [[ $disappeared_or_changed -ne 0 ]] ; then
      echo "ERROR: the lists of plugins in the old and new installations differ"
      res=1
    fi
    set -o pipefail
    if [ "$test_mode" == "all" ] || [ "$test_mode" == "columnstore" ] ; then
      set -o pipefail
      if [ -e $script_home/baselines/ldd.${major_version}.${version_name}.${server_arch} ]; then
        ldd_baseline=$script_home/baselines/ldd.${major_version}.${version_name}.${server_arch}
      else
        ldd_baseline=/home/buildbot/ldd.old
      fi
      diff -U1000 $ldd_baseline /home/buildbot/ldd.new | ( grep -E '^[-+]|^ =' || true )
      if [[ $? -ne 0 ]] ; then
        if [[ "$version_name" == "sid" ]] ; then
          echo "Upgrade warning"": something has changed in the dependencies of binaries or libraries. See the diff"
        else
          echo "ERROR: something has changed in the dependencies of binaries or libraries. See the diff above"
          res=1
        fi
      fi
    fi
    set +o pipefail
    ;;
  esac
fi

#====================================================================================
# Run protocol (3rd-party connectors) tests and store results AFTER upgrade
#====================================================================================

#if [[ "$test_mode" == "server" ]] ; then
if [[ "$test_mode" == "never" ]] ; then
  sudo sed -ie 's/^# deb-src/deb-src/' /etc/apt/sources.list
  sudo apt-get update
  connectors_tests "new"
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
# In server mode we will use the VM for furhter MTR tests, so need MTR
#====================================================================================

if [[ "$test_mode" == "server" ]] ; then
  sudo sh -c "DEBIAN_FRONTEND=noninteractive MYSQLD_STARTUP_TIMEOUT=180 apt-get -o Dpkg::Options::=--force-confnew install --allow-unauthenticated -y mariadb-test mariadb-test-data mariadb-backup"
fi

#====================================================================================
# Check that the server version was modified by the server upgrade
#====================================================================================

if [ "$test_mode" != "install" ] ; then
  diff -u /tmp/version.old /tmp/version.new
  if [[ $? -eq 0 ]] ; then
    echo "ERROR: server version has not changed after upgrade"
    echo "It can be a false positive if we forgot to bump version after release,"
    echo "or if it is a development tree is based on an old version"
    res=1
  fi
fi

exit $res

########################################################################
# End of debian minor package upgrade test
########################################################################
