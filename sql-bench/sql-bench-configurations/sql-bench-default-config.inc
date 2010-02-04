# Template configuration file for running sqlbench.
#
# We are using this configuration file for the wrapper
# script run-sql-bench.sh. For every copy of this file we
# are starting a sqlbench run.
#
# Hakan Kuecuekyilmaz <hakan at askmonty dot org> 2009-12-05.
#

#
# Configure line for compiling MariaDB.
#
export MARIADB_CONFIG="--enable-thread-safe-client \
  --enable-local-infile"

#
# Options for starting mysqld.
#
# Attention: Do not set --datadir, --tmpdir, nor --socket.
#
export MARIADB_OPTIONS="--no-defaults"

#
# Options for sql-bench.
#
# Attention: Do not set --socket.
#
export SQLBENCH_OPTIONS="--log \
  --fast \
  --server=mysql \
  --small-test \
  --user=root"
