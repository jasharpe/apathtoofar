###############################################################################
#
# RBDump.pm
#
# Copyright 2009, Jeremy Sharpe
#
# Created by: Jeremy Sharpe
#
# Contains dump file processing functions (read and write)
#
###############################################################################
package RBDump;

use strict;

# Constants to dump
my @Constants = ('WHAMMY_PER_TICK', 'OD_MULT', 'OD_PHRASE_VALUE', 'OD_ACTIVATE', 'MAX_OD', 'MAX_SQUEEZE', 'VERBOSE', 'MAX_FRONT_TIMING_WINDOW', 'MAX_BACK_TIMING_WINDOW', 'MAX_EARLY_WHAMMY_WINDOW', 'NUM_TICKS');
# Values to dump for each tick
my @TickPrint = qw(note sustain OD endOD solobonus whammy whammyOD realwhammy whammyable fill fillbonus ODuse mult ticksToEndOfSustain value susval noteval frontSqueezeOD maxFrontSqueezeOD backSqueezeOD maxBackSqueezeOD earlyWhammyOD maxEarlyWhammyOD whammyChange len);

sub readdump {
  my ($dumpfile) = @_;
  open(DUMP, "$dumpfile") or die "Can't open $dumpfile: $!";
  my @Ticks;

  my %CONSTANTS;
  foreach my $constant (@Constants) {
    chomp(my $line = <DUMP>);
    $CONSTANTS{$constant} = $line;
  }

  for (my $tick = 0; $tick < $CONSTANTS{'NUM_TICKS'}; $tick++) {
    chomp(my $line = <DUMP>);
    my @Tick = split(/\s+/, $line);
    my %TICK;
    my $propertycount = 0;
    foreach my $property (@TickPrint) {
      $TICK{$property} = $Tick[$propertycount];
      $propertycount++;
    }
    $TICK{timesig}{den} = $Tick[$propertycount];
    $propertycount++;
    $TICK{timesig}{num} = $Tick[$propertycount];
    $propertycount++;
    foreach (0..4) {
      $TICK{notes}[$_] = $Tick[$propertycount];
      $propertycount++;
    }
    push(@Ticks, \%TICK);
  }

  return (\%CONSTANTS, \@Ticks);
}

sub writedump {
  my ($constants, $ticks, $dumpfile) = @_;
  my %CONSTANTS = %{$constants};
  my @Ticks = @{$ticks};

  open(DUMP, "> $dumpfile") or die "Can't open $dumpfile: $!";
  # Print OD settings
  foreach my $setting (@Constants) {
      print DUMP $CONSTANTS{$setting}."\n";
  }

  foreach my $tick (@Ticks) {
      my @ThisTickPrint = map {($tick->{$_} or 0)} @TickPrint;
      push (@ThisTickPrint, $tick->{timesig}{den});
      push (@ThisTickPrint, $tick->{timesig}{num});
      push (@ThisTickPrint, @{$tick->{notes}});
      push (@ThisTickPrint, @{$tick->{earlyWhammyODAmount}});
      print DUMP join(" ", @ThisTickPrint)."\n";
  }
  close(DUMP);
}

1;
