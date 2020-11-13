#!/bin/bash -x

sudo apt-get install -y python python3 python3-setuptools python-setuptools
cd mysql-connector-python-*/
sed -ie 's/-for python/for python/' debian/rules
sed -ie '/(5, 7, /,/^$/d' tests/mysqld.py
sed -ie "s/\(matches = re\.match(r'\.\*Ver (\\\d\))/\1\+)/g" tests/mysqld.py

dh build 2>&1 | tee build.log

grep '^\(FAIL\|ERROR\):' build.log | tee /tmp/test.out
