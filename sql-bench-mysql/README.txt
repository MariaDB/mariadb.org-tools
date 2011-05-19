0. This is fine tuned for running with MySQL

1. What is it?
This wrapper scripts are meant to run the sql-bench benchmark suite
with various compiler options and different run time configurations.

2. Prerequisite
- MySQL bzr tree from lp:mysql-server
- Perl with DBD::MySQL

3. What you will find in those directories?
Each directory represents a compiler/test combination to be run.
3.1 You can find each compiler configuration in
- compiler_<hostname>.cnf.
3.2 You can find the tests for that compiler configuration
in the files ending with
- *.sqlbt.

4. How to run?
Run run-sql-bench.pl and check output for details.

Note: name your test file like the $sql_bench_test array name. For
  instance $sql_bench_test->{'base'} should be named
           base.sqlbt

--
Hakan Kuecuekyilmaz, <hakan at askmonty dot org>, 2011-05-17.
