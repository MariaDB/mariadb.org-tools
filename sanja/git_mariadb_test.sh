#!/bin/bash
#
# This script is to find which commit fixed the test (or vice versa)
#
# Parameters:
#
# $1 test name (name if the test without .test or .result)
# $2 temporary directory (should not contain <test>.test or <test>.result)
# $3 reposicory directory (pathroot of mysql git repository)
# $4 cmake parameters  (default: "-GNinja -DCMAKE_BUILD_TYPE=Debug")
# $5 make command (default: "ninja")
# $6 revert test (0 - find what fixed (defualt), 1 - find what broke)
# $7 pre-build command (default: none)
#
# Example of use (what fixed test 'mysql-test/t/test.test' if in
# mariadb-10.1.19 it failed but in current 10.1 it is ok)
#
# cd ~/maria/git/server
# rm ~/tmp/test.*
# git bisect start
# git bisect good mariadb-10.1.19
# git bisect bad 10.1
# git bisect run bash ~/bin/git_mariadb_test.sh test ~/tmp/ ~/maria/git/server/
#
# Full command line example:
# git bisect run bash ~/bin/git_mariadb_test.sh test ~/tmp/ ~/maria/git/server/ './ -GNinja -DCMAKE_BUILD_TYPE=Debug -DPLUGIN_MROONGA=NO -DPLUGIN_OQGRAPH=NO -DPLUGIN_ROCKSDB=NO -DPLUGIN_CONNECT=NO' ninja 0 "rm -rf  ~/maria/git/server/storage/tokudb"


#set defaults if it is needed
if [ "$4" = "" ] ; then
  CMAKE_PRM="-GNinja -DCMAKE_BUILD_TYPE=Debug"
else
  CMAKE_PRM="$4"
fi
if [ "$5" = "" ] ; then
  MAKE="ninja"
else
  MAKE="$5"
fi
if [ "$6" = "" ] ; then
  REVERT=0
else
  REVERT=1
fi

#Save test scripts as is (if it is needed)
if [ ! -f "$2/$1.test" ] ; then
  cp "$3/mysql-test/t/$1.test" "$2/$1.test"
fi
if [ ! -f "$2/$1.result" ] ; then
  cp "$3/mysql-test/r/$1.result" "$2/$1.result"
fi

cd $3

# Clean what is possible
git clean -xdff
git reset --hard

# Bring the test back
cp "$2/$1.test" "$3/mysql-test/t/$1.test"
cp "$2/$1.result"  "$3/mysql-test/r/$1.result"

# Pre-build command if exists
if [ "$7" != "" ] ; then
  echo '================================================'
  echo 'Prebuild command:'
  echo "$7"
  bash -c "$7"
  echo '================================================'
fi

# Check that the current commit is usable and buildable (otherwise skipp it)
if [ ! -d mysql-test ] ; then
  exit 125
fi
cmake $CMAKE_PRM || exit 125
$MAKE || exit 125
cd mysql-test

# Check the test result
if [ $REVERT -eq 0 ] ; then

if ./mysql-test-run $1 ; then
  git reset --hard
  exit 1
fi
git reset --hard
exit 0

else

if ./mysql-test-run $1 ; then
  git reset --hard
  exit 0
fi
git reset --hard
exit 1

fi
