###############################################################################
#
# PathOutput.pm
#
# Created by: Nic Wolfe
#
# Parent class for all output classes.
#
###############################################################################

package PathOutput;

use strict;
use File::Path;

sub new {
  my ($class) = @_;
  my $self = {
    _songtitle => undef,
    _midname => undef,
    _game => "rb2",
    _inst => "guitar",
    _diff => "expert",
    _lazy => 0,
    _squeeze => 0,
    _whammy => 0,
    _tmpdir => undef,
    _resultspath => undef,
    _resultsfilename => undef,
    _silent => 0,
    _nopath => 0,
    _expmnt => 0
  };
  bless $self, $class;
  return $self;
}

sub songtitle {
    my ( $self, $songtitle ) = @_;
    $self->{_songtitle} = $songtitle if defined($songtitle);
    return $self->{_songtitle};
}

sub midname {
  my ( $self, $midname ) = @_;
  $self->{_midname} = $midname if defined($midname);
  return $self->{_midname};
}

sub game {
    my ( $self, $game ) = @_;
    $self->{_game} = $game if defined($game);
    return $self->{_game};
}

sub inst {
    my ( $self, $inst ) = @_;
    $self->{_inst} = $inst if defined($inst);
    return $self->{_inst};
}

sub diff {
    my ( $self, $diff ) = @_;
    $self->{_diff} = $diff if defined($diff);
    return $self->{_diff};
}

sub lazy {
    my ( $self, $lazy ) = @_;
    $self->{_lazy} = $lazy if defined($lazy);
    return $self->{_lazy};
}

sub squeeze {
    my ( $self, $squeeze ) = @_;
    $self->{_squeeze} = $squeeze if defined($squeeze);
    return $self->{_squeeze};
}

sub whammy {
    my ( $self, $whammy ) = @_;
    $self->{_whammy} = $whammy if defined($whammy);
    return $self->{_whammy};
}

sub silent {
    my ( $self, $silent ) = @_;
    $self->{_silent} = $silent if defined($silent);
    return $self->{_silent};
}

sub nopath {
    my ( $self, $nopath ) = @_;
    $self->{_nopath} = $nopath if defined($nopath);
    return $self->{_nopath};
}

sub expmnt {
    my ( $self, $expmnt ) = @_;
    $self->{_expmnt} = $expmnt if defined($expmnt);
    return $self->{_expmnt};
}

sub tmppath {
  my ($self, $tmpdir) = @_;
  
  if ($tmpdir) {
    $self->{_tmpdir} = $tmpdir;
  }
  return $self->{_tmpdir};
}

sub resultspath {
  my ($self, $resultspath) = @_;

  my $diff = $self->diff;
  my $inst = $self->inst;
  my $game = $self->game;

  # allow the path to be forced
  if ($resultspath) {
    $self->{_resultspath} = $resultspath;
  } elsif (!$self->{_resultspath}) {
    $self->{_resultspath} = lc("paths/".($diff?"$diff/":"").($inst?"$inst/":"").($game?"$game/":""));
  }

  return $self->{_resultspath};
}

sub resultsfilename {
  my ($self, $resultsfilename) = @_;

  my $songtitle = $self->songtitle;
  my $midname = $self->midname;
  my $diff = $self->diff;
  my $inst = $self->inst;
  my $lazy = $self->lazy;
  my $squeeze = $self->squeeze;
  my $whammy = $self->whammy;
  my $expmnt = $self->expmnt;

  # allow the filename to be forced
  if ($resultsfilename) {
    $self->{_resultsfilename} = $resultsfilename;
  } else {
    $self->{_resultsfilename} = lc("$midname.".lc($diff).".".lc($inst).".$lazy.$squeeze.$whammy.");
    if ($expmnt) {
      $self->{_resultsfilename} .= "e.";
    }
  }

  return $self->{_resultsfilename};
}

sub needsRegen {
	my ($self) = @_;
	
	my $outpath = $self->resultspath().$self->resultsfilename();
	
	if (-e $outpath && $self->nopath) {
		return 0;
	} else {
		return 1;
	}
}

sub generatepath {
  my ($self, @Ticks) = @_;
  my $outpath = $self->resultspath().$self->resultsfilename();

  if (-e $outpath && $self->nopath) {
    print "Path $outpath already exists, skipping generation\n" if !$self->silent;
    return $outpath;
  }

  $self->createoutputfile;

  $self->buildpath(@Ticks);

  $self->finishpath;

  return $outpath;

}

# prepare the output file for writing if applicable (needs to be overridden if needed
sub createoutputfile {
  my ($self) = @_;

  mkpath($self->resultspath) unless (-e $self->resultspath);

}

# put together the path
sub buildpath {
  my ($self, @Ticks) = @_;

  print "Parent buildpath is empty\n";

}

# write it to the file, clean up
sub finishpath {
  my ($self) = @_;

  print "Parent finishpath is empty\n";

}

1;
