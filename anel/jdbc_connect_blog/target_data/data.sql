create table t(t int);
insert into t values (1),(2);

# Invoke for localhost

#create table t_jdbc engine=connect
#                    table_type=JDBC
#                    tabname=t
#                    connection='jdbc:mariadb://localhost/test?user=root&password';
#select * from t_jdbc;

# Invoke for sources
# check hostname -I first and change connection url
create table db_mariadb_target engine=connect table_type=JDBC tabname=t_maria connection='jdbc:mariadb://mariadb-source/db_maria?user=root&password';
create table db_mysql_target engine=connect table_type=JDBC tabname=t_mysql connection='jdbc:mariadb://mysql-source/db_mysql?user=root&password';

create server 'oracle1' foreign data wrapper 'oracle' options (
HOST 'jdbc:oracle:thin:@oracle-source:1521:xe',
DATABASE 'XE',
USER 'system',
PASSWORD 'oracle',
PORT 0,
SOCKET '',
OWNER 'SYSTEM');

create server 'oracle2' foreign data wrapper 'oracle' options (
HOST 'jdbc:oracle:thin:@oracle-source:1521:xe',
DATABASE 'XEPDB1',
USER 'system',
PASSWORD 'oracle',
PORT 0,
SOCKET '',
OWNER 'SYSTEM');