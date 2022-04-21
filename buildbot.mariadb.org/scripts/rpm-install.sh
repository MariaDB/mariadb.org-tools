#!/usr/bin/env bash
# shellcheck disable=SC2154

set -e

# Buildbot installation test script
# this script can be called manually by providing the build URL as argument:
# ./rpm-install.sh "https://buildbot.mariadb.org/#/builders/368/builds/695"

# load common functions
# shellcheck disable=SC1091
. ./bash_lib.sh

# function to be able to run the script manually (see bash_lib.sh)
manual_run_switch "$1"

set -x

# print disk usage
df -kT

# # //TEMP this should be done in the VM preparation
# case "$master_branch" in
#   *mdev10416*)
#     sudo cat /etc/sysconfig/selinux | grep SELINUX || true
#     sudo sh -c \"PATH=$PATH:/usr/sbin getenforce || true\"
#     sudo sh -c \"PATH=$PATH:/usr/sbin setenforce Enforcing || true\"
#     sudo sh -c \"PATH=$PATH:/usr/sbin getenforce || true\"
#     ;;
# esac

rpm -qa | { grep -iE 'maria|mysql|galera' || true; }

# Try several times, to avoid sporadic "The requested URL returned error: 404"
made_cache=0
# shellcheck disable=SC2034
for i in 1 2 3 4 5; do
  sudo rm -rf /var/cache/yum/*
  sudo yum clean all
  case $HOSTNAME in
    rhel8*) sudo subscription-manager refresh ;;
  esac
  if sudo yum makecache; then
    made_cache=1
    break
  else
    sleep 5
  fi
done

if ((made_cache != 1)); then
  bb_log_err "failed to make cache"
  exit 1
fi
sudo yum search mysql | { grep "^mysql" || true; }
sudo yum search maria | { grep "^maria" || true; }
sudo yum search percona | { grep percona || true; }

# setup repository
sudo sh -c "echo '[galera]
name=galera
baseurl=https://rpm.mariadb.org/$master_branch/$arch
gpgkey=https://rpm.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1' >/etc/yum.repos.d/galera.repo"

sudo cat /etc/yum.repos.d/galera.repo
sudo yum -y --nogpgcheck install rpms/*.rpm
sh -c 'g=/usr/lib*/galera*/libgalera_smm.so; echo -e "[galera]\nwsrep_provider=$g"' | sudo tee /etc/my.cnf.d/galera.cnf
case "$systemdCapability" in
  yes)
    if ! sudo systemctl start mariadb; then
      sudo journalctl -lxn 500 --no-pager -u mariadb.service
      sudo systemctl -l status mariadb.service --no-pager
      exit 1
    fi
    ;;
  no)
    sudo /etc/init.d/mysql restart
    ;;
  *)
    bb_log_warn "should never happen, check your configuration (systemdCapability property is not set or is set to a wrong value)"
    ;;
esac
if [[ $master_branch == *"10."[4-9]* ]]; then
  bb_log_info "uninstallation of Cracklib plugin may fail if it wasn't installed, it's quite all right"
  if sudo mysql -e "uninstall soname 'cracklib_password_check.so'"; then
    # shellcheck disable=SC2034
    reinstall_cracklib_plugin="YES"
  fi
  sudo mysql -e "set password=''"
fi
mysql -uroot -e 'drop database if exists test; create database test; use test; create table t(a int primary key) engine=innodb; insert into t values (1); select * from t; drop table t;'
if find rpms/*.rpm | grep -qi columnstore; then
  mysql --verbose -uroot -e "create database cs; use cs; create table cs.t_columnstore (a int, b char(8)); insert into cs.t_columnstore select seq, concat('val',seq) from seq_1_to_10; select * from cs.t_columnstore"
  sudo systemctl restart mariadb
  mysql --verbose -uroot -e "select * from cs.t_columnstore; update cs.t_columnstore set b = 'updated'"
  sudo systemctl restart mariadb-columnstore
  mysql --verbose -uroot -e "update cs.t_columnstore set a = a + 10; select * from cs.t_columnstore"
fi
mysql -uroot -e 'show global status like "wsrep%%"'
bb_log_info "test for MDEV-18563, MDEV-18526"
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
for p in /bin /sbin /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin; do
  if test -x $p/mysql_install_db; then
    sudo $p/mysql_install_db --no-defaults --user=mysql --plugin-maturity=unknown
  else
    bb_log_warn "$p/mysql_install_db does not exist"
  fi
done
sudo mysql_install_db --no-defaults --user=mysql --plugin-maturity=unknown
set +e
bb_log_info "all done"
