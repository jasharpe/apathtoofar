###############################################################################
#
# RBMid.pm
#
# Copyright 2009, Jeremy Sharpe
#
# Created by: Jeremy Sharpe
#
# Contains midi processing functions.
#
###############################################################################
package RBMid;

# Modules for midi parsing
use MIDI;
use strict;

sub get_mid_title {
  my ($midfile) = @_;

  # Use midi module to parse midi file.
  my $song = MIDI::Opus->new({'from_file' => $midfile});
  my @Tracks = $song->tracks();

  # Get title, tempo and time signature from Track 0
  my @TimeEvents = $Tracks[0]->events;
  my $title;
  foreach my $event (@TimeEvents) {
    my $type = $event->[0];
    if($type =~ /track_name/) {
      $title = $event->[2];
      # Exceptions
      my %title_exceptions = (
        'thejack_live 360' => 'thejack_live'
      );
      if ($title_exceptions{$title}) {
        $title = $title_exceptions{$title};
      }
      last;
    }
  }

  return $title;
}

# Takes a midi file and returns a hash containing all the information you could
# ever want about it.
sub get_mid_data {
  my ($midfile) = @_;

  # Use midi module to parse midi file.
  my $song = MIDI::Opus->new({'from_file' => $midfile});
  my @Tracks = $song->tracks();

  # This is the master hash that will be returned at the end.
  my %SONG_INFO;

  # Map the track titles
  my %TRACKS;
  $TRACKS{TEMPO} = 0;
  for(my $track = 1; $track < @Tracks; $track++) {
    my @Events = $Tracks[$track]->events;
    my $event = $Events[0];
    my $trackname = $event->[2];
    $TRACKS{$trackname} = $track;
  }

  # Get title, tempo and time signature from Track 0
  my @TimeEvents = $Tracks[$TRACKS{TEMPO}]->events;
  my $time = 0;
  my $conversion = 60000000;
  foreach my $event (@TimeEvents) {
    my $type = $event->[0];
    $time += $event->[1];
    if($type =~ /track_name/) {
      $SONG_INFO{'title'} = $event->[2];
      # Exceptions
      my %title_exceptions = (
        'thejack_live 360' => 'thejack_live'
      );
      if ($title_exceptions{$SONG_INFO{'title'}}) {
        $SONG_INFO{'title'} = $title_exceptions{$SONG_INFO{'title'}};
      }
    } elsif($type =~ /time_signature/) {
      push(@{$SONG_INFO{'TimeSigs'}}, {now => $time, num => $event->[2], den => 2**$event->[3]});
    } elsif($type =~ /set_tempo/) {
      push(@{$SONG_INFO{'Tempos'}}, {now => $time, mus => $event->[2]});
      my $bpm = $conversion/$event->[2];
      push(@{$SONG_INFO{'TemposBPM'}}, {now => $time, bpm => $bpm});
    }
  }

  # Get practice sections from EVENTS
  $time = 0;
  my @eventEvents = $Tracks[$TRACKS{EVENTS}]->events;
  foreach my $event (@eventEvents) {
    my $type = $event->[0];
    $time += $event->[1];
    if($event->[2] =~ /section_intro/) {
      $event->[2] = "[section intro]";
    }
    if($type =~ /track_name/) {
      unless($event->[2] eq "EVENTS") {
        die "This is $event->[2], not the EVENTS track!";
      }
    } elsif($event->[2] =~ /^\[section /) {
      my ($section) = $event->[2] =~ /\[section (.*)\]/;
      $section =~ s/_/ /g;
      push(@{$SONG_INFO{'Sections'}}, {now => $time, name => $section});
    } elsif($event->[2] =~ /^\s*\[end\]\s*$/) {
      $SONG_INFO{'end'} = $time;
    }
  }

  # Get beat stuff from BEAT track
  $time = 0;
  my @BeatEvents = $Tracks[($TRACKS{BEAT} or $TRACKS{BEATS})]->events;
  my $beaton = 0;
  foreach my $event (@BeatEvents) {
    my $type = $event->[0];
    $time += $event->[1];
    if($type =~ /note_on/ and !$beaton) {
      push(@{$SONG_INFO{'Beats'}}, {now => $time});
      $beaton = 1;
    } elsif($type =~ /note_off/ or ($type =~ /note_on/ and $beaton)) {
      $beaton = 0;
    }
  }

  # Get the notes for guitar, bass and drums
  my %OFFSET = (Easy => 60, Medium => 72, Hard => 84, Expert => 96);
  my $solooffset = 103;
  my @PartOffsets = (105, 106);
  my $odoffset = 116;
  my $filloffset = 120;
  my %INST = ("PART DRUMS" => "Drums", "PART BASS" => "Bass", 
    "PART GUITAR" => "Guitar");
  # Sustains are at minimum a quarter of a beat. Normal notes are typically
  # exactly a quarter of a beat long. Use strict inequalities.
  my $sustaincutoff = 160;

  my $notewarns = "";
  # Don't do PART DRUMS, it sucks
  foreach my $part ("PART BASS", "PART GUITAR") {
    my $inst = $INST{$part};
    $time = 0;
    my @NoteEvents = $Tracks[$TRACKS{$part}]->events;
    my %SUSTAINS;
    my %NOTEON;
    EVENT: foreach my $event (@NoteEvents) {
      my $type = $event->[0];
      $time += $event->[1];
      next EVENT if($type !~ /note_on|note_off/);
      my $val = $event->[3];
      my $velocity = $event->[4];
      # Assume an event is an off event if the note is on.
      if($NOTEON{$val}{on}) {
        $type = "note_off";
      }
      # If we have two off events in a row, then skip the event.
      if(!$NOTEON{$val}{on} and $type eq "note_off") {
        next EVENT;
      }
      if($type =~ /note_on/) {
        $NOTEON{$val} = {now => $time, on => 1};
      } elsif($type =~ /note_off/) {
        if($NOTEON{$val}) {
          my $then = $NOTEON{$val}{now};
          my $length = $time - $then;
          $NOTEON{$val}{on} = 0;
          foreach my $diff (keys %OFFSET) {
            if($val >= $OFFSET{$diff} and $val <= $OFFSET{$diff}+4) {
              my $note = $val - $OFFSET{$diff};
              if($length <= $sustaincutoff) {
                $length = 0;
              }
              $SONG_INFO{'NOTES'}{$inst}{$diff} = ($SONG_INFO{'NOTES'}{$inst}{$diff} or []);
              my @PrevNotes = @{$SONG_INFO{'NOTES'}{$inst}{$diff}};
              my $measure = ($then / (480.0*4)) + 1;
              if(@PrevNotes > 0 and $PrevNotes[-1]{now} == $then) {
                $SONG_INFO{'NOTES'}{$inst}{$diff}[-1]{notes}[$note] = 1;
              } else {
                my @Notes = (0, 0, 0, 0, 0);
                $Notes[$note] = 1;
                push(@{$SONG_INFO{'NOTES'}{$inst}{$diff}}, 
                  {now => $then, notes => \@Notes, len => $length});
              }
              next EVENT;
            }
          }
          for(my $half = 0; $half < @PartOffsets; $half++) {
            if($val == $PartOffsets[$half]) {
              $SONG_INFO{'PART'}{$inst}[$half] = ($SONG_INFO{'PART'}{$inst}[$half] or []);
              push(@{$SONG_INFO{'PART'}{$inst}[$half]}, {now => $then, len => $length});
              next EVENT;
            }
          }
          if($val == $odoffset) {
            $SONG_INFO{'OD'}{$inst} = ($SONG_INFO{'OD'}{$inst} or []);
            push(@{$SONG_INFO{'OD'}{$inst}}, {now => $then, len => $length});
            next EVENT;
          }
          # Solo sections occur only on guitar. Key it to instrument too
          # just in case.
          if($inst eq "Guitar") {
            if($val == $solooffset) {
              $SONG_INFO{'SOLO'}{$inst} = ($SONG_INFO{'SOLO'}{$inst} or []);
              push(@{$SONG_INFO{'SOLO'}{$inst}}, {now => $then, len => $length});
              next EVENT;
            }
          }
          if($val >= $filloffset and $val <= $filloffset+4) {
            my $note = $val - $filloffset;
            $SONG_INFO{'FILL'}{$inst} = ($SONG_INFO{'FILL'}{$inst} or []);
            my @PrevNotes = @{$SONG_INFO{'FILL'}{$inst}};
            if(@PrevNotes > 0 and $PrevNotes[-1]{now} == $then) {
              $SONG_INFO{'FILL'}{$inst}[-1]{notes}[$note] = 1;
            } else {
              my @Notes = (0, 0, 0, 0, 0);
              $Notes[$note] = 1;
              push(@{$SONG_INFO{'FILL'}{$inst}}, {now => $then, notes => \@Notes, len => $length});
            }
            next EVENT;
          }
          $notewarns .= "Note $val with length $length not recognized.\n"
        } else {
          die "Note not on."
        }
      }
    }
  }
  return %SONG_INFO;
}

1;
