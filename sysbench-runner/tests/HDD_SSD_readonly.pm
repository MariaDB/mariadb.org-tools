#!/usr/bin/env perl
use warnings;
use strict;


###############   Scenario 3 configuration   ####################
# Comparing the following scenarios:
# 1. MariaDB + XtraDB with both data and transaction log on HDD
# 2. MariaDB + XtraDB with both data and transaction log on SSD
# 3. MariaDB + XtraDB with data on HDD, and transactional log on SSD
# 4. MariaDB + XtraDB with data on SSD, and transactional log on HDD 



#common stuff
our $RUN		= 1; #Perform the actual tests
our $CLEANUP		= 1; #Cleanup after done with the tests
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
our $RESULTS_OUTPUT_DIR	= "$TEMP_DIR/BenchmarkResults/HDD_vs_SSD_readonly";
our $SOCKET		= "$TEMP_DIR/mysql.sock";
our $THREADS		= "1, 4, 8, 12, 16, 24, 32, 48, 64, 128";
our $READONLY		= 1;
our $PARALLEL_PREPARE	= 1;
our $PREPARE_THREADS	= 24;
our $GRAPH_HEADING	= "MariaDB + XtraDB on HDD vs SSD \\n readonly";

our $MYSQL_USER		= "root";

my $SSD_DRIVE		= "$TEMP_DIR/SSD";

my $CONFIG_HOME		= "$PROJECT_HOME/mariadb-tools/sysbench-runner/config";

#case specific
our @configurations = (
		{
			# 1. MariaDB + XtraDB with both data and transaction log on HDD
			DESCRIPTION		=> "Data and transaction log on HDD",
			DATA_SOURCE_DIR		=> "$TEMP_DIR/innodb",
			DATADIR			=> "$TEMP_DIR/data_workdir",
			DBNAME			=> "mariadb_5_2_7",
			KEYWORD			=> "HDD",
			TABLE_ENGINE		=> "innodb",
			CONFIG_FILE		=> "$CONFIG_HOME/mariadb_my.cnf",
			WORKLOAD		=> "$SYSBENCH_HOME/tests/db/oltp.lua",
			MYSQL_HOME		=> "$PROJECT_HOME/mariadb-5.2.7-Linux-x86_64",
			MYSQLD_START_PARAMS 	=> "--innodb_log_group_home_dir=$TEMP_DIR/trans_log_workdir" #this directory has to exist prior the benchmark run
		},
		

		{
			# 2. MariaDB + XtraDB with both data and transaction log on SSD
			DESCRIPTION		=> "Data and transaction log on SSD",
			DATA_SOURCE_DIR		=> "$TEMP_DIR/innodb",
			DATADIR			=> "$SSD_DRIVE/data_workdir",
			DBNAME			=> "mariadb_5_2_7",
			KEYWORD			=> "SSD",
			TABLE_ENGINE		=> "innodb",
			CONFIG_FILE		=> "$CONFIG_HOME/mariadb_my.cnf",
			WORKLOAD		=> "$SYSBENCH_HOME/tests/db/oltp.lua",
			MYSQL_HOME		=> "$PROJECT_HOME/mariadb-5.2.7-Linux-x86_64",
			MYSQLD_START_PARAMS 	=> "--innodb_log_group_home_dir=$SSD_DRIVE/trans_log_workdir" #this directory has to exist prior the benchmark run
		},


		{
			# 3. MariaDB + XtraDB with data on HDD, and transactional log on SSD
			DESCRIPTION		=> "Data on HDD, and transactional log on SSD",
			DATA_SOURCE_DIR		=> "$TEMP_DIR/innodb",
			DATADIR			=> "$TEMP_DIR/data_workdir",
			DBNAME			=> "mariadb_5_2_7",
			KEYWORD			=> "data_HDD_log_SSD",
			TABLE_ENGINE		=> "innodb",
			CONFIG_FILE		=> "$CONFIG_HOME/mariadb_my.cnf",
			WORKLOAD		=> "$SYSBENCH_HOME/tests/db/oltp.lua",
			MYSQL_HOME		=> "$PROJECT_HOME/mariadb-5.2.7-Linux-x86_64",
			MYSQLD_START_PARAMS	=> "--innodb_log_group_home_dir=$SSD_DRIVE/trans_log_workdir" #this directory has to exist prior the benchmark run
		},


		{
			# 4. MariaDB + XtraDB with data on SSD, and transactional log on HDD
			DESCRIPTION		=> "Data on SSD, and transactional log on HDD",
			DATA_SOURCE_DIR		=> "$TEMP_DIR/innodb",
			DATADIR			=> "$SSD_DRIVE/data_workdir",
			DBNAME			=> "mariadb_5_2_7",
			KEYWORD			=> "data_SSD_log_HDD",
			TABLE_ENGINE		=> "innodb",
			CONFIG_FILE		=> "$CONFIG_HOME/mariadb_my.cnf",
			WORKLOAD		=> "$SYSBENCH_HOME/tests/db/oltp.lua",
			MYSQL_HOME		=> "$PROJECT_HOME/mariadb-5.2.7-Linux-x86_64",
			MYSQLD_START_PARAMS 	=> "--innodb_log_group_home_dir=$TEMP_DIR/trans_log_workdir" #this directory has to exist prior the benchmark run
		}
	);
1;

















