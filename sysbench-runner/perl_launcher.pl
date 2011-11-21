#!/usr/bin/env perl
use warnings;
use strict;
use Getopt::Long;
use File::Copy;

our $WARMUP;
our $RUN;
our $CLEANUP;
our $PLOT;
# our $PROJECT_HOME;
our $SCRIPTS_HOME;
our $SYSBENCH_HOME;
our $TEMP_DIR;
our $MAX_TIME;
our $WARMUP_TIME;
our $WARMUP_THREADS;
our $TABLES_COUNT;
our $TABLE_SIZE;
our $RESULTS_OUTPUT_DIR;
our $SOCKET;
our $THREADS;

our $DESCRIPTION;
our $DATADIR;
our $DATA_SOURCE_DIR;
our $MYSQLD_START_PARAMS;
our $DBNAME;
our $KEYWORD;
our $TABLE_ENGINE;
our $CONFIG_FILE;
our $WORKLOAD;
our $MYSQL_HOME;
our $MYSQL_USER;
our $READONLY;
our $PARALLEL_PREPARE;
our $PREPARE_THREADS;
our $PRE_RUN_SQL;
our $GRAPH_HEADING;
our $WARMUP_DELAY;
our $RUN_DELAY;

our @configurations;


my @config_files;




######################################## Function declarations ########################################
sub CheckInputParams{
	my $retErrors = "";
	my $warnings = "";
	
	if(!@config_files){
		$retErrors = "ERROR: Missing input parameter 'config'.\n";
	}

	if($warnings){
		print $warnings;
	}
	return $retErrors;
}

sub GetTimestamp{
	my($min, $hour, $day, $month, $year) = (localtime)[1,2,3,4,5];
	$min	= sprintf '%02d', $min;
	$hour	= sprintf '%02d', $hour;
	$month	= sprintf '%02d', $month+1;
	$day	= sprintf '%02d', $day;
	$year	= $year + 1900;
	return $year . "_$month" . "_$day" . "_$hour" . "$min";
}

sub RunTests{
	my $cnf_file = $_[0];
	require ($cnf_file);
	
	my $graphics_dir 		= "";
	my $graphics_threads		= "";
	my $graphics_title 		= "";
	my $graphics_result_files 	= "";
	my $do_plot			= 0;

	#put a timestamp to the results dir
	
	$RESULTS_OUTPUT_DIR .= "_". GetTimestamp();

	for (my $i=0; $i < scalar(@configurations); $i++){

		my $l_WARMUP			= $configurations[$i]{WARMUP}	 		// $WARMUP;
		my $l_RUN			= $configurations[$i]{RUN}	 		// $RUN;
		my $l_CLEANUP			= $configurations[$i]{CLEANUP}	 		// $CLEANUP;
		my $l_PLOT			= $configurations[$i]{PLOT}	 		// $PLOT;
# 		my $l_PROJECT_HOME 		= $configurations[$i]{PROJECT_HOME} 		// $PROJECT_HOME;
		my $l_SCRIPTS_HOME		= $configurations[$i]{SCRIPTS_HOME} 		// $SCRIPTS_HOME;
		my $l_SYSBENCH_HOME 		= $configurations[$i]{SYSBENCH_HOME} 		// $SYSBENCH_HOME;
		my $l_TEMP_DIR			= $configurations[$i]{TEMP_DIR} 		// $TEMP_DIR;
		my $l_MAX_TIME			= $configurations[$i]{MAX_TIME} 		// $MAX_TIME;
		my $l_WARMUP_TIME		= $configurations[$i]{WARMUP_TIME} 		// $WARMUP_TIME;
		my $l_WARMUP_THREADS		= $configurations[$i]{WARMUP_THREADS} 		// $WARMUP_THREADS;
		my $l_TABLES_COUNT		= $configurations[$i]{TABLES_COUNT} 		// $TABLES_COUNT;
		my $l_TABLE_SIZE		= $configurations[$i]{TABLE_SIZE} 		// $TABLE_SIZE;		
		my $l_SOCKET			= $configurations[$i]{SOCKET} 			// $SOCKET;
		my $l_THREADS			= $configurations[$i]{THREADS} 			// $THREADS;

		my $l_DESCRIPTION		= $configurations[$i]{DESCRIPTION} 		// $DESCRIPTION;
		my $l_DATADIR			= $configurations[$i]{DATADIR} 			// $DATADIR;
		my $l_DATA_SOURCE_DIR		= $configurations[$i]{DATA_SOURCE_DIR} 		// $DATA_SOURCE_DIR;
		my $l_MYSQLD_START_PARAMS	= $configurations[$i]{MYSQLD_START_PARAMS} 	// $MYSQLD_START_PARAMS;
		my $l_DBNAME			= $configurations[$i]{DBNAME} 			// $DBNAME;
		my $l_KEYWORD			= $configurations[$i]{KEYWORD} 			// $KEYWORD;
		my $l_TABLE_ENGINE		= $configurations[$i]{TABLE_ENGINE} 		// $TABLE_ENGINE;
		my $l_CONFIG_FILE		= $configurations[$i]{CONFIG_FILE} 		// $CONFIG_FILE;
		my $l_WORKLOAD			= $configurations[$i]{WORKLOAD} 		// $WORKLOAD;
		my $l_MYSQL_HOME		= $configurations[$i]{MYSQL_HOME} 		// $MYSQL_HOME;
		my $l_MYSQL_USER		= $configurations[$i]{MYSQL_USER} 		// $MYSQL_USER;
		my $l_READONLY			= $configurations[$i]{READONLY} 		// $READONLY;
		my $l_PARALLEL_PREPARE		= $configurations[$i]{PARALLEL_PREPARE} 	// $PARALLEL_PREPARE;
		my $l_PREPARE_THREADS		= $configurations[$i]{PREPARE_THREADS} 		// $PREPARE_THREADS;
		my $l_PRE_RUN_SQL		= $configurations[$i]{PRE_RUN_SQL}		// $PRE_RUN_SQL;

		my $l_WARMUP_DELAY		= $configurations[$i]{WARMUP_DELAY}		// $WARMUP_DELAY	// 0;
		my $l_RUN_DELAY			= $configurations[$i]{RUN_DELAY}		// $RUN_DELAY		// 0;



		print "\n=== $l_DESCRIPTION ===\n";
		
		if(-e $l_DATADIR){
			#system("rm -r $l_DATADIR");
			die "ERROR: DATADIR ($l_DATADIR) already exists.";
		}



		################ PREPARE ################		
		if($l_DATA_SOURCE_DIR){
			#if we have ready folder to copy from
			if(!(-e $l_DATA_SOURCE_DIR)){
				die "ERROR: DATA_SOURCE_DIR ($l_DATA_SOURCE_DIR) does not exits";
			}
			if(-e $l_DATADIR){
				die "ERROR: DATADIR ($l_DATADIR) already exists.";
			}else{
				print "Copying datadir from '$l_DATA_SOURCE_DIR' to '$l_DATADIR'";
				system ("cp -r $l_DATA_SOURCE_DIR $l_DATADIR");# or die "Could not copy datadir to $l_DATA_SOURCE_DIR: $!";
			}
		} else {
			#if not, we should prepare the database ourselves

			#1. Install DB into that folder
			chdir($l_SCRIPTS_HOME) or die "Can't change dir to SCRIPTS_HOME ($l_SCRIPTS_HOME)";
			system("perl bench_script.pl --install \\\
--config-file=$l_CONFIG_FILE \\\
--datadir=$l_DATADIR \\\
--socket=$l_SOCKET \\\
--mysql-home=$l_MYSQL_HOME \\\
--mysql-user=$l_MYSQL_USER");


			#2. Perform prepare statment
			my $parallel_prepare 	= "";
			my $prepare_threads 	= "";
			if($l_PARALLEL_PREPARE){
				$parallel_prepare 	= "--parallel-prepare";
				$prepare_threads	= "--prepare-threads=$l_PREPARE_THREADS";
			}

			chdir($l_SCRIPTS_HOME) or die "Can't change dir to SCRIPTS_HOME ($l_SCRIPTS_HOME)";
			system("perl bench_script.pl --prepare $parallel_prepare $prepare_threads \\\
--sysbench-home=$l_SYSBENCH_HOME \\\
--datadir=$l_DATADIR \\\
--mysql-table-engine=$l_TABLE_ENGINE \\\
--config-file=$l_CONFIG_FILE \\\
--mysql-home=$l_MYSQL_HOME \\\
--socket=$l_SOCKET \\\
--table-size=$l_TABLE_SIZE \\\
--oltp-tables-count=$l_TABLES_COUNT \\\
--mysql-user=$l_MYSQL_USER \\\
--workload=$l_WORKLOAD");
		} #else


		# Perform additional SQL queries to the DB before running tests.
		if($l_PRE_RUN_SQL){
			chdir($l_SCRIPTS_HOME) or die "Can't change dir to SCRIPTS_HOME ($l_SCRIPTS_HOME)";
			system("perl bench_script.pl --do-pre-run \\\
--pre-run-sql=\"$l_PRE_RUN_SQL\" \\\
--datadir=$l_DATADIR \\\
--mysql-table-engine=$l_TABLE_ENGINE \\\
--config-file=$l_CONFIG_FILE \\\
--mysql-home=$l_MYSQL_HOME \\\
--socket=$l_SOCKET \\\
--mysql-user=$l_MYSQL_USER");
			}
		



		################ RUN ################
		if($l_RUN){
			#additional mysqld startup parameters
			my $mysqld_start_params = "";
			if($l_MYSQLD_START_PARAMS){
				$mysqld_start_params = "--mysqld-start-params=\"$l_MYSQLD_START_PARAMS\" ";
			}

			#readonly option
			my $readonly = "";
			if($l_READONLY){
				$readonly = "--readonly ";
			}

			my $warmup = "";
			if($l_WARMUP){
				$warmup = "--warmup";
			}

			my $cleanup = "";
			if($l_CLEANUP){
				$cleanup = "--cleanup";
			}

			#Threads string
			my $threads_string = "";
			for my $thr (split(',', $l_THREADS)){
				$thr =~ s/ *//g;
				$threads_string .= "--t=$thr ";
			}

			chdir($l_SCRIPTS_HOME);
			system("perl bench_script.pl $warmup --run $cleanup $mysqld_start_params \\\
--max-time=$l_MAX_TIME $readonly \\\
--sysbench-home=$l_SYSBENCH_HOME \\\
--dbname=$l_DBNAME \\\
--keyword=$l_KEYWORD \\\
--results-output-dir=$RESULTS_OUTPUT_DIR \\\
--warmup-time=$l_WARMUP_TIME \\\
--warmup-threads=$l_WARMUP_THREADS \\\
--oltp-tables-count=$l_TABLES_COUNT \\\
--mysql-table-engine=$l_TABLE_ENGINE \\\
--config-file=$l_CONFIG_FILE \\\
--workload=$l_WORKLOAD \\\
--datadir=$l_DATADIR \\\
--mysql-home=$l_MYSQL_HOME \\\
--mysql-user=$l_MYSQL_USER \\\
--socket=$l_SOCKET \\\
--warmup-delay=$l_WARMUP_DELAY \\\
--run-delay=$l_RUN_DELAY \\\
$threads_string");
		} #if($l_RUN)


		if($l_PLOT){
			$do_plot 		= 1;
			$graphics_threads	= $l_THREADS;
			if(!$GRAPH_HEADING){
				$graphics_title .= "$l_DESCRIPTION vs. ";
			}
			$graphics_result_files 	.= "'$RESULTS_OUTPUT_DIR/res_$l_KEYWORD" . "_" . $l_DBNAME . "_" . $l_TABLE_ENGINE."_final.txt' with linespoints ti '$l_DESCRIPTION', ";
		}



		################ CLEANUP ################
		if($l_CLEANUP){
			Cleanup($l_DATADIR);
		}	
	} #for





################ PLOT ################
	if($do_plot){
		# Plot the graphics
		$graphics_dir 		= $RESULTS_OUTPUT_DIR;
		$graphics_title 	=~ s/ vs\. $//g;#remove the last ' vs. '
		$graphics_title 	=~ s/\"/\\"/g; 	#replace the apostrophe with escaped one
		$graphics_result_files	=~ s/, $//g;	#remove the last comma 
		
		if($GRAPH_HEADING){
			$graphics_title = $GRAPH_HEADING;
		}
		PlotGraphics($graphics_dir, $graphics_title, $graphics_threads, $graphics_result_files);	
	}
}





sub PlotGraphics{
	my $graphics_dir 		= $_[0];
	my $graphics_title		= $_[1];
	my $graphics_threads		= $_[2];
	my $graphics_result_files	= $_[3];

	my $gnuScript = "set terminal jpeg
			set output '$graphics_dir/graphics.jpeg'
			set xlabel 'Threads'
			set ylabel 'Transactions per second'
			set key below right
			set grid
			set title \"$graphics_title\" 
			set xtics ($graphics_threads)
			plot $graphics_result_files";

	open (MYFILE, "> $graphics_dir/gnuplot_script.txt");
	print MYFILE $gnuScript;
	close (MYFILE); 
	system("gnuplot $graphics_dir/gnuplot_script.txt");
}





sub Cleanup{
	my $datadir 		= $_[0];

	if($datadir){
		system("rm -r $datadir");
	}
}



######################################## Main program ########################################

GetOptions (	"config|c:s" 	=> \@config_files);

my $paramsCheck = CheckInputParams();
if(length($paramsCheck) > 0){
	print $paramsCheck;
	exit;
}else{
	foreach my $file (@config_files){
		RunTests($file);
	}
}

exit;