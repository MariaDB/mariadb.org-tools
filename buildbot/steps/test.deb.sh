########################################################################
# Debian package testing -- common parts of install/upgrade tests
########################################################################

#==================================================================
# Download a new Galera library and prepare the local repo
#==================================================================

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
  if ! wget https://hasky.askmonty.org/builds/mariadb-${GALERA_VERSION}.x/latest/kvm-deb-${version_name}-${galera_arch}-gal/debs/ --recursive -np -R "index.html*" -nH --cut-dirs=4 --no-check-certificate ; then
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

