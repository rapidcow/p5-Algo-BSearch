#!perl

use strict;
use warnings;

use Test::More;
use Sort::Search qw(blsrch2 brsrch2);

my @pi = (1, 1, 2, 3, 3, 4, 5, 5, 5, 6, 8, 9, 9);
my ($lo, $hi);

sub arraymap {
	my @map;
	my $index = 0;
	while (@_ >= 2) {
		my $pos = shift;
		$pos == $index || die "out of order: got $index not $pos?\n";
		push @map, shift;
	}
	continue {
		$index += 1;
	}
	@map;
}

my @rngLH = arraymap(
	0 => [ 0,  0],  1 => [ 0,  2],  2 => [ 2,  3],
	3 => [ 3,  5],  4 => [ 5,  6],  5 => [ 6,  9],
	6 => [ 9, 10],  7 => [10, 10],  8 => [10, 11],
	9 => [11, 13], 10 => [13, 13], 11 => [13, 13],
);

my @rngRH = arraymap(
	0 => [-1, -1],  1 => [-1,  1],  2 => [ 1,  2],
	3 => [ 2,  4],  4 => [ 4,  5],  5 => [ 5,  8],
	6 => [ 8,  9],  7 => [ 9,  9],  8 => [ 9, 10],
	9 => [10, 12], 10 => [12, 12], 11 => [12, 12],
);

sub trace {
	my ($mem, $fun) = @_;
	sub {
		my $cmp = &$fun;
		my $sgn = $cmp < 0 ? "-" : $cmp > 0 ? "+" : "0";
		push @$mem, sprintf "[%2s]%2s<%s>", $_[0], $_, $sgn;
		return $cmp;
	};
}

ok 1;
diag "Range test!";  # flush for prove...

diag "Left range:";
for my $i (0..11) {
	my @trace = ();
	my ($lo, $hi) = blsrch2 \&{ trace \@trace, sub { $_ <=> $i } }, \@pi;
	diag "i=$i @trace => [$lo,$hi] expect [@{[ join(',', @{$rngRH[$i]})] }]";
	is ($lo, $rngLH[$i]->[0], "LH lower bound for i=$i");
	is ($hi, $rngLH[$i]->[1], "LH upper bound for i=$i");
}

diag "Right range:";
for my $i (0..11) {
	my @trace = ();
	my ($hi, $lo) = brsrch2 \&{ trace \@trace, sub { $i <=> $_ } }, \@pi;
	diag "i=$i @trace => [$lo,$hi] expect [@{[ join(',', @{$rngRH[$i]})] }]";
	is ($hi, $rngRH[$i]->[1], "RH lower bound for i=$i");
	is ($lo, $rngRH[$i]->[0], "RH upper bound for i=$i");
}

{
	my @verylow = (-1, -1, -1, -1, 0);
	my (@trace, $lo, $hi);
	diag "<<< Random tests >>>";

	@trace = ();
	($lo, $hi) = blsrch2 \&{ trace \@trace, sub { $_ <=> 99 } }, \@verylow;
	diag "i=99 @trace => [$lo,$hi]";
	is_deeply [$lo, $hi], [5, 5];

	@trace = ();
	($lo, $hi) = blsrch2 \&{ trace \@trace, sub { $_ <=> -2 } }, \@verylow;
	diag "i=-2 @trace => [$lo,$hi]";
	is_deeply [$lo, $hi], [0, 0];

	@trace = ();
	($lo, $hi) = blsrch2 \&{ trace \@trace, sub { $_ <=> -1 } }, \@verylow;
	diag "i=-1 @trace => [$lo,$hi]";
	is_deeply [$lo, $hi], [0, 4];

	@trace = ();
	($lo, $hi) = blsrch2 \&{ trace \@trace, sub { $_ <=> 0 } }, \@verylow;
	diag "i=0 @trace => [$lo,$hi]";
	is_deeply [$lo, $hi], [4, 5];
}

{
	my @trace;
	@trace = ();
	($lo, $hi) = blsrch2 \&{ trace \@trace, sub { $_ < 97 ? -1 : 98 <= $_ ? 1 : 0 } }, 0, 100;
	diag "i=0 @trace => [$lo,$hi]";
	is_deeply [$lo, $hi], [97, 98];

	@trace = ();
	($lo, $hi) = blsrch2 \&{ trace \@trace, sub { $_ < 97 ? -1 : 98 <= $_ ? 1 : 0 } }, -2147483648, 2147483647;
	diag "i=0 @trace => [$lo,$hi]";
	is_deeply [$lo, $hi], [97, 98];

	@trace = ();
	($lo, $hi) = blsrch2 \&{ trace \@trace, sub { $_ < -12345678 ? -1 : 76543210 <= $_ ? 1 : 0 } }, -2147483648, 2147483647;
	diag "i=0 @trace => [$lo,$hi]";
	is_deeply [$lo, $hi], [-12345678, 76543210];
}
done_testing();
