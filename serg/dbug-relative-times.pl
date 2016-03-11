#!/usr/bin/perl -p

# when the trace is generated with i:T
# replaces absolute timestamps with relative, since the last timestamp
# of the same thread

m/^(T@\d+) +: +(\d\d):(\d\d):(\d\d)\.(\d\d\d\d\d\d) / or next;

$cur = (($2*60+$3)*60+$4)*1000+$5;
$_=sprintf "%-7s: %6d %s", $1, $cur - $prev{$1}, $';
$prev{$1}=$cur;

