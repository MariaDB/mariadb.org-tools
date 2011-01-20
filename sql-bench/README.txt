1. What is it?
This wrapper scripts are meant to run sql-bench with
various compiler options and run time configurations.

2. Prerequisite
- MariaDB bzr tree from lp:maria
- Perl with DBD::MySQL

3. What are those directories?
* Each directory represents a compiler configuration. You
can find the compiler configuration in compiler.cnf.
Each compiler configuration has a set of tests (*.sqlbt).

4. How to run?
Run run-sql-bench.pl and check output for details.

Note: name your test file like the $sql_bench_test array name. For
  instance $sql_bench_test->{'base'} should be named
           base.sqlbt

--
Hakan Kuecuekyilmaz, <hakan at askmonty dot org>, 2010-10-28.
