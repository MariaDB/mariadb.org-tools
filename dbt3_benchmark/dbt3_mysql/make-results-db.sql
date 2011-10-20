CREATE DATABASE IF NOT EXISTS dbt3_results;


USE dbt3_results;


CREATE TABLE IF NOT EXISTS test_result (
	test_id 		INTEGER NOT NULL PRIMARY KEY,	/*The test ID. It is a timestamp from Perl and cannot duplicate since it changes every second and launcher.pl sleeps at least for 1 second between tests for that reason*/
	query_name 		VARCHAR(100) NOT NULL,		/*The query that is tested*/
	start_time		DATETIME,			/*When the test started*/
	end_time		DATETIME,			/*When the test ended*/
	min_elapsed_time 	FLOAT,				/*The minimal elapsed time for the test. If the query has timed out, the value will be -1*/
	max_elapsed_time	FLOAT,				/*The maximal elapsed time for the test. If the query has timed out, the value will be -1*/
	avg_elapsed_time	FLOAT,				/*The average elapsed time for the test. If the query has timed out, the value will be -1*/
	results_output_dir	VARCHAR(255),			/*Where the results of the test are stored on the file system. This dir contains files with OS statistics and pre/post run sql/os commands results*/
	pre_test_sql		VARCHAR(255),			/*The filename that pre test sql results are stored into the results_output_dir*/
	post_test_sql		VARCHAR(255),			/*The filename that post test sql results are stored into the results_output_dir*/	
	keyword			VARCHAR(255),			/*A keyword for each test scenario that is run. Example: mariadb_5_3_0_xtradb*/
	storage_engine		VARCHAR(100),			/*Which storage engine was tested. Example: InnoDB*/
	scale_factor		INT,				/*What was the DBT3 scale factor that was tested against. Examples: 1, 10, 30*/
	version			VARCHAR(100),			/*What is the version of the DBMS got with the command 'select version()'*/
	comments		TEXT				/*Any comments during the test. Example: Query timed out*/
) engine=innodb;


CREATE TABLE IF NOT EXISTS query_result(
	test_id 	INTEGER, FOREIGN KEY (test_id) REFERENCES test_result(test_id),	/*Foreign key to test_result*/
	run_id		INTEGER,							/*The ID of each particular run*/
	is_warmup	INTEGER,							/*Was that run a warmup run*/
	start_time	DATETIME,							/*When the test started*/
	end_time	DATETIME,							/*When the test ended*/
	elapsed_time 	FLOAT,								/*What was the elapsed time for that run. If the query timed out, the value will be -1*/
	explain_result	VARCHAR(255),							/*The name of results file from the explain query executed after the run. A file with that filename could be found under results_output_dir*/
	pre_run_sql 	VARCHAR(255),							/*The name of results file from the pre run SQL commands that were executed. A file with that filename could be found under results_output_dir*/
	post_run_sql	VARCHAR(255),							/*The name of results file from the post run SQL commands that were executed. A file with that filename could be found under results_output_dir*/
	comments	TEXT,								/*Any comments during the run. Example: Query timed out*/
	PRIMARY KEY (test_id, run_id, is_warmup)
) engine=innodb;
