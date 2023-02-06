########################################################################
# Debian MTR variations
########################################################################

set -x
res=0
set +o pipefail

# Check that the installation worked, and we have the installed server
if ! dpkg -l | grep "mariadb-server"
then
  echo "Pre-MTR ERROR: previous server installation failed, cannot run MTR tests"
  exit 1
fi

if ! dpkg -l | grep "mariadb-test" ; then
  sudo sh -c "DEBIAN_FRONTEND=noninteractive apt-get install -y mariadb-test mariadb-test-data"
fi

# Also try to install gdb to get decent stack traces, but don't abort if it does not install
if ! sudo sh -c "DEBIAN_FRONTEND=noninteractive MYSQLD_STARTUP_TIMEOUT=180 apt-get install --allow-unauthenticated -y gdb"
then
  echo "Warning: Could not install gdb, proceeding without it"
fi

cd /usr/share/mysql/mysql-test

mtr_opts=" --verbose-restart --force --retry=2 --max-save-core=0 --max-save-datadir=1 --vardir=""$(readlink -f /dev/shm/var)"

if [ "$test_set" == "default" ] ; then
  if test -f suite/plugins/pam/pam_mariadb_mtr.so; then
    for p in /lib*/security /lib*/*/security ; do
      test -f $p/pam_unix.so && sudo cp -v suite/plugins/pam/pam_mariadb_mtr.so $p/
    done
    sudo cp -v suite/plugins/pam/mariadb_mtr /etc/pam.d/
  fi
  # MDEV-29043 -- add qpress (if possible) to enable mariabackup.compress_qpress test
  wget https://repo.percona.com/apt/percona-release_latest.$(lsb_release -sc)_all.deb -O $HOME/percona_all.deb && \
    sudo dpkg -i $HOME/percona_all.deb && \
    ls -l /etc/apt/sources.list.d/ && \
    sudo apt-get update && \
    sudo apt-get install -y qpress
  sudo rm /etc/apt/sources.list.d/percona* && sudo apt-get update
  mtr_opts="$mtr_opts --parallel=4"
elif [ "$test_set" == "galera" ] ; then
  case "$branch" in
  *10.[2-3]*)
    galera_suites=galera,wsrep,wsrep_info,galera_3nodes
    ;;
  *)
    galera_suites=galera,wsrep,wsrep_info,galera_3nodes,galera_sr
    ;;
  esac
  mtr_opts="$mtr_opts --suite=$galera_suites --parallel=2"
elif [ "$test_set" == "galera-smoke" ] ; then
  mtr_opts="$mtr_opts --suite=galera --do-test=\"galera_sst*|galera_ist*|galera_bf*|galera_gcache*|galera_log_bin*\" --parallel=2"
elif [ "$test_set" == "galera-sst" ] ; then
  # Only running big tests, small SST runs in the general galera set
  mtr_opts="$mtr_opts --suite=galera --do-test=galera_sst_* --big --big"
elif [ "$test_set" == "rocksdb" ] ; then
  if ! perl mysql-test-run.pl rocksdb.1st --vardir="$(readlink -f /dev/shm/var)" 2>&1 | grep -E 'RocksDB is not compiled|Could not find' ; then
    mtr_opts="$mtr_opts --suite=rocksdb* --skip-test=rocksdb_hotbackup* --parallel=4"
  else
    echo "Test warning"": RocksDB engine not found, tests will be skipped"
    exit
  fi
elif [ "$test_set" == "s3" ] ; then
  if perl mysql-test-run.pl s3.basic --vardir="$(readlink -f /dev/shm/var)" 2>&1 | grep -E 'Need S3 engine' ; then
    echo "Test warning"": S3 engine not found, tests will be skipped"
    exit
  fi
 
  if ! wget ftp://ftp.askmonty.org/public/minio/minio-linux-${arch} -O ~/minio ; then
    echo "ERROR: Could not download MinIO server for Linux ${arch}"
    echo "Check if it is available at http://dl.min.io/server/minio/release and store as ftp://ftp.askmonty.org/public/minio/minio-linux-${arch}"
    exit 1
  fi
  chmod a+x ~/minio
  MINIO_ACCESS_KEY=minio MINIO_SECRET_KEY=minioadmin ~/minio server /tmp/shared 2>&1 &
  if ! wget ftp://ftp.askmonty.org/public/minio/mc-linux-${arch} -O ~/mc ; then
    echo "ERROR: Could not download MinIO client for Linux ${arch}"
    echo "Check if it is available at http://dl.min.io/client/mc/release/ and store as ftp://ftp.askmonty.org/public/minio/mc-linux-${arch}"
    exit 1
  fi
  chmod a+x ~/mc

  # Try a few times in case the server hasn't finished initializing yet
  res=1
  for i in 1 2 3 4 5 ; do
    ### Cannot use mc alias, because the mc version for i386 is old, it doesn't support it
    # if ~/mc alias set local http://127.0.0.1:9000  minio minioadmin ; then
    if ~/mc config host add local http://127.0.0.1:9000  minio minioadmin ; then
      res=0
      break
    fi
    sleep 1
  done
  if [ "$res" == "1" ] ; then
    echo "ERROR: Couldn't configure MinIO server"
    exit 1
  fi
  # i386 has an old version of minio/mc, which doesn't seem stable. Try a few times before giving up
  res=1
  for i in 1 2 3 4 5 ; do
    if ~/mc mb --ignore-existing local/storage-engine ; then
      res=0
      break
    fi
    sleep 1
  done
  if [ "$res" == "1" ] ; then
    echo "ERROR: Couldn't create the bucket in MinIO"
    exit 1
  fi
  mtr_opts="$mtr_opts --suite=s3"
else
  echo "ERROR: Unknown test set $test_set"
  res=1
fi

if ! NO_FEEDBACK_PLUGIN=1 MTR_PRINT_CORE=medium perl mysql-test-run.pl $mtr_opts ; then
  res=1
fi

rm -rf /home/buildbot/var
cp -r /dev/shm/var /home/buildbot
exit $res
