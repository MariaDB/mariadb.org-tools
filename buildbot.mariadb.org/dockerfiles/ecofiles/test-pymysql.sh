#!/bin/bash

set -xeuvo pipefail

cd /code
[ -d PyMySQL ] || git clone https://github.com/PyMySQL/PyMySQL.git
cd PyMySQL
git clean -dfx
git checkout main
git pull --tags
if [ $# -gt 0 ]
then
  if [ ! -d ../"$1" ]
  then
    git worktree add ../"$1" "$1"
  fi
  cd ../"$1"
  # this is right for tags, not for branches yet
  git checkout $1
fi

/usr/local/mariadb/bin/mysql --comments -u root < ci/docker-entrypoint-initdb.d/init.sql
/usr/local/mariadb/bin/mysql --comments -u root < ci/docker-entrypoint-initdb.d/mariadb.sql

cp ci/docker.json pymysql/tests/databases.json

export USER=buildbot

# test_auth is MySQL sha256password tests
pytest -v -k 'not test_auth'
