#!/usr/bin/env perl
use warnings;
use strict;


###############   Scenario 2 configuration   ####################
# Comparing the following scenarios:
# 1. MySQL 5.5.13 + MyISAM
# 2. MariaDB 5.2.7 + Aria
# 3. MariaDB 5.2.7 + MyISAM


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
our $RESULTS_OUTPUT_DIR	= "$TEMP_DIR/BenchmarkResults/MyISAM_vs_Aria_readonly";
our $SOCKET		= "$TEMP_DIR/mysql.sock";
our $THREADS		= "1, 4, 8, 12, 16, 24, 32, 48, 64, 128";
our $READONLY		= 1;
our $PARALLEL_PREPARE	= 1;
our $PREPARE_THREADS	= 24;
our $GRAPH_HEADING	= "MySQL 5.5.13 + MyISAM vs. MariaDB 5.2.7 + Aria \\n vs. MariaDB 5.2.7 + MyISAM \\n readonly";

our $MYSQL_USER		= "root";

my $CONFIG_HOME		= "$PROJECT_HOME/mariadb-tools/sysbench-runner/config";

our @configurations = (
		{
			#case specific
			DESCRIPTION	=> "MySQL 5.5.13 + MyISAM",
			DATA_SOURCE_DIR	=> "$TEMP_DIR/myisam",
			DATADIR		=> "$TEMP_DIR/data_workdir",
			DBNAME		=> "mysql_5_5_13",
			KEYWORD		=> "mysql_myisam",
			TABLE_ENGINE	=> "myisam",
			CONFIG_FILE	=> "$CONFIG_HOME/mysql_my.cnf",
			WORKLOAD	=> "$SYSBENCH_HOME/tests/db/oltp_aria.lua",
			MYSQL_HOME	=> "$PROJECT_HOME/mysql-5.5.13-linux2.6-x86_64"
		},
		

		{
			#case specific
			DESCRIPTION	=> "MariaDB 5.2.7 + Aria",
			DATA_SOURCE_DIR	=> "$TEMP_DIR/aria",
			DATADIR		=> "$TEMP_DIR/data_workdir",
			DBNAME		=> "mariadb_5_2_7",
			KEYWORD		=> "mariadb_aria",
			TABLE_ENGINE	=> "aria",
			CONFIG_FILE	=> "$CONFIG_HOME/mariadb_my.cnf",
			WORKLOAD	=> "$SYSBENCH_HOME/tests/db/oltp_aria.lua",
			MYSQL_HOME	=> "$PROJECT_HOME/mariadb-5.2.7-Linux-x86_64"
		},


		{
			#case specific
			DESCRIPTION	=> "MariaDB 5.2.7 + MyISAM",
			DATA_SOURCE_DIR	=> "$TEMP_DIR/myisam",
			DATADIR		=> "$TEMP_DIR/data_workdir",
			DBNAME		=> "mariadb_5_2_7",
			KEYWORD		=> "mariadb_myisam",
			TABLE_ENGINE	=> "myisam",
			CONFIG_FILE	=> "$CONFIG_HOME/mariadb_my.cnf",
			WORKLOAD	=> "$SYSBENCH_HOME/tests/db/oltp_aria.lua",
			MYSQL_HOME	=> "$PROJECT_HOME/mariadb-5.2.7-Linux-x86_64"
		}
	);
1;

















