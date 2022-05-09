#!/usr/bin/env bash
# shellcheck disable=SC2154

set -e

# Buildbot installation test script
# this script can be called manually by providing the build URL as argument:
# ./script.sh "https://buildbot.mariadb.org/#/builders/171/builds/7351"

# load common functions
# shellcheck disable=SC1091
. ./bash_lib.sh

store_logs() {
  # Make sure we store all existing logs, whenever we decide to exit game
  set +e
  mkdir /home/buildbot/logs
  for log in /var/log/daemon.log /var/log/syslog; do
    [[ -f $log ]] && sudo cp $log /home/buildbot/logs
  done
  # It looks like buildbot may be enveloping the path into single quotes
  # if it has wildcards, as in '/var/lib/node*/node*.err'.
  # Trying to get rid of the wildcards
  for node in 1 2 3; do
    sudo cp /var/lib/node${node}/node${node}.err /home/buildbot/logs
  done
  if [[ $sst_mode == "mariabackup" ]]; then
    for node in 1 2 3; do
      for log in prepare move backup; do
        if [[ -f /var/lib/node${node}/mariabackup.${log}.log ]]; then
          sudo cp /var/lib/node${node}/mariabackup.${log}.log /home/buildbot/logs/node${node}.mariabackup.${log}.log
        fi
      done
    done
    sudo chown -R buildbot:buildbot /home/buildbot/logs
  fi
  sudo chmod -R +r /home/buildbot/logs
  ls -l /home/buildbot/logs
}

# function to be able to run the script manually (see bash_lib.sh)
manual_run_switch "$1"

# Mandatory variables
for var in arch master_branch version_name sst_mode; do
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

# //TEMP probably need to remove mysqld in the future
bb_log_info "make sure mariadb is not running"
for process in mariadbd mysqld; do
  if pgrep $process >/dev/null; then
    sudo killall $process >/dev/null
  fi
done

# give mariadb the time to shutdown
for i in 1 2 3 4 5 6 7 8 9 10; do
  if pgrep 'mysqld|mariadbd'; then
    bb_log_info "give mariadb the time to shutdown ($i)"
    sleep 3
  else
    break
  fi
done

# We don't want crash recovery, but if mariadb hasn't stopped, we'll have to
# deal with it
for process in mariadbd mysqld; do
  if pgrep $process >/dev/null; then
    sudo killall -s 9 $process >/dev/null
  fi
done

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
  apt_get_update
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
  bb_log_info "still waiting for first node comes up ($i)..."
  sleep 2
  if mysql -uroot -prootpass --port=8301 --protocol=tcp -e "create database mgc; create table mgc.t1 (i int); insert into mgc.t1 values (1)"; then
    res=0
    break
  fi
  date +'%Y-%m-%dT%H:%M:%S%z'
  sudo tail -n 5 /var/lib/node1/node1.err || true
done
set -x
if [ "$res" != "0" ]; then
  bb_log_err "failed to start the first node or to create the table"
  store_logs
  exit 1
fi
mysql -uroot -prootpass --port=8301 --protocol=tcp -e "select * from mgc.t1\G"

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
  for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
    sleep 5
    # echoing to 2>/dev/null because we do not want mysql connection error to
    # be printed ERROR 2002 (HY000): Can't connect to MySQL server on 'localhost'
    if mysql -uroot -prootpass --port=830$node --protocol=tcp -e "select * from mgc.t1\G" 2>/dev/null; then
      res=0
      break
    fi
    bb_log_info "still waiting for node $node to come up ($i)..."
    date +'%Y-%m-%dT%H:%M:%S%z'
    sudo tail -n 5 /var/lib/node${node}/node${node}.err || true
  done
  set -x
  if [ "$res" != "0" ]; then
    bb_log_err "failed to start node $node or to connect to it after the start"
    store_logs
    exit 1
  fi
  mysql -uroot -prootpass --port=830$node --protocol=tcp -e "select * from mgc.t1\G"
done

mysql -uroot -prootpass --port=8301 --protocol=tcp -e "show status like 'wsrep_cluster_size'"

store_logs

set -e
mysql -uroot -prootpass --port=8301 --protocol=tcp -e "show status like 'wsrep_cluster_size'" | grep 3

for node in 2 3; do
  mysql -uroot -prootpass --port=830${node} --protocol=tcp -e "select * from mgc.t1\G"
done

mysql -uroot -prootpass --port=8303 --protocol=tcp -e "drop table mgc.t1"
# check that previous drop was replicated to other nodes
for node in 2 1; do
  if mysql -uroot -prootpass --port=830${node} --protocol=tcp -e "set wsrep_sync_wait=15; use mgc; show tables" | grep -q t1; then
    bb_log_err "modification on node 3 was not replicated on node ${node}"
    mysql -uroot -prootpass --port=830${node} --protocol=tcp -e "use mgc; show tables"
    exit 1
  fi
done

bb_log_info "stop cluster"
sudo killall -s 9 mariadbd || true
sudo killall -s 9 mysqld || true
sudo killall -s 9 mysqld_safe || true

bb_log_ok "all done"
