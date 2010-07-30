
# Time-stamp: "2005-01-29 16:32:14 AST"
require 5;
package MIDI::Simple;
use MIDI;
use Carp;
use strict 'vars';
use strict 'subs';
use vars qw(@ISA @EXPORT $VERSION $Debug
            %package
            %Volume @Note %Note %Length);
use subs qw(&make_opus($\@) &write_score($$\@)
            &read_score($) &dump_score(\@)
           );
require Exporter;
@ISA = qw(Exporter);
$VERSION = '0.81';
$Debug = 0;

@EXPORT = qw(
 new_score n r noop interval note_map
 Score   Time   Duration   Channel   Octave   Tempo   Notes   Volume
 Score_r Time_r Duration_r Channel_r Octave_r Tempo_r Notes_r Volume_r
 Cookies Cookies_r Self
 write_score read_score dump_score make_opus synch
 is_note_spec is_relative_note_spec is_absolute_note_spec
 number_to_absolute number_to_relative

 key_after_touch control_change patch_change channel_after_touch
 pitch_wheel_change set_sequence_number text_event copyright_text_event
 track_name instrument_name lyric marker cue_point

 text_event_08 text_event_09 text_event_0a text_event_0b text_event_0c
 text_event_0d text_event_0e text_event_0f

 end_track set_tempo smpte_offset time_signature key_signature
 sequencer_specific raw_meta_event

 sysex_f0 sysex_f7
 song_position song_select tune_request raw_data
);     # _test_proc

local %package = ();
# hash of package-scores: accessible as $MIDI::Simple::package{"packagename"}
# but REALLY think twice about writing to it, OK?
# To get at the current package's package-score object, just call
#  $my_object = Self;

# /
#|  'Alchemical machinery runs smoothest in the imagination.'
#|    -- Terence McKenna
# \

=head1 NAME

MIDI::Simple - procedural/OOP interface for MIDI composition

=head1 SYNOPSIS

 use MIDI::Simple;
 new_score;
 text_event 'http://www.ely.anglican.org/parishes/camgsm/bells/chimes.html';
 text_event 'Lord through this hour/ be Thou our guide';
 text_event 'so, by Thy power/ no foot shall slide';
 set_tempo 500000;  # 1 qn => .5 seconds (500,000 microseconds)
 patch_change 1, 8;  # Patch 8 = Celesta

 noop c1, f, o5;  # Setup
 # Now play
 n qn, Cs;    n F;   n Ds;  n hn, Gs_d1;
 n qn, Cs;    n Ds;  n F;   n hn, Cs;
 n qn, F;     n Cs;  n Ds;  n hn, Gs_d1;
 n qn, Gs_d1; n Ds;  n F;   n hn, Cs;

 write_score 'westmister_chimes.mid';

=head1 DESCRIPTION

This module sits on top of all the MIDI modules -- notably MIDI::Score
(so you should skim L<MIDI::Score>) -- and is meant to serve as a
basic interface to them, for composition.  By composition, I mean
composing anew; you can use this module to add to or modify existing
MIDI files, but that functionality is to be considered a bit experimental.

This module provides two related but distinct bits of functionality:
1) a mini-language (implemented as procedures that can double as
methods) for composing by adding notes to a score structure; and 2)
simple functions for reading and writing scores, specifically the
scores you make with the composition language.

The fact that this module's interface is both procedural and
object-oriented makes it a definite two-headed beast.  The parts of
the guts of the source code are not for the faint of heart.


=head1 NOTE ON VERSION CHANGES

This module is somewhat incompatible with the MIDI::Simple versions
before .700 (but that was a I<looong> time ago).


=cut

%Volume = ( # I've simply made up these values from more or less nowhere.
# You no like?  Change 'em at runtime, or just use "v64" or whatever,
# to specify the volume as a number 1-127.
 'ppp' =>   1,  # pianississimo
 'pp'  =>  12,  # pianissimo
 'p'   =>  24,  # piano
 'mp'  =>  48,  # mezzopiano
 'm'     =>  64,  # mezzo / medio / meta` / middle / whatever
 'mezzo' =>  64,
 'mf'  =>  80,  # mezzoforte
 'f'   =>  96,  # forte
 'ff'  => 112,  # fortissimo
 'fff' => 127,  # fortississimo
);

%Length = ( # this list should be rather uncontroversial.
 # The numbers here are multiples of a quarter note's length
 # The abbreviations are:
 #    qn for "quarter note",
 #    dqn for "dotted quarter note",
 #    ddqn for "double-dotten quarter note",
 #    tqn for "triplet quarter note"
 'wn' =>  4,     'dwn' => 6,    'ddwn' => 7,       'twn' => (8/3),
 'hn' =>  2,     'dhn' => 3,    'ddhn' => 3.5,     'thn' => (4/3),
 'qn' =>  1,     'dqn' => 1.5,  'ddqn' => 1.75,    'tqn' => (2/3),
 'en' => .5,     'den' => .75,  'dden' => .75,     'ten' => (1/3),
 'sn' => .25,    'dsn' => .375, 'ddsn' => .4375,   'tsn' => (1/6),
 # Yes, these fractions could lead to round-off errors, I suppose.
 # But note that 96 * all of these == a WHOLE NUMBER!!!!!

# Dangit, tsn for "thirty-second note" clashes with pre-existing tsn for
# "triplet sixteenth note"
#For 32nd notes, tha values'd be:
#        .125             .1875           .21875            (1/12)
#But hell, just access 'em as:
#         d12               d18           d21                d8
#(assuming Tempo = 96)

);

%Note = (
 'C'  =>  0,
 'Cs' =>  1, 'Df' =>  1, 'Csharp' =>  1, 'Dflat' =>  1,
 'D'  =>  2,
 'Ds' =>  3, 'Ef' =>  3, 'Dsharp' =>  3, 'Eflat' =>  3,
 'E'  =>  4,
 'F'  =>  5,
 'Fs' =>  6, 'Gf' =>  6, 'Fsharp' =>  6, 'Gflat' =>  6,
 'G'  =>  7,
 'Gs' =>  8, 'Af' =>  8, 'Gsharp' =>  8, 'Aflat' =>  8,
 'A'  =>  9,
 'As' => 10, 'Bf' => 10, 'Asharp' => 10, 'Bflat' => 10,
 'B'  => 11,
);

@Note = qw(C Df  D Ef  E   F Gf  G Af  A Bf  B);
# These are for converting note numbers to names, via, e.g., $Note[2]
# These must be a subset of the keys to %Note.
# You may choose to have these be your /favorite/ names for the particular
# notes.  I've taken a stab at that myself.
###########################################################################

=head2 OBJECT STRUCTURE

A MIDI::Simple object is a data structure with the following
attributes:

=over

=item Score

This is a list of all the notes (each a listref) that constitute this
one-track musical piece.  Scores are explained in L<MIDI::Score>.
You probably don't need to access the Score attribute directly, but be
aware that this is where all the notes you make with C<n> events go.

=item Time

This is a non-negative integer expressing the start-time, in ticks
from the start-time of the MIDI piece, that the next note pushed to
the Score will have.

=item Channel

This is a number in the range [0-15] that specifies the current default
channel for note events.

=item Duration

This is a non-negative (presumably nonzero) number expressing, in
ticks, the current default length of note events, or rests.

=item Octave

This is a number in the range [0-10], expressing what the current
default octave number is.  This is used for figuring out exactly
what note-pitch is meant by a relative note-pitch specification
like "A".

=item Notes

This is a list (presumably non-empty) of note-pitch specifications,
I<as note numbers> in the range [0-127].

=item Volume

This is an integer in the range [0-127] expressing the current default
volume for note events.

=item Tempo

This is an integer expressing the number of ticks a quarter note
occupies.  It's currently 96, and you shouldn't alter it unless you
I<really> know what you're doing.  If you want to control the tempo of
a piece, use the C<set_tempo> routine, instead.

=item Cookies

This is a hash that can be used by user-defined object-methods for
storing whatever they want.

=back

Each package that you call the procedure C<new_score> from, has a
default MIDI::Simple object associated with it, and all the above
attributes are accessible as:

  @Score $Time $Channel $Duration $Octave
  @Notes $Volume $Tempo %Cookies

(Although I doubt you'll use these from any package other than
"main".)  If you don't know what a package is, don't worry about it.
Just consider these attributes synonymous with the above-listed
variables.  Just start your programs with

  use MIDI::Simple;
  new_score;

and you'll be fine.

=head2 Routine/Method/Procedure

MIDI::Simple provides some pure functions (i.e., things that take
input, and give a return value, and that's all they do), but what
you're mostly interested in its routines.  By "routine" I mean a
subroutine that you call, whether as a procedure or as a method, and
that affects data structures other than the return value.

Here I'm using "procedure" to mean a routine you call like this:

  name(parameters...);
  # or, just maybe:
  name;

(In technical terms, I mean a non-method subroutine that can have side
effects, and which may not even provide a useful return value.)  And
I'm using "method" to mean a routine you call like this:

  $object->name(parameters);

So bear these terms in mind when you see routines below that act
like one, or the other, or both.

=head2 MAIN ROUTINES

These are the most important routines:

=over

=item new_score()  or  $obj = MIDI::Simple->new_score()

As a procedure, this initializes the package's default object (Score,
etc.).  As a method, this is a constructor, returning a new
MIDI::Simple object.  Neither form takes any parameters.

=cut

=item n(...parameters...)  or  $obj->n(...parameters...)

This uses the parameters given (and/or the state variables like
Volume, Channel, Notes, etc) to add a new note to the Score -- or
several notes to the Score, if Notes has more than one element in it
-- or no notes at all, if Notes is empty list.

Then it moves Time ahead as appropriate.  See the section "Parameters
For n/r/noop", below.

=cut

sub n { # a note
  my($am_method, $it) = (ref($_[0]) eq "MIDI::Simple")
    ? (1, shift @_)
    : (0, ($package{ (caller)[0] } ||= &_package_object( (caller)[0] )) );
  &MIDI::Simple::_parse_options($it, @_);
  foreach my $note_val (@{$it->{"Notes"}}) {
    # which should presumably not be a null list
    unless($note_val =~ /^\d+$/) {
      carp "note value \"$note_val\" from Notes is non-numeric!  Skipping.";
      next;
    }
    push @{$it->{"Score"}},
      ['note',
       int(${$it->{"Time"}}),
       int(${$it->{"Duration"}}),
       int(${$it->{"Channel"}}),
       int($note_val),
       int(${$it->{"Volume"}}),
      ];
  }
  ${$it->{"Time"}} += ${$it->{"Duration"}};
  return;
}
###########################################################################

=item r(...parameters...)  or  $obj->r(...parameters...)

This is exactly like C<n>, except it never pushes anything to Score,
but moves ahead Time.  (In other words, there is no such thing as a
rest-event; it's just a item during which there are no note-events
playing.)

=cut

sub r { # a rest
  my($am_method, $it) = (ref($_[0]) eq "MIDI::Simple")
    ? (1, shift @_)
    : (0, ($package{ (caller)[0] } ||= &_package_object( (caller)[0] )) );
  &MIDI::Simple::_parse_options($it, @_);
  ${$it->{"Time"}} += ${$it->{"Duration"}};
  return;
}
###########################################################################

=item noop(...parameters...)  or  $obj->noop(...parameters...)

This is exactly like C<n> and C<r>, except it never alters Score,
I<and> never changes Time.  It is meant to be used for setting the
other state variables, i.e.: Channel, Duration, Octave, Volume, Notes.

=cut

sub noop { # no operation
  my($am_method, $it) = (ref($_[0]) eq "MIDI::Simple")
    ? (1, shift @_)
    : (0, ($package{ (caller)[0] } ||= &_package_object( (caller)[0] )) );
  &MIDI::Simple::_parse_options($it, @_);
  return;
}

#--------------------------------------------------------------------------

=back

=cut

=head2 Parameters for n/r/noop

A parameter in an C<n>, C<r>, or C<noop> call is meant to change an
attribute (AKA state variable), namely Channel, Duration, Octave,
Volume, or Notes.

Here are the kinds of parameters you can use in calls to n/r/noop:

* A numeric B<volume> parameter.  This has the form "V" followed by a
positive integer in the range 0 (completely inaudible?) to 127 (AS
LOUD AS POSSIBLE).  Example: "V90" sets Volume to 90.

* An alphanumeric B<volume> parameter.  This is a key from the hash
%MIDI::Simple::Volume.  Current legal values are "ppp", "pp", "p",
"mp", "mezzo" (or "m"), "mf", "f", "ff", and "fff".  Example: "ff"
sets Volume to 112.  (Note that "m" isn't a good bareword, so use
"mezzo" instead, or just always remember to use quotes around "m".)

* A numeric B<channel> parameter.  This has the form "c" followed by a
positive integer 0 to 15.  Example: "c2", to set Channel to 2.

* A numeric B<duration> parameter.  This has the form "d" followed by
a positive (presumably nonzero) integer.  Example: "d48", to set
Duration to 48.

* An alphabetic (or in theory, possibly alphanumeric) B<duration>
parameter.  This is a key from the hash %MIDI::Simple::Length.
Current legal values start with "wn", "hn", "qn", "en", "sn" for
whole, half, quarter, eighth, or sixteenth notes.  Add "d" to the
beginning of any of these to get "dotted..." (e.g., "dqn" for a dotted
quarter note).  Add "dd" to the beginning of any of that first list to
get "double-dotted..."  (e.g., "ddqn" for a double-dotted quarter
note).  Add "t" to the beginning of any of that first list to get
"triplet..."  (e.g., "tsn" for a triplet sixteenth note -- i.e. a note
such that 3 of them add up to something as long as one eighth note).
You may add to the contents of %MIDI::Simple::Length to support
whatever abbreviations you want, as long as the parser can't mistake
them for any other kind of n/r/noop parameter.

* A numeric, absolute B<octave> specification.  This has the form: an
"o" (lowercase oh), and then an integer in the range 0 to 10,
representing an octave 0 to 10.  The Octave attribute is used only in
resolving relative note specifications, as explained further below in
this section.  (All absolute note specifications also set Octave to
whatever octave they occur in.)

* A numeric, relative B<octave> specification.  This has the form:
"o_d" ("d" for down) or "o_u" ("u" for down), and then an integer.
This increments, or decrements, Octave.  E.g., if Octave is 6, "o_d2"
will decrement Octave by 2, making it 4.  If this moves Octave below
0, it is forced to 0.  Or if it moves Octave above 10, it is forced to
10.  (For more information, see the section "Invalid or Out-of-Range
Parameters to n/r/noop", below.)

* A numeric, absolute B<note> specification.  This has the form: an
optional "n", and then an integer in the range 0 to 127, representing
a note ranging from C0 to G10.  The source to L<MIDI> has a useful
reference table showing the meanings of given note numbers.  Examples:
"n60", or "60", which each add a 60 to the list Notes.

Since this is a kind of absolute note specification, it sets Octave to
whatever octave the given numeric note occurs in.  E.g., "n60" is
"C5", and therefore sets Octave to 5.

The setting of the Notes list is a bit special, compared to how
setting the other attributes works.  If there are any note
specifications in a given parameter list for n, r, or noop, then all
those specifications together are assigned to Notes.

If there are no note specifications in the parameter list for n, r, or
noop, then Notes isn't changed.  (But see the description of "rest",
at the end of this section.)

So this:

  n mf, n40, n47, n50;

sets Volume to 80, and Notes to (40, 47, 50).  And it sets Octave,
first to 3 (since n40 is in octave 3), then to 3 again (since n47 =
B3), and then finally to 4 (since n50 = D4).

Note that this is the same as:

  n n40, n47, n50, mf;

The relative orders of parameters is B<usually> irrelevant; but see
the section "Order of Parameters in a Call to n/r/noop", below.

* An alphanumeric, absolute B<note> specification. 

These have the form: a string denoting a note within the octave (as
determined by %MIDI::Simple::Note -- see below, in the description of
alphanumeric, relative note specifications), and then a number
denoting the octave number (in the range 0-10).  Examples: "C3",
"As4" or "Asharp4", "Bf9" or "Bflat9".

Since this is a kind of absolute note specification, it sets Octave to
whatever octave the given numeric note occurs in.  E.g., "C3" sets
Octave to 3, "As4" sets Octave to 4, and "Bflat9" sets Octave to 9.

This:

  n E3, B3, D4, mf;

does the same as this example of ours from before:

  n n40, n47, n50, mf;

* An alphanumeric, relative B<note> specification. 

These have the form: a string denoting a note within the octave (as
determined by %MIDI::Simple::Note), and then an optional parameter
"_u[number]" meaning "so many octaves up from the current octave" or
"_d[parameter]" meaning "so many octaves down from the current
octave".

Examples: "C", "As" or "Asharp", "Bflat" or "Bf", "C_d3", "As_d1" or
"Asharp_d1", "Bflat_u3" or "Bf_u3".

In resolving what actual notes these kinds of specifications denote,
the current value of Octave is used.

What's a legal for the first bit (before any optional octave up/down
specification) comes from the keys to the hash %MIDI::Simple::Note.
The current acceptable values are:

 C                                 (maps to the value 0)
 Cs or Df or Csharp or Dflat       (maps to the value 1)
 D                                 (maps to the value 2)
 Ds or Ef or Dsharp or Eflat       (maps to the value 3)
 E                                 (maps to the value 4)
 F                                 (maps to the value 5)
 Fs or Gf or Fsharp or Gflat       (maps to the value 6)
 G                                 (maps to the value 7)
 Gs or Af or Gsharp or Aflat       (maps to the value 8)
 A                                 (maps to the value 9)
 As or Bf or Asharp or Bflat       (maps to the value 10)
 B                                 (maps to the value 11)

(Note that these are based on the English names for these notes.  If
you prefer to add values to accomodate other strings denoting notes in
the octave, you may do so by adding to the hash %MIDI::Simple::Note
like so:

  use MIDI::Simple;
  %MIDI::Simple::Note =
    (%MIDI::Simple::Note,  # keep all the old values
     'H' => 10,
     'Do' => 0,
     # ...etc...
    );

But the values you add must not contain any characters outside the
range [A-Za-z\x80-\xFF]; and your new values must not look like
anything that could be any other kind of specification.  E.g., don't
add "mf" or "o3" to %MIDI::Simple::Note.)

Consider that these bits of code all do the same thing:

  n E3, B3, D4, mf;       # way 1
  
  n E3, B,  D_u1, mf;     # way 2
  
  n o3, E, B,  D_u1, mf;  # way 3
  
  noop o3, mf;            # way 4
  n     E, B,  D_u1;

or even

  n o3, E, B, o4, D, mf;       # way 5!
  
  n o6, E_d3, B_d3, D_d2, mf;  # way 6!

If a "_d[number]" would refer to a note in an octave below 0, it is
forced into octave 0.  If a "_u[number]" would refer to a note in an
octave above 10, it is forced into octave 10.  E.g., if Octave is 8,
"G_u4" would resolve to the same as "G10" (not "G12" -- as that's out
of range); if Octave is 2, "G_d4" would resolve to the same as "G0".
(For more information, see the section "Invalid or Out-of-Range
Parameters to n/r/noop", below.)

* The string "C<rest>" acts as a sort of note specification -- it sets
Notes to empty-list.  That way you can make a call to C<n> actually
make a rest:

  n qn, G;    # makes a G quarter-note
  n hn, rest; # half-rest -- alters Notes, making it ()
  n C,G;      # half-note chord: simultaneous C and G
  r;          # half-rest -- DOESN'T alter Notes.
  n qn;       # quarter-note chord: simultaneous C and G
  n rest;     # quarter-rest
  n;          # another quarter-rest

(If you can follow the above code, then you understand.)

A "C<rest>" that occurs in a parameter list with other note specs
(e.g., "n qn, A, rest, G") has B<no effect>, so don't do that.

=head2 Order of Parameters in a Call to n/r/noop

The order of parameters in calls to n/r/noop is not important except
insofar as the parameters change the Octave parameter, which may change
how some relative note specifications are resolved.  For example:

  noop o4, mf;
  n G, B, A3, C;

is the same as "n mf, G4, B4, A3, C3".  But just move that "C" to the
start of the list:

  noop o4, mf;
  n C, G, B, A3;

and you something different, equivalent to "n mf, C4, G4, B4, A3".

But note that you can put the "mf" anywhere without changing anything.

But B<stylistically>, I strongly advise putting note parameters at the
B<end> of the parameter list:

  n mf, c10, C, B;  # 1. good
  n C, B, mf, c10;  # 2. bad
  n C, mf, c10, B;  # 3. so bad!

3 is particularly bad because an uninformed/inattentive reader may get
the impression that the C may be at a different volume and on a
different channel than the B.

(Incidentally, "n C5,G5" and "n G5,C5" are the same for most purposes,
since the C and the G are played at the same time, and with the same
parameters (channel and volume); but actually they differ in which
note gets put in the Score first, and therefore which gets encoded
first in the MIDI file -- but this makes no difference at all, unless
you're manipulating the note-items in Score or the MIDI events in a
track.)

=head2 Invalid or Out-of-Range Parameters to n/r/noop

If a parameter in a call to n/r/noop is uninterpretable, Perl dies
with an error message to that effect.

If a parameter in a call to n/r/noop has an out-of-range value (like
"o12" or "c19"), Perl dies with an error message to that effect.

As somewhat of a merciful exception to this rule, if a parameter in a
call to n/r/noop is a relative specification (whether like "o_d3" or
"o_u3", or like "G_d3" or "G_u3") which happens to resolve to an
out-of-range value (like "G_d3" given an Octave value of 2), then Perl
will B<not> die, but instead will silently try to bring that note back
into range, by forcing it up to octave 0 (if it would have been
lower), or down into 9 or 10 (if it would have been an octave higher
than 10, or a note higher than G10), as appropriate.

(This becomes strange in that, given an Octave of 8, "G_u4" is forced
down to G10, but "A_u4" is forced down to an A9.  But that boundary
has to pop up someplace -- it's just unfortunate that it's in the
middle of octave 10.)

=cut

sub _parse_options { # common parser for n/r/noop options
  # This is the guts of the whole module.  Understand this and you'll
  #  understand everything.
  my( $it, @args ) = @_;
  my @new_notes = ();
  print "options for _parse_options: ", map("<$_>", @args), "\n" if $Debug > 3;
  croak "no target for _parse_options" unless ref $it;
  foreach my $arg (@args) {
    next unless length($arg); # sanity check

    if($arg      =~ m<^d(\d+)$>s) {   # numeric duration spec
      ${$it->{"Duration"}} = $1;
    } elsif($arg =~ m<^[vV](\d+)$>s) {   # numeric volume spec
      croak "Volume out of range: $1" if $1 > 127;
      ${$it->{"Volume"}} = $1;
    } elsif($arg eq 'rest') {         # 'rest' clears the note list
      @{$it->{"Notes"}} = ();
    } elsif($arg =~ m<^c(\d+)$>s) {   # channel spec
      croak "Channel out of range: $1" if $1 > 15;
      ${$it->{"Channel"}} = $1;
    } elsif($arg =~ m<^o(\d+)$>s) {   # absolute octave spec
      croak "Octave out of range: \"$1\" in \"$arg\"" if $1 > 10;
      ${$it->{"Octave"}} = int($1);

    } elsif($arg =~ m<^n?(\d+)$>s) {  # numeric note spec
      # note that the "n" is optional
      croak "Note out of range: $1" if $1 > 127;
      push @new_notes, $1;
      ${$it->{"Octave"}} = int($1 / 12);

    # The more complex ones follow...

    } elsif( exists( $MIDI::Simple::Volume{$arg} )) {   # volume spec
      ${$it->{"Volume"}} = $MIDI::Simple::Volume{$arg};

    } elsif( exists( $MIDI::Simple::Length{$arg} )) {   # length spec
      ${$it->{"Duration"}} =
         ${$it->{"Tempo"}} * $MIDI::Simple::Length{$arg};

    } elsif($arg =~ m<^o_d(\d+)$>s) {    # rel (down) octave spec
      ${$it->{"Octave"}} -= int($1);
      ${$it->{"Octave"}} = 0 if ${$it->{"Octave"}} < 0;
      ${$it->{"Octave"}} = 10 if ${$it->{"Octave"}} > 10;

    } elsif($arg =~ m<^o_u(\d+)$>s) {    # rel (up) octave spec
      ${$it->{"Octave"}} += int($1);
      ${$it->{"Octave"}} = 0 if ${$it->{"Octave"}} < 0;
      ${$it->{"Octave"}} = 10 if ${$it->{"Octave"}} > 10;

    } elsif( $arg =~ m<^([A-Za-z\x80-\xFF]+)((?:_[du])?\d+)?$>s
             and exists( $MIDI::Simple::Note{$1})
           )
    {
      my $note = $MIDI::Simple::Note{$1};
      my $octave = ${$it->{"Octave"}};
      my $o_spec = $2;
      print "note<$1> => <$note> ; octave_spec<$2> Octave<$octave>\n"
        if $Debug;

      if(! (defined($o_spec) && length($o_spec))){
         # it's a bare note like "C" or "Bflat"
        # noop
      } elsif ($o_spec =~ m<^(\d+)$>s) {      # absolute! (alphanumeric)
        ${$it->{"Octave"}} = $octave = $1;
        croak "Octave out of range: \"$1\" in \"$arg\"" if $1 > 10;
      } elsif ($o_spec =~ m<^_d(\d+)$>s) {    # relative with _dN
        $octave -= $1;
        $octave = 0 if $octave < 0;
      } elsif ($o_spec =~ m<^_u(\d+)$>s) {    # relative with _uN
        $octave += $1;
        $octave = 10 if $octave > 10;
      } else {
        die "Unexpected error 5176123";
      }

      my $note_value = int($note + $octave * 12);

      # Enforce sanity...
      while($note_value < 0)   { $note_value += 12 } # bump up an octave
      while($note_value > 127) { $note_value -= 12 } # drop down an octave

      push @new_notes, $note_value;
        # 12 = number of MIDI notes in an octive

    } else {
      croak "Unknown note/rest option: \"$arg\"" if length($arg);
    }
  }
  @{$it->{"Notes"}} = @new_notes if @new_notes; # otherwise inherit last list

  return;
}

# Internal-use proc: create a package object for the package named.
sub _package_object {
  my $package = $_[0] || die "no package!!!";
  no strict;
  print "Linking to package $package\n" if $Debug;
  $package{$package} = bless {
    # note that these are all refs, not values
    "Score" => \@{"$package\::Score"},
    "Time" => \${"$package\::Time"},
    "Duration" => \${"$package\::Duration"},
    "Channel" => \${"$package\::Channel"},
    "Octave" => \${"$package\::Octave"},
    "Tempo" => \${"$package\::Tempo"},
    "Notes" => \@{"$package\::Notes"},
    "Volume" => \${"$package\::Volume"},
    "Cookies" => \%{"$package\::Cookies"},
  };

  &_init_score($package{$package});
  return $package{$package};
}

###########################################################################

sub new_score {
  my $p1 = $_[0];
  my $it;

  if(
    defined($p1) &&
    ($p1 eq 'MIDI::Simple'  or  ref($p1) eq 'MIDI::Simple')
  ) { # I'm a method!
    print "~ new_score as a MIDI::Simple constructor\n" if $Debug;
    $it = bless {};
    &_init_score($it);
  } else { # I'm a proc!
    my $cpackage = (caller)[0];
    print "~ new_score as a proc for package $cpackage\n" if $Debug;
    if( ref($package{ $cpackage }) ) {  # Already exists in %package
      print "~  reinitting pobj $cpackage\n" if $Debug;
      &_init_score(  $it = $package{ $cpackage }  );
      # no need to call _package_object
    } else {  # Doesn't exist in %package
      print "~  new pobj $cpackage\n" if $Debug;
      $package{ $cpackage } = $it = &_package_object( $cpackage );
      # no need to call _init_score
    }
  }
  return $it;   # for object use, we'll be capturing this
}

sub _init_score { # Set some default initial values for the object
  my $it = $_[0];
  print "Initting score $it\n" if $Debug;
  @{$it->{"Score"}} = (['text_event', 0, "$0 at " . scalar(localtime) ]);
  ${$it->{"Time"}} = 0;
  ${$it->{"Duration"}} = 96; # a whole note
  ${$it->{"Channel"}} = 0;
  ${$it->{"Octave"}} = 5;
  ${$it->{"Tempo"}} = 96; # ticks per qn
  @{$it->{"Notes"}} = (60); # middle C. why not.
  ${$it->{"Volume"}} = 64; # normal
  %{$it->{"Cookies"}} = (); # empty
  return;
}

###########################################################################
###########################################################################

=head2 ATTRIBUTE METHODS

The object attributes discussed above are readable and writeable with
object methods.  For each attribute there is a read/write method, and a
read-only method that returns a reference to the attribute's value:

  Attribute ||  R/W-Method ||   RO-R-Method
  ----------++-------------++--------------------------------------
  Score     ||  Score      ||   Score_r      (returns a listref)
  Notes     ||  Notes      ||   Notes_r      (returns a listref)
  Time      ||  Time       ||   Time_r       (returns a scalar ref)
  Duration  ||  Duration   ||   Duration_r   (returns a scalar ref)
  Channel   ||  Channel    ||   Channel_r    (returns a scalar ref)
  Octave    ||  Octave     ||   Octave_r     (returns a scalar ref)
  Volume    ||  Volume     ||   Volume_r     (returns a scalar ref)
  Tempo     ||  Tempo      ||   Tempo_r      (returns a scalar ref)
  Cookies   ||  Cookies    ||   Cookies_r    (returns a hashref)

To read any of the above via a R/W-method, call with no parameters,
e.g.:

  $notes = $obj->Notes;  # same as $obj->Notes()

The above is the read-attribute ("get") form.

To set the value, call with parameters:

  $obj->Notes(13,17,22);

The above is the write-attribute ("put") form.  Incidentally, when
used in write-attribute form, the return value is the same as the
parameters, except for Score or Cookies.  (In those two cases, I've
suppressed it for efficiency's sake.)

Alternately (and much more efficiently), you can use the read-only
reference methods to read or alter the above values;

  $notes_r = $obj->Notes_r;
  # to read:
  @old_notes = @$notes_r;
  # to write:
  @$notes_r = (13,17,22);

And this is the only way to set Cookies, Notes, or Score to a (),
like so:

  $notes_r = $obj->Notes_r;
  @$notes_r = ();

Since this:

  $obj->Notes;

is just the read-format call, remember?

Like all methods in this class, all the above-named attribute methods
double as procedures that act on the default object -- in other words,
you can say:

  Volume 10;              # same as:  $Volume = 10;
  @score_copy = Score;    # same as:  @score_copy = @Score
  Score @new_score;       # same as:  @Score = @new_score;
  $score_ref = Score_r;   # same as:  $score_ref = \@Score
  Volume(Volume + 10)     # same as:  $Volume += 10

But, stylistically, I suggest not using these procedures -- just
directly access the variables instead.

=cut

#--------------------------------------------------------------------------
# read-or-write methods

sub Score (;\@) { # yes, a prototype!
  my($am_method, $it) = (ref($_[0]) eq "MIDI::Simple")
    ? (1, shift @_)
    : (0, ($package{ (caller)[0] } ||= &_package_object( (caller)[0] )) );
  if(@_) {
    if($am_method){
      @{$it->{'Score'}} = @_;
    } else {
      @{$it->{'Score'}} = @{$_[0]}; # sneaky, huh!
    }
    return; # special case -- return nothing if this is a PUT
  } else {
    return @{$it->{'Score'}}; # you asked for it
  }
}

sub Cookies {
  my($it) = (ref($_[0]) eq "MIDI::Simple") ? (shift @_)
    : ($package{ (caller)[0] } ||= &_package_object( (caller)[0] ));
  %{$it->{'Cookies'}} = @_ if @_;  # Better have an even number of elements!
  return %{$it->{'Cookies'}};
}

sub Time {
  my($it) = (ref($_[0]) eq "MIDI::Simple") ? (shift @_)
    : ($package{ (caller)[0] } ||= &_package_object( (caller)[0] ));
  ${$it->{'Time'}} = $_[0] if @_;
  return ${$it->{'Time'}};
}

sub Duration {
  my($it) = (ref($_[0]) eq "MIDI::Simple") ? (shift @_)
    : ($package{ (caller)[0] } ||= &_package_object( (caller)[0] ));
  ${$it->{'Duration'}} = $_[0] if @_;
  return ${$it->{'Duration'}};
}

sub Channel {
  my($it) = (ref($_[0]) eq "MIDI::Simple") ? (shift @_)
    : ($package{ (caller)[0] } ||= &_package_object( (caller)[0] ));
  ${$it->{'Channel'}} = $_[0] if @_;
  return ${$it->{'Channel'}};
}

sub Octave {
  my($it) = (ref($_[0]) eq "MIDI::Simple") ? (shift @_)
    : ($package{ (caller)[0] } ||= &_package_object( (caller)[0] ));
  ${$it->{'Octave'}} = $_[0] if @_;
  return ${$it->{'Octave'}};
}

sub Tempo {
  my($it) = (ref($_[0]) eq "MIDI::Simple") ? (shift @_)
    : ($package{ (caller)[0] } ||= &_package_object( (caller)[0] ));
  ${$it->{'Tempo'}} = $_[0] if @_;
  return ${$it->{'Tempo'}};
}

sub Notes {
  my($it) = (ref($_[0]) eq "MIDI::Simple") ? (shift @_)
    : ($package{ (caller)[0] } ||= &_package_object( (caller)[0] ));
  @{$it->{'Notes'}} = @_ if @_;
  return @{$it->{'Notes'}};
}

sub Volume {
  my($it) = (ref($_[0]) eq "MIDI::Simple") ? (shift @_)
    : ($package{ (caller)[0] } ||= &_package_object( (caller)[0] ));
  ${$it->{'Volume'}} = $_[0] if @_;
  return ${$it->{'Volume'}};
}

#-#-#-#-#-#-#-#-##-#-#-#-#-#-#-#-#-#-#-#-##-#-#-#-#-#-#-#-##-#-#-#-#-#-#-#-
# read-only methods that return references

sub Score_r {
  my($it) = (ref($_[0]) eq "MIDI::Simple") ? (shift @_)
    : ($package{ (caller)[0] } ||= &_package_object( (caller)[0] ));
  return $it->{'Score'};
}

sub Time_r {
  my($it) = (ref($_[0]) eq "MIDI::Simple") ? (shift @_)
    : ($package{ (caller)[0] } ||= &_package_object( (caller)[0] ));
  return $it->{'Time'};
}

sub Duration_r {
  my($it) = (ref($_[0]) eq "MIDI::Simple") ? (shift @_)
    : ($package{ (caller)[0] } ||= &_package_object( (caller)[0] ));
  return $it->{'Duration'};
}

sub Channel_r {
  my($it) = (ref($_[0]) eq "MIDI::Simple") ? (shift @_)
    : ($package{ (caller)[0] } ||= &_package_object( (caller)[0] ));
  return $it->{'Channel'};
}

sub Octave_r {
  my($it) = (ref($_[0]) eq "MIDI::Simple") ? (shift @_)
    : ($package{ (caller)[0] } ||= &_package_object( (caller)[0] ));
  return $it->{'Octave'};
}

sub Tempo_r {
  my($it) = (ref($_[0]) eq "MIDI::Simple") ? (shift @_)
    : ($package{ (caller)[0] } ||= &_package_object( (caller)[0] ));
  return $it->{'Tempo'};
}

sub Notes_r {
  my($it) = (ref($_[0]) eq "MIDI::Simple") ? (shift @_)
    : ($package{ (caller)[0] } ||= &_package_object( (caller)[0] ));
  return $it->{'Notes'};
}

sub Volume_r {
  my($it) = (ref($_[0]) eq "MIDI::Simple") ? (shift @_)
    : ($package{ (caller)[0] } ||= &_package_object( (caller)[0] ));
  return $it->{'Volume'};
}

sub Cookies_r {
  my($it) = (ref($_[0]) eq "MIDI::Simple") ? (shift @_)
    : ($package{ (caller)[0] } ||= &_package_object( (caller)[0] ));
  return $it->{'Cookies'};
}

###########################################################################
###########################################################################

=head2 MIDI EVENT ROUTINES

These routines, below, add a MIDI event to the Score, with a
start-time of Time.  Example:

  text_event "And now the bongos!";  # procedure use
  
  $obj->text_event "And now the bongos!";  # method use

These are named after the MIDI events they add to the score, so see
L<MIDI::Event> for an explanation of what the data types (like
"velocity" or "pitch_wheel") mean.  I've reordered this list so that
what I guess are the most important ones are toward the top:


=over

=item patch_change I<channel>, I<patch>;

=item key_after_touch I<channel>, I<note>, I<velocity>;

=item channel_after_touch I<channel>, I<velocity>;

=item control_change I<channel>, I<controller(0-127)>, I<value(0-127)>;

=item pitch_wheel_change I<channel>, I<pitch_wheel>;

=item set_tempo I<tempo>;  (See the section on tempo, below.)

=item smpte_offset I<hr>, I<mn>, I<se>, I<fr>, I<ff>;

=item time_signature I<nn>, I<dd>, I<cc>, I<bb>;

=item key_signature I<sf>, I<mi>;

=item text_event I<text>;

=item copyright_text_event I<text>;

=item track_name I<text>;

=item instrument_name I<text>;

=item lyric I<text>;

=item set_sequence_number I<sequence>;

=item marker I<text>;

=item cue_point I<text>;

=item sequencer_specific I<raw>;

=item sysex_f0 I<raw>;

=item sysex_f7 I<raw>;

=back


And here's the ones I'll be surprised if anyone ever uses:

=over

=item text_event_08 I<text>;

=item text_event_09 I<text>;

=item text_event_0a I<text>;

=item text_event_0b I<text>;

=item text_event_0c I<text>;

=item text_event_0d I<text>;

=item text_event_0e I<text>;

=item text_event_0f I<text>;

=item raw_meta_event I<command>(0-255), I<raw>;

=item song_position I<starttime>;

=item song_select I<song_number>;

=item tune_request I<starttime>;

=item raw_data I<raw>;

=item end_track I<starttime>;

=item note I<duration>, I<channel>, I<note>, I<velocity>;

=back

=cut

sub key_after_touch ($$$) { &_common_push('key_after_touch', @_) }
sub control_change ($$$) { &_common_push('control_change', @_) }
sub patch_change ($$) { &_common_push('patch_change', @_) }
sub channel_after_touch ($$) { &_common_push('channel_after_touch', @_) }
sub pitch_wheel_change ($$) { &_common_push('pitch_wheel_change', @_) }
sub set_sequence_number ($) { &_common_push('set_sequence_number', @_) }
sub text_event ($) { &_common_push('text_event', @_) }
sub copyright_text_event ($) { &_common_push('copyright_text_event', @_) }
sub track_name ($) { &_common_push('track_name', @_) }
sub instrument_name ($) { &_common_push('instrument_name', @_) }
sub lyric ($) { &_common_push('lyric', @_) }
sub marker ($) { &_common_push('marker', @_) }
sub cue_point ($) { &_common_push('cue_point', @_) }
sub text_event_08 ($) { &_common_push('text_event_08', @_) }
sub text_event_09 ($) { &_common_push('text_event_09', @_) }
sub text_event_0a ($) { &_common_push('text_event_0a', @_) }
sub text_event_0b ($) { &_common_push('text_event_0b', @_) }
sub text_event_0c ($) { &_common_push('text_event_0c', @_) }
sub text_event_0d ($) { &_common_push('text_event_0d', @_) }
sub text_event_0e ($) { &_common_push('text_event_0e', @_) }
sub text_event_0f ($) { &_common_push('text_event_0f', @_) }
sub end_track ($) { &_common_push('end_track', @_) }
sub set_tempo ($) { &_common_push('set_tempo', @_) }
sub smpte_offset ($$$$$) { &_common_push('smpte_offset', @_) }
sub time_signature ($$$$) { &_common_push('time_signature', @_) }
sub key_signature ($$) { &_common_push('key_signature', @_) }
sub sequencer_specific ($) { &_common_push('sequencer_specific', @_) }
sub raw_meta_event ($$) { &_common_push('raw_meta_event', @_) }
sub sysex_f0 ($) { &_common_push('sysex_f0', @_) }
sub sysex_f7 ($) { &_common_push('sysex_f7', @_) }
sub song_position () { &_common_push('song_position', @_) }
sub song_select ($) { &_common_push('song_select', @_) }
sub tune_request () { &_common_push('tune_request', @_) }
sub raw_data ($) { &_common_push('raw_data', @_) }

sub _common_push {
  # I'm your doctor when you need / Have some coke
  # / Want some weed / I'm Your Pusher Man
  #print "*", map("<$_>", @_), "\n";
  my(@p) = @_;
  my $event = shift @p;
  my $it;
  if(ref($p[0]) eq "MIDI::Simple") {
    $it = shift @p;
  } else {
    $it = ($package{ (caller(1))[0] } ||= &_package_object( (caller(1))[0] ) );
  }
  #print "**", map("<$_>", @p), " from ", ()[0], "\n";

  #printf "Pushee to %s 's %s: e<%s>, t<%s>, p<%s>\n",
  #       $it, $it->{'Score'}, $event, ${$it->{'Time'}}, join("~", @p);
  push @{$it->{'Score'}},
    [ $event, ${$it->{'Time'}}, @p ];
  return;
}

=head2 About Tempo

The chart above shows that tempo is set with a method/procedure that
takes the form set_tempo(I<tempo>), and L<MIDI::Event> says that
I<tempo> is "microseconds, a value 0 to 16,777,215 (0x00FFFFFF)".
But at the same time, you see that there's an attribute of the
MIDI::Simple object called "Tempo", which I've warned you to leave at
the default value of 96.  So you may wonder what the deal is.

The "Tempo" attribute (AKA "Divisions") is an integer that specifies
the number of "ticks" per MIDI quarter note.  Ticks is just the
notional timing unit all MIDI events are expressed in terms of.
Calling it "Tempo" is misleading, really; what you want to change to
make your music go faster or slower isn't that parameter, but instead
the mapping of ticks to actual time -- and that is what C<set_tempo>
does.  Its one parameter is the number of microseconds each quarter
note should get.

Suppose you wanted a tempo of 120 quarter notes per minute.  In terms
of microseconds per quarter note:

  set_tempo 500_000; # you can use _ like a thousands-separator comma

In other words, this says to make each quarter note take up 500,000
microseconds, namely .5 seconds.  And there's 120 of those
half-seconds to the minute; so, 120 quarter notes to the minute.

If you see a "[quarter note symbol] = 160" in a piece of sheet music,
and you want to figure out what number you need for the C<set_tempo>,
do:

  60_000_000 / 160  ... and you get:  375_000

Therefore, you should call:

  set_tempo 375_000;

So in other words, this general formula:

  set_tempo int(60_000_000 / $quarter_notes_per_minute);

should do you fine.

As to the Tempo/Duration parameter, leave it alone and just assume
that 96 ticks-per-quarter-note is a universal constant, and you'll be
happy.

(You may wonder: Why 96?  As far as I've worked out, all purmutations
of the normal note lengths (whole, half, quarter, eighth, sixteenth,
and even thirty-second notes) and tripletting, dotting, or
double-dotting, times 96, all produce integers.  For example, if a
quarter note is 96 ticks, then a double-dotted thirty-second note is
21 ticks (i.e., 1.75 * 1/8 * 96).  But that'd be a messy 10.5 if there
were only 48 ticks to a quarter note.  Now, if you wanted a quintuplet
anywhere, you'd be out of luck, since 96 isn't a factor of five.  It's
actually 3 * (2 ** 5), i.e., three times two to the fifth.  If you
really need quintuplets, then you have my very special permission to
mess with the Tempo attribute -- I suggest multiples of 96, e.g., 5 *
96.)

(You may also have read in L<MIDI::Filespec> that C<time_signature>
allows you to define an arbitrary mapping of your concept of quarter
note, to MIDI's concept of quarter note.  For your sanity and mine,
leave them the same, at a 1:1 mapping -- i.e., with an '8' for
C<time_signature>'s last parameter, for "eight notated 32nd-notes per
MIDI quarter note".  And this is relevant only if you're calling
C<time_signature> anyway, which is not necessarily a given.)

=cut

###########################################################################
###########################################################################

=head2 MORE ROUTINES

=over

=cut

sub _test_proc {
  my($am_method, $it) = (ref($_[0]) eq "MIDI::Simple")
    ? (1, shift @_)
    : (0, ($package{ (caller)[0] } ||= &_package_object( (caller)[0] )) );
  print " am method: $am_method\n it: $it\n params: <", join(',',@_), ">\n";
}

###########################################################################

=item $opus = write_score I<filespec>

=item $opus = $obj->write_score(I<filespec>)

Writes the score to the filespec (e.g, "../../samples/funk2.midi", or
a variable containing that value), with the score's Ticks as its tick
parameters (AKA "divisions").  Among other things, this function calls
the function C<make_opus>, below, and if you capture the output of
write_score, you'll get the opus created, if you want it for anything.
(Also: you can also use a filehandle-reference instead of the
filespec: C<write_score *STDOUT{IO}>.)

=cut

sub write_score {
  my($am_method, $it) = (ref($_[0]) eq "MIDI::Simple")
    ? (1, shift @_)
    : (0, ($package{ (caller)[0] } ||= &_package_object( (caller)[0] )) );
  my($out, $ticks, $score_r) =
    ( $_[0], (${$it->{'Tempo'}} || 96), $it->{'Score'} );

  croak "First parameter to MIDI::Simple::write_score can't be null\n"
    unless( ref($out) || length($out) );
  croak "Ticks can't be 0" unless $ticks;

  carp "Writing a score with no notes!" unless @$score_r;
  my $opus = $it->make_opus;
# $opus->dump( { 'dump_tracks' => 1 } );

  if(ref($out)) {
    $opus->write_to_handle($out);
  } else {
    $opus->write_to_file($out);
  }
  return $opus; # capture it if you want it.
}

###########################################################################

=item read_score I<filespec>

=item $obj = MIDI::Simple->read_score('foo.mid'))

In the first case (a procedure call), does C<new_score> to erase and
initialize the object attributes (Score, Octave, etc), then reads from
the file named.  The file named has to be a MIDI file with exactly one
eventful track, or Perl dies.  And in the second case, C<read_score>
acts as a constructor method, returning a new object read from the
file.

Score, Ticks, and Time are all affected:

Score is the event form of all the MIDI events in the MIDI file.
(Note: I<Seriously> deformed MIDI files may confuse the routine that
turns MIDI events into a Score.)

Ticks is set from the ticks setting (AKA "divisions") of the file.

Time is set to the end time of the latest event in the file.

(Also: you can also use a filehandle-reference instead of the
filespec: C<read_score *STDIN{IO}>.)

If ever you have to make a Score out of a single track from a
I<multitrack> file, read the file into an $opus, and then consider
something like:

        new_score;
        $opus = MIDI::Opus->new({ 'from_file' => "foo2.mid" });
        $track = ($opus->tracks)[2]; # get the third track
        
        ($score_r, $end_time) =
          MIDI::Score::events_r_to_score_r($track->events_r);

        $Ticks = $opus->ticks;
        @Score =  @$score_r;
        $Time = $end_time;

=cut

sub read_score {
  my $am_cons = ($_[0] eq "MIDI::Simple");
  shift @_ if $am_cons;

  my $in = $_[0];

  my($track, @eventful_tracks);
  croak "First parameter to MIDI::Simple::read_score can't be null\n"
    unless( ref($in) || length($in) );

  my $in_switch = ref($in) ? 'from_handle' : 'from_file';
  my $opus = MIDI::Opus->new({ $in_switch => $in });

  @eventful_tracks = grep( scalar(@{$_->events_r}),  $opus->tracks );
  if(@eventful_tracks == 0) {
    croak "Opus from $in has NO eventful tracks to consider as a score!\n";
  } elsif (@eventful_tracks > 1) {
    croak
      "Opus from $in has too many (" .
        scalar(@eventful_tracks) . ") tracks to be a score.\n";
  } # else OK...
  $track = $eventful_tracks[0];
  #print scalar($track->events), " events in track\n";

  # If ever you want just a single track as a score, here's how:
  #my $score_r =  ( MIDI::Score::events_r_to_score_r($track->events_r) )[0];
  my( $score_r, $time) = MIDI::Score::events_r_to_score_r($track->events_r);
  #print scalar(@$score_r), " notes in score\n";

  my $it;
  if($am_cons) { # just make a new object and return it.
    $it = MIDI::Simple->new_score;
    $it->{'Score'} = $score_r;
  } else { # need to fudge it back into the pobj
    my $cpackage = (caller)[0];
    #print "~ read_score as a proc for package $cpackage\n";
    if( ref($package{ $cpackage }) ) {  # Already exists in %package
      print "~  reinitting pobj $cpackage\n" if $Debug;
      &_init_score(  $it = $package{ $cpackage }  );
      # no need to call _package_object
    } else {  # Doesn't exist in %package
      print "~  new pobj $cpackage\n" if $Debug;
      $package{ $cpackage } = $it = &_package_object( $cpackage );
      # no need to call _init_score
    }
    @{$it->{'Score'}} = @$score_r;
  }
  ${$it->{'Tempo'}} = $opus->ticks;
  ${$it->{'Time'}} = $time;

  return $it;
}
###########################################################################

=item synch( LIST of coderefs )

=item $obj->synch( LIST of coderefs )

LIST is a list of coderefs (whether as a series of anonymous subs, or
as a list of items like C<(\&foo, \&bar, \&baz)>, or a mixture of
both) that C<synch> calls in order to add to the given object -- which
in the first form is the package's default object, and which in the
second case is C<$obj>.  What C<synch> does is:

* remember the initial value of Time, before calling any of the
routines;

* for each routine given, reset Time to what it was initially, call
the routine, and then note what the value of Time is, after each call;

* then, after having called all of the routines, set Time to whatever
was the greatest (equals latest) value of Time that resulted from any
of the calls to the routines.

The coderefs are all called with one argument in C<@_> -- the object
they are supposed to affect.  All these routines should/must therefore
use method calls instead of procedure calls.  Here's an example usage
of synch:

        my $measure = 0;
        my @phrases =(
          [ Cs, F,  Ds, Gs_d1 ], [Cs,    Ds, F, Cs],
          [ F,  Cs, Ds, Gs_d1 ], [Gs_d1, Ds, F, Cs]
        );
        
        for(1 .. 20) { synch(\&count, \&lalala); }
        
        sub count {
          my $it = $_[0];
          $it->r(wn); # whole rest
          # not just "r(wn)" -- we want a method, not a procedure!
          ++$measure;
        }
        
        sub lalala {
          my $it = $_[0];
          $it->noop(c1,mf,o3,qn); # setup
          my $phrase_number = ($measure + -1) % 4;
          my @phrase = @{$phrases[$phrase_number]};
          foreach my $note (@phrase) { $it->n($note); }
        }

=cut

sub synch {
  my($am_method, $it) = (ref($_[0]) eq "MIDI::Simple")
    ? (1, shift @_)
    : (0, ($package{ (caller)[0] } ||= &_package_object( (caller)[0] )) );

  my @subs = grep(ref($_) eq 'CODE', @_);

  print " My subs: ", map("<$_> ", @subs), ".\n"
   if $Debug;
  return unless @subs;
  # my @end_times = (); # I am the Lone Array of the Apocalypse!
  my $orig_time = ${$it->{'Time'}};
  my $max_time  = $orig_time;
  foreach my $sub (@subs) {
    printf " Before %s\:  Entry time: %s   Score items: %s\n",
            $sub, $orig_time, scalar(@{$it->{'Score'}}) if $Debug;
    ${$it->{'Time'}} = $orig_time; # reset Time

    &{$sub}($it); # now call it

    printf "   %s items ending at %s\n",
     scalar( @{$it->{'Score'}} ), ${$it->{'Time'}} if $Debug;
    $max_time = ${$it->{'Time'}} if ${$it->{'Time'}} > $max_time;
  }
  print " max end-time of subs: $max_time\n" if $Debug;

  # now update and get out
  ${$it->{'Time'}} = $max_time;
}

########################################################################### 

=item $opus = make_opus  or  $opus = $obj->make_opus

Makes an opus (a MIDI::Opus object) out of Score, setting the opus's
tick parameter (AKA "divisions") to $ticks.  The opus is,
incidentally, format 0, with one track.

=cut

sub make_opus {
  # Make a format-0 one-track MIDI out of this score.

  my($am_method, $it) = (ref($_[0]) eq "MIDI::Simple")
    ? (1, shift @_)
    : (0, ($package{ (caller)[0] } ||= &_package_object( (caller)[0] )) );

  my($ticks, $score_r) = (${$it->{'Tempo'}}, $it->{'Score'});
  carp "Encoding a score with no notes!" unless @$score_r;
  my $events_r = ( MIDI::Score::score_r_to_events_r($score_r) )[0];
  carp "Creating a track with no events!" unless @$events_r;

  my $opus =
    MIDI::Opus->new({ 'ticks'  => $ticks,
                      'format' => 0,
                      'tracks' => [ MIDI::Track->new({
                                                    'events' => $events_r
                                                   }) ]
                    });
  return $opus;
}

###########################################################################

=item dump_score  or  $obj->dump_score

Dumps Score's contents, via C<print> (so you can C<select()> an output
handle for it).  Currently this is in this somewhat uninspiring format:

  ['note', 0, 96, 1, 25, 96],
  ['note', 96, 96, 1, 29, 96],

as it is (currently) just a call to &MIDI::Score::dump_score; but in
the future I may (should?) make it output in C<n>/C<r> notation.  In
the meantime I assume you'll use this, if at all, only for debugging
purposes.

=cut

sub dump_score {
  my($am_method, $it) = (ref($_[0]) eq "MIDI::Simple")
    ? (1, shift @_)
    : (0, ($package{ (caller)[0] } ||= &_package_object( (caller)[0] )) );
  return &MIDI::Score::dump_score( $it->{'Score'} );
}

###########################################################################
###########################################################################

=back

=head2 FUNCTIONS

These are subroutines that aren't methods and don't affect anything
(i.e., don't have "side effects") -- they just take input and/or give
output.

=over

=item interval LISTREF, LIST

This takes a reference to a list of integers, and a list of note-pitch
specifications (whether relative or absolute), and returns a list
consisting of the given note specifications transposed by that many
half-steps.  E.g.,

  @majors = interval [0,4,7], C, Bflat3;

which returns the list C<(C,E,G,Bf3,D4,F4)>.

Items in LIST which aren't note specifications are passed thru
unaltered.

=cut

sub interval { # apply an interval to a list of notes.
  my(@out);
  my($am_method, $it) = (ref($_[0]) eq "MIDI::Simple")
    ? (1, shift @_)
    : (0, ($package{ (caller)[0] } ||= &_package_object( (caller)[0] )) );
  my($interval_r, @notes) = @_;

  croak "first argument to &MIDI::Simple::interval must be a listref\n"
   unless ref($interval_r);
  # or a valid key into a hash %Interval?

  foreach my $note (@notes) {
    my(@them, @status, $a_flag, $note_number);
    @status = &is_note_spec($note);
    unless(@status) { # not a note spec
      push @out, $note;
    }

    ($a_flag, $note_number) = @status;
    @them = map { $note_number + $_ } @$interval_r;

    if($a_flag) { # If based on an absolute note spec.
      if($note =~ m<^\d+$>s) {   # "12"
        # no-op -- leave as is
      } elsif ($note =~ m<^n\d+$>s) { # "n12"
        @them = map("n$_", @them);
      } else {                        # "C4"
        @them = map(&number_to_absolute($_), @them);
      }
    } else { # If based on a relative note spec.
      @them = map(&number_to_relative($_), @them);
    }
    push @out, @them;
  }
  return @out;
}
#--------------------------------------------------------------------------

=item note_map { BLOCK } LIST

This is pretty much based on (or at least inspired by) the normal Perl
C<map> function, altho the syntax is a bit more restrictive (i.e.,
C<map> can take the form C<map {BLOCK} LIST> or C<map(EXPR,LIST)> --
the latter won't work with C<note_map>).

C<note_map {BLOCK} (LIST)> evaluates the BLOCK for each element of
LIST (locally setting $_ to each element's note-number value) and
returns the list value composed of the results of each such
evaluation.  Evaluates BLOCK in a list context, so each element of
LIST may produce zero, one, or more elements in the returned value.
Moreover, besides setting $_, C<note_map> feeds BLOCK (which it sees
as an anonymous subroutine) three parameters, which BLOCK can access
in @_ :

  $_[0]  :  Same as $_.  I.e., The current note-specification,
            as a note number.
            This is the result of having fed the original note spec
            (which you can see in $_[2]) to is_note_spec.

  $_[1]  :  The absoluteness flag for this note, from the
            above-mentioned call to is_note_spec.
            0 = it was relative (like 'C')
            1 = it was absolute (whether as 'C4' or 'n41' or '41')

  $_[2] : the actual note specification from LIST, if you want
            to access it for any reason.

Incidentally, any items in LIST that aren't a note specification are
passed thru unchanged -- BLOCK isn't called on it.

So, in other words, what C<note_map> does, for each item in LIST, is:

* It calls C<is_note_spec> on it to test whether it's a note
specification at all.  If it isn't, just passes it thru.  If it is,
then C<note_map> stores the note number and the absoluteness flag that
C<is_note_spec> returned, and...

* It calls BLOCK, providing the note number in $_ and $_[0], the
absoluteness flag in $_[1], and the original note specification in
$_[2].  Stores the return value of calling BLOCK (in a list context of
course) -- this should be a list of note numbers.

* For each element of the return value (which is actually free to be
an empty list), converts it from a note number to whatever B<kind> of
specification the original note value was.  So, for each element, if
the original was relative, C<note_map> interprets the return value as
a relative note number, and calls C<number_to_relative> on it; if it
was absolute, C<note_map> will try to restore it to the
correspondingly formatted absolute specification type.

An example is, I hope, helpful:

This:

        note_map { $_ - 3, $_ + 2 }  qw(Cs3 n42 50 Bf)

returns this:

        ('Bf2', 'Ef3', 'n39', 'n44', '47', '52', 'G', 'C_u1')

Or, to line things up:

          Cs3       n42       50      Bf
           |         |        |       |
        /-----\   /-----\   /---\   /----\
        Bf2 Ef3   n39 n44   47 52   G C_u1

Now, of course, this is the same as what this:

        interval [-3, 2], qw(Cs3 n42 50 Bf)

returns.  This is fitting, as C<interval>, internally, is basically a
simplified version of C<note_map>.  But C<interval> only lets you do
unconditional transposition, whereas C<note_map> lets you do anything
at all.  For example:

       @note_specs = note_map { $funky_lookup_table{$_} }
                              C, Gf;

or

       @note_specs = note_map { $_ + int(rand(2)) }
                              @stuff;

C<note_map>, like C<map>, can seem confusing to beginning programmers
(and many intermediate ones, too), but it is quite powerful.

=cut

sub note_map (&@) { # map a function to a list of notes
  my($sub, @notes) = @_;
  return() unless @notes;

  return
    map {
      # For each input note...
      my $note = $_;
      my @status = &is_note_spec($note);
      if(@status) {
        my($a_flag, $note_number) = @status;
        my $orig_note = $note;  # Just in case BLOCK changes it!
        my $orig_a_flag = $a_flag;  # Ditto!
        my @them = map { &{$sub}($note_number, $a_flag, $note ) }
                       $note_number;

        if($orig_a_flag) { # If based on an absolute note spec.
          # try to duplicate the original format
          if($orig_note =~ m<^\d+$>s) {   # "12"
            # no-op -- leave as is
          } elsif ($orig_note =~ m<^n\d+$>s) { # "n12"
            @them = map("n$_", @them);
          } else {                        # "C4"
            @them = map(&number_to_absolute($_), @them);
          }
        } else { # If based on a relative note spec.
          @them = map(&number_to_relative($_), @them);
        }
        @them;
      } else { # it wasn't a real notespec
        $note;
      }
    }
  @notes
  ;
}

###########################################################################

=item number_to_absolute NUMBER

This returns the absolute note specification (in the form "C5") that
the MIDI note number in NUMBER represents.

This is like looking up the note number in %MIDI::number2note -- not
exactly the same, but effectively the same.  See the source for more
details.

=cut

sub number_to_absolute ($) {
  my $in = int($_[0]);
  # Look for @Note at the top of this document.
  return( $MIDI::Simple::Note[ $in % 12 ] . int($in / 12) );
}

=item the function number_to_relative NUMBER

This returns the relative note specification that NUMBER represents.
The idea of a numerical representation for C<relative> note
specifications was necessitated by C<interval> and C<note_map> --
since without this, you couldn't meaningfully say, for example,
interval [0,2] 'F'.  This should illustrate the concept:

          number_to_relative(-10)   =>   "D_d1"
          number_to_relative( -3)   =>   "A_d1"
          number_to_relative(  0)   =>   "C"
          number_to_relative(  5)   =>   "F"
          number_to_relative( 10)   =>   "Bf"
          number_to_relative( 19)   =>   "G_u1"
          number_to_relative( 40)   =>   "E_u3"

=cut

sub number_to_relative ($) {
  my $o_spec;
  my $in = int($_[0]);

  if($in < 0) { # Negative, so 'octave(s) down'
    $o_spec = '_d' . (1 + abs(int(($in + 1) / 12)));  # Crufty, but it works.
  } elsif($in < 12) {  # so 'same octave'
    $o_spec = '';
  } else {  # Positive, greater than 12, so 'N octave(s) up'
    $o_spec = '_u' . int($in / 12);
  }
  return( $MIDI::Simple::Note[ $in % 12 ] . $o_spec );
}

###########################################################################

=item is_note_spec STRING

If STRING is a note specification, C<is_note_spec(STRING)> returns a
list of two elements: first, a flag of whether the note specification
is absolute (flag value 1) or relative (flag value 0); and second, a
note number corresponding to that note specification.  If STRING is
not a note specification, C<is_note_spec(STRING)> returns an empty
list (which in a boolean context is FALSE).

Implementationally, C<is_note_spec> just uses C<is_absolute_note_spec>
and C<is_relative_note_spec>.

Example usage:

        @note_details = is_note_spec($thing);
        if(@note_details) {
          ($absoluteness_flag, $note_num) = @note_details;
          ...stuff...
        } else {
          push @other_stuff, $thing;  # or whatever
        }

=cut

sub is_note_spec ($) {
  # if false, return()
  # if true,  return(absoluteness_flag, $note_number)
  my($in, @ret) = ($_[0]);
  return() unless length $in;
  @ret = &is_absolute_note_spec($in);  return(1, @ret) if @ret;
  @ret = &is_relative_note_spec($in);  return(0, @ret) if @ret;
  return();
}

=item is_relative_note_spec STRING

If STRING is an relative note specification, returns the note number
for that specification as a one-element list (which in a boolean
context is TRUE).  Returns empty-list (which in a boolean context is
FALSE) if STRING is NOT a relative note specification.

To just get the boolean value:

      print "Snorf!\n" unless is_relative_note_spec($note);

But to actually get the note value:

      ($note_number) = is_relative_note_spec($note);

Or consider this:

      @is_rel = is_relative_note_spec($note);
      if(@is_rel) {
        $note_number = $is_rel[0];
      } else {
        print "Snorf!\n";
      }

(Author's note, two years later: all this business of returning lists
of various sizes, with this and other functions in here, is basically
a workaround for the fact that there's not really any such thing as a
boolean context in Perl -- at least, not as far as user-defined
functions can see.  I now think I should have done this with just
returning a single scalar value: a number (which could be 0!) if the
input is a number, and undef/emptylist (C<return;>) if not -- then,
the user could test:

      # Hypothetical --
      # This fuction doesn't actually work this way:
      if(defined(my $note_val = is_relative_note_spec($string))) {
         ...do things with $note_val...
      } else {
         print "Hey, that's no note!\n";
      }

However, I don't anticipate users actually using these messy functions
often at all -- I basically wrote these for internal use by
MIDI::Simple, then I documented them on the off chance they I<might>
be of use to anyone else.)

=cut

sub is_relative_note_spec ($) {
  # if false, return()
  # if true,  return($note_number)
  my($note_number, $octave_number, $in, @ret) = (-1, 0, $_[0]);
  return() unless length $in;

  if($in =~ m<^([A-Za-z]+)$>s   # Cs
     and exists( $MIDI::Simple::Note{$1} )
  ){
    $note_number = $MIDI::Simple::Note{$1};
  } elsif($in =~ m<^([A-Za-z]+)_([du])(\d+)$>s   # Cs_d4, Cs_u1
     and exists( $MIDI::Simple::Note{$1} )
  ){
    $note_number = $MIDI::Simple::Note{$1};
    $octave_number = $3;
    $octave_number *= -1  if $2 eq "d";
  } else {
    @ret = ();
  }
  unless($note_number == -1) {
    @ret = ( $note_number + $octave_number * 12 );
  }
  return @ret;
}

=item is_absolute_note_spec STRING

Just like C<is_relative_note_spec>, but for absolute note
specifications instead of relative ones.

=cut

sub is_absolute_note_spec ($) {
  # if false, return()
  # if true,  return($note_number)
  my($note_number, $in, @ret) = (-1, $_[0]);
  return() unless length $in;
  if( $in =~ /^n?(\d+)$/s ) {  # E.g.,  "29", "n38"
    $note_number = 0 + $1;
  } elsif( $in =~ /^([A-Za-z]+)(\d+)/s ) {  # E.g.,  "C3", "As4"
    $note_number = $MIDI::Simple::Note{$1} + $2 * 12
      if exists($MIDI::Simple::Note{$1});
  }
  @ret = ($note_number) if( $note_number >= 0 and $note_number < 128);
  return @ret;
}

#--------------------------------------------------------------------------

=item Self() or $obj->Self();

Presumably the second syntax is useless -- it just returns $obj.  But
the first syntax returns the current package's default object.

Suppose you write a routine, C<funkify>, that does something-or-other
to a given MIDI::Simple object.  You could write it so that acts on
the current package's default object, which is fine -- but, among
other things, that means you can't call C<funkify> from a sub you have
C<synch> call, since such routines should/must use only method calls.
So let's say that, instead, you write C<funkify> so that the first
argument to it is the object to act on.  If the MIDI::Simple object
you want it to act on is it C<$sonata>, you just say

  funkify($sonata)

However, if you want it to act on the current package's default
MIDI::Simple object, what to say?  Simply,

  $package_opus = Self;
  funkify($package_opus);

=cut

sub Self { # pointless as a method -- but as a sub, useful if
  # you want to access your current package's object.
  # Juuuuuust in case you need it.
  my($am_method, $it) = (ref($_[0]) eq "MIDI::Simple")
    ? (1, shift @_)
    : (0, ($package{ (caller)[0] } ||= &_package_object( (caller)[0] )) );
  return $it;
}

=back

=cut

###########################################################################

=head1 COPYRIGHT 

Copyright (c) 1998-2005 Sean M. Burke. All rights reserved.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 AUTHOR

Sean M. Burke C<sburke@cpan.org>

=cut

1;

__END__
