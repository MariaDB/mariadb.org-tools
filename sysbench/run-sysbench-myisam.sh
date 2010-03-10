#!/bin/bash
#
# Run sysbench tests with MariaDB and MySQL
#
# Notes:
#   * Do not run this script with root privileges. We use
#   killall -9, which can cause severe side effects!
#   * By bzr pull we mean bzr merge --pull
#
# Index sizes for 20 mio rows (--table-size=20000000).
#   * delete.lua:           313M  sbtest.MYI
#   * insert.lua:           4.0K  sbtest.MYI
#   * oltp_complex_ro.lua:  313M  sbtest.MYI
#   * oltp_complex_rw.lua:  313M  sbtest.MYI
#   * oltp_simple.lua:      325M  sbtest.MYI
#   * select.lua:           313M  sbtest.MYI
#   * update_index.lua:     313M  sbtest.MYI
#   * update_non_index.lua: 313M  sbtest.MYI
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
  --key_buffer_size=32M \
  --max_connections=256 \
  --query_cache_size=0 \
  --query_cache_type=0 \
  --skip-grant-tables \
  --socket=$MY_SOCKET \
  --table_open_cache=512 \
  --thread_cache=512 \
  --tmpdir=$TEMP_DIR"
#  --key_cache_partitions=7 \

# Number of threads we run sysbench with.
NUM_THREADS="1 4 8 16 32 64 128"

# The table size we use for sysbench.
TABLE_SIZE=20000000

# The run time we use for sysbench.
RUN_TIME=300

# Warm up time we use for sysbench.
WARM_UP_TIME=180

# How many times we run each test.
LOOP_COUNT=3

# We need at least 1 GB disk space in our $WORK_DIR.
SPACE_LIMIT=1000000

SYSBENCH_TESTS="delete.lua \
  insert.lua \
  oltp_complex_ro.lua \
  oltp_complex_rw.lua \
  oltp_simple.lua \
  select.lua \
  update_index.lua \
  update_non_index.lua"

#
# Note: myisam-max-rows has to match or exceed oltp-table-size
#   otherwise we get a table full error while preparing the run.
#
SYSBENCH_OPTIONS="--oltp-table-size=$TABLE_SIZE \
  --max-requests=0 \
  --mysql-table-engine=MyISAM \
  --mysql-user=root \
  --mysql-engine-trx=no \
  --myisam-max-rows=50000000 \
  --rand-seed=303"

# Timeout in seconds for waiting for mysqld to start.
TIMEOUT=100

#
# Directories.
#
BASE="${HOME}/work"
TEST_DIR="${BASE}/monty_program/sysbench/sysbench/tests/db"
RESULT_DIR="${BASE}/sysbench-results"
SYSBENCH_DB_BACKUP="${TEMP_DIR}/sysbench_db"

#
# Files
#
BUILD_LOG="${WORK_DIR}/${PRODUCT}_build.log"

#
# Check system.
#
# We should at least have $SPACE_LIMIT in $WORKDIR.
AVAILABLE=$(df $WORK_DIR | grep -v Filesystem | awk '{ print $4 }')

if [ $AVAILABLE -lt $SPACE_LIMIT ]; then
    echo "[ERROR]: We need at least $SPACE_LIMIT space in $WORK_DIR."
    echo 'Exiting.'
    
    exit 1
fi

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

function kill_mysqld {
    killall -9 mysqld
    rm -rf $DATA_DIR
    rm -f $MY_SOCKET
    mkdir $DATA_DIR
}

function start_mysqld {
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
}

#
# Write out configurations used for future refernce.
#
echo $MYSQL_OPTIONS > ${RESULT_DIR}/${TODAY}/${PRODUCT}/mysqld_options.txt
echo $SYSBENCH_OPTIONS > ${RESULT_DIR}/${TODAY}/${PRODUCT}/sysbench_options.txt
echo '' >> ${RESULT_DIR}/${TODAY}/${PRODUCT}/sysbench_options.txt
echo "Warm up time is: $WARM_UP_TIME" >> ${RESULT_DIR}/${TODAY}/${PRODUCT}/sysbench_options.txt
echo "Run time is: $RUN_TIME" >> ${RESULT_DIR}/${TODAY}/${PRODUCT}/sysbench_options.txt

for SYSBENCH_TEST in $SYSBENCH_TESTS
    do
    mkdir ${RESULT_DIR}/${TODAY}/${PRODUCT}/${SYSBENCH_TEST}

    kill_mysqld
    start_mysqld
    $MYSQLADMIN $MYSQLADMIN_OPTIONS create sbtest
    if [ $? != 0 ]; then
        echo "[ERROR]: Create of sbtest database failed"
        echo "  Please check your setup."
        echo "  Exiting"
        exit 1
    fi

    echo "[$(date "+%Y-%m-%d %H:%M:%S")] Preparing and loading data for $SYSBENCH_TEST."
    SYSBENCH_OPTIONS="${SYSBENCH_OPTIONS} --test=${TEST_DIR}/${SYSBENCH_TEST}"
    $SYSBENCH $SYSBENCH_OPTIONS --max-time=$RUN_TIME prepare
    
    $MYSQLADMIN $MYSQLADMIN_OPTIONS shutdown
    sync
    rm -rf ${SYSBENCH_DB_BACKUP}
    mkdir ${SYSBENCH_DB_BACKUP}
    
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] Copying $DATA_DIR of $SYSBENCH_TEST for later usage."
    cp -a ${DATA_DIR}/* ${SYSBENCH_DB_BACKUP}/

    for THREADS in $NUM_THREADS
        do
        THIS_RESULT_DIR="${RESULT_DIR}/${TODAY}/${PRODUCT}/${SYSBENCH_TEST}/${THREADS}"
        mkdir $THIS_RESULT_DIR
        echo "[$(date "+%Y-%m-%d %H:%M:%S")] Running $SYSBENCH_TEST with $THREADS threads and $LOOP_COUNT iterations for $PRODUCT" | tee ${THIS_RESULT_DIR}/results.txt
        echo '' >> ${THIS_RESULT_DIR}/results.txt

        SYSBENCH_OPTIONS_WARM_UP="${SYSBENCH_OPTIONS} --num-threads=1 --max-time=$WARM_UP_TIME"
        SYSBENCH_OPTIONS_RUN="${SYSBENCH_OPTIONS} --num-threads=$THREADS --max-time=$RUN_TIME"

        k=0
        while [ $k -lt $LOOP_COUNT ]
            do
            echo ''
            echo "[$(date "+%Y-%m-%d %H:%M:%S")] Killing mysqld and copying back $DATA_DIR for $SYSBENCH_TEST."
            kill_mysqld
            cp -a ${SYSBENCH_DB_BACKUP}/* ${DATA_DIR}
            
            # Clear file system cache. This works only with Linux >= 2.6.16.
            # On Mac OS X we can use sync; purge.
            sync
            echo 3 | $SUDO tee /proc/sys/vm/drop_caches

            echo "[$(date "+%Y-%m-%d %H:%M:%S")] Starting mysqld for running $SYSBENCH_TEST with $THREADS threads and $LOOP_COUNT iterations for $PRODUCT"
            start_mysqld
            sync

            echo "[$(date "+%Y-%m-%d %H:%M:%S")] Starting warm up of $WARM_UP_TIME seconds."
            $SYSBENCH $SYSBENCH_OPTIONS_WARM_UP run
            sync
            echo "[$(date "+%Y-%m-%d %H:%M:%S")] Finnished warm up."

            echo "[$(date "+%Y-%m-%d %H:%M:%S")] Starting actual sysbench run."
            $SYSBENCH $SYSBENCH_OPTIONS_RUN run > ${THIS_RESULT_DIR}/result${k}.txt 2>&1
            
            grep "write requests:" ${THIS_RESULT_DIR}/result${k}.txt | awk '{ print $4 }' | sed -e 's/(//' >> ${THIS_RESULT_DIR}/results.txt

            k=$(($k + 1))
        done
        
        echo '' >> ${THIS_RESULT_DIR}/results.txt
        echo "[$(date "+%Y-%m-%d %H:%M:%S")] Finnished $SYSBENCH_TEST with $THREADS threads and $LOOP_COUNT iterations for $PRODUCT" | tee -a ${THIS_RESULT_DIR}/results.txt
    done
done

#
# We are done!
#
echo "[$(date "+%Y-%m-%d %H:%M:%S")] Finished sysbench runs."
echo "  You can check your results."
