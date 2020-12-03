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

# until bb master.cfg reloaded
[ -d /data/test ] || curl https://raw.githubusercontent.com/MariaDB/mariadb.org-tools/master/buildbot.mariadb.org/dockerfiles/ecofiles/installdb.sh | bash -s

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

export PDO_MYSQL_TEST_DSN="mysql:host=127.0.0.1;dbname=${MYSQL_TEST_DB}"
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

declare -a mysqlifailtests
declare -a pdofailtests

case "${branch}" in
	PHP-7\.[12])
		mysqlifailtests+=( mysqli_get_client_stats ) # 7.3 fixed
		mysqlifailtests+=( 057 )
		mysqlifailtests+=( mysqli_pconn_max_links )
		mysqlifailtests+=( mysqli_stmt_bind_param_many_columns )
		mysqlifailtests+=( mysqli_report )
		mysqlifailtests+=( bug34810 )
		mysqlifailtests+=( mysqli_class_mysqli_interface )
		;&
	PHP-7\.3)
		pdofailtests+=( bug_38546 ) # fixed in at least 8.0
		mysqlifailtests+=( mysqli_change_user_new ) # at least 8.0 (not 7.4)
		;&
	PHP-7\.4)
		mysqlifailtests+=( 063 ) # fixed in 8.0 at least
		;&
	PHP-8\.0)
		# no new test failures. Yay
		;&
	master)
		mysqlifailtests+=( mysqli_expire_password ) # https://github.com/php/php-src/pull/6480
		mysqlifailtests+=( mysqli_stmt_get_result_metadata_fetch_field ) # https://github.com/php/php-src/pull/6484
		mysqlifailtests+=( mysqli_debug )
		mysqlifailtests+=( mysqli_debug_append )
		mysqlifailtests+=( mysqli_debug_control_string )
		mysqlifailtests+=( mysqli_debug_mysqlnd_control_string )
		mysqlifailtests+=( mysqli_debug_mysqlnd_only )

esac

for f in "${mysqlifailtests[@]}"
do
  GLOBIGNORE="$GLOBIGNORE:$codedir/ext/mysqli/tests/$f.phpt"
done
for f in "${pdofailtests[@]}"
do
  GLOBIGNORE="$GLOBIGNORE:$codedir/ext/pdo_mysql/tests/$f.phpt"
done
echo $GLOBIGNORE

mkdir -p /tmp/s /tmp/t

# -j$(nproc) not in 7.3 - didn't significantly parallize anyway
TEST_PHP_EXECUTABLE=./sapi/cli/php ./sapi/cli/php "$codedir"/run-tests.php \
       --temp-source /tmp/s --temp-target /tmp/t  --show-diff \
       "$codedir"/ext/mysqli/tests/*phpt \
       "$codedir"/ext/pdo_mysql/tests/*phpt
