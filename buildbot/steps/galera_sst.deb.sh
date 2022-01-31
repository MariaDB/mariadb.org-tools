########################################################################
# Galera SST test
########################################################################

#===============
# This test can be performed in different SST modes:
# - 'mariabackup'
# - 'mysqldump'
# - 'rsync'
# - 'xtrabackup-v2' -- Legacy, currently disabled and no longer supported
#===============

# Setting the path for some utilities on CentOS
export PATH="$PATH:/usr/sbin:/usr/bin:/sbin:/bin"

commandex()
{
    if [ -n "$BASH_VERSION" ]; then
        command -v "$1" || :
    elif [ -x "$1" ]; then
        echo "$1"
    else
        which "$1" || :
    fi
}

check_sockets_utils()
{
    lsof_available=0
    sockstat_available=0
    ss_available=0

    [ -n "$(commandex lsof)" ] && lsof_available=1
    [ -n "$(commandex sockstat)" ] && sockstat_available=1
    [ -n "$(commandex ss)" ] && ss_available=1

    if [ $lsof_available -eq 0 -a \
         $sockstat_available -eq 0 -a \
         $ss_available -eq 0 ]
    then
        echo "Neither lsof, nor sockstat or ss tool was found in" \
             "the PATH. Make sure you have it installed."
        store_logs
        exit 1
    fi
}

check_sockets_utils

#
# Check if the port is in the "listen" state.
# The first parameter is the PID of the process that should
# listen on the port - if it is not known, you can specify
# an empty string or zero.
# The second parameter is the port number.
# The third parameter is a list of the names of utilities
# (via "|") that can listen on this port during the state
# transfer.
#
check_port()
{
    local pid="${1:-0}"
    local port="$2"
    local utils="$3"

    [ $pid -le 0 ] && pid='[0-9]+'

    local rc=1

    if [ $lsof_available -ne 0 ]; then
        lsof -Pnl -i ":$port" 2>/dev/null | \
        grep -q -E "^($utils)[^[:space:]]*[[:space:]]+$pid[[:space:]].*\\(LISTEN\\)" && rc=0
    elif [ $sockstat_available -ne 0 ]; then
        local opts='-p'
        if [ "$OS" = 'FreeBSD' ]; then
            # sockstat on FreeBSD requires the "-s" option
            # to display the connection state:
            opts='-sp'
        fi
        sockstat "$opts" "$port" 2>/dev/null | \
        grep -q -E "[[:space:]]+($utils)[^[:space:]]*[[:space:]]+$pid[[:space:]].*[[:space:]]LISTEN" && rc=0
    elif [ $ss_available -ne 0 ]; then
        ss -nlpH "( sport = :$port )" 2>/dev/null | \
        grep -q -E "users:\\(.*\\(\"($utils)[^[:space:]]*\"[^)]*,pid=$pid(,[^)]*)?\\)" && rc=0
    else
        echo "Unknown sockets utility"
        store_logs
        exit 1
    fi

    return $rc
}

check_pid_and_port()
{
    local pid="$1"
    local addr="$2"
    local port="$3"

    local utils='mysqld|mariadbd'

    if ! check_port "$pid" "$port" "$utils"; then
        local port_info
        local busy=0

        if [ $lsof_available -ne 0 ]; then
            port_info=$(lsof -Pnl -i ":$port" 2>/dev/null | \
                        grep -F '(LISTEN)')
            echo "$port_info" | \
            grep -q -E "[[:space:]](\\*|\\[?::\\]?):$port[[:space:]]" && busy=1
        else
            local filter='([^[:space:]]+[[:space:]]+){4}[^[:space:]]+'
            if [ $sockstat_available -ne 0 ]; then
                local opts='-p'
                if [ "$OS" = 'FreeBSD' ]; then
                    # sockstat on FreeBSD requires the "-s" option
                    # to display the connection state:
                    opts='-sp'
                    # in addition, sockstat produces an additional column:
                    filter='([^[:space:]]+[[:space:]]+){5}[^[:space:]]+'
                fi
                port_info=$(sockstat "$opts" "$port" 2>/dev/null | \
                    grep -E '[[:space:]]LISTEN' | grep -o -E "$filter")
            else
                port_info=$(ss -nlpH "( sport = :$port )" 2>/dev/null | \
                    grep -F 'users:(' | grep -o -E "$filter")
            fi
            echo "$port_info" | \
            grep -q -E "[[:space:]](\\*|\\[?::\\]?):$port\$" && busy=1
        fi

        if [ $busy -eq 0 ]; then
            if ! echo "$port_info" | grep -qw -F "[$addr]:$port" && \
               ! echo "$port_info" | grep -qw -F -- "$addr:$port"
            then
                if [ -n "$pid" ] && ! ps -p $pid >/dev/null 2>&1; then
                    echo "server daemon (PID: $pid) terminated unexpectedly."
                    store_logs
                    exit 1
                fi
                return 1
            fi
        fi

        if ! check_port $pid "$port" "$utils"; then
            echo "server daemon port '$port'" \
                 "has been taken by another program"
            store_logs
            exit 1
        fi
    fi

    return 0
}

wait_port()
{
    local pid="$1"
    local addr="$2"
    local port="$3"
    for i in {0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29}; do
        if check_pid_and_port "$pid" "$addr" "$port"; then
            break
        fi
        echo "wait pid=${pid:-ANY} for port=$port..."
        sleep 2
    done
}

store_logs() {
  # Make sure we store all existing logs, whenever we decide to exit game
  set +e
  mkdir /home/buildbot/sst_logs
  sudo chmod uga+r /var/lib/node*/node*.err
  sudo cp /var/lib/node*/node*.err /home/buildbot/sst_logs
  if [ "$sst_mode" == "mariabackup" ] ; then
    mkdir /home/buildbot/sst_logs/mbackup
    for node in 1 2 3 ; do
      for log in prepare move backup ; do
        sudo cp /var/lib/node${node}/mariabackup.${log}.log /home/buildbot/sst_logs/mbackup/node${node}.mariabackup.${log}.log
      done
    done
    sudo chown -R buildbot:buildbot /home/buildbot/sst_logs
  fi
  ls -l /home/buildbot/sst_logs/
}

# Mandatory variables
for var in sst_mode arch version_name ; do
  if [ -z "${!var}" ] ; then
    echo "ERROR: $var variable is not defined"
    exit 1
  fi
done

# Limitations coming from Percona
if [ "$sst_mode" == "xtrabackup-v2" ] ; then
  case $version_name in
    "bionic"|"focal"|"groovy"|"hirsute"|"bullseye")
      xtrabackup_version="0.1-5"
      ;;
    *)
      xtrabackup_version="0.1-4"
      ;;
  esac
fi

sudo killall mysqld mariadbd || true

for i in 1 2 3 4 5 6 7 8 9 10 ; do
  if sudo ps -ef | grep -iE 'mysqld|mariadb' | grep -v grep ; then
    sleep 3
  else
    break
  fi
done

# We don't want crash recovery, but if mysqld hasn't stopped, we'll have to deal with it
sudo killall -s 9 mysqld mariadbd

if [ "$sst_mode" == "mariabackup" ] ; then
# Starting from 10.3.6, MariaBackup packages have a generic name mariadb-backup.
# Before 10.3, MariaBackup packages have a version number in them, e.g. mariadb-backup-10.2 etc.
# First, try to find the generic package, if can't, then the name with the number
  mbackup=`ls buildbot/debs/binary/ | grep -v ddeb | grep mariadb-backup_ | sed -e 's/^\(mariadb-backup\).*/\\1/' | uniq`
  if [ -z "$mbackup" ] ; then
    mbackup=`ls buildbot/debs/binary/ | grep -v ddeb | grep mariadb-backup- | sed -e 's/^\(mariadb-backup-10\.[1-9]\).*/\\1/' | uniq`
    if [ -z "$mbackup" ] ; then
      echo "Test warning: mariabackup is not available for installing?"
      exit 1
    fi
  fi
  echo "Installing $mbackup"
  if ! sudo sh -c "DEBIAN_FRONTEND=noninteractive MYSQLD_STARTUP_TIMEOUT=180 apt-get install --allow-unauthenticated -y $mbackup socat" ; then
    echo "Test warning: failed to install MariaBackup"
    store_logs
    exit 1
  fi
elif [ "$sst_mode" == "xtrabackup-v2" ] ; then
  sudo wget https://repo.percona.com/apt/percona-release_${xtrabackup_version}.${version_name}_all.deb
  sudo dpkg -i percona-release_${xtrabackup_version}.${version_name}_all.deb
  sudo apt-get update
  if ! sudo sh -c "DEBIAN_FRONTEND=noninteractive MYSQLD_STARTUP_TIMEOUT=180 apt-get install --allow-unauthenticated -y percona-xtrabackup-24 socat" ; then
    echo "Test warning: could not install XtraBackup, check if it's available for this version/architecture"
    store_logs
    exit 1
  fi
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
res=1
set +x
echo "Waiting till the first node comes up..."
for i in 1 2 3 4 5 ; do
  wait_port "" "127.0.0.1" "8301"
  sleep 3
  if mysql -uroot -prootpass --port=8301 --protocol=tcp -e "create database mgc; create table mgc.t1 (i int); insert into mgc.t1 values (1)" ; then
    res=0
    break
  fi
done
set -x
if [ "$res" != "0" ] ; then
  echo "ERROR: Failed to start the first node or to create the table"
  store_logs
  exit 1
fi
mysql -uroot -prootpass --port=8301 --protocol=tcp -e "select * from mgc.t1"

# We can't start both nodes at once, because it causes rsync port conflict
# (and maybe some other SST methods will have problems too)
for node in 2 3 ; do
  sudo mysqld_safe --defaults-extra-file=/home/buildbot/node$node.cnf --user=mysql &
  res=1
  set +x
  echo "Waiting till node $node comes up..."
  for i in 1 2 3 4 5 ; do
    wait_port "" "127.0.0.1" "830$node"
    sleep 3
    if mysql -uroot -prootpass --port=830$node --protocol=tcp -e "select * from mgc.t1" ; then
      res=0
      break
    fi
  done
  set -x
  if [ "$res" != "0" ] ; then
    echo "ERROR: Failed to start node $node or to connect to it after the start"
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
! mysql -uroot -prootpass --port=8302 --protocol=tcp -e "set wsrep_sync_wait=15; select * from mgc.t1"
! mysql -uroot -prootpass --port=8301 --protocol=tcp -e "set wsrep_sync_wait=15; select * from mgc.t1"
