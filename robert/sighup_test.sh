#! /bin/bash

# The test assumes MariaDB 10.4+

# Change the paths to point to your local installation
#export PATH=$MARIAI/bin/:$MARIAI/scripts:$PATH
client_bin=$MARIAI/bin/mysql
server_bin=$MARIAI/bin/mysqld
install_bin=$MARIAI/scripts/mysql_install_db
set -x

echo '----Setup new datadir----'
datadir_path='/tmp/test_datadir'
mkdir -p $datadir_path
$install_bin --datadir=$datadir_path

echo '----Start the server in a new login-shell terminal----'
xterm -ls -e $server_bin --datadir=$datadir_path &
xterm_pid=$!

echo '----Wait for server to get ready----'
sleep 3

echo '----Create new user----'
sudo $client_bin -e 'create user test_user@localhost;'

echo '----Delete guest user----'
sudo $client_bin -e 'drop user if exists ""@localhost;'

echo '----The new user should be able to connect----'
sudo $client_bin -utest_user -e 'select 1;'

echo '----Delete the user from the system tables, but ACL user should still exist----'
sudo $client_bin -e 'truncate table mysql.global_priv;'

echo '----Kill the terminal parent of mysqld----'
kill $xterm_pid
sleep 2

echo '----When killing the terminal sends a SIGHUP to mysqld, mysqld shouldnt reload the user table, thus the next login should work----'
sudo $client_bin -utest_user -e 'select 1;'

echo '----Cleanup----'
pkill mysqld
sleep 2
rm -rf $datadir_path

