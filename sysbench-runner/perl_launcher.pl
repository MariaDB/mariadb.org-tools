#!/usr/bin/env perl
use warnings;
use strict;


my $MYSQLADMIN			= "./bin/mysqladmin";
my $MYSQLADMIN_OPTIONS	= "";
my $MYSQLD_SAFE			= "./bin/mysqld_safe";
my $MYSQLD_OPTIONS		= "";
my $TIMEOUT				= 100;
my $PROJECT_HOME		= $ENV{"HOME"}."/Projects/MariaDB/mariadb-tools/sysbench-runner";
my $MYSQL_HOME			= $ENV{"HOME"}."/Projects/MariaDB/mysql-5.5.13-linux2.6-x86_64";
my $MARIADB_HOME		= $ENV{"HOME"}."/Projects/MariaDB/mariadb-5.2.7-Linux-x86_64";
my $TEMP_DIR			= $ENV{"HOME"}."/Projects/MariaDB/temp";
my $SSD_HOME			= "/media/ssd_tmp";#$ENV{"HOME"}."/Projects/MariaDB/SSD";
my $SSD_FOLDER_NAME		= "vlado_bench_ssd";
my $MAX_TIME			= 10;
my $WARMUP_TIME			= 30;


sub kill_mysqld {
    system("killall -9 mysqld");
#    rm -rf $DATA_DIR
#    rm -f $MY_SOCKET
#    mkdir $DATA_DIR
}


sub PrepareDBs{
	chdir($PROJECT_HOME);

	#innodb
	system("perl bench_script.pl --nowarmup --norun --nocleanup --mysql-table-engine=innodb --config-file=mysql_my.cnf --mysql-home=$MYSQL_HOME --parallel-prepare");
	system("cp -r $MYSQL_HOME/data/sbtest/ $TEMP_DIR/innodb/");
	system("cp -r $MYSQL_HOME/data/mysql/ $TEMP_DIR/mysql_innodb/");
	#cleanup
	system("perl bench_script.pl --nowarmup --norun --noprepare --mysql-table-engine=innodb --config-file=mysql_my.cnf --mysql-home=$MYSQL_HOME");


	#myisam
	system("perl bench_script.pl --nowarmup --norun --nocleanup --mysql-table-engine=myisam --config-file=mysql_my.cnf --mysql-home=$MYSQL_HOME --parallel-prepare");
	system("cp -r $MYSQL_HOME/data/sbtest/ $TEMP_DIR/myisam/");
	system("cp -r $MYSQL_HOME/data/mysql/ $TEMP_DIR/mysql_myisam/");
	#cleanup
	system("perl bench_script.pl --nowarmup --norun --noprepare --mysql-table-engine=myisam --config-file=mysql_my.cnf --mysql-home=$MYSQL_HOME");


	#aria
	system("perl bench_script.pl --nowarmup --norun --nocleanup --mysql-table-engine=aria --config-file=mariadb_my.cnf --mysql-home=$MARIADB_HOME --parallel-prepare");
	system("cp -r $MARIADB_HOME/data/sbtest/ $TEMP_DIR/aria/");
	system("cp -r $MARIADB_HOME/data/mysql/ $TEMP_DIR/mysql_aria/");
	#cleanup
	system("perl bench_script.pl --nowarmup --norun --noprepare --mysql-table-engine=aria --config-file=mariadb_my.cnf --mysql-home=$MARIADB_HOME ");
	

	#pbxt
	system("perl bench_script.pl --nowarmup --norun --nocleanup --mysql-table-engine=pbxt --config-file=mariadb_my.cnf --mysql-home=$MARIADB_HOME --parallel-prepare");
	system("cp -r $MARIADB_HOME/data/sbtest/ $TEMP_DIR/pbxt/");
	system("cp -r $MARIADB_HOME/data/mysql/ $TEMP_DIR/mysql_pbxt/");
	#cleanup
	system("perl bench_script.pl --nowarmup --norun --noprepare --mysql-table-engine=pbxt --config-file=mariadb_my.cnf --mysql-home=$MARIADB_HOME");
}




sub Scenario1{
	print "--- Running Scenario1 ---\n";
	chdir($PROJECT_HOME);

	#1)Execute the perl script for the first test with MySQL 5.5.13 and engine InnoDB
	system("cp -r $TEMP_DIR/innodb/* $MYSQL_HOME/data/sbtest");
	system("cp -r $TEMP_DIR/mysql_innodb/* $MYSQL_HOME/data/mysql/");
	system("perl bench_script.pl --max-time=$MAX_TIME \\\
--dbname=mysql_5_5_13 \\\
--keyword=scenario1  \\\
--results-output-dir=./Scenario1 \\\
--warmup-time=$WARMUP_TIME \\\
--mysql-table-engine=innodb \\\
--noprepare \\\
--config-file=mysql_my.cnf \\\
--mysql-home=$MYSQL_HOME");


	#2) Execute the perl script for the second test with MariaDB 5.2.7 and engine InnoDB
	system("cp -r $TEMP_DIR/innodb/* $MARIADB_HOME/data/sbtest");
	system("cp -r $TEMP_DIR/mysql_innodb/* $MARIADB_HOME/data/mysql");
	system("perl bench_script.pl --max-time=$MAX_TIME \\\
--dbname=mariadb_5_2_7 \\\
--keyword=scenario1  \\\
--results-output-dir=./Scenario1 \\\
--warmup-time=$WARMUP_TIME \\\
--mysql-table-engine=innodb \\\
--noprepare \\\
--config-file=mariadb_my.cnf \\\
--mysql-home=$MARIADB_HOME");


	#3) Execute the perl script for the second test with MariaDB 5.2.7 and engine PBXT
	system("cp -r $TEMP_DIR/pbxt/* $MARIADB_HOME/data/sbtest");
	system("cp -r $TEMP_DIR/mysql_pbxt/* $MARIADB_HOME/data/mysql");
	system("perl bench_script.pl --max-time=$MAX_TIME \\\
--dbname=mariadb_5_2_7 \\\
--keyword=scenario1  \\\
--results-output-dir=./Scenario1 \\\
--warmup-time=$WARMUP_TIME \\\
--mysql-table-engine=pbxt \\\
--noprepare \\\
--config-file=mariadb_my.cnf \\\
--mysql-home=$MARIADB_HOME");


	#4) Run the gnuplot script to generate a graphic
	chdir("$PROJECT_HOME");
	system("gnuplot $PROJECT_HOME/gnuplot_scenario1.txt");

	print "\nScenario 1 complete\n";
}


sub Scenario2{
	print "--- Running Scenario 2 ---\n";
	chdir($PROJECT_HOME);

	#1)Execute the perl script for the first test with MySQL 5.5.13 and engine MyISAM
	system("cp -r $TEMP_DIR/myisam/* $MYSQL_HOME/data/sbtest");
	system("cp -r $TEMP_DIR/mysql_myisam/* $MYSQL_HOME/data/mysql/");
	system("perl bench_script.pl --max-time=$MAX_TIME \\\
--dbname=mysql_5_5_13 \\\
--keyword=scenario2  \\\
--results-output-dir=./Scenario2 \\\
--warmup-time=$WARMUP_TIME \\\
--mysql-table-engine=myisam \\\
--noprepare \\\
--config-file=mysql_my.cnf \\\
--workload=oltp_aria.lua \\\
--mysql-home=$MYSQL_HOME");


	#2) Execute the perl script for the second test with MariaDB 5.2.7 and engine Aria
	system("cp -r $TEMP_DIR/aria/* $MARIADB_HOME/data/sbtest");
	system("cp -r $TEMP_DIR/mysql_aria/* $MARIADB_HOME/data/mysql");
	system("perl bench_script.pl --max-time=$MAX_TIME \\\
--dbname=mariadb_5_2_7 \\\
--keyword=scenario2  \\\
--results-output-dir=./Scenario2 \\\
--warmup-time=$WARMUP_TIME \\\
--mysql-table-engine=aria \\\
--noprepare \\\
--config-file=mariadb_my.cnf \\\
--workload=oltp_aria.lua \\\
--mysql-home=$MARIADB_HOME");

	#3) Execute the perl script for the second test with MariaDB 5.2.7 and engine MyISAM
	system("cp -r $TEMP_DIR/myisam/* $MARIADB_HOME/data/sbtest");
	system("cp -r $TEMP_DIR/mysql_myisam/* $MARIADB_HOME/data/mysql");
	system("perl bench_script.pl --max-time=$MAX_TIME \\\
--dbname=mariadb_5_2_7 \\\
--keyword=scenario2  \\\
--results-output-dir=./Scenario2 \\\
--warmup-time=$WARMUP_TIME \\\
--mysql-table-engine=myisam \\\
--noprepare \\\
--config-file=mariadb_my.cnf \\\
--workload=oltp_aria.lua \\\
--mysql-home=$MARIADB_HOME");


	#4) Run the gnuplot script to generate a graphic
	chdir("$PROJECT_HOME");
	system("gnuplot $PROJECT_HOME/gnuplot_scenario2.txt");

	print "\nScenario 2 complete\n";

}

sub Scenario3{
	print "--- Running Scenario 3 ---\n";
	chdir($PROJECT_HOME);
	
	#1) Create a folder on the SSD drive
	system("mkdir $SSD_HOME/$SSD_FOLDER_NAME");


	#2) Execute the perl script for the first test with MariaDB + XtraDB with both data and binlog on HDD
	system("cp -r $TEMP_DIR/innodb/* $MARIADB_HOME/data/sbtest");
	system("cp -r $TEMP_DIR/mysql_innodb/* $MARIADB_HOME/data/mysql");
	system("cp -r $MARIADB_HOME/data/ $SSD_HOME/$SSD_FOLDER_NAME/");
	system("perl bench_script.pl --max-time=$MAX_TIME \\\
--dbname=mariadb_5_2_7 \\\
--keyword=hdd  \\\
--results-output-dir=./Scenario3 \\\
--warmup-time=$WARMUP_TIME \\\
--mysql-table-engine=innodb \\\
--noprepare \\\
--config-file=mariadb_my.cnf \\\
--log-basename=hdd_binlog \\\
--log-bin \\\
--datadir=./data \\\
--mysql-home=$MARIADB_HOME");


	#3) Execute the perl script for the first test with MariaDB + XtraDB with both data and binlog on SSD
	system("cp -r $TEMP_DIR/innodb/* $SSD_HOME/$SSD_FOLDER_NAME/data/sbtest");
	system("cp -r $TEMP_DIR/mysql_innodb/* $SSD_HOME/$SSD_FOLDER_NAME/data/mysql");
	system("perl bench_script.pl --max-time=$MAX_TIME \\\
--dbname=mariadb_5_2_7 \\\
--keyword=ssd  \\\
--results-output-dir=./Scenario3 \\\
--warmup-time=$WARMUP_TIME \\\
--mysql-table-engine=innodb \\\
--noprepare \\\
--config-file=mariadb_my.cnf \\\
--log-basename=$SSD_HOME/$SSD_FOLDER_NAME/ssd_binlog \\\
--log-bin \\\
--datadir=$SSD_HOME/$SSD_FOLDER_NAME/data \\\
--mysql-home=$MARIADB_HOME");


	#4) Execute the perl script for the first test with MariaDB + XtraDB with data on HDD, and transactional log on SSD 
	system("cp -r $TEMP_DIR/innodb/* $MARIADB_HOME/data/sbtest");
	system("cp -r $TEMP_DIR/mysql_innodb/* $MARIADB_HOME/data/mysql");
	system("perl bench_script.pl --max-time=$MAX_TIME \\\
--dbname=mariadb_5_2_7 \\\
--keyword=ssd_hdd  \\\
--results-output-dir=./Scenario3 \\\
--warmup-time=$WARMUP_TIME \\\
--mysql-table-engine=innodb \\\
--noprepare \\\
--config-file=mariadb_my.cnf \\\
--log-basename=$SSD_HOME/$SSD_FOLDER_NAME/ssd_binlog \\\
--log-bin \\\
--datadir=./data \\\
--mysql-home=$MARIADB_HOME");

	
	#5) Cleanup the files from SSD
	system("rm -r $SSD_HOME/$SSD_FOLDER_NAME");

	
	#6) Run the gnuplot script to generate a graphic
	chdir("$PROJECT_HOME");
	system("gnuplot $PROJECT_HOME/gnuplot_scenario3.txt");


	print "\nScenario 3 complete\n";
}

#PrepareDBs();
#Scenario1();
#Scenario2();
Scenario3();
