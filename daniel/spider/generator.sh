#!/bin/bash
set -x -v
read -r -a getenthosts <<< "$(getent hosts  self.metadata.compute.edgeengine.io)"
# result form: ip cname self.meta....

# take cname from the form:
# [instance-name].[deployment-scope].[target-name].[workload-slug].[stack-slug].[root-domain]
read -r -a parts <<< "${getenthosts[1]//./ }"

# The database host is the same as our name, with "gen" replaced by "db"
host=${parts[0]/gen-/db-}
# altenately db-${parts[2]}-${parts[1]}-0
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
