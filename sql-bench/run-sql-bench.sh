#!/bin/bash
#
# Run sql-bench for every given configuration file
# we find in the directory $SQL_BENCH_CONFIGS.
#
# Note: Do not run this script with root privileges.
#   We use killall -9, which can cause severe side effects!
#
# Hakan Kuecuekyilmaz <hakan at askmonty dot org> 2009-12-05.
#

if [ $# != 2 ]; then
    echo '[ERROR]: Please provide exactly two options.'
    echo "  Example: $0 [/path/to/bzr/repository] [name_without_spaces]"
    echo '  [name_without_spaces] is used as identifier in the result file.'
    
    exit 1
else
    REPOSITORY="$1"
    REPOSITORY_NAME="$2"
fi

#
# Directories.
#
SQL_BENCH_CONFIGS='/home/hakan/sql-bench-configurations'
SQL_BENCH_RESULTS='/home/hakan/sql-bench-results'
WORK_DIR='/tmp'

#
# Variables.
#
# We need at least 1 GB disk space in our $WORK_DIR.
SPACE_LIMIT=1000000
MYSQLADMIN_OPTIONS='--no-defaults'
MACHINE=$(hostname -s)
RUN_DATE=$(date +%Y-%m-%d)

# Timeout in seconds for waiting for mysqld to start.
TIMEOUT=100

#
# Binaries.
#
BZR='/usr/local/bin/bzr'
MYSQLADMIN='client/mysqladmin'

#
# Check system.
#
# We should at least have $SPACE_LIMIT in $WORKDIR.
AVAILABLE=$(df $WORK_DIR | grep -v Filesystem | awk '{ print $4 }')

if [ $AVAILABLE -lt $SPACE_LIMIT ]; then
    echo "[ERROR]: We need at least $ONE_GB space in $WORK_DIR."
    echo 'Exiting.'
    
    exit 1
fi

#
# Run sql-bench.
#
for i in ${SQL_BENCH_CONFIGS}/*.inc
    do
    # Set configuration and check that all required parameters are set.
    source $i

    if [ x"$MARIADB_CONFIG" == x"" ]; then
        echo '[ERROR]: $MARIADB_CONFIG is not set.'
        echo 'Exiting.'
        
        exit 1
    fi

    if [ x"$SQLBENCH_OPTIONS" == x"" ]; then
        echo '[ERROR]: $SQLBENCH_OPTIONS is not set.'
        echo 'Exiting.'
        
        exit 1
    fi

    if [ x"$MARIADB_OPTIONS" == x"" ]; then
        echo '[ERROR]: $MARIADB_OPTIONS is not set.'
        echo 'Exiting.'
        
        exit 1
    fi

    # Check out and compile.
    REVISION_ID=$($BZR version-info $REPOSITORY | grep revision-id)
    if [ $? != 0 ]; then
        echo '[ERROR]: bzr version-info failed. Please provide'
        echo '  a working bzr repository'
        echo 'Exiting.'

        exit 1
    fi
    
    cd $WORK_DIR
    # Clean up of previous runs
    killall -9 mysqld

    TEMP_DIR=$(mktemp --directory)
    if [ $? != 0 ]; then
        echo "[ERROR]: mktemp in $WORK_DIR failed."
        echo 'Exiting.'

        exit 1
    fi

    # bzr export refuses to export to an existing directory,
    # therefore we use a build directory.
    echo "Branching from $REPOSITORY to ${TEMP_DIR}/build"

    $BZR export --format=dir ${TEMP_DIR}/build $REPOSITORY
    if [ $? != 0 ]; then
        echo '[ERROR]: bzr export failed.'
        echo 'Exiting.'

        exit 1
    fi

    cd ${TEMP_DIR}/build
    BUILD/autorun.sh
    if [ $? != 0 ]; then
        echo '[ERROR]: BUILD/autorun.sh failed.'
        echo '  Please check your development environment.'
        echo 'Exiting.'

        exit 1
    fi

    ./configure $MARIADB_CONFIG
    if [ $? != 0 ]; then
        echo "[ERROR]: ./configure $MARIADB_CONFIG failed."
        echo "  Please check your MARIADB_CONFIG in $i."
        echo 'Exiting.'

        exit 1
    fi
    
    make -j4
    if [ $? != 0 ]; then
        echo '[ERROR]: make failed.'
        echo '  Please check your build logs.'
        echo 'Exiting.'

        exit 1
    fi

    # Start mysqld.
    MARIADB_SOCKET="${TEMP_DIR}/mysql.sock"
    MARIADB_OPTIONS="$MARIADB_OPTIONS \
      --datadir=$TEMP_DIR \
      --tmpdir=$TEMP_DIR \
      --socket=$MARIADB_SOCKET"

    MYSQLADMIN_OPTIONS="$MYSQLADMIN_OPTIONS \
      --socket=$MARIADB_SOCKET"

    sql/mysqld $MARIADB_OPTIONS &

    j=0
    STARTED=-1
    while [ $j -le $TIMEOUT ]
        do
        $MYSQLADMIN $MYSQLADMIN_OPTIONS -uroot ping > /dev/null 2>&1
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
        echo 'Exiting.'

        exit 1
    fi

    $MYSQLADMIN $MYSQLADMIN_OPTIONS create test
    if [ $? != 0 ]; then
        echo '[ERROR]: Create schema test failed.'
        echo '  Please check your mysqld error log.'
        echo 'Exiting.'

        exit 1
    fi

    # Run sql-bench.
    cd sql-bench
    COMMENTS="Revision used: $REVISION_ID \
      Configure: $MARIADB_CONFIG \
      Server options: $MARIADB_OPTIONS"

    # TODO: Adding --comments="$COMMENTS" does not work
    SQLBENCH_OPTIONS="$SQLBENCH_OPTIONS \
      --socket=$MARIADB_SOCKET"

    ./run-all-tests $SQLBENCH_OPTIONS
    if [ $? != 0 ]; then
        echo '[ERROR]: run-all-tests produced errors.'
        echo '  Please check your sql-bench error logs.'
        echo 'Exiting.'

        exit 1
    fi
    
    # Save result file for later usage and comparison.
    RESULT_FILE=$(ls output/RUN-*)
    if [ x"$RESULT_FILE" != x"" ]; then
        NEW_FILE_NAME="RUN-${REPOSITORY_NAME}-$(basename $RESULT_FILE | awk -F 'RUN-' '{ print $2 }')"

        CONFIGURATION=$(basename "$i" | awk -F . '{ print $1 }')
        ARCHIVE_DIR="${SQL_BENCH_RESULTS}/${MACHINE}/${RUN_DATE}/${CONFIGURATION}"
        mkdir -p $ARCHIVE_DIR
        
        # Add comment to result file.
        sed -e "s%Comments:%Comments:            ${COMMENTS}%" $RESULT_FILE > foo.tmp
        mv foo.tmp $RESULT_FILE
        # TODO: check for failures and copy the logs in question.
        cp $RESULT_FILE ${ARCHIVE_DIR}/$NEW_FILE_NAME
        
        # Clean up for next round.
        rm -rf $TEMP_DIR
    else
        echo '[ERROR]: Cannot find result file after sql-bench run!'
    fi

done
