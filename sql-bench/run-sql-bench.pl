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
my ($config_file);
my ($repository);
my ($suffix);
my ($help);

# Variables, which we are using in our configuration file.
our ($config);
our ($sql_bench_test);

# Config file we read.
# TODO: Make the config file a parameter.
#my $config_file = './conf/sql-bench-base.cnf';

#
# Directories.
#
my $sql_bench_results='/home/hakan/sql-bench-results';
my $work_dir='/tmp';

#
# Variables.
#
# We need at least 1 GB disk space in our $work_dir.
my $space_limit=1000000;
my $mysqladmin_options='--no-defaults';
my $machine=qx(hostname);
my $run_date=qx(date +%Y-%m-%d);

# Timeout in seconds for waiting for mysqld to start.
my $timeout=100;

#
# Binaries.
#
my $bzr='/usr/local/bin/bzr';
#my $bzr='/usr/bin/bzr';
my $mysqladmin='bin/mysqladmin';

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
  exit;
}

require $config_file;

#
# For debugging the config file parsing.
#
#foreach my $key (keys %{$config}) {
#    print "The value of $key is $config->{$key}\n";
#}

print "\n";

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

#
# Check system.
#
# We should at least have $space_limit in $workdir.
my $available=qx(df $work_dir | grep -v Filesystem | awk '{ print \$4 }');

if ($available < $space_limit)
{
  print "[ERROR]: We need at least $space_limit space in $work_dir.";
  print 'Exiting.';

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
  print "Exiting.\n";

  exit 1;
}

chdir($work_dir)
  or die
  "[ERROR]: cd to $work_dir failed.\n";
  "  Does your $work_dir directory exists?\n";
    "  Exiting.\n";

# Clean up of previous runs.
qx(killall -9 mysqld);

#my $temp_dir = qx(mktemp --directory);
# For Mac OS X.
$ENV{'TMPDIR'} = "/tmp";
my $temp_dir = qx(/sw/sbin/mktemp -d);
if ($? != 0)
{
  print "[ERROR]: mktemp in $work_dir failed.\n";
  print "  Exiting.\n";

  exit 1;
}

# Get rid of any newline.
chomp($temp_dir);

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
# mysql_install_db does not work properly.
qx(./configure $config->{configure_line} --prefix=$temp_dir/install);
if ($? != 0)
{
  print "[ERROR]: ./configure $config->{configure_line} failed.\n";
  print "  Please check your $config->{configure_line}.\n";
  print "  Exiting.\n";

  exit 1;
}

qx(make -j4);
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

qx(make install);
if ($? != 0)
{
  print "[ERROR]: make install.\n";
  print "  Please check your build logs.\n";
  print "  Exiting.\n";

  exit 1
}

chdir("$temp_dir/install")
  or die
  "[ERROR]: cd to $temp_dir/install failed.\n";
  "  Does your $temp_dir/install directory exists?\n";
    "  Exiting.\n";

# Install system tables.
qx(bin/mysql_install_db --no-defaults --basedir=$temp_dir/install --datadir=$temp_dir/data);

# Start mysqld.
$now = qx(date "+%Y-%m-%d %H:%M:%S");
chomp($now);
print "[$now]: Starting mysqld, ...\n";

my $mariadb_socket = "$temp_dir/mysql.sock";
my $mariadb_options = '';
$mariadb_options = "$mariadb_options --datadir=$temp_dir/data --tmpdir=$temp_dir --socket=$mariadb_socket";

$mysqladmin_options = "$mysqladmin_options --socket=$mariadb_socket";

# Determine mysqld version for result file naming.
my $mariadb_version = qx(libexec/mysqld --version | awk '{ print $3 }');
$suffix = "$suffix" . "-" . "$mariadb_version";

system "libexec/mysqld $mariadb_options &";

my $j = 0;
my $started = -1;
while ($j < $timeout) {
  qx($mysqladmin $mysqladmin_options -uroot ping > /dev/null 2>&1);
  if ($? == 0)
  {
    $started = 0;
    last;
   }
   
   sleep 1;
   $j++;
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

$now = qx(date "+%Y-%m-%d %H:%M:%S");
chomp($now);
print "[$now]: Starting sql-bench run, ...\n";

# Run sql-bench tests configurations in a loop.
chdir("sql-bench")
  or die
  "[ERROR]: cd to sql-bench failed.\n";
  "  Does your sql-bench directory exists?\n";
  "  Exiting.\n";

#my $comments = "Revision used: $REVISION_ID\nConfigure: $mariadb_config\nServer options: $mariadb_options";

# TODO: Add --comments="$comments".
#my $sqlbench_options = "$sqlbench_options --socket=$mariadb_socket --suffix=$suffix";
#my $sqlbench_options = "--socket=$mariadb_socket --suffix=$suffix";
my $sqlbench_options = "--socket=$mariadb_socket";

#qx(./run-all-tests $sqlbench_options);
print "/sw/bin/perl ./run-all-tests $sqlbench_options\n";

qx(/sw/bin/perl ./run-all-tests $sqlbench_options);
if ($? != 0)
{
  print "[ERROR]: run-all-tests produced errors.\n";
  print "  Please check your sql-bench error logs.\n";
  print "  Exiting.\n";

  exit 1;
}

$now = qx(date "+%Y-%m-%d %H:%M:%S");
chomp($now);
print "[$now]: Finished sql-bench!\n";
