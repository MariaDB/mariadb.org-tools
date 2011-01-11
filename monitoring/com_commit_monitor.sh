#!/bin/bash
#
# Simple COM_COMMIT monitor
#
# Hakan Kuecuekyilmaz, <hakan at askmonty dot org>, 2010-12-16.

if [ $# != 2 ]; then
    echo "[ERROR]: Please use exactly two arguments"
    echo "  Usage: $0 [time interval] [absolute | delta]"
    echo "  Example: $0 10 delta"

    exit 1
else
    INTERVALL="$1"
    MODE="$2"
fi

# Adjust this patch to match your path to the mysql client.
MYSQL="/usr/local/mysql/bin/mysql"

COMMIT_COUNT_QUERY="SELECT VARIABLE_VALUE FROM INFORMATION_SCHEMA.GLOBAL_STATUS WHERE VARIABLE_NAME = 'COM_COMMIT'"
PROCESSES_COUNT_QUERY="SELECT count(*) FROM INFORMATION_SCHEMA.PROCESSLIST"

while true
    do
    DATE=$(date +%s)
    PROCESSES_COUNT=$(echo $PROCESSES_COUNT_QUERY | $MYSQL -uroot --column-names=false)
    COMMIT_COUNT=$(echo $COMMIT_COUNT_QUERY | $MYSQL -uroot --column-names=false)

    sleep $INTERVALL

    if [  x"$MODE" = x"absolute" ]; then
        echo "$DATE $PROCESSES_COUNT $COMMIT_COUNT"
    else
        DATE=$(date +%s)

        COMMIT_COUNT2=$(echo $COMMIT_COUNT_QUERY | $MYSQL -uroot --column-names=false)
        DELTA=$(($COMMIT_COUNT2 - $COMMIT_COUNT))

        echo "$DATE $PROCESSES_COUNT $DELTA"
    fi
done
