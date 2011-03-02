#! /usr/bin/perl

# Copyright (C) 2003,2008 MySQL AB
# Copyright (C) 2010 Sergei Golubchik and Monty Program Ab
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

# Run gcov and report test coverage on only those code lines touched by
# a given list of revisions.

use strict;
use warnings;

use Getopt::Long;
use File::Find;
use Cwd qw/realpath/;
use File::Basename;

my $verbose=0;
my $all_opt;
my $context= 3;
my $help;
my $purge_opt;
my $only_gcov_opt;
my $skip_gcov_opt;
my $local_opt;
my $uncommitted_opt;

my $result= GetOptions
  ("c|context=i"   => \$context,
   "a|all"         => \$all_opt,
   "v|verbose+"    => \$verbose,
   "h|help"        => \$help,
   "p|purge"       => \$purge_opt,
   "g|only-gcov"   => \$only_gcov_opt,
   "s|skip-gcov"   => \$skip_gcov_opt,
   "l|local"       => \$local_opt,
   "u|uncommitted" => \$uncommitted_opt,
  ) or exit;

usage() if $help;

#
# In verbose mode we output to STDERR as well as to STDOUT.
# Avoid misplaced output due to buffering.
#
if ($verbose) {
  select STDERR; $| = 1;      # make unbuffered
  select STDOUT; $| = 1;      # make unbuffered
}

my $troot= `bzr root`;
chomp $troot;
if (!$troot || !chdir $troot) {
    die "Failed to find tree root (this tool must be run within\n" .
        "a bzr work tree).\n";
} else {
  print STDERR "Chdir $troot\n" if $verbose;
}

my $res;
my $cmd;
if ($purge_opt or not $skip_gcov_opt)
{
  # One cannot create a file with empty name. But empty argument with -f
  # makes 'rm' silent when there is no file to remove.
  $cmd= "find . " .($purge_opt ? "-name '*.da' -o -name '*.gcda' -o " : "").
           "-name '*.gcov' -o -name '*.dgcov' | grep -v 'README\.gcov' | ".
           "xargs rm -f ''";
  print STDERR "Running: $cmd\n" if $verbose;
  $res= system($cmd);
  exit ($res ? ($? >> 8) : 0) if $res or $purge_opt;

  # gcov is difficult. source files might be in different places:
  # 1. in the same directory where the .o file is
  # 2. in include/ for headers
  # 3. elsewhere, symlinked
  # 4. elsewhere, if Makefile specifies a file from a different directory
  #
  # because of 2/3/4 one source file may have more than one .gcov file,
  # and even more than one .gcov file with the same name (like, include/my_sys.h
  # will have as many files with the name "sql/my_sys.h.gcov" as there are
  # .o files in the sql directory. these "sql/my_sys.h.gcov" files are
  # _different_ files with the same name, and different content)
  #
  # that's what we'll do here: delete all .gcov and .dgcov files (already done,
  # see above).  run gcov once per every .gcda file, grab all generated .gcov
  # files and aggregate them with the already existing .dgcov files for the
  # corresponding source files.
  #
  find(\&gcov_one_file, ".");

  exit 0 if $only_gcov_opt;
}

my @revisions = @ARGV;
if(@revisions == 0 && !$uncommitted_opt) {
  $local_opt= 1;
}

if($local_opt) {
  # Add revisions present in this tree only.
  my $cmd= "bzr missing --this";
  print STDERR "Running: $cmd\n"
      if $verbose;
  for $_ (`$cmd`)
  {
    next
        unless /^revno: (.*)/;
    push @revisions, $1;
    print STDERR "Added revision $1\n"
        if $verbose;
  }
}
die "No revision differences to check.\n"
    if (@revisions == 0 && !$uncommitted_opt);

my $filemap= {};
# First find all files and their revisions included in the list of revisions.
for my $cs (@revisions) {
  # getting the list of revisions
  my $cmd="bzr log --line -r '$cs'";
  $cs="$cs..$cs" unless $cs =~ /\.\./;
  my @revs=();
  print STDERR "Running: $cmd\n" if $verbose;
  print STDERR "." if !$verbose and -t STDERR;

  open PIPE, '-|', $cmd
      or die "Failed to spawn '$cmd': $!: $?\n";
  while(<PIPE>) {
    die "unexpected output from '$cmd': $_\n" unless /^(\d+):/;
    push @revs, $1;
  }
  close PIPE or die "subcommand '$cmd' failed: $!: $?\n";

  $cmd= "bzr status --short -r before:'$cs'";
  print STDERR "Running: $cmd\n" if $verbose;
  print STDERR "." if !$verbose and -t STDERR;

  open PIPE, '-|', $cmd
      or die "Failed to spawn '$cmd': $!: $?\n";
  while(<PIPE>) {
    die "unexpected output from '$cmd': $_\n" unless /^[- +RX?CP][ NDKM][ *] /;
    next unless /^( M|\+N). (.*)$/;
    my $file = $2;
    next unless -r "$file.dgcov";
    $filemap->{$file}{$_} = 1 for (@revs);
    printf STDERR "Added file $file for @revs\n" if $verbose;
  }
  close PIPE or die "subcommand '$cmd' failed: $!: $?\n";
}
print STDERR "\n" unless $verbose;

my $uncommitted_changes= { };
if($uncommitted_opt) {
  $uncommitted_changes= get_uncommitted_changes_unified();
}

# Next, run 'bzr annotate' and 'gcov' on the source files.
my $missing_files= 0;
my $total_lines= 0;
my $numfiles= 0;
my $uncovered= 0;
my $bad_anno_lines= 0;

for my $file (sort keys %$filemap) {
  my $cmd;
  my $lines = [ ];

  if (@revisions != 0) {
    $cmd= "bzr annotate --all '$file'";
    print STDERR "Running: $cmd\n" if $verbose;
    open PIPE, '-|', $cmd or die "Failed to spawn '$cmd': $!";
    my $linenum= 1;
    while(<PIPE>) {
      die "Unexpected source line '$_'\n"
          unless /^([.0-9]+)\??\s+[^|]+ \| (.*)$/;
      my ($rev, $text)= ($1, $2);
      # Push line number on list of touched lines if revision matches.
      if($filemap->{$file}{$rev}) {
        push @$lines, $linenum;
        ++$total_lines;
      }
      ++$linenum;
    }
    close PIPE
        or die "command '$cmd' failed: $!: $?\n";
  }
  $numfiles++;

  my $dgcov_file= "$file.dgcov";

  $lines= apply_diff_to_file($uncommitted_changes->{$file}, $lines)
    if -r $dgcov_file and $uncommitted_changes->{$file};

  # Skip if no lines actually touched in the file.
  next unless @$lines;

  # Remember previous N lines to be able to print context.
  my @prev= ( );
  # Print N more lines of context.
  my $pending= 0;

  $res= open FH, '<', $dgcov_file;
  if(!$res) {
    warn "Failed to open gcov output file '$dgcov_file'\n".
         "The file was never run yet ?\n";
    $missing_files++;
    die; # can that happen now ?
    next;
  }

  my ($mark, $lineno, $src, $full);
  my $did_header= undef;
  my $last_lineno= undef;

  my $printer= sub {
    unless($did_header) {
      print "\nFile: $file\n", '-' x 79, "\n";
      $did_header= 1;
    }
    print $_[0];
    $last_lineno= $lineno;
  };

  my $annotation= undef;

  while(<FH>) {
    next if /^function /;       # Skip function summaries.
    die "Unexpected line '$_'\n"
        unless /^([^:]+):[ \t]*([0-9]+):(.*)$/;
    ($mark, $lineno, $src, $full)= ($1, $2, $3, $_);

    # Check for source annotation for inspected/dead/tested code.
    if($src =~ m!/\*[ \t]+purecov[ \t]*:[ \t]*(inspected|tested|deadcode)[ \t]+\*/!) {
      $annotation= 'SINGLE';
    } elsif($src =~ m!/\*[ \t]+purecov[ \t]*:[ \t]*begin[ \t]+(inspected|tested|deadcode)[ \t]+\*/!) {
      $annotation= 'RUNNING';
    } elsif($src =~ m!/\*[ \t]+purecov[ \t]*:[ \t]*end[ \t]+\*/!) {
      warn "Warning: Found /* purecov: end */ annotation " .
           "not matched by begin.\n" .
           "         At line $lineno in '$file'.\n"
        unless defined($annotation) && $annotation eq 'RUNNING';
      $annotation= undef;
    } else {
      $annotation= undef if defined($annotation) && $annotation eq 'SINGLE';
    }

    shift @prev if @prev > $context;

    if(@$lines == 0 || $lineno < $lines->[0]) {
      # This line was not touched by any revision. But we might need
      # to print it as context.

      # For lines printed as context (not touched by any revision)
      # that are not covered, we make the ##### marker a little less
      # prominent.
      $full=~ s/^([ \t]*)\#\#\#\#\#:/"$1+++++:"/e;

      if ($pending > 0) {
        # Print as context for a previous line included in our revisions.
        die "Internal error: pending context to print, but \@prev non-empty"
          if @prev;
        $pending--;
        $printer->(".$full");
      } else {
        # Not printed now, so save it as context which may be needed later.
        push @prev, ".$full";
      }
    } else {
      # The line is included in our revision list.
      shift @$lines;

      # We need to print the line (and any previous context lines)
      # either if this line is not covered, or if it should be shown as
      # context for a previous printed line.
      # However, a purecov: annotation reverses this logic, so we will warn
      # about an annotated line that is actually covered by the test.
      if($mark =~ /\#\#\#\#\#/ && !defined($annotation)) {
        $uncovered++;
        # Make sure we print this line and following context lines.
        $pending= $context + 1;
      }
      if($mark =~ /^[ \t]*[0-9]+$/ && defined($annotation)) {
        $bad_anno_lines++;
        # Make sure we print this line and following context lines.
        $pending= $context + 1;
      }
      if($all_opt) {
        # In all_opt mode, all lines modified in revisions are printed.
        $pending= $context + 1;
      }
      if($pending > 0) {
        if(defined($last_lineno) && $last_lineno < $lineno - 1) {
          # Mark a gap in the printed file with an empty line.
          print "\n";
        }
        $printer->($_) for @prev;
        @prev = ( );
        $pending--;
        $printer->("|$full");
      } else {
        # Not printed now, so save it as context which may be needed later.
          push @prev, "|$full";
      }
    }
  }
  close FH;
  print "\n"
    if ($did_header);
}

print '-' x 79, "\n\n";
print "$total_lines line(s) in $numfiles source file(s) modified in revision(s).\n";
print "$uncovered line(s) not covered by tests.\n";
print "$bad_anno_lines line(s) with redundant purecov: annotations.\n"
    if $bad_anno_lines > 0;
print "$missing_files file(s) not processed with gcov.\n"
    if $missing_files;
print "For documentation, see http://forge.mysql.com/wiki/DGCov_doc\n";

exit ($uncovered > 0 || $bad_anno_lines > 0 ? 1 : 0);

###############################################################################

sub get_uncommitted_changes_simple {
  my $cmd= "bzr diff";
  print STDERR "Running: $cmd\n"
      if $verbose;
  open PIPE, '-|', $cmd
      or die "Failed to spawn '$cmd': $!";

  my $x= { };
  my $c= undef;

  while(<PIPE>) {
    if(/^===== (.*) [0-9]+\.[0-9]+(\.[0-9]+\.[0-9]+)? vs edited =====$/) {
      $c= [ ];
      $x->{$1}= $c;
      $filemap->{$1}{UNCOMMITTED}= 1
        unless exists($filemap->{$1});
      printf STDERR "Added file %-14s %s\n", "UNCOMMITTED", $1
          if $verbose;
    } elsif(/^([0-9]+)a([0-9]+),([0-9]+)$/) {
      # Append new lines $2-$3 after old line $1.
      push @$c, [a => $1, $2, $3];
    } elsif(/^([0-9]+)a([0-9]+)$/) {
      push @$c, [a => $1, $2, $2];
    } elsif(/^([0-9]+),([0-9]+)d([0-9]+)$/) {
      # Delete old lines $1-$2 after new line $3.
      push @$c, [d => $1, $2, $3];
    } elsif(/^([0-9]+)d([0-9]+)$/) {
      push @$c, [d => $1, $1, $2];
    } elsif(/^([0-9]+),([0-9]+)c([0-9]+),([0-9]+)$/) {
      # Change old lines $1-$2 to new lines $3-$4
      push @$c, [c => $1, $2, $3, $4];
    } elsif(/^([0-9]+)c([0-9]+),([0-9]+)$/) {
      push @$c, [c => $1, $1, $2, $3];
    } elsif(/^([0-9]+),([0-9]+)c([0-9]+)$/) {
      push @$c, [c => $1, $2, $3, $3];
    } elsif(/^([0-9]+)c([0-9]+)$/) {
      push @$c, [c => $1, $1, $2, $2];
    } elsif(/^([<>]|---)/) {
      # We are not interested in the actual diff content, just the
      # line numbers that were changed.
    } else {
      die "Unexpected output from '$cmd':\n$_";
    }
  }

  return $x;
}

sub get_uncommitted_changes_unified {
  my $cmd= "bzr diff --diff-options=-U0";
  print STDERR "Running: $cmd\n"
      if $verbose;
  open PIPE, '-|', $cmd
      or die "Failed to spawn '$cmd': $!";

  my $x= { };
  my $c= undef;

  while(<PIPE>) {
    # Ignore directories.
    if(/^=== added directory '(.*)'$/) {

      # Collect files.
    } elsif(/^=== (modified file|added file) '(.*)'$/) {
      $c= [ ];
      $x->{$2}= $c;
      $filemap->{$2}{UNCOMMITTED}= 1
        unless exists($filemap->{$2});
      printf STDERR "Added file %-14s %s\n", "UNCOMMITTED", $2
          if $verbose;

      # Ignore removed files.
    } elsif(/^=== (removed file) '(.*)'$/) {

      # Ignore file names.
    } elsif(/^(---|\+\+\+) ./) {

      # Collect changed lines. Ignore those with 0 lines changed.
      # Change old lines $1-$2 to new lines $3-$4
    } elsif(/^@@ [+-](\d+),(\d+) [+-](\d+),([1-9]\d*) @@/) {
      push @$c, [c => $1, $1+$2, $3, $3+$4];
    } elsif(/^@@ [+-](\d+) [+-](\d+),([1-9]\d*) @@/) {
      push @$c, [c => $1, $1, $2, $2+$3];
    } elsif(/^@@ [+-](\d+),(\d+) [+-](\d+) @@/) {
      push @$c, [c => $1, $1+$2, $3, $3];
    } elsif(/^@@ [+-](\d+) [+-](\d+) @@/) {
      push @$c, [c => $1, $1, $2, $2];

    } elsif(/^@@ /) {
      # Ignore diffs with 0 lines changed.

    } elsif(/^[ +-]|^$/) {
      # We are not interested in the actual diff content, just the
      # line numbers that were changed.
    } else {
      die "Unexpected output from '$cmd':\n$_";
    }
  }

  return $x;
}

sub apply_diff_to_file {
  my ($c, $l)= @_;
  my $i= 0;
  my $shift= 0;
  my $l_new= [ ];

  # Copy over line numbers, applying the diffs on the way.
  for my $d (@$c) {
    my $t= shift @$d;
    if($t eq 'a') {
      my ($old, $from, $to)= @$d;
      # Find the place to insert the lines.
      push @$l_new, $l->[$i++] + $shift && ++$total_lines
        while $i< @$l && $l->[$i] <= $old;
      push @$l_new, ($from .. $to);
      ++$total_lines;
      $shift+= ($to - $from + 1);
    } elsif($t eq 'd') {
      my ($from, $to, $new)= @$d;
      push @$l_new, $l->[$i++] + $shift && ++$total_lines
        while $i< @$l && $l->[$i] + $shift <= $new;
      # Skip any deleted lines.
      $i++
        while $i< @$l && $l->[$i] <= $to;
      $shift-= ($to - $from + 1);
    } elsif($t eq 'c') {
      my ($ofrom, $oto, $nfrom, $nto)= @$d;
      push @$l_new, $l->[$i++] + $shift && ++$total_lines
        while $i< @$l && $l->[$i] < $ofrom;
      $i++
        while $i< @$l && $l->[$i] <= $oto;
      push @$l_new, ($nfrom .. $nto);
      ++$total_lines;
      $shift= $shift - ($oto-$ofrom) + ($nto-$nfrom);
    } else {
      die "Internal?!?";
    }
  }
  push @$l_new, $l->[$i] + $shift
    while $i< @$l;
  return $l_new;
}

sub usage {
  print <<END;
Usage: $0 --help
       $0 [options] [revisionspec [revisionspec ...]]

The dgcov program runs gcov for code coverage analysis, and reports missing
coverage only for those lines that are changed by the specified revision(s).
Revisions are specified in any bzr supported format, as invidual revisions or
ranges.
If no revisions are specified, the default is to work on all unpushed
revisions (bzr missing --this).

Options:

  -h    --help        This help.
  -v    --verbose     Show commands run.
  -a    --all         All lines modified in revisions are printed.
  -c N  --context=N   Show N (default 3) lines of context around reported lines.
  -p    --purge       Delete all test coverage information, to prepare for a
                      new coverage test.
  -g    --only-gcov   Stop after running gcov, don't run bzr
  -s    --skip-gcov   Do not run gcov, assume .dgcov files are already in place
  -l    --local       Add revisions from 'bzr missing --this' (default if no
                      revisions given and not using -u).
  -u    --uncommitted Also consider changes not committed (slow).

Prior to running this tool, the analyzed program should be compiled with
-fprofile-arcs -ftest-coverage (for MySQL, BUILD/compile-pentium-gcov script
does just that), and the testsuite should be run. dgcov will report
all lines that are modified in the specified revisions and that are reported
as not covered by gcov.

Lines not covered are marked by '#####', lines without generated code are
marked with '-', and other lines are marked with the number of times they
were executed. See 'info gcov' for more information.

Lines modified by revisions are pre-fixed by '|', context lines not included
in the specified revisions are prefixed by '.'. Non-modified context lines
that are not covered by tests are marked with '+++++' instead of '#####'.

Reports of non-covered lines may be suppressed by 'purecov' annotations:

  inspected   For code that cannot be covered (like out of memory conditions),
              but which has been reviewed and is considered correct.
  deadcode    Unreachable code.
  tested      Code that is not covered by automatic tests, but which has been
              manually tested.

Annotations may be for a single line:

  if((p= malloc(10)) == NULL) return 0;   /* purecov: inspected */

or for a span of lines:

  /* purecov: begin deadcode */
  tmp= x;
  x= y;
  y= tmp;
  /* purecov: end */

Note that if annotated lines are actually covered, they will be reported as
errors as well (since the annotations are then clearly wrong).
END

  exit 1;
}

sub suck_in {
  no warnings 'numeric';
  my ($acc, $fh) = @_;
  while (<$fh>)
  {
    die "not a gcov file?" unless /^\s*(-|#+|-?\d+):\s*(\d+):/;
    my ($cnt, $line) = ($1, $2);
    next if $cnt eq '-';
    $cnt =~ s/^-//;
    $acc->[$line]+=$cnt;
  }
}

my $file_no=0;
sub gcov_one_file {
  return unless /\.gcda$/;
  my $ofile="$`.o";
  my $sourcepath;
  my $lastfile;

  $cmd= "gcov '$_'";
  print STDERR ++$file_no, "\r" if !$verbose and -t STDERR;
  print STDERR "Running: $cmd\n" if $verbose;
  my $res= system "$cmd 2>/dev/null >/dev/null";
  if($res) {
    warn "Failed to spawn '$_': $res: $!: $?\n".
         "The gcov report may be incomplete.\n";
    $missing_files++;
    die; # can that happen now ?
    return;
  }
  # now, read all generated files
  for my $file (<*.gcov>) {
    open FH, '<', $file;
    $_=<FH>;
    chomp;
    # first, we read the name or the source file from the .gcov file
    # that works pretty well for included headers
    warn "$File::Find::dir/$file does not start from a Source line ? Weird "
      unless /^\s+-:\s+0:Source:/;
    my $sourcefile=$';
    print STDERR "Looking for $sourcefile\n" if $verbose > 1;
    # remove .libs from the end of the path
    # for building dynamic libraries libtool puts .o files in the .libs/
    my $up="";
    $up = "../" if $File::Find::dir =~ /\/\.libs$/ and
                   $sourcefile !~ /^\//;
    # and resolve symlinks, we love symlinking sources so much!
    my $source=realpath($up.$sourcefile);
    unless ($source and -r $source) {
      # Hm, let's try to find the file in the same directory where the last
      # file was.
      # the only file that needs it is libmysqld/sql_yacc.yy.gcov
      $source=dirname($lastfile)."/".$sourcefile if $lastfile;
    }
    unless ($source and -r $source) {
      # still no cookie, time to try something new.
      # sometimes files are not symlinked, but specified in the Makefile with
      # a path, like file.o: ../foobar/file.c
      # in that case the ../foobar part is recorded in the .o file
      unless (defined $sourcepath) {
        $_=`readelf -wi $ofile|grep -m1 'DW_AT_name.*/' 2>/dev/null`;
        m!DW_AT_name\s*:\s*(?:\(.*\): )?(\S.*)/[^/]+\n! or
          die "error running 'readelf -wi $File::Find::dir/$ofile', no 'DW_AT_name.*/' found";
        print STDERR "Got the path '$1' with 'readelf -wi $File::Find::dir/$ofile'\n" if $verbose;
        $sourcepath=$1;
      }
      $source=realpath("$up$sourcepath/$sourcefile");
    }
    die "A source file $source for $File::Find::dir/$up$file does not exists"
      unless -r $source;

    unless ($source =~ /^$troot/o) {
      warn "Skipping $source\n";
      unlink $file;
      next;
    }
    $lastfile=$source;

    my @acc=();
    print STDERR "Reading: $File::Find::dir/$file\n" if $verbose;
    suck_in(\@acc, *FH);
    close FH;

    my $dgcov_file="$source.dgcov";
    if (-r $dgcov_file) {
      open (FH, '<', $dgcov_file);
      print STDERR "Adding: $dgcov_file\n" if $verbose;
      suck_in(\@acc, *FH);
      close FH;
    }

    open (F, '<', $source) or die "cannot read $source";
    open (FH, '>', $dgcov_file) or die "cannot write to $dgcov_file";
    print STDERR "Writing: $dgcov_file\n" if $verbose;
    while (<F>) {
      printf FH '%9s:%5s:%s',
        defined ($acc[$.]) ? $acc[$.]  || '#####' : '-',
        $., $_;
    }
    close FH;
    close F;
    unlink $file;
  }
}

