#!/bin/bash

set -xeuvo pipefail

if [ $# -eq 0 ]
then
	echo 'Error - URL of tarball required as argument'
	exit 1
fi

curl "$1" | tar -zxvf - -C /usr/local --exclude '*/include/mysql/server' --exclude '*/mysql-test' --exclude '*/sql-bench' --exclude '*/man' --exclude '*/support-files'
mkdir -p /data
cd /usr/local/mariadb-*
ln -s $PWD /usr/local/mariadb
# for server plugins
ln -s $PWD /usr/local/mysql
./scripts/mysql_install_db --basedir=$PWD --datadir=/data --user=buildbot
bin/mysqld_safe --datadir=/data --user=buildbot  --local-infile &

countdown=5
while [ ! -S /tmp/mysql.sock ] && [ $countdown -gt 0 ]
do
	echo waiting 3 seconds
	sleep 3
	countdown=$(( $countdown - 1 ))
done

[ -S /tmp/mysql.sock ] || exit 1
