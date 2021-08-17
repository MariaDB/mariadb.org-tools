#!/bin/bash
set -xv
# Limitations coming from Percona
if [ "$sst_mode" == "xtrabackup-v2" ] ; then
  case $version_name in
    "bionic"|"focal")
      xtrabackup_version="0.1-5"
      ;;
    *)
      xtrabackup_version="0.1-4"
      ;;
  esac
fi
sudo killall mysqld
for i in 1 2 3 4 5 6 7 8 9 10 ; do
  if sudo ps -ef | grep -iE 'mysqld|mariadb' | grep -v grep ; then
    sleep 3
  else
    break
  fi
done
# We don't want crash recovery, but if mysqld hasn't stopped, we'll have to deal with it
sudo killall -s 9 mysqld
if [ "$sst_mode" == "mariabackup" ] ; then
# Starting from 10.3.6, MariaBackup packages have a generic name mariadb-backup.
# Before 10.3, MariaBackup packages have a version number in them, e.g. mariadb-backup-10.2 etc.
# First, try to find the generic package, if can't, then the name with the number
  mbackup=`ls debs/binary/ | grep -v ddeb | grep mariadb-backup_ | sed -e 's/^\(mariadb-backup\).*/\\1/' | uniq`
  if [ -z "$mbackup" ] ; then
    mbackup=`ls debs/binary/ | grep -v ddeb | grep mariadb-backup- | sed -e 's/^\(mariadb-backup-10\.[1-9]\).*/\\1/' | uniq`
    if [ -z "$mbackup" ] ; then
      echo "Test warning: mariabackup is not available for installing?"
      exit 1
    fi
  fi
  echo "Installing $mbackup"
  if ! sudo sh -c "DEBIAN_FRONTEND=noninteractive MYSQLD_STARTUP_TIMEOUT=180 apt-get install --allow-unauthenticated -y $mbackup socat" ; then
    echo "Test warning: failed to install MariaBackup"
    exit 1
  fi
elif [ "$sst_mode" == "xtrabackup-v2" ] ; then
  sudo wget https://repo.percona.com/apt/percona-release_${xtrabackup_version}.${version_name}_all.deb
  sudo dpkg -i percona-release_${xtrabackup_version}.${version_name}_all.deb
  sudo apt-get update
  if ! sudo sh -c "DEBIAN_FRONTEND=noninteractive MYSQLD_STARTUP_TIMEOUT=180 apt-get install --allow-unauthenticated -y percona-xtrabackup-24 socat" ; then
    echo "Test warning: could not install XtraBackup, check if it's available for this version/architecture"
    exit 1
  fi
fi
echo "Run MTR tests for the corresponding SST method ($sst_mode)"
sudo sh -c "DEBIAN_FRONTEND=noninteractive MYSQLD_STARTUP_TIMEOUT=180 apt-get install --allow-unauthenticated $allow_downgrades -y mariadb-test"
cd /usr/share/mysql/mysql-test
perl mysql-test-run.pl --vardir="$(readlink -f /dev/shm/var)" --force --max-save-core=0 --max-save-datadir=0 --big-test --suite=galera --do-test=galera_sst_${sst_mode}*
res=$?
rm -rf /home/buildbot/var
cp -r /dev/shm/var /home/buildbot
if [ $res -ne 0 ] ; then
    echo "ERROR: MTR tests failed"
    exit $res
fi
sudo cp -r /var/lib/mysql /var/lib/node1
sudo cp -r /var/lib/mysql /var/lib/node2
sudo cp -r /var/lib/mysql /var/lib/node3
sudo chown -R mysql:mysql /var/lib/node1 /var/lib/node2 /var/lib/node3
# To make sure that xtrabackup / mariabackup works with the right datadir
sudo mv /var/lib/mysql /var/lib/mysql.save
sudo sh -c "echo '
[galera]
wsrep-on
binlog-format=ROW
wsrep_sst_method=$sst_mode
wsrep_provider=libgalera_smm.so
' > /etc/mysql/conf.d/galera.cnf"
if [ "$sst_mode" == "mysqldump" ] ; then
  sudo sh -c "echo 'bind-address=0.0.0.0' >> /etc/mysql/conf.d/galera.cnf"
fi
if [ "$sst_mode" != "rsync" ] ; then
  sudo sh -c "echo 'wsrep_sst_auth=galera:gal3ra123' >> /etc/mysql/conf.d/galera.cnf"
fi
echo '
[mysqld]
port=8301
socket=/tmp/node1.sock
pid-file=/tmp/node1.pid
datadir=/var/lib/node1
server-id=1
log-error=node1.err
wsrep_cluster_address=gcomm://127.0.0.1:4566,127.0.0.1:4567?gmcast.listen_addr=tcp://127.0.0.1:4565
wsrep_node_address=127.0.0.1:4565
[mysqld_safe]
socket=/tmp/node1.sock
pid-file=/tmp/node1.pid
log-error=/var/lib/node1/node1.err
skip-syslog
' > /home/buildbot/node1.cnf
echo '
[mysqld]
port=8302
socket=/tmp/node2.sock
pid-file=/tmp/node2.pid
datadir=/var/lib/node2
server-id=2
log-error=node2.err
wsrep_cluster_address=gcomm://127.0.0.1:4565?gmcast.listen_addr=tcp://127.0.0.1:4566
wsrep_node_address=127.0.0.1:4566
[mysqld_safe]
socket=/tmp/node2.sock
pid-file=/tmp/node2.pid
log-error=/var/lib/node2/node2.err
skip-syslog
' > /home/buildbot/node2.cnf
echo '
[mysqld]
port=8303
socket=/tmp/node3.sock
pid-file=/tmp/node3.pid
datadir=/var/lib/node3
server-id=3
log-error=node3.err
wsrep_cluster_address=gcomm://127.0.0.1:4565?gmcast.listen_addr=tcp://127.0.0.1:4567
wsrep_node_address=127.0.0.1:4567
[mysqld_safe]
socket=/tmp/node3.sock
pid-file=/tmp/node3.pid
log-error=/var/lib/node3/node3.err
skip-syslog
' > /home/buildbot/node3.cnf
chmod uga+r /home/buildbot/node*.cnf
sudo mysqld_safe --defaults-extra-file=/home/buildbot/node1.cnf --user=mysql --wsrep-new-cluster &
mysql -uroot -prootpass --port=8301 --protocol=tcp -e "DROP database mgc IF EXISTS"
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 ; do
  sleep 2
  if mysql -uroot -prootpass --port=8301 --protocol=tcp -e "create database mgc; create table mgc.t1 (i int); insert into mgc.t1 values (1); select * from mgc.t1" ; then
    break
  fi
done
# We can't start both nodes at once, because it causes rsync port conflict
# (and maybe some other SST methods will have problems too)
for node in 2 3 ; do
  if [ "$sst_mode" == "rsync" ] ; then
    sudo killall rsync
  fi
  sudo mysqld_safe --defaults-extra-file=/home/buildbot/node$node.cnf --user=mysql &
  for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 ; do
    if ! mysql -uroot -prootpass --port=830$node --protocol=tcp -e "select * from mgc.t1" ; then
      sleep 3
    else
      break
    fi
  done
done
mysql -uroot -prootpass --port=8301 --protocol=tcp -e "show status like 'wsrep_cluster_size'"
sudo chmod uga+r /var/lib/node*/node*.err
if [ "$sst_mode" == "mariabackup" ] ; then
  mkdir /home/buildbot/mariabackup_logs
  for node in 1 2 3 ; do
    for log in prepare move backup ; do
      sudo cp /var/lib/node${node}/mariabackup.${log}.log /home/buildbot/mariabackup_logs/node${node}.mariabackup.${log}.log
    done
  done
  sudo chown -R buildbot:buildbot /home/buildbot/mariabackup_logs
fi
set -e
mysql -uroot -prootpass --port=8301 --protocol=tcp -e "show status like 'wsrep_cluster_size'" | grep 3
mysql -uroot -prootpass --port=8302 --protocol=tcp -e "select * from mgc.t1"
mysql -uroot -prootpass --port=8303 --protocol=tcp -e "select * from mgc.t1"
mysql -uroot -prootpass --port=8303 --protocol=tcp -e "drop table mgc.t1"
! mysql -uroot -prootpass --port=8302 --protocol=tcp -e "set wsrep_sync_wait=15; select * from mgc.t1"
! mysql -uroot -prootpass --port=8301 --protocol=tcp -e "set wsrep_sync_wait=15; select * from mgc.t1"

sudo pkill --signal 9 mysqld 2> /dev/null || true
sudo pkill --signal 9 mariadb 2> /dev/null || true
sudo pkill --signal 9 mysqld_safe 2> /dev/null || true
