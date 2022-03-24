# This script is run on a primary
CREATE USER 'repluser'@'%' IDENTIFIED BY 'replsecret';
GRANT REPLICATION SLAVE ON *.* TO 'repluser'@'%';
# This is run in case you want to do a mariadbdump (I will start with empty primary)
# FLUSH TABLES WITH READ LOCK;
SHOW MASTER STATUS;
# Do mariadbdump or alternatively start the slave with volume of existing DB(will not test this)
# mariadbdump -h <ip-address> -P 3306 -u root -p --all-databases --single-transaction --quick > ~/mariadb-backup/backup-111-$(date +%FT%T).sql
# After finishing on the slave run
# UNLOCK TABLE