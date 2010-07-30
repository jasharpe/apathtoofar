#!/usr/bin/perl -w
use strict;

my $prefix = "../../media/mid/";
opendir(DIR, $prefix) or die "Can't open $prefix: $!";
open(OUTPUT, "> $ARGV[0]") or die "Can't open $ARGV[0]: $!";
#print join(',', readdir(DIR));
foreach my $dir (grep {-d $prefix.$_ && /brbdlc/} readdir(DIR)) {
  my $subdir = $prefix.$dir;
  opendir(SUBDIR, $prefix.$dir) or die "$!";
  foreach my $song (grep {!/^\.$|^\.\.$/ && /\.mid/} readdir(SUBDIR)) {
    $song =~ s/\.mid//;
    print OUTPUT "$song,$dir\n";
  }
}
close(OUTPUT);
