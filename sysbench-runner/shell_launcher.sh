#!/bin/bash
MYSQLADMIN="./bin/mysqladmin"
MYSQLADMIN_OPTIONS=""
MYSQLD_SAFE="./bin/mysqld_safe"
MYSQLD_OPTIONS=""
TIMEOUT=100
PROJECT_HOME="${HOME}/Projects/MariaDB";
MAX_TIME=10
WARMUP_TIME=30

function kill_mysqld {
	./bin/mysqladmin --user=root shutdown 0
    killall -9 mysqld
#    rm -rf $DATA_DIR
#    rm -f $MY_SOCKET
#    mkdir $DATA_DIR
}

function start_mysqld {
    ./bin/mysqld_safe $MYSQLD_OPTIONS &

    j=0
    STARTED=-1
    while [ $j -le $TIMEOUT ]
        do
        $MYSQLADMIN $MYSQLADMIN_OPTIONS ping > /dev/null 2>&1
        if [ $? = 0 ]; then
            STARTED=0

            break
        fi

        sleep 1
        j=$(($j + 1))
    done

    if [ $STARTED != 0 ]; then
        echo '[ERROR]: Start of mysqld failed.'
        echo '  Please check your error log.'
        echo '  Exiting.'

        exit 1
    fi
}



echo "--- Running Scenario1 ---"

#1) Start the MySQL 5.5.13 server
cd $PROJECT_HOME/mysql-5.5.13-linux2.6-x86_64
# ./bin/mysqld_safe --defaults-file=../scripts/config/mysql_my.cnf --user=root &
MYSQLD_OPTIONS="--defaults-file=$PROJECT_HOME/scripts/config/mysql_my.cnf --user=root"
kill_mysqld
start_mysqld

#2)Execute the perl script for the first test with MySQL 5.5.13 and engine InnoDB
cd $PROJECT_HOME/scripts/
perl bench_script.pl --max-time=$MAX_TIME \
--dbname=mysql_5_5_13 \
--keyword=scenario1  \
--results-output-dir=./Scenario1 \
--warmup-time=$WARMUP_TIME --warmup-threads=4 \
--mysql-table-engine=innodb \
--parallel-prepare

#3) Switch to MariaDB
cd $PROJECT_HOME/mysql-5.5.13-linux2.6-x86_64/
kill_mysqld
cd $PROJECT_HOME/mariadb-5.2.7-Linux-x86_64
MYSQLD_OPTIONS="--defaults-file=$PROJECT_HOME/scripts/config/mariadb_my.cnf";
start_mysqld

#4) Execute the perl script for the second test with MariaDB and engine InnoDB
cd $PROJECT_HOME/scripts/
perl bench_script.pl --max-time=$MAX_TIME \
--dbname=mariadb_5_2_7 \
--keyword=scenario1  \
--results-output-dir=./Scenario1 \
--warmup-time=$WARMUP_TIME --warmup-threads=4 \
--mysql-table-engine=innodb \
--parallel-prepare

#5) Execute the perl script for the second test with MariaDB and engine PBXT
cd $PROJECT_HOME/scripts/
perl bench_script.pl --max-time=$MAX_TIME \
--dbname=mariadb_5_2_7 \
--keyword=scenario1  \
--results-output-dir=./Scenario1 \
--warmup-time=$WARMUP_TIME --warmup-threads=4 \
--mysql-table-engine=pbxt \
--parallel-prepare

#6) Stop the server after the tests are complete
cd $PROJECT_HOME/mariadb-5.2.7-Linux-x86_64/
kill_mysqld

#7) Run the gnuplot script to generate a graphic
cd $PROJECT_HOME/scripts/
gnuplot $PROJECT_HOME/scripts/gnuplot_scenario1.txt

echo "Scenario 1 complete"



: <<'END'

echo "--- Running Scenario2 ---"

#1) Copy oltp_aria.lua to the other default workloads in sysbench
cd $PROJECT_HOME/scripts/
cp oltp_aria.lua ../sysbench/sysbench/tests/db/

#2) Start the MySQL 5.5.13 server
cd $PROJECT_HOME/mysql-5.5.13-linux2.6-x86_64
MYSQLD_OPTIONS="--defaults-file=../scripts/config/mysql_my.cnf --user=root"
kill_mysqld
start_mysqld

#3) Execute the perl script with MySQL 5.5.13 and MyISAM storage engine
cd $PROJECT_HOME/scripts/
perl bench_script.pl --max-time=$MAX_TIME \
--dbname=mysql_5_5_13 \
--keyword=scenario2  \
--results-output-dir=./Scenario2 \
--warmup-time=$WARMUP_TIME --warmup-threads=4 \
--mysql-table-engine=myisam \
--workload=oltp_aria.lua \
--parallel-prepare

#4) Switch to MariaDB 5.2.7
cd $PROJECT_HOME/mysql-5.5.13-linux2.6-x86_64/
kill_mysqld
cd $PROJECT_HOME/mariadb-5.2.7-Linux-x86_64
MYSQLD_OPTIONS="--defaults-file=../scripts/config/mariadb_my.cnf"
start_mysqld

#5) Execute the perl script with MariaDB 5.2.7 and Aria storage engine
cd $PROJECT_HOME/scripts/
perl bench_script.pl --max-time=$MAX_TIME \
--dbname=mariadb_5_2_7 \
--keyword=scenario2  \
--results-output-dir=./Scenario2 \
--warmup-time=$WARMUP_TIME --warmup-threads=4 \
--mysql-table-engine=aria \
--workload=oltp_aria.lua \
--parallel-prepare

#6) Stop the server after the tests are complete
cd $PROJECT_HOME/mariadb-5.2.7-Linux-x86_64/
kill_mysqld

#7) Run the gnuplot script to generate a graphic
cd $PROJECT_HOME/scripts/
gnuplot gnuplot_scenario2.txt

echo "Scenario 2 complete"




echo "--- Running Scenario3 ---"
#1) Create a folder on the SSD drive
#cd /media/ssd_tmp
#mkdir vlado_bench_ssd
#2) Copy the installed data directory to SSD
#cp -r $PROJECT_HOME/mariadb-5.2.7-Linux-x86_64/data/ /media/ssd_tmp/vlado_bench_ssd/

#3) Start the mysqld process for MariaDB 5.2.7 with both data and binlog on HDD
cd $PROJECT_HOME/mariadb-5.2.7-Linux-x86_64
kill_mysqld
MYSQLD_OPTIONS="--defaults-file=../scripts/config/mariadb_my.cnf --log-basename=hdd_binlog --log-bin=1 --datadir=./data"
start_mysqld

#4) Execute the perl script for the first test with MariaDB + XtraDB with both data and binlog on HDD
cd $PROJECT_HOME/scripts/ 
perl bench_script.pl --max-time=$MAX_TIME \
--dbname=mariadb_5_2_7 \
--keyword=hdd  \
--results-output-dir=./Scenario3 \
--warmup-time=$WARMUP_TIME --warmup-threads=4 \
--mysql-table-engine=innodb \
--parallel-prepare

#5) Stop mysqld process and restart it with both data and binlog on SSD
cd $PROJECT_HOME/mariadb-5.2.7-Linux-x86_64/
kill_mysqld
MYSQLD_OPTIONS="--defaults-file=../scripts/config/mariadb_my.cnf --log-basename=/media/ssd_tmp/vlado_bench_ssd/ssd_binlog --log-bin=1 --datadir=/media/ssd_tmp/vlado_bench_ssd/data"
start_mysqld

#6) Execute the perl script for the second test with MariaDB + XtraDB with both data and binlog on SSD
cd $PROJECT_HOME/scripts/ 
perl bench_script.pl --max-time=$MAX_TIME \
--dbname=mariadb_5_2_7 \
--keyword=ssd  \
--results-output-dir=./Scenario3 \
--warmup-time=$WARMUP_TIME --warmup-threads=4 \
--mysql-table-engine=innodb \
--parallel-prepare

#7) Stop mysqld process and restart it with data on HDD, and transactional log on SSD 
cd $PROJECT_HOME/mariadb-5.2.7-Linux-x86_64/
kill_mysqld
MYSQLD_OPTIONS="--defaults-file=../scripts/config/mariadb_my.cnf --log-basename=/media/ssd_tmp/vlado_bench_ssd/ssd_binlog --log-bin=1 --datadir=./data"
start_mysqld

#8) Execite the perl script for the third test with data on HDD, and transactional log on SSD 
cd $PROJECT_HOME/scripts/ 
perl bench_script.pl --max-time=$MAX_TIME \
--dbname=mariadb_5_2_7 \
--keyword=ssd_hdd  \
--results-output-dir=./Scenario3 \
--warmup-time=$WARMUP_TIME --warmup-threads=4 \
--mysql-table-engine=innodb \
--parallel-prepare

#9) Stop the server after the tests are complete
cd $PROJECT_HOME/mariadb-5.2.7-Linux-x86_64/
kill_mysqld

#10)  Run the gnuplot script to generate a graphic
cd $PROJECT_HOME/scripts/
gnuplot gnuplot_scenario3.txt

echo "Scenario 3 complete"


END
