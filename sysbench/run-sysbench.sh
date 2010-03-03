#!/bin/bash
#
# Run sysbench tests with MariaDB and MySQL
#
# Notes:
#   * Do not run this script with root privileges. We use
#   killall -9, which can cause severe side effects!
#   * By bzr pull we mean bzr merge --pull
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

if [ $# != 3 ]; then
    echo '[ERROR]: Please provide exactly three options.'
    echo "  Example: $0 [pull | no-pull] [/path/to/bzr/repo] [name]"
    echo "  $0 pull ${HOME}/work/monty_program/maria-local-master MariaDB"
    
    exit 1
else
    PULL="$1"
    LOCAL_MASTER="$2"
    PRODUCT="$3"
fi

#
# Read system dependent settings.
#
if [ ! -f conf/${HOSTNAME}.inc ]; then
    echo "[ERROR]: Could not find config file: conf/${HOSTNAME}.conf."
    echo "  Please create one."
    
    exit 1
else
    source conf/${HOSTNAME}.inc
fi

#
# Binaries used after building from source. You do not have to
# change these, except you exactly know what you are doing.
#
MYSQLADMIN='client/mysqladmin'

#
# Variables.
#
MY_SOCKET="/tmp/mysql.sock"
MYSQLADMIN_OPTIONS="--no-defaults -uroot --socket=$MY_SOCKET"
MYSQL_OPTIONS="--no-defaults \
  --datadir=$DATA_DIR \
  --language=./sql/share/english \
  --max_connections=256 \
  --query_cache_size=0 \
  --query_cache_type=0 \
  --skip-grant-tables \
  --socket=$MY_SOCKET \
  --table_open_cache=512 \
  --thread_cache=512 \
  --tmpdir=$TEMP_DIR \
  --innodb_additional_mem_pool_size=32M \
  --innodb_buffer_pool_size=1024M \
  --innodb_data_file_path=ibdata1:32M:autoextend \
  --innodb_data_home_dir=$DATA_DIR \
  --innodb_doublewrite=0 \
  --innodb_flush_log_at_trx_commit=1 \
  --innodb_flush_method=O_DIRECT \
  --innodb_lock_wait_timeout=50 \
  --innodb_log_buffer_size=16M \
  --innodb_log_file_size=256M \
  --innodb_log_group_home_dir=$DATA_DIR \
  --innodb_max_dirty_pages_pct=80 \
  --innodb_thread_concurrency=0"

# Number of threads we run sysbench with.
NUM_THREADS="1 4 8 16 32 64 128"

# The table size we use for sysbench.
TABLE_SIZE=2000000

# The run time we use for sysbench.
RUN_TIME=300

# How many times we run each test.
LOOP_COUNT=3

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

# Timeout in seconds for waiting for mysqld to start.
TIMEOUT=100

#
# Files
#
BUILD_LOG="/tmp/${PRODUCT}_build.log"

#
# Directories.
#
BASE="${HOME}/work"
TEST_DIR="${BASE}/monty_program/sysbench/sysbench/tests/db"
RESULT_DIR="${BASE}/sysbench-results"
WORK_DIR='/tmp'

if [ ! -d $LOCAL_MASTER ]; then
    echo "[ERROR]: Supplied local master $LOCAL_MASTER does not exists."
    echo "  Please provide a valid bzr repository."
    echo "  Exiting."
    exit 1
fi

#
# Refresh repositories, if requested.
#
if [ x"$PULL" = x"pull" ]; then
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] Refreshing source repositories."

    cd $LOCAL_MASTER
    echo "Pulling latest MariaDB sources."
    $BZR merge --pull
    if [ $? != 0 ]; then
        echo "[ERROR]: $BZR pull for $LOCAL_MASTER failed"
        echo "  Please check your bzr setup and/or repository"
        echo "  Exiting."
        exit 1
    fi

    echo "[$(date "+%Y-%m-%d %H:%M:%S")] Done refreshing source repositories."
fi        

cd $WORK_DIR
TEMP_DIR=$(mktemp -d)
if [ $? != 0 ]; then
    echo "[ERROR]: mktemp in $WORK_DIR failed."
    echo 'Exiting.'

    exit 1
fi

#
# bzr export refuses to export to an existing directory,
# therefore we use an extra build/ directory.
#
echo "Exporting from $LOCAL_MASTER to ${TEMP_DIR}/build"
$BZR export --format=dir ${TEMP_DIR}/build $LOCAL_MASTER
if [ $? != 0 ]; then
    echo '[ERROR]: bzr export failed.'
    echo 'Exiting.'

    exit 1
fi

#
# Compile sources.
# TODO: Add platform detection and choose proper build script accordingly.
#
echo "[$(date "+%Y-%m-%d %H:%M:%S")] Starting to compile $PRODUCT."

cd ${TEMP_DIR}/build
BUILD/compile-amd64-max > $BUILD_LOG 2>&1
if [ $? != 0 ]; then
    echo "[ERROR]: Build of $PRODUCT failed"
    echo "  Please check your log at $BUILD_LOG"
    echo "  Exiting."
    exit 1
fi

echo "[$(date "+%Y-%m-%d %H:%M:%S")] Finnished compiling $PRODUCT."

#
# Go to work.
#
echo "[$(date "+%Y-%m-%d %H:%M:%S")] Starting sysbench runs."

#
# Prepare results directory.
#
if [ ! -d $RESULT_DIR ]; then
    echo "[NOTE]: $RESULT_DIR did not exist."
    echo "  We are creating it for you!"
    
    mkdir $RESULT_DIR
fi

TODAY=$(date +%Y-%m-%d)
mkdir ${RESULT_DIR}/${TODAY}
mkdir ${RESULT_DIR}/${TODAY}/${PRODUCT}

killall -9 mysqld
rm -rf $DATA_DIR
rm -f $MY_SOCKET
mkdir $DATA_DIR

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

for SYSBENCH_TEST in $SYSBENCH_TESTS
    do
    mkdir ${RESULT_DIR}/${TODAY}/${PRODUCT}/${SYSBENCH_TEST}

    for THREADS in $NUM_THREADS
        do
        THIS_RESULT_DIR="${RESULT_DIR}/${TODAY}/${PRODUCT}/${SYSBENCH_TEST}/${THREADS}"
        mkdir $THIS_RESULT_DIR
        echo "[$(date "+%Y-%m-%d %H:%M:%S")] Running $SYSBENCH_TEST with $THREADS threads and $LOOP_COUNT iterations for $PRODUCT" | tee ${THIS_RESULT_DIR}/results.txt
        echo '' >> ${THIS_RESULT_DIR}/results.txt

        k=0
        while [ $k -lt $LOOP_COUNT ]
            do
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

            sync
            sleep 3

            $SYSBENCH $SYSBENCH_OPTIONS run > ${THIS_RESULT_DIR}/result${k}.txt 2>&1
            
            grep "write requests:" ${THIS_RESULT_DIR}/result${k}.txt | awk '{ print $4 }' | sed -e 's/(//' >> ${THIS_RESULT_DIR}/results.txt

            k=$(($k + 1))
        done
    done
done

#
# We are done!
#
echo "[$(date "+%Y-%m-%d %H:%M:%S")] Finished sysbench runs."
echo "  You can check your results."
