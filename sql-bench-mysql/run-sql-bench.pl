#!/usr/bin/perl -w

# Run sql-bench for given configuration file with different
# configurations
# we find in the directory $SQL_BENCH_CONFIGS.
#
# Notes:
#   * Do not run this script with root privileges.
#   We use killall -9, which can cause severe side effects!
#
#   * Variables and paths, which you can adjust to your
#   environment are tagged with [CHANGEABLE]
#
# Hakan Kuecuekyilmaz, <hakan at askmonty dot org>, 2010-10-22.
use strict;
use Getopt::Long;
use File::Basename;

# Paths we are using.
#
# Every directory except the conf/ directory represents a
# compiler options and test combination we want to run. If
# you a new compiler option scenario, then you add a directory
# with a descriptive name and add the sql-bench test variations
# you want to run. Every file ending on *.sqlbt represents a
# test variation to run.
#
# If you want to run a new sql-bench test scenario for a
# given compiler option, then you add a file with a descriptive
# name ending with *.sqlbt to the compiler configuration
# directory of your choice.
#
# You can also overwrite the default MariaDB tree version,
# which you define by a command line option of this script.
#
# Mind the run time of a sql-bench scenario which can vary
# from 30 minutes to 2 hours or more.
my @folders;

# [CHANGEABLE]: Set this to your sql-bench/ directory path, in which
# you branched lp:mariadb-tools with bzr.
#
# Note: Mind the trailing /.
my $path = "$ENV{'HOME'}/work/monty_program/mariadb-tools/sql-bench-mysql/";

# [CHANGEABLE]: Name of compile log file.
# This will be prefixed whith each corresponding configuration.
my $compile_log = "compile.log";

# The MariaDB tree to use and compile.
# We are also using the sql-bench directory from there.
my $repository;

# Additional sql-bench options, mostly for testing and
# debugging like --small-test.
my $cl_sql_bench_options;
my $help;
my $debug;

#
# Binaries.
#
my $mysql = 'bin/mysql';
my $mysqladmin = 'bin/mysqladmin';

# Variables we read in from .sqlbt files.
my $current_mysqld_start_options;
my $current_mysqld_init_command;
my $current_sql_bench_options;

# Variables, which we are using for our configurations.
our $config;
our $sql_bench_test;

# [CHANGEABLE] Variables, which we are using in our host specific
# configuration file from the conf/ directory.
our $sql_bench_results;
our $work_dir;
our $bzr;
our $mktemp;
our $mkdir;
our $sudo;
our $make;
our $concurrency;
our $perl;
our $ccache;

#
# Variables.
#
# We need at least 1 GB disk space in our $work_dir.
my $space_limit = 1000000;
my $machine = qx(/bin/hostname -s);
chomp($machine);
my $run_date = qx(date +%Y-%m-%d);
chomp($run_date);

# Timeout in seconds for waiting for mysqld to start.
my $timeout = 100;

my $run_by = qx(whoami);
if ($run_by eq 'root')
{
  print '[ERROR]: Do not run this script as root!' . "\n";
  print '  Exiting.';

  exit 1;
}

usage() if (@ARGV < 3
            or !GetOptions('help|?' => \$help,
                           'repository=s' => \$repository,
                           'sql-bench-options=s' => \$cl_sql_bench_options,
                           'debug=s' => \$debug,)
            or defined $help);

# Read in every compiler option directory for iterating except conf/ directory.
opendir(DIR, $path) or die "cant find $path: $!";
while (defined(my $file = readdir(DIR))) {
  next if $file =~ /^\.\.?$/;
    if (-d "$path$file" && $file ne "conf") {
      push @folders, "$path$file";
    }
}
closedir(DIR);

# Iterate over ever directory read in compile_<hostname>.cnf and
# run every test we find in that directory.
print "[" . print_timestamp() . "]: Entering main iteration loop.\n";
foreach my $compile_config (@folders) {
  print "[" . print_timestamp() . "]: In directory " . $compile_config . "\n";
  
  my $compile_machine_config = $compile_config . '/compiler_' . $machine . '.cnf';

  # Compile configuration specific config file. If there is no
  # machine specific configuration file, we skip it.
  if (!-f $compile_machine_config) {
    print "[" . print_timestamp() . "]: Skipping directory " . $compile_config . "\n";
    print "  Because " . basename($compile_machine_config) . " was not found" . "\n";
    
    next;
  }

  # Configuration specific config file.
  require $compile_machine_config;

  if ($debug eq 'yes') {
    print "Variables read in from: $compile_machine_config\n";
    print '$ENV{\'CC\'}: ' . $ENV{'CC'} . "\n";
    print '$ENV{\'CFLAGS\'}: ' . $ENV{'CFLAGS'} . "\n";
    print '$ENV{\'CXX\'}: ' . $ENV{'CXX'} . "\n";
    print '$ENV{\'CXXFLAGS\'}: ' . $ENV{'CXXFLAGS'} . "\n";
    print '$ENV{\'CXXLDFLAGS\'}: ' . $ENV{'CXXLDFLAGS'} . "\n";
    print '$config->{configure_line}: ' . $config->{configure_line} . "\n";
    print "\n";
  }

  # Host specific config file.
  require './conf/' . $machine . '.cnf';
  $ENV{'CC'}  = $ccache . " " . $ENV{'CC'};
  $ENV{'CXX'} = $ccache . " " . $ENV{'CXX'};

  if ($debug eq 'yes') {
    print 'Variables read in from: ' . './conf/' . $machine . '.cnf' . "\n";
    print '$sql_bench_results: ' . $sql_bench_results . "\n";
    print '$work_dir: ' . $work_dir . "\n";
    print '$bzr: ' . $bzr . "\n";
    print '$mktemp: ' . $mktemp . "\n";
    print '$mkdir: ' . $mkdir . "\n";
    print '$make: ' . $make . "\n";
    print '$concurrency: ' . $concurrency . "\n";
    print '$perl: ' . $perl . "\n";
    print '$ccache: ' . $ccache . "\n";
    print '$ENV{\'CC\'}: ' . $ENV{'CC'} . "\n";
    print '$ENV{\'CXX\'}: ' . $ENV{'CXX'} . "\n";
    print "\n";
  }

  #
  # Check system.
  #
  # We should at least have $space_limit in $work_dir.
  my $available = qx(df $work_dir | grep -v Filesystem | awk '{ print \$4 }');

  if ($available < $space_limit)
  {
    print "[ERROR]: We need at least $space_limit space in $work_dir.";
    print '  Exiting.';

    exit 1;
  }

  #
  # Check out MariaDB, compile, and install it.
  #
  my $revision_id = qx($bzr version-info $repository | grep revision-id);
  if ($? != 0)
  {
    print "[ERROR]: bzr version-info failed. Please provide\n";
    print "  a working bzr repository (--repository)\n";
    print "  Exiting.\n";

    exit 1;
  }

  chdir($work_dir)
    or die
      "[ERROR]: cd to $work_dir failed.\n"
      . "  Does your $work_dir directory exist?\n"
      . "  Exiting.\n";

  # Clean up of previous runs.
  print "[NOTE]: Cleaning up previous runs and killing all mysqld processes.\n";
  qx(killall -9 mysqld);

  # Mac OS X needs explicit TMPDIR environment variable for mktemp -d to work.
  $ENV{'TMPDIR'} = $work_dir;
  my $temp_dir = qx($mktemp -d);
  if ($? != 0)
  {
    print "[ERROR]: mktemp in $work_dir failed.\n";
    print "  Exiting.\n";

    exit 1;
  }

  # Get rid of any newline.
  chomp($temp_dir);
  my $mariadb_datadir = "$temp_dir/data";
  my $compile_log_current = $temp_dir ."/" . basename($compile_config) . "_" . $compile_log;

  # bzr export refuses to export to an existing directory,
  # therefore we use a build directory.
  print "[" . print_timestamp() . "]: Exporting from $repository to $temp_dir/build\n";

  qx($bzr export --format=dir $temp_dir/build $repository);
  if ($? != 0)
  {
    print "[ERROR]: bzr export failed.\n";
    print "  Exiting.\n";

    exit 1;
  }

  print "[" . print_timestamp() . "]: Finished exporting from $repository to $temp_dir/build\n";
  print "[" . print_timestamp() . "]: Starting to compile and logging into $compile_log_current.\n";

  chdir("$temp_dir/build")
    or die
      "[ERROR]: cd to $temp_dir/build failed.\n"
      . "  Does your $temp_dir/build directory exist?\n"
      . "  Exiting.\n";

  print "[" . print_timestamp() . "]: Running BUILD/autorun.sh\n";
  qx(BUILD/autorun.sh > $compile_log_current 2>&1);
  if ($? != 0)
  {
    print "[ERROR]: BUILD/autorun.sh failed.\n";
    print "  Please check your development environment.\n";
    print "  You can also examine your compile log $compile_log_current\n";
    print "  Exiting.\n";

    exit 1;
  }

  # We need --prefix for running make install. Otherwise
  # mysql_install_db will not work properly.
  print "[" . print_timestamp() . "]: Running ./configure\n";
  qx(./configure $config->{configure_line} --prefix=$temp_dir/install >> $compile_log_current 2>&1);
  if ($? != 0)
  {
    print "[ERROR]: ./configure $config->{configure_line} failed.\n";
    print "  Please check your '$config->{configure_line}'.\n";
    print "  You can also examine your compile log $compile_log_current\n";
    print "  Exiting.\n";

    exit 1;
  }

  print "[" . print_timestamp() . "]: Running $make -j$concurrency\n";
  qx($make -j$concurrency >> $compile_log_current 2>&1);
  if ($? != 0)
  {
    print "[ERROR]: make failed.\n";
    print "  Please examine your compile log $compile_log_current\n";
    print "  Exiting.\n";

    exit 1;
  }

  print "[" . print_timestamp() . "]: Finished compiling.\n";

  print "[" . print_timestamp() . "]: Running $make install\n";
  qx($make install >> $compile_log_current 2>&1);
  if ($? != 0)
  {
    print "[ERROR]: make install failed.\n";
    print "  Please examine your compile log $compile_log_current\n";
    print "  Exiting.\n";

    exit 1;
  }

  chdir("$temp_dir/install")
    or die
      "[ERROR]: cd to $temp_dir/install failed.\n"
      . "  Does your $temp_dir/install directory exist?\n"
      . "  Exiting.\n";

  # Install system tables.
  print "[" . print_timestamp() . "]: Installing system tables.\n";
  qx(bin/mysql_install_db --no-defaults --basedir=$temp_dir/install --datadir=$mariadb_datadir);

  my $mariadb_socket = "$temp_dir/mysql.sock";

  # Determine mysqld version for result file naming.
  my $mariadb_version = qx(libexec/mysqld --version | awk '{ print $3 }');

  print "[" . print_timestamp() . "]: Starting sql-bench run for $compile_config, ...\n";

  # Run sql-bench test configurations in a loop.
  my $current_dir = '';
  my $output_dir =  '';

  opendir(DIR, $compile_config);
  my @sql_bench_tests = grep(/\.sqlbt$/, readdir(DIR));
  closedir(DIR);

  foreach my $sql_bench_test_file (@sql_bench_tests) {
    require $compile_config . '/' . $sql_bench_test_file;

    my $current_sql_bench_test_name = basename($sql_bench_test_file, ".sqlbt");
    $current_mysqld_start_options = "";
    $current_sql_bench_options = "";
    $current_mysqld_init_command = "";

    foreach my $test_name (keys %{$sql_bench_test}) {
      $current_mysqld_start_options = $sql_bench_test->{$current_sql_bench_test_name}->{mysqld_start_options};
      $current_mysqld_init_command = $sql_bench_test->{$current_sql_bench_test_name}->{mysqld_init_command};
      $current_sql_bench_options = $sql_bench_test->{$current_sql_bench_test_name}->{sql_bench_options};
    }

    if ($debug eq 'yes') {
      print "current_mysqld_start_options: $current_mysqld_start_options\n";
      print "current_mysqld_init_command: $current_mysqld_init_command\n";
      print "current_sql_bench_options: $current_sql_bench_options\n";
      print "\n";
    }

    print "[" . print_timestamp() . "]: Starting test configuration: $sql_bench_test_file\n";

    $current_sql_bench_options = "$current_sql_bench_options --socket=$mariadb_socket $cl_sql_bench_options";

    # Clear file system cache. This works only with Linux >= 2.6.16.
    # On Mac OS X we can use sync; purge.
    system "sync";
    system "purge";
    system "echo 3 | $sudo tee /proc/sys/vm/drop_caches";

    start_mysqld($mariadb_datadir, $temp_dir, $mariadb_socket, $current_mysqld_start_options, $current_mysqld_init_command);

    chdir("$temp_dir/install/sql-bench")
      or die
        "[ERROR]: cd to sql-bench failed.\n"
        . "  Does your sql-bench directory exist?\n"
        . "  Exiting.\n";

    $current_dir = qx(pwd);
    chomp($current_dir);
    print "Current dir is: $current_dir\n";

    my $compile_config_name = basename($compile_config);
    $output_dir = "$sql_bench_results/$machine/$run_date/$compile_config_name/$sql_bench_test_file";
    qx($mkdir -p $output_dir);

    print "[" . print_timestamp() . "]: Running $perl run-all-tests $current_sql_bench_options --dir $output_dir --log\n";

    qx($perl run-all-tests $current_sql_bench_options --dir $output_dir --log);
    if ($? != 0)
    {
      print "[" . print_timestamp() . "][WARNING]: run-all-tests for $sql_bench_test_file produced errors.\n";
      print "  Please check your sql-bench error logs.\n";
    }

    print "[" . print_timestamp() . "]: Finished $sql_bench_test_file\n\n";

    print "[" . print_timestamp() . "]: Killing mysqld and installing system tables.\n";
    kill_mysqld($mariadb_datadir, $mariadb_socket, $temp_dir);
  }

  print "[" . print_timestamp() . "]: Finished sql-bench run for $compile_config!\n\n";
}

sub usage
{
  print "Please provide exactly three options.\n";
  print "  Example: $0 --repository=[/path/to/bzr/repository]\n";
  print "                              --sql-bench-options=[additional sql-bench-options]\n";
  print "                              --debug=[yes|no]\n";
  print "  --sql-bench-options is mostly used in testing and debugging cases,\n";
  print "  where we want to have short run times - for instance\n";
  print "  using --small-test or --small-table. You can separate\n" ;
  print "  several sql-bench-options with spaces like:\n";
  print "  --sql_bench_options=\"--small-test --small-table\"\n";

  exit 1;
}

sub print_timestamp
{
  my $now = qx(date "+%Y-%m-%d %H:%M:%S");
  chomp($now);
  
  return $now;
}

sub kill_mysqld
{
  my $mariadb_datadir = $_[0];
  my $mariadb_socket = $_[1];
  my $temp_dir = $_[2];
  
  qx(killall -9 mysqld);
  qx(rm -rf $mariadb_datadir);
  qx(rm -f $mariadb_socket);

  qx($mkdir $mariadb_datadir);

  # Install system tables.
  print "[" . print_timestamp() . "]: Installing system tables with following options:\n";
  print "  --no-defaults\n";
  print "  --basedir=$temp_dir/install\n";
  print "  --datadir=$mariadb_datadir\n";

  qx($temp_dir/install/bin/mysql_install_db --no-defaults --basedir=$temp_dir/install --datadir=$mariadb_datadir);
}

sub start_mysqld
{
  my $mariadb_datadir = $_[0];
  my $temp_dir        = $_[1];
  my $mariadb_socket  = $_[2];
  my $start_options   = $_[3];
  my $init_command    = $_[4];

  my $mariadb_options = "--no-defaults --log-error=$mariadb_datadir/mysqld.err --datadir=$mariadb_datadir --tmpdir=$temp_dir --socket=$mariadb_socket $start_options";
  my $mysql_options = "--no-defaults -uroot --socket=$mariadb_socket";
  my $mysqladmin_options = "--no-defaults -uroot --socket=$mariadb_socket";

  chdir("$temp_dir/install")
    or die
      "[ERROR]: cd to $temp_dir/install failed.\n"
      . "  Does your $temp_dir/install directory exist?\n"
      . "  Exiting.\n";

  print "[" . print_timestamp() . "]: Starting mysqld with following mariadb_options: $mariadb_options\n";
  system "$temp_dir/install/libexec/mysqld $mariadb_options &";

  my $j = 0;
  my $started = -1;
  while ($j < $timeout) {
    qx($temp_dir/install/$mysqladmin $mysqladmin_options ping > /dev/null 2>&1);
    if ($? == 0)
    {
      $started = 0;
      last;
    }

    sleep 1;
    $j++;
  }

  if ($init_command ne '')
  {
    print "[" . print_timestamp() . "]: Using following init command: $init_command \n";
    qx(echo "$init_command" | $temp_dir/install/$mysql $mysql_options);

    if ($? != 0)
    {
      print "[" . print_timestamp() . "][WARNING]: $init_command failed.\n";
      print "  Please check '$init_command'.\n";
    }
  }

  if ($started != 0)
  {
    print "[ERROR]: Start of mysqld failed.\n";
    print "  Please check your error log.\n";
    print "  Exiting.\n";

    exit 1;
  }

  print "[" . print_timestamp() . "]: Started mysqld!\n";
}
