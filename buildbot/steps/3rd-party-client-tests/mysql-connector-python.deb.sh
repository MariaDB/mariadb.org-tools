#!/bin/bash -x

sudo apt-get install -y python python3
cd mysql-connector-python-*/
sed -ie 's/-for python/for python/' debian/rules
sed -ie '/(5, 7, /,/^$/d' tests/mysqld.py 

dh build |tee build.log 2>&1 

grep '^\(FAIL\|ERROR\):' build.log
