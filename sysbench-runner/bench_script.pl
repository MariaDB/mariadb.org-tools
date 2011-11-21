#!/usr/bin/env perl
use warnings;
use strict;

# import module
use Getopt::Long;
use File::Path;

my $results_output_dir	= "";

my $MYSQL_HOME		= "";
my $SYSBENCH_HOME	= "";
my $socket		= "";
my $mysql_user		= "";
my $tables_count	= 0;
my $table_size		= 0;
my @threads_count;
my $max_time		= 0; 	#in seconds
my $table_engine	= "";

my $dry_run		= 0;
my $prepare		= 0;
my $warmup		= 0;
my $run			= 0;
my $cleanup		= 0;
my $install		= 0;
my $plot_graph		= 0;
my $parallel_prepare	= 0;
my $prepare_threads	= 0; 	# $tables_count should be a multiplier of $prepare_threads
my $gnuplot_script	= "";
my $dbname		= "";
my $keyword		= "";
my $readonly		= "";
my $bReadonly		= 0; 	#execute only select operations
my $workload		= "";	#the default workload.
my $warmup_threads_num	= 0; 	#how many threads will execute the warmup
my $warmup_time		= 0;	#in seconds
my $pre_run_sql		= "";
my $do_pre_run		= 0;
my $mysqld_start_params = "";
my $warmup_delay	= 0;	#How many seconds should the warmup run be delayed after prepare
my $run_delay		= 0;	#How many seconds should the actual run be delayed after warmup or prepare

my $nostart_mysql		= 0;
my $nostop_mysql		= 0;
my $datadir			= "";
#my $log_bin			= "";
#my $innodb_log_group_home_dir	= "";
my $config_file			= "";



######################################## Get input parameters ########################################
GetOptions ("dry-run" 				=> \$dry_run, 
		"max-time:i" 			=> \$max_time, 
		"mysql-user:s"			=> \$mysql_user, 
		"oltp-tables-count:i" 		=> \$tables_count, 
		"threads|t:s"			=> \@threads_count,
		"prepare" 			=> \$prepare,
		"warmup"			=> \$warmup,
		"run"				=> \$run,
		"cleanup" 			=> \$cleanup,
		"install"			=> \$install,
		"mysql-table-engine:s"		=> \$table_engine,
		"table-size:i"			=> \$table_size,
		"plot"				=> \$plot_graph,
		"gnuplot-script:s"		=> \$gnuplot_script,
		"dbname:s"			=> \$dbname,
		"keyword:s"			=> \$keyword,
		"results-output-dir:s"		=> \$results_output_dir,
		"readonly"			=> \$bReadonly,
		"workload:s"			=> \$workload,
		"warmup-threads:i"		=> \$warmup_threads_num,
		"warmup-time:i"			=> \$warmup_time,
		"no-start-mysql"		=> \$nostart_mysql,
		"no-stop-mysql"			=> \$nostop_mysql,
		"datadir:s"			=> \$datadir,
		"config-file:s"			=> \$config_file,
		"mysql-home:s"			=> \$MYSQL_HOME,
		"sysbench-home:s"		=> \$SYSBENCH_HOME,
		"socket:s"			=> \$socket,
		"parallel-prepare"		=> \$parallel_prepare,
		"prepare-threads:i"		=> \$prepare_threads,
		"pre-run-sql:s"			=> \$pre_run_sql,
		"do-pre-run"			=> \$do_pre_run,
		"mysqld-start-params:s"		=> \$mysqld_start_params,
		"warmup-delay:i"		=> \$warmup_delay,
		"run-delay:i"			=> \$run_delay);  




######################################## Function declarations ########################################
sub GetTimestamp{
	my($sec, $min, $hour, $day, $month, $year) = (localtime)[0,1,2,3,4,5];
	$sec	= sprintf '%02d', $sec;
	$min	= sprintf '%02d', $min;
	$hour	= sprintf '%02d', $hour;
	$month	= sprintf '%02d', $month+1;
	$day	= sprintf '%02d', $day;
	$year	= $year + 1900;
	return $year . "-$month" . "-$day" . " $hour" . ":$min" . ":$sec";
}


sub CheckInputParams{
	my $retErrors 	= "";
	my $warnings 	= "";

	#Warnings
	if($dry_run){
		$warnings .= "### WARNING: Starting program in DRY-RUN mode\n";
	}

	if($bReadonly){
		$warnings .= "### WARNING: Starting program in READONLY mode\n";
		$readonly = "--oltp-read-only=on";
	}

	if(!$datadir){
		$warnings .= "### WARNINIG: No 'datadir' input parameter detected. This will use default data directory.\n";
	}

# 	if($run && $innodb_log_group_home_dir){
# 		if(!(-e $innodb_log_group_home_dir)){
# 			$warnings .= "### WARNINIG: Directory '$innodb_log_group_home_dir' does not exist. Creating it for you.\n";
# 			mkdir ($innodb_log_group_home_dir);
# 		}
# 	}

	#Errors
	if(($prepare || $warmup || $run || $cleanup) && !$tables_count){
		$retErrors .= "ERROR: Input parameter 'oltp-tables-count' is missing. \n";
	}

	if($prepare && !$table_size){
		$retErrors .= "ERROR: Input parameter 'table-size' is missing. \n";
	}

	if(($prepare || $warmup || $run || $cleanup) && !$SYSBENCH_HOME){
		$retErrors .= "ERROR: Input parameter 'sysbench-home' is missing. \n";
	}
	
	if(!$nostart_mysql || !$nostop_mysql || $install){
		if(!$MYSQL_HOME){
			$retErrors .= "ERROR: Input parameter 'mysql-home' is missing. \n";
		}elsif (!(-e $MYSQL_HOME)){
			$retErrors .= "ERROR: The folder for 'mysql-home' ($MYSQL_HOME) does not exist. \n";
		}
	}

	if((!$nostart_mysql || $prepare || $warmup || $run || $cleanup || !$nostop_mysql) && !$socket){
		$retErrors .= "ERROR: Input parameter 'socket' is missing. \n";
	}

	if(($prepare || $run || $warmup) && !$table_engine){
		$retErrors .= "ERROR: Input parameter 'mysql-table-engine' is missing. \n";
	}

	if($run && !$max_time){
		$retErrors .= "ERROR: Input parameter 'max-time' is missing. \n";
	}

	if($prepare && $parallel_prepare && !$prepare_threads){
		$retErrors .= "ERROR: Input parameter 'prepare-threads' is missing. \n";
	} elsif ($prepare && $parallel_prepare && $tables_count % $prepare_threads != 0){
		$retErrors .= "ERROR: Input parameter 'tables-count' should be a multiplier of 'prepare-threads'.\n";
	}

	if($do_pre_run && !$pre_run_sql){
		$retErrors .= "ERROR: Input parameter 'pre_run_sql' is missing.\n";
	}
	
	if($run && !@threads_count){
		$retErrors .= "ERROR: Input parameter 'threads' or 't' is missing. (Example: -t=1 -t=2 -t=3) \n";
	}

	if(($run || $warmup) && !$dbname){
		$retErrors .= "ERROR: Input parameter 'dbname' is missing. \n";
	}

	if(($prepare || $warmup || $run || $cleanup) && !$workload){
		$retErrors .= "ERROR: Input parameter 'workload' is missing. \n";
	}

	if($warmup && !$warmup_threads_num){
		$retErrors .= "ERROR: Input parameter 'warmup-threads' is missing. \n";
	}

	if($warmup && !$warmup_time){
		$retErrors .= "ERROR: Input parameter 'warmup-time' is missing. \n";
	}

	if(($warmup || $run) && !$results_output_dir){
		$retErrors .= "ERROR: Input parameter 'results-output-dir' is missing. \n";
	}else{
		if(($warmup || $run) && !(-e $results_output_dir)){
			mkpath ($results_output_dir);
		} else {
# 			$retErrors .= "ERROR: The results output directory $results_output_dir already exists";
		}
	}
	
	if(($prepare || $warmup || $run || $cleanup || !$nostop_mysql || $install) && !$mysql_user){
		$retErrors .= "ERROR: Input parameter 'mysql-user' is missing. \n";
	}
	
	if((!$nostart_mysql || $install) && !$config_file){
		$retErrors .= "ERROR: Input parameter 'config-file' is missing. \n";
	}

	PrintMsg("$warnings\n\n");

	return $retErrors;
}



sub Prepare{
	#execute Prepare statement
	my $num_prepare_threads = "";
	my $prepare_workload = $workload;
	if($parallel_prepare){
		$num_prepare_threads = "--num-threads=$prepare_threads";
		$prepare_workload = "$SYSBENCH_HOME/tests/db/parallel_prepare.lua";
	}

	my $prepare_stmt = "$SYSBENCH_HOME/sysbench \\\
--mysql-socket=$socket \\\
--mysql-user=$mysql_user \\\
--test=$prepare_workload $num_prepare_threads \\\
--oltp-tables-count=$tables_count \\\
--mysql-table-engine=$table_engine \\\
--oltp-table-size=$table_size \\\
--myisam_max_rows=10000000 prepare";
	PrintMsg("\n####### Prepare statement #######\n$prepare_stmt\n##########################\n");
	if(!$dry_run){
		print `$prepare_stmt`;
	}
}


sub Warmup{
	#warmup the caches by running for some time
	my $warmup_stmt = "$SYSBENCH_HOME/sysbench --mysql-socket=$socket --mysql-user=$mysql_user --test=$workload --oltp-tables-count=$tables_count --max-time=$warmup_time --max-requests=0 --num-threads=$warmup_threads_num --mysql-table-engine=$table_engine $readonly run > $results_output_dir/res_$keyword"."_$dbname"."_$table_engine"."_warmup.txt"; 
	PrintMsg("\n-------- Warming up with $warmup_threads_num threads for $warmup_time seconds --------\n$warmup_stmt\n--------------------------------\n");
	if(!$dry_run){
		print `$warmup_stmt`;
	}
}


sub Run{
	#execute Run statements
	PrintMsg( "\n####### Run statements #######");
	foreach my $thread_num (@threads_count){
		my $run_stmt = "$SYSBENCH_HOME/sysbench --mysql-socket=$socket --mysql-user=$mysql_user --test=$workload --oltp-tables-count=$tables_count --max-time=$max_time --max-requests=0 --num-threads=$thread_num --mysql-table-engine=$table_engine $readonly run > $results_output_dir/res_$keyword"."_$dbname"."_$table_engine"."_$thread_num.txt"; 
	
		PrintMsg("\n-------- Run with $thread_num threads --------\n$run_stmt\n--------------------------------\n");
		if(!$dry_run){
			print `$run_stmt`;
			print "Test with $thread_num threads completed. Results are in $results_output_dir/res_$keyword"."_$dbname"."_$table_engine"."_$thread_num.txt\n";
		}
	}
	PrintMsg( "##########################\n");
}


sub Cleanup{
	#execute Cleanup statement
	my $cleanup_stmt = "$SYSBENCH_HOME/sysbench --mysql-socket=$socket --mysql-user=$mysql_user --test=$workload --oltp-tables-count=$tables_count cleanup";
	PrintMsg("\n####### Cleanup #######\n$cleanup_stmt\n##########################\n");
	if(!$dry_run){
		print `$cleanup_stmt`;
	}
}



sub ExtractResults{
	my $result_filename = $results_output_dir."/res_$keyword"."_$dbname"."_$table_engine"."_final.txt";
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


sub ShowGlobalStatus{
	chdir($MYSQL_HOME) or die "Can't chdir to $MYSQL_HOME $!";
	my $showGlobal = "./bin/mysql -u $mysql_user --socket=$socket -e \"show global status;\" > $results_output_dir/global_status_$keyword"."_$dbname"."_$table_engine".".txt";
	PrintMsg("Getting globals with the following sql command: $showGlobal \n");
	if(!$dry_run){
		print `$showGlobal`;
	}
}

sub ShowVariables{
	chdir($MYSQL_HOME) or die "Can't chdir to $MYSQL_HOME $!";
	my $showVars = "./bin/mysql -u $mysql_user --socket=$socket -e \"show variables;\" > $results_output_dir/variables_$keyword"."_$dbname"."_$table_engine".".txt";
	PrintMsg("Showing variables with the following sql command: $showVars \n");
	if(!$dry_run){
		print `$showVars`;
	}
}

sub ShowEngines{
	chdir($MYSQL_HOME) or die "Can't chdir to $MYSQL_HOME $!";
	my $showEngines = "./bin/mysql -u $mysql_user --socket=$socket -e \"show engines;\" > $results_output_dir/engines_$keyword"."_$dbname"."_$table_engine".".txt";
	PrintMsg("Showing engines with the following sql command: $showEngines \n");
	if(!$dry_run){
		print `$showEngines`;
	}
}

sub ShowCreateTable{
	chdir($MYSQL_HOME) or die "Can't chdir to $MYSQL_HOME $!";
	my $showCreateTable = "./bin/mysql -u $mysql_user --socket=$socket -e \"use sbtest; show create table sbtest1;\" > $results_output_dir/show_create_table_$keyword"."_$dbname"."_$table_engine".".txt";
	PrintMsg("Showing Create table with the following sql command: $showCreateTable \n");
	if(!$dry_run){
		print `$showCreateTable`;
	}
}

sub ExecutePreRunSQL{
	chdir($MYSQL_HOME) or die "Can't chdir to $MYSQL_HOME $!";
	my $sql = "./bin/mysql -u $mysql_user --socket=$socket -e \"$pre_run_sql\"";
	PrintMsg("Executing pre-run SQL:\n $sql \n");
	if(!$dry_run){
		print `$sql`;
	}
}

sub Install{
	chdir($MYSQL_HOME) or die "Can't chdir to $MYSQL_HOME $!";
	my $installStr = "./scripts/mysql_install_db --defaults-file=$config_file --datadir=$datadir";
	PrintMsg("Installing database:\n $installStr \n");
	if(!$dry_run){
		system($installStr);
	}
}


sub CreateDB_sbtest{
	chdir($MYSQL_HOME) or die "Can't chdir to $MYSQL_HOME $!";	
	my $createStr = "./bin/mysqladmin -u $mysql_user -S $socket create sbtest";
	PrintMsg("Creating database with the following command:\n $createStr \n");
	if(!$dry_run){
		system($createStr);
	}
}


#Start the mysqld process with parameters (TODO)
sub StartMysql{

	my $started = -1;
	my $j=0;
	my $timeout=100;
	my $MYSQLADMIN_OPTIONS = "--socket=$socket";
	my $mysqld_options = "--defaults-file=$config_file --socket=$socket ";
	if($datadir){
		$mysqld_options .= " --datadir=$datadir";
	}
# 	if($log_bin){
# 		$mysqld_options .= " --log-bin=$log_bin";
# 	}
	if($mysqld_start_params){
		$mysqld_options .= " $mysqld_start_params";
	}

	chdir($MYSQL_HOME) or die "Can't chdir to $MYSQL_HOME $!";
	my $startMysql_stmt = "./bin/mysqld_safe $mysqld_options &";
	PrintMsg("Starting mysqld with the following line:\n$startMysql_stmt\n\n");
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
	chdir($MYSQL_HOME) or die "Can't chdir to $MYSQL_HOME $!";;
	my $stopMysql_stmt = "./bin/mysqladmin --socket=$socket --user=$mysql_user shutdown 0";
	PrintMsg("Stopping mysql with the following line:\n$stopMysql_stmt\n\n");
	if(!$dry_run){
		print `$stopMysql_stmt`;
	}
	#TODO: check for failure
}


sub PrintMsg{
	#TODO: hide the printed messages if a setting is set
	my $msg = $_[0];
	print "\n*** " .GetTimestamp() ." *** bench_script.pl: $msg";
}

######################################## Main program ########################################
my $paramsCheck = CheckInputParams();
if(length($paramsCheck) > 0){
	print $paramsCheck;
	exit;
}

if($install){
	Install();
}

if(!$nostart_mysql){
	StartMysql();
}

if($install){
	CreateDB_sbtest();
}

if($prepare){
	Prepare();
}

if($do_pre_run){
	ExecutePreRunSQL();
}

if($warmup){
	if($warmup_delay > 0){
		print "Delaying warmup with $warmup_delay seconds.";
		sleep $warmup_delay;
	}
	Warmup();
}

if($run){
	if($run_delay > 0){
		print "Delaying run with $run_delay seconds.";
		sleep $run_delay;
	}
	Run();
	ShowGlobalStatus();
	ShowVariables();
	ShowEngines();
	ShowCreateTable();
}

if($cleanup){
	Cleanup();
}

if(!$dry_run){
	if($run){
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

