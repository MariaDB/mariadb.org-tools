#!/bin/bash
#
# Run sysbench tests with MariaDB and MySQL
#
# Note: Do not run this script with root privileges.
#   We use killall -9, which can cause severe side effects!
#
# Hakan Kuecuekyilmaz <hakan at askmonty dot org> 2010-02-19.
#

#
# Do not run this script as root!
#
RUN_BY=$(whoami)
if [ x"root" = x"$RUN_BY" ];then
   echo '[ERROR]: Do not run this script as root!'
   echo '  Exiting.'
   
   exit 1
fi

#
# Variables.
#
TEMP_DIR='/tmp'
DATA_DIR="${TEMP_DIR}/data"
MY_SOCKET="${TEMP_DIR}/mysql.sock"
MYSQLADMIN_OPTIONS="--no-defaults -uroot --socket=$MY_SOCKET"
MYSQL_OPTIONS="--no-defaults \
  --skip-grant-tables \
  --language=./sql/share/english \
  --datadir=$DATA_DIR \
  --tmpdir=$TEMP_DIR \
  --socket=$MY_SOCKET \
  --table_open_cache=512 \
  --thread_cache=512 \
  --query_cache_size=0 \
  --query_cache_type=0 \
  --innodb_data_home_dir=$DATA_DIR \
  --innodb_data_file_path=ibdata1:128M:autoextend \
  --innodb_log_group_home_dir=$DATA_DIR \
  --innodb_buffer_pool_size=1024M \
  --innodb_additional_mem_pool_size=32M \
  --innodb_log_file_size=256M \
  --innodb_log_buffer_size=16M \
  --innodb_flush_log_at_trx_commit=1 \
  --innodb_lock_wait_timeout=50 \
  --innodb_doublewrite=0 \
  --innodb_flush_method=O_DIRECT \
  --innodb_thread_concurrency=0 \
  --innodb_max_dirty_pages_pct=80"

NUM_THREADS="1 4 8 16 32 64 128"
TABLE_SIZE=2000000
RUN_TIME=300
SYSBENCH_TESTS="delete.lua \
  insert.lua \
  oltp_complex_ro.lua \
  oltp_complex_rw.lua \
  oltp_simple.lua \
  select.lua \
  update_index.lua \
  update_non_index.lua"
SYSBENCH_OPTIONS="--oltp-table-size=$TABLE_SIZE \
  --max-time=$RUN_TIME \
  --max-requests=0 \
  --mysql-table-engine=InnoDB \
  --mysql-user=root \
  --mysql-engine-trx=yes"

PRODUCTS='MariaDB MySQL'

# Timeout in seconds for waiting for mysqld to start.
TIMEOUT=100

#
# Files
#
MARIADB_BUILD_LOG='/tmp/mariadb_build.log'
MYSQL_BUILD_LOG='/tmp/mysql_build.log'

#
# Directories.
#
BASE="${HOME}/work"
MARIADB_LOCAL_MASTER="${BASE}/monty_program/maria-local-master"
MARIADB_WORK="${BASE}/monty_program/maria"
MYSQL_LOCAL_MASTER="${BASE}/mysql/mysql-server-local-master"
MYSQL_WORK="${BASE}/mysql/mysql-server"
TEST_DIR="${BASE}/monty_program/sysbench/sysbench/tests/db"
RESULT_DIR="${BASE}/sysbench-results"

#
# Binaries.
#
MYSQLADMIN='./client/mysqladmin'
SYSBENCH='/usr/local/bin/sysbench'
BZR='/usr/local/bin/bzr'

#
# Refresh repositories.
#
echo "[$(date "+%Y-%m-%d %H:%M:%S")] Refreshing source repositories."
rm -rf $MARIADB_WORK
if [ ! -d $MARIADB_LOCAL_MASTER ]; then
    echo "[ERROR]: Local master of MariaDB does not exist."
    echo "  Please make a initial branch from lp:maria"
    echo "  Exiting."
    exit 1
else
    cd $MARIADB_LOCAL_MASTER
    echo "Pulling latest MariaDB sources."
    $BZR pull
    if [ $? != 0 ]; then
        echo "[ERROR]: $BZR pull for $MARIADB_LOCAL_MASTER failed"
        echo "  Please check your bzr setup"
        echo "  Exiting."
        exit 1
    fi
    
    echo "Branching MariaDB working directory."
    $BZR branch $MARIADB_LOCAL_MASTER $MARIADB_WORK
    if [ $? != 0 ]; then
        echo "[ERROR]: $BZR branch of $MARIADB_LOCAL_MASTER failed"
        echo "  Please check your bzr setup"
        echo "  Exiting."
        exit 1
    fi
fi

rm -rf $MYSQL_WORK
if [ ! -d $MYSQL_LOCAL_MASTER ]; then
    echo "[ERROR]: Local master of MySQL does not exist."
    echo "  Please make a initial branch from lp:mysql-server"
    echo "  Exiting."
    exit 1
else
    cd $MYSQL_LOCAL_MASTER
    echo "Pulling latest MySQL sources."
    $BZR pull
    if [ $? != 0 ]; then
        echo "[ERROR]: $BZR pull for $MYSQL_LOCAL_MASTER failed"
        echo "  Please check your bzr setup"
        echo "  Exiting."
        exit 1
    fi

    echo "Branching MySQL working directory."
    $BZR branch $MYSQL_LOCAL_MASTER $MYSQL_WORK
    if [ $? != 0 ]; then
        echo "[ERROR]: $BZR branch of $MYSQL_LOCAL_MASTER failed"
        echo "  Please check your bzr setup"
        echo "  Exiting."
        exit 1
    fi
fi

echo "[$(date "+%Y-%m-%d %H:%M:%S")] Done refreshing source repositories."


#
# TODO: Add platform detection and choose proper build script.
#
echo "[$(date "+%Y-%m-%d %H:%M:%S")] Starting to compile."

echo "[$(date "+%Y-%m-%d %H:%M:%S")] Compiling MariaDB."
cd $MARIADB_WORK
BUILD/compile-amd64-max > $MARIADB_BUILD_LOG 2>&1
if [ $? != 0 ]; then
    echo "[ERROR]: Build of $MARIADB_WORK failed"
    echo "  Please check the log at $MARIDB_BUILD_LOG"
    echo "  Exiting."
    exit 1
fi
echo "[$(date "+%Y-%m-%d %H:%M:%S")] Finnished compiling MariaDB."

echo "[$(date "+%Y-%m-%d %H:%M:%S")] Compiling MySQL."
cd $MYSQL_WORK
BUILD/compile-amd64-max > $MYSQL_BUILD_LOG 2>&1
if [ $? != 0 ]; then
    echo "[ERROR]: Build of $MYSQL_WORK failed"
    echo "  Please check the log at $MYSQL_BUILD_LOG"
    echo "  Exiting."
    exit 1
fi
echo "[$(date "+%Y-%m-%d %H:%M:%S")] Finnished compiling MySQL."
echo "[$(date "+%Y-%m-%d %H:%M:%S")] Finnished compiling."

#
# Go to work.
#
echo "[$(date "+%Y-%m-%d %H:%M:%S")] Starting sysbench runs."

#
# Prepare results directory.
#
if [ ! -d $RESULT_DIRS ]; then
    echo "[NOTE]: $RESULT_DIRS did not exist."
    echo "  We are creating it for you!"
    
    mkdir $RESULT_DIRS
fi

TODAY=$(date +%Y-%m-%d)
mkdir ${RESULT_DIR}/${TODAY}

for PRODUCT in $PRODUCTS; do
    mkdir ${RESULT_DIR}/${TODAY}/${PRODUCT}

    killall -9 mysqld
    rm -rf $DATA_DIR
    rm -f $MY_SOCKET
    mkdir $DATA_DIR

    if [ x"$PRODUCT" = x"MariaDB" ];then        
        cd $MARIADB_WORK
    else
        cd $MYSQL_WORK
    fi

    sql/mysqld $MYSQL_OPTIONS &
    
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
    
    for SYSBENCH_TEST in $SYSBENCH_TESTS; do
        mkdir ${RESULT_DIR}/${TODAY}/${PRODUCT}/${SYSBENCH_TEST}

        for THREADS in $NUM_THREADS; do
            THIS_RESULT_DIR="${RESULT_DIR}/${TODAY}/${PRODUCT}/${SYSBENCH_TEST}/${THREADS}"
            mkdir $THIS_RESULT_DIR
            echo "[$(date "+%Y-%m-%d %H:%M:%S")] Running $SYSBENCH_TEST with $THREADS threads for $PRODUCT"

            $MYSQLADMIN $MYSQLADMIN_OPTIONS -f drop sbtest
            $MYSQLADMIN $MYSQLADMIN_OPTIONS create sbtest
            if [ $? != 0 ]; then
                echo "[ERROR]: Create of sbtest database failed"
                echo "  Please check your setup."
                echo "  Exiting"
                exit 1
            fi

            SYSBENCH_OPTIONS="$SYSBENCH_OPTIONS --num-threads=$THREADS --test=${TEST_DIR}/${SYSBENCH_TEST}"
            $SYSBENCH $SYSBENCH_OPTIONS prepare
            $SYSBENCH $SYSBENCH_OPTIONS run > ${THIS_RESULT_DIR}/result.txt 2>&1

        done
    done
done

#
# We are done!
#
echo "[$(date "+%Y-%m-%d %H:%M:%S")] Finished sysbench runs."
echo "  You can check your results."
