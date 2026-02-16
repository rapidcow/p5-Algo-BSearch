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

done_testing;
