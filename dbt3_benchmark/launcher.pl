#!/usr/bin/env perl
use warnings;
use strict;

# import module
use Getopt::Long;
use File::Path;
use File::Copy;
use Config::Auto;
use Data::Dumper;
use DBI;
use IPC::Open3;


#input parameter variables
my $TEST_FILE		= "";
my $RESULTS_OUTPUT_DIR	= "";
my $dry_run		= 0;
my $PROJECT_HOME	= "";
my $DATADIR_HOME	= "";
my $QUERIES_HOME	= "";
my $SCALE_FACTOR	= 0;

my $GRAPH_HEADING	= "";

my $startedServers 	= {}; #a hash with all the started MySQL and PostgreSQL servers

######################################## Function declarations ########################################
sub GetTimestampAsFilename{
	my($sec, $min, $hour, $day, $month, $year) = (localtime)[0,1,2,3,4,5];
	return sprintf("%02d-%02d-%02d\_%02d%02d%02d", $year + 1900, $month + 1, $day, $hour, $min, $sec);
}

sub GetTimestamp{
	my($sec, $min, $hour, $day, $month, $year) = (localtime)[0,1,2,3,4,5];
	return sprintf("%02d-%02d-%02d %02d:%02d:%02d", $year + 1900, $month + 1, $day, $hour, $min, $sec);
}


sub CheckInputParams{
	my $retVal 	= 1;
	my $errors 	= "";
	my $warnings 	= "";

	#Warnings
	if($dry_run){
		$warnings .= "### WARNING: Starting program in DRY-RUN mode\n";
	}

	if(!$TEST_FILE){
		$errors = "### ERROR: Missing input parameter 'test'.\n";
	}else{

		if(!(-e $TEST_FILE)){
			$errors .= "### ERROR: Configuration file $TEST_FILE does not exist \n";
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
	my ($configHash) = @_;

	my $retVal 	= 1;
	my $errors 	= "";
	my $warnings 	= "";
	
	#Errors
	if(!$configHash->{'test_config'}->{'MIN_MAX_OUT_OF_N'} && !$configHash->{'test_config'}->{'ANALYZE_EXPLAIN'} && !$configHash->{'test_config'}->{'SIMPLE_AVERAGE'}){
		$errors .= "### ERROR: At least one of the following should be set to true in the test configuration: MIN_MAX_OUT_OF_N, ANALYZE_EXPLAIN or SIMPLE_AVERAGE \n";
	}elsif($configHash->{'test_config'}->{'MIN_MAX_OUT_OF_N'} + $configHash->{'test_config'}->{'ANALYZE_EXPLAIN'} + $configHash->{'test_config'}->{'SIMPLE_AVERAGE'} > 1){
		$errors .= "### ERROR: Only one of the three options should be set: MIN_MAX_OUT_OF_N or ANALYZE_EXPLAIN or SIMPLE_AVERAGE\n";
	}elsif($configHash->{'test_config'}->{'MIN_MAX_OUT_OF_N'} && !$configHash->{'test_config'}->{'NUM_TESTS'}){
		$errors .= "### ERROR: When MIN_MAX_OUT_OF_N is set to true, then NUM_TESTS should be greater than 0 \n";
	}elsif($configHash->{'test_config'}->{'SIMPLE_AVERAGE'} && !$configHash->{'test_config'}->{'NUM_TESTS'}){
		$errors .= "### ERROR: When SIMPLE_AVERAGE is set to true, then NUM_TESTS should be greater than 0 \n";
	}

	if(!$configHash->{'queries'}->{'queries_settings'}->{'QUERIES_HOME'}){
		$errors .= "### ERROR: Config parameter 'QUERIES_HOME' is missing. \n";
	}

	if(!$configHash->{'db_config'}->{'DBMS_HOME'}){
		$errors .= "### ERROR: Config parameter 'DBMS_HOME' is missing. \n";
	}else{
		if(! -e $configHash->{'db_config'}->{'DBMS_HOME'}){
			$errors .= "### ERROR: Directory '".$configHash->{'db_config'}->{'DBMS_HOME'}."' for parameter DBMS_HOME does not exist \n";
		}
	}

	if(!$configHash->{'db_config'}->{'DBMS_USER'}){
		$errors .= "### ERROR: Config parameter 'DBMS_USER' is missing. \n";
	}

	if(!$configHash->{'db_config'}->{'CONFIG_FILE'}){
		$errors .= "### ERROR: Config parameter 'CONFIG_FILE' is missing. \n";
	}

	if(!$configHash->{'db_config'}->{'SOCKET'}){
		$errors .= "### ERROR: Config parameter 'SOCKET' is missing. \n";
	}

	if(!$configHash->{'db_config'}->{'PORT'}){
		$errors .= "### ERROR: Config parameter 'PORT' is missing. \n";
	}

	if(!$configHash->{'db_config'}->{'DATADIR'}){
		$errors .= "### ERROR: Config parameter 'DATADIR' is missing. \n";
	}else{
		if(! -e $configHash->{'db_config'}->{'DATADIR'}){
			$errors .= "### ERROR: Directory '".$configHash->{'db_config'}->{'DATADIR'}."' for parameter DATADIR does not exist \n";
		}
	}

	if(!$configHash->{'db_config'}->{'TMPDIR'}){
		$errors .= "### ERROR: Config parameter 'TMPDIR' is missing. \n";
	}else{
		if(! -e $configHash->{'db_config'}->{'TMPDIR'}){
			$errors .= "### ERROR: Directory '".$configHash->{'db_config'}->{'TMPDIR'}."' for parameter TMPDIR does not exist \n";
		}
	}

	if(!$configHash->{'db_config'}->{'DBNAME'}){
		$errors .= "### ERROR: Config parameter 'DBNAME' is missing. \n";
	}
	
	if(!$configHash->{'db_config'}->{'DBMS'}){
		$errors .= "### ERROR: Config parameter 'DBMS' is missing. \n";
	}else{
		if($configHash->{'db_config'}->{'DBMS'} ne "MariaDB" && $configHash->{'db_config'}->{'DBMS'} ne "MySQL" && $configHash->{'db_config'}->{'DBMS'} ne "PostgreSQL"){
			$errors .= "### ERROR: Unknown value for parameter DBMS: ".$configHash->{'db_config'}->{'DBMS'}.". Possible values are: 'MariaDB', 'MySQL' and 'PostgreSQL' \n";
		}
	}

	if(!$configHash->{'db_config'}->{'KEYWORD'}){
		$errors .= "### ERROR: Config parameter 'KEYWORD' is missing. \n";
	}


	if($configHash->{'db_config'}->{'MYSQL_SYSTEM_DIR'} && !-e $configHash->{'db_config'}->{'MYSQL_SYSTEM_DIR'}){
		$errors .= "### ERROR: MySQL sysetem directory set by the parameter MYSQL_SYSTEM_DIR = '".$configHash->{'db_config'}->{'MYSQL_SYSTEM_DIR'}."' does not exist \n";
	}


	#Results DB params:
	if(!$configHash->{'results_db'}->{'DBMS_HOME'}){
		$errors .= "### ERROR: Config parameter 'DBMS_HOME' for the results DB is missing. \n";
	}else{
		if(! -e $configHash->{'results_db'}->{'DBMS_HOME'}){
			$errors .= "### ERROR: Directory '".$configHash->{'results_db'}->{'DBMS_HOME'}."' for parameter DBMS_HOME for the results DB does not exist \n";
		}
	}

	if(!$configHash->{'results_db'}->{'DBMS_USER'}){
		$errors .= "### ERROR: Config parameter 'DBMS_USER' for the results DB is missing. \n";
	}

	if(!$configHash->{'results_db'}->{'DATADIR'}){
		$errors .= "### ERROR: Config parameter 'DATADIR' for the results DB is missing. \n";
	}else{
		if(! -e $configHash->{'results_db'}->{'DATADIR'}){
			$errors .= "### ERROR: Directory '".$configHash->{'results_db'}->{'DATADIR'}."' for parameter DATADIR for the results DB does not exist \n";
		}
	}

	if(!$configHash->{'results_db'}->{'CONFIG_FILE'}){
		$errors .= "### ERROR: Config parameter 'CONFIG_FILE' for the results DB is missing. \n";
	}

	if(!$configHash->{'results_db'}->{'SOCKET'}){
		$errors .= "### ERROR: Config parameter 'SOCKET' for the results DB is missing. \n";
	}

	if(!$configHash->{'results_db'}->{'PORT'}){
		$errors .= "### ERROR: Config parameter 'PORT' for the results DB is missing. \n";
	}

	if(!$configHash->{'results_db'}->{'DBNAME'}){
		$errors .= "### ERROR: Config parameter 'DBNAME' for the results DB is missing. \n";
	}

	if(!$configHash->{'results_db'}->{'HOST'}){
		$errors .= "### ERROR: Config parameter 'HOST' for the results DB is missing. \n";
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


sub ReplaceWithParam{
	my ($paramName, $str, $replacStr, $replacement, $paramIsFolder) = @_;

	if($str =~ m/$replacStr/){
		if(!$replacement){
			SafelyDie("Input parameter '$paramName' is missing", __LINE__);
		}else{
			if($paramIsFolder && ! -e $replacement){
				SafelyDie("Queries home directory '$replacement' does not exist", __LINE__);
			}else{
				$str =~ s/$replacStr/$replacement/g;
			}
		}
	}
	return $str;
}


sub ParseConfigFile{
	my ($filename, $format) = @_;
	my $config = Config::Auto->new( source => $filename, format => $format);
	my $parsed = $config->parse; 
	
	foreach my $key (keys(%{$parsed})){
		if(ref($parsed->{$key}) eq "HASH"){
			foreach my $key1 (keys (%{$parsed->{$key}})){
				$parsed->{$key}->{$key1} = ReplaceWithParam('project-home', $parsed->{$key}->{$key1}, "\\\$PROJECT_HOME", $PROJECT_HOME, 1);
				$parsed->{$key}->{$key1} = ReplaceWithParam('datadir-home', $parsed->{$key}->{$key1}, "\\\$DATADIR_HOME", $DATADIR_HOME, 1);
				$parsed->{$key}->{$key1} = ReplaceWithParam('queries-home', $parsed->{$key}->{$key1}, "\\\$QUERIES_HOME", $QUERIES_HOME, 1);
				$parsed->{$key}->{$key1} = ReplaceWithParam('scale-factor', $parsed->{$key}->{$key1}, "\\\$SCALE_FACTOR", $SCALE_FACTOR, 0);

			}
		}else{
			$parsed->{$key} = ReplaceWithParam('project-home', $parsed->{$key}, "\\\$PROJECT_HOME", $PROJECT_HOME, 1);
			$parsed->{$key} = ReplaceWithParam('datadir-home', $parsed->{$key}, "\\\$DATADIR_HOME", $DATADIR_HOME, 1);
			$parsed->{$key} = ReplaceWithParam('queries-home', $parsed->{$key}, "\\\$QUERIES_HOME", $QUERIES_HOME, 1);
			$parsed->{$key} = ReplaceWithParam('scale-factor', $parsed->{$key}, "\\\$SCALE_FACTOR", $SCALE_FACTOR, 0);
		}
	}
 
	return $parsed;
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
	my ($sleepTime, $cpuStats, $ioStats, $memoryStats, $keyword, $queryName, $queryRunNo) = @_;
	
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
				open (SAR_U, ">> $RESULTS_OUTPUT_DIR/$keyword/$queryName"."_no_$queryRunNo"."_sar_u.txt") or SafelyDie("Error while opening file: $!", __LINE__);
				print SAR_U $sar_u;
				close (SAR_U); 
			}
			
			if($ioStats){
				open (SAR_B, ">> $RESULTS_OUTPUT_DIR/$keyword/$queryName"."_no_$queryRunNo"."_sar_b.txt") or SafelyDie("Error while opening file: $!", __LINE__);
				print SAR_B $sar_b;
				close (SAR_B); 
			}

			if($memoryStats){
				open (SAR_R, ">> $RESULTS_OUTPUT_DIR/$keyword/$queryName"."_no_$queryRunNo"."_sar_r.txt") or SafelyDie("Error while opening file: $!", __LINE__);
				print SAR_R $sar_r;
				close (SAR_R); 
			}
		}else {
			if($cpuStats){
				my @arr1 = split(/\n/, $sar_u);
				open (SAR_U, ">> $RESULTS_OUTPUT_DIR/$keyword/$queryName"."_no_$queryRunNo"."_sar_u.txt") or SafelyDie("Error while opening file: $!", __LINE__);
				print SAR_U $arr1[3] . "\n";
				close (SAR_U); 
			}

			if($ioStats){
				my @arr2 = split(/\n/, $sar_b);
				open (SAR_B, ">> $RESULTS_OUTPUT_DIR/$keyword/$queryName"."_no_$queryRunNo"."_sar_b.txt") or SafelyDie("Error while opening file: $!", __LINE__);
				print SAR_B $arr2[3] . "\n";
				close (SAR_B);
			}

			if($memoryStats){
				my @arr3 = split(/\n/, $sar_r);
				open (SAR_R, ">> $RESULTS_OUTPUT_DIR/$keyword/$queryName"."_no_$queryRunNo"."_sar_r.txt") or SafelyDie("Error while opening file: $!", __LINE__);
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
	my ($mysqlHash, $stServers) = @_;

	my $mysql_home		= $mysqlHash->{'DBMS_HOME'};
	my $datadir		= $mysqlHash->{'DATADIR'};
	my $config_file 	= $mysqlHash->{'CONFIG_FILE'};
	my $socket		= $mysqlHash->{'SOCKET'};
	my $port		= $mysqlHash->{'PORT'};
	my $tmpdir		= $mysqlHash->{'TMPDIR'};
	my $startup_params	= $mysqlHash->{'STARTUP_PARAMS'};
	my $read_only		= $mysqlHash->{'READ_ONLY'};
	my $mysql_system_dir	= $mysqlHash->{'MYSQL_SYSTEM_DIR'};


	my $retVal = 1;

	my $started = -1;
	my $j=0;
	my $timeout=100;
	my $mysql_admin_options = "--socket=$socket";
	my $mysqld_options = "--defaults-file=$config_file --port=$port --socket=$socket";


	#make one datadir to work for both MariaDB and MySQL. The problem is the following query: SET GLOBAL EVENT_SCHEDULER = ON;
	#So each datadir that you want to make available for both MariaDB and MySQL should have the following folders:
	# - mysql_mysql - a directory that runs MySQL properly
	# - mylsq_mariadb - a directory that runs MariaDB properly
	#Then a symbolic link is created to the necessary folder based on the $mysqlHash->{'DBMS'} parameter
# 	if(-e "$datadir/mysql_mysql" && -e "$datadir/mysql_mariadb"){
# 		if(-e "$datadir/mysql"){
# 			unlink "$datadir/mysql" or SafelyDie("Could not unlink mysql folder: $!", __LINE__);
# 		}
# 		if($mysqlHash->{'DBMS'} eq "MySQL" && -e "$datadir/mysql_mysql"){
# 			symlink ("$datadir/mysql_mysql", "$datadir/mysql") or SafelyDie("Could not create link: $!", __LINE__);
# 		}elsif($mysqlHash->{'DBMS'} eq "MariaDB" && -e "$datadir/mysql_mariadb"){
# 			symlink ("$datadir/mysql_mariadb", "$datadir/mysql") or SafelyDie("Could not create link: $!", __LINE__);
# 		}
# 	}

	if($mysql_system_dir && -e "$mysql_system_dir"){
		if(-e "$datadir/mysql"){
			unlink "$datadir/mysql" or SafelyDie("Could not unlink mysql folder: $!", __LINE__);
		}
		symlink ("$mysql_system_dir", "$datadir/mysql") or SafelyDie("Could not create link: $!", __LINE__);
	}


	if($datadir){
		$mysqld_options .= " --datadir=$datadir";
	}

	if($tmpdir){
		$mysqld_options .= " --tmpdir=$tmpdir";
	}

	if($startup_params){
		$mysqld_options .= " $startup_params";
	}
	
	if($read_only){
		$mysqld_options .= " --read-only";
	}

	chdir($mysql_home) or SafelyDie("Can't chdir to $mysql_home $!", __LINE__);

	my $startMysql_stmt = "./bin/mysqld_safe $mysqld_options &";
	PrintMsg("Starting mysqld with the following line:\n$startMysql_stmt\n\n");
	if(!$dry_run){
		#check for previously started server
		system("./bin/mysqladmin $mysql_admin_options ping > /dev/null 2>&1");
		if ($? == 0){
			print "[ERROR]: There is a mysql server already started on socket '$socket'\n";
			return 0;
		}

		system($startMysql_stmt);
	
	 	while ($j <= $timeout){	
			system("./bin/mysqladmin $mysql_admin_options ping > /dev/null 2>&1");		
		    if ($? == 0){
		        $started=0;
			$stServers->{$socket."_".$port} = $mysqlHash;
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
	}

	return $retVal;
}


#Stop the mysqld process 
sub StopMysql{
	my ($mysqlHash, $stServers) = @_;
	my $mysql_home	= $mysqlHash->{'DBMS_HOME'};
	my $socket	= $mysqlHash->{'SOCKET'};
	my $port	= $mysqlHash->{'PORT'};
	my $mysql_user	= $mysqlHash->{'DBMS_USER'};


	chdir($mysql_home) or SafelyDie("Can't chdir to $mysql_home $!", __LINE__);
	my $stopMysql_stmt = "./bin/mysqladmin --socket=$socket --port=$port --user=$mysql_user shutdown 0";
	PrintMsg("Stopping mysql with the following line:\n$stopMysql_stmt\n\n");
	if(!$dry_run){
		print `$stopMysql_stmt`;
		
		# check for failure
		system("./bin/mysqladmin --socket=$socket --port=$port ping > /dev/null 2>&1");
		if ($? == 0){
			print "[ERROR]: MySQL/MariaDB server did not start properly on socket '$socket'\n";
			return 0;
		}

		delete($stServers->{$socket."_".$port});
	}
	return 1;
}



#PostgreSQL
sub StartPostgres{
	my ($postgreHash, $stServers) = @_;

	my $postgres_home	= $postgreHash->{'DBMS_HOME'};
	my $datadir		= $postgreHash->{'DATADIR'};
	my $config_file		= $postgreHash->{'CONFIG_FILE'};
	my $port		= $postgreHash->{'PORT'};
	my $startup_params	= $postgreHash->{'STARTUP_PARAMS'};


	chdir($postgres_home) or SafelyDie("Can't chdir to $postgres_home $!", __LINE__);

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
		copy ($config_file, "$RESULTS_OUTPUT_DIR/") or SafelyDie("Could not copy $config_file to directory '$RESULTS_OUTPUT_DIR'", __LINE__);
		$stServers->{"postgres_".$port} = $postgreHash;
	}
	return 1;
}


sub StopPostgres{
	my ($postgreHash, $stServers) = @_;

	my $postgres_home	= $postgreHash->{'DBMS_HOME'};
	my $datadir		= $postgreHash->{'DATADIR'};
	my $port		= $postgreHash->{'PORT'};

	chdir($postgres_home) or SafelyDie("Can't chdir to $postgres_home $!", __LINE__);
	if (-e "$datadir/postmaster.pid"){
		sleep 1;
		my $cmd = "./bin/pg_ctl -D $datadir -p $port stop";
		PrintMsg("Stopping PostgreSQL with the following line:\n $cmd");
		if(!$dry_run){
			print `$cmd`;
			sleep 1;
			
			#check for usuccessfully stopped server
			if (-e "$datadir/postmaster.pid"){
				print "PostgresSQL could not be stopped.";
				return 0;
			}

			delete($stServers->{"postgres_".$port});
		}
	}
	return 1;
}



sub SafelyDie{
	my ($errorMsg, $line) = @_;
	PrintMsg("\n[ERROR on line $line]: $errorMsg\n\n Exiting.\n");
	
	#kill the started mysql/postgres servers
	while (my ($key, $value) = each(%{$startedServers})){
		my $processes;
		if($value->{'DBMS'} eq "PostgreSQL"){
			$processes = `ps -ef |grep \`whoami\`| grep postgre | grep $value->{'PORT'} | cut -c10-15`;
		}else{
			$processes = `ps -ef |grep \`whoami\`| grep mysqld | grep $value->{'SOCKET'} | cut -c10-15`;
		}
		foreach my $procId (split(' ', $processes)){
			system("kill -9 $procId > /dev/null 2>&1");
		}
	}
	exit 0;
}



sub ExecuteWithTimeout{
	# TODO: Implement timeout algorithm for PostgreSQL. Currently it is working only with MariaDB and MySQL
	my ($dbms, $dbh, $run_stmts, $timeout) = @_;

	my $timeout_exceeded 	= 0;
	my $startTime		= 0;
	my $elapsedTime		= 0;
	
	if($timeout && $dbms ne "PostgreSQL"){
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
			SafelyDie("\nDBI resulted with an error: $DBI::errstr", __LINE__);
		}
	};

	if($timeout && $dbms ne "PostgreSQL"){
		$dbh->do("DROP EVENT IF EXISTS timeout");
	}

	return $elapsedTime;
}


sub ExecuteInShell{
	my ($dbms_hash, $stmt, $stmtFilename, $keyword, $resultFile) = @_;

	my $port 	= $dbms_hash->{'PORT'};
	my $socket	= $dbms_hash->{'SOCKET'};
	my $dbname	= $dbms_hash->{'DBNAME'};
	my $dbms_user	= $dbms_hash->{'DBMS_USER'};

	my $startTime		= 0;
	my $elapsedTime		= 0;

	if($stmt){
		PrintMsg("\n***Executing in shell \n$stmt\n");
	}elsif($stmtFilename){
		PrintMsg("\n***Executing in shell \n$stmtFilename\n");
	}

	if(!$dry_run){
		if($keyword && !(-e "$RESULTS_OUTPUT_DIR/$keyword")){
			mkpath("$RESULTS_OUTPUT_DIR/$keyword") or SafelyDie("Could not make path '$RESULTS_OUTPUT_DIR/$keyword'", __LINE__);
		}

		$startTime = time;
		if($stmtFilename){
			if($dbms_hash->{'DBMS'} eq "PostgreSQL"){
				system ("./bin/psql -p $port -d $dbname -f $stmtFilename > $RESULTS_OUTPUT_DIR/$keyword/$resultFile");
			} else {
				system ("./bin/mysql -S $socket -P $port -u $dbms_user $dbname -t < $stmtFilename > $RESULTS_OUTPUT_DIR/$keyword/$resultFile");
			}
		}else{
			if(!(-e "$RESULTS_OUTPUT_DIR/$keyword/$resultFile")){
				open (MYFILE, ">>$RESULTS_OUTPUT_DIR/$keyword/$resultFile") or SafelyDie("Error while opening file: $!", __LINE__);
				print MYFILE "SQL_command:\n$stmt\n\n===Results===\n";
				close (MYFILE); 
			}
			if($dbms_hash->{'DBMS'} eq "PostgreSQL"){
				system ("./bin/psql -p $port -d $dbname -c \"$stmt\" >> $RESULTS_OUTPUT_DIR/$keyword/$resultFile");
			} else {
				system ("./bin/mysql -S $socket -P $port -u $dbms_user $dbname -e \"$stmt\" -t >> $RESULTS_OUTPUT_DIR/$keyword/$resultFile");
			}
		}
		$elapsedTime = time - $startTime;
	}

	return $elapsedTime;
}




sub GetBestCluster{
	my ($queryResults, $clusterSize, $getBestAvailable) = @_;

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



sub GetBestExplainCluster{
	my ($explainResultsRef, $clusterSize, $getBestAvailable) = @_;

	my $retVal	= 0;
	my $min		= 10000000;
# 	my $minkey	= "";
	my $minCount	= 0;
	while (my ($key, $value) = each(%{$explainResultsRef})){
		#get the average
		my $avg		= 0;
		my $count	= 0;
		foreach my $tmp (@{ $value }){
			$count++;
			$avg += $tmp;
			if($tmp == -1){#timeout
				$avg = -1;
				last;
			}
		}
		if($count && $avg != -1){
			$avg = $avg / $count;
			if($min > $avg){
				$min		= $avg;
# 				$minkey		= $key;
				$minCount	= $count;
			}
		}
	}
	if($getBestAvailable || $minCount >= $clusterSize){
		if($min == 10000000){
			$retVal = -1;
		}else{
			$retVal = $min;
		}
	}
	return $retVal;
}


#Analyzes explain results and returns the explain string as a key for the %GlobalExplainResults hash.
# Parameters:
#	The first parameter is the file that contians the explain results
#	The second parameter is a reference to the %GlobalExplainResults hash with explain as a key and fastest query time as value
#If this explain (calculated execution plan) is new for the test, then the test should be run and the results recorded
#If this explain has already been run and it is not the best resulting execution plan, then return "" and no another run is necessary, so just restart the server and seek for the best execution plan
sub AnalyzeExplain{
	my ($file, $explainResultsRef) = @_;

	my $expl 	= "";
	my $retVal 	= "";

	#exclude the column 'rows'
	my $wholeFile = "";

	#first read the whole file since it doesn't handle newline breaks properly if read line by line
	open ( my $explain_fh, "<", $file) or SafelyDie("Error while opening file: $!", __LINE__);
	while (<$explain_fh>) {		
		$wholeFile .= $_;
	}
	close ($explain_fh);

	#then split it by newlines and then to tabs
	my @lines = split ("\n", $wholeFile);
	foreach my $line (@lines){
 		my ($id, $select_type, $table, $type, $possible_keys, $key, $key_len, $ref, $rows, $extra) =  split(/\t/, $line);
 		$expl .= "$id\t$select_type\t$table\t$type\t$possible_keys\t$key\t$key_len\t$ref\t###########\t$extra";
	}


	if(! exists $explainResultsRef->{$expl}){
		#run for the first time with such explain
		$explainResultsRef->{$expl} = [];
		$retVal = $expl;
	}else{
		#running the best execution plan so far
		my $min = 10000000;
		my $minkey = "";
		while (my ($key, $value) = each(%{$explainResultsRef})){
			#get the average
			my $avg		= 0;
			my $count	= 0;
			foreach my $tmp (@{ $value }){
				$count++;
				$avg += $tmp;
				if($tmp == -1){#timeout
					$avg = -1;
					last;
				}
			}
			if($count && $avg != -1){
				$avg = $avg / $count;
				if($min > $avg){
					$min = $avg;
					$minkey = $key;
				}
			}
		}
		if($expl eq $minkey){
			$retVal = $expl;
		}
	}
	PrintMsg("Analyzing explain returns\n$retVal");
	return $retVal; 
}


sub GetMinMax{
	my ($explainResultsRef) = @_;
	
	my $retVal = {'min' => 'null', 'max' => 'null', 'avg' => 'null'};
	my $min = 10000000;
	my $max = 0;
	while (my ($key, $value) = each(%{$explainResultsRef})){
		foreach my $tmp (@{ $value }){
			if($tmp == -1){
				if($min == 10000000){
					$min = $tmp;
				}
				if($max == 0){
					$max = $tmp;
				}
			}else{
				if($tmp < $min || $min == -1){
					$min = $tmp;
				}

				if($tmp > $max && $max != -1){
					$max = $tmp;
				}
			}
		}
	}

	$retVal->{'min'} = $min;
	$retVal->{'max'} = $max;
	return $retVal;
}


sub GetSimpleAverage{
	my ($explainResultsRef) = @_;

	my $retVal 	= -1;
	my $sum 	= 0;
	my $count 	= 0;
	while (my ($key, $value) = each(%{$explainResultsRef})){
		foreach my $tmp (@{ $value }){
			if($tmp == -1){
				$retVal = -1;
				last;
			}else{
				$sum += $tmp;
				$count ++;
			}
		}
	}	
	if($count > 0){
		$retVal = $sum / $count;
	}

	return $retVal;
}


sub LogStartTestResult{
	my ($dbh, $test_id, $query_name, $results_output_dir, $pre_test_sql, $keyword, $storage_engine, $scale_factor, $version) = @_;

	$keyword =~ s/\'/\\\'/g;
	$dbh->do("insert into test_result (test_id, query_name, start_time, results_output_dir, pre_test_sql, keyword, storage_engine, scale_factor, version) values ('$test_id', '$query_name', now(), '$results_output_dir', '$pre_test_sql', '$keyword', '$storage_engine', $scale_factor, '$version')");
}


sub LogEndTestResult{
	my ($dbh, $test_id, $min_elapsed_time, $max_elapsed_time, $avg_elapsed_time, $post_test_sql, $test_comments) = @_;
	$test_comments =~ s/\'/\\\'/g;
	$dbh->do("update test_result set end_time = now(), min_elapsed_time = $min_elapsed_time, max_elapsed_time = $max_elapsed_time, avg_elapsed_time = $avg_elapsed_time, post_test_sql = '$post_test_sql', comments = '$test_comments' where test_id = $test_id");
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
# 	my ($dbms, $dbname, $host, $port, $socket, $dbms_user) = @_;
	my ($dbms_hash) = @_;

	my $dbms 	= $dbms_hash->{'DBMS'};
	my $dbname	= $dbms_hash->{'DBNAME'};
	my $host	= $dbms_hash->{'HOST'};
	my $port	= $dbms_hash->{'PORT'};
	my $socket	= $dbms_hash->{'SOCKET'};
	my $dbms_user	= $dbms_hash->{'DBMS_USER'};

	my $version = "";
	my $dbh_ver;

	if($dbms eq "PostgreSQL"){
		# TODO
# 		$dbh_ver = DBI->connect("DBI:Pg:$dbname;host=$host:$port;", "$mysql_user", "", {PrintError => 0, RaiseError => 1}) || SafelyDie("Could not connect to database: $DBI::errstr", __LINE__);
	} else {
		$dbh_ver = DBI->connect("DBI:mysql:$dbname;host=$host:$port;mysql_socket=$socket", $dbms_user, "", {PrintError => 0, RaiseError => 1}) || SafelyDie("Could not connect to database: $DBI::errstr", __LINE__);
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


sub ClearTheCaches{
	system ("free -m");
	print "\nClearing the caches...\n";
# 	system ("sync ; echo 3 | sudo tee /proc/sys/vm/drop_caches");
	system ("sudo /sbin/sysctl vm.drop_caches=3");
	system ("free -m");
}


sub AppendFileToAnother{
	my ($source, $dest, $header, $footer) = @_;
	
	open(INPUT, $source) or SafelyDie("Could not open source file '$source': $!", __LINE__);
	open(OUTPUT, ">>$dest") or SafelyDie("Could not open destination file '$dest': $!", __LINE__);

	if($header){
		print OUTPUT "$header\n";
	}
	
	while(<INPUT>)
	{
		print OUTPUT $_;
	}

	if($footer){
		print OUTPUT "$footer\n";
	}
	close( INPUT );
	close( OUTPUT );
}

sub PlotGraph{
	my ($dbh, $graph_heading, $analyze_explain, $min_max_out_of_n, $simple_average) = @_;

	my $plotFiles		= "";
	my $query_name		= "";
	my $min_elapsed_time 	= "";
	my $max_elapsed_time 	= "";
	my $avg_elapsed_time 	= "";
	my $version		= "";
	my $keyword		= "";
	my $storage_engine	= "";

	open (RESDAT, ">$RESULTS_OUTPUT_DIR/results.dat") or SafelyDie("Error while opening file: $!", __LINE__);

	my $sth = $dbh->prepare("SELECT query_name, min_elapsed_time, max_elapsed_time, avg_elapsed_time, version, keyword, storage_engine FROM test_result WHERE results_output_dir = '$RESULTS_OUTPUT_DIR'");
	$sth->execute();
	my $maxTime = 1;
	my $i = 0;
	my $baseHash = {};


	while(my $ref = $sth->fetchrow_hashref()) {
		$query_name		= $ref->{'query_name'};
		$min_elapsed_time 	= $ref->{'min_elapsed_time'}	// "";
		$max_elapsed_time 	= $ref->{'max_elapsed_time'}	// "";
		$avg_elapsed_time 	= $ref->{'avg_elapsed_time'}	// "";
		
		if(	$version 	ne $ref->{'version'} || 
			$keyword 	ne $ref->{'keyword'} ||
			$storage_engine	ne $ref->{'storage_engine'}){
		
			$version	= $ref->{'version'};
			$keyword	= $ref->{'keyword'};
			$storage_engine	= $ref->{'storage_engine'};
			print RESDAT "\n\n#Version:$version; StorageEngine:$storage_engine; Keyword: $keyword\n";
			
			
			my $j = 2; #start from the second column
			if($min_max_out_of_n && $min_elapsed_time ne "" && $max_elapsed_time ne ""){
				$plotFiles .= "'$RESULTS_OUTPUT_DIR/results.dat' index $i using (\$3):(0):(\$2):xtic(1) ti \"$keyword\",";
			}elsif($analyze_explain && $min_elapsed_time ne ""){
 				$plotFiles .= "'$RESULTS_OUTPUT_DIR/results.dat' index $i using ".($j++).":xtic(1) ti \"$keyword min\",";
 			}elsif($simple_average && $avg_elapsed_time ne ""){
				$plotFiles .= "'$RESULTS_OUTPUT_DIR/results.dat' index $i using ".($j++).":xtic(1) ti \"$keyword avg\",";
			}
			$i++;
		}

		
		if($min_elapsed_time ne "" && $min_elapsed_time > $maxTime){
			$maxTime = $min_elapsed_time;
		}

		if($avg_elapsed_time ne "" && $avg_elapsed_time > $maxTime){
			$maxTime = $avg_elapsed_time;
		}

		if($max_elapsed_time ne "" && $max_elapsed_time > $maxTime){
			$maxTime = $max_elapsed_time;
		}

		#if query timed out
		if($min_elapsed_time ne "" && $min_elapsed_time == -1){
			$min_elapsed_time = 100000;
		}
		if($avg_elapsed_time ne "" && $avg_elapsed_time == -1){
			$avg_elapsed_time = 100000;
		}
		if($max_elapsed_time ne "" && $max_elapsed_time == -1){
			$max_elapsed_time = 100000;
		}

		my $str = "";
		if($min_elapsed_time ne ""){ $str .= $min_elapsed_time."\t";}
		if($max_elapsed_time ne ""){ $str .= $max_elapsed_time."\t";}
		if($avg_elapsed_time ne ""){ $str .= $avg_elapsed_time."\t";}


		if(!exists $baseHash->{$query_name."_min"} && $min_elapsed_time ne ""){
			$baseHash->{$query_name."_min"} = $min_elapsed_time || 1;
		}
		if(!exists $baseHash->{$query_name."_max"} && $max_elapsed_time ne ""){
			$baseHash->{$query_name."_max"} = $max_elapsed_time || 1;
		}
		if(!exists $baseHash->{$query_name."_avg"} && $avg_elapsed_time ne ""){
			$baseHash->{$query_name."_avg"} = $avg_elapsed_time || 1;
		}

		if(exists $baseHash->{$query_name."_min"} && $min_elapsed_time ne ""){
			if($baseHash->{$query_name."_min"} == 100000 || $min_elapsed_time == 100000){
				$str .= "\t";
			}else{
				$str .= sprintf("%.2f\t", ($min_elapsed_time / $baseHash->{$query_name."_min"}));
			}
		}
		if(exists $baseHash->{$query_name."_max"} && $max_elapsed_time ne ""){
			if($baseHash->{$query_name."_max"} == 100000 || $max_elapsed_time == 100000){
				$str .= "\t";
			}else{
				$str .= sprintf("%.2f\t", ($max_elapsed_time / $baseHash->{$query_name."_max"}));
			}
		}
		if(exists $baseHash->{$query_name."_avg"} && $avg_elapsed_time ne ""){
			if($baseHash->{$query_name."_avg"} == 100000 || $avg_elapsed_time == 100000){
				$str .= "\t";
			}else{
				$str .= sprintf("%.2f", ($avg_elapsed_time / $baseHash->{$query_name."_avg"}));
			}
		}

		print RESDAT "$query_name\t$str\n";
	}
	$sth->finish();

	close (RESDAT); 

	$plotFiles = substr($plotFiles, 0, -1);

	$graph_heading =~ s/\"/\\\"/g;
	$maxTime = int($maxTime * 1.2 + 0.5); #add 20% and round it up to nearest integer

	open (GNUFILE, ">$RESULTS_OUTPUT_DIR/gnuplot_script.txt") or SafelyDie("Error while opening file: $!", __LINE__);
	#print GNUFILE "set terminal jpeg nocrop enhanced font arial 8 size 640,480
	print GNUFILE "set terminal jpeg nocrop enhanced size 1280,1024
	set output '$RESULTS_OUTPUT_DIR/graphics.jpeg'
	set boxwidth 0.9 absolute
	set style fill solid 0.5 border -1\n";

	if($min_max_out_of_n){
		print GNUFILE "	set style histogram errorbars gap 1 lw 3 title offset character 0, 0, 0\n";
	}else{
		print GNUFILE "	set style histogram clustered gap 1 title offset character 0, 0, 0\n";
	}

	print GNUFILE "	set datafile missing '-'
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
# 	my $test_file = $_[0];
# 	require ($test_file);
# 	copy ($test_file, "$RESULTS_OUTPUT_DIR/") || SafelyDie("Could not copy configuration file '$test_file'!", __LINE__);

	my $configHash = $_[0];


	my $KEYWORD 		= $configHash->{'db_config'}->{'KEYWORD'};
	my $STORAGE_ENGINE	= $configHash->{'db_config'}->{'STORAGE_ENGINE'};
	my $PRE_TEST_SQL	= $configHash->{'db_config'}->{'PRE_TEST_SQL'}			// "";
	my $POST_TEST_SQL	= $configHash->{'db_config'}->{'POST_TEST_SQL'}			// "";
	my $PRE_TEST_OS		= $configHash->{'db_config'}->{'PRE_TEST_OS'}			// $configHash->{'test_config'}->{'PRE_TEST_OS'}		// "";
	my $POST_TEST_OS	= $configHash->{'db_config'}->{'POST_TEST_OS'}			// $configHash->{'test_config'}->{'POST_TEST_OS'}		// "";
	my $CLEAR_CACHES	= $configHash->{'command_line'}->{'CLEAR_CACHES'}		// $configHash->{'test_config'}->{'CLEAR_CACHES'}		// 0;
# 	my $CLEAR_CACHES_PROGRAM= $configHash->{'command_line'}->{'CLEAR_CACHES_PROGRAM'}	// $configHash->{'test_config'}->{'CLEAR_CACHES_PROGRAM'}	// "";
# 	my $SCALE_FACTOR	= $configHash->{'command_line'}->{'SCALE_FACTOR'}		// $configHash->{'test_config'}->{'SCALE_FACTOR'};
	my $QUERIES_AT_ONCE	= $configHash->{'command_line'}->{'QUERIES_AT_ONCE'}		// $configHash->{'test_config'}->{'QUERIES_AT_ONCE'}		// 0;
	
	if(ref($PRE_TEST_SQL) eq "ARRAY"){
		$PRE_TEST_SQL	= join(" ", @$PRE_TEST_SQL);
	}
	if(ref($POST_TEST_SQL) eq "ARRAY"){	
		$POST_TEST_SQL	= join(" ", @$POST_TEST_SQL);
	}
	if(ref($PRE_TEST_OS) eq "ARRAY"){	
		$PRE_TEST_OS	= join(" ", @$PRE_TEST_OS);
	}
	if(ref($POST_TEST_OS) eq "ARRAY"){	
		$POST_TEST_OS	= join(" ", @$POST_TEST_OS);
	}


	#Start the results DB server
	if(!StartMysql($configHash->{'results_db'}, $startedServers)){
		SafelyDie("Could not start results mysqld process", __LINE__);
	}
	my $dbh_res = DBI->connect("DBI:mysql:".$configHash->{'results_db'}->{'DBNAME'}.";host=".$configHash->{'results_db'}->{'HOST'}.":".$configHash->{'results_db'}->{'PORT'}.";mysql_socket=".$configHash->{'results_db'}->{'SOCKET'}, $configHash->{'results_db'}->{'DBMS_USER'}, "", {PrintError => 0, RaiseError => 1}) || SafelyDie("Could not connect to database: $DBI::errstr", __LINE__);	



	if($QUERIES_AT_ONCE){
		#The startup variables should be set as global if we don't refresh caches between runs
		
		if($CLEAR_CACHES){
			#clear the caches prior the whole test
			ClearTheCaches();
		}
		if($configHash->{'db_config'}->{'DBMS'} eq "PostgreSQL"){
			if(!StartPostgres($configHash->{'db_config'}, $startedServers)){
				SafelyDie("Could not start PostgreSQL process", __LINE__);
			}
		}else{
			if(!StartMysql($configHash->{'db_config'}, $startedServers)){
				SafelyDie("Could not start mysqld process", __LINE__);
			}
		}
		copy ($configHash->{'db_config'}->{'CONFIG_FILE'}, "$RESULTS_OUTPUT_DIR/$KEYWORD/") or SafelyDie("Could not copy file ".$configHash->{'db_config'}->{'CONFIG_FILE'}." to folder '$RESULTS_OUTPUT_DIR/$KEYWORD/'", __LINE__);
		
		#Pre-test statements
		if($PRE_TEST_SQL){
			ExecuteInShell($configHash->{'db_config'}, $PRE_TEST_SQL, "", $KEYWORD, "pre_test_sql_results.txt");
		}

		if($PRE_TEST_OS){
			system("$PRE_TEST_OS > $RESULTS_OUTPUT_DIR/$KEYWORD/pre_test_os_results.txt");
		}
	}


	if($GRAPH_HEADING && $configHash->{'db_config'}->{'GRAPH_HEADING'}){
		$GRAPH_HEADING .= "\\n vs. ";
	}
	$GRAPH_HEADING .= $configHash->{'db_config'}->{'GRAPH_HEADING'};


	PrintMsg("\n\n============ Working now for ".$configHash->{'db_config'}->{'GRAPH_HEADING'}." ============\n\n");


	my $i = 0;
	my $l_CONFIG_QUERY_HOME = "";
	foreach my $queryKey ( keys(%{ $configHash->{'queries'} }) ){
# 		print "\n\n===== key = $queryKey =====\n\n";
		if($queryKey eq "queries_settings"){
			#Get the main configuration parameters
			$l_CONFIG_QUERY_HOME = $configHash->{'queries'}->{$queryKey}->{'QUERIES_HOME'};
			next;
		}

		$i++;

		#DB settings
		my $DBMS_hash = {};
		$DBMS_hash->{'DBMS'}		= $configHash->{'db_config'}->{'DBMS'};
		$DBMS_hash->{'DBMS_HOME'}	= $configHash->{'db_config'}->{'DBMS_HOME'};
		$DBMS_hash->{'DBMS_USER'}	= $configHash->{'db_config'}->{'DBMS_USER'};
		$DBMS_hash->{'DATADIR'}		= $configHash->{'db_config'}->{'DATADIR'};
		$DBMS_hash->{'DBNAME'}		= $configHash->{'db_config'}->{'DBNAME'};
		$DBMS_hash->{'SOCKET'}		= $configHash->{'db_config'}->{'SOCKET'};
		$DBMS_hash->{'PORT'}		= $configHash->{'db_config'}->{'PORT'};
		$DBMS_hash->{'HOST'}		= $configHash->{'db_config'}->{'HOST'};
		$DBMS_hash->{'MYSQL_SYSTEM_DIR'}= $configHash->{'db_config'}->{'MYSQL_SYSTEM_DIR'};
		$DBMS_hash->{'READ_ONLY'}	= $configHash->{'db_config'}->{'READ_ONLY'};
		$DBMS_hash->{'CONFIG_FILE'}	= $configHash->{'queries'}->{'queries_settings'}->{'CONFIG_FILE'}	// $configHash->{'queries'}->{$queryKey}->{'CONFIG_FILE'}	// $configHash->{'db_config'}->{'CONFIG_FILE'};
		$DBMS_hash->{'TMPDIR'}		= $configHash->{'queries'}->{$queryKey}->{'TMPDIR'}			// $configHash->{'db_config'}->{'TMPDIR'}			// "";
		$DBMS_hash->{'STARTUP_PARAMS'}	= $configHash->{'queries'}->{$queryKey}->{'STARTUP_PARAMS'}		// $configHash->{'db_config'}->{'STARTUP_PARAMS'};
		my $l_PRE_RUN_SQL		= $configHash->{'queries'}->{$queryKey}->{'PRE_RUN_SQL'}		// $configHash->{'db_config'}->{'PRE_RUN_SQL'}			// "";
		my $l_POST_RUN_SQL		= $configHash->{'queries'}->{$queryKey}->{'POST_RUN_SQL'}		// $configHash->{'db_config'}->{'POST_RUN_SQL'}			// "";

		#query settings
		my $l_QUERIES_HOME	= $configHash->{'command_line'}->{'QUERIES_HOME'} 		// $l_CONFIG_QUERY_HOME	// $configHash->{'test_config'}->{'QUERIES_HOME'};
		my $l_QUERY		= $configHash->{'queries'}->{$queryKey}->{'QUERY'};
		my $l_EXPLAIN_QUERY	= $configHash->{'queries'}->{$queryKey}->{'EXPLAIN_QUERY'}	// "";
		
		#test settings
		my $l_RUN		= $configHash->{'command_line'}->{'RUN'}		// $configHash->{'queries'}->{$queryKey}->{'RUN'}		// $configHash->{'test_config'}->{'RUN'}		// 0;
		my $l_EXPLAIN		= $configHash->{'command_line'}->{'EXPLAIN'}		// $configHash->{'queries'}->{$queryKey}->{'EXPLAIN'}		// $configHash->{'test_config'}->{'EXPLAIN'}		// 0;
		my $l_TIMEOUT		= $configHash->{'command_line'}->{'TIMEOUT'}		// $configHash->{'queries'}->{$queryKey}->{'TIMEOUT'}		// $configHash->{'test_config'}->{'TIMEOUT'};
		my $l_NUM_TESTS		= $configHash->{'command_line'}->{'NUM_TESTS'}		// $configHash->{'queries'}->{$queryKey}->{'NUM_TESTS'}		// $configHash->{'test_config'}->{'NUM_TESTS'};
		my $l_MAX_SKIPPED_TESTS	= $configHash->{'command_line'}->{'MAX_SKIPPED_TESTS'}	// $configHash->{'queries'}->{$queryKey}->{'MAX_SKIPPED_TESTS'}	// $configHash->{'test_config'}->{'MAX_SKIPPED_TESTS'};
		my $l_WARMUP		= $configHash->{'command_line'}->{'WARMUP'}		// $configHash->{'queries'}->{$queryKey}->{'WARMUP'}		// $configHash->{'test_config'}->{'WARMUP'};
		my $l_WARMUPS_COUNT	= $configHash->{'command_line'}->{'WARMUPS_COUNT'}	// $configHash->{'queries'}->{$queryKey}->{'WARMUPS_COUNT'}	// $configHash->{'test_config'}->{'WARMUPS_COUNT'};
		my $l_MAX_QUERY_TIME	= $configHash->{'command_line'}->{'MAX_QUERY_TIME'}	// $configHash->{'queries'}->{$queryKey}->{'MAX_QUERY_TIME'}	// $configHash->{'test_config'}->{'MAX_QUERY_TIME'};
		my $l_CLUSTER_SIZE	= $configHash->{'command_line'}->{'CLUSTER_SIZE'}	// $configHash->{'queries'}->{$queryKey}->{'CLUSTER_SIZE'}	// $configHash->{'test_config'}->{'CLUSTER_SIZE'};
		my $l_PRE_RUN_OS	= $configHash->{'command_line'}->{'PRE_RUN_OS'}		// $configHash->{'queries'}->{$queryKey}->{'PRE_RUN_OS'}	// $configHash->{'test_config'}->{'PRE_RUN_OS'}		// "";
		my $l_POST_RUN_OS	= $configHash->{'command_line'}->{'POST_RUN_OS'}	// $configHash->{'queries'}->{$queryKey}->{'POST_RUN_OS'}	// $configHash->{'test_config'}->{'POST_RUN_OS'}	// "";
		my $l_OS_STATS_INTERVAL	= $configHash->{'command_line'}->{'OS_STATS_INTERVAL'}	// $configHash->{'queries'}->{$queryKey}->{'OS_STATS_INTERVAL'}	// $configHash->{'test_config'}->{'OS_STATS_INTERVAL'}	// 1;
	
		my $l_MIN_MAX_OUT_OF_N	= $configHash->{'command_line'}->{'MIN_MAX_OUT_OF_N'}	// $configHash->{'test_config'}->{'MIN_MAX_OUT_OF_N'}		// 0;
		my $l_ANALYZE_EXPLAIN	= $configHash->{'command_line'}->{'ANALYZE_EXPLAIN'}	// $configHash->{'test_config'}->{'ANALYZE_EXPLAIN'}		// 0;
		my $l_SIMPLE_AVERAGE	= $configHash->{'command_line'}->{'SIMPLE_AVERAGE'}	// $configHash->{'test_config'}->{'SIMPLE_AVERAGE'}		// 0;

# 		$l_QUERIES_HOME 	=~ s/\$SCALE_FACTOR/$SCALE_FACTOR/g;
# 		$DBMS_hash->{'DATADIR'}	=~ s/\$SCALE_FACTOR/$SCALE_FACTOR/g;

		if(ref($l_PRE_RUN_SQL) eq "ARRAY"){
			$l_PRE_RUN_SQL 	= join(" ", @$l_PRE_RUN_SQL);
		}
		if(ref($l_POST_RUN_SQL) eq "ARRAY"){
			$l_POST_RUN_SQL = join(" ", @$l_POST_RUN_SQL);
		}
		if(ref($l_PRE_RUN_OS) eq "ARRAY"){
			$l_PRE_RUN_OS 	= join(" ", @$l_PRE_RUN_OS);
		}
		if(ref($l_POST_RUN_OS) eq "ARRAY"){
			$l_POST_RUN_OS 	= join(" ", @$l_POST_RUN_OS);
		}


		if(!CheckConfigParams($configHash)){
			SafelyDie("Incorrect config parameters", __LINE__);
		}

		#Read the passed file
		my @run_stmts;
		if($l_RUN){
			$/ = ';';
			open (FH, "< $l_QUERIES_HOME/$l_QUERY") or SafelyDie("Error while opening file $l_QUERIES_HOME/$l_QUERY: $!", __LINE__);
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
		my $resultHash 	= {'min' => "null", 'max' => "null", 'avg' => "null"};
		my $queryStartTime	= time;
		my @queryResults;
		my $j 			= 0;
		my $skippedTestsCount	= 0;
		
		my $test_id 		= time; #This will be the ID of the test into the results DB
		my $test_comments 	= ""; #If any comments arise during the test they will be stored into the database
		my %GlobalExplainResults; # a hash with explain string as a key and the fastest running query for that explain as value
		my $noMoreTests 	= 0;

		while (!$noMoreTests){
			$j ++;

			$noMoreTests = 0;
			my $skipCurrentRun = 0;

			
			if(!$QUERIES_AT_ONCE){
				if($i == 1 && $j == 1 && $PRE_TEST_OS){
					print "\n\n============\n$PRE_TEST_OS\n==============\n\n";
					system("$PRE_TEST_OS > $RESULTS_OUTPUT_DIR/$KEYWORD/pre_test_os_results.txt");
				}

				#start mysql
				if($CLEAR_CACHES){
					#clear the caches prior the whole test
					ClearTheCaches();
				}

				if($DBMS_hash->{'DBMS'} eq "PostgreSQL"){
					if(!StartPostgres($DBMS_hash, $startedServers)){
						SafelyDie("Could not start mysqld process", __LINE__);
					}
				}else{
					if(!StartMysql($DBMS_hash, $startedServers)){
						SafelyDie("Could not start mysqld process", __LINE__);
					}
				}
				copy ($DBMS_hash->{'CONFIG_FILE'}, "$RESULTS_OUTPUT_DIR/$KEYWORD/") or SafelyDie("Could not copy config file '".$DBMS_hash->{'CONFIG_FILE'}."' to directory '$RESULTS_OUTPUT_DIR/$KEYWORD/'", __LINE__);

				$warmed_up = 0;

				#if that's the first run, perform the pre-test statements
				if($i == 1 && $j == 1){
					if($PRE_TEST_SQL){
						ExecuteInShell($DBMS_hash, $PRE_TEST_SQL, "", $KEYWORD, "pre_test_sql_results.txt");
					}
				}
			}


			if($j == 1){
				my $version = GetServerVersion($DBMS_hash);
				LogStartTestResult($dbh_res, $test_id, $l_QUERY, $RESULTS_OUTPUT_DIR, "$KEYWORD/pre_test_sql_results.txt", $KEYWORD, $STORAGE_ENGINE, $SCALE_FACTOR, $version);
			}



			
			if(!$dry_run){
				my $elapsedTime = 0;
				my $dbh;

				if($DBMS_hash->{'DBMS'} eq "PostgreSQL"){
					#$dbh = DBI->connect("DBI:Pg:$l_DBNAME;host=$l_HOST:$l_PORT;", "$l_MYSQL_USER", "", {PrintError => 0, RaiseError => 1}) || SafelyDie("Could not connect to database: $DBI::errstr", __LINE__);
				} else {
					$dbh = DBI->connect("DBI:mysql:".$DBMS_hash->{'DBNAME'}.";host=".$DBMS_hash->{'HOST'}.":".$DBMS_hash->{'PORT'}.";mysql_socket=".$DBMS_hash->{'SOCKET'}, $DBMS_hash->{'DBMS_USER'}, "", {PrintError => 0, RaiseError => 1}) || SafelyDie("Could not connect to database: $DBI::errstr", __LINE__);
					$dbh->{'mysql_auto_reconnect'} = 1;

					if($l_TIMEOUT > 0){
						$dbh->do("SET GLOBAL EVENT_SCHEDULER = ON");
					}
				}

				#Pre-run statements
				my $preRunSQLFilename = $l_QUERY. "_no_$j" . "_pre_run_sql.txt";
				if($l_PRE_RUN_SQL){						
					ExecuteInShell($DBMS_hash, $l_PRE_RUN_SQL, "", $KEYWORD, $preRunSQLFilename);
				}

				my $preRunOSFilename = $l_QUERY. "_no_$j" . "_pre_run_os.txt";
				if($l_PRE_RUN_OS){
					system("$l_PRE_RUN_OS > $RESULTS_OUTPUT_DIR/$KEYWORD/$preRunOSFilename");
				}


				############ EXPLAIN #############
				my $explainFilename 	= "";
				my $executionPlan	= "no_explain";
				if($l_EXPLAIN && $l_EXPLAIN_QUERY){
					$explainFilename = "$l_EXPLAIN_QUERY" . "_$j" . "_results.txt";
					ExecuteInShell($DBMS_hash, "", "$l_QUERIES_HOME/$l_EXPLAIN_QUERY", $KEYWORD, $explainFilename);

					if($l_ANALYZE_EXPLAIN){
						#Analyze the explain results and skip test if that's not the fastest execution plan
						if($DBMS_hash->{'DBMS'} ne "PostgreSQL"){
							# TODO: Make this algorithm for PostgreSQL if needed
							$executionPlan = AnalyzeExplain("$RESULTS_OUTPUT_DIR/$KEYWORD/$explainFilename", \%GlobalExplainResults);
							if($executionPlan eq "" && !$QUERIES_AT_ONCE){
								#skip this run
								$skipCurrentRun = 1;
								$skippedTestsCount ++;
								
								#adjust $j since there is no actual test performed
								$j--;

								if($skippedTestsCount >= $l_MAX_SKIPPED_TESTS){
									$resultHash->{'min'} = GetBestExplainCluster(\%GlobalExplainResults, $l_CLUSTER_SIZE, 1);
									$noMoreTests = 1;
								}
							}
						}
					}
				}
				#####################################


				if(!$skipCurrentRun){

					############ WARMUP #############
					if($l_WARMUP && !$warmed_up){
						for (my $w = 0; $w < $l_WARMUPS_COUNT; $w ++){
							PrintMsg("\n-------- WARMUP run #".($w+1)." for $l_QUERY -------\n@run_stmts\n--------------------------------\n");
							LogStartRunResult($dbh_res, $test_id, $w, 1, "", "");

							if($DBMS_hash->{'DBMS'} eq "PostgreSQL"){
								$elapsedTime = ExecuteInShell($DBMS_hash, "", "$l_QUERIES_HOME/$l_QUERY", $KEYWORD, $l_QUERY."_warmup_output.txt");
							} else {
								$elapsedTime = ExecuteWithTimeout($DBMS_hash->{'DBMS'}, $dbh, \@run_stmts, $l_TIMEOUT);
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

	
					LogStartRunResult($dbh_res, $test_id, $j, 0, $explainFilename, $preRunSQLFilename);


########				############ ACTUAL RUN #############

					if($l_RUN){
						PrintMsg("\n-------- Test run #$j for $l_QUERY -------\n@run_stmts\n--------------------------------\n");
						
						my $pid = fork();
						if (not defined $pid) {
							SafelyDie("Could not fork. Resources not avilable.\n", __LINE__);
						} elsif ($pid == 0) {
							#CHILD
							$dbh->{InactiveDestroy} = 1;
							$dbh_res->{InactiveDestroy} = 1;
							CollectStatistics_OS($l_OS_STATS_INTERVAL, 1, 1, 1, $KEYWORD, $l_QUERY, $j);
						} else {
							#PARENT";
							if($DBMS_hash->{'DBMS'} eq "PostgreSQL"){
								$elapsedTime = ExecuteInShell($DBMS_hash, "", "$l_QUERIES_HOME/$l_QUERY", $KEYWORD, $l_QUERY."_output.txt");
							} else {
								$elapsedTime = ExecuteWithTimeout($DBMS_hash->{'DBMS'}, $dbh, \@run_stmts, $l_TIMEOUT);
								$dbh->disconnect();
							}
							
							kill("KILL", $pid);
						}



						print "Time elapsed: $elapsedTime";

						if($l_EXPLAIN && $l_EXPLAIN_QUERY){
							AppendFileToAnother("$l_QUERIES_HOME/$l_EXPLAIN_QUERY", "$RESULTS_OUTPUT_DIR/$KEYWORD/all_explains.txt", "\n\n\n===== $l_EXPLAIN_QUERY Run No: $j =====\nSTARTUP_PARAMS: ".$DBMS_hash->{'STARTUP_PARAMS'}."\n\n" );
							AppendFileToAnother("$RESULTS_OUTPUT_DIR/$KEYWORD/$explainFilename", "$RESULTS_OUTPUT_DIR/$KEYWORD/all_explains.txt", "--- Explain result ---", "--- Time elapsed ---\n$elapsedTime");
						}


						#Push the elapsed time into the hash with different execution plans					
						push(@{ $GlobalExplainResults{$executionPlan} }, $elapsedTime);
					}
########				#####################################


					#Post-run statements
					my $postRunSQLFilename = $l_QUERY . "_no_$j" . "_post_run_sql.txt";
					if($l_POST_RUN_SQL){
						ExecuteInShell($DBMS_hash, $l_POST_RUN_SQL, "", $KEYWORD, $postRunSQLFilename);
					}


					my $postRunOSFilename =  $l_QUERY . "_no_$j" . "_post_run_os.txt";
					if($l_POST_RUN_OS){
						system("$l_POST_RUN_OS > $RESULTS_OUTPUT_DIR/$KEYWORD/$postRunOSFilename");
					}


					my $run_comments = "";
					if($elapsedTime == -1){
						$run_comments = "Timeout exceeded";
					}

					LogEndRunResult($dbh_res, $test_id, $j, 0, $elapsedTime, $postRunSQLFilename, $run_comments);



					if($l_ANALYZE_EXPLAIN){
						#Check the results. If time limit is reached or target queries run is reached, stop the test for that query
						if(	($l_NUM_TESTS != 0 && $j >= $l_NUM_TESTS) ||
							($l_MAX_QUERY_TIME != 0 && $l_MAX_QUERY_TIME < $l_TIMEOUT + (time - $queryStartTime))){
							#There is no time for new test. Get the best cluster and show a warning
							$resultHash->{'min'} = GetBestExplainCluster(\%GlobalExplainResults, $l_CLUSTER_SIZE, 1);

							if ($l_NUM_TESTS != 0 && $j >= $l_NUM_TESTS){
								PrintMsg("\n\n Test limit of $l_NUM_TESTS reached. Getting the best result available: ".$resultHash->{'min'}."\n\n");
							}else{
								PrintMsg("\n\n No time for next run. Getting the best result available: ".$resultHash->{'min'}."\n\n");
								$test_comments .= "No time for next run. Getting the best result available.\n";
							}
							$noMoreTests = 1;
						}else{
							if($l_NUM_TESTS == 0){
								#There is enough time to perform another test
								$resultHash->{'min'} = GetBestExplainCluster(\%GlobalExplainResults, $l_CLUSTER_SIZE, 0);
								if($resultHash->{'min'}){
									$noMoreTests = 1;
								}
							}
						}
					}elsif($l_MIN_MAX_OUT_OF_N){
						if($j >= $l_NUM_TESTS){
							$resultHash = GetMinMax(\%GlobalExplainResults);
							$noMoreTests = 1;
						}
					}elsif($l_SIMPLE_AVERAGE){
						if($j >= $l_NUM_TESTS){
							$resultHash->{'avg'} = GetSimpleAverage(\%GlobalExplainResults);
							$noMoreTests = 1;
						}
					}
				}#if(!$skipCurrentRun)
			}
			

			
			#stop mysql
			if(!$QUERIES_AT_ONCE){
				#if that's the last test and last run, perform the post-test before stopping mysqld
				if($noMoreTests && $i+1 == scalar(keys %{ $configHash->{'queries'} })){
					if($POST_TEST_SQL){
						ExecuteInShell($DBMS_hash, $POST_TEST_SQL, "", $KEYWORD, "post_test_sql_results.txt");
					}
				}

				if($DBMS_hash->{'DBMS'} eq "PostgreSQL"){
					if(!StopPostgres($DBMS_hash, $startedServers)){
						SafelyDie("Could not stop postgres process", __LINE__);
					}
				}else{
					if(!StopMysql($DBMS_hash, $startedServers)){
						SafelyDie("Could not stop mysqld process", __LINE__);
					}
				}

				if($noMoreTests && $i+1 == scalar(keys %{ $configHash->{'queries'} })){
					if($POST_TEST_OS){
						system("$POST_TEST_OS > $RESULTS_OUTPUT_DIR/$KEYWORD/post_test_os_results.txt");
					}
				}
			}

		}#while

		PrintMsg("\nRESULT FOR QUERY: min=".$resultHash->{'min'}."   max=".$resultHash->{'max'}."   avg=".$resultHash->{'avg'}."\n\n");
		LogEndTestResult($dbh_res, $test_id, $resultHash->{'min'}, $resultHash->{'max'}, $resultHash->{'avg'}, "$KEYWORD/post_test_sql_results.txt", $test_comments);
		
		
		#Plot the graph
		PlotGraph($dbh_res, $GRAPH_HEADING, $l_ANALYZE_EXPLAIN, $l_MIN_MAX_OUT_OF_N, $l_SIMPLE_AVERAGE);
		sleep 1; #wait at least a second here to avoid two tests in one second that coauses PRIMARY KEY violation.
	}#for


	if($QUERIES_AT_ONCE){
		#Post-test statements
		if($POST_TEST_SQL){
			ExecuteInShell($configHash->{'db_config'}, $POST_TEST_SQL, "", $KEYWORD, "post_test_sql_results.txt");
		}

		if($POST_TEST_OS){
			system("$POST_TEST_OS > $RESULTS_OUTPUT_DIR/$KEYWORD/post_test_os_results.txt");
		}

		if($configHash->{'db_config'}->{'DBMS'} eq "PostgreSQL"){
			if(!StopPostgres($configHash->{'db_config'}, $startedServers)){
				SafelyDie("Could not start postgres process", __LINE__);
			}
		}else{
			if(!StopMysql($configHash->{'db_config'}, $startedServers)){
				SafelyDie("Could not stop mysqld process", __LINE__);
			}
		}
	}

	#Stop results DB server
	$dbh_res->disconnect();

	if(!StopMysql($configHash->{'results_db'}, $startedServers)){
		SafelyDie("Could not stop Results' mysqld process", __LINE__);
	}
}



sub PrintMsg{
	#TODO: hide the printed messages if a setting is set
	my $msg = $_[0];
	print "\n*** " .GetTimestamp() ." *** DBT3 test: $msg";
}

######################################## Main program ########################################

my %testingConfiguration;
my $command_line_hash = {};

GetOptions (	"test|t:s" 			=> \$TEST_FILE,
		"results-output-dir|r:s"	=> \$RESULTS_OUTPUT_DIR,
		"dry-run" 			=> \$dry_run,
		"project-home:s"		=> \$PROJECT_HOME,
		"datadir-home:s"		=> \$DATADIR_HOME,
		"queries-home:s"		=> \$QUERIES_HOME,
		"scale-factor|sf:s"		=> \$SCALE_FACTOR,

		#overriding parameters
		"CLEAR_CACHES:s"		=> \$command_line_hash->{'CLEAR_CACHES'},
		"QUERIES_AT_ONCE:s"		=> \$command_line_hash->{'QUERIES_AT_ONCE'},
		"RUN:s" 			=> \$command_line_hash->{'RUN'},
		"EXPLAIN:s" 			=> \$command_line_hash->{'EXPLAIN'},
		"TIMEOUT:s" 			=> \$command_line_hash->{'TIMEOUT'},
		"NUM_TESTS:s" 			=> \$command_line_hash->{'NUM_TESTS'},
		"MAX_SKIPPED_TESTS:s" 		=> \$command_line_hash->{'MAX_SKIPPED_TESTS'},
		"WARMUP:s" 			=> \$command_line_hash->{'WARMUP'},
		"WARMUPS_COUNT:s" 		=> \$command_line_hash->{'WARMUPS_COUNT'},
		"MAX_QUERY_TIME:s" 		=> \$command_line_hash->{'MAX_QUERY_TIME'},
		"CLUSTER_SIZE:s" 		=> \$command_line_hash->{'CLUSTER_SIZE'},
		"PRE_RUN_OS:s" 			=> \$command_line_hash->{'PRE_RUN_OS'},
		"POST_RUN_OS:s" 		=> \$command_line_hash->{'POST_RUN_OS'},
		"OS_STATS_INTERVAL:s" 		=> \$command_line_hash->{'OS_STATS_INTERVAL'}
);

$testingConfiguration{'command_line'} = $command_line_hash;


if(!CheckInputParams()){
	exit;
}else{
	CollectHardwareInfo();

	

	my $scenarioConfig = ParseConfigFile($TEST_FILE, "ini");	
	copy ($TEST_FILE, "$RESULTS_OUTPUT_DIR/") or SafelyDie("Could not copy test configuration file to $RESULTS_OUTPUT_DIR", __LINE__);

	if(! -e $scenarioConfig->{'common'}->{'RESULTS_DB_CONFIG'}){
		SafelyDie("Configuration file ".$scenarioConfig->{'common'}->{'RESULTS_DB_CONFIG'}." does not exist!", __LINE__);
	}else{
		$testingConfiguration{'results_db'} = ParseConfigFile($scenarioConfig->{'common'}->{'RESULTS_DB_CONFIG'}, "equal");
		$testingConfiguration{'results_db'}->{'config_filename'} = $scenarioConfig->{'common'}->{'RESULTS_DB_CONFIG'};
		
		copy ($testingConfiguration{'results_db'}->{'config_filename'}, "$RESULTS_OUTPUT_DIR/") or SafelyDie("Could not copy results_db configuration file to $RESULTS_OUTPUT_DIR", __LINE__);
	}

	if(! -e $scenarioConfig->{'common'}->{'TEST_CONFIG'}){
		SafelyDie("Configuration file ".$scenarioConfig->{'common'}->{'TEST_CONFIG'}." does not exist!", __LINE__);
	}else{
		$testingConfiguration{'test_config'} = ParseConfigFile($scenarioConfig->{'common'}->{'TEST_CONFIG'}, "equal");
		$testingConfiguration{'test_config'}->{'config_filename'} = $scenarioConfig->{'common'}->{'TEST_CONFIG'};
		
		copy ($testingConfiguration{'test_config'}->{'config_filename'}, "$RESULTS_OUTPUT_DIR/") or SafelyDie("Could not copy test_config configuration file to $RESULTS_OUTPUT_DIR", __LINE__);
	}


	while ( my ($key, $value) = each(%{$scenarioConfig}) ) {
		
		if($key eq "common"){
			next;
		}		

		delete($testingConfiguration{'queries'});
		delete($testingConfiguration{'db_config'});

		if(! -e $scenarioConfig->{$key}->{'QUERIES_CONFIG'}){
			SafelyDie("Configuration file ".$scenarioConfig->{$key}->{'QUERIES_CONFIG'}." does not exist!", __LINE__);
		}else{
			$testingConfiguration{'queries'} = ParseConfigFile($scenarioConfig->{$key}->{'QUERIES_CONFIG'}, "ini");
		}

		if(! -e $scenarioConfig->{$key}->{'DB_CONFIG'}){
			SafelyDie("Configuration file ".$scenarioConfig->{$key}->{'DB_CONFIG'}." does not exist!", __LINE__);
		}else{
			$testingConfiguration{'db_config'} = ParseConfigFile($scenarioConfig->{$key}->{'DB_CONFIG'}, "ini")->{'db_settings'};
		}

		my $keyword = $testingConfiguration{'db_config'}->{'KEYWORD'};
		if($keyword && !(-e "$RESULTS_OUTPUT_DIR/$keyword")){
			mkpath("$RESULTS_OUTPUT_DIR/$keyword") or SafelyDie("Could not make path '$RESULTS_OUTPUT_DIR/$keyword'", __LINE__);
		}

		
		copy ($scenarioConfig->{$key}->{'DB_CONFIG'}, "$RESULTS_OUTPUT_DIR/$keyword/") or SafelyDie("Could not copy '".$scenarioConfig->{$key}->{'DB_CONFIG'}."'db_config configuration file to $RESULTS_OUTPUT_DIR/$keyword/", __LINE__);
		copy ($scenarioConfig->{$key}->{'QUERIES_CONFIG'}, "$RESULTS_OUTPUT_DIR/$keyword/") or SafelyDie("Could not copy queries configuration file to $RESULTS_OUTPUT_DIR/$keyword/", __LINE__);

		RunTests(\%testingConfiguration);
	}
}




exit 1;
