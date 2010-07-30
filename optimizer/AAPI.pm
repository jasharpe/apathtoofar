###############################################################################
#
# AAPI.pm
#
# Copyright 2009, Jeremy Sharpe
#
# Created by: Jeremy Sharpe
#
# Contains web access functions and functions related to ajanata's API (hence
# the name).
#
###############################################################################

package AAPI;

use HTTP::Request;
use HTTP::Headers;
use LWP::UserAgent;
use LWP::Simple;
use File::Path;
use Misc;
use strict;

my $CHARTGEN_URL = 'http://static.socialgamer.net/~ajanata/phpspopt/web/chartgenapi.php';

my %SH =
  ('diff' => {'expert' => 4, 'hard' => 3, 'medium' => 2, 'easy' => 1},
   'inst' => {'guitar' => 1, 'bass' => 2, 'drums' => 3, 'vocals' => 4});

# searches for midi files
sub find_mid {
  my ($midname, $game, $middir) = @_;

  if (!$middir) {
    $middir = "mid";
  }

  # if they didn't give us a $game to look in just search them all
  if (opendir(MIDDIR, $middir)) {
    foreach my $dir (grep {!/\.|\.\./} readdir MIDDIR) {
      if(-e "$middir/$dir/$midname.mid") {
        return $dir;
      }
    }
  }

  return 0;
}

# Creates an image path using ajanata's API. Arguments are the origin file
# describing the path, the destination file, and the url that is queried.
sub create_path_img {
  my ($orig, $dest, $game, $inst, $diff, $title) = @_;

  my $url = "$CHARTGEN_URL?game=".lc($game)."\&".lc($inst)."=".lc($diff)."\&file=".lc($title);

  my $content = get_file_contents($orig);

  my $header = HTTP::Headers->new;
  $header->header('Content-Type' => 'application/octet-stream');
  my $r = HTTP::Request->new("POST", $url, $header, $content);

  my $ua = LWP::UserAgent->new;
  my $response = $ua->request($r, $dest);
  return $response;
}

# Returns the contents of a file, in binary. Not good for huge files, but fine
# for the small text files that we're uploading.
sub get_file_contents {
  my ($file) = @_;
  open(FILE, $file) or die "Can't read $file: $!";
  binmode(FILE);
  my $contents = '';
  my $buffer;
  while(read(FILE, $buffer, 65536)) {
    $contents .= $buffer;
  }
  return $contents;
}

1;
