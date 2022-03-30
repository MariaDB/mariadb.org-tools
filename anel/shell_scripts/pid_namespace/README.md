# How to test
1. install mariadb-server from apt manager (ubuntu has 10.1 default)
2. start mariadb/mysql container to get mysqld/mariadbd
```bash
$ docker container run --name mysql-cont --rm MYSQL_ROOT_PASSWORD=secret -d mysql
```
3. Run the script and obtain the results (I stored mine in a file)
```bash
$ ./testpidnamespace.sh >results.txt 2>&1
```
