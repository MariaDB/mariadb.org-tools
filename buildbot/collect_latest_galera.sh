#!/bin/bash

# The loop traverses through all stored builds of Galera in mariadb-4.x
# and mariadb-3.x, starting from the newest ones, and collects links
# to newest builds on different platforms in the "latest" folder

for galera in 3 4 ; do

  rm -rf /tmp/latest.new
  mkdir /tmp/latest.new
  for rev in `ls -t /ds1819/archive/builds/mariadb-${galera}.x/` ; do
    if [[ ${rev} =~ latest ]] ; then
      continue
    fi
    for bld in `ls /ds1819/archive/builds/mariadb-${galera}.x/${rev}` ; do
      if ! [ -e /tmp/latest.new/${bld} ] ; then
        ln -s /ds1819/archive/builds/mariadb-${galera}.x/${rev}/${bld} /tmp/latest.new/${bld}
      fi
    done
  done

  rm -rf /ds1819/archive/builds/mariadb-${galera}.x/latest.old
  if [ -e /ds1819/archive/builds/mariadb-${galera}.x/latest ] ; then
    mv /ds1819/archive/builds/mariadb-${galera}.x/latest /ds1819/archive/builds/mariadb-${galera}.x/latest.old
  fi
  mv /tmp/latest.new /ds1819/archive/builds/mariadb-${galera}.x/latest

done
