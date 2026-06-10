#!perl
# t/20-mean.t - integer range midpoint
use 5.006;
use strict;
use warnings;
use Test::More tests => 50;

use Sort::Search qw(bixectl bixectr);

sub numfmt {
	ref($_[0]) ? "$_[0]" : sprintf '%s%#x', (
		$_[0] < 0 ? ('-', -$_[0]) : ('+', +$_[0])
	);
}

my $uvmin = ( +0 );  # (is actually an IV...)
my $uvmax = ( ~0 );
my $ivmax = ( $uvmax >> 1 );
my $ivmin = ( -$ivmax - 1 );

note "DBG: uvmin " . numfmt $uvmin;
note "DBG: uvmax " . numfmt $uvmax;
note "DBG: ivmax " . numfmt $ivmax;
note "DBG: ivmin " . numfmt $ivmin;

sub lmean { scalar bixectl { 1 } $_[0], $_[1]; }
sub rmean { scalar bixectr { 1 } $_[1], $_[0]; }

sub lmean_ok {
	local $Test::Builder::Level = $Test::Builder::Level + 1;
	my $mesg = sprintf "lmean(%s, %s) = %s", map { numfmt($_) } @_;
	cmp_ok (lmean( $_[0], $_[1] ), '==', ( $_[2] ), $mesg);
}

	lmean_ok +( 0, 1 ) => ( 0 );
	lmean_ok +( -10, 42 ) => ( 16 );
	lmean_ok +( 0, 69 ) => ( 34 );
	lmean_ok +( -1, 0 ) => ( -1 );
	lmean_ok +( -42, 10 ) => ( -16 );
	lmean_ok +( -69, 0 ) => ( -35 );

sub rmean_ok {
	local $Test::Builder::Level = $Test::Builder::Level + 1;
	my $mesg = sprintf "rmean(%s, %s) = %s", map {
		ref($_) ? "$_" : sprintf '%s%#x', (
			$_ < 0 ? ('-', -$_) : ('+', +$_)
		)
	} @_;
	cmp_ok (rmean( $_[0], $_[1] ), '==', ( $_[2] ), $mesg);
}

	rmean_ok +( 0, 1 ) => ( 1 );
	rmean_ok +( -10, 42 ) => ( 16 );
	rmean_ok +( 0, 69 ) => ( 35 );
	rmean_ok +( -1, 0 ) => ( 0 );
	rmean_ok +( -42, 10 ) => ( -16 );
	rmean_ok +( -69, 0 ) => ( -34 );

SKIP: {
	$] >= 5.008 or skip ("lossy IV+UV arithmetic", 8);

	lmean_ok +( $uvmin, $ivmax ) => ( $ivmax >> 1 );
	lmean_ok +( $uvmin, $uvmax ) => ( $ivmax );
	lmean_ok +( $ivmin, $ivmax ) => ( -1 );
	lmean_ok +( $ivmin, $uvmax ) => ( $ivmax >> 1 );

	rmean_ok +( $uvmin, $ivmax ) => ( $ivmax >> 1 ) + 1;
	rmean_ok +( $uvmin, $uvmax ) => ( $ivmax ) + 1;
	rmean_ok +( $ivmin, $ivmax ) => ( 0 );
	rmean_ok +( $ivmin, $uvmax ) => ( $ivmax >> 1 ) + 1;
}

# Math::BigInt should be in core, but technically
# we never required it ourselves in TEST_REQUIRES...
SKIP: {
	eval { require Math::BigInt; 1 } or skip ("No Math::BigInt", 30);

	my $ZERO = Math::BigInt->new("0");
	my $ONE = Math::BigInt->new("1");

# Let's use an absurdly big number no system is known
# to use to ensure that native integer math isn't used.
	my $u256_min = $ZERO;
	my $u256_max = ($ONE << 256) - $ONE;
	my $i256_min = - ($ONE << 255);
	my $i256_max = ($ONE << 255) - $ONE;

	lmean_ok +( $u256_min, $i256_max ) => ( $i256_max >> 1 );
	lmean_ok +( $u256_min, $u256_max - 2 ) => ( $i256_max ) - 1;
	lmean_ok +( $u256_min, $u256_max - 1 ) => ( $i256_max );
	lmean_ok +( $u256_min, $u256_max ) => ( $i256_max );
	lmean_ok +( $i256_min, $i256_max ) => ( -1 );
	lmean_ok +( $i256_min, $u256_max ) => ( $i256_max >> 1 );

	lmean_ok +( $i256_min, $i256_min + 1 ) => ( $i256_min );
	lmean_ok +( $i256_min, $i256_min + 2 ) => ( $i256_min + 1 );
	lmean_ok +( $i256_min, $i256_min + 3 ) => ( $i256_min + 1 );
	lmean_ok +( $i256_max - 1, $i256_max ) => ( $i256_max - 1 );
	lmean_ok +( $i256_max - 2, $i256_max ) => ( $i256_max - 1 );
	lmean_ok +( $i256_max - 3, $i256_max ) => ( $i256_max - 2 );
	lmean_ok +( $u256_max - 1, $u256_max ) => ( $u256_max - 1 );
	lmean_ok +( $u256_max - 2, $u256_max ) => ( $u256_max - 1 );
	lmean_ok +( $u256_max - 3, $u256_max ) => ( $u256_max - 2 );

	rmean_ok +( $u256_min, $i256_max ) => ( $i256_max >> 1 ) + 1;
	rmean_ok +( $u256_min, $u256_max - 2 ) => ( $i256_max );
	rmean_ok +( $u256_min, $u256_max - 1 ) => ( $i256_max );
	rmean_ok +( $u256_min, $u256_max ) => ( $i256_max ) + 1;
	rmean_ok +( $i256_min, $i256_max ) => ( 0 );
	rmean_ok +( $i256_min, $u256_max ) => ( $i256_max >> 1 ) + 1;

	rmean_ok +( $i256_min, $i256_min + 1 ) => ( $i256_min + 1 );
	rmean_ok +( $i256_min, $i256_min + 2 ) => ( $i256_min + 1 );
	rmean_ok +( $i256_min, $i256_min + 3 ) => ( $i256_min + 2 );
	rmean_ok +( $i256_max - 1, $i256_max ) => ( $i256_max );
	rmean_ok +( $i256_max - 2, $i256_max ) => ( $i256_max - 1 );
	rmean_ok +( $i256_max - 3, $i256_max ) => ( $i256_max - 1 );
	rmean_ok +( $u256_max - 1, $u256_max ) => ( $u256_max );
	rmean_ok +( $u256_max - 2, $u256_max ) => ( $u256_max - 1 );
	rmean_ok +( $u256_max - 3, $u256_max ) => ( $u256_max - 1 );
}
