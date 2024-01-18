#!/bin/bash
set -x -v
host=$1
shift
db=$1
shift
user=$1
shift
password=$1

while true
do

	code=A$((1000 + RANDOM % 1000))
	qty=$((1 + RANDOM % 10))
	value=$(( RANDOM % 100 )).$(( RANDOM % 100))
	echo "INSERT INTO sales(code, quantity, value) VALUES ('$code', $qty, $value);"
	sleep 1
done | MYSQL_PWD="$password" mariadb --host "$host" --user "$user" "$db"
