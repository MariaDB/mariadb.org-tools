# Restore data from mariadbdump from primary (I wont do that, starting from fresh instance)

# Change master related settings
CHANGE MASTER TO
  MASTER_HOST='172.17.0.2',
  MASTER_USER='repluser',
  MASTER_PASSWORD='replsecret',
  MASTER_PORT=3306,
  MASTER_CONNECT_RETRY=10;
  #MASTER_LOG_FILE='my-mariadb-bin.000096', # this is needed only after doing mariadbdump
  #MASTER_LOG_POS=568,# this is needed only after doing mariadbdump

# Start slave and show status
#START SLAVE;
#SHOW SLAVE STATUS\G