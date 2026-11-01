#!perl
use 5.006;
use strict;
use warnings;
use Test::More;

use Sort::Search;
sub bisect (&$$) {
    scalar &Sort::Search::bisectl;
}

BEGIN { plan tests => 1; }

{
	my @uvw =
		grep { /0/ }
		( bisect { $_ > 19 } 0, 32 ), # 20
		( bisect { $_ > 24 } 0, 32 ), # 25
		( bisect { $_ >  9 } 0, 32 ), # 10
		( bisect { $_ >= 0 } 0, 32 ); # 0

	is_deeply (\@uvw, [20, 10, 0], 'scope of $_ with bisect')
		or diag explain { uvw => \@uvw };
}

# Most tests there cannot be ported here...
