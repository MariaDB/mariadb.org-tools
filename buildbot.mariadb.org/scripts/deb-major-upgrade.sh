#!/bin/bash
set -ex

dpkg -l | grep -iE 'maria|mysql|galera' || true
old_ver=`dpkg -l | grep -iE 'mysql-server-|mariadb-server-' | head -1 | awk '{print $2}' | sed -e "s/.*\(mysql\|mariadb\)-server-\(5\.[567]\|10\.[0-9]\).*/\\1-\\2/"`

sudo sh -c "echo 'deb [trusted=yes] https://ci.mariadb.org/${tarbuildnum}/${parentbuildername}/debs .' >> /etc/apt/sources.list"

package_version=$mariadb_version
packages_to_install="mariadb-server mariadb-client libmariadbclient18"

case "${old_ver}-${mariadb_version}" in
mysql-5.7-10.[0-1])
  echo "Upgrade warning: cannot downgrade from InnoDB 5.7 to 5.6"
  exit
  ;;
mysql-5.[67]-5.5)
  echo "Upgrade warning: cannot downgrade from InnoDB $old_ver to 5.5"
  exit
  ;;
mariadb-10.[0-9]-5.5)
  echo "Upgrade warning: Downgrade from $old_ver to 5.5 is not expected to work"
  exit
  ;;
mariadb-10.[0-9]-10.[0-9])
  if [[ "$old_ver" > "mariadb-$mariadb_version" ]] ; then
    echo "Upgrade warning: Downgrade from $old_ver to $major_version is not expected to work"
    exit
  fi
  if [[ "$old_ver" == "mariadb-$mariadb_version" ]]
  then
    # 3rd column is the package version, e.g. 10.1.23-9+deb9u1 vs 10.1.23+maria-1~stretch
    if ! dpkg -l | grep -i mariadb-server- | head -1 | awk '{print $3}' | grep maria
    then
      echo "Upgrade warning: MDEV-11979 - cannot upgrade from Debian packages to MariaDB packages of the same major version"
      exit
    fi
  fi
  ;;
mysql*-8.0-*)
  echo "Upgrade warning: live upgrade from MySQL 8.0 is not supported, re-installation with dump/restore will be performed instead"
  replace_incompatible_version=8.0
  ;;
*)
  echo "Upgrade from MySQL $old_ver to MariaDB ${mariadb_version} will be attempted"
  ;;
esac

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

# Sometimes apt-get update fails because the repo is being updated.
for i in 1 2 3 4 5 6 7 8 9 10 ; do
  if sudo apt-get update ; then
    break
  fi
  echo "Upgrade warning: apt-get update failed, retrying ($i)"
  sleep 10
done
# On some of VMs the password might be not pre-created as expected
if mysql -uroot -e "set password = password('rootpass')" ; then
  echo "The password has now been set"
# Or, Debian packages local root might be using unix_socket plugin even with older versions.
# Change it to the normal password authentication
elif sudo mysql -uroot -e "update mysql.user set plugin = 'mysql_native_password'; flush privileges; set password = password('rootpass')" ; then
  echo "The error above does not mean a test failure, it's one of expected outcomes"
  echo "Unix socket authentication has been unset"
else
  echo "Errors above do not mean a test failure, it's one of expected outcomes"
fi
mysql -uroot -prootpass -e "CREATE DATABASE if not exists mytest"
mysql -uroot -prootpass -e "use mytest; drop table if exists upgrade_test; create table upgrade_test (pk int primary key auto_increment, c char(64), v varchar(2048), d date, t time, dt datetime, ts timestamp) engine=InnoDB; begin; insert into upgrade_test values (null, 'test', 'test', date(now()), time(now()), now(), now());  insert into upgrade_test select null, 'test', 'test', date(now()), time(now()), now(), now() from upgrade_test; insert into upgrade_test select null, 'test', 'test', date(now()), time(now()), now(), now() from upgrade_test; insert into upgrade_test select null, 'test', 'test', date(now()), time(now()), now(), now() from upgrade_test; insert into upgrade_test select null, 'test', 'test', date(now()), time(now()), now(), now() from upgrade_test; insert into upgrade_test select null, 'test', 'test', date(now()), time(now()), now(), now() from upgrade_test; insert into upgrade_test select null, 'test', 'test', date(now()), time(now()), now(), now() from upgrade_test; insert into upgrade_test select null, 'test', 'test', date(now()), time(now()), now(), now() from upgrade_test; insert into upgrade_test select null, 'test', 'test', date(now()), time(now()), now(), now() from upgrade_test; insert into upgrade_test select null, 'test', 'test', date(now()), time(now()), now(), now() from upgrade_test; insert into upgrade_test select null, 'test', 'test', date(now()), time(now()), now(), now() from upgrade_test; insert into upgrade_test select null, 'test', 'test', date(now()), time(now()), now(), now() from upgrade_test; insert into upgrade_test select null, 'test', 'test', date(now()), time(now()), now(), now() from upgrade_test; commit" --force
mysql -uroot -prootpass --skip-column-names -e "select @@version" | awk -F'-' '{ print $1 }' > /tmp/version.old
old_version=`cat /tmp/version.old`
# If the tested branch has the same version as the public repository,
# upgrade won't work properly. For releasable branches, we will return an error
# urging to bump the version number. For other branches, we will abort the test
# with a warning (which nobody will read). This is done upon request from
# development, as temporary branches might not be rebased in a timely manner
if [ "$package_version" == "$old_version" ] ; then
    echo "ERROR: Server version $package_version has already been released. Bump the version number!"
    for b in $releasable_branches ; do
	if [ "$b" == "$branch" ] ; then
	    exit 1
	fi
    done
    echo "The test will be skipped, as upgrade will not work properly"
    exit 0
fi
mysql -uroot -prootpass -e "CREATE DATABASE autoinc; CREATE TABLE autoinc.t_autoinc(a SERIAL) ENGINE=InnoDB SELECT 42 a"
mysql -uroot -prootpass -e "CREATE TABLE autoinc.t_autoinc2(a SERIAL) ENGINE=InnoDB; BEGIN; INSERT INTO autoinc.t_autoinc2 VALUES (NULL),(NULL); ROLLBACK; SHOW CREATE TABLE autoinc.t_autoinc2 \G"
if [ -n "$replace_incompatible_version" ] ; then
  mysqldump -uroot -prootpass -E --triggers --routines --databases mytest autoinc > ~/mysql.dump
# See notes in MDEV-21179, possibly more adjustments will have to be added here with time
  sed -i 's/utf8mb4_0900_ai_ci/utf8mb4_general_ci/g' ~/mysql.dump
  sudo apt-get purge -y `dpkg -l | grep mysql | grep "$replace_incompatible_version" | grep -E '^ii' | awk '{ print $2 }' | xargs`
# On some reason apt-get purge for 8.0.18 doesn't remove /var/lib/mysql, maybe because mysql-common-5.8 remains
  sudo mv /var/lib/mysql /var/lib/mysql.backup.$replace_incompatible_version || true
fi
sudo sh -c "DEBIAN_FRONTEND=noninteractive MYSQLD_STARTUP_TIMEOUT=180 apt-get install --allow-unauthenticated -y $packages_to_install"
if [ -n "$replace_incompatible_version" ] ; then
# Since we re-installed system tables, we need to adjust the password again
  if sudo mysql -uroot -e "set password = password('rootpass')" ; then
    echo "The password has now been set"
  elif sudo mysql -uroot -e "update mysql.user set plugin = 'mysql_native_password'; flush privileges; set password = password('rootpass')" ; then
    echo "The error above does not mean a test failure, it's one of expected outcomes"
    echo "Unix socket authentication has been unset"
  else
    echo "Errors above do not mean a test failure, it's one of expected outcomes"
  fi
  mysql -uroot -prootpass < ~/mysql.dump
fi
mysql -uroot -prootpass --skip-column-names -e "INSERT INTO autoinc.t_autoinc SET a=NULL;  SELECT COUNT(*) Expect_2 FROM autoinc.t_autoinc WHERE a>=42"
echo "Prior to MDEV-6076, the next SELECT would return 1. After MDEV-6076, it should be 3"
mysql -uroot -prootpass --skip-column-names -e "INSERT INTO autoinc.t_autoinc2 VALUES (NULL); SELECT * FROM autoinc.t_autoinc2"
mysql -uroot -prootpass -e "select @@version, @@version_comment"
mysql -uroot -prootpass --skip-column-names -e "select @@version" | awk -F'-' '{ print $1 }' > /tmp/version.new
echo "The next line must show a difference between versions, otherwise it's a failure"
echo "It can be a false positive if we forgot to bump version after release,"
echo "or if the tree is based on an old version"
! diff -u  /tmp/version.old  /tmp/version.new
sudo cat /var/lib/mysql/mysql_upgrade_info | awk -F'-' '{ print $1 }' > /tmp/version.upgrade
# mysql_upgrade is run automatically in deb packages
# TODO: something weird goes on with mysql_upgrade, to be checked later
#diff -u /tmp/version.new /tmp/version.upgrade
cat /tmp/version.new
cat /tmp/version.upgrade
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
  sudo systemctl --no-pager restart mariadb
  systemctl --no-pager status mariadb
  sudo journalctl -lxn 500 --no-pager | grep -iE 'mysqld|mariadb'
  # It does not do the same as systemctl now
  # /etc/init.d/mysql status
  ;;
no)
  echo "Steps related to systemd will be skipped"
  ;;
*)
  echo "It should never happen, check your configuration (systemdCapability property is not set or is set to a wrong value)"
  ;;
esac
mysql -uroot -prootpass -e "use mytest; select count(*) from upgrade_test"
# Workaround for MDEV-20298
# and for libdbd-mariadb-perl not "pretending" to be DBD:mysql
#if ! dpkg -l | grep -E 'libdbd-mysql-perl|libdbd-mariadb-perl' ; then
if ! dpkg -l | grep libdbd-mysql-perl ; then
  sudo apt-get install -y libdbd-mysql-perl
fi
perl -MDBD::mysql -e print
