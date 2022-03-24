# Restore data from mariadbdump from primary (I wont do that, starting from fresh instance)

# Grant privileges for restored DB or any other DB to a user (note I could create that user from -e var)
CREATE USER 'repluser'@'%' IDENTIFIED BY 'replsecret';
grant all privileges on *.* to 'repluser'@'%';

# Stop/reset slave
STOP SLAVE;
RESET SLAVE;

# Change master related settings
CHANGE MASTER TO
  MASTER_HOST='mariadb-primary', # or containerID
  MASTER_USER='repluser',
  MASTER_PASSWORD='replsecret',
  MASTER_PORT=3306,
  MASTER_CONNECT_RETRY=10;
  #MASTER_LOG_FILE='master1-bin.000096', # this is needed only after doing mariadbdump
  #MASTER_LOG_POS=568,# this is needed only after doing mariadbdump

# Start slave and show status
START SLAVE;
SHOW SLAVE STATUS\G