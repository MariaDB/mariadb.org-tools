#! bin/bash
curuser="$USER"
curusergroup="$(id -gn)"
dirprimary="log-files-primary"
dirsecondary="log-files-secondary"
primary_name="mariadb-primary"
secondary_name="mariadb-secondary"
num_replicas=2
cleanOldFiles()
{
    dir=$1
    sudo chown "$curuser":"$curusergroup" -R "$dir"
    sudo rm -rf "$dir"
    if [ "$?" -eq 0 ]; then
        if [ "$dir" = "$dirprimary" ];then
            echo "Files from <primary> '$primary_name' cleaned!"
        else
            if [ $num_replicas -gt 1 ];then
                echo "Files from <secondary> '$secondary_name'-${dir: -1} cleaned!"
            else
                echo "Files from <secondary> '$secondary_name'-${dir: -1} cleaned!"
            fi
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
for i in $(seq $num_replicas)
do
    if [ "$(docker ps | grep "$secondary_name-$i")" ]; then
        echo "---------------Stoping the secondary container $secondary_name-$i ---------------"
        docker stop "$secondary_name-$i"
    fi
    echo -e "\n"
done
# Clean log files
echo "---------------Cleaning old logs ---------------"
if [ -d "$dirprimary" ]; then
    cleanOldFiles "$dirprimary"
fi
for i in $(seq $num_replicas)
do
    if [ -d "$dirsecondary-$i" ]; then
    cleanOldFiles "$dirsecondary-$i"
    fi
done

# config files stored in /etc/mysql/conf.d on a master
# data files stored in /var/lib/mysql we will not use them 
# log file stored in ( #-v ~/container-data/mariadb-log:/var/log/mysql )

# ------- Create the primary server ------- #
echo -e "\n---------------START THE PRIMARY ---------------\n"
docker run -d --rm --name $primary_name \
-v $PWD/config-files/primarycnf:/etc/mysql/conf.d:z \
-v "$PWD/$dirprimary":/var/log/mysql \
-v $PWD/primaryinit:/docker-entrypoint-initdb.d:z \
-w /var/lib/mysql \
-e MYSQL_ROOT_PASSWORD=secret \
-e MYSQL_INITDB_SKIP_TZINFO=Y \
mariadb:latest

# ------- Create the replica server ------- #
echo -e "\n---------------START THE REPLICA ---------------\n"
for i in $(seq $num_replicas)
do
    echo "Starting replica #$i"
    docker run -d --rm --name "$secondary_name-$i" \
    -v $PWD/config-files/"secondary-$i":/etc/mysql/conf.d:z \
    -v "$PWD/$dirsecondary-$i":/var/log/mysql \
    -v $PWD/secondaryinit:/docker-entrypoint-initdb.d:z \
    -e MYSQL_ROOT_PASSWORD=secret \
    -e MYSQL_INITDB_SKIP_TZINFO=Y \
    mariadb:latest
    echo -e "\n"
done

# Check state
echo -e "\n--------------- Check the state ---------------\n"
docker ps 
echo -e "\n--------------- Check primary logs ---------------\n"
docker logs $primary_name
echo -e "\n--------------- Check secondary logs ---------------\n"
for i in $(seq $num_replicas)
do
    echo "Check secondary log #$i"
    docker logs "$secondary_name-$i"
    echo -e "\n"
done

echo -e "\n--------------- Test primary ---------------\n"
# Wait on primary
: '
# One could use this command, but since needs time for master status, it is not applicable
if [ "$( docker container inspect -f '{{.State.Status}}' $container_name )" == "running" ]; then
'
replication_started=$(docker exec -it $primary_name mariadb -uroot -psecret -e "show master status;")
replication_started=$?
while [ $replication_started -eq 1 ]
do
    #echo "replication_started: $replication_started"
    replication_started=$(docker exec -it $primary_name mariadb -uroot -psecret -e "show master status;")
    replication_started=$?
done
sleep 1
# Output the result of primary status
docker exec -it $primary_name mariadb -uroot -psecret -e "show master status;"
# ^ can return an error, don't know how to get deterministic test sleep added
echo $?

echo -e "\n--------------- Test first/second secondary ---------------\n"
# Wait on secondary (same as for primary)
for i in $(seq $num_replicas); do
    replication_started=$(docker exec -it "$secondary_name-$i" mariadb -uroot -psecret -e "show slave status\G;")
    replication_started=$?
    while [ $replication_started -eq 1 ]
    do
        #echo "replication_started: $replication_started"
        output=$(docker exec -it "$secondary_name-$i" mariadb -uroot -psecret -e "show slave status\G;")
        replication_started=$?
    done

    # Output the result of secondary status
    echo -e "Show Slave Status for Replica $i \n"
    docker exec -it "$secondary_name-$i" mariadb -uroot -psecret -e "show slave status\G;"
    echo -e "\n"
done

# Note you will need to change MASTER_HOST IP address in a secondary

echo "--------------- Get IP of primary ---------------"
docker exec $primary_name cat /etc/hosts
# You will need to do: stop slave;change master to master_host='172.17.0.2'; again no problem in that case

echo -e "\n--------------- Test Replication - Primary ---------------\n"
echo -e "Primary test 1. Write data on primary to new database \n"
docker exec -it $primary_name mariadb -uroot -psecret \
-e "create database if not exists k8s; use k8s; create table t(t int); insert into t values (1),(2);"

echo -e "Primary test 2. Check data on primary\n"
docker exec $primary_name mariadb -uroot -psecret -e "use k8s; select * from t;"

echo -e "Primary test 3. Show master status\n"
docker exec $primary_name mariadb -uroot -psecret -e "show master status\G;"
echo -e "Primary test 4. Show binary logs\n"
docker exec $primary_name mariadb -uroot -psecret -e "show binary logs\G;"
echo -e "Primary test 5. Show mariadb-binlog\n"
docker exec $primary_name mariadb-binlog -uroot -psecret --start-position=0 --stop-position=4 my-mariadb-bin.000001
echo -e "Primary test 6. Show binlog events 1\n"
docker exec $primary_name mariadb -uroot -psecret "show binlog events in 'my-mariadb-bin.000001'"
echo -e "Primary test 7. Show binlog events 2\n"
docker exec $primary_name mariadb -uroot -psecret "show binlogs events in 'my-mariadb-bin.000002'"
#docker exec $primary_name mariadb -uroot -psecret -e "show binlog events\G;" # A lot of rows

for i in $(seq $num_replicas); do
    echo -e "\n--------------- Test Replication - Secondary $i ---------------\n"
    # Read data on replica (here have to wait until latest binlog gets to replica, how to check for that?)
    echo "Replica $i test 1. Get database on replica $i"
    docker exec "$secondary_name-$i" mariadb -uroot -psecret \
    -e "show databases;"
    echo "Replica $i test 2. Get data from database on replica $i"
    docker exec "$secondary_name-$i" mariadb -uroot -psecret \
    -e "select * from k8s.t"
done

echo -e "\n--------------- Open questions ---------------\n"
echo "Q1 : How to deterministally conclude the time needed to start the primary/secondaries ?"
# Show slave status
#docker exec $secondary_name mariadb -uroot -psecret -e "show slave status\G;"