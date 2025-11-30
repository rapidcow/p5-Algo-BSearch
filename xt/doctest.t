#!perl

use 5.006;
use strict;
use warnings;

use Sort::Search qw(blsrch0);
use Test::More tests => 3;

sub search {
    my ($array, $want) = @_;
    my ($idx, $cmp, $elt) = blsrch0 { $_ <=> $want } $array;
    if (!defined $cmp) { "$want not found anywhere" }
    elsif ($cmp != 0)  { "$want not found; the best "
                         . "I got was $elt at [$idx]" }
    else               { "$want found at [$idx] :)" }
}

my $list = [1, 1, 2, 3, 3, 4, 5, 5, 5, 6, 8, 9, 9];
is(( search $list => 5 ),  "5 found at [6] :)", "first equal example #1");
is(( search $list => 7 ),  "7 not found; the best I got was 8 at [10]",
                                                  "first equal example #2");
is(( search $list => 10 ), "10 not found anywhere", "first equal example #3");
