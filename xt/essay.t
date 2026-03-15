#!perl

use strict;
use warnings;

use Sort::Search qw(bisectl bisectr);
use Test::More tests => 1;

subtest '00INTRO.txt' => sub {
plan tests => 16;

my %bisectl = (
	samp => sub {
		my ($ok, $lo, $hi) = @_;
		while ($lo < $hi) {
			# This computes the floor of ($lo+$hi) / 2
			# -- without floating point arithmetic! :^)
			my $mid = $lo + (($hi - $lo) >> 1);
			if ($ok->($mid)) {
				$hi = $mid;       # include
			} else {
				$lo = $mid + 1;   # exclude
			}
		} $hi
	},
	real => sub {
		my ($ok, $lo, $hi) = @_;
		scalar bisectl { $ok->($_) } $lo, $hi;
	},
);

foreach my $impl (qw(samp real)) {
	# "bisect_in_reverse", or "last_false"
	my $bisectr_mockimpl = sub {
		my ($ok, $lo, $hi) = @_;
		-$bisectl{$impl}->( sub { !$ok->( -$_[0] ) }, -$lo, -$hi );
	};

	my $isqrt_mockimpl = sub {
		my ($S) = @_;
		$bisectr_mockimpl->( sub { $_[0] * $_[0] > $S }, $S, -1 );
	};

	cmp_ok ($isqrt_mockimpl->(2024), '==', 20+24
		=> "isqrt: mock-$impl 2024");
	cmp_ok ($isqrt_mockimpl->(2025), '==', 20+25
		=> "isqrt: mock-$impl 2025");
	cmp_ok ($isqrt_mockimpl->(2026), '==', 45
		=> "isqrt: mock-$impl 2026");
	cmp_ok ($isqrt_mockimpl->(-729), '==', -1
		=> "isqrt: mock-$impl -729");
}

my %bisectr = (
	samp => sub {
		my ($ok, $hi, $lo) = @_;
		while ($lo < $hi) {
			# This computes the ceiling of ($lo+$hi) / 2!
			# Contrast with floor in left bisection...
			my $mid = $lo + (($hi - $lo + 1) >> 1);
			if ($ok->($mid)) {
				$lo = $mid;      # include
			} else {
				$hi = $mid - 1;  # exclude
			}
		} $lo
	},
	real => sub {
		my ($ok, $hi, $lo) = @_;
		scalar bisectr { $ok->($_) } ($hi, $lo);
	},
);

foreach my $impl (qw(samp real)) {
	my $isqrt_impl = sub {
		my ($S) = @_;
		$bisectr{$impl}->( sub { $_[0] * $_[0] <= $S }, $S, -1 );
	};

	cmp_ok ($isqrt_impl->(2024), '==', 20+24
		=> "isqrt: $impl 2024");
	cmp_ok ($isqrt_impl->(2025), '==', 20+25
		=> "isqrt: $impl 2025");
	cmp_ok ($isqrt_impl->(2026), '==', 45
		=> "isqrt: $impl 2026");
	cmp_ok ($isqrt_impl->(-729), '==', -1
		=> "isqrt: $impl -729");
}

}; # '00INTRO.txt' subtest
