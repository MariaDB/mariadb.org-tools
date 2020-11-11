#!/bin/bash

set -x -v

tar -axvf /packages/mariadb-*.tar.gz -C /usr/local
mkdir /data
cd /usr/local/mariadb*
ln -s $PWD /usr/local/mariadb
# for server plugins
ln -s $PWD /usr/local/mysql
./scripts/mysql_install_db --basedir=$PWD --datadir=/data --user=buildbot
bin/mysqld_safe --datadir=/data --user=buildbot &

while [ ! -S /tmp/mysqld.sock ]
do
	echo waiting 3 seconds
	sleep 3
done
