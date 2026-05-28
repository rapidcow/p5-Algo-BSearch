#!perl

use 5.006;
use strict;
use warnings;

use Sort::Search qw(bisectl);
use Test::More tests => 7;

is ((bisectl { -$_ < 1 } 0, 8), 0, "case of all T");
is ((bisectl {  $_ > 2 } 0, 8), 3, "case of some F, some T");
is ((bisectl {  $_ > 7 } 0, 8), 8, "case of all F but last");
is ((bisectl {  $_ > 8 } 0, 8), 8, "case of all F, including last");

is ((bisectl { 1 } 0, 0), 0, "degenerate case of all T");
is ((bisectl { 0 } 0, 0), 0, "degenerate case of all F");

# proof of concept (with diagrams, again)
#
# for x = (1,2,..i):
#     <=sqrt   <=sqrt   >sqrt   >sqrt  ...
#              ^^^^^^   ^^^^^
#              isqrt    isqrt+1
#
# for x = (-i,-i+1,..-2,-1):
#     >sqrt    >sqrt    <=sqrt  <=sqrt
#              ^^^^^^   ^^^^^^
#            -isqrt-1   -isqrt
#
# in other words -isqrt is the first i s.t.
#
#     0<-x<=sqrt(i) <=> (-x)^2<=i && (-x-1)^2>i \ provided that
#   && -x-1>sqrt(i) <=> x*x<=i && (x+1)(x+1)>i  / <=> x<0.
#
{
	# named subroutines have package scope :(
	# https://www.perlmonks.org/?node_id=741744
	my $isqrt = sub {
		my ($i) = @_;
		return -(bisectl { $_ * $_ <= $i } -$i, 0);
	};
	is ($isqrt->(2025), 45, "isqrt with bisectl");
}
