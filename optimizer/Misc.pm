###############################################################################
#
# Misc.pm
#
# Copyright 2009, Jeremy Sharpe
# 
# Created by: Jeremy Sharpe
#
# Contains miscellaneous functions that get used in lots of different places.
#
###############################################################################
package Misc;

use strict;

# general subroutines
# Gets the gcd of an arbitrarily long list of numbers
sub gcd {
    my ($a, $b, @Rest) = @_;
    if(@_ == 1) {
        return $a;
    }
    while($b != 0) {
        my $t = $b;
        $b = $a % $b;
        $a = $t;
    }
    if(scalar @Rest == 0) {
        return $a;
    } else {
        return gcd($a, @Rest);
    }
}

# returns the min of a list of numbers.
sub min {
    my $min = $_[0];
    foreach(@_) {
        if($_ < $min) {
            $min = $_;
        }
    }
    return $min;
}

# returns the max of a list of numbers.
sub max {
    return -(min(map {-$_} @_));
}

1;
