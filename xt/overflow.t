#!perl

use strict;
use warnings;

use Sort::Search;
use Test::More;
plan('no_plan');  # XXX: under development

# https://stackoverflow.com/a/15133735/19411800
use constant uvmin => +0;  # (is actually an IV...)
use constant uvmax => ~0;
use constant ivmax => uvmax >> 1;
use constant ivmin => -ivmax - 1;

BEGIN {
	if ($ENV{PERL_SS_TRACE}) {
		note "uvmin ", explain uvmin;
		note "uvmax ", explain uvmax;
		note "ivmin ", explain ivmin;
		note "ivmax ", explain ivmax;
		no strict 'refs';
		# The foreach loop seems to create a closure...
		# Not sure if it has always been this way, but
		# this is for debugging anyways, so eh. I'm
		# just gonna take that for granted :]
		# https://stackoverflow.com/a/6587579/19411800
		foreach my $name (qw(not_ok all_ok)) {
			*$name = sub {
				my $index = do {
					my $class = ref $_[0];
					unless ($class) {
						$_[0] < 0
						? sprintf '- %x', -$_[0]
						: sprintf '+ %x', +$_[0];
					} else {
						'@ ' .
						$class eq 'Math::BigInt' ?
						$_[0]->to_hex() : "$_[0]";
					}
				};
				note "  CALL $name $index";
				$name eq "all_ok";
			};
		}
	} else {
		*not_ok = sub { 0 };
		*all_ok = sub { 1 };
	}
}

my ($i, $j);

{
	$i = Sort::Search::bisectl(\&not_ok, ivmin, ivmax);
	cmp_ok $i, '==', ivmax, "bisectl !!0 on [ivmin, ivmax) = ivmax";

	$j = Sort::Search::bisectl(\&all_ok, ivmin, ivmax);
	cmp_ok $j, '==', ivmin, "bisectl !!1 on [ivmin, ivmax) = ivmin";
}

{
	$i = Sort::Search::bisectl(\&not_ok, uvmin, uvmax);
	cmp_ok $i, '==', uvmax, "bisectl !!0 on [uvmin, uvmax) = uvmax";

	$j = Sort::Search::bisectl(\&all_ok, uvmin, uvmax);
	cmp_ok $j, '==', uvmin, "bisectl !!1 on [uvmin, uvmax) = uvmin";
}

{
	$i = Sort::Search::bisectl(\&not_ok, -1, uvmax);
	cmp_ok $i, '==', uvmax, "bisectl !!0 on [-1, uvmax) = uvmax";

	$j = Sort::Search::bisectl(\&all_ok, -1, uvmax);
	cmp_ok $j, '==', -1, "bisectl !!1 on [-1, uvmax) = -1";

	# Ensure that the index sequence starts at floor(LO + HI)
	# The first sum is simple -- just 2**N - 2 on an N-bit perl.
	# Divide that by 2 and it's 2**(N-1) - 1, or ivmax.
	eval { Sort::Search::bisectl(sub { die "$_\n" }, -1, uvmax) };
	cmp_ok $@, '==', ivmax, "bisectl on [-1, uvmax) starts at ivmax";

	# On my 64-bit Perl, this quotient is:
	# >>> divmod(((2**64 - 1) + (-2**63)), 2)
	# (4611686018427387903, 1)
	# >>> hex(_[0])
	# '0x3fffffffffffffff'
	# (Computed with Python 3, since %#x here is easier :)
	#
	# The floor rounds down the remainder, so it's just
	# 4611686018427387903, 0x3f{15}... or ivmax >> 1.
	eval { Sort::Search::bisectl(sub { die "$_\n" }, ivmin, uvmax) };
	cmp_ok $@, '==', ivmax >> 1, "bisectl on [ivmin, uvmax) starts at ivmax >> 1";
}

{
	$i = Sort::Search::bisectr(\&not_ok, ivmax, ivmin);
	cmp_ok $i, '==', ivmin, "bisectr !!1 on (ivmin, ivmax] = ivmin";

	$j = Sort::Search::bisectr(\&all_ok, ivmax, ivmin);
	cmp_ok $j, '==', ivmax, "bisectr !!0 on (ivmin, ivmax] = ivmax";
}

{
	$i = Sort::Search::bisectr(\&not_ok, uvmax, uvmin);
	cmp_ok $i, '==', uvmin, "bisectr !!1 on (uvmin, uvmax] = uvmin";

	$i = Sort::Search::bisectr(\&all_ok, uvmax, uvmin);
	cmp_ok $i, '==', uvmax, "bisectr !!1 on (uvmin, uvmax] = uvmax";
}

{
	$i = Sort::Search::bisectr(\&not_ok, uvmax, -1);
	cmp_ok $i, '==', -1, "bisectr !!0 on (-1, uvmax] = -1";

	$j = Sort::Search::bisectr(\&all_ok, uvmax, -1);
	cmp_ok $j, '==', uvmax, "bisectr !!1 on (-1, uvmax] = uvmax";

	# Ensure that the index sequence starts at ceil(LO + HI)
	# The first quotient is the same as before with bisectl,
	# while the second quotient is rounded up.
	eval { Sort::Search::bisectr(sub { die "$_\n" }, uvmax, -1) };
	cmp_ok $@, '==', ivmax, "bisectr on (-1, uvmax] starts at ivmax";

	eval { Sort::Search::bisectr(sub { die "$_\n" }, uvmax, ivmin) };
	cmp_ok $@, '==', 1 + ivmax >> 1, "bisectr on (ivmin, uvmax] starts at 1 + ivmax >> 1";
}

done_testing;
