#!perl

use 5.006;
use strict;
use warnings;

use FastLook qw(bisectr);
use Test::More tests => 1;

{
    my $isqrt = sub {
        my ($i) = @_;
        return bisectr { $_ * $_ <= $i } $i, 0;
    };
    is ($isqrt->(2025), 45, "isqrt with bisectr");
}
