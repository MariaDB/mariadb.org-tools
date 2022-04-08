#! /bin/bash
primary_name="mariadb-primary"
secondary_name="mariadb-secondary"
dirsecondary="log-files-secondary"
num_replicas=2

docker ps |grep $primary_name

for i in $(seq $num_replicas)
do 
    echo "Starting replica/secondary $i"
    docker run -d --rm --name "$secondary_name-$i" \
    -v $PWD/config-files/secondarycnf:/etc/mysql/conf.d:z \
    -v "$PWD/$dirsecondary-$i":/var/log/mysql \
    -v $PWD/secondaryinit:/docker-entrypoint-initdb.d:z \
    -e MYSQL_ROOT_PASSWORD=secret \
    mariadb:latest

done