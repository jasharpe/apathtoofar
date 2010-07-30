#!/usr/bin/perl -w

use strict;

use Getopt::Long;
use File::Path;

# mid folder should contain mid files to be processed
# output folder will contain .opt, .png and .txt files
my $mid_folder;
my $output_folder;
my $zip_folder = "zips";
my $mid_list;

# misc
my $verbose = 0;
# Basically just does the simplest path so stuff can be tested
my $debug = 0;

my $failure = GetOptions('folder=s' => \$mid_folder,
                         'outputfolder=s' => \$output_folder,
                         'zipfolder=s' => \$zip_folder,
                         'list=s' => \$mid_list,
                         'verbose' => \$verbose,
                         'debug' => \$debug);

if (!$mid_folder or !$output_folder) {
  die "\$mid_folder or \$output_folder was not specified at command-line!\n";
}

if (! -d $output_folder) {
  mkpath($output_folder) or die "Can't make path $output_folder: $!\n";
}

if (! -d $zip_folder) {
  mkpath($zip_folder) or die "Can't make path $zip_folder: $!\n";
}

# Standard settings for paths
my @swl = ([0,0,100], [0,0,0], [50,0,0], [50, 50,0], [80, 80,0], [100, 100,0]);
# Standard command to run. Arguments that must be provided are:
# * diff string
# * inst string
# * lazy whammy value
# * squeeze value
# * early whammy value
# * mid name
my $cmd_template = 'perl rbopt.pl -e -d %s -i %s --lazy %d --squeeze %d --whammy %d -p "%s" -o "%s" -g %s %s';

open(MIDLIST, $mid_list) or die "Can't open $mid_list: $!\n";
my %NAME_TO_GAME;
foreach my $entry (<MIDLIST>) {
  chomp $entry;
  my ($mid_name, $game) = $entry =~ /^(.*),(.*)$/;
  $NAME_TO_GAME{$mid_name} = $game;
}

opendir(MIDDIR, $mid_folder) or die "Can't open dir $mid_folder: $!\n";
foreach my $mid (grep { /\.mid$/ } readdir(MIDDIR)) {
  my ($mid_name) = $mid =~ /^(.*)\.mid$/;
  my $game = $NAME_TO_GAME{$mid_name};
  if (!$game) {
    die "No game corresponding to $mid_name!\n";
  }
  print "Starting song $mid_name\n" if $verbose;
  my $mid_output_folder = $output_folder."/$mid_name";
  if ($debug) {
    my $diff = 'Easy'; my $inst = 'Guitar'; my $lazy = 0; my $squeeze = 0; my $whammy = 0;
    my $cmd = sprintf($cmd_template, $diff, $inst, $lazy, $squeeze, $whammy, $mid_folder, $mid_output_folder, $game, $mid_name);
          system($cmd);
  } else {
    foreach my $inst (('Guitar', 'Bass')) {
      foreach my $diff (('Easy', 'Medium', 'Hard', 'Expert')) {
        foreach my $setting (@swl) {
          my ($squeeze, $whammy, $lazy) = @{$setting};
          print "Settings: $squeeze, $whammy, $lazy\n" if $verbose;
          my $cmd = sprintf($cmd_template, $diff, $inst, $lazy, $squeeze, $whammy, $mid_folder, $mid_output_folder, $game, $mid_name);
          system($cmd);
        }
      }
    }
  }

  use Archive::Zip qw(:ERROR_CODES :CONSTANTS);
  my $zipName = $mid_name.".zip";
  my $zip = Archive::Zip->new();
  warn "Couldn't add $mid_output_folder\n"
    if $zip->addTree($mid_output_folder, "") != AZ_OK;
  my $status = $zip->writeToFileNamed("$zip_folder/$zipName");
}
