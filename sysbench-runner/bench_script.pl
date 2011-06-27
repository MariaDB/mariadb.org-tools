#!/usr/bin/env perl
use warnings;
use strict;

# import module
use Getopt::Long;

my $results_output_dir 	= "./TestResults";
my $sysbench_dir		= "../sysbench/sysbench";

my $mysql_host			= "127.0.0.1";
my $mysql_user			= "root";
my $tables_count		= 24;
my $table_size			= 2000000;
my @threads_count_def	= (1, 4, 8, 12, 16, 24, 32, 48, 64, 128); #default value
my @threads_count;
my $max_time			= 1200; #in seconds
my $table_engine		= "innodb";

my $dry_run				= 0;
my $noprepare			= 0;
my $nocleanup			= 0;
my $plot_graph			= 0;
my $parallel_prepare	= 0;
my $prepare_threads		= 24; # $tables_count should be a multiplier of $prepare_threads
my $gnuplot_script		= "./gnuplot_scenario1.txt";
my $dbname				= "mariadb_5_2_7";
my $keyword				= "";
my $readonly			= "";
my $bReadonly			= 0; 							#execute only select operations
my $workload			= "oltp.lua"; 					#the default workload.
my $nowarmup			= 0; 							#by default a warmup will be performed
my $warmup_threads_num	= 4; 							#how many threads will execute the warmup
my $warmup_time			= 300; 							#in seconds

#mysql options (TODO: mysql parameters are under construction)
my $mysqlDir			= "../mysql";
my $nostart_mysql		= 0;
my $nostop_mysql		= 0;
my $datadir				= "./data";
my $max_connections		= "256";
my $key_buffer_size		= "1G";
my $sort_buffer_size	= "24M";
my $read_buffer_size	= "24M";



#my $pid; (TODO for fork)

######################################## Get input parameters ########################################
GetOptions ("dry-run" 				=> \$dry_run, 
			"max-time:i" 			=> \$max_time, 
			"mysql-user:s"			=> \$mysql_user, 
			"oltp-tables-count:i" 	=> \$tables_count, 
			"threads|t:s"			=> \@threads_count,
			"noprepare" 			=> \$noprepare,
			"nocleanup" 			=> \$nocleanup,
			"mysql-table-engine:s"	=> \$table_engine,
			"table-size:i"			=> \$table_size,
			"plot"					=> \$plot_graph,
			"gnuplot-script:s"		=> \$gnuplot_script,
			"dbname:s"				=> \$dbname,
			"keyword:s"				=> \$keyword,
			"results-output-dir:s"	=> \$results_output_dir,
			"readonly"				=> \$bReadonly,
			"workload:s"			=> \$workload,
			"nowarmup"				=> \$nowarmup,
			"warmup-threads:i"		=> \$warmup_threads_num,
			"warmup-time:i"			=> \$warmup_time,
			"no-start-mysql"		=> \$nostart_mysql,
			"no-stop-mysql"			=> \$nostop_mysql,
			"datadir:s"				=> \$datadir,
			"mysql-host:s"			=> \$mysql_host,
			"parallel-prepare"		=> \$parallel_prepare,
			"prepare-threads:i"		=> \$prepare_threads);  

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

	my $prepare_stmt = "$sysbench_dir/sysbench --mysql-host=$mysql_host --mysql-user=$mysql_user --test=$sysbench_dir/tests/db/$prepare_workload $num_prepare_threads --oltp-tables-count=$tables_count --mysql-table-engine=$table_engine --oltp-table-size=$table_size prepare";
	print "\n####### Prepare statement #######\n$prepare_stmt\n##########################\n";
	if(!$dry_run){
		print `$prepare_stmt`;
	}
}


sub Warmup{
	#warmup the caches by running for some time
	my $warmup_stmt = "$sysbench_dir/sysbench --mysql-host=$mysql_host --mysql-user=$mysql_user --test=$sysbench_dir/tests/db/$workload --oltp-tables-count=$tables_count --max-time=$warmup_time --num-threads=$warmup_threads_num --mysql-table-engine=$table_engine $readonly run > $results_output_dir/res_$keyword"."_$dbname"."_$table_engine"."_warmup.txt"; 
	print "\n-------- Warming up with $warmup_threads_num threads for $warmup_time seconds--------\n$warmup_stmt\n--------------------------------\n";
	if(!$dry_run){
		print `$warmup_stmt`;
	}
}


sub Run{
	#execute Run statements
	print "\n####### Run statements #######";
	foreach my $thread_num (@threads_count){
		my $run_stmt = "$sysbench_dir/sysbench --mysql-host=$mysql_host --mysql-user=$mysql_user --test=$sysbench_dir/tests/db/$workload --oltp-tables-count=$tables_count --max-time=$max_time --num-threads=$thread_num --mysql-table-engine=$table_engine $readonly run > $results_output_dir/res_$keyword"."_$dbname"."_$table_engine"."_$thread_num.txt"; 
	
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
		my $cleanup_stmt = "$sysbench_dir/sysbench --mysql-host=$mysql_host --mysql-user=$mysql_user --test=$sysbench_dir/tests/db/$workload --oltp-tables-count=$tables_count cleanup";
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
	my $mysqld_options = 	"--datadir=$datadir \\\
							--user=$mysql_user \\\
							--max_connections=$max_connections \\\
							--key_buffer_size=$key_buffer_size \\\
							--sort_buffer_size=$sort_buffer_size \\\
							--read_buffer_size=$read_buffer_size";

	chdir $mysqlDir;
	my $startMysql_stmt = "./bin/mysqld_safe $mysqld_options &";
	print "Starting mysqld with the following line:\n$startMysql_stmt\n\n";
	if(!$dry_run){
		print `$startMysql_stmt`;
	}
	#TODO: check for failure
}


#Stop the mysqld process (TODO)
sub StopMysql{
	chdir $mysqlDir;
	my $stopMysql_stmt = "./bin/mysqladmin --user=$mysql_user shutdown 0";
	print "Stopping mysql with the following line:\n$stopMysql_stmt\n\n";
	if(!$dry_run){
		print `$stopMysql_stmt`;
	}
	#TODO: check for failure
}



######################################## Main program ########################################
#TODO...
#if(!$nostart_mysql){
#	unless ($pid = fork) {
#        unless (fork) {
#			StartMysql();
#           exit 0;
#        }
#        exit 0;
#    }
#    waitpid($pid,0);
#}

if(!$noprepare){
	Prepare();
}

if(!$nowarmup){
	Warmup();
}


Run();

if(!$nocleanup){
	Cleanup();
}

if(!$dry_run){
	ExtractResults();
	if($plot_graph){
		PlotGraph();
	}
}

#TODO...
#if(!$nostop_mysql){
#	StopMysql();
#}
exit;

