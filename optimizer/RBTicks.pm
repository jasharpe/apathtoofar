package RBTicks;

use Misc;
use strict;

sub get_maxSqueeze {
  my @Ticks = @_;
  
  my $maxSqueeze = 0;

  foreach my $tick (@Ticks) {
    $maxSqueeze = Misc::max($tick->{frontSqueezeOD}, $tick->{backSqueezeOD}, $maxSqueeze);
  }

  return $maxSqueeze;
}

sub get_maxWhammyChange {
  my @Ticks = @_;
  
  my $maxWhammyChange = 0;

  foreach my $tick (@Ticks) {
    $maxWhammyChange = Misc::max($tick->{whammyChange}, $maxWhammyChange);
  }

  return $maxWhammyChange;
}

sub get_ODUSES {
  my @Ticks = @_;
  
  my %ODUSES;

  foreach my $tick (@Ticks) {
    $ODUSES{$tick->{'ODuse'}} = 1;
  }

  return %ODUSES;
}

sub get_WHAMMYODS {
  my @Ticks = @_;
  
  my %WHAMMYODS;

  foreach my $tick (@Ticks) {
    if ($tick->{'whammyOD'} != 0) {
      $WHAMMYODS{$tick->{'whammyOD'}} = 1;
    }
  }

  return %WHAMMYODS;
}

sub get_EARLYWHAMMYODS {
  my @Ticks = @_;
  
  my %WHAMMYODS;

  foreach my $tick (@Ticks) {
    for(my $early = 1; $early < @{$tick->{'earlyWhammyODAmount'}}; $early++) {
      $WHAMMYODS{$tick->{'earlyWhammyODAmount'}[$early]} = 1;
      #die $tick->{'earlyWhammyODAmount'}[$early] if !defined($tick->{'earlyWhammyODAmount'}[$early]);
    }
  }

  return %WHAMMYODS;
}

sub get_ticks {
  my ($song_info, $constants) = @_;
  my %SONG_INFO = %{$song_info};
  my %CONSTANTS = %{$constants};

  # Create @Ticks array from %SONG_INFO
  if($SONG_INFO{'end'} % $CONSTANTS{'MIDITICKS_PER_TICK'} != 0) {
    #$SONG_INFO{'end'} += $CONSTANTS{'MIDITICKS_PER_TICK'} - $SONG_INFO{'end'} % $CONSTANTS{'MIDITICKS_PER_TICK'};
    $SONG_INFO{'end'} -= $SONG_INFO{'end'} % $CONSTANTS{'MIDITICKS_PER_TICK'};
    if($SONG_INFO{'end'} % $CONSTANTS{'MIDITICKS_PER_TICK'} != 0) {
      die "End $SONG_INFO{'end'} is not divisible by $CONSTANTS{'MIDITICKS_PER_TICK'}\n";
    }
  }
  my $numticks = $SONG_INFO{'end'} / $CONSTANTS{'MIDITICKS_PER_TICK'};

  my @Ticks;
  my $noteindex = 0;
  my $tempoindex = 0;
  my $sectionindex = 0;
  my $beatindex = 0;
  my $fillindex = 0;
  my $soloindex = 0;
  my $timesigindex = 0;
  # Round the beginning and length of the solo down to nearest $MIDITICKS_PER_TICK.
  map {$_->{len} = int($_->{len} / $CONSTANTS{'MIDITICKS_PER_TICK'}) * $CONSTANTS{'MIDITICKS_PER_TICK'};
    $_->{now} = int($_->{now} / $CONSTANTS{'MIDITICKS_PER_TICK'}) * $CONSTANTS{'MIDITICKS_PER_TICK'};}
  @{$SONG_INFO{'Solos'}};
  my $curOD = 0;
  my $filltime = 0; # This is the number of microseconds of Big Rock Ending
  my $getpoints = 1; # This determines whether notes and sustains give points.
  my $solonotes = 0; # A counter for solo notes.
  my $curODuse = 0;
  my $timeSinceLastNote = 0; # literal time, in microseconds
  my $totalwhammyreal = 0;
  my $totalwhammyfake = 0;
  for(my $i = 0; $i < $numticks; $i++) {
    my $time = $CONSTANTS{'MIDITICKS_PER_TICK'} * $i;
    if($noteindex < @{$SONG_INFO{'Notes'}}
        and (($SONG_INFO{'Notes'}[$noteindex]{now} + $SONG_INFO{'Notes'}[$noteindex]{len} <= $time and $SONG_INFO{'Notes'}[$noteindex]{len} > 0)
          or ($SONG_INFO{'Notes'}[$noteindex]{now} < $time and $SONG_INFO{'Notes'}[$noteindex]{len} == 0))) {
      $curOD = 0 if($SONG_INFO{'Notes'}[$noteindex]{endOD});
      $noteindex++;
    }
    $tempoindex++ if($tempoindex < @{$SONG_INFO{'Tempos'}} and $SONG_INFO{'Tempos'}[$tempoindex+1] and $SONG_INFO{'Tempos'}[$tempoindex+1]{now} <= $time);
    $sectionindex++ if($sectionindex < @{$SONG_INFO{'Sections'}} and $SONG_INFO{'Sections'}[$sectionindex+1] and $SONG_INFO{'Sections'}[$sectionindex+1]{now} <= $time);
    $timesigindex++ if($timesigindex < @{$SONG_INFO{'TimeSigs'}} and $SONG_INFO{'TimeSigs'}[$timesigindex+1] and $SONG_INFO{'TimeSigs'}[$timesigindex+1]{now} <= $time);
    $beatindex++ if($beatindex < @{$SONG_INFO{'Beats'}} and $SONG_INFO{'Beats'}[$beatindex+1] and $SONG_INFO{'Beats'}[$beatindex+1]{now} <= $time);
    $fillindex++ if($fillindex < @{$SONG_INFO{'Fills'}} and $SONG_INFO{'Fills'}[$fillindex]{now} + $SONG_INFO{'Fills'}[$fillindex]{len} <= $time);
    $soloindex++ if($soloindex < @{$SONG_INFO{'Solos'}} and $SONG_INFO{'Solos'}[$soloindex]{now} + $SONG_INFO{'Solos'}[$soloindex]{len} < $time);
    # A definition of the properties of a tick.
    my %TICK = (
      len => 0, # length of the beat the tick is in in microseconds
      notes => [0, 0, 0, 0, 0], # which notes are used? 0's for empty
      note => 0, # is this tick a note?
      sustain => 0, # is this tick part of a sustain?
      OD => 0, # is this tick in an OD phrase?
      endOD => 0, # does this tick end an OD phrase?
      solo => 0, # is this in a solo?
      endsolo => 0, # does this end a solo?
      whammy => 0, # can you get OD for whammying?
      whammyOD => 0, # how much whammy is provided by whammying this tick?
      realwhammy => 0, # How much does this tick contribute to whammy NOT including rounding
      fill => 0, # is this tick part of a fill?
      fillbonus => 0, # bonus from the BRE at the end of the song. Only
      # appears on the last strummed note.
      ODuse => 0, # the multiplier on the OD used on this tick.
      mult => 0, # multiplier that this tick is under
      value => 0, # total value of tick, unmultiplied
      # Note: susval + noteval = value
      susval => 0, # total value of any sustains on this tick
      noteval => 0, # total value of any notes on this tick
      solobonus => 0, # bonus garnered on this tick from a solo, usually 0
      sect => "", # practice section title
      timesig => {num => 0, den => 0},
      frontSqueezeOD => 0, # the amount of OD that represents the size of the front-end squeeze on this tick, in other words, how early can you hit this tick. (at the end of an activation).
      backSqueezeOD => 0, # same, but for back-end squeeze
      earlyWhammyOD => 0, # max OD from this tick for early whammy.
      earlyWhammyODAmountTotal => 0,
      earlyWhammyODAmount => [],
      maxFrontSqueezeOD => 0,
      maxBackSqueezeOD => 0,
      maxEarlyWhammyOD => 0,
      whammyable    => 0, # whether the tick is whammyable (for lazy whammy)
      whammyChange => 0,
    );
    my $note = $SONG_INFO{'Notes'}[$noteindex];
    my $tempo = $SONG_INFO{'Tempos'}[$tempoindex];
    my $section = $SONG_INFO{'Sections'}[$sectionindex];
    my $beat = $SONG_INFO{'Beats'}[$beatindex];
    my $fill = $SONG_INFO{'Fills'}[$fillindex];
    my $solo = $SONG_INFO{'Solos'}[$soloindex];
    my $timesig = $SONG_INFO{'TimeSigs'}[$timesigindex];

    # Turn on OD or solo if note warrants it.
    if($note and $note->{OD} and $time == $note->{now}) {
      $curOD = 1;
    }

    # Fill in each of these properties
    # len
    $TICK{len} = $tempo->{mus};
    $timeSinceLastNote += $TICK{len}/12;

    # notes
    if($note and $time >= $note->{now}) {
      $TICK{notes} = $note->{notes};
    }

    # note
    if($note and $time == $note->{now}) {
      $TICK{note} = 1;
      $timeSinceLastNote = 0;
    }

    # sustain
    if($note and $time >= $note->{now} and $note->{len} > 0) {
      $TICK{sustain} = 1;
    }

    # OD
    $TICK{OD} = $curOD;

    # endOD
    if($note and $time == $note->{now} and $note->{endOD}) {
      $TICK{endOD} = 1;
    }

    # solo
    if($solo and $time >= $solo->{now}) {
      $TICK{solo} = 1;
      if($note and $time == $note->{now}) {
        $solonotes++;
      }
    }

    # endsolo
    if($solo and $time == $solo->{now} + $solo->{len}) {
      $TICK{endsolo} = 1;
    }

    # whammy
    if($TICK{sustain} and $TICK{OD}) {
      $TICK{whammy} = 1;
    }

    # realwhammy
    if ($TICK{sustain} and $TICK{OD}) {
      $TICK{realwhammy} = ($note->{reallen} / $note->{len});
    }

    # whammyable
    if ($TICK{whammy} and $timeSinceLastNote >= $CONSTANTS{'LAZY_WHAMMY_TIME'}) {
      $TICK{whammyable} = 1;
    }

    # fill
    if($fill and $time >= $fill->{now}) {
      $TICK{fill} = 1;
      $getpoints = 0;
      $filltime += $TICK{len};
    }

    # fillbonus, only appears on last note.
    if($note and $time == $note->{now} and !$SONG_INFO{'Notes'}[$noteindex+1] and @{$SONG_INFO{'Fills'}}) {
      my $fillsecs = $filltime/12/1000000;
      my $fillbonus = $CONSTANTS{'BIG_ROCK_ENDING_MAX'} + $fillsecs * $CONSTANTS{'BIG_ROCK_ENDING'};
      $TICK{fillbonus} = int($fillbonus);
    }

    # ODuse, depends on BEAT track
    my $nextbeat = $SONG_INFO{'Beats'}[$beatindex+1];
    my $endmidticks = $nextbeat?$nextbeat->{now}:$SONG_INFO{'end'};
    my $midticks = $endmidticks - $beat->{now};
    if($endmidticks == $SONG_INFO{'end'} and $midticks > 24*40) {
      $midticks = 480;
    }
    my $midticksperbeat = $CONSTANTS{'MIDITICKS_PER_TICK'} * $CONSTANTS{'TICKS_PER_BEAT'};
    my $ODuse;
    if ($CONSTANTS{'EXPMNT'}) {
      $ODuse = int($CONSTANTS{'ODDENOM'}*12*12/($midticks/40));
    } else {
      $ODuse = int($CONSTANTS{'ODDENOM'}*12*12/($midticks/40));
    }
    $TICK{ODuse} = $ODuse;
    $curODuse = $ODuse; 

    # mult
    my $played = 0;
    if($note) {
      $played = 1 if $time >= $note->{now};
      $TICK{mult} = Misc::min(int(($noteindex+$played)/$CONSTANTS{'NOTES_TO_GAIN_MULT'})+1, $CONSTANTS{'MAX_MULT'});
    } else {
      $TICK{mult} = $CONSTANTS{'MAX_MULT'};
    }

    # value, susval, and noteval calculations could be combined. I'm not bothering
    # because it's a bit clearer to have them separate and it doesn't take too
    # long to run.

    # value
    my $value = 0;
    if($note and $time >= $note->{now}) {
      foreach (@{$note->{notes}}) {
        if($_) {
          $value += $CONSTANTS{'TICK_VALUE'} if $TICK{sustain};
          $value += $CONSTANTS{'NOTE_VALUE'} if $TICK{note};
        }
      }
    }
    # Don't get any points once we're in the Big Rock Ending
    $value = 0 unless($getpoints);
    $TICK{value} = $value;

    # susval
    my $susval = 0;
    if($note and $time >= $note->{now}) {
      foreach(@{$note->{notes}}) {
        if($_) {
          $susval += $CONSTANTS{'TICK_VALUE'} if $TICK{sustain};
        }
      }
    }
    $susval = 0 unless($getpoints);
    $TICK{susval} = $susval;

    # noteval
    my $noteval = 0;
    if($note and $time >= $note->{now}) {
      foreach(@{$note->{notes}}) {
        if($_) {
          $noteval += $CONSTANTS{'NOTE_VALUE'} if $TICK{note};
        }
      }
    }
    $noteval = 0 unless($getpoints);
    $TICK{noteval} = $noteval;

    # solobonus
    if($TICK{endsolo}) {
      $TICK{solobonus} = $CONSTANTS{'SOLO_BONUS_PER_NOTE'} * $solonotes;
      $solonotes = 0; 
    }

    # sect
    $TICK{sect} = $section->{name};

    # timesig
    $TICK{timesig} = {num => $timesig->{num}, den => $timesig->{den}};

    # frontSqueezeOD
    $TICK{frontSqueezeOD} = int($CONSTANTS{'FRONT_TIMING_WINDOW'}/($TICK{len}/12) + 1/2);

    # backSqueezeOD
    $TICK{backSqueezeOD} = int($CONSTANTS{'BACK_TIMING_WINDOW'}/($TICK{len}/12) + 1/2);

    # earlyWhammyOD
    if($TICK{whammy} && $TICK{note}) {
      my $earlyWhammyOD = int($CONSTANTS{'EARLY_WHAMMY_WINDOW'}/($TICK{len}/12) + 1/2);
      $TICK{earlyWhammyOD} = Misc::min($earlyWhammyOD, getLastSustain(@Ticks));
      if ($CONSTANTS{'EXPMNT'}) {
        $TICK{earlyWhammyODAmountTotal} = 0;
        $TICK{earlyWhammyODAmount}[0] = 0;
        for (my $early = 1; $early <= $TICK{earlyWhammyOD}; $early++) {
          $totalwhammyreal += $CONSTANTS{'WHAMMY_PER_TICK_REAL'};
          $totalwhammyfake += $CONSTANTS{'NORMAL_WHAMMY'};
          $TICK{earlyWhammyODAmountTotal} += $CONSTANTS{'NORMAL_WHAMMY'};
          if ($totalwhammyreal - $totalwhammyfake >= $CONSTANTS{'MAX_OD_ERROR'}) {
            $TICK{earlyWhammyODAmountTotal} += 2*$CONSTANTS{'MAX_OD_ERROR'};
            $totalwhammyfake += 2*$CONSTANTS{'MAX_OD_ERROR'};
          }
          if ($totalwhammyfake <= $totalwhammyreal) {
            $totalwhammyreal -= $totalwhammyfake;
            $totalwhammyfake = 0;
          }
          $TICK{earlyWhammyODAmount}[$early] = $TICK{earlyWhammyODAmountTotal};
        }
      } else {
        $TICK{earlyWhammyODAmount}[0] = 0;
        $TICK{earlyWhammyODAmountTotal} = 0;
        for (my $early = 1; $early <= $TICK{earlyWhammyOD}; $early++) {
          $TICK{earlyWhammyODAmountTotal} += $CONSTANTS{'WHAMMY_PER_TICK'};
          $TICK{earlyWhammyODAmount}[$early] = $TICK{earlyWhammyODAmountTotal};
        }
      }
    } else {
      $TICK{earlyWhammyODAmount}[0] = 0;
      $TICK{earlyWhammyOD} = 0;
    }

    # whammyOD
    if ($TICK{whammy}) {
      if ($CONSTANTS{'EXPMNT'}) {
        $totalwhammyreal += $CONSTANTS{'WHAMMY_PER_TICK_REAL'};
        $TICK{whammyOD} = $CONSTANTS{'NORMAL_WHAMMY'};
        $totalwhammyfake += $TICK{whammyOD};
        if ($totalwhammyreal - $totalwhammyfake >= $CONSTANTS{'MAX_OD_ERROR'}) {
          #print "Enhancing $i with $CONSTANTS{MAX_OD_ERROR} since $totalwhammyreal too far from $totalwhammyfake\n";
          $TICK{whammyOD} += 2*$CONSTANTS{'MAX_OD_ERROR'};
          $totalwhammyfake += 2*$CONSTANTS{'MAX_OD_ERROR'};
        }
        if ($totalwhammyfake <= $totalwhammyreal) {
          $totalwhammyreal -= $totalwhammyfake;
          $totalwhammyfake = 0;
        }
      } else {
        $TICK{whammyOD} = $CONSTANTS{'WHAMMY_PER_TICK'};
      }
    }

    # maxFrontSqueezeOD
    $TICK{maxFrontSqueezeOD} = int($CONSTANTS{'MAX_FRONT_TIMING_WINDOW'}/($TICK{len}/12) + 1/2);

    # maxBackSqueezeOD
    $TICK{maxBackSqueezeOD} = int($CONSTANTS{'MAX_BACK_TIMING_WINDOW'}/($TICK{len}/12) + 1/2);

    # maxEarlyWhammyOD
    if($TICK{OD} && $TICK{note} && $TICK{sustain}) {
      my $maxEarlyWhammyOD = int($CONSTANTS{'MAX_EARLY_WHAMMY_WINDOW'}/($TICK{len}/12) + 1/2);
      $TICK{maxEarlyWhammyOD} = $maxEarlyWhammyOD;
    } else {
      $TICK{maxEarlyWhammyOD} = 0;
    }

    # whammyChange
    $TICK{whammyChange} = int($CONSTANTS{'WHAMMY_TIMEOUT'} / ($TICK{len}/12) + 1/2);

    # Add to tick array
    push(@Ticks, \%TICK);
  }

  my @NextTwoNotes;
  my $size = @Ticks; # make a variable for memory purposes
  for (my $tick = 0; $tick < @Ticks; $tick++) {
    getTwoNotePosns($tick, $size, \@Ticks, \@NextTwoNotes);
    $Ticks[$tick]->{frontSqueezeOD} = Misc::min($Ticks[$tick]->{frontSqueezeOD}, int(($NextTwoNotes[1] + $NextTwoNotes[0])/2));
  }

  for (my $tick = 0; $tick < $size; $tick++) {
    if ($Ticks[$tick]->{sustain}) {
      $Ticks[$tick]->{ticksToEndOfSustain} = getEndSustainPosn($tick, $size, \@Ticks);
    } else {
      $Ticks[$tick]->{ticksToEndOfSustain} = 0;
    }
  }

  return @Ticks;
}

sub getEndSustainPosn {
  my ($tick, $size, $Ticks) = @_;
  for (my $i = $tick; $i < $size; $i++) {
    if (!$Ticks->[$i]{sustain}) {
      return $i - $tick - 1;
    }
  }
}

sub getTwoNotePosns {
  my ($tick, $size, $Ticks, $toFill) = @_;
  my $firstNote = 0;
  for(my $i = $tick; $i < $size; $i++) {
    if($Ticks->[$i]{note}) {
      if (!$firstNote) {
        $toFill->[0] = $i - $tick + 1;
        $firstNote = 1;
      } else {
        $toFill->[1] = $i - $tick + 1;
        return;
      }
    }
  }
  return 1000;
}

sub getLastSustain {
  my @Ticks = @_;
  for(my $i = @Ticks - 1; $i >= Misc::max(0, @Ticks - 10); $i--) {
    if($Ticks[$i]{sustain}) {
      return @Ticks - ($i + 1);
    }
  }
  return 1000;
}

1;
