#!/bin/bash

set -x -v

tar -axvf /packages/mariadb-*.tar.gz -C /usr/local --exclude '*/include/mysql/server' --exclude '*/mysql-test' --exclude '*/sql-bench' --exclude '*/man' --exclude '*/support-files'
mkdir -p /data
cd /usr/local/mariadb-*
ln -s $PWD /usr/local/mariadb
# for server plugins
ln -s $PWD /usr/local/mysql
./scripts/mysql_install_db --basedir=$PWD --datadir=/data --user=buildbot
bin/mysqld_safe --datadir=/data --user=buildbot &

while [ ! -S /tmp/mysql.sock ]
do
	echo waiting 3 seconds
	sleep 3
done
