<?php
/**
 * Analyze sysbench v0.5 results
 *
 * We take one directory as an argument and produce
 * SQL INSERT statements for further usage.
 *
 * The current directory structure is:
 *   ${RESULT_DIR}/${TODAY}/${PRODUCT}/${SYSBENCH_TEST}/${THREADS}
 *
 * For instance:
 *   $HOME/work/sysbench-results/2010-02-26/MariaDB/select.lua/16
 *
 * The current result file format is:
 *   [2010-02-27 02:45:42] Running select.lua with 16 threads and 3 iterations for MariaDB
 *
 *   21921.91
 *   21806.86
 *   21749.94
 *
 * The current layout of the tables for storing the
 * benchmark results of a sysbench run is:
 *   CREATE TABLE sysbench_run (
 *     id int unsigned NOT NULL auto_increment,
 *     host varchar(80),               -- Hostname we ran the test on.
 *     run_date date,                  -- The day we ran the test.
 *     sysbench_version varchar(32),   -- Version of sysbench we used.
 *     test_name varchar(32),          -- Name of the sysbench test.
 *     run_time int unsigned,          -- Run time in seconds.
 *     runs int unsigned,              -- Number of iterations of the test.
 *     PRIMARY KEY (id),
 *     KEY (host),
 *     KEY (run_date
 *   );
 *
 *   CREATE TABLE sysbench_comment (
 *     id int unsigned NOT NULL auto_increment,
 *     sysbench_run_id int unsigned NOT NULL,  -- FK pointing to sysbench_run.
 *     compile_info text,                      -- Compile options we used.
 *     machine_info text,                      -- Details about the hardware.
 *     sysbench_options text,                  -- The sysbench options we used.
 *     PRIMARY KEY (id),
 *     KEY (sysbench_run_id)
 *   );
 *
 *   CREATE TABLE sysbench_result (
 *     id int unsigned NOT NULL auto_increment,
 *     sysbench_run_id int unsigned NOT NULL,  -- FK pointing to sysbench_run.
 *     concurrency int unsigned,               -- Concurrency level we used.
 *     result decimal(7,2),                    -- The actual result.
 *     io varchar(80),                         -- The IO from iostat.
 *     cpu varchar(80),                        -- CPU utilization.
 *     profile text,                           -- Profiling information.
 *     error text,                             -- Error messages and stack traces.
 *     PRIMARY KEY (id),
 *     KEY (sysbench_run_id
 *   );
 *
 * @see run-sysbench.sh
 *
 * Hakan Kuecuekyilmaz, <hakan at askmonty dot org>, 2010-03-02.
 */

/**
 * Base path to our result files.
 */
define('BASE_PATH', $_SERVER['HOME'] . '/work/sysbench-results/' . RUN_DATE . '/' . PRODUCT);

/**
 * The sysbench tests, which were run. This has to be the same set
 * of tests as in run-sysbench.sh.
 */
$sysbench_tests = array('delete.lua',
                        'insert.lua',
                        'oltp_complex_ro.lua',
                        'oltp_complex_rw.lua',
                        'oltp_simple.lua',
                        'select.lua',
                        'update_index.lua',
                        'update_non_index.lua'
                        );

/**
 * The concurrency levels, we run sysbench with. This has to be the
 * same list as in run-sysbench.sh.
 */
$threads = array(1, 4, 8, 16, 32, 64, 128),

/**
 * Number of iterations we ran each test. This has to be the same
 * as in run-sysbench.sh
 */
define('RUNS', 3);

foreach ($sysbench_tests as $data) {
    foreach ($threads as $thread_number) {
        $file = BASE_PATH . '/'. $data . '/' . $thread_number;

        if (file_exists($file)) {
            $tmp = file_get_contents($file)
        } else {
            echo '[ERROR]: Could not open ...';
        }
    }
}
?>
