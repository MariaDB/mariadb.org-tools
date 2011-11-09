#!/usr/bin/env perl
use warnings;
use strict;


###############   Creating databases   ####################
# This script creates and prepares the databases, so that they can be just copy/pasted instead of prepared each time.
# The following databases will be created
# 1. MySQL 5.5.13 + InnoDB
# 2. MySQL 5.5.13 + MyISAM
# 3. MariaDB 5.2.7 + Aria
# 4. MariaDB 5.2.7 + PBXT


#common stuff
our $RUN		= 0; #This means that only prepare statements will be executed
our $CLEANUP		= 0; #Don't cleanup, we will need the prepared folders
our $PLOT		= 0; #Don't need to plot anything since we haven't any results

our $PROJECT_HOME	= $ENV{"HOME"}."/benchmark/sysbench/";
our $SCRIPTS_HOME	= "$PROJECT_HOME/mariadb-tools/sysbench-runner/";
our $SYSBENCH_HOME	= "$PROJECT_HOME/sysbench/sysbench";
our $TEMP_DIR		= "$PROJECT_HOME/temp";
our $MAX_TIME		= 600;
our $WARMUP_TIME	= 600;
our $WARMUP_THREADS	= 24;
our $TABLES_COUNT	= 24;
our $TABLE_SIZE		= 2000000;
our $RESULTS_OUTPUT_DIR	= "$PROJECT_HOME/results/Prepare_DBs";
our $SOCKET		= "$TEMP_DIR/mysql.sock";
#our $THREADS		= "1, 4, 8, 12, 16, 24, 32, 48, 64, 128";
our $READONLY		= 0;
our $PARALLEL_PREPARE	= 1;
our $PREPARE_THREADS	= 24;

our $MYSQL_USER		= "root";

my $CONFIG_HOME		= "$PROJECT_HOME/mariadb-tools/sysbench-runner/config";


#case specific
our @configurations = (
		{
			# 1. MariaDB 5.3.2 + InnoDB
			DESCRIPTION	=> "MariaDB 5.3.2 + InnoDB",
			#DATA_SOURCE_DIR	=> "$TEMP_DIR/innodb",
			DATADIR		=> "$TEMP_DIR/innodb",
			DBNAME		=> "mariadb_5_3_2",
			KEYWORD		=> "mariadb_innodb",
			TABLE_ENGINE	=> "innodb",
			CONFIG_FILE	=> "$CONFIG_HOME/mariadb_innodb_fb2_my.cnf",
			WORKLOAD	=> "$SYSBENCH_HOME/tests/db/oltp.lua",
			MYSQL_HOME	=> "$PROJECT_HOME/bin/mariadb-5.3.2-beta-linux-x86_64/"
		}#,
		

#		{
			# 2. MySQL 5.5.13 + MyISAM
#			DESCRIPTION	=> "MySQL 5.5.13 + MyISAM",
			#DATA_SOURCE_DIR	=> "$TEMP_DIR/myisam",
#			DATADIR		=> "$TEMP_DIR/myisam",
#			DBNAME		=> "mysql_5_5_13",
#			KEYWORD		=> "mysql_myisam", 
#			TABLE_ENGINE	=> "myisam",
#			CONFIG_FILE	=> "$CONFIG_HOME/mysql_my.cnf",
#			WORKLOAD	=> "$SYSBENCH_HOME/tests/db/oltp.lua",
#			MYSQL_HOME	=> "$PROJECT_HOME/mysql-5.5.13-linux2.6-x86_64"
#		},


#		{
			# 3. MariaDB 5.2.7 + Aria
#			DESCRIPTION	=> "MariaDB 5.2.7 + Aria",
			#DATA_SOURCE_DIR	=> "$TEMP_DIR/aria",
#			DATADIR		=> "$TEMP_DIR/aria",
#			DBNAME		=> "mariadb_5_2_7",
#			KEYWORD		=> "mariadb_aria", 
#			TABLE_ENGINE	=> "aria",
#			CONFIG_FILE	=> "$CONFIG_HOME/mariadb_my.cnf",
#			WORKLOAD	=> "$SYSBENCH_HOME/tests/db/oltp.lua",
#			MYSQL_HOME	=> "$PROJECT_HOME/mariadb-5.2.7-Linux-x86_64",
#			PRE_RUN_SQL	=> "use sbtest; ".
#					"ALTER TABLE sbtest1 TRANSACTIONAL=0;".
#					"ALTER TABLE sbtest2 TRANSACTIONAL=0; ".
#					"ALTER TABLE sbtest2 TRANSACTIONAL=0; ".
#					"ALTER TABLE sbtest3 TRANSACTIONAL=0; ".
#					"ALTER TABLE sbtest4 TRANSACTIONAL=0; ".
#					"ALTER TABLE sbtest5 TRANSACTIONAL=0; ".
#					"ALTER TABLE sbtest6 TRANSACTIONAL=0; ".
#					"ALTER TABLE sbtest7 TRANSACTIONAL=0; ".
#					"ALTER TABLE sbtest8 TRANSACTIONAL=0; ".
#					"ALTER TABLE sbtest9 TRANSACTIONAL=0; ".
#					"ALTER TABLE sbtest10 TRANSACTIONAL=0; ".
#					"ALTER TABLE sbtest11 TRANSACTIONAL=0; ".
#					"ALTER TABLE sbtest12 TRANSACTIONAL=0; ".
#					"ALTER TABLE sbtest13 TRANSACTIONAL=0; ".
#					"ALTER TABLE sbtest14 TRANSACTIONAL=0; ".
#					"ALTER TABLE sbtest15 TRANSACTIONAL=0; ".
#					"ALTER TABLE sbtest16 TRANSACTIONAL=0; ".
#					"ALTER TABLE sbtest17 TRANSACTIONAL=0; ".
#					"ALTER TABLE sbtest18 TRANSACTIONAL=0; ".
#					"ALTER TABLE sbtest19 TRANSACTIONAL=0; ".
#					"ALTER TABLE sbtest20 TRANSACTIONAL=0; ".
#					"ALTER TABLE sbtest21 TRANSACTIONAL=0; ".
#					"ALTER TABLE sbtest22 TRANSACTIONAL=0; ".
#					"ALTER TABLE sbtest23 TRANSACTIONAL=0; ".
#					"ALTER TABLE sbtest24 TRANSACTIONAL=0;"
#		},


#		{
			# 4. MariaDB 5.2.7 + PBXT
#			DESCRIPTION	=> "MariaDB 5.2.7 + PBXT",
			#DATA_SOURCE_DIR	=> "$TEMP_DIR/pbxt",
#			DATADIR		=> "$TEMP_DIR/pbxt",
#			DBNAME		=> "mariadb_5_2_7",
#			KEYWORD		=> "mariadb_pbxt", 
#			TABLE_ENGINE	=> "pbxt",
#			CONFIG_FILE	=> "$CONFIG_HOME/mariadb_my.cnf",
#			WORKLOAD	=> "$SYSBENCH_HOME/tests/db/oltp.lua",
#			MYSQL_HOME	=> "$PROJECT_HOME/mariadb-5.2.7-Linux-x86_64",
#			PARALLEL_PREPARE=> 0
#		}
	);
1;

















