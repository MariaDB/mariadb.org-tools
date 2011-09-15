#!/usr/bin/env perl
use warnings;
use strict;

# import module
use Getopt::Long;
use File::Path;
use File::Copy;


#push(@INC, "/home/vlado/Projects/dbt3/DBD-mysql-4.019/lib/");
#push(@INC, "/home/vlado/Projects/dbt3/DBD-mysql-4.019/lib/DBD/");  

# system("export PERL5LIB=/home/vlado/Projects/dbt3/DBD-mysql-4.019/lib");
# system("export LD_LIBRARY_PATH=/home/vlado/Projects/dbt3/DBD-mysql-4.019/blib/arch/auto/DBD/mysql/:/home/vlado/Projects/dbt3/mariadb-5.3.0-beta-Linux-x86_64/lib/mysql/");
# $ENV{PERL5LIB} = "/home/vlado/Projects/dbt3/DBD-mysql-4.019/lib";
# $ENV{LD_LIBRARY_PATH} = "/home/vlado/Projects/dbt3/DBD-mysql-4.019/blib/arch/auto/DBD/mysql/:/home/vlado/Projects/dbt3/mariadb-5.3.0-beta-Linux-x86_64/lib/mysql/";


use DBI;

our $QUERIES_AT_ONCE	= 0;
our $CLEAR_CACHES	= 0;
our $WARMUP		= 0;
our $EXPLAIN		= 0;
our $RUN		= 0;
our $USER_IS_ADMIN	= 0;

our $QUERIES_HOME	= "";
# our $PROJECT_HOME	= ".";
our $MYSQL_HOME		= "";
our $MYSQL_USER		= "";
our $CONFIG_FILE	= "";
our $SOCKET		= "";
our $PORT		= 0;
our $DATADIR		= "";
our $DBNAME		= "";
our $QUERY		= "";
our $EXPLAIN_QUERY	= "";
our $TIMEOUT		= 0;
our $OS_STATS_INTERVAL	= 0;
our $PRE_RUN_SQL	= "";
our $POST_RUN_SQL	= "";
our $PRE_TEST_SQL	= "";
our $POST_TEST_SQL	= "";
our $PRE_RUN_OS		= "";
our $POST_RUN_OS	= "";
our $PRE_TEST_OS	= "";
our $POST_TEST_OS	= "";
our $NUM_TESTS		= 0;
our $WARMUPS_COUNT	= 0;
our $MAX_QUERY_TIME	= 0;
our $CLUSTER_SIZE	= 0;
our $KEYWORD		= "";
our $DBMS		= "";
our $STORAGE_ENGINE	= "";
our $SCALE_FACTOR	= 0;
our $STARTUP_PARAMS	= "";
our $GRAPH_HEADING	= "";

our @configurations;


#Results DB configuration vars:
our $RESULTS_MYSQL_HOME		= "";
our $RESULTS_MYSQL_USER		= "";
our $RESULTS_DATADIR		= "";
our $RESULTS_CONFIG_FILE	= "";
our $RESULTS_SOCKET		= "";
our $RESULTS_PORT		= 0;
our $RESULTS_STARTUP_PARAMS	= "";
our $RESULTS_DB_NAME		= "";


#input parameter variables
my @test_files;
my $RESULTS_OUTPUT_DIR	= "";
my $dry_run		= 0;

#local variables
my $l_QUERIES_HOME	= "";
my $l_MYSQL_HOME	= "";
my $l_MYSQL_USER	= "";
my $l_CONFIG_FILE	= "";
my $l_SOCKET		= "";
my $l_PORT		= 0;
my $l_DATADIR		= "";
my $l_DBNAME		= "";
my $l_STARTUP_PARAMS	= "";
my $l_QUERY		= "";
my $l_EXPLAIN_QUERY	= "";
my $l_EXPLAIN		= 0;
my $l_TIMEOUT		= 0;
my $l_PRE_RUN_SQL	= "";
my $l_POST_RUN_SQL	= "";
my $l_PRE_RUN_OS	= "";
my $l_POST_RUN_OS	= "";
my $l_NUM_TESTS		= 0;
my $l_WARMUP		= 0;
my $l_WARMUPS_COUNT	= 0;
my $l_MAX_QUERY_TIME	= 0;
my $l_CLUSTER_SIZE	= 0;
my $l_GRAPH_HEADING	= "";



GetOptions (	"test|t:s" 			=> \@test_files,
		"results-output-dir|r:s"	=> \$RESULTS_OUTPUT_DIR,
		"dry-run" 			=> \$dry_run);



######################################## Function declarations ########################################
sub GetTimestamp{
	my $asFilename 	= $_[0];
	my $retStr	= "";

	my($sec, $min, $hour, $day, $month, $year) = (localtime)[0,1,2,3,4,5];
	$sec	= sprintf '%02d', $sec;
	$min	= sprintf '%02d', $min;
	$hour	= sprintf '%02d', $hour;
	$month	= sprintf '%02d', $month+1;
	$day	= sprintf '%02d', $day;
	$year	= $year + 1900;

	if($asFilename){
		$retStr =  $year . "-$month" . "-$day" . "_$hour$min$sec";
	}else{
		$retStr =  $year . "-$month" . "-$day" . " $hour" . ":$min" . ":$sec";
	}

	return $retStr;
}

sub GetTimestampAsFilename{
	return GetTimestamp(1);
}


sub CheckInputParams{
	my $retVal 	= 1;
	my $errors 	= "";
	my $warnings 	= "";

	#Warnings
	if($dry_run){
		$warnings .= "### WARNING: Starting program in DRY-RUN mode\n";
	}

	if(!@test_files){
		$errors = "### ERROR: Missing input parameter 'test'.\n";
	}else{
		foreach my $file (@test_files){
			if(!(-e $file)){
				$errors .= "### ERROR: Configuration file $file does not exist \n";
			}
		}
	}

	if(!$RESULTS_OUTPUT_DIR){
		$errors .= "### ERROR: Config parameter 'results-output-dir' is missing. \n";
	}


	if($warnings){
		print $warnings;
	}

	if($errors){
		$retVal = 0;
		print $errors;
	}

	return $retVal;
}


sub CheckConfigParams{
	my $retVal 	= 1;
	my $errors 	= "";
	my $warnings 	= "";
	
	#Errors
	
# 	if(!$PROJECT_HOME){
# 		$errors .= "### ERROR: Config parameter 'PROJECT_HOME' is missing. \n"
# 	}

	if(!$l_QUERIES_HOME){
		$errors .= "### ERROR: Config parameter 'QUERIES_HOME' is missing. \n";
	}

	if(!$l_MYSQL_HOME){
		$errors .= "### ERROR: Config parameter 'MYSQL_HOME' is missing. \n";
	}

	if(!$l_MYSQL_USER){
		$errors .= "### ERROR: Config parameter 'MYSQL_USER' is missing. \n";
	}

	if(!$l_CONFIG_FILE){
		$errors .= "### ERROR: Config parameter 'CONFIG_FILE' is missing. \n";
	}

	if(!$l_SOCKET){
		$errors .= "### ERROR: Config parameter 'SOCKET' is missing. \n";
	}

	if(!$l_PORT){
		$errors .= "### ERROR: Config parameter 'PORT' is missing. \n";
	}

	if(!$l_DATADIR){
		$errors .= "### ERROR: Config parameter 'DATADIR' is missing. \n";
	}

	if(!$l_DBNAME){
		$errors .= "### ERROR: Config parameter 'DBNAME' is missing. \n";
	}
	
	if(!$DBMS){
		$errors .= "### ERROR: Config parameter 'DBMS' is missing. \n";
	}else{
		if($DBMS ne "MariaDB" && $DBMS ne "MySQL" && $DBMS ne "PostgreSQL"){
			$errors .= "### ERROR: Unknown value for parameter DBMS: $DBMS. Possible values are: 'MariaDB', 'MySQL' and 'PostgreSQL' \n";
		}
	}

	if(!$KEYWORD){
		$errors .= "### ERROR: Config parameter 'KEYWORD' is missing. \n";
	}

# 	if(!$l_NUM_TESTS){
# 		$errors .= "### ERROR: Config parameter 'NUM_TESTS' is missing. \n";
# 	}
	

	#Results DB params:
	if(!$RESULTS_MYSQL_HOME){
		$errors .= "### ERROR: Config parameter 'RESULTS_MYSQL_HOME' is missing. \n";
	}

	if(!$RESULTS_MYSQL_USER){
		$errors .= "### ERROR: Config parameter 'RESULTS_MYSQL_USER' is missing. \n";
	}

	if(!$RESULTS_DATADIR){
		$errors .= "### ERROR: Config parameter 'RESULTS_DATADIR' is missing. \n";
	}

	if(!$RESULTS_CONFIG_FILE){
		$errors .= "### ERROR: Config parameter 'RESULTS_CONFIG_FILE' is missing. \n";
	}

	if(!$RESULTS_SOCKET){
		$errors .= "### ERROR: Config parameter 'RESULTS_SOCKET' is missing. \n";
	}

	if(!$RESULTS_PORT){
		$errors .= "### ERROR: Config parameter 'RESULTS_PORT' is missing. \n";
	}

	if(!$RESULTS_DB_NAME){
		$errors .= "### ERROR: Config parameter 'RESULTS_DB_NAME' is missing. \n";
	}


	if($warnings){
		print $warnings;
	}

	if($errors){
		$retVal = 0;
		print $errors;
	}

	return $retVal;
}


sub CollectHardwareInfo{
	$RESULTS_OUTPUT_DIR = $RESULTS_OUTPUT_DIR . "_" . GetTimestampAsFilename();
	if(!(-e $RESULTS_OUTPUT_DIR)){
		mkpath($RESULTS_OUTPUT_DIR);
	}
	system("/bin/cat /proc/cpuinfo > $RESULTS_OUTPUT_DIR/cpu_info.txt");
	system("uname -a > $RESULTS_OUTPUT_DIR/uname.txt");
}




sub CollectStatistics_OS{
	my $sleepTime 	= $_[0];
	my $cpuStats 	= $_[1];
	my $ioStats	= $_[2];
	my $memoryStats	= $_[3];
	my $keyword	= $_[4];
	my $queryName	= $_[5];
	my $queryRunNo	= $_[6];
	
	if($sleepTime == 0){
		$sleepTime = 1; #min interval - 1 second
	}

	my $i 		= 0;
	my $sar_u	= 0;
	my $sar_b	= 0;
	my $sar_r	= 0;

	while ($i < 30) {
		$i++;
		
		if($cpuStats){
			$sar_u = `sar -u 0 2>null`;
		}
		
		if($ioStats){
			$sar_b = `sar -b 0 2>null`;
		}

		if($memoryStats){
			$sar_r = `sar -r 0 2>null`;
		}

		#if that's the first time
		if($i == 1){
			if($cpuStats){
				open (SAR_U, ">> $RESULTS_OUTPUT_DIR/$keyword/$queryName"."_no_$queryRunNo"."_sar_u.txt");
				print SAR_U $sar_u;
				close (SAR_U); 
			}
			
			if($ioStats){
				open (SAR_B, ">> $RESULTS_OUTPUT_DIR/$keyword/$queryName"."_no_$queryRunNo"."_sar_b.txt");
				print SAR_B $sar_b;
				close (SAR_B); 
			}

			if($memoryStats){
				open (SAR_R, ">> $RESULTS_OUTPUT_DIR/$keyword/$queryName"."_no_$queryRunNo"."_sar_r.txt");
				print SAR_R $sar_r;
				close (SAR_R); 
			}
		}else {
			if($cpuStats){
				my @arr1 = split(/\n/, $sar_u);
				open (SAR_U, ">> $RESULTS_OUTPUT_DIR/$keyword/$queryName"."_no_$queryRunNo"."_sar_u.txt");
				print SAR_U $arr1[3] . "\n";
				close (SAR_U); 
			}

			if($ioStats){
				my @arr2 = split(/\n/, $sar_b);
				open (SAR_B, ">> $RESULTS_OUTPUT_DIR/$keyword/$queryName"."_no_$queryRunNo"."_sar_b.txt");
				print SAR_B $arr2[3] . "\n";
				close (SAR_B);
			}

			if($memoryStats){
				my @arr3 = split(/\n/, $sar_r);
				open (SAR_R, ">> $RESULTS_OUTPUT_DIR/$keyword/$queryName"."_no_$queryRunNo"."_sar_r.txt");
				print SAR_R $arr3[3] . "\n";
				close (SAR_R); 
			}
		}
		sleep $sleepTime;
# 		last;
	};
	exit(0);
}



#Start the mysqld process with parameters
sub StartMysql{
	my $mysql_home		= $_[0];
	my $datadir		= $_[1];
	my $config_file		= $_[2];
	my $socket		= $_[3];
	my $port		= $_[4];
	my $startup_params	= $_[5];



	my $retVal = 1;

	my $started = -1;
	my $j=0;
	my $timeout=100;
	my $mysql_admin_options = "--socket=$socket";
	my $mysqld_options = "--defaults-file=$config_file --port=$port --socket=$socket --read-only ";
	if($datadir){
		$mysqld_options .= " --datadir=$datadir";
	}

	if($startup_params){
		$mysqld_options .= " $startup_params";
	}

	chdir($mysql_home) or die "Can't chdir to $mysql_home $!";
	my $startMysql_stmt = "./bin/mysqld_safe $mysqld_options &";
	PrintMsg("Starting mysqld with the following line:\n$startMysql_stmt\n\n");
	if(!$dry_run){
		system($startMysql_stmt);
	
	 	while ($j <= $timeout){	
			system("./bin/mysqladmin $mysql_admin_options ping > /dev/null 2>&1");		
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
		    $retVal = 0;
	   	}
		copy ($config_file, "$RESULTS_OUTPUT_DIR/");

	}

	return $retVal;
}


#Stop the mysqld process 
sub StopMysql{
	my $mysql_home	= $_[0];
	my $socket	= $_[1];
	my $port	= $_[2];
	my $mysql_user	= $_[3];


	my $retVal = 1;

	chdir($mysql_home) or die "Can't chdir to $mysql_home $!";
	my $stopMysql_stmt = "./bin/mysqladmin --socket=$socket --port=$port --user=$mysql_user shutdown 0";
	PrintMsg("Stopping mysql with the following line:\n$stopMysql_stmt\n\n");
	if(!$dry_run){
		print `$stopMysql_stmt`;
	}
	# TODO: check for failure
	return $retVal;
}



#PostgreSQL
sub StartPostgres{
	my $postgres_home	= $_[0];
	my $datadir		= $_[1];
	my $config_file		= $_[2];
	my $port		= $_[3];
	my $startup_params	= $_[4];

	
	chdir($postgres_home) or die "Can't chdir to $postgres_home $!";

	if (-e "$datadir/postmaster.pid"){
		print "PostgresSQL is already started.";
		return 0;
	}

	my $cmd = "./bin/postgres -D $datadir -p $port $startup_params &";

	PrintMsg("Starting PostgreSQL with the following line:\n $cmd\n");
	if(!$dry_run){
		system("cp $config_file $datadir");
		system($cmd);
		sleep 10;
		copy ($config_file, "$RESULTS_OUTPUT_DIR/");
	}
}


sub StopPostgres{
	my $postgres_home	= $_[0];
	my $datadir		= $_[1];
	my $port		= $_[2];

	chdir($postgres_home) or die "Can't chdir to $postgres_home $!";
	if (-e "$datadir/postmaster.pid"){
		sleep 1;
		my $cmd = "./bin/pg_ctl -D $datadir -p $port stop";
		PrintMsg("Stopping PostgreSQL with the following line:\n $cmd");
		if(!$dry_run){
			print `$cmd`;
			sleep 1;
		}
	}
}





sub ExecuteWithTimeout{
	# TODO: Implement timeout algorithm for PostgreSQL. Currently it is not working
	my $dbms	= $_[0];
	my $dbh 	= $_[1];
	my $run_stmts	= $_[2];
	my $timeout 	= $_[3];

	my $timeout_exceeded 	= 0;
	my $startTime		= 0;
	my $elapsedTime		= 0;
	
	if($timeout && $dbms ne "postgres" && $dbms ne "PostgreSQL"){
		my $connection_id = $dbh->selectrow_array("SELECT CONNECTION_ID()");
		$dbh->do("DROP EVENT IF EXISTS timeout");
		$dbh->do("CREATE EVENT timeout ON SCHEDULE AT CURRENT_TIMESTAMP + INTERVAL $timeout SECOND DO KILL QUERY $connection_id");
	}
	eval{
		$startTime = time;
		foreach my $stmt (@$run_stmts){
			$dbh->do($stmt);
		}
		$elapsedTime = time - $startTime;
		1;
	} or do{
		$elapsedTime = -1;
		if($DBI::errstr eq "Query execution was interrupted"){
			$timeout_exceeded = 1;
		}else{
			print "\nDBI resulted with an error: $DBI::errstr";
		}
	};

	if($timeout && $dbms ne "postgres" && $dbms ne "PostgreSQL"){
		$dbh->do("DROP EVENT IF EXISTS timeout");
	}

	return $elapsedTime;
}


sub ExecuteInShell{
	my $dbms	= $_[0];
	my $stmt 	= $_[1];
	my $keyword	= $_[2];
	my $resultFile	= $_[3];
	my $stmtIsFile	= $_[4] || 0;

	my $startTime		= 0;
	my $elapsedTime		= 0;

	PrintMsg("\n***Executing in shell $stmt\n");
	if(!$dry_run){
		if($keyword && !(-e "$RESULTS_OUTPUT_DIR/$keyword")){
			mkpath("$RESULTS_OUTPUT_DIR/$keyword");
		}

		$startTime = time;
		if($stmtIsFile){
			if($dbms eq "postgre" || $dbms eq "PostgreSQL"){
				system ("./bin/psql -p $l_PORT -d $l_DBNAME -f $stmt >> $RESULTS_OUTPUT_DIR/$keyword/$resultFile");
			} else {
				system ("./bin/mysql -S $l_SOCKET -P $l_PORT -u $l_MYSQL_USER $l_DBNAME < $stmt >> $RESULTS_OUTPUT_DIR/$keyword/$resultFile");
			}
		}else{
			if(!(-e "$RESULTS_OUTPUT_DIR/$keyword/$resultFile")){
				open (MYFILE, ">>$RESULTS_OUTPUT_DIR/$keyword/$resultFile");
				print MYFILE "SQL_command:\n$stmt\n\n===Results===\n";
				close (MYFILE); 
			}
			if($dbms eq "postgre" || $dbms eq "PostgreSQL"){
				system ("./bin/psql -p $l_PORT -d $l_DBNAME -c \"$stmt\" >> $RESULTS_OUTPUT_DIR/$keyword/$resultFile");
			} else {
				system ("./bin/mysql -S $l_SOCKET -P $l_PORT -u $l_MYSQL_USER $l_DBNAME -e \"$stmt\" >> $RESULTS_OUTPUT_DIR/$keyword/$resultFile");
			}
		}
		$elapsedTime = time - $startTime;
	}

	return $elapsedTime;
	# TODO: Log the results into a database
}


sub ExecuteFileInShell{
	my $dbms	= $_[0];
	my $fileToExec 	= $_[1];
	my $keyword	= $_[2];
	my $resultFile	= $_[3];

	return ExecuteInShell($dbms, $fileToExec, $keyword, $resultFile, 1);
}



# NOTE: This algorithm is not ready and is replaced by GetBestCluster. However, leaving it for ideas referrences.
# sub FindClusters{
# 	my $queryResults 	= $_[0];
# 	my $clusterSize		= $_[1];
# 	
# 	if(scalar(@$queryResults) < $clusterSize){
# 		return 0;
# 	}
# 
# 
# 	my $sumTimeDiff	= 0;
# 	for (my $i = 1; $i < scalar(@$queryResults); $i++){
# 		$sumTimeDiff += @$queryResults[$i] - @$queryResults[$i-1];
# 	}
# 	my $avgTimeDiff = $sumTimeDiff / (scalar(@$queryResults) - 1);
# 	print "\nAverage time: $avgTimeDiff";
# 
# 	my $upperLimit = @$queryResults[0] + ($clusterSize) * $avgTimeDiff;
#  	print "\nupperLimit = $upperLimit";
# 	for (my $i = 0; $i <= scalar(@$queryResults) - $clusterSize; $i++){
# 		if(@$queryResults[$i + $clusterSize - 1] <= $upperLimit){
# 			my $sumClusterTime = 0;
# 			for (my $j = $i; $j < $clusterSize; $j++){
# 				$sumClusterTime += @$queryResults[$j];
# 			}
# 			return $sumClusterTime / $clusterSize;
# 		}
# 	}
# 
# 	return 0;
# }


sub GetBestCluster{
	my $queryResults 	= $_[0];
	my $clusterSize		= $_[1];
	my $getBestAvailable	= $_[2]; #Get the best available result no matter what the clusterSize should be. It gets the most scored result

	if(!$getBestAvailable && scalar(@$queryResults) < $clusterSize){
		#Not enough results to form a cluster.
		print "\nNot enough results to form a cluster.";
		return 0;
	}


	#get the average time difference between the results
	my $sumTimeDiff	= 0;
	for (my $i = 1; $i < scalar(@$queryResults); $i++){
		$sumTimeDiff += @$queryResults[$i] - @$queryResults[$i-1];
	}

	my $tmp = (scalar(@$queryResults) == 1 ? 1 : scalar(@$queryResults) - 1);
	my $avgTimeDiff = $sumTimeDiff / $tmp;
# 	print "\nsumTimeDiff = $sumTimeDiff\n get scalar=".scalar(@$queryResults)."\n the average time difference between the results: $avgTimeDiff";


	#scoring each group
	my @scores;
	for (my $i = 0; $i < scalar(@$queryResults) - 1; $i++){
		$scores[$i] = 1;
		for(my $j = $i + 1; $j < scalar(@$queryResults); $j++){
			if((@$queryResults[$j] != -1 && @$queryResults[$i] == -1) || @$queryResults[$j] - @$queryResults[$j - 1] > $avgTimeDiff*1.3){
				last;
			}
			$scores[$i] ++;
		}
	}
	$scores[scalar(@$queryResults)-1] = 1;
# 	print "\nscoring each group: @scores";


	#get the max score and the max-scored group start index
	my $bestStart 	= 0;
	my $maxScore 	= -100;
	for(my $i = 0; $i < scalar(@scores); $i++){
		if($maxScore < $scores[$i]){
			$maxScore 	= $scores[$i];
			$bestStart 	= $i;
		}
	}
# 	print "\nget the max score ($maxScore) and the max-scored group start index ($bestStart)";


	#get the average time for the max-scored group
	my $sumBestDiff = 0;
	for(my $i = $bestStart; $i <= $bestStart + $maxScore - 1; $i++){
		$sumBestDiff += @$queryResults[$i];
	}


	my $retVal = 0;
	if($getBestAvailable || $maxScore >= $clusterSize){
		$retVal = $sumBestDiff / $maxScore;
	}
# 	print "\nget the average time for the max-scored group: $retVal";
	return $retVal;
}


sub LogStartTestResult{
	my ($dbh, $test_id, $query_name, $results_output_dir, $pre_test_sql, $keyword, $storage_engine, $scale_factor, $version) = @_;

	$keyword =~ s/\'/\\\'/g;
	$dbh->do("insert into test_result (test_id, query_name, start_time, results_output_dir, pre_test_sql, keyword, storage_engine, scale_factor, version) values ('$test_id', '$query_name', now(), '$results_output_dir', '$pre_test_sql', '$keyword', '$storage_engine', $scale_factor, '$version')");
}


sub LogEndTestResult{
	my ($dbh, $test_id, $elapsed_time, $post_test_sql, $test_comments) = @_;
	$test_comments =~ s/\'/\\\'/g;
	$dbh->do("update test_result set end_time = now(), elapsed_time = $elapsed_time, post_test_sql = '$post_test_sql', comments = '$test_comments' where test_id = $test_id");
}


sub LogStartRunResult{
	my ($dbh, $test_id, $run_id, $is_warmup, $explain_result, $pre_run_sql, ) = @_;

	$dbh->do("insert into query_result (test_id, run_id, is_warmup, start_time, explain_result, pre_run_sql) values ('$test_id', '$run_id', $is_warmup, now(), '$explain_result', '$pre_run_sql')");
}


sub LogEndRunResult{
	my ($dbh, $test_id, $run_id, $is_warmup, $elapsed_time, $post_run_sql, $run_comments) = @_;

	$dbh->do("update query_result set end_time = now(), elapsed_time = $elapsed_time, post_run_sql = '$post_run_sql', comments = '$run_comments' where test_id = $test_id and run_id = $run_id and is_warmup = $is_warmup");
}


sub GetServerVersion{
	my ($dbms, $dbname, $port, $socket, $mysql_user) = @_;

	my $version = "";
	my $dbh_ver;

	if($dbms eq "postgre" || $dbms eq "PostgreSQL"){
# 		$dbh_ver = DBI->connect("DBI:Pg:$dbname;host=127.0.0.1:$port;", "$mysql_user", "", {PrintError => 0, RaiseError => 1}) || die "Could not connect to database: $DBI::errstr";
	} else {
		$dbh_ver = DBI->connect("DBI:mysql:$dbname;host=127.0.0.1:$port;mysql_socket=$socket", "$mysql_user", "", {PrintError => 0, RaiseError => 1}) || die "Could not connect to database: $DBI::errstr";
		my $sth = $dbh_ver->prepare("select version()");
		$sth->execute();
		if(my $ref = $sth->fetchrow_hashref()) {
			$version = $ref->{'version()'};
		}
		$sth->finish();
		$dbh_ver->disconnect();
	}
	

	return $version;
}


sub PlotGraph{
	my ($dbh, $graph_heading) = @_;

	my $plotFiles		= "";
	my $query_name		= "";
	my $elapsed_time 	= "";
	my $version		= "";
	my $keyword		= "";
	my $storage_engine	= "";

	open (RESDAT, ">$RESULTS_OUTPUT_DIR/results.dat");

	my $sth = $dbh->prepare("select query_name, elapsed_time, version, keyword, storage_engine from test_result where results_output_dir = '$RESULTS_OUTPUT_DIR'");
	$sth->execute();
	my $maxTime = 1;
	my $i = 0;
	while(my $ref = $sth->fetchrow_hashref()) {
		$query_name	= $ref->{'query_name'};
		$elapsed_time 	= $ref->{'elapsed_time'};
		
		if(	$version 	ne $ref->{'version'} || 
			$keyword 	ne $ref->{'keyword'} ||
			$storage_engine	ne $ref->{'storage_engine'}){
		
			$version	= $ref->{'version'};
			$keyword	= $ref->{'keyword'};
			$storage_engine	= $ref->{'storage_engine'};
			print RESDAT "\n\n#Version:$version; StorageEngine:$storage_engine; Keyword: $keyword\n";
			$plotFiles .= "'$RESULTS_OUTPUT_DIR/results.dat' index " . ($i++) . " using 2:xtic(1) ti \"$keyword\",";
		}

		
		if($elapsed_time > $maxTime){
			$maxTime = $elapsed_time;
		}

		#if query timed out
		if($elapsed_time == -1){
			$elapsed_time = 100000;
		}
		print RESDAT "$query_name\t$elapsed_time\n";
	}
	$sth->finish();

	close (RESDAT); 

	$plotFiles = substr($plotFiles, 0, -1);

	$graph_heading =~ s/\"/\\\"/g;
	$maxTime = int($maxTime * 1.2 + 0.5); #add 10% and round it up to nearest integer

	open (GNUFILE, ">$RESULTS_OUTPUT_DIR/gnuplot_script.txt");
	#print GNUFILE "set terminal jpeg nocrop enhanced font arial 8 size 640,480
	print GNUFILE "set terminal jpeg nocrop enhanced size 640,480
	set output '$RESULTS_OUTPUT_DIR/graphics.jpeg'
	set boxwidth 0.9 absolute
	set style fill   solid 0.5 border -1
	set style histogram clustered gap 1 title  offset character 0, 0, 0
	set datafile missing '-'
	set style data histograms
	set xtics border in scale 1,0.5 nomirror rotate by -45  offset character 0, 0, 0 
	set xlabel 'Query'
	set ylabel 'Seconds'
	set grid
	set key below right
	set title \"$graph_heading\" 
	set yrange [ 0. : $maxTime. ] noreverse nowriteback
	plot $plotFiles";

	system("gnuplot $RESULTS_OUTPUT_DIR/gnuplot_script.txt");

}



sub RunTests{
	my $test_file = $_[0];

# 	chdir($PROJECT_HOME)  or die "Can't chdir to $PROJECT_HOME $!";
	require ($test_file);

# 	CollectHardwareInfo($test_file);
	copy ($test_file, "$RESULTS_OUTPUT_DIR/");

	#Start the results DB server
	if(!StartMysql($RESULTS_MYSQL_HOME, $RESULTS_DATADIR, $RESULTS_CONFIG_FILE, $RESULTS_SOCKET, $RESULTS_PORT, $RESULTS_STARTUP_PARAMS)){
		die "Could not start results mysqld process";
	}
	my $dbh_res = DBI->connect("DBI:mysql:$RESULTS_DB_NAME;host=127.0.0.1:$RESULTS_PORT;mysql_socket=$RESULTS_SOCKET", "$RESULTS_MYSQL_USER", "", {PrintError => 0, RaiseError => 1}) || die "Could not connect to database: $DBI::errstr";	

	if($QUERIES_AT_ONCE){
		#The startup variables should be set as global if we don't refresh caches between runs
		$l_MYSQL_HOME		= $MYSQL_HOME;
		$l_MYSQL_USER		= $MYSQL_USER;
		$l_CONFIG_FILE		= $CONFIG_FILE;
		$l_SOCKET		= $SOCKET;
		$l_PORT			= $PORT;
		$l_DATADIR		= $DATADIR;
		$l_STARTUP_PARAMS	= $STARTUP_PARAMS;
		$l_DBNAME		= $DBNAME;

		if($l_GRAPH_HEADING && $GRAPH_HEADING){
			$l_GRAPH_HEADING .= " vs. ";
		}
		$l_GRAPH_HEADING 	.= $GRAPH_HEADING;

		if($USER_IS_ADMIN && $CLEAR_CACHES){
			#clear the caches prior the whole test
			system("echo 1 > /proc/sys/vm/drop_caches");
		}
		if($DBMS eq "postgre" || $DBMS eq "PostgreSQL"){
			if(!StartPostgres($l_MYSQL_HOME, $l_DATADIR, $l_CONFIG_FILE, $l_PORT, $l_STARTUP_PARAMS)){
				die "Could not start PostgreSQL process";
			}
		}else{
			if(!StartMysql($l_MYSQL_HOME, $l_DATADIR, $l_CONFIG_FILE, $l_SOCKET, $l_PORT, $l_STARTUP_PARAMS)){
				die "Could not start mysqld process";
			}
		}
		
		#Pre-test statements
		if($PRE_TEST_SQL){
			ExecuteInShell($DBMS, "$PRE_TEST_SQL", $KEYWORD, "pre_test_sql_results.txt");
		}

		if($PRE_TEST_OS){
			system("$PRE_TEST_OS >$RESULTS_OUTPUT_DIR/$KEYWORD/pre_test_os_results.txt");
		}
	}


	for (my $i=0; $i < scalar(@configurations); $i++){
		$l_QUERIES_HOME		= $configurations[$i]{QUERIES_HOME}	// $QUERIES_HOME;
		$l_MYSQL_HOME		= $configurations[$i]{MYSQL_HOME}	// $MYSQL_HOME;
		$l_MYSQL_USER		= $configurations[$i]{MYSQL_USER}	// $MYSQL_USER;
		$l_CONFIG_FILE		= $configurations[$i]{CONFIG_FILE}	// $CONFIG_FILE;
		$l_SOCKET		= $configurations[$i]{SOCKET}		// $SOCKET;
		$l_PORT			= $configurations[$i]{PORT}		// $PORT;
		$l_DATADIR		= $configurations[$i]{DATADIR}		// $DATADIR;
		$l_DBNAME		= $configurations[$i]{DBNAME}		// $DBNAME;
		$l_STARTUP_PARAMS	= $configurations[$i]{STARTUP_PARAMS}	// $STARTUP_PARAMS;
		$l_QUERY		= $configurations[$i]{QUERY}		// $QUERY;
		$l_EXPLAIN_QUERY	= $configurations[$i]{EXPLAIN_QUERY}	// $EXPLAIN_QUERY;
		$l_EXPLAIN		= $configurations[$i]{EXPLAIN}		// $EXPLAIN;
		$l_TIMEOUT		= $configurations[$i]{TIMEOUT}		// $TIMEOUT;
		$l_NUM_TESTS		= $configurations[$i]{NUM_TESTS}	// $NUM_TESTS;
		$l_WARMUP		= $configurations[$i]{WARMUP}		// $WARMUP;
		$l_WARMUPS_COUNT	= $configurations[$i]{WARMUPS_COUNT}	// $WARMUPS_COUNT;
		$l_MAX_QUERY_TIME	= $configurations[$i]{MAX_QUERY_TIME}	// $MAX_QUERY_TIME;
		$l_PRE_RUN_SQL		= $configurations[$i]{PRE_RUN_SQL}	// $PRE_RUN_SQL;
		$l_POST_RUN_SQL		= $configurations[$i]{POST_RUN_SQL}	// $POST_RUN_SQL;
		$l_PRE_RUN_OS		= $configurations[$i]{PRE_RUN_OS}	// $PRE_RUN_OS;
		$l_POST_RUN_OS		= $configurations[$i]{POST_RUN_OS}	// $POST_RUN_OS;
		$l_CLUSTER_SIZE		= $configurations[$i]{CLUSTER_SIZE}	// $CLUSTER_SIZE;
		

		if(!CheckConfigParams()){
			exit;
		}

		#Read the passed file
		my @run_stmts;
		if($RUN){
			$/ = ';';
			open FH, "< $l_QUERIES_HOME/$l_QUERY";
			while (<FH>) {
				my $tmp = $_;
				$tmp =~ s/^\s+//;
				$tmp =~ s/\s+$//;
				if(length($tmp) > 0){
					push(@run_stmts, $tmp);
				}
			}
			close FH;
		}


		my $warmed_up		= 0;
		my $mainClusterAvg 	= 0;
		my $queryStartTime	= time;
		my @queryResults;
		my $j 			= 0;
		
		my $test_id = time; #This will be the ID of the test into the results DB
		my $test_comments = ""; #If any comments arise during the test they will be stored into the database

		

		while (!$mainClusterAvg){
			$j ++;
			my $noMoreTests = 0;

			
			if(!$QUERIES_AT_ONCE){
				#start mysql
				if($USER_IS_ADMIN && $CLEAR_CACHES){
					#clear the caches prior the whole test
					system("echo 1 > /proc/sys/vm/drop_caches");
				}

				if($DBMS eq "postgre" || $DBMS eq "PostgreSQL"){
					if(!StartPostgres($l_MYSQL_HOME, $l_DATADIR, $l_CONFIG_FILE, $l_PORT, $l_STARTUP_PARAMS)){
						die "Could not start mysqld process";
					}
				}else{
					if(!StartMysql($l_MYSQL_HOME, $l_DATADIR, $l_CONFIG_FILE, $l_SOCKET, $l_PORT, $l_STARTUP_PARAMS)){
						die "Could not start mysqld process";
					}
				}


				$warmed_up = 0;

				#if that's the first run, perform the pre-test statements
				if($i == 0 && $j == 1){
					if($PRE_TEST_SQL){
						ExecuteInShell($DBMS, "$PRE_TEST_SQL", $KEYWORD, "pre_test_sql_results.txt");
					}

					if($PRE_TEST_OS){
						system("$PRE_TEST_OS >$RESULTS_OUTPUT_DIR/$KEYWORD/pre_test_os_results.txt");
					}
				}

		
			}


			if($j == 1){
				my $version = GetServerVersion($DBMS, $l_DBNAME, $l_PORT, $l_SOCKET, $l_MYSQL_USER);
				LogStartTestResult($dbh_res, $test_id, $l_QUERY, $RESULTS_OUTPUT_DIR, "$KEYWORD/pre_test_sql_results.txt", $KEYWORD, $STORAGE_ENGINE, $SCALE_FACTOR, $version);
			}



			#Run
			if($RUN){
				if(!$dry_run){
					my $elapsedTime = 0;
					my $dbh;

					if($DBMS eq "postgre" || $DBMS eq "PostgreSQL"){
						#$dbh = DBI->connect("DBI:Pg:$l_DBNAME;host=127.0.0.1:$l_PORT;", "$l_MYSQL_USER", "", {PrintError => 0, RaiseError => 1}) || die "Could not connect to database: $DBI::errstr";
					} else {
						$dbh = DBI->connect("DBI:mysql:$l_DBNAME;host=127.0.0.1:$l_PORT;mysql_socket=$l_SOCKET", "$l_MYSQL_USER", "", {PrintError => 0, RaiseError => 1}) || die "Could not connect to database: $DBI::errstr";
						$dbh->{'mysql_auto_reconnect'} = 1;

						if($l_TIMEOUT > 0){
							$dbh->do("SET GLOBAL EVENT_SCHEDULER = ON");
						}
					}

					#Pre-run statements
					my $preRunSQLFilename = "pre_run_sql_q_" . $l_QUERY. "_no_$j" . "_results.txt";
					if($l_PRE_RUN_SQL){
						ExecuteInShell($DBMS, $l_PRE_RUN_SQL, $KEYWORD, $preRunSQLFilename);
					}

					my $preRunOSFilename = "pre_run_os_q_" . $l_QUERY. "_no_$j" . "_results.txt";
					if($l_PRE_RUN_OS){
						system("$l_PRE_RUN_OS > $RESULTS_OUTPUT_DIR/$KEYWORD/$preRunOSFilename");
					}




					
					############ WARMUP #############
					if($l_WARMUP && !$warmed_up){
						for (my $w = 0; $w < $l_WARMUPS_COUNT; $w ++){
							PrintMsg("\n-------- WARMUP run #".($w+1)." for $l_QUERY -------\n@run_stmts\n--------------------------------\n");
							LogStartRunResult($dbh_res, $test_id, $w, 1, "", "");

							if($DBMS eq "postgre" || $DBMS eq "PostgreSQL"){
								$elapsedTime = ExecuteFileInShell($DBMS, "$l_QUERIES_HOME/$l_QUERY", $KEYWORD, $l_QUERY."_warmup_output.txt");
							} else {
								$elapsedTime = ExecuteWithTimeout($DBMS, $dbh, \@run_stmts, $l_TIMEOUT);
							}
							print "Warmup! Time: $elapsedTime";

							my $warmup_comments = "";
							if($elapsedTime == -1){
								$warmup_comments = "Timeout exceeded";
							}
							LogEndRunResult($dbh_res, $test_id, $w, 1, $elapsedTime, "", $warmup_comments);
						}
						$warmed_up = 1;
					}
					#####################################

					
					my $explainFilename = "";
					if($l_EXPLAIN){
						$explainFilename = "$l_EXPLAIN_QUERY" . "_$j" . "_results.txt";
					}
					LogStartRunResult($dbh_res, $test_id, $j, 0, $explainFilename, $preRunSQLFilename);

					

########				############ ACTUAL RUN #############
					PrintMsg("\n-------- Test run #$j for $l_QUERY -------\n@run_stmts\n--------------------------------\n");
					
					my $pid = fork();
					if (not defined $pid) {
						die "Could not fork. Resources not avilable.\n";
					} elsif ($pid == 0) {
						#CHILD
						CollectStatistics_OS($OS_STATS_INTERVAL, 1, 1, 1, $KEYWORD, $l_QUERY, $j);
					} else {
						#PARENT";
						if($DBMS eq "postgre" || $DBMS eq "PostgreSQL"){
							$elapsedTime = ExecuteFileInShell($DBMS, "$l_QUERIES_HOME/$l_QUERY", $KEYWORD, $l_QUERY."_output.txt");
						} else {
							$elapsedTime = ExecuteWithTimeout($DBMS, $dbh, \@run_stmts, $l_TIMEOUT);
							$dbh->disconnect();
						}
						
						kill("KILL", $pid);
					}
########				#####################################


					print "Time elapsed: $elapsedTime";
					push(@queryResults, $elapsedTime);
					@queryResults = sort(@queryResults);


					#Explain
					if($l_EXPLAIN){
						ExecuteFileInShell($DBMS, "$l_QUERIES_HOME/$l_EXPLAIN_QUERY", $KEYWORD, $explainFilename);
					}




					#Post-run statements
					my $postRunSQLFilename = "post_run_sql_q_" . $l_QUERY. "_no_$j" . "_results.txt";
					if($l_POST_RUN_SQL){
						ExecuteInShell($DBMS, "$l_POST_RUN_SQL", $KEYWORD, $postRunSQLFilename);
					}


					my $postRunOSFilename = "post_run_os_q_" . $l_QUERY. "_no_$j" . "_results.txt";
					if($l_POST_RUN_OS){
						system("$l_POST_RUN_OS > $RESULTS_OUTPUT_DIR/$KEYWORD/$postRunOSFilename");
					}


					my $run_comments = "";
					if($elapsedTime == -1){
						$run_comments = "Timeout exceeded";
					}

					LogEndRunResult($dbh_res, $test_id, $j, 0, $elapsedTime, $postRunSQLFilename, $run_comments);



					if(	($l_NUM_TESTS != 0 && $j >= $l_NUM_TESTS) ||
						($l_MAX_QUERY_TIME != 0 && $l_MAX_QUERY_TIME < $l_TIMEOUT + (time - $queryStartTime))){
						#There is no time for new test. Get the best cluster and show a warning
						$mainClusterAvg = GetBestCluster(\@queryResults, $l_CLUSTER_SIZE, 1);

						if ($l_NUM_TESTS != 0 && $j >= $l_NUM_TESTS){
							PrintMsg("\n\n Test limit of $l_NUM_TESTS reached. Getting the best result available: $mainClusterAvg\n\n");
						}else{
							PrintMsg("\n\n No time for next run. Getting the best result available: $mainClusterAvg\n\n");
							$test_comments .= "No time for next run. Getting the best result available.\n";
						}
						
						$noMoreTests = 1;
					}else{
						#Hide the results if there are more tests to be run. We will stop if we complete NUM_TESTS or exceed time limit
						if($l_NUM_TESTS != 0){
							$mainClusterAvg = 0;
						}else{
							#There is enough time to perform another test
							$mainClusterAvg = GetBestCluster(\@queryResults, $l_CLUSTER_SIZE, 0);
						}
					}

				}
			}

			
			#stop mysql
			if(!$QUERIES_AT_ONCE){
				#if that's the last test and last run, perform the post-test before stopping mysqld
				if($noMoreTests && $i+1 == scalar(@configurations)){
					if($POST_TEST_SQL){
						ExecuteInShell($DBMS, "$POST_TEST_SQL", $KEYWORD, "post_test_sql_results.txt");
					}

					if($POST_TEST_OS){
						system("$POST_TEST_OS > $RESULTS_OUTPUT_DIR/$KEYWORD/post_test_os_results.txt");
					}
				}

				if($DBMS eq "postgre" || $DBMS eq "PostgreSQL"){
					if(!StopPostgres($l_MYSQL_HOME, $l_DATADIR, $l_PORT)){
						die "Could not stop postgres process";
					}
				}else{
					if(!StopMysql($l_MYSQL_HOME, $l_SOCKET, $l_PORT, $l_MYSQL_USER)){
						die "Could not stop mysqld process";
					}
				}
			}


			if($noMoreTests){
				last;
			}
		}#while

		print "\nRESULT FOR QUERY: $mainClusterAvg";
		LogEndTestResult($dbh_res, $test_id, $mainClusterAvg, "$KEYWORD/post_test_sql_results.txt", $test_comments);
		
		
		#Plot the graph
		PlotGraph($dbh_res, $l_GRAPH_HEADING);

		sleep 1; #wait at least a second here to avoid two tests in one second that coauses PRIMARY KEY violation.
		
	}#for


	if($QUERIES_AT_ONCE){
		#Post-test statements
		if($POST_TEST_SQL){
			ExecuteInShell($DBMS, "$POST_TEST_SQL", $KEYWORD, "post_test_sql_results.txt");
		}

		if($POST_TEST_OS){
			system("$POST_TEST_OS > $RESULTS_OUTPUT_DIR/$KEYWORD/post_test_os_results.txt");
		}

		if($DBMS eq "postgre" || $DBMS eq "PostgreSQL"){
			if(!StopPostgres($l_MYSQL_HOME, $l_DATADIR, $l_PORT)){
				die "Could not start postgres process";
			}
		}else{
			if(!StopMysql($l_MYSQL_HOME, $l_SOCKET, $l_PORT, $l_MYSQL_USER)){
				die "Could not stop mysqld process";
			}
		}
	}

	#Stop results DB server
	$dbh_res->disconnect();
	if(!StopMysql($RESULTS_MYSQL_HOME, $RESULTS_SOCKET, $RESULTS_PORT, $RESULTS_MYSQL_USER)){
		die "Could not stop Results' mysqld process";
	}
}



sub PrintMsg{
	#TODO: hide the printed messages if a setting is set
	my $msg = $_[0];
	print "\n*** " .GetTimestamp() ." *** DBT3 test: $msg";
}

######################################## Main program ########################################
if(!CheckInputParams()){
	exit;
}else{
	CollectHardwareInfo();

	foreach my $file (@test_files){
		$file = File::Spec->rel2abs($file);
	}

	foreach my $file (@test_files){
		RunTests($file);
	}
}

exit;