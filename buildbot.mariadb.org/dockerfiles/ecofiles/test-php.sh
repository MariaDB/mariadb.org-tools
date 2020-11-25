#!/bin/bash
# wget url | bash -s [branch] [buildopt] [additional build options...]
set -x -v

declare -A buildopts=(
	[mysqlnd]='--enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd'
	[mysqlclient]='--with-mysqli=/usr/bin/mysql_config --with-pdo-mysql=/usr/'
	[mariadbclient]='--with-mysqli=/usr/local/mariadb/bin/mysql_config --with-pdo-mysql=/usr/local/mariadb'
)

branch=${1:-master}
shift || echo "Using default branch '$branch'"
opt=${1:-mysqlnd}
shift || echo "Using default option '$opt'"

if [ -z "${buildopts[$opt]}" ]; then
   echo "Unsupported build option $opt"
   exit 1
fi

export MYSQL_TEST_DB=test
export MYSQL_TEST_HOST=localhost
export MYSQL_TEST_PORT=3306
export MYSQL_TEST_SOCKET=/tmp/mysql.sock
export MYSQL_TEST_USER=root
export MYSQL_TEST_PASSWD=

# Controlling Environment variables from ./ext/mysqli/tests/connect.inc
# MYSQL_TEST_{HOST,PORT,USER,PASSWD,DB
# ENGINE,SOCKET
# CONNECT_FLAGS - integer for mysqli_real_connect

export PDO_MYSQL_TEST_DSN="mysql:host=${MYSQL_TEST_HOST};dbname=${MYSQL_TEST_DB}"
export PDO_MYSQL_TEST_USER="${MYSQL_TEST_USER}"
export PDO_MYSQL_TEST_PASS="${MYSQL_TEST_PASSWD}"
# 
# ./ext/pdo_mysql/tests/mysql_pdo_test.inc
# PDO_MYSQL_TEST_DSN, = mysql:host=localhost;dbname=test
# PDO_MYSQL_TEST_USER
# PDO_MYSQL_TEST_PASS
# PDOTEST_ATTR
# PDO_MYSQL_TEST_ENGINE

cd /code

# https://stackoverflow.com/questions/3258243/check-if-pull-needed-in-git
UPSTREAM='@{u}'
git_update_refs()
{
  LOCAL=$(git rev-parse @)
  REMOTE=$(git rev-parse "$UPSTREAM")
  BASE=$(git merge-base @ "$UPSTREAM")
  if [ $LOCAL = $REMOTE ]; then
    echo "Up-to-date"
  elif [ $LOCAL = $BASE ]; then
    echo "Need to pull"
    git pull
    ./buildconf
  elif [ $REMOTE = $BASE ]; then
    echo "Need to push"
  else
    echo "Diverged"
  fi
}

if [ -d master ]
then
  cd master
  git remote update
else
  git clone https://github.com/php/php-src.git master
  cd master
fi
git_update_refs

codedir=/code/$branch

if [ "$branch" != "master" ]
then
  if [ -d "$codedir" ]
  then
    ( cd "$codedir"; git_update_refs )
  else
    mkdir -p "$codedir"
    git worktree add "$codedir" "$branch"
    ( cd "$codedir"; ./buildconf )
  fi
fi

echo
echo "BRANCH: $branch"
echo "BUILD: $opt"

builddir="/build/${branch}-${opt}"
mkdir -p "$builddir"
cd "$builddir"
if [ "$codedir"/configure -nt config.log ]
then
  "$codedir"/configure --enable-debug \
                 ${buildopts[$opt]} $@ \
                 --with-mysql-sock=/tmp/mysql.sock || cat config.log
fi
make -j $(nproc)

echo
echo Testing...
echo

mkdir -p /tmp/s /tmp/t

# -j$(nproc) not in 7.3 - didn't significantly parallize anyway
TEST_PHP_EXECUTABLE=./sapi/cli/php ./sapi/cli/php "$codedir"/run-tests.php \
       --temp-source /tmp/s --temp-target /tmp/t  --show-diff \
       "$codedir"/ext/mysqli/tests/*phpt \
       "$codedir"/ext/pdo_mysql/tests/*phpt
