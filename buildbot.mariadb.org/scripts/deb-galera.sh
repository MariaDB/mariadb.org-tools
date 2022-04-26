#!/usr/bin/env bash
# shellcheck disable=SC2154

set -e

# Buildbot installation test script
# this script can be called manually by providing the build URL as argument:
# ./deb-install.sh "https://buildbot.mariadb.org/#/builders/171/builds/7351"

# load common functions
# shellcheck disable=SC1091
. ./bash_lib.sh

store_logs() {
  # Make sure we store all existing logs, whenever we decide to exit game
  set +e
  mkdir /home/buildbot/sst_logs
  # It looks like buildbot may be enveloping the path into single quotes
  # if it has wildcards, as in '/var/lib/node*/node*.err'.
  # Trying to get rid of the wildcards
  sudo chmod uga+r /var/lib/node1/node1.err /var/lib/node2/node2.err /var/lib/node3/node3.err
  sudo cp /var/lib/node1/node1.err /var/lib/node2/node2.err /var/lib/node3/node3.err /home/buildbot/sst_logs
  if [[ $sst_mode == "mariabackup" ]]; then
    mkdir /home/buildbot/sst_logs/mbackup
    for node in 1 2 3; do
      for log in prepare move backup; do
        sudo cp /var/lib/node${node}/mariabackup.${log}.log /home/buildbot/sst_logs/mbackup/node${node}.mariabackup.${log}.log
      done
    done
    sudo chown -R buildbot:buildbot /home/buildbot/sst_logs
  fi
  ls -l /home/buildbot/sst_logs/
}

# function to be able to run the script manually (see bash_lib.sh)
manual_run_switch "$1"

# Mandatory variables
for var in sst_mode arch version_name; do
  if [[ -z $var ]]; then
    bb_log_err "$var is not defined"
    exit 1
  fi
done

# Limitations coming from Percona
if [[ $sst_mode == "xtrabackup-v2" ]]; then
  case $version_name in
    "bionic" | "focal" | "groovy" | "hirsute" | "bullseye")
      xtrabackup_version="0.1-5"
      ;;
    *)
      xtrabackup_version="0.1-4"
      ;;
  esac
fi

sudo killall mysqld mariadbd || true

# give mariadb the time to shutdown
for i in 1 2 3 4 5 6 7 8 9 10; do
  if pgrep 'mysqld|mariadbd'; then
    sleep 3
  else
    break
  fi
done

# We don't want crash recovery, but if mysqld hasn't stopped, we'll have to deal with it
if pgrep 'mysqld|mariadbd'; then
  sudo killall -s 9 mysqld mariadbd
fi

if [[ $sst_mode == "mariabackup" ]]; then
  # Starting from 10.3.6, MariaBackup packages have a generic name mariadb-backup.
  # Before 10.3, MariaBackup packages have a version number in them, e.g. mariadb-backup-10.2 etc.
  # First, try to find the generic package, if can't, then the name with the number

  if ((${master_branch/10./} > 3)); then
    mbackup="mariadb-backup"
  else
    #//TEMP to be tested !!
    mbackup=$(apt-cache search mariadb-backup | grep -v dbgsym | awk '{print $1}' | uniq)
    if [[ -z $mbackup ]]; then
      bb_log_warn "mariabackup is not available for installing?"
      exit 1
    fi
  fi
  bb_log_info "installing $mbackup"
  if ! sudo sh -c "DEBIAN_FRONTEND=noninteractive MYSQLD_STARTUP_TIMEOUT=180 apt-get install --allow-unauthenticated -y $mbackup socat"; then
    bb_log_warn "failed to install MariaBackup"
    exit 1
  fi
elif [[ $sst_mode == "xtrabackup-v2" ]]; then
  wget "https://repo.percona.com/apt/percona-release_${xtrabackup_version}.${version_name}_all.deb"
  sudo dpkg -i "percona-release_${xtrabackup_version}.${version_name}_all.deb"
  sudo apt-get update
  if ! sudo sh -c "DEBIAN_FRONTEND=noninteractive MYSQLD_STARTUP_TIMEOUT=180 apt-get install --allow-unauthenticated -y percona-xtrabackup-24 socat"; then
    bb_log_warn "could not install XtraBackup, check if it's available for this version/architecture"
    exit 1
  fi
fi

# # //TEMP not done by corp, should we?
# bb_log_info "run MTR tests for the corresponding SST method ($sst_mode)"
# sudo sh -c "DEBIAN_FRONTEND=noninteractive MYSQLD_STARTUP_TIMEOUT=180 apt-get install --allow-unauthenticated $allow_downgrades -y mariadb-test"
# cd /usr/share/mysql/mysql-test
# perl mysql-test-run.pl --vardir="$(readlink -f /dev/shm/var)" --force --max-save-core=0 --max-save-datadir=0 --big-test --suite=galera --do-test="galera_sst_${sst_mode}*"
# res=$?
# rm -rf /home/buildbot/var
# cp -r /dev/shm/var /home/buildbot
# if ((res != 0)); then
#   bb_log_err "MTR tests failed"
#   exit $res
# fi

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

if [[ $sst_mode == "mysqldump" ]]; then
  sudo sh -c "echo 'bind-address=0.0.0.0' >> /etc/mysql/conf.d/galera.cnf"
fi

if [[ $sst_mode != "rsync" ]]; then
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
' >/home/buildbot/node1.cnf

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
' >/home/buildbot/node2.cnf

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
' >/home/buildbot/node3.cnf

chmod uga+r /home/buildbot/node*.cnf

sudo mysqld_safe --defaults-extra-file=/home/buildbot/node1.cnf --user=mysql --wsrep-new-cluster &
res=1
set +x
bb_log_info "waiting till the first node comes up..."
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
  sleep 2
  if mysql -uroot -prootpass --port=8301 --protocol=tcp -e "create database mgc; create table mgc.t1 (i int); insert into mgc.t1 values (1)"; then
    res=0
    break
  fi
  date "+%H:%M:%S"
  sudo tail -n 5 /var/lib/node1/node1.err || true
done
set -x
if [ "$res" != "0" ]; then
  bb_log_err "failed to start the first node or to create the table"
  store_logs
  exit 1
fi
mysql -uroot -prootpass --port=8301 --protocol=tcp -e "select * from mgc.t1"

# We can't start both nodes at once, because it causes rsync port conflict
# (and maybe some other SST methods will have problems too)
for node in 2 3; do
  if [[ $sst_mode == "rsync" ]]; then
    sudo killall rsync
  fi
  sudo mysqld_safe --defaults-extra-file=/home/buildbot/node$node.cnf --user=mysql &
  res=1
  set +x
  bb_log_info "waiting till node $node comes up..."
  # shellcheck disable=SC2034
  for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
    sleep 5
    if mysql -uroot -prootpass --port=830$node --protocol=tcp -e "select * from mgc.t1"; then
      res=0
      break
    fi
    date "+%H:%M:%S"
    tail -n 5 /var/lib/node${node}/node${node}.err || true
  done
  set -x
  if [ "$res" != "0" ]; then
    bb_log_err "failed to start node $node or to connect to it after the start"
    store_logs
    exit 1
  fi
  mysql -uroot -prootpass --port=830$node --protocol=tcp -e "select * from mgc.t1"
done

mysql -uroot -prootpass --port=8301 --protocol=tcp -e "show status like 'wsrep_cluster_size'"

store_logs

set -e
mysql -uroot -prootpass --port=8301 --protocol=tcp -e "show status like 'wsrep_cluster_size'" | grep 3
mysql -uroot -prootpass --port=8302 --protocol=tcp -e "select * from mgc.t1"
mysql -uroot -prootpass --port=8303 --protocol=tcp -e "select * from mgc.t1"
mysql -uroot -prootpass --port=8303 --protocol=tcp -e "drop table mgc.t1"

# //TEMP I don't understand this test but it's not validated by shellcheck
# shellcheck disable=SC2251
! mysql -uroot -prootpass --port=8302 --protocol=tcp -e "set wsrep_sync_wait=15; select * from mgc.t1"
! mysql -uroot -prootpass --port=8301 --protocol=tcp -e "set wsrep_sync_wait=15; select * from mgc.t1"
