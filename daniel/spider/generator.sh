#!/bin/bash
set -x -v
if [ -n "$MARIADB_HOST" ]; then
  host=$MARIADB_HOST
else
  host=db-euus-${POP,,}-0
fi
db=$MARIADB_DATABASE
user=$MARIADB_USER
password=$MARIADB_PASSWORD

while true
do

	code=A$((1000 + RANDOM % 1000))
	qty=$((1 + RANDOM % 10))
	value=$(( RANDOM % 100 )).$(( RANDOM % 100))
	echo "INSERT INTO sales(code, quantity, value) VALUES ('$code', $qty, $value);"
	sleep 1
done | MYSQL_PWD="$password" mariadb --host "$host" --user "$user" "$db"
