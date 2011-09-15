#!/usr/bin/env perl
use warnings;
use strict;

our $QUERIES_AT_ONCE	= 0; #If set to 1, then all the queries are executed sequentally without restarting the server between queries.
our $CLEAR_CACHES	= 1; #Clearing server caches
our $USER_IS_ADMIN	= 0; #This matters only for clearing caches since the command requires super user rights
our $WARMUP		= 0; #perform a warm-up before running the tests
our $EXPLAIN		= 1; #run an Explain command prior the run of the test
our $RUN		= 1; #perform the actual test

our $SCALE_FACTIOR	= 10; #The scale factor that will be tested against. It is used also for logging the final result into the results database.

our $PROJECT_HOME	= $ENV{"HOME"}."/Projects/dbt3";
our $TEMP_DIR		= "$PROJECT_HOME/temp";
our $QUERIES_HOME	= "/data_old/benchmarks/dbt3_queries/gen_s$SCALE_FACTIOR"; #Where the queries are stored.

our $MYSQL_HOME		= "$PROJECT_HOME/mysql-5.6.2-m5-linux2.6-x86_64"; #Where the instalation folder of MariaDB / MySQL / PostgreSQL is located
our $MYSQL_USER		= "root";
our $CONFIG_FILE	= "$PROJECT_HOME/mariadb-tools/dbt3_benchmark/config/mysql_my.cnf"; #The config file that mysqld or postgres will use when starting
our $SOCKET		= "$TEMP_DIR/mysql.sock";
our $PORT		= 12340; 
our $DATADIR		= "/data_old/benchmarks/datadir/mysql/myisam_s$SCALE_FACTIOR"; #Where is the datadir for mysqld or postgres
our $DBNAME		= "dbt3"; #The database name that will be used for the test
our $NUM_TESTS		= 3; #how many times will the same query be executed in order to calculate the average run time
our $WARMUPS_COUNT	= 0; #how many times will the query be warmed up before taking the results into account
our $CLUSTER_SIZE	= 3; #how big is one cluster with test results
our $MAX_QUERY_TIME	= 360; #What is the maximum time allowed for testing one query.
our $TIMEOUT		= 120; #What is the timeout of running one query, Currently works only with MariaDB/MySQL
our $OS_STATS_INTERVAL	= 5; #what the interval between each statistics extract will be
our $KEYWORD		= "mysql_5_6_2_myisam"; #This text will be stored into the results database as a keyword. Also will be used as a name for a subfolder with results and statistics.
our $DBMS		= "MySQL"; #Database Management System that will be used. Possible values: "MySQL", "MariaDB" and "PostgreSQL"
our $STORAGE_ENGINE	= "MyISAM"; #The storage engine that was used
our $STARTUP_PARAMS	= ""; #Any startup parameters that will be used while starting the mysqld process or postgres process
our $GRAPH_HEADING	= "MySQL 5.6.2 + MyISAM"; #The heading of the graphic


our $PRE_RUN_SQL	= "flush status; set global userstat=on;"; #This only executes if $RUN is set to 1
our $POST_RUN_SQL	= "show status; select * from information_schema.STATISTICS;"; #This only executes if $RUN is set to 1
our $PRE_TEST_SQL	= ""; #Cannot be overridden in the different configurations. SQL commands are run prior the whole test
our $POST_TEST_SQL	= ""; #Cannot be overridden in the different configurations. SQL commands are run after the whole test

our $PRE_RUN_OS		= ""; #OS commands that will be executed before each run
our $POST_RUN_OS	= ""; #OS commands that will be executed after each run
our $PRE_TEST_OS	= ""; #Cannot be overridden in the different configurations. OS commands are run prior the whole test
our $POST_TEST_OS	= ""; #Cannot be overridden in the different configurations. OS commands are run after the whole test


#Results Database
our $RESULTS_MYSQL_HOME		= "$PROJECT_HOME/mariadb-5.3.1_bin";
our $RESULTS_MYSQL_USER		= "root";
our $RESULTS_DATADIR		= "/data_old/benchmarks/datadir/dbt3_results_db";
our $RESULTS_CONFIG_FILE	= "$PROJECT_HOME/mariadb-tools/dbt3_benchmark/config/mariadb_my.cnf";
our $RESULTS_SOCKET		= "$TEMP_DIR/mysql_results.sock";
our $RESULTS_PORT		= 12341; #Should be different than the $PORT value above
our $RESULTS_STARTUP_PARAMS	= "";
our $RESULTS_DB_NAME		= "dbt3_results";


#case specific
our @configurations = (
		{
			QUERY 		=> "1.sql",
			EXPLAIN_QUERY	=> "1_explain.sql"
		},
		{
			QUERY 		=> "2.sql",
			EXPLAIN_QUERY	=> "2_explain.sql"
		},
		{
			QUERY 		=> "3.sql",
			EXPLAIN_QUERY	=> "3_explain.sql"
		},
		{
			QUERY 		=> "4.sql",
			EXPLAIN_QUERY	=> "4_explain.sql"
		},
		{
			QUERY 		=> "5.sql",
			EXPLAIN_QUERY	=> "5_explain.sql"
		},
		{
			QUERY 		=> "6.sql",
			EXPLAIN_QUERY	=> "6_explain.sql"
		},
		{
			EXPLAIN		=> 0,	#Explain of this query takes enormous amount of time on MySQL
			QUERY 		=> "7.sql",
			EXPLAIN_QUERY	=> "7_explain.sql"
		},
		{
			EXPLAIN		=> 0,	#Explain of this query takes enormous amount of time on MySQL
			QUERY 		=> "8.sql",
			EXPLAIN_QUERY	=> "8_explain.sql"
		},
		{
			EXPLAIN		=> 0,	#Explain of this query takes enormous amount of time on MySQL
			QUERY 		=> "9.sql",
			EXPLAIN_QUERY	=> "9_explain.sql"
		},
		{
			QUERY 		=> "10.sql",
			EXPLAIN_QUERY	=> "10_explain.sql"
		},
		{
			QUERY 		=> "11.sql",
			EXPLAIN_QUERY	=> "11_explain.sql"
		},
		{
			QUERY 		=> "12.sql",
			EXPLAIN_QUERY	=> "12_explain.sql"
		},
		{
			EXPLAIN		=> 0,	#Explain of this query takes enormous amount of time on MySQL
			QUERY 		=> "13.sql",
			EXPLAIN_QUERY	=> "13_explain.sql"
		},
		{
			QUERY 		=> "14.sql",
			EXPLAIN_QUERY	=> "14_explain.sql"
		},
		{
			QUERY 		=> "15.sql",
			EXPLAIN_QUERY	=> "15_explain.sql"
		},
		{
			QUERY 		=> "16.sql",
			EXPLAIN_QUERY	=> "16_explain.sql"
		},
		{
			QUERY 		=> "17.sql",
			EXPLAIN_QUERY	=> "17_explain.sql"
		},
		{
			QUERY 		=> "18.sql",
			EXPLAIN_QUERY	=> "18_explain.sql"
		},
		{
			QUERY 		=> "19.sql",
			EXPLAIN_QUERY	=> "19_explain.sql"
		},
		{
			QUERY 		=> "20.sql",
			EXPLAIN_QUERY	=> "20_explain.sql"
		},
		{
			QUERY 		=> "21.sql",
			EXPLAIN_QUERY	=> "21_explain.sql"
		},
		{
			QUERY 		=> "22.sql",
			EXPLAIN_QUERY	=> "22_explain.sql"
		}
);

1;