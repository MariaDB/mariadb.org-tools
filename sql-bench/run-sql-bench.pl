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

# Parameters from the command line.
# The base configuration file.
my $config_file;

# The MariaDB tree to use and compile.
# We are also using the sql-bench directory from there.
my $repository;
my $suffix;
my $help;

# Variables, which we are using in our configuration file.
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
my $mysql_options = '--no-defaults';
my $mysqladmin_options = '--no-defaults';
my $machine = qx(/bin/hostname -s);
chomp($machine);
my $run_date = qx(date +%Y-%m-%d);
chomp($run_date);

# Timeout in seconds for waiting for mysqld to start.
my $timeout = 100;

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

usage() if (@ARGV < 3
            or !GetOptions('help|?' => \$help,
                           'config-file=s' => \$config_file,
                           'repository=s' => \$repository,
                           'suffix=s' => \$suffix)
            or defined $help);

sub usage
{
  print "Please provide exactly three options.\n";
  print "  Example: $0 --config-file=[/path/to/config/file] --repository=[/path/to/bzr/repository] --suffix=[name_without_spaces]\n";
  print "  [name_without_spaces] is used as identifier in the result file (--suffix).\n";

  exit 1;
}

# Base config file.
require $config_file;

# Host specific config file;
require './conf/' . $machine . '.cnf';

#
# For debugging the config file parsing.
#
#foreach my $key (keys %{$config}) {
#    print "The value of $key is $config->{$key}\n";
#}

#print "\n";

#foreach my $sql_bench_test_name (keys %{$sql_bench_test}) {
#    print "The value of $sql_bench_test_name is $sql_bench_test->{$sql_bench_test_name}\n";
#
#    foreach my $sql_bench_test_option (keys %{$sql_bench_test->{$sql_bench_test_name}}) {
#        print "The value of $sql_bench_test_name $sql_bench_test_option is $sql_bench_test->{$sql_bench_test_name}->{$sql_bench_test_option}\n";
#        print "\n";
#    }
#
#    print "\n";
#}
#my $now = '';
#foreach my $test_name (keys %{$sql_bench_test}) {
#  $now = qx(date "+%Y-%m-%d %H:%M:%S");
#  chomp($now);
#  print "[$now]: Starting $test_name\n";
#  print "\n";
#  print "mysqld_start_options: $sql_bench_test->{$test_name}->{mysqld_start_options}\n";
#  print "mysqld_init_command: $sql_bench_test->{$test_name}->{mysqld_init_command}\n";
#  print "sql_bench_options: $sql_bench_test->{$test_name}->{sql_bench_options}\n";
#  print "\n";
#}

#exit 1;

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
my $mariadb_options = "--no-defaults --datadir=$mariadb_datadir --tmpdir=$temp_dir --socket=$mariadb_socket";

$mysql_options = "$mysql_options -uroot --socket=$mariadb_socket";
$mysqladmin_options = "$mysqladmin_options -uroot --socket=$mariadb_socket";

# Determine mysqld version for result file naming.
my $mariadb_version = qx(libexec/mysqld --version | awk '{ print $3 }');
$suffix = "$suffix" . "-" . "$mariadb_version";

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

  $now = qx(date "+%Y-%m-%d %H:%M:%S");
  chomp($now);
  print "[$now]: Starting mysqld, ...\n";

  chdir("$temp_dir/install")
    or die
    "[ERROR]: cd to $temp_dir/install failed.\n";
    "  Does your $temp_dir/install directory exists?\n";
    "  Exiting.\n";

  $mariadb_options .= " $start_options";

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

  if ($init_command != '')
  {
    qx(echo $init_command | $temp_dir/install/$mysql $mysql_options);

    if ($? != 0)
    {
      print "[WARNING]: $init_command failed.\n";
      print "  Please check your '$init_command'.\n";
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
print "[$now]: Starting sql-bench run for $config_file, ...\n";

my $comments = "Revision used: $revision_id\nConfigure: $config->{configure_line}\nServer options: $mariadb_options";

# TODO: Add --comments="$comments".
#my $sql_bench_options = "--socket=$mariadb_socket --suffix=$suffix";

# Run sql-bench test configurations in a loop.

my $sql_bench_options = '';
my $current_dir = '';
my $output_dir =  '';
foreach my $test_name (keys %{$sql_bench_test}) {
  $now = qx(date "+%Y-%m-%d %H:%M:%S");
  chomp($now);
  print "[$now]: Starting test configuration: $test_name\n";

  start_mysqld($sql_bench_test->{$test_name}->{mysqld_start_options},
               $sql_bench_test->{$test_name}->{mysqld_init_command});

  $sql_bench_options = "$sql_bench_test->{$test_name}->{sql_bench_options} --socket=$mariadb_socket";

  chdir("$temp_dir/install/sql-bench")
    or die
    "[ERROR]: cd to sql-bench failed.\n";
    "  Does your sql-bench directory exists?\n";
    "  Exiting.\n";

  $current_dir = qx(pwd);
  chomp($current_dir);
  print "Current dir is: $current_dir\n";

  $output_dir = "$sql_bench_results/$machine/$run_date/$test_name";
  qx($mkdir -p $output_dir);

  print "$perl ./run-all-tests $sql_bench_options --dir $output_dir --log\n";

  qx($perl ./run-all-tests $sql_bench_options --dir $output_dir --log);
  if ($? != 0)
  {
    print "[WARNING]: run-all-tests for $test_name produced errors.\n";
    print "  Please check your sql-bench error logs.\n";
  }

  kill_mysqld();

  $now = qx(date "+%Y-%m-%d %H:%M:%S");
  chomp($now);
  print "[$now]: Finished $test_name\n";
}

$now = qx(date "+%Y-%m-%d %H:%M:%S");
chomp($now);
print "[$now]: Finished sql-bench run for $config_file!\n";
