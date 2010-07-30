###############################################################################
#
# AAPIOutput.pm
#
# Created by: Nic Wolfe
#
# Outputs path in a format suitable for upload to ajanata's API.
#
###############################################################################

package AAPIOutput;

# inherit from PathOutput
use PathOutput;
our @ISA = qw(PathOutput);

use strict;
use AAPIUser;
use AAPI;
use Digest::MD5 qw(md5_hex);

sub new {
  my ($class) = @_;

  # call the constructor of the parent class
  my $self = $class->SUPER::new();

  # print to screen by default
  $self->{_outref} = undef;

  bless $self, $class;
  return $self;
}

# accessor for outref
sub outref {
  my ($self, $outref) = @_;

  $self->{_outref} = $outref if $outref;

  return $self->{_outref};

}

# return the filename plus our extension
sub resultsfilename {
  my ($self, $resultsfilename) = @_;

  return $self->SUPER::resultsfilename."png";
}

# return the filename plus our extension
sub tempresultsfilename {
  my ($self, $tempresultsfilename) = @_;

  return $self->SUPER::resultsfilename."aapi";
}

sub createoutputfile {
  my ($self) = @_;

  $self->SUPER::createoutputfile;

  # find out where to write
  my $outfile = $self->SUPER::tmppath.$self->tempresultsfilename;

  # open the file for writing
  open(OUTPUT, "> $outfile") or die "Can't open $outfile: $!";
  $self->{_outref} = *OUTPUT;

}

sub buildpath {
  my ($self, @Ticks) = @_;

  my $measure = 0;
  my $ticksinmeasure = 0;
  my $tickssincelastmeasure = 0;

  my $currently_activated = 0;

  my $activation_start_tick = 0;
  my $OD_start_tick = 0;
  my $activated_OD_start_tick = 0;
  my $nowhammy_start_tick = 0;

  my $activated_OD_string = "";
  my $activation_string = "";
  my $early_whammy_string = "";
  my $squeezing_string = "";
  my $nowhammy_string = "";
  my $diff_string = "";

  my @Path = ();
  my $overlap = 0;
  my $phrases = 0;
  my $activated = 0;
  my $activatedlasttick = 0;
  my $ticknum = 0;

  foreach my $tick (@Ticks) {
    my %TICK = %{$tick};
    my %NEXTTICK = %{$Ticks[($ticknum + 1) % @Ticks]};
    my %LASTTICK = %{$Ticks[Misc::min(1, $ticknum - 1)]};
    if($activated and !$TICK{activated} and !$TICK{squeezing} and !($LASTTICK{activated} && $NEXTTICK{squeeze})) {
      push(@Path, "$phrases".($overlap?"($overlap)":""));
      $overlap = 0;
      $phrases = 0;
    }
    $activated = $TICK{activated} || $TICK{squeezing} || ($LASTTICK{activated} && $NEXTTICK{squeeze});
    if($TICK{endOD} and $activated) {
      $overlap++;
    } elsif($TICK{endOD}) {
      $phrases++;
    }
    $ticknum++;
  }

  my $path = join("-", @Path);

  my %AAPIColours = (
    activation => "184 197 232",
    nowhammy => "228 120 37",
    earlywhammy => "255 151 178",
    text => "0 0 0", # black
    ODPhrase => "186 240 120",
    squeeze => "255 178 217",
    rsqueeze => "255 0 255"
  );
  my $AAPI_CHART_NOTE_HEIGHT = 12;

  my $songtitle = $self->songtitle;
  my $diff = $self->diff;
  my $inst = $self->inst;
  my $lazy = $self->lazy;
  my $squeeze = $self->squeeze;
  my $whammy = $self->whammy;

  # set up username
  print {$self->outref} "user " . AAPIUser::get_user() . " " . md5_hex(AAPIUser::get_key() . $songtitle)."\n";

  # set up options
  print {$self->outref} "option shift 100\n";

  # set up colours
  print {$self->outref} "coloralpha activation $AAPIColours{activation}\n";
  print {$self->outref} "colorname activation Activation\n";
  print {$self->outref} "coloralpha odphrase $AAPIColours{ODPhrase}\n";
  print {$self->outref} "colorname odphrase Overrun OD Phrase\n";
  print {$self->outref} "coloralpha whammy $AAPIColours{earlywhammy}\n";
  print {$self->outref} "coloralpha nowhammy $AAPIColours{nowhammy}\n";
  print {$self->outref} "coloralpha squeeze $AAPIColours{squeeze}\n";
  print {$self->outref} "coloralpha rsqueeze $AAPIColours{rsqueeze}\n";
  print {$self->outref} "coloralpha text $AAPIColours{text}\n";

  my $i;
  my $measurewhammy = 0;
  my @diffarr = ();
  for($i = 0; $i < @Ticks; $i++) {
    my %TICK = %{$Ticks[$i]};

    # Update $measure
    $tickssincelastmeasure++;
    if($tickssincelastmeasure > $ticksinmeasure) {
      $measure++;
      if (@diffarr) {
        $diff_string .= "string 2 text ".(($i-$ticksinmeasure)*40+1)." 0 ".lc($inst)." ".join(", ", @diffarr)."\n";
      }
      @diffarr = ();
      $tickssincelastmeasure = 1;
      $ticksinmeasure = $TICK{timesig}{num} * 12 * 4 / $TICK{timesig}{den};
    }

    # This section is entered at the beginning of every measure.
    if($tickssincelastmeasure == 1) {

      # draw the measure's scores
      if ($measure > 1) {
        #print {$self->outref} "measscore $inst ".($measure-1)." $Ticks[$i - 1]->{score}\n";
        print {$self->outref} "totalscore $inst ".($measure-1)." $Ticks[$i - 1]->{ODscore}\n";
        my $measurewhammybeats = sprintf("%.3f", $measurewhammy / 12);
        if ($measurewhammy > 0) {
          print {$self->outref} "whammy $inst ".($measure-1)." $measurewhammybeats\n";
        }
        
        $measurewhammy = 0;
      }

    }

    my @Notes = @{$TICK{notes}};

    # Squeeze difficulties
    if ($TICK{earlywhammydiff}) {
      push(@diffarr, "EW: $TICK{earlywhammydiff}%");
    }
    if ($TICK{squeezediff}) {
      push(@diffarr, "S: $TICK{squeezediff}%");
    }
    if ($TICK{rsqueezediff}) {
      push(@diffarr, "RS: $TICK{rsqueezediff}%");
    }

    # Increment whammy
    if ($TICK{dowhammy}) {
      $measurewhammy += $TICK{realwhammy};
    }

    # paint squeezes
		if ($TICK{squeeze} > 0) {
      $squeezing_string .= "fill $inst squeeze ".(($i*40)-20)." ".((($i+$TICK{squeeze}-1)*40)+20)." 5\n";
    }

    # paint reverse squeezes
		if ($TICK{rsqueeze} > 0) {
			if ($TICK{activate}) {
				$squeezing_string .= "fill $inst rsqueeze ".((($i-$TICK{rsqueeze}+1)*40)-20)." ".(($i*40)+20)." 5\n";
			} else {
				$squeezing_string .= "fill $inst rsqueeze ".((($i+1)*40)-20)." ".(((($i+1)+$TICK{rsqueeze}-1)*40)+20)." 5\n";
			}
    }

    # remember where the start of a no-whammy is
    if (!$TICK{dowhammy} && $TICK{whammyable} and $TICK{sustain} and $TICK{OD} and $nowhammy_start_tick == 0) {
      $nowhammy_start_tick = $i;

    # if we're not whammying and we start again or the sustain ends then this is the end of a nowhammy line
    } elsif ( (!$TICK{sustain} or ($TICK{dowhammy} and $TICK{sustain} and $TICK{OD})) and $nowhammy_start_tick > 0) {
      $nowhammy_string .= "fill $inst nowhammy ".(($nowhammy_start_tick*40)-20)." ".(($i*40)+20)." 5\n";
      $nowhammy_start_tick = 0;
    }

    
    # ajanata's API: print early whammy
    if ($TICK{earlywhammy} > 0) {
      $early_whammy_string .= "fill $inst whammy ".($i*40-$TICK{earlywhammy}*40)." ".($i*40)." 5\n";
      $measurewhammy += $TICK{earlywhammy};
    }

    # if we're not activated and we used to be, activation just ended
    if (!$TICK{activated} and $currently_activated) {

      # print the activation fill
      $activation_string .= "fill $inst activation ".(($activation_start_tick*40)-20)." ".((($i-1)*40)+20)." 5\n";
      $activation_start_tick = 0;

      # if we are in the middle of an OD phrase, draw the bg fill for the part phrase
      if ($activated_OD_start_tick != 0) {
        $activated_OD_string .= "fill $inst odphrase ".(($activated_OD_start_tick*40)-20)." ".((($i-1)*40)+20)." 5\n";
        $activated_OD_start_tick = 0;
      }

      $currently_activated = 0;
        
    # if we're activating on this tick
    } elsif ($TICK{activated} && !$currently_activated) {

      # keep track of activation status
      $currently_activated = 1;

      # remember where the start of this activation is
      $activation_start_tick = $i;

      # if we're activating in the middle of an OD phrase then remember
      if ($OD_start_tick > 0) {
        $activated_OD_start_tick = $i;
        $OD_start_tick = 0;
      }

    }

    # if an OD phrase is starting during an activation 
    if ($TICK{note} && $TICK{OD} && $activated_OD_start_tick == 0 && $activation_start_tick > 0) {

      $activated_OD_start_tick = $i;

    # if an OD phrase is starting not during an activation
    } elsif ($TICK{note} && $TICK{OD} && $OD_start_tick == 0 && $activation_start_tick == 0) {

      $OD_start_tick = $i;

    }

    # if we're at the end of an OD phrase
    if ($TICK{endOD}) {
    
      # if we're activated then draw the activated OD fill
      if ($activated_OD_start_tick != 0) {
          $activated_OD_string .= "fill $inst odphrase ".(($activated_OD_start_tick*40)-20)." ".(($i*40)+20)." 5\n";
          $activated_OD_start_tick = 0;
      }

      $OD_start_tick = 0;
    
    }

  }

  print {$self->outref} "measscore $inst ".($measure)." $Ticks[-1]->{score}\n";
  print {$self->outref} "totalscore $inst ".($measure)." $Ticks[-1]->{ODscore}\n";
  print {$self->outref} $activation_string;
  print {$self->outref} $activated_OD_string;
  print {$self->outref} $early_whammy_string;
  print {$self->outref} $nowhammy_string;
  print {$self->outref} $squeezing_string;
  print {$self->outref} $diff_string;
  print {$self->outref} "string 5 text 0 60 Base score: $Ticks[-1]->{score}\n";
  print {$self->outref} "string 5 text 0 75 Estimated path score: $Ticks[-1]->{ODscore}\n";
  print {$self->outref} "string 5 text 0 90 Lazy: $lazy\%\n";
  print {$self->outref} "string 5 text 0 105 Squeeze: $squeeze\%\n";
  print {$self->outref} "string 5 text 0 120 Early whammy: $whammy\%\n";
  print {$self->outref} "string 5 text 0 135 Path summary: $path\n";
}

sub finishpath {
  my ($self) = @_;

  close($self->outref);

  my $imagefile = $self->resultspath.$self->resultsfilename;
  my $game = "rb";
  if ($self->game eq "brb" or $self->game eq "brbdlc") {
    $game = "tbrb";
  }
  AAPI::create_path_img($self->tmppath.$self->tempresultsfilename, $imagefile, $game, $self->inst, $self->diff, $self->songtitle);

  print "Wrote image path to $imagefile\n" if !$self->silent;

}


1;
