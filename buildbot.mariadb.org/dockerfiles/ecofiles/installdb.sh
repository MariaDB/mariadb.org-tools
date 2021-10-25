#!/bin/bash

set -xeuvo pipefail

if [ $# -eq 0 ]
then
	echo 'Error - URL of tarball required as argument'
	exit 1
fi

curl "$1" | tar -zxvf - -C /usr/local --exclude '*/include/mysql/server' --exclude '*/mysql-test' --exclude '*/sql-bench' --exclude '*/man' --exclude '*/support-files'
shift
mkdir -p /data
cd /usr/local/mariadb-*
ln -s $PWD /usr/local/mariadb
# for server plugins
ln -s $PWD /usr/local/mysql
./scripts/mysql_install_db --basedir=$PWD --datadir=/data --user=buildbot
bin/mysqld_safe --datadir=/data --user=buildbot  --local-infile --plugin-maturity=unknown "$@" &

countdown=5
while [ ! -S /tmp/mysql.sock ] && [ $countdown -gt 0 ]
do
	echo waiting 3 seconds
	sleep 3
	countdown=$(( $countdown - 1 ))
done

if [ ! -S /tmp/mysql.sock ]
then
	cat /data/*err
	exit 1
fi

/usr/local/mariadb/bin/mysql -e 'create user if not exists root;
	set password for root = password("") ;
	grant all on *.* TO root with grant option;
	drop user if exists ""@localhost;
	execute immediate concat("drop user if exists \"\"@",@@hostname);
	show create user root;
       	show grants for root;
	drop user if exists root@localhost'
