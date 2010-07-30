#!/usr/bin/perl -w
use strict;
###############################################################################
# 
# rbopt.pl
#
# Copyright 2009, Jeremy Sharpe
#
# Created by: Jeremy Sharpe
#
# Authors: Jeremy Sharpe, Nic Wolfe
#
# Takes a midi file for Rock Band and provides the optimal Overdrive path for
# it in various formats.
#
# This program is designed to support guitar and bass on any difficulty.
#
# The optimizer assumes that you hit every note. This is not necessarily the
# optimal method for every conceivable song, but in practice it is.
#
# Uses a separate program written in Java to do the actual optimization.
#
# Formats provided:
# Text
# Image (.png), generously assisted by ajanata
#
###############################################################################

##################################
### GET COMMAND-LINE ARGUMENTS ###
##################################

my $starttime = time;

# Modules
use Getopt::Long;
use RBMid; # Contains midi processing functions
use RBTicks;
use RBDump;
use AAPI; # Contains web interface stuff
use TextOutput; # Class used to output a text path
use AAPIOutput; # Class used to output a png with ajanata's API
use Misc; # Contains general purpose functions
use POSIX; # Has some math stuff like ceil and floor

my $help = 0;
my $diff = "Expert";
my $inst = "Guitar";
my $game = '';
my $verbose = 0;
my $lazy_pct = 0;
my $whammy_pct = 0;
my $squeeze_pct = 0;
my $skip = 0;
my $accurate = 2;
my $auto = 0;
my $silent = 0;
my $noopt = 0;
my $nopath = 0;
my $javaheapsize = 856;
my $expmnt = 0;
my $test = 0;
my $path;
my $optdir;

my $failure = GetOptions("help" => \$help,
                         "diff=s" => \$diff,
                         "inst=s" => \$inst,
                         "game=s" => \$game,
                         "verbose" => \$verbose,
                         "whammy=i" => \$whammy_pct,
                         "squeeze=i" => \$squeeze_pct,
                         "lazy=i" => \$lazy_pct,
                         "quiet" => \$auto,
                         "noopt" => \$noopt,
                         "nopath" => \$nopath,
                         "javaheap=i" => \$javaheapsize,
                         "accuracy=s" => \$accurate,
                         "experimental" => \$expmnt,
                         "test" => \$test,
                         "path=s" => \$path,
                         "optdir=s" => \$optdir);

# if we're calling this script programmatically, use some special behavior
if ($auto) {
    # don't output anything but the score
    $silent = 1;

    # skip any files that already exist,  or skip optimizing if all types of paths exist
}

# do some error checking on the options
if ($whammy_pct < 0) {
    $whammy_pct = 0;
}
             
if ($squeeze_pct < 0) {
    $squeeze_pct = 0;
}

if ($javaheapsize < 10) {
    $javaheapsize = 256;
}

############
### HELP ###
############

if($help) {
    print "TODO: Add help. Sorry... :(";
    exit(0);
}

my $midname = $ARGV[0];

#####################################
### DATA COLLECTION FROM THE MIDI ###
#####################################

# We collect all tracks (except vocals, because they're weird), even though
# right now we only use guitar and bass.

print "Gathering midi data...\n" if $verbose;

# Modules for midi parsing
use MIDI;

# File locations
my $midfile = "";
my $middir = "";
if ($path) {
  $middir = $path;
  $midfile = "$path/$midname.mid";
  if (!$game) {
    die "If you specify a path, you also need to specify the game!\n";
  }
} else {
  $middir = "mid";
  $game = AAPI::find_mid($midname, $game, $middir);
  # if game is 0 we couldn't find the mid
  if (!$game) {
    die("ERROR: Unable to find the mid $midname locally or online\n");
  } else {
    $midfile = "$middir/$game/$midname.mid";
  }
}

my %SONG_INFO;
my $title;

my $optimalscore;

my $tmpdir = "tmp";
use File::Path;
if ($path) {
  mkpath($path);
}
if ($optdir) {
  mkpath($optdir);
}
mkpath($tmpdir);
mkpath("$tmpdir/score");
my $scorefile = "$tmpdir/score/$midname.".lc($diff).".".lc($inst).".$lazy_pct.$squeeze_pct.$whammy_pct.score";

# if score file exists, read it
my $midread = 0;
if (-e $scorefile) {
  open(OPTSCORE, "$scorefile") or die "Can't open $scorefile: $!";
  chomp(($title, $optimalscore) = split(",",<OPTSCORE>));
  close(OPTSCORE);
} else {
  %SONG_INFO = RBMid::get_mid_data($midfile) if !$midread;
  $midread = 1;
  $title = $SONG_INFO{'title'};
}

#print("Generating Overdrive path for:\nSong: $SONG_INFO{'title'}\nDifficulty: $diff\nInstrument: $inst\n") if $verbose;

if (!$optdir) {
  $optdir = $tmpdir;
}

my $dumpfile = "$tmpdir/$midname.".lc($diff).".".lc($inst).".$lazy_pct.$squeeze_pct.$whammy_pct.dump";
my $optfile = "$optdir/$midname.".lc($diff).".".lc($inst).".$lazy_pct.$squeeze_pct.$whammy_pct.opt";
my $comfile = "$tmpdir/$midname.".lc($diff).".".lc($inst).".$lazy_pct.$squeeze_pct.$whammy_pct.com";
if ($expmnt) {
  $dumpfile = "$tmpdir/$midname.".lc($diff).".".lc($inst).".$lazy_pct.$squeeze_pct.$whammy_pct.e.dump";
  $optfile = "$optdir/$midname.".lc($diff).".".lc($inst).".$lazy_pct.$squeeze_pct.$whammy_pct.e.opt";
  $comfile = "$tmpdir/$midname.".lc($diff).".".lc($inst).".$lazy_pct.$squeeze_pct.$whammy_pct.e.com";
}

my @Ticks;
my %CONSTANTS;

# if dump exists, read it
if (-e $dumpfile && $noopt) {

  print "Reading dump file...\n" if $verbose;
  my ($constants, $ticks) = RBDump::readdump($dumpfile);
  @Ticks = @{$ticks};
  %CONSTANTS = %{$constants};

# if not, parse the mid
} else {

  print "Parsing mid...\n" if $verbose;
  %SONG_INFO = RBMid::get_mid_data($midfile) if !$midread;
  $midread = 1;

  #############################
  ### PROCESSING INTO TICKS ###
  #############################

  # length of one second
  my $SECOND = 1000000;
  $CONSTANTS{'EXPMNT'} = $expmnt;
  # OD
  if ($CONSTANTS{'EXPMNT'}) {
    my $factor = 5;
    $CONSTANTS{'WHAMMY_TO_USE_RATIO'} = 1.088;
    $CONSTANTS{'OD_PER_TICK'} = 12 * $factor; # Normal OD use rate
    $CONSTANTS{'WHAMMY_PER_TICK'} = 12 * $factor;
    $CONSTANTS{'ODDENOM'} = 1 * $factor;
    $CONSTANTS{'WHAMMY_PER_TICK_REAL'} = $CONSTANTS{'OD_PER_TICK'} * $CONSTANTS{'WHAMMY_TO_USE_RATIO'};
    $CONSTANTS{'MAX_OD_ERROR'} = $factor;#ceil($CONSTANTS{'WHAMMY_PER_TICK_REAL'}) - $CONSTANTS{'OD_PER_TICK'} - $factor;
    #print $CONSTANTS{'MAX_OD_ERROR'};
    #$CONSTANTS{'NORMAL_WHAMMY'} = $CONSTANTS{'OD_PER_TICK'} + 1 * $factor;
    $CONSTANTS{'NORMAL_WHAMMY'} = floor($CONSTANTS{'WHAMMY_PER_TICK_REAL'}) - $CONSTANTS{'MAX_OD_ERROR'};
  } elsif($accurate == 3) {
    # This is the exact whammy rate
    $CONSTANTS{'WHAMMY_PER_TICK'} = 1632;
    $CONSTANTS{'ODDENOM'} = 125;
    print "Using perfect whammy.\n" if $verbose;
  } elsif($accurate == 2) {
    # This is a damn good approximation of the whammy rate.
    $CONSTANTS{'WHAMMY_PER_TICK'} = 248;
    $CONSTANTS{'ODDENOM'} = 19;
    print "Using ridiculously accurate whammy.\n" if $verbose;
  } elsif($accurate == 1) {
    # This is a fairly good approximation of the whammy rate.
    $CONSTANTS{'WHAMMY_PER_TICK'} = 136;
    $CONSTANTS{'ODDENOM'} = 10;
    print "Using reasonably accurate whammy.\n" if $verbose;
  } else {
    # This is a bad but fast approximation of the whammy rate.
    print "Using inaccurate (but fast) whammy.\n" if $verbose;
    $CONSTANTS{'WHAMMY_PER_TICK'} = 12;
    $CONSTANTS{'ODDENOM'} = 1;
  }
  $CONSTANTS{'OD_MULT'} = 2; # The multiplier applied when OD is used.
  # It takes 7.5 beats to fill up a phrase value = 12 * 12 *  7.5 = 1080
  # It takes 8 beats to use up a full bar, so 2 beats to use up a quarter
  # bar. Whammy per tick = use per tick, so use per tick at 4/4 is 12.
  # Thus OD_PHRASE_VALUE = 8 beats * 12 ticks/beat * 12 OD units/tick = 1152 OD units
  $CONSTANTS{'OD_PHRASE_VALUE'} = 1152 * $CONSTANTS{'ODDENOM'}; # The amount of OD gained from completing an OD phrase.
  $CONSTANTS{'OD_ACTIVATE'} = $CONSTANTS{'OD_PHRASE_VALUE'}*2; # The amount of OD needed to activate
  $CONSTANTS{'MAX_OD'} = $CONSTANTS{'OD_PHRASE_VALUE'}*4; # The maximum OD capacity

  # Scoring
  # The maximum multiplier for each instrument.
  my %MAX_MULT = (Guitar => 4, Drums => 4, Bass => 6);
  $CONSTANTS{'MAX_MULT'} = $MAX_MULT{$inst};
  # The number of notes needed to be played to increase multiplier
  $CONSTANTS{'NOTES_TO_GAIN_MULT'} = 10;
  # Points for single tick, unmultiplied
  $CONSTANTS{'TICK_VALUE'} = 1;
  # The point value for one unmultiplied note
  $CONSTANTS{'NOTE_VALUE'} = 25;

  # Timing
  # The number of midi ticks per tick
  $CONSTANTS{'MIDITICKS_PER_TICK'} = 40;
  # The number of real ticks in a beat.
  $CONSTANTS{'TICKS_PER_BEAT'} = 12;
  # The number of microseconds in the timing window (both before AND after the note)
  $CONSTANTS{'TIMING_WINDOW'} = 2 * 1/8 * $SECOND;
  # FRONT and BACK timing windows add up to TIMING_WINDOW$
  $CONSTANTS{'FRONT_RATIO'} = 1/2;
  $CONSTANTS{'FRONT_TIMING_WINDOW'} = $CONSTANTS{'FRONT_RATIO'} * $CONSTANTS{'TIMING_WINDOW'} * ($squeeze_pct/100);
  $CONSTANTS{'BACK_TIMING_WINDOW'} = (1 - $CONSTANTS{'FRONT_RATIO'}) * $CONSTANTS{'TIMING_WINDOW'} * ($squeeze_pct/100);
  # This is the amount of time for the early whammy window. It is probably
  # technically the same as the front end timing window, but in practice
  # may be different.
  $CONSTANTS{'EARLY_WHAMMY_WINDOW'} = $CONSTANTS{'FRONT_RATIO'} * $CONSTANTS{'TIMING_WINDOW'} * ($whammy_pct/100);
  # Max Front and Back timing windows
  $CONSTANTS{'MAX_FRONT_TIMING_WINDOW'} = $CONSTANTS{'FRONT_RATIO'} * $CONSTANTS{'TIMING_WINDOW'};
  $CONSTANTS{'MAX_BACK_TIMING_WINDOW'} = (1 - $CONSTANTS{'FRONT_RATIO'}) * $CONSTANTS{'TIMING_WINDOW'};
  # This is the amount of time for the early whammy window. It is probably
  # technically the same as the front end timing window, but in practice
  # may be different.
  $CONSTANTS{'MAX_EARLY_WHAMMY_WINDOW'} = $CONSTANTS{'FRONT_RATIO'} * $CONSTANTS{'TIMING_WINDOW'};

  # Lazy whammy is a percentage of 1/2 second.
  $CONSTANTS{'LAZY_WHAMMY_TIME'} = int($SECOND / 2 * $lazy_pct / 100);
  $CONSTANTS{'WHAMMY_TIMEOUT'} = $SECOND / 2;

  # Misc Rock Band stuff
  # The number of points gained per note in a solo.
  $CONSTANTS{'SOLO_BONUS_PER_NOTE'} = 100;
  # The number of points per second?
  # Seems to be 150 points per 1.5 seconds, or 100 points per second, according
  # to:
  # http://rockband.scorehero.com/forum/viewtopic.php?t=3238
  $CONSTANTS{'BIG_ROCK_ENDING'} = 500;
  $CONSTANTS{'BIG_ROCK_ENDING_MAX'} = 750;

  # This array will represent all the notes in the song. All information, except
  # possibly the Big Rock Ending, is represented in @Notes in some form or
  # another.
  my @Notes = @{$SONG_INFO{'NOTES'}{$inst}{$diff}};

  # Set a flag on each note indicating whether or not it is in an OD phrase and
  # whether or not it ends an OD phrase. Do this for solos too.
  print "Calculating notes in OD phrases and in solos...\n" if $verbose;
  my @ODs = @{$SONG_INFO{'OD'}{$inst} or []};
  my @Solos = @{$SONG_INFO{'SOLO'}{$inst} or []};
  for(my $i = 0; $i < @Notes; $i++) {
      my $underOD = 0;
      my $curOD;
      my %Note = %{$Notes[$i]};
      $Note{reallen} = $Note{len};
      OD: foreach my $OD (@ODs) {
          my $endODtime = $OD->{now} + $OD->{len};
          # Check if the note is contained in the OD phrase
          if($Note{now} >= $OD->{now} and $Note{now} < $endODtime) {
              $Note{OD} = 1;
              if(!$Notes[$i+1] or $Notes[$i+1]->{now} >= $endODtime) {
                  $Note{endOD} = 1;
              }
              last OD;
          }
      }
      SOLO: foreach my $solo (@Solos) {
          my $endsolotime = $solo->{now} + $solo->{len};
          # Check if note is contained in the solo
          if($Note{now} >= $solo->{now} and $Note{now} < $endsolotime) {
              $Note{solo} = 1;
              if(!$Notes[$i+1] or $Notes[$i+1]->{now} >= $endsolotime) {
                  $Note{endsolo} = 1;
              }
              last SOLO;
          }
      }
      $Notes[$i] = \%Note;
  }

  # Round the sustain length down to the nearest multiple of $MIDITICKS_PER_TICK.
  # As far as I can tell this is how the scoring system works. Also round each
  # note down to the nearest multiple of $MIDITICKS_PER_TICK.  This shouldn't
  # screw anything up because the closest notes ever get to each other is 60 midi
  # ticks, and $MIDITICKS_PER_TICK is 40.
  map {
    $_->{len} = 
      int(($_->{len} + $CONSTANTS{'MIDITICKS_PER_TICK'} / 2) / $CONSTANTS{'MIDITICKS_PER_TICK'}) * $CONSTANTS{'MIDITICKS_PER_TICK'};
    $_->{now} = int($_->{now} / $CONSTANTS{'MIDITICKS_PER_TICK'}) * $CONSTANTS{'MIDITICKS_PER_TICK'};
  } @Notes;

  # Round the beats down to the nearest $MIDITICKS_PER_TICK.
  map {$_->{now} = int(($_->{now}+$CONSTANTS{'MIDITICKS_PER_TICK'}/2) / $CONSTANTS{'MIDITICKS_PER_TICK'}) * $CONSTANTS{'MIDITICKS_PER_TICK'};}
      @{$SONG_INFO{'Beats'}};

  # Check that we haven't created any overlaps. Could do some correction here.
  print "Checking for errors in rounding...\n" if $verbose;
  my $loc = -1;
  my $index = 0;

  foreach my $note (@Notes) {
      my $lastnote = ($Notes[$index-1] or {now => -1});
      while($note->{now} < $loc or $note->{now} == $lastnote->{now}) {
        if ($note->{now} < $loc && $Notes[$index-1]{len} > 0) {
          $Notes[$index-1]{len} -= $CONSTANTS{'MIDITICKS_PER_TICK'};
          $loc -= $CONSTANTS{'MIDITICKS_PER_TICK'};
          print "shortening sustain...\n" if $verbose;
        } elsif ($note->{now} <= $lastnote->{now}) {
          $note->{now} += $CONSTANTS{'MIDITICKS_PER_TICK'};
          print "adjusting back...\n" if $verbose;
        }
      }
      $loc = $note->{now} + $note->{len};
      $index++;
  }

  $loc = -1;
  $index = 0;
  foreach my $note (@Notes) {
      my $lastnote = ($Notes[$index-1] or {now => -1});
      if($note->{now} < $loc or $note->{now} == $lastnote->{now}) {
        die "Notes overlap. End of previous note: $loc, beginning of next note: ".
            "Tick $note->{now}, Measure ".($note->{now}/480/4+1).", Notes: ".
            join(", ", @{$note->{notes}}).", Previous note length: $lastnote->{len}\n";
      }
      $loc = $note->{now} + $note->{len};
      $index++;
  }

  $SONG_INFO{'Solos'} = \@Solos;
  $SONG_INFO{'Notes'} = \@Notes;
  my @Fills = @{$SONG_INFO{'FILL'}{$inst} or []};
  $SONG_INFO{'Fills'} = \@Fills;
  @Ticks = RBTicks::get_ticks(\%SONG_INFO, \%CONSTANTS);
  my $maxSqueeze = RBTicks::get_maxSqueeze(@Ticks);
  my %ODUSES = RBTicks::get_ODUSES(@Ticks);
  my %WHAMMYODS = RBTicks::get_WHAMMYODS(@Ticks);
  my %EARLYWHAMMYODS = RBTicks::get_EARLYWHAMMYODS(@Ticks);

  my $odgcd = Misc::gcd(keys %ODUSES, keys %WHAMMYODS, keys %EARLYWHAMMYODS, $CONSTANTS{'WHAMMY_PER_TICK'}, $CONSTANTS{'OD_PHRASE_VALUE'});
  #print $odgcd."\n";
  #print join(", ", keys %ODUSES)."\n";
  #print join(", ", keys %WHAMMYODS)."\n";
  #print join(", ", keys %EARLYWHAMMYODS)."\n";
  if($odgcd != 1) {
    foreach my $tick (@Ticks) {
      $tick->{ODuse} /= $odgcd;
      $tick->{whammyOD} /= $odgcd;
      for(my $j = 0; $j < @{$tick->{earlyWhammyODAmount}}; $j++) {
        #die join(" ", @{$tick->{earlyWhammyODAmount}}) if !defined($tick->{earlyWhammyODAmount}[$j]);
        $tick->{earlyWhammyODAmount}[$j] /= $odgcd;
      }
    }
    $CONSTANTS{'WHAMMY_PER_TICK'} /= $odgcd;
    $CONSTANTS{'OD_PHRASE_VALUE'} /= $odgcd;
    $CONSTANTS{'OD_ACTIVATE'} /= $odgcd;
    $CONSTANTS{'MAX_OD'} /= $odgcd;
  }

  $CONSTANTS{'MAX_SQUEEZE'} = $maxSqueeze;
  $CONSTANTS{'VERBOSE'} = $verbose;
  $CONSTANTS{'NUM_TICKS'} = scalar @Ticks;

  RBDump::writedump(\%CONSTANTS, \@Ticks, $dumpfile);
  
}

# add more outputs here to have them automatically run as long as they inherit from PathOutput
my $textoutput = eval { new TextOutput(); } or die ("Error creating text path object: $@\n");
my $aapioutput = eval { new AAPIOutput(); } or die ("Error creating AAPI path object: $@\n");
my @outputs = ($textoutput, $aapioutput);

# set up all outputs
my $readopt = 0;
foreach my $output (@outputs) {

  $output->songtitle($title);
  $output->midname($midname);
  $output->game($game);
  $output->inst($inst);
  $output->diff($diff);
  $output->lazy($lazy_pct);
  $output->squeeze($squeeze_pct);
  $output->whammy($whammy_pct);
  $output->silent($silent);
  $output->nopath($nopath);
  $output->expmnt($expmnt);
  $output->tmppath("$tmpdir/");
  if ($optdir) {
    $output->resultspath("$optdir/");
  }

  $readopt = $readopt || $output->needsRegen();
}

my $optresult = 1;

my $bad = 0;
my $optimizerrun = 0;
my $forcerun = 0;
my $maxWhammyChange = RBTicks::get_maxWhammyChange(@Ticks);
#print "whammy change: $maxWhammyChange\n";
do {
  # if noopt isn't set or the opt doesn't exist, run the optimizer
  if (!$noopt || !-e $optfile || $forcerun) {
    $optimizerrun = 1;
    print "Running optimizer...\n" if $verbose;

    # Optimize
    # Requires a call to the Java program.
    # Determine whether we need to recompile the Java by checking out its timestamp.
    my $recompile = 0;
    my $optsource = "rbopt.java";
    my $optcompiled = "rbopt.class";
    my $opt = "rbopt";
    if(-e $optsource) {
        unless(-e $optcompiled) {
            $recompile = 1;
        } else {
            my @SourceStat = stat($optsource);
            my @CompStat = stat($optcompiled);
            # If the source has been modified more recently than the compiled
            # version, then recompile.
            if($SourceStat[9] > $CompStat[9]) {
                $recompile = 1;
            }
        }
    } else {
        warn("Optimization source file $optsource doesn't exist. Not compiling.\n");
    }

    # Recompile if necessary
    if($recompile) {
        my $compileresult = system("javac $optsource");
        if($compileresult) {
            die("Compilation of $optsource failed: $!");
        }
    }

    unless(-e $optcompiled) {
        die("$optcompiled doesn't exist. Can't run optimize without it.");
    }

    my $wuse = $bad ? $maxWhammyChange : 0;

    # Run the optimization subroutine.
    if ($test) {
      $optresult = system("java -Xmx".$javaheapsize."m $opt \"$dumpfile\" \"$optfile\" $wuse $silent \"$comfile\"");
    } else {
      $optresult = system("java -Xmx".$javaheapsize."m $opt \"$dumpfile\" \"$optfile\" $wuse $silent");
    }

    if($optresult) {
      die("Optimization program failed: $!");
    }

  }

  # if noopt is set, the .opt exists, and any of the outputs needsRegen(), OR we ran the optimizer above, load the .opt
  if (($noopt && -e $optfile && $readopt) || !$optresult) {
    
    print "Reading opt file...\n" if $verbose;
    
    # Gather results of optimization.
    open(OPT, "< $optfile") or die "Can't open $optfile: $!";
    foreach my $tick (@Ticks) {
      my $line = <OPT>;
      chomp($line);
      my ($ticknum, $whammy, $activate, $early, $activated, $score, $ODscore, $ODtotal, $squeeze, $squeezing, $rsqueeze) = split(" ", $line);
      $tick->{dowhammy} = $whammy;
      $tick->{activate} = $activate;
      $tick->{earlywhammy} = $early; # number of ticks to early whammy
      $tick->{activated} = $activated;
      $tick->{score} = $score;
      $tick->{ODscore} = $ODscore;
      $tick->{ODtotal} = $ODtotal;
      $tick->{squeeze} = $squeeze;
      $tick->{rsqueeze} = $rsqueeze;
      $tick->{squeezing} = $squeezing;
    }
    close(OPT);

    my $numempty = 0;
    for (my $ticknum = 0; $ticknum < @Ticks; $ticknum++) {
      my $tick = $Ticks[$ticknum];
      
      if ($tick->{rsqueeze} > 0 && $tick->{activate}) {
        my $maxback = Misc::min($numempty, $tick->{rsqueeze});
        for (my $revtick = $ticknum - 1; $revtick > $ticknum - 1 - $maxback; $revtick--) {
          $tick->{rsqueeze}--;
          $Ticks[$revtick]{activated} = 1;
        }
      } elsif ($tick->{rsqueeze} > 0) {
        for (my $revtick = $ticknum + $tick->{rsqueeze}; $revtick > $ticknum; $revtick--) {
          if ($Ticks[$revtick]->{value} == 0) {
            $tick->{rsqueeze}--;
          }
        }
      }
      
      if ($tick->{value} == 0) {
        $numempty++;
      } else {
        $numempty = 0;
      }
    }

    # Check for bad whammy, but only do it if the optimizer was run so we don't
    # get into an infinite loop.
    if ($optimizerrun) {
      $bad = 0;
      my $wuse = 0;
      for (my $ticknum = 0; $ticknum < @Ticks; $ticknum++) {
        my %Tick = %{$Ticks[$ticknum]};
        if ($Tick{dowhammy} || $Tick{earlywhammy}) {
          if ($wuse == 0) {
            $wuse = $Tick{whammyChange};
          } else {
            $wuse = Misc::max(1, $wuse - 1);
          }
        } elsif ($wuse <= 1 || !$Tick{whammy}) {
          $wuse = 0;
        } else {
          $bad = 1;
          last;
        }
      }

      # force optimizer to run again if bad
      if ($bad) {
        $forcerun = 1;
      }
    }

    # Rate difficulty of squeezes and early whammy
    for (my $ticknum = 0; $ticknum < @Ticks; $ticknum++) {
      my $tick = $Ticks[$ticknum];
      $tick->{earlywhammydiff} = 0;
      $tick->{squeezediff} = 0;
      $tick->{rsqueezediff} = 0;
      if ($tick->{earlywhammy}) {
        #print "Early whammy: ".($tick->{earlywhammy}*$tick->{len} / 12).", Max: ".$CONSTANTS{'MAX_EARLY_WHAMMY_WINDOW'}."\n";
        $tick->{earlywhammydiff} = int(100 * ($tick->{earlywhammy}*$tick->{len} / 12) / $CONSTANTS{'MAX_EARLY_WHAMMY_WINDOW'} + 1/2);
      }
      if ($tick->{squeeze}) {
        if ($tick->{ODtotal} >= $CONSTANTS{'OD_ACTIVATE'}) {
          $tick->{squeezediff} = int(100 * ($tick->{squeeze} * $tick->{len} / 12) / $CONSTANTS{'MAX_FRONT_TIMING_WINDOW'} + 1/2);
        } else {
          $tick->{squeezediff} = int(100 * ($tick->{squeeze} * $tick->{len} / 12) / $CONSTANTS{'MAX_BACK_TIMING_WINDOW'} + 1/2);
        }
      }
      if ($tick->{rsqueeze}) {
        if ($tick->{ODtotal} >= $CONSTANTS{'OD_ACTIVATE'}) {
          $tick->{rsqueezediff} = int(100 * ($tick->{rsqueeze} * $tick->{len} / 12) / $CONSTANTS{'MAX_FRONT_TIMING_WINDOW'} + 1/2);
        } else {
          $tick->{rsqueezediff} = int(100 * ($tick->{rsqueeze} * $tick->{len} / 12) / $CONSTANTS{'MAX_BACK_TIMING_WINDOW'} + 1/2);
        }
      }
      $tick->{earlywhammydiff} = Misc::min($tick->{earlywhammydiff}, $whammy_pct);
      $tick->{squeezediff} = Misc::min($tick->{squeezediff}, $squeeze_pct);
      $tick->{rsqueezediff} = Misc::min($tick->{rsqueezediff}, $squeeze_pct);
    }

    $optimalscore = $Ticks[-1]->{ODscore};

    if(open(OPTSCORE, "> $scorefile")) {
      print OPTSCORE "$title,$optimalscore";
      close(OPTSCORE);
    }

  }
} while ($bad);

print "Optimal score: " . $optimalscore . "\n" if $verbose;

# run all outputs
foreach my $output (@outputs) {
  $output->generatepath(@Ticks);
}

my $endtime = time;

print "Total processing time: " . ($endtime - $starttime) . " seconds\n" if !$silent;

# the only thing we print if silent is on
print "$optimalscore" if $silent;
