These are the files that have been used while preparing the benchmark of MariaDB with DBT3 tests.


====== Prepare QGEN and DBGEN ======
Here are the steps to build QGEN and DBGEN and generate the queries and workload for MariaDB/MySQL test
NOTE: The folder where the branch lp:mariadb-tools have been downloaded will be referred to as {PROJECT_HOME}.

1. Go to http://sourceforge.net/projects/osdldbt/files/dbt3/

2. Download the archive for DBT3 1.9 into your project folder {PROJECT_HOME}

3. Unzip the archive into your project folder
	cd {PROJECT_HOME}
	tar -zxf dbt3-1.9.tar.gz

4. Copy the file tpcd.h into the dbt3 folder. This step includes the necessary labels for MySQL/MariaDB when building queries.
	cp {PROJECT_HOME}/mariadb-tools/dbt3_benchmark/dbt3_mysql/tpcd.h {PROJECT_HOME}/dbt3-1.9/src/dbgen

5. Copy the file Makefile into the dbt3 folder
NOTE: This step is executed only if you want to overwrite the default behaviour of PostgreSQL settings. After copying this Makefile and building the project, QGEN will
be set to generate queries for MariaDB/MySQL. If you skip this step, QGEN will generate queries for PostgreSQL by default.
	cp {PROJECT_HOME}/mariadb-tools/dbt3_benchmark/dbt3_mysql/Makefile {PROJECT_HOME}/dbt3-1.9/src/dbgen

6. Go to {PROJECT_HOME}/dbt3-1.9/src/dbgen and build the project
	cd {PROJECT_HOME}/dbt3-1.9/src/dbgen
	make

7. Set the variable DSS_QUERY to the folder with template queries for MariaDB/MySQL or for PostgreSQL
7.1. If you want to build the queries that fit MariaDB/MySQL dialect execute the following command:
	export DSS_QUERY={PROJECT_HOME}/mariadb-tools/dbt3_benchmark/dbt3_mysql/mysql_queries
7.2. If you want to use the default PostgreSQL templates, execute the following command:
	export DSS_QUERY={PROJECT_HOME}/dbt3-1.9/queries/pgsql

8. Create a directory to store the generated queries in
	mkdir $DSS_QUERY/generated 

9. Generate the queries
NOTE: The examples use scale factor 1. If you want different scale, change the value of -s parameter
	cd {PROJECT_HOME}/dbt3-1.9/src/dbgen
	./qgen -s 1 1 > $DSS_QUERY/generated/1.sql
	./qgen -s 1 2 > $DSS_QUERY/generated/2.sql
	./qgen -s 1 3 > $DSS_QUERY/generated/3.sql
	./qgen -s 1 4 > $DSS_QUERY/generated/4.sql
	./qgen -s 1 5 > $DSS_QUERY/generated/5.sql
	./qgen -s 1 6 > $DSS_QUERY/generated/6.sql
	./qgen -s 1 7 > $DSS_QUERY/generated/7.sql
	./qgen -s 1 8 > $DSS_QUERY/generated/8.sql
	./qgen -s 1 9 > $DSS_QUERY/generated/9.sql
	./qgen -s 1 10 > $DSS_QUERY/generated/10.sql
	./qgen -s 1 11 > $DSS_QUERY/generated/11.sql
	./qgen -s 1 12 > $DSS_QUERY/generated/12.sql
	./qgen -s 1 13 > $DSS_QUERY/generated/13.sql
	./qgen -s 1 14 > $DSS_QUERY/generated/14.sql
	./qgen -s 1 15 > $DSS_QUERY/generated/15.sql
	./qgen -s 1 16 > $DSS_QUERY/generated/16.sql
	./qgen -s 1 17 > $DSS_QUERY/generated/17.sql
	./qgen -s 1 18 > $DSS_QUERY/generated/18.sql
	./qgen -s 1 19 > $DSS_QUERY/generated/19.sql
	./qgen -s 1 20 > $DSS_QUERY/generated/20.sql
	./qgen -s 1 21 > $DSS_QUERY/generated/21.sql
	./qgen -s 1 22 > $DSS_QUERY/generated/22.sql

10. Generate the explain queries
	./qgen -s 1 -x 1 > $DSS_QUERY/generated/1_explain.sql
	./qgen -s 1 -x 2 > $DSS_QUERY/generated/2_explain.sql
	./qgen -s 1 -x 3 > $DSS_QUERY/generated/3_explain.sql
	./qgen -s 1 -x 4 > $DSS_QUERY/generated/4_explain.sql
	./qgen -s 1 -x 5 > $DSS_QUERY/generated/5_explain.sql
	./qgen -s 1 -x 6 > $DSS_QUERY/generated/6_explain.sql
	./qgen -s 1 -x 7 > $DSS_QUERY/generated/7_explain.sql
	./qgen -s 1 -x 8 > $DSS_QUERY/generated/8_explain.sql
	./qgen -s 1 -x 9 > $DSS_QUERY/generated/9_explain.sql
	./qgen -s 1 -x 10 > $DSS_QUERY/generated/10_explain.sql
	./qgen -s 1 -x 11 > $DSS_QUERY/generated/11_explain.sql
	./qgen -s 1 -x 12 > $DSS_QUERY/generated/12_explain.sql
	./qgen -s 1 -x 13 > $DSS_QUERY/generated/13_explain.sql
	./qgen -s 1 -x 14 > $DSS_QUERY/generated/14_explain.sql
	./qgen -s 1 -x 15 > $DSS_QUERY/generated/15_explain.sql
	./qgen -s 1 -x 16 > $DSS_QUERY/generated/16_explain.sql
	./qgen -s 1 -x 17 > $DSS_QUERY/generated/17_explain.sql
	./qgen -s 1 -x 18 > $DSS_QUERY/generated/18_explain.sql
	./qgen -s 1 -x 19 > $DSS_QUERY/generated/19_explain.sql
	./qgen -s 1 -x 20 > $DSS_QUERY/generated/20_explain.sql
	./qgen -s 1 -x 21 > $DSS_QUERY/generated/21_explain.sql
	./qgen -s 1 -x 22 > $DSS_QUERY/generated/22_explain.sql

Now the generated queries for MariaDB/MySQL test are ready and are stored into the folder {PROJECT_HOME}/mariadb-tools/dbt3_benchmark/dbt3_mysql/mysql_queries/generated.
Additional reorganization of directories is up to the user.

11. Create a temp directory
	mkdir {PROJECT_HOME}/temp

12. Set the variable DSS_PATH to the folder with the generated table data.The generated dataload for the test will be generated there.
	export DSS_PATH={PROJECT_HOME}/temp

13. Generate the table data
NOTE: The example uses scale factor = 1. If you want to change it, you should change the parameter -s.
	./dbgen -vfF -s 1

Now the generated data load is stored into the folder set in $DSS_PATH = {PROJECT_HOME}/temp


14. Open the file {PROJECT_HOME}/mariadb-tools/dbt3_benchmark/dbt3_mysql/make-dbt3-db_innodb.sql and edit the values for the call of the sql commands that look like this one:
	LOAD DATA LOCAL INFILE '/data/benchmarks/dataload/dbt3s1/nation.tbl' into table nation fields terminated by '|';
They all look the same but operate with different tables.
Replace "/data/benchmarks/dataload/dbt3s1" with it's real value {PROJECT_HOME}/temp - the path where the data load is prepared. 
At the end the same command could look like this:
	LOAD DATA LOCAL INFILE '~/Projects/dbt3/temp/nation.tbl' into table nation fields terminated by '|';

14. Download MariaDB and install it into a data directory for scale factor 1.
NOTE: The folder where MariaDB or MySQL is installed will be reffered as {MYSQL_HOME}
	mkdir {PROJECT_HOME}/temp/data_innodb_s1
	cd {MYSQL_HOME}
	./scripts/mysql_install_db --datadir={PROJECT_HOME}/temp/data_innodb_s1

15. Start the mysqld process
	./bin/mysqld_safe --defaults-file={PROJECT_HOME}/dbt3_mysql/mariadb_my.cnf --port=12340 --socket={PROJECT_HOME}/temp/mysql.sock  --datadir={PROJECT_HOME}/temp/data_innodb_s1/ &

16. Load the data into the database by executing the file make-dbt3-db.sql
	./bin/mysql -u root -P 12340 -S {PROJECT_HOME}/temp/mysql.sock < {PROJECT_HOME}/dbt3_mysql/make-dbt3-db.sql
Alternatively you can log into the database and copy/paste the separate blocks of that file, so that you can see and control the output and workflow of loading data.


17. Shutdown the results db server:
	./bin/mysqladmin --user=root --port=12340 --socket={PROJECT_HOME}/temp/mysql.sock shutdown 0

Now you have a database loaded with scale 1. Its datadir is {PROJECT_HOME}/temp/data_innodb_s1.

The same steps can be reproduced for different scale factors and for different storage engines