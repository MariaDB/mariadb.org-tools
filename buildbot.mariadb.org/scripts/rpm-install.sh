#!/bin/bash
set -ex
branch=${1:-bb-10.8-release}
df -kT
case "$branch" in
*mdev10416*)
  sudo cat /etc/sysconfig/selinux | grep SELINUX || true
  sudo sh -c \"PATH=$PATH:/usr/sbin getenforce || true\"
  sudo sh -c \"PATH=$PATH:/usr/sbin setenforce Enforcing || true\"
  sudo sh -c \"PATH=$PATH:/usr/sbin getenforce || true\"
  ;;
esac
rpm -qa | { grep -iE 'maria|mysql|galera' || true; }
# Try several times, to avoid sporadic "The requested URL returned error: 404"
made_cache=0
for i in 1 2 3 4 5 ; do
  sudo rm -rf /var/cache/yum/*
  sudo yum clean all
  case $HOSTNAME in
    rhel8*) sudo subscription-manager refresh ;;
  esac
  if sudo yum makecache ; then
    made_cache=1
    break
  else
    sleep 5
  fi
done
if [ "$made_cache" != "1" ] ; then
  echo "Failed to make cache"
  exit 1
fi
sudo yum search mysql | { grep "^mysql" || true; }
sudo yum search maria | { grep "^maria" || true; }
sudo yum search percona | { grep percona || true; }
sudo sh -c "echo '[galera]
name=galera
baseurl=http://yum.mariadb.org/galera/repo/rpm/$arch
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1' > /etc/yum.repos.d/galera.repo"
# Update galera.repo to point at either the galera-3 or galera-4 test repo
case "$branch" in
  *10.[1-3]*)
    sudo sed -i 's/repo/repo3/' /etc/yum.repos.d/galera.repo
    ;;
  *10.[4-9]*)
    sudo sed -i 's/repo/repo4/' /etc/yum.repos.d/galera.repo
    ;;
esac
sudo cat /etc/yum.repos.d/galera.repo
sudo yum -y --nogpgcheck install rpms/*.rpm
sh -c 'g=/usr/lib*/galera*/libgalera_smm.so; echo -e "[galera]\nwsrep_provider=$g"' | sudo tee /etc/my.cnf.d/galera.cnf
case "$systemdCapability" in
yes)
  if ! sudo systemctl start mariadb ; then
    sudo journalctl -lxn 500 --no-pager -u mariadb.service
    sudo systemctl -l status mariadb.service --no-pager
    exit 1
  fi
  ;;
no)
  sudo /etc/init.d/mysql restart
  ;;
*)
  echo "It should never happen, check your configuration (systemdCapability property is not set or is set to a wrong value)"
  ;;
esac
if [[ "$branch" == *"10."[4-9]* ]] ; then
  echo "Uninstallation of Cracklib plugin may fail if it wasn't installed, it's quite all right"
  if sudo mysql -e "uninstall soname 'cracklib_password_check.so'" ; then
    reinstall_cracklib_plugin="YES"
  fi
  sudo mysql -e "set password=''"
fi
mysql -uroot -e 'drop database if exists test; create database test; use test; create table t(a int primary key) engine=innodb; insert into t values (1); select * from t; drop table t;'
if ls rpms/*.rpm | grep -i columnstore > /dev/null 2>&1 ; then
  mysql --verbose -uroot -e "create database cs; use cs; create table cs.t_columnstore (a int, b char(8)); insert into cs.t_columnstore select seq, concat('val',seq) from seq_1_to_10; select * from cs.t_columnstore"
  sudo systemctl restart mariadb
  mysql --verbose -uroot -e "select * from cs.t_columnstore; update cs.t_columnstore set b = 'updated'"
  sudo systemctl restart mariadb-columnstore
  mysql --verbose -uroot -e "update cs.t_columnstore set a = a + 10; select * from cs.t_columnstore"
fi
mysql -uroot -e 'show global status like "wsrep%%"'
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
echo "All done"
