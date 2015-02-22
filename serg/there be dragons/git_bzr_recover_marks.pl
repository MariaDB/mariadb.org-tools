#!/usr/bin/perl

use autodie;

open(M, '<', 'missing.log');
open(G, '>', 'git.log');
open(O, '>', 'out.log');
open(E, '>', 'err.log');
while (<M>) {
  chomp;
  my ($mark, $revid) = /^:(\d+) (\S+)$/ or die;
  my $bzr = `bzr log -l1 -r $revid /home/serg/Abk/mysql/10.0`;
  unless ($bzr =~ /\w/) {
    print E "bad: $mark $revid\n";
    warn "bad: $mark $revid\n";
    next;
  }

  die "$bzr " unless $bzr =~ /\nmessage:\n  (.*)\n/;
  my $bzrmessage = "\Q$1";
  $bzrmessage =~ s/\\([()+|<>'])/\1/g; # fix after \Q

  die "$bzr " unless $bzr =~ /\ntimestamp: .* \d\d:(\d\d:\d\d) /;
  my $bzrminsec = $1;

  my $bzrbranch = "5.5";
  $bzrbranch = $1 if $bzr =~ /\nbranch nick: (\S+)\n/;

  my $gitbranch = '10.0';
  for (qw(10.0 5.5 10.0-galera 5.5-galera)) {
    $gitbranch = $_ if $bzrbranch =~ /\Q$_/;
  }

  warn "\e[1mgit log --grep=\"^$bzrmessage\" origin/$gitbranch\e[0m\n";
  my $git = `git log --grep="^$bzrmessage" origin/$gitbranch`;

#  unless ($git) {
#    print "$bzr\n>>> ";
#    my $commit=<STDIN>;
#    $git = `git log -n1 $commit`;
#  }
  my (undef, @commits)= split /^commit /m, $git;
  my $found=0;
  for (@commits) {
    die "$git <<$_>>" unless /\nDate: .* \d\d:(\d\d:\d\d) /;
    if ($1 eq $bzrminsec) {
      $found++;
      my ($commit) = /^(\w+)/;
      print G ":$mark $commit\n";
      print O '=' x 60, "\ncommit $_$bzr";
      print ":$mark $revid => $commit\n";
    }
  }
  print E "$found:found: $mark $revid\n" unless $found == 1;
  warn "$found:found: $mark $revid" unless $found == 1;
}
