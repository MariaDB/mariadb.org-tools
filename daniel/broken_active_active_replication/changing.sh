#!/bin/bash

MARIADB_USER=testuser
MARIADB_PASSWORD=password
MARIADB_DATABASE=testdb

db=$MARIADB_DATABASE
user=$MARIADB_USER
password=$MARIADB_PASSWORD
delay=0
set -x -v

while true
do

	port=$(( RANDOM % 2 + 3307))
	id=$((RANDOM % 6 + 1))
	value=$(( RANDOM % 100 )).$(( RANDOM % 100))
	MYSQL_PWD="$password" mariadb --host 127.0.0.1 --port 3308 --user "$user" "$db" -e "UPDATE tbl SET val='$value' WHERE id=$id;"
	sleep $delay
done &
#| MYSQL_PWD="$password" mariadb --host 127.0.0.1 --port $port --user "$user" "$db"

while true
do
	port=$(( RANDOM % 2 + 3307))
	id=$((RANDOM % 6 + 1))
	MYSQL_PWD="$password" mariadb --host 127.0.0.1 --port $port --user "$user" "$db" -e "DELETE FROM tbl WHERE id=$id;"
	sleep $delay
done &
#| MYSQL_PWD="$password" mariadb --host 127.0.0.1 --port 3307 --user "$user" "$db"
while true
do
	port=$(( RANDOM % 2 + 3307))
	id=$((RANDOM % 6 + 1))
	value=$(( RANDOM % 100 )).$(( RANDOM % 100))
	MYSQL_PWD="$password" mariadb --host 127.0.0.1 --port $port --user "$user" "$db" -e "INSERT INTO tbl (id, val) VALUES ($id, '$value');"
	sleep $delay
done
#| MYSQL_PWD="$password" mariadb --host 127.0.0.1 --port 3307 --user "$user" "$db"


