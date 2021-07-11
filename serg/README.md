_Everything in this directory, unless specifically noted
is under BSD-new (3-clause) license._

# run_gdb

A wrapper that can run any executable under gdb.  useful for debugging mysqld
bootstrap (before mtr learned to do that) and to debug
mysql, mysqldump, mysqlbinlog, etc that are run from inside `*.test` files.

Use as

    run_gdb <path-to-executable>

it'll rename executable to <old-name>.exe and put a symlink to itself
under the old executable name. When run as this executable it'll
start gdb in xterm.

# thou_shalt_not_kill.pm

A perl module that prevents killing of subprocesses. Useful to prevent
`mysql-test-run` from `kill -9` your gdb session and from killing mysqld too
early, before it has finished the logging or whatever.

Use as

    perl -Mthou_shalt_not_kill ./mtr sometest

When mtr will try to kill something, you will see what it's trying to
kill and you'll be able to approve or cancel the killing action.

# y.output-to-html

Converts bison output file (from `bison --verbose`) to a huge html file,
that takes quite a while to load, but then one can navigate the grammar
with a comfort of a browser.

# mtr-rejects

After running `mysql-test-run.pl` (particularly with `--force`), you can get many
`*.reject` files. Simply run this script from the mysql-test/ dir and it'll fire
gvimdiff for every reject file, you can review and merge changes as you like.
When you exit gvimdiff and reject and result file are still different, the
script will ask whether you want to overwrite `.result` with `.reject` (so you
don't need to merge all diffs in gvimdiff, but can simply answer 'y' later).

For many diffs with identical changes, where you mainly need review and full
overwrite (not chunk-by-chunk manual merging) run this script with `--diff`
option.  It will use diff instead of gvimdiff, saving you a few keypresses
per reject file.

It can also be run with the explicit list of reject files as arguments.

# dbug-relative-times.pl

when the trace is generated with `i:T`
replaces absolute timestamps with relative, since the last timestamp
of the same thread

# mtr-log-pp

Filters the `typescript` (result of `script -c './mtr --force'`) or
`text` ("save as" plain-text buildbot log of an mtr run) or any file specified
on the command-line (expected to be mtr output) as follows:

    test 'c1' w1 [ pass ]^M
    worker[2] - Restart^M
    test      w2 [ fail ]^M^G

becomes

    test,c1  w1 [ pass ]
    w2 - Restart
    test      w2 [ fail ]

That is, control characters are removed. One can grep for "w2" to
find all tests of the second worker and when it was restarted.
And one can easily copy-paste tests that were run (note "test,c1").

# gdbinit

Defines helper commands for using with `./mtr --gdb`
See inside, all commands are documented.

Also loads .gdb.py (see below)

# gdb.py

Python part of .gdbinit. Needs gdb-tools
(see https://github.com/vuvova/gdb-tools)
Loads duel and creates pretty-printers for various data structures.
To use, just print values normally, for example

    (gdb) p table->alias
    $1 = _binary "plugin"
    (gdb) p table->tmp_set
    $5 = b'00'
    (gdb) p/r table->tmp_set
    $6 = {bitmap = 0x7ffff4c19830, last_word_ptr = 0x7ffff4c19830, mutex = 0x0, 
      last_word_mask = 4294967292, n_bits = 2}

the last example shows `p/r` command to bypass a pretty-printer, if needed.

# mtr-bash-completion.sh

The name says it all. Bash command line completion for mtr.
Use as `source mtr-bash-completion.sh` from your `.bashrc`

# bookmarklets.html

## ANSIfy

Convert ANSI sequences in logs into html.
Very useful when reading stdout logs from buildbot.
