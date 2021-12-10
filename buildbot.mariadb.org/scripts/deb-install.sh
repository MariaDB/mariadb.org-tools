#!/bin/bash

set -ex
df -kT
dpkg -l | grep -iE 'maria|mysql|galera' || true
# We want a clean installation here
dpkg -l | grep -iE 'maria|mysql|galera' | awk '{print $2}' | xargs sudo apt-get remove -y
dpkg -l | grep -iE 'maria|mysql|galera' | awk '{print $2}' | xargs sudo apt-get purge -y

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

sudo sh -c "echo 'deb [trusted=yes] https://ci.mariadb.org/${tarbuildnum}/${parentbuildername}/debs .' >> /etc/apt/sources.list"

wget "https://ci.mariadb.org/${tarbuildnum}/${parentbuildername}/deb/Packages.gz" | gunzip -c > Packages
# Due to MDEV-14622 and its effect on Spider installation,
# Spider has to be installed separately after the server
package_list=`grep -B 1 'Source: mariadb-' Packages | grep 'Package:' | grep -vE 'galera|spider|columnstore' | awk '{print $2}' | xargs`
if grep -i spider debs/binary/Packages > /dev/null ; then
  spider_package_list=`grep -B 1 'Source: mariadb-' Packages | grep 'Package:' | grep 'spider' | awk '{print $2}' | xargs`
fi
if grep -i columnstore Packages > /dev/null ; then
  if [ "$arch" != "amd64" ] && [ "$arch" != "arm64" ]; then
    echo "Upgrade warning: Due to MCOL-4123, Columnstore won't be installed on $arch"
  else
    columnstore_package_list=`grep -B 1 'Source: mariadb-' Packages | grep 'Package:' | grep 'columnstore' | awk '{print $2}' | xargs`
  fi
fi
# Sometimes apt-get update fails because the repo is being updated.
for i in 1 2 3 4 5 6 7 8 9 10 ; do
  if sudo apt-get update ; then
    break
  fi
  echo "Upgrade warning: apt-get update failed, retrying ($i)"
  sleep 10
done
sudo sh -c "DEBIAN_FRONTEND=noninteractive MYSQLD_STARTUP_TIMEOUT=180 apt-get install -y $package_list $columnstore_package_list"
# MDEV-14622: Wait for mysql_upgrade running in the background to finish
res=1
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 ; do
if ps -ef | grep -iE 'mysql_upgrade|mysqlcheck|mysqlrepair|mysqlanalyze|mysqloptimize|mariadb-upgrade|mariadb-check' | grep -v grep ; then
  sleep 2
else
  res=0
  break
fi
done
if [[ $res -ne 0 ]] ; then
  echo "Upgrade warning: mysql_upgrade or alike have not finished in reasonable time, different problems may occur"
fi
# To avoid confusing errors in further logic, do an explicit check
# whether the service is up and running
if [[ "$systemdCapability" == "yes" ]] ; then
  if ! sudo systemctl status mariadb --no-pager ; then
    sudo journalctl -xe --no-pager
    echo "Upgrade warning: mariadb service isn't running properly after installation"
    if echo $package_list | grep columnstore ; then
      echo "It is likely to be caused by ColumnStore problems upon installation, getting the logs"
      set +e
      # It is done in such a weird way, because Columnstore currently makes its logs hard to read
      for f in `sudo ls /var/log/mariadb/columnstore | xargs` ; do
	f=/var/log/mariadb/columnstore/$f
	echo "----------- $f -----------"
	sudo cat $f
      done
      for f in /tmp/columnstore_tmp_files/* ; do
	echo "----------- $f -----------"
	sudo cat $f
      done
    fi
    echo "ERROR: mariadb service didn't start properly after installation"
    exit 1
  fi
fi
# Due to MDEV-14622 and its effect on Spider installation,
# Spider has to be installed separately after the server
if [ -n "$spider_package_list" ] ; then
  sudo sh -c "DEBIAN_FRONTEND=noninteractive MYSQLD_STARTUP_TIMEOUT=180 apt-get install -y $spider_package_list"
fi

# Unix socket
if [[ "$branch" == *"10."[4-9]* ]] ; then
  sudo mysql -e "set password=password('rootpass')"
else
  # Even without unix_socket, on some of VMs the password might be not pre-created as expected. This command should normally fail.
  mysql -uroot -e "set password = password('rootpass')" >> /dev/null 2>&1
fi

mysql --verbose -uroot -prootpass -e "create database test; use test; create table t(a int primary key) engine=innodb; insert into t values (1); select * from t; drop table t; drop database test; create user galera identified by 'gal3ra123'; grant all on *.* to galera;"
mysql -uroot -prootpass -e "select @@version"
echo "Test for MDEV-18563, MDEV-18526"
set +e
case "$systemdCapability" in
yes)
  sudo systemctl stop mariadb
  ;;
no)
  sudo /etc/init.d/mysql stop
  ;;
esac
sleep 1
sudo pkill -9 mysqld
for p in /bin /sbin /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin ; do
  if test -x $p/mysql_install_db ; then
    sudo $p/mysql_install_db --no-defaults --user=mysql --plugin-maturity=unknown
  else
    echo "$p/mysql_install_db does not exist"
  fi
done
sudo mysql_install_db --no-defaults --user=mysql --plugin-maturity=unknown
set +e
## Install mariadb-test for further use
#sudo sh -c "DEBIAN_FRONTEND=noninteractive MYSQLD_STARTUP_TIMEOUT=180 apt-get install -y mariadb-test"
if dpkg -l | grep -i spider > /dev/null ; then
  echo "Upgrade warning: Workaround for MDEV-22979, otherwise server hangs further in SST steps"
  sudo sh -c "DEBIAN_FRONTEND=noninteractive MYSQLD_STARTUP_TIMEOUT=180 apt-get remove --allow-unauthenticated -y mariadb-plugin-spider" || true
  sudo sh -c "DEBIAN_FRONTEND=noninteractive MYSQLD_STARTUP_TIMEOUT=180 apt-get purge --allow-unauthenticated -y mariadb-plugin-spider" || true
fi
if dpkg -l | grep -i columnstore > /dev/null ; then
  echo "Upgrade warning: Workaround for a bunch of Columnstore bugs, otherwise mysqldump in SST steps fails when Columnstore returns errors"
  sudo sh -c "DEBIAN_FRONTEND=noninteractive MYSQLD_STARTUP_TIMEOUT=180 apt-get remove --allow-unauthenticated -y mariadb-plugin-columnstore" || true
  sudo sh -c "DEBIAN_FRONTEND=noninteractive MYSQLD_STARTUP_TIMEOUT=180 apt-get purge --allow-unauthenticated -y mariadb-plugin-columnstore" || true
fi
