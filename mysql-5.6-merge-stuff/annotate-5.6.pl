#! /usr/bin/perl

# Annotate the list of pushes in MySQL-5.6 with useful info such as
# diff size, 5.5 merge, number of changesets merged, etc.

use strict;
use warnings;

use FileHandle;
use Data::Dumper;    # For debugging

# Max number of processes to spawn concurrently
my $parallelism= 8;

my $repo_55= $ENV{HOME} . '/my/mysql/5.5';
my $repo_56= $ENV{HOME} . '/my/mysql/mysql-server';
my $branch_tmpdir= $ENV{HOME} . '/my/mysql/tmp-annotate';

sub spawn {
  my ($argv, %options)= @_;

  my $fh= new FileHandle;
  my $pid= open $fh, '-|';
  die "fork() failed: $!\n"
      if !defined($pid);
  if (!$pid) {
    # Child
    if (exists($options{CHDIR})) {
      chdir $options{CHDIR} or die "chdir() failed: $!\n";
    }
    exec @$argv or die "exec() failed: $!\n";
  } else {
    # Parent
    return $fh;
  }
}


# Simple event-driven multi-programming framework.
# We have a hash of fileno that we read from, with event handler callbacks
# associated with each.

my $active_filenos = { };

sub event_loop {
  for (;;) {
    my $rin= '';
    my ($rout, $fileno, $doer);
    for (keys %$active_filenos) {
      vec($rin, $_, 1)= 1;
    }
    last if $rin eq '';
    my $n= select($rout= $rin, undef, undef, undef);
    die "select() returns $n: $!\n"
        unless $n;
    while (($fileno, $doer)= each %$active_filenos) {
      if (vec($rout, $fileno, 1)) {
        my $res= sysread $doer->{FH}, $doer->{BUF}, 16384, length($doer->{BUF});
        die "sysread() failed: $!\n"
            unless defined($res);
        if ($res) {
          my @a= split("\n", $doer->{BUF}, -1);
          for (my $i= 0; $i < @a - 1; $i++) {
            $doer->{CB}($a[$i]);
          }
          $doer->{BUF}= $a[-1];
        }
        if ($res == 0) {
          # EOF
          $doer->{CB}($doer->{BUF}) if $doer->{BUF} ne '';
          delete $active_filenos->{$fileno};
          $doer->{CB}(undef);
        }
      }
    }
  }
}

sub num_doers {
  return scalar(keys(%$active_filenos));
}

sub add_doer {
  my ($fh, $cb)= @_;
  $active_filenos->{fileno($fh)}= { FH => $fh, BUF => '', CB => $cb };
  #print STDERR "RUNNING: ", scalar(keys(%$active_filenos)), "\n";
}


#######################################################################

my $pushlist= [ ];
sub read_pushlist {
  my $cur;
#  open FH, '<', 'test-pushlist.txt'
  open FH, '<', '56-pushlist.txt'
      or die "open() failed: $!\n";
  while (<FH>) {
    if (/^\s*$/) {
      next;
    } elsif (/^\s+([^\s].*)$/) {
      if (exists($cur->{COMMENT})) {
        $cur->{COMMENT}.= " $1";
      } else {
        $cur->{COMMENT}= $1;
      }
    } elsif (/^M\s+(.*)$/) {
      $cur->{M_NOTE}= $1;
    } else {
      chomp;
      $cur= { REVID => $_ };
      push @$pushlist, $cur;
    }
  }
  close FH;
  print STDERR "Number of pushes: ", scalar(@$pushlist), "\n";
}

#######################################################################

my $hash_55_revids= { };
my $done_55_revids= undef;

# Grab all the revision ids in 5.5.
# Note that this is somewhat broken, there seems to be no full-proof
# way to distinguish an actual revid in the `bzr log` output from a
# similar-looking line in a commit message. However, in practice, this
# should be good enough.
sub get_55_revids {

  my $fh= spawn(['bzr', 'log', '--include-merges', '--short', '--show-ids',
                 $repo_55]);
  add_doer($fh, sub {
    my ($line)= @_;
    if (!defined($line)) {
      print STDERR "Number of changesets in 5.5: ", scalar(keys %$hash_55_revids), "\n";
      $done_55_revids= 1;
      schedule();
      return;
    }
    $hash_55_revids->{$1}= 1
        if $line =~ /^\s*revision-id:(.*)$/;
  });
}


my $hash_56_revinfo= { };
my $done_56_revinfo;

# Get useful info for all revision ids in 5.6
# (We only need it for the ones in the push list, but it is probably
# faster to parse the output of a single `bzr log` compared to asking
# for each one individually).
sub get_56_revinfo {

  my $fh= spawn(['bzr', 'log', '--include-merges', '--long', '--show-ids',
                 $repo_56]);
  my $cur;
  my ($indent, $indent_len);
  add_doer($fh, sub {
    my ($line)= @_;
    if (!defined($line)) {
      $hash_56_revinfo->{$cur->{REVID}} = $cur
          if defined($cur);
      print STDERR "Number of changesets in 5.6: ", scalar(keys %$hash_56_revinfo), "\n";
      $done_56_revinfo= 1;
      schedule();
      return;
    }

    if ($indent) {
      if (substr($line, 0, $indent_len) eq $indent &&
          $line ne "$indent  ------------------------------------------------------------") {
        $cur->{MSG}.= substr($line, $indent_len) . "\n";
        return;
      } else {
        # Unfortunately, it seems it is impossible in general to distinguish
        # a new changeset from a similar-looking part of a commit message.
        # And such possible confusions _does_ occur in practice in 5.6, f.ex.
        # revid: andrei.elkin@oracle.com-20110819130428-1u8szmg89f862bjc
        # We try to detect this by the omission of revid and parent; this
        # should work in practice, though we will cut the commit message
        # short in these cases.
        if (exists($cur->{REVID}) && @{$cur->{PARENT}}) {
          $hash_56_revinfo->{$cur->{REVID}} = $cur;
        }
        $cur= undef;
        $indent= undef;
      }
    }

    if ($line =~ /^\s*revno: ([.0-9]+)(\s+\[merge\])?$/) {
      $cur= { REVNO => $1, PARENT => [ ], MSG => '' };
      $cur->{MERGE}= 1 if $2;
    } elsif ($cur && $line =~ /^\s*revision-id: (.*)$/) {
      $cur->{REVID}= $1;
    } elsif ($cur && $line =~ /^\s*parent: (.*)$/) {
      my $parents= $cur->{PARENT};
      my $n= scalar(@$parents);
      push @$parents, $1
          if $n == 0 || ($n == 1 && $cur->{MERGE});
    } elsif ($cur && $line =~ /^\s*committer: (.*)$/) {
      $cur->{COMMITTER}= $1;
    } elsif ($cur && $line =~ /^\s*author: (.*)$/) {
      $cur->{AUTHOR}= $1;
    } elsif ($cur && $line =~ /^\s*timestamp: (.*)$/) {
      $cur->{TIMESTAMP}= $1;
    } elsif ($cur && $line =~ /^\s*branch nick: (.*)$/) {
      $cur->{NICK}= $1;
    } elsif ($cur && $line =~ /^\s*tags: (.*)$/) {
      $cur->{TAGS}= [split ', ', $1];
    } elsif ($cur && $line =~ /^(\s*)message:$/ &&
             exists($cur->{REVID}) && @{$cur->{PARENT}}) {
      $indent= $1 . '  ';
      $indent_len= length($indent);
    }
  });
}


my $diff_index= 0;

# Compute size of diff in a push.
sub spawn_diff {
  my $i= $diff_index++;
  my $a= $pushlist->[$i+1];
  my $b= $pushlist->[$i];
  my $revid1= $a->{REVID};
  my $revid2= $b->{REVID};
  my $info= $hash_56_revinfo->{$revid2};
  die "Hey, $revid2 not found in 5.6?!?\n"
      unless defined($info);
  # Find the revision we merge, add as M_NOTE (checking against any existing
  # M_NOTE), look up if this is a merge from 5.5.
  my $parents= $info->{PARENT};
  if ($info->{MERGE}) {
    die "Huh?!? $revid2 is a merge, but not two parents:\n". Dumper($info)
        unless @$parents == 2;
    my $mparent;
    if ($revid1 eq $parents->[0]) {
      $mparent= $parents->[1];
    } elsif ($revid1 eq $parents->[1]) {
      $mparent= $parents->[0];
    } else {
      die "Huh?!? $revid2 does not have $revid1 as parent\n";
    }
    die "Wrong M info for $revid2\n"
        if exists($b->{M_NOTE}) && $mparent ne $b->{M_NOTE};
    $b->{M_NOTE}= $mparent;
    $b->{MERGE55} = 1
        if exists($hash_55_revids->{$mparent});
  } else {
    die "Huh?!? Unexpected parents for $revid2:\n". Dumper($info)
        unless defined($parents) && @$parents == 1 && $parents->[0] eq $revid1;
  }
  # If we do not have a hand-crafted comment, build one from the commit msg.
  if (!exists($b->{COMMENT})) {
    my $c= $info->{MSG};
    $c =~ s/\n/|/gs;
    $c =~ s/\s+/ /g;
    $c =~ s/\|+/|/g;
    $c =~ s/\|+$//;
    if (length($c) > 80) {
      $c= substr($c, 0, 78);
      $c =~ s/\|+$//;
      $c.= '..';
    }
    $b->{COMMENT}= $c;
  }

  my $fh= spawn(['bzr', 'diff', "-rrevid:$revid1..revid:$revid2", $repo_56]);
  my $line_count= 0;
  add_doer($fh, sub {
    my ($line)= @_;
    if (defined($line)) {
      ++$line_count;
    } else {
      $b->{DIFFSIZE}= $line_count;
      #print STDERR "Diff size: $line_count\n";
      schedule();
    }
  });
  return 1;
}


#######################################################################

sub cleanup_tmpdir {
  system 'rm', '-Rf', $branch_tmpdir;
  mkdir $branch_tmpdir;
}

my $branch_index= 0;
# done_branch: exists-but-undef when branch started, true when done.
my $done_branch= { };

sub do_branch_revid {
  my ($revid)= @_;

  # Mark that branch is in progress.
  $done_branch->{$revid}= undef;
  my $fh= spawn(['bzr', 'branch', '--quiet', '--no-tree', "-rrevid:$revid",
                 $repo_56, $revid],
                CHDIR => $branch_tmpdir);
  add_doer($fh, sub {
    my ($line)= @_;
    # We can ignore output, we are only interested in when branch is done.
    return if defined($line);
    # Mark that branch is done.
    $done_branch->{$revid}= 1;
    #print STDERR "branched $revid\n";
    schedule();
  });
}

sub spawn_branch {
  for (;;) {
    return 0 if $branch_index >= @$pushlist - 1;
    my $revid= $pushlist->[$branch_index]{REVID};
    my $info= $hash_56_revinfo->{$revid};
    die "$revid not found in 5.6?!?" unless defined($info);
    if ($info->{MERGE}) {
      # Branch this revision if not done already ...
      if (!exists($done_branch->{$revid})) {
        do_branch_revid($revid);
        return 1;
      }
      # Branch previous revision if not done already ...
      my $revid2= $pushlist->[$branch_index+1]{REVID};
      if (!exists($done_branch->{$revid2})) {
        do_branch_revid($revid2);
        return 1;
      }
    }
    ++$branch_index;
  }
}

my $missing_index= 0;
sub spawn_missing {
  for (;;) {
    return 0 if $missing_index >= @$pushlist - 1;
    my $revid= $pushlist->[$missing_index]{REVID};
    my $info= $hash_56_revinfo->{$revid};
    die "$revid not found in 5.6?!?" unless defined($info);
    if ($info->{MERGE}) {
      my $idx= $missing_index;
      # Check if bzr has finished with the required branches.
      my $revid2= $pushlist->[$idx+1]{REVID};
      if (!$done_branch->{$revid} || !$done_branch->{$revid2}) {
        return 0;
      }
      my $fh= spawn(['bzr', 'missing', '--include-merges', '--line',
                     '--theirs-only', "../$revid"],
                    CHDIR => "$branch_tmpdir/$revid2");
      my $changeset_count= 0;
      add_doer($fh, sub {
        my ($line)= @_;
        if (defined($line)) {
          return if $line =~ /^You are missing/;
          ++$changeset_count;
          return;
        }
        # Note: this count includes the merge changeset itself. So
        # normally we will want to subtract one to get the number of
        # changesets actually merged.
        $pushlist->[$idx]{MERGE_COUNT}= $changeset_count;
        #print STDERR "$changeset_count changesets merged in $revid\n";
        schedule();
      });
      ++$missing_index;
      return 1;
    }
    ++$missing_index;
  }
}

#######################################################################

# When a job is done, call this to check for more jobs to start.
sub schedule {
  return if !$done_55_revids || !$done_56_revinfo;
  while (num_doers() < $parallelism) {
    my $spawned= 0;
    if ($branch_index < @$pushlist - 1) {
      $spawned+= spawn_branch();
    }
    if ($missing_index < @$pushlist - 1) {
      $spawned+= spawn_missing();
    }
    if ($diff_index < @$pushlist - 1) {
      $spawned+= spawn_diff();
    }
    if ($spawned == 0) {
      last;
    }
  }
}


#######################################################################

cleanup_tmpdir();

get_55_revids();
get_56_revinfo();

read_pushlist;

event_loop();

for (my $i= 0; $i < @$pushlist-1; $i++) {
  my $x= $pushlist->[$i];
  printf "%6d", $x->{DIFFSIZE};
  if (exists($x->{M_NOTE})) {
    printf "%5d", $x->{MERGE_COUNT}-1;
    if ($x->{MERGE55}) {
      print "*";
    } else {
      print " ";
    }
  } else {
    print " " x 6;
  }
  print " " x 5, $x->{REVID}, "\n";
  if (exists($x->{COMMENT})) {
    print ' ' x 13, $x->{COMMENT}, "\n";
  }
}
