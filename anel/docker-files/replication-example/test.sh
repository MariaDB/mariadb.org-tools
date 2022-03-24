#! bin/bash
echo "---------------Stoping the containers ---------------"
docker stop mariadb-primary mariadb-secondary-1
# Clean log files
echo "---------------Cleaning old logs ---------------"
rm -rf log-files-primary og-files-secondary1
if [ "$?" -eq 0 ]; then
echo "Files cleaned"
fi 

# config files stored in /etc/mysql/conf.d on a master
# data files stored in /var/lib/mysql we will not use them 
# log file stored in ( #-v ~/container-data/mariadb-log:/var/log/mysql )

# ------- Create the primary server ------- #
echo "---------------Start the primary ---------------"
docker run -d --rm --name mariadb-primary \
-v $PWD/config-files/primarycnf:/etc/mysql/conf.d:z \
-v $PWD/log-files-primary:/var/log/mysql \
-v $PWD/primaryinit:/docker-entrypoint-initdb.d:z \
-e MYSQL_ROOT_PASSWORD=secret \
mariadb:latest

# ------- Create the replica server ------- #
echo "---------------Start the replica ---------------"
docker run -d --rm --name mariadb-secondary-1 \
-v $PWD/config-files/secondarycnf:/etc/mysql/conf.d:z \
-v $PWD/log-files-secondary1:/var/log/mysql \
-v $PWD/secondaryinit:/docker-entrypoint-initdb.d:z \
-e MYSQL_ROOT_PASSWORD=secret \
mariadb:latest

# Check state
docker ps 
echo "--------------- Check primary logs ---------------"
docker logs mariadb-primary
echo "--------------- Check secondary logs ---------------"
docker logs mariadb-secondary-1

echo "--------------- Test primary ---------------"
docker exec -it mariadb-primary mariadb -uroot -psecret -e "show master status;"

echo "--------------- Test secondary ---------------"
docker exec -it mariadb-secondary-1 mariadb -uroot -psecret -e "show slave status\G;"

# Note you will need to change MASTER_HOST IP address in a secondary
echo "--------------- Get IP of master ---------------"
docker exec mariadb-primary cat /etc/hosts
