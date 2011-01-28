#!/usr/bin/perl

# Run sql-bench for given configuration file with different
# configurations
# we find in the directory $SQL_BENCH_CONFIGS.
#
# Note: Do not run this script with root privileges.
#   We use killall -9, which can cause severe side effects!
#
# Hakan Kuecuekyilmaz, <hakan at askmonty dot org>, 2010-10-22.
use strict;
use Getopt::Long;
use File::Basename;

# The MariaDB tree to use and compile.
# We are also using the sql-bench directory from there.
my $repository;
# Additional sql-bench options, mostly for testing and
# debugging like --small-test.
my $cl_sql_bench_options;
my $help;

# Variables we read in from .sqlbt files.
my $current_mysqld_start_options;
my $current_mysqld_init_command;
my $current_sql_bench_options;

# Variables, which we are using for our configurations.
my $config_file;
our $config;
our $sql_bench_test;

# Variables, which we are using in our host specific configuration file.
our $sql_bench_results;
our $work_dir;
our $bzr;
our $mktemp;
our $mkdir;
our $make;
our $perl;

#
# Variables.
#
# We need at least 1 GB disk space in our $work_dir.
my $space_limit = 1000000;
my $mysqladmin_options = '--no-defaults';
my $machine = qx(/bin/hostname -s);
chomp($machine);
my $run_date = qx(date +%Y-%m-%d);
chomp($run_date);

# Timeout in seconds for waiting for mysqld to start.
my $timeout = 100;

# Paths we are using.
# Every directory except the con/ directory represents a
# compiler options/test combination we wan to run. If you
# a new compiler option scenario, then you add a directory
# with a descriptive name and add the sql-bench test versions
# you want to run. Every file ending on *.sqlbt represents a
# test version to run.
#
# If you want to run a new sql-bench test scenario for a
# given compiler option, then you add a file with a descriptive
# name ending with *.sqlbt to the compiler configuration
# directory of your choice.
#
# You can also overwrite the default MariaDB tree version,
# which is defined by a command line option of this script.
#
# Mind the run time of a sql-bench scenario which can vary
# from 30 minutes to 2 hours.
my @folders;
# Set this to your path to sql-bench/, which you checked output_dir
# with bzr. Mind the trailing /.
my $path = "/home/hakan/work/monty_program/mariadb-tools/sql-bench/";

#
# Binaries.
#
my $mysql = 'bin/mysql';
my $mysqladmin = 'bin/mysqladmin';

my $run_by = qx(whoami);
if ($run_by eq 'root')
{
  print '[ERROR]: Do not run this script as root!' . "\n";
  print '  Exiting.';

  exit 1;
}

#usage() if (@ARGV < 3
#            or !GetOptions('help|?' => \$help,
#                           'config-file=s' => \$config_file,
#                           'repository=s' => \$repository,
#                           'suffix=s' => \$suffix)
#            or defined $help);

usage() if (@ARGV < 2
            or !GetOptions('help|?' => \$help,
                           'repository=s' => \$repository,
                           'sql-bench-options=s' => \$cl_sql_bench_options)
            or defined $help);

sub usage
{
  print "Please provide exactly two options.\n";
  print "  Example: $0 --repository=[/path/to/bzr/repository]\n";
  print "                              --sql-bench-options=[additional sql-bench-options]\n";
  print "    sql-bench-options is mostly used for testing and debugging cases,\n";
  print "    where we want to have short run times - for instance\n";
  print "    using --small-test or --small-table.\n" ;

  exit 1;
}

# Read in every compiler option directory for iterating.
opendir(DIR, $path) or die "cant find $path: $!";
while (defined(my $file = readdir(DIR))) {
  next if $file =~ /^\.\.?$/;
    if (-d "$path$file" && $file ne "conf") {
      push @folders,"$path$file";
    }
}
closedir(DIR);

# Iterate over ever directory except conf/, read in compile.cnf and run
# every test we find in that directory.
foreach my $compile_config (@folders) {
  print "$compile_config\n";

  # Compile configuration specific config file.
  require $compile_config . '/compiler_' . $machine . '.cnf';

  # Host specific config file.
  require './conf/' . $machine . '.cnf';

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
    "[ERROR]: cd to $work_dir failed.\n";
    "  Does your $work_dir directory exists?\n";
    "  Exiting.\n";

  # Clean up of previous runs.
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

  # bzr export refuses to export to an existing directory,
  # therefore we use a build directory.
  my $now = qx(date "+%Y-%m-%d %H:%M:%S");
  chomp($now);
  print "[$now]: Exporting from $repository to $temp_dir/build\n";

  qx($bzr export --format=dir $temp_dir/build $repository);
  if ($? != 0)
  {
    print "[ERROR]: bzr export failed.\n";
    print "  Exiting.\n";

    exit 1;
  }

  $now = qx(date "+%Y-%m-%d %H:%M:%S");
  chomp($now);
  print "[$now]: Finished exporting from $repository to $temp_dir/build\n";

  $now = qx(date "+%Y-%m-%d %H:%M:%S");
  chomp($now);
  print "[$now]: Starting to compile, ...\n";

  chdir("$temp_dir/build")
    or die
    "[ERROR]: cd to $temp_dir/build failed.\n";
    "  Does your $temp_dir/build directory exists?\n";
    "  Exiting.\n";

  qx(BUILD/autorun.sh);
  if ($? != 0)
  {
    print "[ERROR]: BUILD/autorun.sh failed.\n";
    print "  Please check your development environment.\n";
    print "  Exiting.\n";

    exit 1;
  }

  # We need --prefix for running make install. Otherwise
  # mysql_install_db will not work properly.
  qx(./configure $config->{configure_line} --prefix=$temp_dir/install);
  if ($? != 0)
  {
    print "[ERROR]: ./configure $config->{configure_line} failed.\n";
    print "  Please check your '$config->{configure_line}'.\n";
    print "  Exiting.\n";

    exit 1;
  }

  qx($make);
  if ($? != 0)
  {
    print "[ERROR]: make failed.\n";
    print "  Please check your build logs.\n";
    print "  Exiting.\n";

    exit 1;
  }

  $now = qx(date "+%Y-%m-%d %H:%M:%S");
  chomp($now);
  print "[$now]: Finished compiling.\n";

  qx($make install);
  if ($? != 0)
  {
    print "[ERROR]: make install failed.\n";
    print "  Please check your build logs.\n";
    print "  Exiting.\n";

    exit 1;
  }

  chdir("$temp_dir/install")
    or die
    "[ERROR]: cd to $temp_dir/install failed.\n";
    "  Does your $temp_dir/install directory exists?\n";
    "  Exiting.\n";

  # Install system tables.
  qx(bin/mysql_install_db --no-defaults --basedir=$temp_dir/install --datadir=$mariadb_datadir);

  my $mariadb_socket = "$temp_dir/mysql.sock";

  # Determine mysqld version for result file naming.
  my $mariadb_version = qx(libexec/mysqld --version | awk '{ print $3 }');

  $now = qx(date "+%Y-%m-%d %H:%M:%S");
  chomp($now);
  print "[$now]: Starting sql-bench run for $compile_config, ...\n";

  # Run sql-bench test configurations in a loop.
  my $current_dir = '';
  my $output_dir =  '';

  #
  #$sql_bench_test->{'base'} = {
  #  mysqld_start_options => '',
  #  mysqld_init_command => '',
  #  sql_bench_options => '--comment="base test (with MyISAM)"',
  #};

  opendir(DIR, $compile_config);
  my @sql_bench_tests = grep(/\.sqlbt$/, readdir(DIR));
  closedir(DIR);

  foreach my $sql_bench_test_file (@sql_bench_tests) {
    require $compile_config . '/' . $sql_bench_test_file;

    #my $comments = "Revision used: $revision_id\nConfigure: $config->{configure_line}\nServer options: $mariadb_options";

    $mysqladmin_options = "$mysqladmin_options -uroot --socket=$mariadb_socket";

    my $current_sql_bench_test_name = basename($sql_bench_test_file, ".sqlbt");
    $current_mysqld_start_options = "";
    $current_sql_bench_options = "";
    $current_mysqld_init_command = "";

    foreach my $test_name (keys %{$sql_bench_test}) {
      $current_mysqld_start_options = $sql_bench_test->{$current_sql_bench_test_name}->{mysqld_start_options};
      $current_mysqld_init_command = $sql_bench_test->{$current_sql_bench_test_name}->{mysqld_init_command};
      $current_sql_bench_options = $sql_bench_test->{$current_sql_bench_test_name}->{sql_bench_options};
    }

    # For debugging.
    #print "current_mysqld_start_options: $current_mysqld_start_options\n";
    #print "current_mysqld_init_command: $current_mysqld_init_command\n";
    #print "current_sql_bench_options: $current_sql_bench_options\n";
    #print "\n";

    sub kill_mysqld
    {
      qx(killall -9 mysqld);
      qx(rm -rf $mariadb_datadir);
      qx(rm -f $mariadb_socket);

      qx($mkdir $mariadb_datadir);
      # Install system tables.
      qx($temp_dir/install/bin/mysql_install_db --no-defaults --basedir=$temp_dir/install --datadir=$mariadb_datadir);
    }

    sub start_mysqld($$)
    {
      my $start_options = shift;
      my $init_command = shift;

      my $mariadb_options = "--no-defaults --log-error=$mariadb_datadir/mysqld.err --datadir=$mariadb_datadir --tmpdir=$temp_dir --socket=$mariadb_socket";
      my $mysql_options = '--no-defaults';
      $mysql_options = "$mysql_options -uroot --socket=$mariadb_socket";

      $now = qx(date "+%Y-%m-%d %H:%M:%S");
      chomp($now);

      chdir("$temp_dir/install")
        or die
        "[ERROR]: cd to $temp_dir/install failed.\n";
        "  Does your $temp_dir/install directory exists?\n";
        "  Exiting.\n";

      print "[$now]: Starting mysqld with this mariadb_options: $mariadb_options\n";
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

      if ($current_mysqld_init_command != '')
      {
        $now = qx(date "+%Y-%m-%d %H:%M:%S");
        chomp($now);
        print "[$now]: Using this init command: $current_mysqld_init_command \n";
        qx(echo $current_mysqld_init_command  | $temp_dir/install/$mysql $mysql_options);

        if ($? != 0)
        {
          print "[WARNING]: $current_mysqld_init_command failed.\n";
          print "  Please check '$current_mysqld_init_command'.\n";
        }
      }

      if ($started != 0)
      {
        print "[ERROR]: Start of mysqld failed.\n";
        print "  Please check your error log.\n";
        print "  Exiting.\n";

        exit 1;
      }

      $now = qx(date "+%Y-%m-%d %H:%M:%S");
      chomp($now);
      print "[$now]: Started mysqld!\n";
    }

    $now = qx(date "+%Y-%m-%d %H:%M:%S");
    chomp($now);
    print "[$now]: Starting test configuration: $sql_bench_test_file\n";

    $current_sql_bench_options = "$current_sql_bench_options --socket=$mariadb_socket $cl_sql_bench_options";

    start_mysqld($current_mysqld_start_options, $current_mysqld_init_command);

    chdir("$temp_dir/install/sql-bench")
      or die
      "[ERROR]: cd to sql-bench failed.\n";
      "  Does your sql-bench directory exists?\n";
      "  Exiting.\n";

    $current_dir = qx(pwd);
    chomp($current_dir);
    print "Current dir is: $current_dir\n";

    my $compile_config_name = basename($compile_config);
    $output_dir = "$sql_bench_results/$machine/$run_date/$compile_config_name/$sql_bench_test_file";
    qx($mkdir -p $output_dir);

    print "$perl ./run-all-tests $current_sql_bench_options --dir $output_dir --log\n";

    qx($perl ./run-all-tests $current_sql_bench_options --dir $output_dir --log);
    if ($? != 0)
    {
      print "[WARNING]: run-all-tests for $sql_bench_test_file produced errors.\n";
      print "  Please check your sql-bench error logs.\n";
    }

    kill_mysqld();

    $now = qx(date "+%Y-%m-%d %H:%M:%S");
    chomp($now);
    print "[$now]: Finished $sql_bench_test_file\n";
  }

  $now = qx(date "+%Y-%m-%d %H:%M:%S");
  chomp($now);
  print "[$now]: Finished sql-bench run for $config_file!\n";
}