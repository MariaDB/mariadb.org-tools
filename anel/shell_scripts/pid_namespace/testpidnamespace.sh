#! /bin/sh
echo "----- List PID namespaces  -----"
lsns -t pid # there are different type, check unshare to create isolated PID
# Output of ^ 
: '
        NS TYPE NPROCS   PID USER COMMAND
4026531836 pid      77  3078 anel /lib/systemd/systemd --user
'
# Grep one or more processes from namespace
echo "----- Get PIDs of mysqld -----"
set -- $(pgrep -x mysqld)
pid1=$1
shift
pid2=$1
echo "PID host: $pid1, PID container: $pid2"
# Note that I have host mysqld and container mysqld

echo "----- Get PID namespaces of mariadbd/mysqld -----"
echo "+++ Note: unnamed namespaces"
ps -eo pidns,pid,args|grep -E "mysqld|mariadbd"
# Output ^ (5165 is the container process, 13320 i a host process)
: '
         -  5165 mysqld
4026531836  7424 grep --color=auto -E mysqld|mariadbd
         - 13320 /usr/sbin/mysqld
'

echo "+++ Note: named namespaces with root are visible"
sudo lsns -p $pid1 -t pid
sudo lsns -p $pid1 -t pid
echo "+++ Alternative (see other namespace types)"
sudo ls -la /proc/13320/ns/|grep pid

echo "----- Testing PID namespace of ppgrep -----"
# This will return all PIDs from namespace of current PID
pgrep -x --nslist pid --ns $$ |wc -l
# Output ^ 77

echo "----- Errors testing pgrep -x --ns PID mysqld -----"
# !!!!   Errors   !!!!
# this doesn't work at all
echo "Applied from patch fb7c1b9415c9 doesn't work - not a valid command"
pgrep -x --ns $$ mysqld
echo $? # ends with 1

# this doesn't work also
echo "Applied from patch fb7c1b9415c9 with sudo doesn't work - not a valid command"
sudo pgrep -x --ns $$ mysqld
echo $?

echo "----- Errors testing pgrep --ns PID PID number -----"
# Try host
pgrep --ns $$ $pid1
echo $? # ends with 1
# Try container
pgrep --ns $$ $pid2
echo $? # ends with 1
# Cannot read even host PID
pgrep --ns $pid1
echo $?
# Even if we apply right host PID, we got the error (see lsns, unnamed namespace, bug?)

# Cannot read more namespaces of multiple PIDs
pgrep --ns $pid1 $pid2
echo $? # ends with 3

echo "----- Errors testing pgrep --ns PID|grep single process -----"
pgrep --ns `pgrep -x mysqld` | head -n 1
#pgrep --ns 13320  # the same is for containerized PID 5165
# Output ^: Error reading reference namespace information

echo "----- Errors testing pgrep --ns PID|grep multiple processes -----"
pgrep --ns `pgrep -x mysqld`

echo "------ SUGGESTED SOLUTION  ------"

set -- $(pgrep -x "mysqld|mariadbd")
echo "All PIDs: $@"
host_pid=0
for mysqld_pid in "$@"; do
  echo "+ Current PID analaysis: $mysqld_pid"
  # Process in child PID namespace has PID 1 in a 3.column
  cat /proc/$mysqld_pid/status |grep NSpid
  # If num of columns is 2 that means it is a host PID, if 2+ it is a container PID
  num_columns=$(cat /proc/$mysqld_pid/status |grep NSpid|wc -w)
  echo $num_columns
  echo "Who am I?"
  if [ $num_columns -eq 2 ]; then
    echo "I am host PID"
    host_pid=$mysqld_pid
  else
    echo "I am container PID"
  fi
done
echo "HOST PID: $host_pid"
sleep 2100
