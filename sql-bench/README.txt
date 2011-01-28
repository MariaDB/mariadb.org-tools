1. What is it?
This wrapper scripts are meant to run sql-bench with
various compiler options and run time configurations.

2. Prerequisite
- MariaDB bzr tree from lp:maria
- Perl with DBD::MySQL

3. What you will find in those directories?
Each directory represents a compiler/test combination to be run.
3.1 You can find the compiler configuration in
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
Hakan Kuecuekyilmaz, <hakan at askmonty dot org>, 2010-10-28.
