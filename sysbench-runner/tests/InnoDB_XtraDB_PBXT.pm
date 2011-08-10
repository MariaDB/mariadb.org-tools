#!/usr/bin/env perl
use warnings;
use strict;


###############   Scenario 1 configuration   ####################
# Comparing the following scenarios:
# 1. MySQL 5.5.13 + InnoDB
# 2. MariaDB 5.2.7 + XtraDB
# 3. MariaDB 5.2.7 + PBXT


#common stuff
our $RUN		= 1; #Perform the actual tests
our $CLEANUP		= 1; #Cleanup after done with the test
our $PLOT		= 1; #Plot the graphics after the test is done

our $PROJECT_HOME	= $ENV{"HOME"}."/Projects/MariaDB";
our $SCRIPTS_HOME	= "$PROJECT_HOME/mariadb-tools/sysbench-runner/";
our $SYSBENCH_HOME	= "$PROJECT_HOME/sysbench/sysbench";
our $TEMP_DIR		= "$PROJECT_HOME/temp";
our $MAX_TIME		= 600;
our $WARMUP_TIME	= 600;
our $WARMUP_THREADS	= 24;
our $TABLES_COUNT	= 24;
our $TABLE_SIZE		= 2000000;
our $RESULTS_OUTPUT_DIR	= "$TEMP_DIR/BenchmarkResults/InnoDB_vs_XtraDB_vs_PBXT";
our $SOCKET		= "$TEMP_DIR/mysql.sock";
our $THREADS		= "1, 4, 8, 12, 16, 24, 32, 48, 64, 128";
our $READONLY		= 0;
our $PARALLEL_PREPARE	= 1;
our $PREPARE_THREADS	= 24;
our $GRAPH_HEADING	= "MySQL 5.5.13 + InnoDB vs. MariaDB 5.2.7 + XtraDB \\n vs. MariaDB 5.2.7 + PBXT";

our $MYSQL_USER		= "root";

my $CONFIG_HOME		= "$PROJECT_HOME/mariadb-tools/sysbench-runner/config";

our @configurations = (
		{
			#case specific
			DESCRIPTION	=> "MySQL 5.5.13 + InnoDB",
			DATA_SOURCE_DIR	=> "$TEMP_DIR/innodb",
			DATADIR		=> "$TEMP_DIR/data_workdir",
			DBNAME		=> "mysql_5_5_13",
			KEYWORD		=> "mysql_innodb",
			TABLE_ENGINE	=> "innodb",
			CONFIG_FILE	=> "$CONFIG_HOME/mysql_my.cnf",
			WORKLOAD	=> "$SYSBENCH_HOME/tests/db/oltp.lua",
			MYSQL_HOME	=> "$PROJECT_HOME/mysql-5.5.13-linux2.6-x86_64"
		},
		

		{
			#case specific
			DESCRIPTION	=> "MariaDB 5.2.7 + XtraDB",
			DATA_SOURCE_DIR	=> "$TEMP_DIR/innodb",
			DATADIR		=> "$TEMP_DIR/data_workdir",
			DBNAME		=> "mariadb_5_2_7",
			KEYWORD		=> "mariadb_xtradb", 
			TABLE_ENGINE	=> "innodb",
			CONFIG_FILE	=> "$CONFIG_HOME/mariadb_my.cnf",
			WORKLOAD	=> "$SYSBENCH_HOME/tests/db/oltp.lua",
			MYSQL_HOME	=> "$PROJECT_HOME/mariadb-5.2.7-Linux-x86_64"
		},


		{
			#case specific
			DESCRIPTION	=> "MariaDB 5.2.7 + PBXT",
			DATA_SOURCE_DIR	=> "$TEMP_DIR/pbxt",
			DATADIR		=> "$TEMP_DIR/data_workdir",
			DBNAME		=> "mariadb_5_2_7",
			KEYWORD		=> "mariadb_pbxt", 
			TABLE_ENGINE	=> "pbxt",
			CONFIG_FILE	=> "$CONFIG_HOME/mariadb_my.cnf",
			WORKLOAD	=> "$SYSBENCH_HOME/tests/db/oltp.lua",
			MYSQL_HOME	=> "$PROJECT_HOME/mariadb-5.2.7-Linux-x86_64"
		}
	);
1;

















