#!perl
# t/10-mean.t - midpoints over potentially big IV/UV
use 5.006;
use strict;
use warnings;

use Test::More tests => 72;
use Sort::Search qw(bixectl bixectr);

use constant uvmin => ( +0 );  # (is actually an IV...)
use constant uvmax => ( ~0 );
use constant ivmax => ( uvmax() >> 1 );
use constant ivmin => ( -ivmax() - 1 );

BEGIN {
	no strict 'refs';
	foreach my $name (qw( uvmin uvmax ivmin ivmax )) {
		foreach (&{"::$name"}) {
			note "DBG: $name " . sprintf "%s%#x",
			$_ < 0 ? ('-', -$_) : ('+', +$_);
		}
	}
}

sub lmean { scalar bixectl { 1 } $_[0], $_[1] }
sub rmean { scalar bixectr { 1 } $_[1], $_[0] }

sub lmean_ok {
	local $Test::Builder::Level = $Test::Builder::Level + 1;
	my $mesg = sprintf "lmean(%s, %s) = %s", map {
		# Explicitly pass $_ here, as it may be
		# mistaken for ref ?PATTERN? (deprecated
		# in v5.14 and only removed in v5.22)
		ref($_) ? "$_" : sprintf '%s%#x', (
			$_ < 0 ? ('-', -$_) : ('+', +$_)
		)
	} @_;
	cmp_ok (lmean( $_[0], $_[1] ), '==', ( $_[2] ), $mesg);
}

	lmean_ok +( 0, 1 ) => ( 0 );
	lmean_ok +( -10, 42 ) => ( 16 );
	lmean_ok +( 0, 69 ) => ( 34 );
	lmean_ok +( -1, 0 ) => ( -1 );
	lmean_ok +( -42, 10 ) => ( -16 );
	lmean_ok +( -69, 0 ) => ( -35 );

SKIP: {
	skip ("lossy IV+UV arithmetic", 15) if $] < 5.008;

	lmean_ok +( uvmin, ivmax ) => ( ivmax >> 1 );
	lmean_ok +( uvmin, uvmax-2 ) => ( ivmax ) - 1;
	lmean_ok +( uvmin, uvmax-1 ) => ( ivmax );
	lmean_ok +( uvmin, uvmax ) => ( ivmax );
	lmean_ok +( ivmin, ivmax ) => ( -1 );
	lmean_ok +( ivmin, uvmax ) => ( ivmax >> 1 );

	lmean_ok +( ivmin, ivmin+1 ) => ( ivmin );
	lmean_ok +( ivmin, ivmin+2 ) => ( ivmin + 1 );
	lmean_ok +( ivmin, ivmin+3 ) => ( ivmin + 1 );
	lmean_ok +( ivmax-1, ivmax ) => ( ivmax - 1 );
	lmean_ok +( ivmax-2, ivmax ) => ( ivmax - 1 );
	lmean_ok +( ivmax-3, ivmax ) => ( ivmax - 2 );
	lmean_ok +( uvmax-1, uvmax ) => ( uvmax - 1 );
	lmean_ok +( uvmax-2, uvmax ) => ( uvmax - 1 );
	lmean_ok +( uvmax-3, uvmax ) => ( uvmax - 2 );
}

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
	skip ("lossy IV+UV arithmetic", 15) if $] < 5.008;

	rmean_ok +( uvmin, ivmax ) => ( ivmax >> 1 ) + 1;
	rmean_ok +( uvmin, uvmax-2 ) => ( ivmax );
	rmean_ok +( uvmin, uvmax-1 ) => ( ivmax );
	rmean_ok +( uvmin, uvmax ) => ( ivmax ) + 1;
	rmean_ok +( ivmin, ivmax ) => ( 0 );
	rmean_ok +( ivmin, uvmax ) => ( ivmax >> 1 ) + 1;

	rmean_ok +( ivmin, ivmin+1 ) => ( ivmin + 1 );
	rmean_ok +( ivmin, ivmin+2 ) => ( ivmin + 1 );
	rmean_ok +( ivmin, ivmin+3 ) => ( ivmin + 2 );
	rmean_ok +( ivmax-1, ivmax ) => ( ivmax );
	rmean_ok +( ivmax-2, ivmax ) => ( ivmax - 1 );
	rmean_ok +( ivmax-3, ivmax ) => ( ivmax - 1 );
	rmean_ok +( uvmax-1, uvmax ) => ( uvmax );
	rmean_ok +( uvmax-2, uvmax ) => ( uvmax - 1 );
	rmean_ok +( uvmax-3, uvmax ) => ( uvmax - 1 );
}

# Math::BigInt should be in core, but technically
# we never required it ourselves in TEST_REQUIRES...
SKIP: {
	skip "No Math::BigInt", 30 unless eval { require Math::BigInt; 1 };

	my $ZERO = Math::BigInt->new("0");
	my $ONE = Math::BigInt->new("1");

# Let's use an absurdly big number no system is known
# to use to ensure that native integer math isn't used.
	my $U256_min = $ZERO;
	my $U256_max = ($ONE << 256) - $ONE;
	my $I256_min = - ($ONE << 255);
	my $I256_max = ($ONE << 255) - $ONE;

	lmean_ok +( $U256_min, $I256_max ) => ( $I256_max >> 1 );
	lmean_ok +( $U256_min, $U256_max-2 ) => ( $I256_max ) - 1;
	lmean_ok +( $U256_min, $U256_max-1 ) => ( $I256_max );
	lmean_ok +( $U256_min, $U256_max ) => ( $I256_max );
	lmean_ok +( $I256_min, $I256_max ) => ( -1 );
	lmean_ok +( $I256_min, $U256_max ) => ( $I256_max >> 1 );

	lmean_ok +( $I256_min, $I256_min+1 ) => ( $I256_min );
	lmean_ok +( $I256_min, $I256_min+2 ) => ( $I256_min + 1 );
	lmean_ok +( $I256_min, $I256_min+3 ) => ( $I256_min + 1 );
	lmean_ok +( $I256_max-1, $I256_max ) => ( $I256_max - 1 );
	lmean_ok +( $I256_max-2, $I256_max ) => ( $I256_max - 1 );
	lmean_ok +( $I256_max-3, $I256_max ) => ( $I256_max - 2 );
	lmean_ok +( $U256_max-1, $U256_max ) => ( $U256_max - 1 );
	lmean_ok +( $U256_max-2, $U256_max ) => ( $U256_max - 1 );
	lmean_ok +( $U256_max-3, $U256_max ) => ( $U256_max - 2 );

	rmean_ok +( $U256_min, $I256_max ) => ( $I256_max >> 1 ) + 1;
	rmean_ok +( $U256_min, $U256_max-2 ) => ( $I256_max );
	rmean_ok +( $U256_min, $U256_max-1 ) => ( $I256_max );
	rmean_ok +( $U256_min, $U256_max ) => ( $I256_max ) + 1;
	rmean_ok +( $I256_min, $I256_max ) => ( 0 );
	rmean_ok +( $I256_min, $U256_max ) => ( $I256_max >> 1 ) + 1;

	rmean_ok +( $I256_min, $I256_min+1 ) => ( $I256_min + 1 );
	rmean_ok +( $I256_min, $I256_min+2 ) => ( $I256_min + 1 );
	rmean_ok +( $I256_min, $I256_min+3 ) => ( $I256_min + 2 );
	rmean_ok +( $I256_max-1, $I256_max ) => ( $I256_max );
	rmean_ok +( $I256_max-2, $I256_max ) => ( $I256_max - 1 );
	rmean_ok +( $I256_max-3, $I256_max ) => ( $I256_max - 1 );
	rmean_ok +( $U256_max-1, $U256_max ) => ( $U256_max );
	rmean_ok +( $U256_max-2, $U256_max ) => ( $U256_max - 1 );
	rmean_ok +( $U256_max-3, $U256_max ) => ( $U256_max - 1 );
}
