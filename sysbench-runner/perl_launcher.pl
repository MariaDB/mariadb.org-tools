#!/usr/bin/env perl
use warnings;
use strict;
#use DBI;
#use Mysql;

# import module
use Getopt::Long;

my $MYSQLADMIN		= "./bin/mysqladmin";
my $MYSQLADMIN_OPTIONS	= "";
my $MYSQLD_SAFE		= "./bin/mysqld_safe";
my $MYSQLD_OPTIONS	= "";
my $TIMEOUT		= 100;

my $PROJECT_HOME	= $ENV{"HOME"}."/Projects/MariaDB";
my $MYSQL_HOME		= "";
my $MARIADB_HOME	= "";
my $TEMP_DIR		= "";
my $CONFIG_HOME		= "";
my $SYSBENCH_HOME	= "";

my $SSD_HOME		= "";

my $SSD_FOLDER_NAME	= "vlado_bench_ssd";
my $MAX_TIME		= 600;
my $WARMUP_TIME		= 600;
my $TABLE_SIZE		= 2000000;

my $install 		= 0;
my $prepare 		= 0;
my $create_db		= 0;
my $set_transactional	= 0;
my $scenario1		= 0;
my $scenario2		= 0;
my $scenario3		= 0;
my $cleanup		= 0;
my $bReadonly		= 0;
my $readonly		= "";

######################################## Get input parameters ########################################
GetOptions ("max-time:i" 		=> \$MAX_TIME, 
		"warmup-time:i"		=> \$WARMUP_TIME, 
		"table-size:i"		=> \$TABLE_SIZE,
		"project-home:s"	=> \$PROJECT_HOME,
		"config-home:s"		=> \$CONFIG_HOME,
		"mysql-home:s"		=> \$MYSQL_HOME,
		"mariadb-home:s"	=> \$MARIADB_HOME,
		"sysbench-home:s"	=> \$SYSBENCH_HOME,
		"temp-dir:s"		=> \$TEMP_DIR,
		"ssd_home:s"		=> \$SSD_HOME,
		"ssd_folder_name:s"	=> \$SSD_FOLDER_NAME,
		"install"		=> \$install,
		"create-db"		=> \$create_db,
		"set_transactional"	=> \$set_transactional,
		"prepare"		=> \$prepare,
		"scenario1"		=> \$scenario1,
		"scenario2"		=> \$scenario2,
		"scenario3"		=> \$scenario3,
		"cleanup"		=> \$cleanup,
		"readonly"		=> \$bReadonly
);


#Default values
if(length($MYSQL_HOME) == 0){
	$MYSQL_HOME	= "$PROJECT_HOME/mysql-5.5.13-linux2.6-x86_64";
}

if(length($MARIADB_HOME) == 0){
	$MARIADB_HOME	= "$PROJECT_HOME/mariadb-5.2.7-Linux-x86_64";
}

if(length($TEMP_DIR) == 0){
	$TEMP_DIR	= "$PROJECT_HOME/temp";
}

if(length($CONFIG_HOME) == 0){
	$CONFIG_HOME	= "$PROJECT_HOME/mariadb-tools/sysbench-runner/config";
}

if(length($SYSBENCH_HOME) == 0){
	$SYSBENCH_HOME	= "$PROJECT_HOME/sysbench/sysbench";
}

if(length($SSD_HOME) == 0){
	#$SSD_HOME	= "/media/ssd_tmp";
	$SSD_HOME	= "$TEMP_DIR/SSD";
}


if($bReadonly){
	$readonly = "--readonly ";
}




sub kill_mysqld {
    system("killall -9 mysqld");
#    rm -rf $DATA_DIR
#    rm -f $MY_SOCKET
#    mkdir $DATA_DIR
}


sub InstallDBs{
	chdir($MYSQL_HOME);
	system("./scripts/mysql_install_db --defaults-file=$CONFIG_HOME/mysql_my.cnf --datadir=$TEMP_DIR/innodb");
	system("./scripts/mysql_install_db --defaults-file=$CONFIG_HOME/mysql_my.cnf --datadir=$TEMP_DIR/myisam");

	chdir($MARIADB_HOME);
	system("./scripts/mysql_install_db --defaults-file=$CONFIG_HOME/mariadb_my.cnf --datadir=$TEMP_DIR/pbxt");
	system("./scripts/mysql_install_db --defaults-file=$CONFIG_HOME/mariadb_my.cnf --datadir=$TEMP_DIR/aria");
}

sub CreateSbtestDBs{
	#TODO: turn this copy/paste shell commands to a script
	#switch to MySQL folder
	
	#shell> ./bin/mysqld_safe --defaults-file=$CONFIG_HOME/mysql_my.cnf --datadir=$TEMP_DIR/innodb &
	#shell> ./bin/mysql --user=root
	#mysql> create database sbtest;
	#mysql> exit;
	#shell> ./bin/mysqladmin --user=root shutdown 0

	#shell> ./bin/mysqld_safe --defaults-file=$CONFIG_HOME/mysql_my.cnf --datadir=$TEMP_DIR/myisam &
	#shell> ./bin/mysql --user=root
	#mysql> create database sbtest;
	#mysql> exit;
	#shell> ./bin/mysqladmin --user=root shutdown 0


	#switch to MariaDB folder

	#shell> ./bin/mysqld_safe --defaults-file=$CONFIG_HOME/mariadb_my.cnf --datadir=$TEMP_DIR/pbxt &
	#shell> ./bin/mysql --user=root
	#mysql> create database sbtest;
	#mysql> exit;
	#shell> ./bin/mysqladmin --user=root shutdown 0

	#shell> ./bin/mysqld_safe --defaults-file=$CONFIG_HOME/mariadb_my.cnf --datadir=$TEMP_DIR/aria &
	#shell> ./bin/mysql --user=root
	#mysql> create database sbtest;
	#mysql> exit;
	#shell> ./bin/mysqladmin --user=root shutdown 0
}


sub PrepareDBs{
	chdir("$PROJECT_HOME/mariadb-tools/sysbench-runner");
 	system("perl bench_script.pl \\\
--sysbench-home=$SYSBENCH_HOME \\\
--datadir=$TEMP_DIR/innodb \\\
--nowarmup \\\
--norun \\\
--nocleanup \\\
--mysql-table-engine=innodb \\\
--config-file=$CONFIG_HOME/mysql_my.cnf \\\
--mysql-home=$MYSQL_HOME \\\
--parallel-prepare \\\
--table-size=$TABLE_SIZE");
 
 	system("perl bench_script.pl \\\
--sysbench-home=$SYSBENCH_HOME \\\
--datadir=$TEMP_DIR/myisam \\\
--nowarmup \\\
--norun \\\
--nocleanup \\\
--mysql-table-engine=myisam \\\
--config-file=$CONFIG_HOME/mysql_my.cnf \\\
--mysql-home=$MYSQL_HOME \\\
--parallel-prepare \\\
--table-size=$TABLE_SIZE");
 
 	system("perl bench_script.pl \\\
--sysbench-home=$SYSBENCH_HOME \\\
--datadir=$TEMP_DIR/pbxt \\\
--nowarmup \\\
--norun \\\
--nocleanup \\\
--mysql-table-engine=pbxt \\\
--config-file=$CONFIG_HOME/mariadb_my.cnf \\\
--mysql-home=$MARIADB_HOME \\\
--table-size=$TABLE_SIZE");

	system("perl bench_script.pl \\\
--sysbench-home=$SYSBENCH_HOME \\\
--datadir=$TEMP_DIR/aria \\\
--nowarmup \\\
--norun \\\
--nocleanup \\\
--mysql-table-engine=aria \\\
--config-file=$CONFIG_HOME/mariadb_my.cnf \\\
--mysql-home=$MARIADB_HOME \\\
--parallel-prepare \\\
--table-size=$TABLE_SIZE");
}


sub SetTransactional{
#TODO: Make it automatic. 
#For now start mariadb with the following line:
#	./bin/mysqld_safe --defaults-file=$PROJECT_HOME/mariadb-tools/sysbench-runner/config/mariadb_my.cnf --datadir=$PROJECT_HOME/MariaDB/temp/aria &
#	./bin/mysql --user=root
#Copy/paste the following SQL commands
	"USE sbtest;
	ALTER TABLE sbtest1 TRANSACTIONAL=0;
	ALTER TABLE sbtest2 TRANSACTIONAL=0;
	ALTER TABLE sbtest3 TRANSACTIONAL=0;
	ALTER TABLE sbtest4 TRANSACTIONAL=0;
	ALTER TABLE sbtest5 TRANSACTIONAL=0;
	ALTER TABLE sbtest6 TRANSACTIONAL=0;
	ALTER TABLE sbtest7 TRANSACTIONAL=0;
	ALTER TABLE sbtest8 TRANSACTIONAL=0;
	ALTER TABLE sbtest9 TRANSACTIONAL=0;
	ALTER TABLE sbtest10 TRANSACTIONAL=0;
	ALTER TABLE sbtest11 TRANSACTIONAL=0;
	ALTER TABLE sbtest12 TRANSACTIONAL=0;
	ALTER TABLE sbtest13 TRANSACTIONAL=0;
	ALTER TABLE sbtest14 TRANSACTIONAL=0;
	ALTER TABLE sbtest15 TRANSACTIONAL=0;
	ALTER TABLE sbtest16 TRANSACTIONAL=0;
	ALTER TABLE sbtest17 TRANSACTIONAL=0;
	ALTER TABLE sbtest18 TRANSACTIONAL=0;
	ALTER TABLE sbtest19 TRANSACTIONAL=0;
	ALTER TABLE sbtest20 TRANSACTIONAL=0;
	ALTER TABLE sbtest21 TRANSACTIONAL=0;
	ALTER TABLE sbtest22 TRANSACTIONAL=0;
	ALTER TABLE sbtest23 TRANSACTIONAL=0;
	ALTER TABLE sbtest24 TRANSACTIONAL=0;";
#Exit and shutdown MariaDB
#	exit;
#	./bin/mysqladmin --user=root shutdown 0

}



sub Scenario1{
	print "--- Running Scenario1 ---\n";
	chdir("$PROJECT_HOME/mariadb-tools/sysbench-runner");

	#1)Execute the perl script for the first test with MySQL 5.5.13 and engine InnoDB
	system("rm -r $TEMP_DIR/data_workdir");
	system("cp -r $TEMP_DIR/innodb $TEMP_DIR/data_workdir");
	system("perl bench_script.pl --max-time=$MAX_TIME $readonly \\\
--sysbench-home=$SYSBENCH_HOME \\\
--dbname=mysql_5_5_13 \\\
--keyword=scenario1  \\\
--results-output-dir=$PROJECT_HOME/mariadb-tools/sysbench-runner/Scenario1 \\\
--warmup-time=$WARMUP_TIME \\\
--mysql-table-engine=innodb \\\
--noprepare \\\
--config-file=$CONFIG_HOME/mysql_my.cnf \\\
--datadir=$TEMP_DIR/data_workdir \\\
--mysql-home=$MYSQL_HOME");


	#2) Execute the perl script for the second test with MariaDB 5.2.7 and engine InnoDB
	system("rm -r $TEMP_DIR/data_workdir");
	system("cp -r $TEMP_DIR/innodb $TEMP_DIR/data_workdir");
	system("perl bench_script.pl --max-time=$MAX_TIME $readonly \\\
--sysbench-home=$SYSBENCH_HOME \\\
--dbname=mariadb_5_2_7 \\\
--keyword=scenario1  \\\
--results-output-dir=$PROJECT_HOME/mariadb-tools/sysbench-runner/Scenario1 \\\
--warmup-time=$WARMUP_TIME \\\
--mysql-table-engine=innodb \\\
--noprepare \\\
--config-file=$CONFIG_HOME/mariadb_my.cnf \\\
--datadir=$TEMP_DIR/data_workdir \\\
--mysql-home=$MARIADB_HOME");


	#3) Execute the perl script for the second test with MariaDB 5.2.7 and engine PBXT
	system("rm -r $TEMP_DIR/data_workdir");
	system("cp -r $TEMP_DIR/pbxt $TEMP_DIR/data_workdir");
	system("perl bench_script.pl --max-time=$MAX_TIME $readonly \\\
--sysbench-home=$SYSBENCH_HOME \\\
--dbname=mariadb_5_2_7 \\\
--keyword=scenario1  \\\
--results-output-dir=$PROJECT_HOME/mariadb-tools/sysbench-runner/Scenario1 \\\
--warmup-time=$WARMUP_TIME \\\
--mysql-table-engine=pbxt \\\
--noprepare \\\
--config-file=$CONFIG_HOME/mariadb_my.cnf \\\
--datadir=$TEMP_DIR/data_workdir \\\
--mysql-home=$MARIADB_HOME");


	#4) Run the gnuplot script to generate a graphic
	chdir("$PROJECT_HOME/mariadb-tools/sysbench-runner");
	system("gnuplot $PROJECT_HOME/mariadb-tools/sysbench-runner/gnuplot_scenario1.txt");

	print "\nScenario 1 complete\n";
}


sub Scenario2{
	print "--- Running Scenario 2 ---\n";
	chdir("$PROJECT_HOME/mariadb-tools/sysbench-runner");

	#1)Execute the perl script for the first test with MySQL 5.5.13 and engine MyISAM
	system("rm -r $TEMP_DIR/data_workdir");
	system("cp -r $TEMP_DIR/myisam $TEMP_DIR/data_workdir");
	system("perl bench_script.pl --max-time=$MAX_TIME $readonly \\\
--sysbench-home=$SYSBENCH_HOME \\\
--dbname=mysql_5_5_13 \\\
--keyword=scenario2  \\\
--results-output-dir=$PROJECT_HOME/mariadb-tools/sysbench-runner/Scenario2 \\\
--warmup-time=$WARMUP_TIME \\\
--mysql-table-engine=myisam \\\
--noprepare \\\
--config-file=$CONFIG_HOME/mysql_my.cnf \\\
--workload=oltp_aria.lua \\\
--datadir=$TEMP_DIR/data_workdir \\\
--mysql-home=$MYSQL_HOME");


	#2) Execute the perl script for the second test with MariaDB 5.2.7 and engine Aria
	system("rm -r $TEMP_DIR/data_workdir");
	system("cp -r $TEMP_DIR/aria $TEMP_DIR/data_workdir");
	system("perl bench_script.pl --max-time=$MAX_TIME $readonly \\\
--sysbench-home=$SYSBENCH_HOME \\\
--dbname=mariadb_5_2_7 \\\
--keyword=scenario2  \\\
--results-output-dir=$PROJECT_HOME/mariadb-tools/sysbench-runner/Scenario2 \\\
--warmup-time=$WARMUP_TIME \\\
--mysql-table-engine=aria \\\
--noprepare \\\
--config-file=$CONFIG_HOME/mariadb_my.cnf \\\
--workload=oltp_aria.lua \\\
--datadir=$TEMP_DIR/data_workdir \\\
--mysql-home=$MARIADB_HOME");

	#3) Execute the perl script for the second test with MariaDB 5.2.7 and engine MyISAM
	system("rm -r $TEMP_DIR/data_workdir");
	system("cp -r $TEMP_DIR/myisam $TEMP_DIR/data_workdir");
	system("perl bench_script.pl --max-time=$MAX_TIME $readonly\\\
--sysbench-home=$SYSBENCH_HOME \\\
--dbname=mariadb_5_2_7 \\\
--keyword=scenario2  \\\
--results-output-dir=$PROJECT_HOME/mariadb-tools/sysbench-runner/Scenario2 \\\
--warmup-time=$WARMUP_TIME \\\
--mysql-table-engine=myisam \\\
--noprepare \\\
--config-file=$CONFIG_HOME/mariadb_my.cnf \\\
--workload=oltp_aria.lua \\\
--datadir=$TEMP_DIR/data_workdir \\\
--mysql-home=$MARIADB_HOME");


	#4) Run the gnuplot script to generate a graphic
	chdir("$PROJECT_HOME/mariadb-tools/sysbench-runner");
	system("gnuplot $PROJECT_HOME/mariadb-tools/sysbench-runner/gnuplot_scenario2.txt");

	print "\nScenario 2 complete\n";

}

sub Scenario3{
	print "--- Running Scenario 3 ---\n";
	chdir("$PROJECT_HOME/mariadb-tools/sysbench-runner");
	
	#1) Create a folder on the SSD drive
	system("mkdir $SSD_HOME/$SSD_FOLDER_NAME");
	system("mkdir $SSD_HOME/$SSD_FOLDER_NAME/trans_log_workdir");
	system("mkdir $TEMP_DIR/trans_log_workdir");

	#2) Execute the perl script for the first test with MariaDB + XtraDB with both data and transaction log on HDD
	system("rm -r $TEMP_DIR/data_workdir");
	system("rm -r $TEMP_DIR/trans_log_workdir/*");
	system("cp -r $TEMP_DIR/innodb $TEMP_DIR/data_workdir");
	system("perl bench_script.pl --max-time=$MAX_TIME $readonly\\\
--sysbench-home=$SYSBENCH_HOME \\\
--dbname=mariadb_5_2_7 \\\
--keyword=hdd  \\\
--results-output-dir=$PROJECT_HOME/mariadb-tools/sysbench-runner/Scenario3 \\\
--warmup-time=$WARMUP_TIME \\\
--mysql-table-engine=innodb \\\
--noprepare \\\
--config-file=$CONFIG_HOME/mariadb_my.cnf \\\
--innodb_log_group_home_dir=$TEMP_DIR/trans_log_workdir \\\
--datadir=$TEMP_DIR/data_workdir \\\
--mysql-home=$MARIADB_HOME");


	#3) Execute the perl script for the first test with MariaDB + XtraDB with both data and transaction log on SSD
	system("rm -r $SSD_HOME/$SSD_FOLDER_NAME/data_workdir");
	system("rm -r $SSD_HOME/$SSD_FOLDER_NAME/trans_log_workdir/*");
	system("cp -r $TEMP_DIR/innodb $SSD_HOME/$SSD_FOLDER_NAME/data_workdir");
	system("perl bench_script.pl --max-time=$MAX_TIME $readonly\\\
--sysbench-home=$SYSBENCH_HOME \\\
--dbname=mariadb_5_2_7 \\\
--keyword=ssd  \\\
--results-output-dir=$PROJECT_HOME/mariadb-tools/sysbench-runner/Scenario3 \\\
--warmup-time=$WARMUP_TIME \\\
--mysql-table-engine=innodb \\\
--noprepare \\\
--config-file=$CONFIG_HOME/mariadb_my.cnf \\\
--innodb_log_group_home_dir=$SSD_HOME/$SSD_FOLDER_NAME/trans_log_workdir \\\
--datadir=$SSD_HOME/$SSD_FOLDER_NAME/data_workdir \\\
--mysql-home=$MARIADB_HOME");


	#4) Execute the perl script for the first test with MariaDB + XtraDB with data on HDD, and transactional log on SSD 
	system("rm -r $TEMP_DIR/data_workdir");
	system("rm -r $SSD_HOME/$SSD_FOLDER_NAME/trans_log_workdir/*");
	system("cp -r $TEMP_DIR/innodb $TEMP_DIR/data_workdir");
	system("perl bench_script.pl --max-time=$MAX_TIME $readonly\\\
--sysbench-home=$SYSBENCH_HOME \\\
--dbname=mariadb_5_2_7 \\\
--keyword=data_hdd_log_ssd  \\\
--results-output-dir=$PROJECT_HOME/mariadb-tools/sysbench-runner/Scenario3 \\\
--warmup-time=$WARMUP_TIME \\\
--mysql-table-engine=innodb \\\
--noprepare \\\
--config-file=$CONFIG_HOME/mariadb_my.cnf \\\
--innodb_log_group_home_dir=$SSD_HOME/$SSD_FOLDER_NAME/trans_log_workdir \\\
--datadir=$TEMP_DIR/data_workdir \\\
--mysql-home=$MARIADB_HOME");


	#5) Execute the perl script for the first test with MariaDB + XtraDB with data on SSD, and transactional log on HDD 
	system("rm -r $SSD_HOME/$SSD_FOLDER_NAME/data_workdir");
	system("rm -r $TEMP_DIR/trans_log_workdir/*");
	system("cp -r $TEMP_DIR/innodb $SSD_HOME/$SSD_FOLDER_NAME/data_workdir");
	system("perl bench_script.pl --max-time=$MAX_TIME $readonly\\\
--sysbench-home=$SYSBENCH_HOME \\\
--dbname=mariadb_5_2_7 \\\
--keyword=data_ssd_log_hdd  \\\
--results-output-dir=$PROJECT_HOME/mariadb-tools/sysbench-runner/Scenario3 \\\
--warmup-time=$WARMUP_TIME \\\
--mysql-table-engine=innodb \\\
--noprepare \\\
--config-file=$CONFIG_HOME/mariadb_my.cnf \\\
--innodb_log_group_home_dir=$TEMP_DIR/trans_log_workdir \\\
--datadir=$SSD_HOME/$SSD_FOLDER_NAME/data_workdir \\\
--mysql-home=$MARIADB_HOME");

	
	#6) Run the gnuplot script to generate a graphic
	chdir("$PROJECT_HOME/mariadb-tools/sysbench-runner");
	system("gnuplot $PROJECT_HOME/mariadb-tools/sysbench-runner/gnuplot_scenario3.txt");


	print "\nScenario 3 complete\n";
}


sub Cleanup(){
	system("rm -r $SSD_HOME/$SSD_FOLDER_NAME");	
	system("rm -r $TEMP_DIR/data_workdir");
	system("rm -r $TEMP_DIR/trans_log_workdir");
}

###### Step1: Install the 4 database engines: InnoDB, MyISAM, PBXT and Aria #####
if($install){
	InstallDBs();
}



##### Step2: Created the database sbtest for each database engine #####
#TODO... For now it is manual
if($create_db){
	CreateSbtestDBs();
}



##### Step3: Prepare the 4 databases #####
if($prepare){
	PrepareDBs();
}


##### Step4: Set TRANSACTIONAL=0 to sbtest #####
#TODO... For now it is manual
if($set_transactional){
	SetTransactional();
}


##### Step5: Run the scenarios #####
if($scenario1){
	Scenario1();
}
if($scenario2){
	Scenario2();
}
if($scenario3){
	Scenario3();
}


##### Step6: Cleanup #####
if($cleanup){
	Cleanup();
}
