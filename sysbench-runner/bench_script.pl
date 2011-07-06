#!/usr/bin/env perl
use warnings;
use strict;

# import module
use Getopt::Long;

my $results_output_dir 	= "./TestResults";
my $sysbench_dir		= "../../sysbench/sysbench";
my $PROJECT_HOME		= $ENV{"HOME"}."/Projects/MariaDB/mariadb-tools/sysbench-runner";
my $MYSQL_HOME			= $ENV{"HOME"}."/Projects/MariaDB/mysql-5.5.13-linux2.6-x86_64/";

my $mysql_host			= "localhost";
my $socket				= $ENV{"HOME"}."/Projects/MariaDB/temp/mysql.sock";
my $mysql_user			= "root";
my $tables_count		= 24;
my $table_size			= 2000000;
my @threads_count_def	= (1, 4, 8, 12, 16, 24, 32, 48, 64, 128); #default value
my @threads_count;
my $max_time			= 1200; #in seconds
my $table_engine		= "innodb";

my $dry_run				= 0;
my $noprepare			= 0;
my $norun				= 0;
my $nocleanup			= 0;
my $plot_graph			= 0;
my $parallel_prepare	= 0;
my $prepare_threads		= 24; # $tables_count should be a multiplier of $prepare_threads
my $gnuplot_script		= "./gnuplot_scenario1.txt";
my $dbname				= "mysql_5_5_13";
my $keyword				= "";
my $readonly			= "";
my $bReadonly			= 0; 							#execute only select operations
my $workload			= "oltp.lua"; 					#the default workload.
my $nowarmup			= 0; 							#by default a warmup will be performed
my $warmup_threads_num	= 4; 							#how many threads will execute the warmup
my $warmup_time			= 30; #300; 							#in seconds


my $pid;
#mysql options (TODO: mysql parameters are under construction)
my $nostart_mysql		= 0;
my $nostop_mysql		= 0;
my $datadir				= "";
my $log_bin				= "";
my $innodb_log_group_home_dir = "";
my $config_file			= "mysql_my.cnf";



#my $pid; (TODO for fork)

######################################## Get input parameters ########################################
GetOptions ("dry-run" 						=> \$dry_run, 
			"max-time:i" 					=> \$max_time, 
			"mysql-user:s"					=> \$mysql_user, 
			"oltp-tables-count:i" 			=> \$tables_count, 
			"threads|t:s"					=> \@threads_count,
			"noprepare" 					=> \$noprepare,
			"norun"							=> \$norun,
			"nocleanup" 					=> \$nocleanup,
			"mysql-table-engine:s"			=> \$table_engine,
			"table-size:i"					=> \$table_size,
			"plot"							=> \$plot_graph,
			"gnuplot-script:s"				=> \$gnuplot_script,
			"dbname:s"						=> \$dbname,
			"keyword:s"						=> \$keyword,
			"results-output-dir:s"			=> \$results_output_dir,
			"readonly"						=> \$bReadonly,
			"workload:s"					=> \$workload,
			"nowarmup"						=> \$nowarmup,
			"warmup-threads:i"				=> \$warmup_threads_num,
			"warmup-time:i"					=> \$warmup_time,
			"no-start-mysql"				=> \$nostart_mysql,
			"no-stop-mysql"					=> \$nostop_mysql,
			"datadir:s"						=> \$datadir,
			"log-bin:s"						=> \$log_bin,
			"innodb_log_group_home_dir:s" 	=> \$innodb_log_group_home_dir,
			"config-file:s"					=> \$config_file,
			"mysql-home:s"					=> \$MYSQL_HOME,
			"mysql-host:s"					=> \$mysql_host,
			"socket:s"						=> \$socket,
			"parallel-prepare"				=> \$parallel_prepare,
			"prepare-threads:i"				=> \$prepare_threads);  

if($dry_run){
	print "Starting program in DRY-RUN mode\n";
}

if($bReadonly){
	$readonly = "--oltp-read-only=true";
}

if(@threads_count == 0){
	@threads_count = @threads_count_def;
}

my $result_filename			= $results_output_dir."/res_$keyword"."_$dbname"."_$table_engine"."_final.txt";


######################################## Function declarations ########################################
sub Prepare{
	#execute Prepare statement
	my $num_prepare_threads = "";
	my $prepare_workload = $workload;
	if($parallel_prepare){
		$num_prepare_threads = "--num-threads=$prepare_threads";
		$prepare_workload = "parallel_prepare.lua";
	}

	my $prepare_stmt = "$sysbench_dir/sysbench --mysql-host=$mysql_host --mysql-socket=$socket --mysql-user=$mysql_user --test=$sysbench_dir/tests/db/$prepare_workload $num_prepare_threads --oltp-tables-count=$tables_count --mysql-table-engine=$table_engine --oltp-table-size=$table_size prepare";
	print "\n####### Prepare statement #######\n$prepare_stmt\n##########################\n";
	if(!$dry_run){
		print `$prepare_stmt`;
	}
}


sub Warmup{
	#warmup the caches by running for some time
	my $warmup_stmt = "$sysbench_dir/sysbench --mysql-host=$mysql_host --mysql-socket=$socket --mysql-user=$mysql_user --test=$sysbench_dir/tests/db/$workload --oltp-tables-count=$tables_count --max-time=$warmup_time --max-requests=0 --num-threads=$warmup_threads_num --mysql-table-engine=$table_engine $readonly run > $results_output_dir/res_$keyword"."_$dbname"."_$table_engine"."_warmup.txt"; 
	print "\n-------- Warming up with $warmup_threads_num threads for $warmup_time seconds--------\n$warmup_stmt\n--------------------------------\n";
	if(!$dry_run){
		print `$warmup_stmt`;
	}
}


sub Run{
	#execute Run statements
	print "\n####### Run statements #######";
	foreach my $thread_num (@threads_count){
		my $run_stmt = "$sysbench_dir/sysbench --mysql-host=$mysql_host --mysql-socket=$socket --mysql-user=$mysql_user --test=$sysbench_dir/tests/db/$workload --oltp-tables-count=$tables_count --max-time=$max_time --max-requests=0 --num-threads=$thread_num --mysql-table-engine=$table_engine $readonly run > $results_output_dir/res_$keyword"."_$dbname"."_$table_engine"."_$thread_num.txt"; 
	
		print "\n-------- Run with $thread_num threads --------\n$run_stmt\n--------------------------------\n";
		if(!$dry_run){
			print `$run_stmt`;
		}
		print "Test with $thread_num threads completed. Results are in $results_output_dir/res_$keyword"."_$dbname"."_$table_engine"."_$thread_num.txt\n";
	}
	print "##########################\n";
}


sub Cleanup{
	#execute Cleanup statement
	if(!$nocleanup){
		my $cleanup_stmt = "$sysbench_dir/sysbench --mysql-host=$mysql_host --mysql-socket=$socket --mysql-user=$mysql_user --test=$sysbench_dir/tests/db/$workload --oltp-tables-count=$tables_count cleanup";
		print "\n####### Cleanup #######\n$cleanup_stmt\n##########################\n";
		if(!$dry_run){
			print `$cleanup_stmt`;
		}
	}
}



sub ExtractResults{
	#extract data from the result files
	open(my $fhw, '>', $result_filename);

	foreach my $thread_num (@threads_count){
		my $filename = $results_output_dir."/res_$keyword"."_$dbname"."_$table_engine"."_$thread_num.txt";
		open(my $fh, '<', $filename) or die "cannot open '$filename' $!";

		while(<$fh>){
			#find the transactions row
			if($_ =~ m/transactions:.*\(.* per sec.\)/){
				$_ =~ m/(\d+\.\d+)/g;

				#print to console			
				print $1 . "\n";

				#print to file
				print $fhw "$thread_num $1 \n";
			}
		}
	}

	close($fhw);
}


#print the jpeg with gnuplot
sub PlotGraph{
	print `gnuplot $gnuplot_script`;
}

#Start the mysqld process with parameters (TODO)
sub StartMysql{

	my $started = -1;
	my $j=0;
	my $timeout=100;
	my $MYSQLADMIN_OPTIONS = "--socket=$socket";
	my $mysqld_options = "--defaults-file=$PROJECT_HOME/config/$config_file --socket=$socket ";
	if($datadir){
		$mysqld_options .= " --datadir=$datadir";
	}
	if($log_bin){
		$mysqld_options .= " --log-bin=$log_bin";
	}
	if($innodb_log_group_home_dir){
		$mysqld_options .= " --innodb_log_group_home_dir=$innodb_log_group_home_dir";
	}

	chdir($MYSQL_HOME) or die "Cant chdir to $MYSQL_HOME $!";
	my $startMysql_stmt = "./bin/mysqld_safe $mysqld_options &";
	print "Starting mysqld with the following line:\n$startMysql_stmt\n\n";
	if(!$dry_run){
		system($startMysql_stmt);
	
	 	while ($j <= $timeout){	
			system("./bin/mysqladmin $MYSQLADMIN_OPTIONS ping > /dev/null 2>&1");		
		    if ($? == 0){
		        $started=0;
		        last;
		    }
		    sleep 1;
		    $j = $j + 1;		
		}

		if($started != 0){
		    print "[ERROR]: Start of mysqld failed.\n";
		    print "  Please check your error log.\n";
		    print "  Exiting.\n";
		    exit 1;
	   	}
	}
}


#Stop the mysqld process 
sub StopMysql{
	chdir($MYSQL_HOME) or die "Cant chdir to $MYSQL_HOME $!";;
	my $stopMysql_stmt = "./bin/mysqladmin --socket=$socket --user=$mysql_user shutdown 0";
	print "Stopping mysql with the following line:\n$stopMysql_stmt\n\n";
	if(!$dry_run){
		print `$stopMysql_stmt`;
	}
	#TODO: check for failure
}



######################################## Main program ########################################

if(!$nostart_mysql){
	StartMysql();
	chdir($PROJECT_HOME) or die "Cannot change dir to $PROJECT_HOME";
}



if(!$noprepare){
	Prepare();
}

if(!$nowarmup){
	Warmup();
}

if(!$norun){
	Run();
}

if(!$nocleanup){
	Cleanup();
}

if(!$dry_run){
	if(!$norun){
		ExtractResults();
		if($plot_graph){
			PlotGraph();
		}
	}
}


if(!$nostop_mysql){
	StopMysql();
}
exit;

