# This script is run on a primary
CREATE USER 'repluser'@'%' IDENTIFIED BY 'replsecret';
GRANT REPLICATION SLAVE ON *.* TO 'repluser'@'%';
CREATE DATABASE primary_db;
# It is not allowed to have inserts during initialization
#USE primary_db;
#CREATE TABLE primary_db.primary_tbl (name char(20));
#INSERT INTO primary_db.primary_tbl values 
# ("Anna"), ("Andrea"), ("Kaj"), ("Monty"), ("Ian"),
#("Vicentiu"), ("Daniel"), ("Faustin"),("Vlad"),
#("Anel");

# This is run in case you want to do a mariadbdump (I will start with empty primary)
# FLUSH TABLES WITH READ LOCK;
# SHOW MASTER STATUS;
# Do mariadbdump or alternatively start the slave with volume of existing DB(will not test this)
# mariadbdump -h <ip-address> -P 3306 -u root -p --all-databases --single-transaction --quick > ~/mariadb-backup/backup-111-$(date +%FT%T).sql
# After finishing on the slave run
# UNLOCK TABLE