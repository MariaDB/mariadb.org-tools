#! bin/bash
curuser="$USER"
curusergroup="$(id -gn)"
dirprimary="log-files-primary"
dirsecondary="log-files-secondary-1"
primary_name="mariadb-primary"
secondary_name="mariadb-secondary"
cleanOldFiles()
{
    dir=$1
    sudo chown "$curuser":"$curusergroup" -R "$dir"
    sudo rm -rf "$dir"
    if [ "$?" -eq 0 ]; then
        if [ "$dir" = "$dirprimary" ];then
            echo "Files from <primary> '$primary_name' cleaned!"
        else
            echo "Files from <secondary> '$secondary_name' cleaned!"
        fi
    fi 
}

# I want to stop mariadb service
if [ "$(systemctl is-active mariadb)" == "active" ]; then
    echo "Stopping mariadb service temporarly."
    sudo systemctl stop mariadb
fi

# Check is primary started, if it is stoped it
if [ "$(docker ps | grep $primary_name)" ]; then
    echo "---------------Stoping/Removing the primary container $primary_name ---------------"
    docker stop "$primary_name"
fi
# Check is/are secondary/ies started, if it is/are stoped it/them
if [ "$(docker ps | grep $secondary_name)" ]; then
    echo "---------------Stoping the seconary container $secondary_name ---------------"
    docker stop "$secondary_name"
fi

# Clean log files
echo "---------------Cleaning old logs ---------------"
if [ -d "$dirprimary" ]; then
    cleanOldFiles "$dirprimary"
fi

if [ -d "$dirsecondary" ]; then
  cleanOldFiles "$dirsecondary"
fi

# config files stored in /etc/mysql/conf.d on a master
# data files stored in /var/lib/mysql we will not use them 
# log file stored in ( #-v ~/container-data/mariadb-log:/var/log/mysql )

# ------- Create the primary server ------- #
echo "---------------START THE PRIMARY ---------------"
docker run -d --rm --name $primary_name \
-v $PWD/config-files/primarycnf:/etc/mysql/conf.d:z \
-v "$PWD/$dirprimary":/var/log/mysql \
-v $PWD/primaryinit:/docker-entrypoint-initdb.d:z \
-w /var/lib/mysql \
-e MYSQL_ROOT_PASSWORD=secret \
mariadb:latest

# ------- Create the replica server ------- #
echo "---------------START THE REPLICA ---------------"
docker run -d --rm --name $secondary_name \
-v $PWD/config-files/secondarycnf:/etc/mysql/conf.d:z \
-v "$PWD/$dirsecondary":/var/log/mysql \
-v $PWD/secondaryinit:/docker-entrypoint-initdb.d:z \
-e MYSQL_ROOT_PASSWORD=secret \
mariadb:latest

# Check state
docker ps 
echo "--------------- Check primary logs ---------------"
docker logs $primary_name
echo "--------------- Check secondary logs ---------------"
docker logs $secondary_name

echo "--------------- Test primary ---------------"
# Wait on primary
replication_started=$(docker exec -it $primary_name mariadb -uroot -psecret -e "show master status;")
replication_started=$?
while [ $replication_started -eq 1 ]
do
    #echo "replication_started: $replication_started"
    replication_started=$(docker exec -it $primary_name mariadb -uroot -psecret -e "show master status;")
    replication_started=$?
done
# Output the result of primary status
docker exec -it $primary_name mariadb -uroot -psecret -e "show master status;"

echo "--------------- Test secondary ---------------"
# Wait on secondary
replication_started=$(docker exec -it $secondary_name mariadb -uroot -psecret -e "show slave status\G;")
replication_started=$?
while [ $replication_started -eq 1 ]
do
    #echo "replication_started: $replication_started"
    output=$(docker exec -it $secondary_name mariadb -uroot -psecret -e "show slave status\G;")
    replication_started=$?
done
# Output the result of secondary status
docker exec -it $secondary_name mariadb -uroot -psecret -e "show slave status\G;"
# Note you will need to change MASTER_HOST IP address in a secondary
echo "--------------- Get IP of primary ---------------"
docker exec $primary_name cat /etc/hosts
# You will need to do: stop slave;change master to master_host='172.17.0.2'; again no problem in that case

echo "--------------- Test Replication ---------------"
echo "1. Write data on primary"
docker exec -it $primary_name mariadb -uroot -psecret \
-e "create database if not exists k8s; use k8s; create table t(t int); insert into t values (1),(2);"

echo "2. Check data on primary"
docker exec $primary_name mariadb -uroot -psecret -e "use k8s; select * from t;"

echo "3. Check binlog on primary"
docker exec $primary_name mariadb -uroot -psecret -e "show master status\G;"
docker exec $primary_name mariadb -uroot -psecret -e "show binary logs\G;"
docker exec $primary_name mariadb -uroot -psecret -e "mysqlbinlog --start-position=2393 --stop-position=3698 my-mariadb-bin.000001"
#docker exec $primary_name mariadb -uroot -psecret -e "show binlog events\G;" # A lot of rows

# Read data on replica (here have to wait until latest binlog gets to replica, how to check for that?)
echo "4. Read data on replica"
docker exec $secondary_name mariadb -uroot -psecret \
-e "show databases; use k8s; select * from t;"
# Show slave status
#docker exec $secondary_name mariadb -uroot -psecret -e "show slave status\G;"