#!perl

use 5.006;
use strict;
use warnings;

use Sort::Search qw(bisectr);
use Test::More tests => 5;

{
	my $isqrt = sub {
		my ($i) = @_;
		return bisectr { $_ * $_ <= $i } $i, 0;
	};
	is ($isqrt->(2025), 45, "isqrt with bisectr");
	is ($isqrt->(2024), 44, "isqrt, slightly less");
	is ($isqrt->(2026), 45, "isqrt, slightly more");
	is ($isqrt->(0), 0, "isqrt, boundary case");
	is ($isqrt->(-1), 0, "isqrt, degenerate case");
}
