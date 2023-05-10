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
