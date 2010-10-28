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
my($config, $config_text, $sql_bench_test);
my $config_file = './conf/sql-bench-base.cnf';

my $run_by = qx(whoami);
if ($run_by eq 'root')
{
  print '[ERROR]: Do not run this script as root!' . "\n";
  print '  Exiting.';
   
  exit 1;
}

# TODO: rewrite to Perl syntax
#if ($# != 2) {
#    echo '[ERROR]: Please provide exactly two options.'
#    echo "  Example: $0 [/path/to/bzr/repository] [name_without_spaces]"
#    echo '  [name_without_spaces] is used as identifier in the result file (--suffix).'
#    
#    exit 1
#} else {
#    REPOSITORY="$1"
#    SUFFIX="-$2"
#}

open(CONF, $config_file) or die "unable to open config file '$config_file': $!";
read(CONF, my $config_text, -s $config_file);
eval ($config_text);

# Print a specific error if the config file is invalid,
# along with a line number.
die "Unable to load $config_file: $@" if $@;

# Here we will have $config->{hash_key1} containing 'hash_value1'.
# print $config->{configure_env};
# print "\n";
# print "\n";

# print $sql_bench_test['myisam']->{'mysqld_start_options'};
# print "\n";
# print "\n";

#
# For debugging the config file parsing.
#
foreach my $key (keys %{$config}) {
    print "The value of $key is $config->{$key}\n";
}

print "\n";

foreach my $sql_bench_test_name (keys %{$sql_bench_test}) {
    print "The value of $sql_bench_test_name is $sql_bench_test->{$sql_bench_test_name}\n";
    
    foreach my $sql_bench_test_option (keys %{$sql_bench_test->{$sql_bench_test_name}}) {
        print "The value of $sql_bench_test_name $sql_bench_test_option is $sql_bench_test->{$sql_bench_test_name}->{$sql_bench_test_option}\n";
        print "\n";
    }
    
    print "\n";
}
