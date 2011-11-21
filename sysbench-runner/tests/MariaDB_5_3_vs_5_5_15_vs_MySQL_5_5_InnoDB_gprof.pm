#!/usr/bin/env perl
use warnings;
use strict;


###############   Scenario 1 configuration   ####################
# Comparing the following scenarios:
# 1. MariaDB 5.3.2 + XtraDB
# 2. MariaDB 5.5.15 + XtraDB
# 3. MySQL 5.5.19 + InnoDB
# 4. MariaDB 5.2.9 + XtraDB

#common stuff
our $RUN		= 1; #Perform the actual tests
our $CLEANUP		= 1; #Cleanup after done with the test
our $PLOT		= 1; #Plot the graphics after the test is done
our $WARMUP		= 0; #Perform a warmup

our $PROJECT_HOME	= $ENV{"HOME"}."/benchmark/sysbench/";
our $SCRIPTS_HOME	= "$PROJECT_HOME/mariadb-tools/sysbench-runner/";
our $SYSBENCH_HOME	= "$PROJECT_HOME/sysbench/sysbench";
our $TEMP_DIR		= "$PROJECT_HOME/temp";
our $RUN_DELAY		= 60;
our $WARMUP_DELAY	= 0;
our $MAX_TIME		= 600;
our $WARMUP_TIME	= 600;
our $WARMUP_THREADS	= 1;
our $TABLES_COUNT	= 24;
our $TABLE_SIZE		= 2000000;
our $RESULTS_OUTPUT_DIR	= "$PROJECT_HOME/results/MariaDB_5_3_2_vs_5_5_15_vs_MySQL_5_5_19_InnoDB";
our $SOCKET		= "$TEMP_DIR/mysql.sock";
our $THREADS		= "1";
our $READONLY		= 0;
our $PARALLEL_PREPARE	= 1;
our $PREPARE_THREADS	= 24;
#our $GRAPH_HEADING	= "MariaDB 5.2.9 + XtraDB \\n vs. MariaDB 5.3.2 + XtraDB \\n vs. MariaDB 5.5.15 + XtraDB \\n vs. MySQL 5.5.19 + InnoDB";
our $GRAPH_HEADING     = "MariaDB 5.3.2 + XtraDB \\n vs. MariaDB 5.5.15 + XtraDB \\n vs. MySQL 5.5.19 + InnoDB";


our $MYSQL_USER		= "root";

my $CONFIG_HOME		= "$PROJECT_HOME/mariadb-tools/sysbench-runner/config";

our @configurations = (
		{
			#case specific
			DESCRIPTION	=> "MariaDB 5.3.2 + XtraDB",
			DATA_SOURCE_DIR	=> "$TEMP_DIR/innodb",
			DATADIR		=> "$PROJECT_HOME/db_data/data_workdir_5_3",
			DBNAME		=> "mariadb_5_3_2",
			KEYWORD		=> "mariadb_5_3_2_xtradb",
			TABLE_ENGINE	=> "innodb",
			CONFIG_FILE	=> "$CONFIG_HOME/mariadb_innodb_fb2_my.cnf",
			WORKLOAD	=> "$SYSBENCH_HOME/tests/db/oltp.lua",
			MYSQL_HOME	=> "$PROJECT_HOME/bin-gprof/mariadb-5.3.2-beta-linux-x86_64"
		},
		

		{
			#case specific
			DESCRIPTION	=> "MariaDB 5.5.15 + XtraDB",
			DATA_SOURCE_DIR	=> "$TEMP_DIR/innodb",
			DATADIR		=> "$PROJECT_HOME/db_data/data_workdir_5_5",
			DBNAME		=> "mariadb_5_5_15",
			KEYWORD		=> "mariadb_5_5_15_xtradb", 
			TABLE_ENGINE	=> "innodb",
			CONFIG_FILE	=> "$CONFIG_HOME/mariadb_innodb_fb2_my.cnf",
			WORKLOAD	=> "$SYSBENCH_HOME/tests/db/oltp.lua",
			MYSQL_HOME	=> "$PROJECT_HOME/bin-gprof/mariadb-5.5.15-mariadb-linux-x86_64"
		},


		{
	               	#case specific
			DESCRIPTION     => "MySQL 5.5.19 + InnoDB",
			DATA_SOURCE_DIR => "$TEMP_DIR/innodb",
			DATADIR         => "$PROJECT_HOME/db_data/data_workdir_mysql_5_5_19",
			DBNAME          => "mysql_5_5_19",
			KEYWORD         => "mysql_5_5_19_innodb",
			TABLE_ENGINE    => "innodb",
			CONFIG_FILE     => "$CONFIG_HOME/mysql_innodb_fb2_my.cnf",
			WORKLOAD        => "$SYSBENCH_HOME/tests/db/oltp.lua",
			MYSQL_HOME      => "$PROJECT_HOME/bin-gprof/mysql-5.5.19-linux-x86_64"
		}#,


#		{
#			#case specific
#			DESCRIPTION     => "MariaDB 5.2.9 + XtraDB",
#			DATA_SOURCE_DIR => "$TEMP_DIR/innodb",
#			DATADIR         => "$PROJECT_HOME/db_data/data_workdir_5_2",
#			DBNAME          => "mariadb_5_2_9",
#			KEYWORD         => "mariadb_5_2_9_xtradb", 
#			TABLE_ENGINE    => "innodb",
#			CONFIG_FILE     => "$CONFIG_HOME/mariadb_5_2_innodb_fb2_my.cnf",
#			WORKLOAD        => "$SYSBENCH_HOME/tests/db/oltp.lua",
#			MYSQL_HOME      => "$PROJECT_HOME/bin/mariadb-5.2.9-Linux-x86_64"
#		}
	);
1;

















