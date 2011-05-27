#!/bin/bash
#
# Run SysBench tests with MariaDB and MySQL
#
# Notes:
#   * Do not run this script with root privileges. We use
#   killall -9, which can cause severe side effects!
#   * By bzr pull we mean bzr merge --pull
#   * For reasonable performance set your IO scheduler to noop or deadline, for
#   reference please check
#   http://www.mysqlperformanceblog.com/2009/01/30/linux-schedulers-in-tpcc-like-benchmark/
#
# For proper work we need these two commands to be run via sudo
# with no password. Example:
#   hakan ALL=NOPASSWD: /usr/bin/opcontrol
#   hakan ALL=NOPASSWD: /usr/bin/tee /proc/sys/vm/drop_caches
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
    echo "[ERROR]: Could not find config file: conf/${HOSTNAME}.inc."
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
MYSQLD_OPTIONS="--no-defaults \
  --datadir=$DATA_DIR \
  --language=./sql/share/english \
  --log-error \
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

# Number of threads we run SysBench with.
NUM_THREADS="1 4 8 16 32 64 128"

# The table size we use for SysBench.
TABLE_SIZE=2000000

# The run time we use for SysBench.
RUN_TIME=1200

# Warm up time we use for SysBench.
WARM_UP_TIME=300

# How many times we run each test.
LOOP_COUNT=3

# We need at least 1 GB disk space in our $WORK_DIR.
SPACE_LIMIT=1000000

# Interval in seconds for monitoring system status like disk IO,
# CPU utilization, and such.
MONITOR_INTERVAL=10

SYSBENCH_OPTIONS="--oltp-table-size=$TABLE_SIZE \
  --max-requests=0 \
  --mysql-table-engine=InnoDB \
  --mysql-user=root \
  --mysql-engine-trx=yes \
  --rand-seed=303"

# Timeout in seconds for waiting for mysqld to start.
TIMEOUT=100

#
# Directories.
# ${BASE} and ${TEMP_DIR} are defined in the $HOSTNAME.inc configuration file.
#
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

# Location of our mysqld binary.
MYSQLD_BINARY="${TEMP_DIR}/build/sql/mysqld"

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
echo "[$(date "+%Y-%m-%d %H:%M:%S")] Starting SysBench runs."

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
    sql/mysqld $MYSQLD_OPTIONS &

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
# Write out configurations used for future reference.
#
echo $MYSQLD_OPTIONS > ${RESULT_DIR}/${TODAY}/${PRODUCT}/mysqld_options.txt
echo $SYSBENCH_OPTIONS > ${RESULT_DIR}/${TODAY}/${PRODUCT}/sysbench_options.txt
echo '' >> ${RESULT_DIR}/${TODAY}/${PRODUCT}/sysbench_options.txt
echo "Warm up time is: $WARM_UP_TIME" >> ${RESULT_DIR}/${TODAY}/${PRODUCT}/sysbench_options.txt
echo "Run time is: $RUN_TIME" >> ${RESULT_DIR}/${TODAY}/${PRODUCT}/sysbench_options.txt

#
# Clean up possibly left over monitoring processes.
#
killall -9 iostat
killall -9 mpstat
killall -9 mysqladmin
$SUDO opcontrol --stop
$SUDO opcontrol --deinit
$SUDO opcontrol --reset

for (( i = 0 ; i < ${#SYSBENCH_TESTS[@]} ; i++ ))
    do
    # Get rid of any options of given SysBench test.
    SYSBENCH_TEST=$(echo "${SYSBENCH_TESTS[$i]}" | awk '{ print $1 }')

    # If we run the same SysBench test with different options,
    # then we have to take care to not overwrite our previous results.
    m=0
    DIR_CREATED=-1
    MKDIR_RETRY=512
    DIR_TO_CREATE="${RESULT_DIR}/${TODAY}/${PRODUCT}/${SYSBENCH_TEST}"

    if [ ! -d $DIR_TO_CREATE ]; then
        mkdir $DIR_TO_CREATE
        CURRENT_RESULT_DIR="$DIR_TO_CREATE"
    else 
        while [ $m -le $MKDIR_RETRY ]
            do
            if [ ! -d ${DIR_TO_CREATE}-${m} ]; then
                mkdir ${DIR_TO_CREATE}-${m}
                CURRENT_RESULT_DIR="${DIR_TO_CREATE}-${m}"
                DIR_CREATED=1

                break
            fi

            m=$(($m + 1))
        done

        if [ $DIR_CREATED = -1 ]; then
            echo "[ERROR]: Could not create result dir after $MKDIR_RETRY times."
            echo '  Please check your configuration and file system.'
            echo '  Refusing to overwrite existing results. Exiting!'

            exit 1
        fi
    fi

    kill_mysqld
    start_mysqld
    $MYSQLADMIN $MYSQLADMIN_OPTIONS create sbtest
    if [ $? != 0 ]; then
        echo "[ERROR]: Create of sbtest database failed"
        echo "  Please check your setup."
        echo "  Exiting"
        exit 1
    fi

    echo "[$(date "+%Y-%m-%d %H:%M:%S")] Preparing and loading data for ${SYSBENCH_TESTS[$i]}."
    SYSBENCH_OPTIONS="${SYSBENCH_OPTIONS} --test=${TEST_DIR}/${SYSBENCH_TESTS[$i]}"
    $SYSBENCH $SYSBENCH_OPTIONS --max-time=$RUN_TIME prepare

    $MYSQLADMIN $MYSQLADMIN_OPTIONS shutdown
    sync
    rm -rf ${SYSBENCH_DB_BACKUP}
    mkdir ${SYSBENCH_DB_BACKUP}

    echo "[$(date "+%Y-%m-%d %H:%M:%S")] Copying $DATA_DIR of ${SYSBENCH_TESTS[$i]} for later usage."
    cp -a ${DATA_DIR}/* ${SYSBENCH_DB_BACKUP}/

    for THREADS in $NUM_THREADS
        do
        THIS_RESULT_DIR="${CURRENT_RESULT_DIR}/${THREADS}"
        mkdir $THIS_RESULT_DIR
        echo "[$(date "+%Y-%m-%d %H:%M:%S")] Running ${SYSBENCH_TESTS[$i]} with $THREADS threads and $LOOP_COUNT iterations for $PRODUCT" | tee ${THIS_RESULT_DIR}/results.txt
        echo '' >> ${THIS_RESULT_DIR}/results.txt

        SYSBENCH_OPTIONS_WARM_UP="${SYSBENCH_OPTIONS} --num-threads=3 --max-time=$WARM_UP_TIME"
        SYSBENCH_OPTIONS_RUN="${SYSBENCH_OPTIONS} --num-threads=$THREADS --max-time=$RUN_TIME"

        # Check whether we want a profiled run.
        PROFILE_IT=-1
        for l in $DO_OPROFILE
            do
            if [ x"$l" = x"$THREADS" ]; then
                PROFILE_IT=1
                break
            fi
        done

        k=0
        while [ $k -lt $LOOP_COUNT ]
            do
            echo ''
            echo "[$(date "+%Y-%m-%d %H:%M:%S")] Killing mysqld and copying back $DATA_DIR for ${SYSBENCH_TESTS[$i]}."
            kill_mysqld
            cp -a ${SYSBENCH_DB_BACKUP}/* ${DATA_DIR}

            # Clear file system cache. This works only with Linux >= 2.6.16.
            # On Mac OS X we can use sync; purge.
            sync
            echo 3 | $SUDO tee /proc/sys/vm/drop_caches

            echo "[$(date "+%Y-%m-%d %H:%M:%S")] Starting mysqld for running ${SYSBENCH_TESTS[$i]} with $THREADS threads and $LOOP_COUNT iterations for $PRODUCT"
            start_mysqld
            sync

            echo ""
            echo "[$(date "+%Y-%m-%d %H:%M:%S")] Starting warm up of $WARM_UP_TIME seconds."
            $SYSBENCH $SYSBENCH_OPTIONS_WARM_UP run
            sync
            echo "[$(date "+%Y-%m-%d %H:%M:%S")] Finnished warm up."

            echo "[$(date "+%Y-%m-%d %H:%M:%S")] Starting actual SysBench run."

            $IOSTAT -d -k $IOSTAT_DEVICE $MONITOR_INTERVAL > ${THIS_RESULT_DIR}/iostat${k}.txt 2>&1 &
            IOSTAT_PID=$!

            $MPSTAT -u $MONITOR_INTERVAL > ${THIS_RESULT_DIR}/cpustat${k}.txt 2>&1 &
            MPSTAT_PID=$!

            $MYSQLADMIN $MYSQLADMIN_OPTIONS --sleep $MONITOR_INTERVAL status > ${THIS_RESULT_DIR}/server_status${k}.txt 2>&1 &
            SERVER_STATUS_PID=$!

            if [ $PROFILE_IT -eq 1 ]; then
                $SUDO opcontrol --setup --no-vmlinux --separate=lib,kernel,thread
                $SUDO opcontrol --start-daemon
                if [ $? != 0 ]; then
                    echo "[WARNING]: Could not start oprofile daemonl."
                    echo "  Please check your OProfile installation."
                fi

                $SUDO opcontrol --start
                echo "[$(date "+%Y-%m-%d %H:%M:%S")] This is an OProfile'd SysBench run."
            fi

            $SYSBENCH $SYSBENCH_OPTIONS_RUN run > ${THIS_RESULT_DIR}/result${k}.txt 2>&1

            if [ $PROFILE_IT -eq 1 ]; then
                PROFILE_IT=-1
                $SUDO opcontrol --dump
                $SUDO opcontrol --stop

                opreport --demangle=smart --threshold 0.5 --symbols --long-filenames --merge tgid $MYSQLD_BINARY > ${THIS_RESULT_DIR}/oprofile${k}.txt 2>&1

                $SUDO opcontrol --deinit
                $SUDO opcontrol --reset
            fi

            # Copy mysqld error log for future reference.
            # TODO: add chrash detection.
            cp ${DATA_DIR}/${HOSTNAME}.err ${THIS_RESULT_DIR}/${HOSTNAME}${k}.err

            sync; sync; sync
            sleep 1

            grep "write requests:" ${THIS_RESULT_DIR}/result${k}.txt | awk '{ print $4 }' | sed -e 's/(//' >> ${THIS_RESULT_DIR}/results.txt

            kill -9 $IOSTAT_PID
            kill -9 $MPSTAT_PID
            kill -9 $SERVER_STATUS_PID

            k=$(($k + 1))
        done

        echo '' >> ${THIS_RESULT_DIR}/results.txt
        echo "[$(date "+%Y-%m-%d %H:%M:%S")] Finnished ${SYSBENCH_TESTS[$i]} with $THREADS threads and $LOOP_COUNT iterations for $PRODUCT" | tee -a ${THIS_RESULT_DIR}/results.txt
    done
done

#
# We are done!
#
echo "[$(date "+%Y-%m-%d %H:%M:%S")] Finished SysBench runs."
echo "  You can check your results."
