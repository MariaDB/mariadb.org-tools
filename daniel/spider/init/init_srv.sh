define(){ IFS=$'\n' read -r -d '' "${1}" || true; }

define TABLE <<EOT
    CREATE TABLE sales(
      id INT NOT NULL AUTO_INCREMENT,
      code VARCHAR(20),
      quantity INT UNSIGNED NOT NULL,
      value DECIMAL(10,2) NOT NULL,
      \`date\` DATETIME NOT NULL DEFAULT NOW(),
      PRIMARY KEY(id),
      KEY i_date(\`date\`)
    )
EOT

docker_process_sql <<<"install soname 'ha_spider';"
docker_process_sql <<<"$TABLE"

for srv in node1 node2; do
    remote_table=sales_remote_$srv
    if [ -z "$view" ]; then
       view="create view sales_all_nodes as select *,'$srv' as node from $remote_table"
    else
       view="$view union all select *,'$srv' from $remote_table"
    fi
    docker_process_sql <<-EOSQL
    CREATE SERVER $srv FOREIGN DATA WRAPPER mariadb OPTIONS(
      HOST '$srv',
      PORT 3306,
      DATABASE '$MARIADB_DATABASE',
      USER '$MARIADB_USER',
      PASSWORD '$MARIADB_PASSWORD');

    ${TABLE/sales/$remote_table} ENGINE=SPIDER REMOTE_SERVER="$srv" REMOTE_TABLE="sales";
EOSQL
done

docker_process_sql <<<"$view"
