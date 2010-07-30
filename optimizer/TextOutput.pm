###############################################################################
#
# TextOutput.pm
#
# Created by: Nic Wolfe
#
# Outputs path in a human-readable text format.
#
###############################################################################

package TextOutput;

# inherit from PathOutput
use PathOutput;
our @ISA = qw(PathOutput);

use strict;
use warnings;

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

  return $self->SUPER::resultsfilename."txt";
}

sub createoutputfile {
  my ($self) = @_;

  $self->SUPER::createoutputfile;

  # find out where to write
  my $outfile = $self->SUPER::resultspath.$self->resultsfilename;

  # open the file for writing
  open(OUTPUT, "> $outfile") or die "Can't open $outfile: $!";
  $self->{_outref} = *OUTPUT;
  #$self->{_outref} = *STDOUT;

}

sub buildpath {
  my ($self, @Ticks) = @_;

  my $measure = 0;
  my $ticksinmeasure = 0;
  my $tickssincelastmeasure = 0;

  my $last_note = "";
  my $last_note_tick = 0;
  my $currently_activated = 0;
  my %note_count = ();
  my %measure_note_count = ();
  my %OD_phrase_note_count = ();
  my $extra_OD_phrases = 0;
  my $OD_phrases = 0;
  my $cur_line = "";
  my %TextNotes = (0 => "G",
    1 => "R",
    2 => "Y",
    3 => "B",
    4 => "O");

  my $squeeze = $self->squeeze;
  my $songtitle = $self->songtitle;
  my $diff = $self->diff;
  my $inst = $self->inst;

  print {$self->outref} "Path for $songtitle $diff $inst\n";
  print {$self->outref} "Base Score: $Ticks[-1]->{score}\n";
  print {$self->outref} "Estimated Optimal Score: $Ticks[-1]->{ODscore}\n\n";

  my $i;
  for($i = 0; $i < @Ticks; $i++) {
    my %TICK = %{$Ticks[$i]};

    # Update $measure
    $tickssincelastmeasure++;
    if($tickssincelastmeasure > $ticksinmeasure) {
      $measure++;
      $tickssincelastmeasure = 1;
      $ticksinmeasure = $TICK{timesig}{num} * 12 * 4 / $TICK{timesig}{den};
    }

    # This section is entered at the beginning of every measure.
    if($tickssincelastmeasure == 1) {

      # Text
      %measure_note_count = ();
    }

    my @Notes = @{$TICK{notes}};

    my $cur_note = "";

    # check what note this tick is
    for(my $j = 0; $j < @Notes; $j++) {
      if ($Notes[$j] and $TICK{note}) {
        $cur_note .= $TextNotes{$j};
      }
    }

    # if the tick has any notes on it, then count it as a note
    if ($cur_note ne "") {
        $last_note = $cur_note;
        $last_note_tick = $i;

        if (!exists $note_count{$last_note}) {
            $note_count{$last_note} = 0;
        }

        if (!exists $measure_note_count{$last_note}) {
            $measure_note_count{$last_note} = 0;
        }

        $note_count{$last_note}++;
        $measure_note_count{$cur_note}++;
        
        # if it's in an OD phrase count it as such
        if ($TICK{OD}) {
            if (!exists $OD_phrase_note_count{$cur_note}) {
                $OD_phrase_note_count{$cur_note} = 0;
            }
            $OD_phrase_note_count{$cur_note}++;
        }
    }

    # if we're not activated and we used to be, activation just ended
    if (!$TICK{activated} and $currently_activated) {


#        print "Activation ended in measure $measure tick ".($i-1)." = ".(($i-1)*40)." ($extra_OD_phrases)\n";
        $currently_activated = 0;
        
        # add any extra OD phrases we pick up while activated
        if ($extra_OD_phrases ne 0) {
            $cur_line .= " [+$extra_OD_phrases]";
        }
        
        $cur_line .= "\n";

#        print $cur_line;
        print {$self->outref} $cur_line;
        
        $cur_line = "";
    
        # reset for next activation
#        print "resetting in measure $measure\n";
        $extra_OD_phrases = 0;
        $OD_phrases = 0;
    
    # if we're activating on this tick
    } elsif ($TICK{activate}) {

      # keep track of activation status
      $currently_activated = 1;

      # tell us how many OD phrases
      $cur_line = "$OD_phrases - ";

      # if we activated on a tick that isn't a note, just say how many beats since the last note
      # TODO: need to verify that $TICK{timesig}{num}*12 is actually the number of ticks in a musical beat not in a MIDI BEAT
      if ($cur_note eq "") {

        if (!exists $note_count{$last_note}) {
          $note_count{$last_note} = "";
        }

        # if it's immediate say so
        if (($i-$last_note_tick) == 1) {
          $cur_line .= "imm.";
            
        # if it's not immediate then say how many beats to wait and after which note
        } else {
          if ($note_count{$last_note} eq "") {
            $cur_line .= "after ";
          }
          $cur_line .= sprintf("%.2f", ($i-$last_note_tick)/12)." beats";
        }
            
        if ($note_count{$last_note} ne "") {
          $cur_line .= " after $note_count{$last_note}".counting_suffix($note_count{$last_note})." $last_note";
        }

      # if it's NN say NN
      } elsif (scalar keys %note_count eq 1 and $note_count{(keys %note_count)[0]} eq 1) {
        $cur_line .= "NN";

      # if it's in an OD phrase then use that
      } elsif ($TICK{OD}) {
            
        my $num_notes_into_OD = 0;
        for my $note (keys %OD_phrase_note_count) {
          $num_notes_into_OD += $OD_phrase_note_count{$note};
        }
            
        $cur_line .= "$num_notes_into_OD".counting_suffix($num_notes_into_OD)." note of next OD";

      # if not, tell us which note it is
      } else {
        $cur_line .= "$note_count{$last_note}".counting_suffix($note_count{$last_note})." $last_note";
      }

      # add the measure number and activation point info no matter what
      $cur_line .= " (";
      if ($cur_note eq "") {
        if (($i-$last_note_tick) == 1) {
          $cur_line .= "imm.";
        } else {
          $cur_line .= sprintf("%.2f", ($i-$last_note_tick)/12)." beats";
        }
        $cur_line .= " after ";
      }

      if (!exists $measure_note_count{$last_note}) {
        $cur_line .= "$last_note, in m$measure)";
      } else {
        $cur_line .= "$measure_note_count{$last_note}".counting_suffix($measure_note_count{$last_note})." $last_note in m$measure)";
      }
        
    }

    # if we're at the end of an OD phrase
    if ($TICK{endOD}) {
    
      %OD_phrase_note_count = ();
    
      # if we're activated then we picked up an extra phrase
      if ($TICK{activated}) {
          $extra_OD_phrases++;
#          print "Picked up an extra OD phrase in measure $measure  ($extra_OD_phrases)\n";
            
      # if we're not activated we picked up an OD phrase
      } else {
        $OD_phrases++;
      }
        
      # start counting notes to next activation
      %note_count = ();

    }

  }

}

sub finishpath {
  my ($self) = @_;

  close($self->outref);

  print "Wrote text path to ".$self->resultspath.$self->resultsfilename."\n" if !$self->silent;

}

# returns a proper counting suffix
sub counting_suffix {
	my $number = $_[0];
    
    if ($number == 11 or $number == 12 or $number == 13) {
        return "th";
    } elsif ($number % 10 == 1) {
        return "st";
    } elsif ($number % 10 == 2) {
        return "nd";
    } elsif ($number % 10 == 3) {
        return "rd";
    } else {
        return "th";
    }
}

1;
