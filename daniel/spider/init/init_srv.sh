define(){ IFS=$'\n' read -r -d '' "${1}" || true; }

define TABLE <<EOT
    CREATE TABLE data(
      id INT NOT NULL AUTO_INCREMENT,
      code VARCHAR(10),
      PRIMARY KEY(id)
    )
EOT

if resolveip master ; then
  docker_process_sql <<<"install soname 'ha_spider';"
  for srv in node1 node2; do
  
    docker_process_sql <<-EOSQL
    CREATE SERVER $srv FOREIGN DATA WRAPPER mariadb OPTIONS(
      HOST '$srv',
      PORT 3306,
      DATABASE '$MARIADB_DATABASE',
      USER '$MARIADB_USER',
      PASSWORD '$MARIADB_PASSWORD');
    $TABLE ENGINE=SPIDER REMOTE_SERVER="$srv" REMOTE_TABLE="data";
    RENAME TABLE data TO remote_${srv};
EOSQL
  done


else
  docker_process_sql <<<"$TABLE"
fi
